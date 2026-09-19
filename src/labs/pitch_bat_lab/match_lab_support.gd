class_name MatchLabSupport
extends RefCounted

const MIN_EFFORT: float = 0.82
const MAX_EFFORT: float = 1.12

static func create_match(
	debug_player_id: StringName,
	player_team_name: String,
	rival_team_name: String
) -> MatchState:
	var player_roster: Array[PlayerDefinition] = _build_roster(
		debug_player_id,
		"Player",
		false
	)
	var rival_roster: Array[PlayerDefinition] = _build_roster(
		debug_player_id,
		"Rival",
		true
	)
	return MatchState.create(
		TeamMatchState.create(player_team_name, player_roster),
		TeamMatchState.create(rival_team_name, rival_roster)
	)

static func rated_pitch(
	pitch: PitchDefinition,
	pitcher: PlayerDefinition,
	effort: float
) -> PitchDefinition:
	var result: PitchDefinition = pitch.duplicate() as PitchDefinition
	var bounded_effort: float = clampf(effort, MIN_EFFORT, MAX_EFFORT)
	var velocity_factor: float = (
		0.90 + float(pitcher.velocity) * 0.02
	) * bounded_effort
	var effort_break_factor: float = lerpf(
		0.92,
		1.06,
		inverse_lerp(MIN_EFFORT, MAX_EFFORT, bounded_effort)
	)
	var break_factor: float = (
		0.85 + float(pitcher.break_rating) * 0.03
	) * effort_break_factor
	result.nominal_velocity_mps *= velocity_factor
	result.nominal_spin_rpm *= break_factor
	result.perforation_influence *= break_factor
	return result

static func stamina_cost(pitch: PitchDefinition, effort: float) -> float:
	var bounded_effort: float = clampf(effort, MIN_EFFORT, MAX_EFFORT)
	var cost_multiplier: float
	if bounded_effort <= 1.0:
		cost_multiplier = lerpf(
			0.68,
			1.0,
			inverse_lerp(MIN_EFFORT, 1.0, bounded_effort)
		)
	else:
		cost_multiplier = lerpf(
			1.0,
			1.38,
			inverse_lerp(1.0, MAX_EFFORT, bounded_effort)
		)
	return pitch.stamina_cost * cost_multiplier

static func execution_quality_penalty(effort: float) -> float:
	return maxf(0.0, effort - 1.0) * 0.40

static func pitcher_fielding_rating(lab: PitchBatLab) -> int:
	if lab._match_mode and lab._match_state != null:
		return lab._match_state.pitcher().definition.fielding
	return 5

static func assign_ai_defense_for_half(lab: PitchBatLab) -> void:
	if not lab._player_is_batting():
		return
	var team: TeamMatchState = lab._match_state.defensive_team()
	team.pitcher_index = posmod(lab._match_state.inning - 1, team.roster.size())
	team.fielder_index = (team.pitcher_index + 1) % team.roster.size()

static func ai_pitch_choice(
	option_count: int,
	throw_number: int,
	inning: int
) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (throw_number + 1) * 7919 + inning * 101
	var result: Dictionary = {
		"pitch_index": rng.randi_range(0, maxi(0, option_count - 1)),
		"target": Vector2.ZERO,
		"effort": rng.randf_range(0.88, 1.08),
	}
	if rng.randf() < 0.72:
		result.target = Vector2(
			rng.randf_range(-0.34, 0.34),
			rng.randf_range(0.66, 1.44)
		)
		return result

	match rng.randi_range(0, 3):
		0:
			result.target = Vector2(
				rng.randf_range(-0.68, -0.46),
				rng.randf_range(0.55, 1.55)
			)
		1:
			result.target = Vector2(
				rng.randf_range(0.46, 0.68),
				rng.randf_range(0.55, 1.55)
			)
		2:
			result.target = Vector2(
				rng.randf_range(-0.38, 0.38),
				rng.randf_range(0.34, 0.52)
			)
		_:
			result.target = Vector2(
				rng.randf_range(-0.38, 0.38),
				rng.randf_range(1.58, 1.80)
			)
	return result

static func apply_ai_pitch_choice(lab: PitchBatLab) -> void:
	var options: Array[PitchDefinition] = lab._current_pitch_options()
	if options.is_empty():
		return
	var choice: Dictionary = ai_pitch_choice(
		options.size(),
		lab._throw_number,
		lab._match_state.inning
	)
	lab._selected_pitch_index = int(choice["pitch_index"])
	lab._pitch_target = choice["target"]
	lab._pitch_effort = float(choice["effort"])
	lab._refresh_markers()

static func try_ai_swing(lab: PitchBatLab) -> void:
	if (
		not lab._match_mode
		or lab._match_state == null
		or lab._player_is_batting()
		or lab._ai_swing_decided
		or lab._pitch_actor == null
		or not lab._pitch_actor.running
		or lab._pitch_actor.state == null
		or lab._pitch_actor.state.position.z > 0.60
	):
		return
	lab._ai_swing_decided = true
	var batter_state: PlayerMatchState = lab._match_state.batter()
	var ball_xy: Vector2 = Vector2(
		lab._pitch_actor.state.position.x,
		lab._pitch_actor.state.position.y
	)
	var appears_hittable: bool = (
		ball_xy.x >= lab.ZONE_MIN_X - 0.10
		and ball_xy.x <= lab.ZONE_MAX_X + 0.10
		and ball_xy.y >= lab.ZONE_MIN_Y - 0.10
		and ball_xy.y <= lab.ZONE_MAX_Y + 0.10
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (
		lab._throw_number * 3571
		+ lab._match_state.plate_appearance_number * 97
	)
	var swing_chance: float = 0.84 if appears_hittable else 0.14
	if rng.randf() > swing_chance:
		return
	var aim_sigma: float = lerpf(
		0.16,
		0.055,
		float(batter_state.definition.contact) / 10.0
	)
	var ai_aim: Vector2 = ball_xy + Vector2(
		rng.randfn(0.0, aim_sigma),
		rng.randfn(0.0, aim_sigma)
	)
	var use_power: bool = (
		batter_state.definition.power > batter_state.definition.contact
		and rng.randf() < 0.52
	)
	lab._resolve_swing(
		lab.POWER_SWING_ID if use_power else lab.CONTACT_SWING_ID,
		ai_aim
	)

static func launch_debug_batted_ball(lab: PitchBatLab) -> void:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0.0, 1.05, 0.35)
	var preset_name: String
	match lab._debug_launch_index:
		0:
			preset_name = "Grounder"
			launch.velocity = Vector3(-2.0, 1.5, 18.0)
			launch.angular_velocity = Vector3(18.0, 4.0, 0.0)
		1:
			preset_name = "Deep Air"
			launch.velocity = Vector3(3.0, 6.5, 12.5)
			launch.angular_velocity = Vector3(-70.0, 0.0, 5.0)
		2:
			preset_name = "Wall On Fly"
			launch.velocity = Vector3(-3.0, 7.0, 26.0)
			launch.angular_velocity = Vector3(-45.0, 0.0, 0.0)
		_:
			preset_name = "Home Run Arc"
			launch.velocity = Vector3(1.0, 14.5, 27.0)
			launch.angular_velocity = Vector3(-95.0, 0.0, 0.0)
	lab._debug_launch_index = (lab._debug_launch_index + 1) % 4
	lab._status_label.text = (
		"DEBUG BIP — %s\nJolt launch with live field rules and defense"
		% preset_name
	)
	lab._start_ball_in_play(launch)

static func _build_roster(
	debug_player_id: StringName,
	prefix: String,
	mirror_handedness: bool
) -> Array[PlayerDefinition]:
	var result: Array[PlayerDefinition] = []
	var template: PlayerDefinition = ContentDB.get_player(debug_player_id)
	var role_names: Array[String] = ["Ace", "Slugger", "Glove", "Utility"]
	for index in range(TeamMatchState.ROSTER_SIZE):
		var player: PlayerDefinition = template.duplicate() as PlayerDefinition
		player.id = StringName("player.lab_%s_%d" % [prefix.to_lower(), index])
		player.display_name = "%s %s" % [prefix, role_names[index]]
		player.bats = (
			PlayerDefinition.Handedness.LEFT
			if (index + int(mirror_handedness)) % 2 == 1
			else PlayerDefinition.Handedness.RIGHT
		)
		player.throws = (
			PlayerDefinition.Handedness.LEFT
			if index == 2
			else PlayerDefinition.Handedness.RIGHT
		)
		_configure_player(player, index, mirror_handedness)
		result.append(player)
	return result

static func _configure_player(
	player: PlayerDefinition,
	index: int,
	rival: bool
) -> void:
	var pitch_ids: Array[StringName]
	match index:
		0:
			_set_stats(player, [5, 5, 6, 8, 7, 7, 8])
			pitch_ids = [
				&"pitch.overhand_four_seam",
				&"pitch.overhand_slider",
				&"pitch.overhand_sinker",
			]
		1:
			_set_stats(player, [5, 9, 4, 5, 4, 5, 5])
			pitch_ids = [
				&"pitch.overhand_four_seam",
				&"pitch.eephus",
			]
		2:
			_set_stats(player, [7, 4, 9, 5, 8, 6, 6])
			pitch_ids = [
				&"pitch.sidearm_sinker",
				&"pitch.sidearm_slider",
				&"pitch.knuckleball",
			]
		_:
			_set_stats(player, [8, 6, 7, 6, 6, 8, 7])
			pitch_ids = [
				&"pitch.overhand_four_seam",
				&"pitch.riser",
				&"pitch.drop",
			]
	if rival:
		player.contact = clampi(player.contact + 1, 0, 10)
		player.control = clampi(player.control - 1, 0, 10)
	player.starting_pitches = []
	for pitch_id in pitch_ids:
		var pitch: PitchDefinition = ContentDB.get_pitch(pitch_id)
		if pitch != null:
			player.starting_pitches.append(pitch)
	player.pitch_capacity = player.starting_pitches.size()

static func _set_stats(player: PlayerDefinition, stats: Array[int]) -> void:
	player.contact = int(stats[0])
	player.power = int(stats[1])
	player.fielding = int(stats[2])
	player.velocity = int(stats[3])
	player.break_rating = int(stats[4])
	player.control = int(stats[5])
	player.stamina = int(stats[6])
