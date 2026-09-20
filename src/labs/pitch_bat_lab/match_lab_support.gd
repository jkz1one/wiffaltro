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
	effort: float,
	release_overdrive: float = 0.0
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
	var overdrive: float = clampf(release_overdrive, 0.0, 1.0)
	match pitch.category:
		PitchDefinition.Category.FASTBALL:
			result.nominal_velocity_mps *= lerpf(1.0, 1.045, overdrive)
		PitchDefinition.Category.BREAKING:
			result.nominal_velocity_mps *= lerpf(1.0, 1.012, overdrive)
			result.nominal_spin_rpm *= lerpf(1.0, 1.10, overdrive)
			result.perforation_influence *= lerpf(1.0, 1.08, overdrive)
		PitchDefinition.Category.OFF_SPEED:
			result.nominal_velocity_mps *= lerpf(1.0, 1.020, overdrive)
			result.nominal_spin_rpm *= lerpf(1.0, 1.04, overdrive)
		_:
			result.nominal_velocity_mps *= lerpf(1.0, 1.015, overdrive)
			result.perforation_influence *= lerpf(1.0, 1.04, overdrive)
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

static func release_overdrive_control_penalty(release_overdrive: float) -> float:
	return clampf(release_overdrive, 0.0, 1.0) * 0.18

static func can_edit_pitch_plan(lab: PitchBatLab) -> bool:
	if (
		not lab._match_mode
		or lab._match_state == null
		or not lab._player_is_pitching()
		or lab._debug_paused
	):
		return false
	if (
		lab._match_state.phase != MatchState.Phase.PRE_PITCH
		and lab._match_state.phase != MatchState.Phase.PLAY_DEAD
	):
		return false
	if (
		(lab._release_controller != null and lab._release_controller.active)
		or (lab._pitch_actor != null and lab._pitch_actor.running)
	):
		return false
	return not lab._ball_in_play_is_live()

static func pitcher_fielding_rating(lab: PitchBatLab) -> int:
	if lab._match_mode and lab._match_state != null:
		return lab._match_state.pitcher().definition.fielding
	return 5

static func select_pitcher(lab: PitchBatLab, roster_index: int) -> void:
	if (
		not can_edit_pitch_plan(lab)
		or not lab._match_state.can_change_defense()
	):
		lab._status_label.text = (
			"Pitching changes are allowed only between batters."
		)
		return
	var team: TeamMatchState = lab._match_state.defensive_team()
	if not team.select_pitcher(roster_index):
		return
	lab._selected_pitch_index = 0
	lab._apply_defensive_assignment()
	lab._status_label.text = "%s is now pitching." % [
		team.current_pitcher().definition.display_name,
	]
	lab._refresh_config()

static func cycle_pitcher(lab: PitchBatLab, direction: int) -> void:
	if lab._match_state == null:
		return
	var team: TeamMatchState = lab._match_state.defensive_team()
	select_pitcher(
		lab,
		posmod(team.pitcher_index + direction, team.roster.size())
	)

static func cycle_primary_fielder(lab: PitchBatLab) -> void:
	if (
		not can_edit_pitch_plan(lab)
		or not lab._match_state.can_change_defense()
	):
		lab._status_label.text = (
			"Fielder changes are allowed only between batters."
		)
		return
	lab._match_state.defensive_team().cycle_fielder(1)
	lab._apply_defensive_assignment()
	lab._refresh_config()

static func toggle_field_setup(lab: PitchBatLab) -> void:
	if lab._field_setup_active:
		lab._field_setup_active = false
		lab._apply_role_camera()
		lab._status_label.text = (
			"Field position locked. Hold click, then release on the timing cue."
		)
		lab._refresh_config()
		return
	if (
		not lab._player_is_pitching()
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or (lab._pitch_actor != null and lab._pitch_actor.running)
		or lab._release_controller.active
	):
		lab._status_label.text = "Field setup is available before a defensive Pitch."
		return
	lab._field_setup_active = true
	lab._camera_director.set_shot(MatchCameraDirector.Shot.FIELD_SETUP)
	lab._status_label.text = "FIELD SETUP — choose a 3×3 anchor, then return to Pitch."
	lab._refresh_config()

static func select_fielder_anchor(lab: PitchBatLab, anchor_index: int) -> void:
	if lab._match_mode and not can_edit_pitch_plan(lab):
		lab._status_label.text = "Fielder position is locked during delivery."
		return
	if (
		(lab._pitch_actor != null and lab._pitch_actor.running)
		or lab._ball_in_play_is_live()
	):
		lab._status_label.text = "Fielder position is locked during the play."
		return
	lab._fielder_anchor_index = clampi(anchor_index, 0, 8)
	if lab._primary_fielder != null:
		lab._primary_fielder.set_anchor(
			lab._field_definition.fielder_anchor(lab._fielder_anchor_index)
		)
	lab._status_label.text = "Primary Fielder: %s" % [
		lab._field_definition.fielder_anchor_name(lab._fielder_anchor_index),
	]
	lab._refresh_config()

static func cycle_base_preset(lab: PitchBatLab) -> void:
	if lab._ball_in_play_is_live():
		lab._status_label.text = "Base state is locked during the play."
		return
	lab._base_preset_index = (lab._base_preset_index + 1) % 3
	lab._base_state.set_debug_preset(lab._base_preset_index)
	lab._refresh_config()

static func assign_ai_defense_for_half(lab: PitchBatLab) -> void:
	if not lab._player_is_batting():
		return
	var team: TeamMatchState = lab._match_state.defensive_team()
	team.pitcher_index = posmod(lab._match_state.inning - 1, team.roster.size())
	team.fielder_index = (team.pitcher_index + 1) % team.roster.size()

static func ai_pitch_choice(
	option_count: int,
	throw_number: int,
	inning: int,
	balls: int = 0,
	strikes: int = 0,
	previous_pitch_index: int = -1
) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (
		(throw_number + 1) * 7919
		+ inning * 101
		+ balls * 43
		+ strikes * 67
	)
	var pitch_index: int = rng.randi_range(0, maxi(0, option_count - 1))
	if (
		option_count > 1
		and pitch_index == previous_pitch_index
		and rng.randf() < 0.58
	):
		pitch_index = (pitch_index + rng.randi_range(1, option_count - 1)) % option_count
	var strike_probability: float = 0.70
	if balls >= 3 and strikes >= 2:
		strike_probability = 0.82
	elif balls >= 3:
		strike_probability = 0.90
	elif strikes >= 2:
		strike_probability = 0.50
	var result: Dictionary = {
		"pitch_index": pitch_index,
		"target": Vector2.ZERO,
		"effort": (
			rng.randf_range(0.90, 1.04)
			if balls >= 3
			else rng.randf_range(0.88, 1.10)
		),
	}
	if rng.randf() < strike_probability:
		result.target = Vector2(
			rng.randf_range(-0.37, 0.37),
			rng.randf_range(0.62, 1.48)
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
		lab._match_state.inning,
		lab._match_state.balls,
		lab._match_state.strikes,
		lab._last_ai_pitch_index
	)
	lab._selected_pitch_index = int(choice["pitch_index"])
	lab._last_ai_pitch_index = lab._selected_pitch_index
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
	):
		return
	var pitch: PitchDefinition = lab._selected_pitch()
	if pitch == null or lab._batter_approach == null:
		return
	if (
		lab._batter_approach.plate_appearance_number
		!= lab._match_state.plate_appearance_number
	):
		lab._batter_approach.reset(lab._match_state.plate_appearance_number)
	var ball_xy: Vector2 = Vector2(
		lab._pitch_actor.state.position.x,
		lab._pitch_actor.state.position.y
	)
	var plate_speed_mps: float = lab._pitch_actor.state.velocity.length()
	var trigger_z: float = lab._batter_approach.trigger_z(
		pitch,
		plate_speed_mps,
		ball_xy
	)
	if lab._pitch_actor.state.position.z > trigger_z:
		return
	lab._ai_swing_decided = true
	var batter_state: PlayerMatchState = lab._match_state.batter()
	var decision: Dictionary = lab._batter_approach.decide(
		pitch,
		ball_xy,
		ball_xy,
		batter_state.definition,
		lab._match_state.balls,
		lab._match_state.strikes,
		plate_speed_mps,
		lab._throw_number * 3571
		+ lab._match_state.plate_appearance_number * 97
	)
	lab._last_ai_awareness = float(decision["awareness"])
	lab._last_ai_read_text = "%s • swing %.0f%% • aim σ %.0f cm" % [
		String(decision["location_read"]),
		float(decision["swing_chance"]) * 100.0,
		float(decision["aim_sigma"]) * 100.0,
	]
	lab._batter_approach.observe(pitch, ball_xy)
	if not bool(decision["swing"]):
		return
	var ai_aim: Vector2 = decision["aim"]
	lab._resolve_swing(
		lab.POWER_SWING_ID if bool(decision["use_power"]) else lab.CONTACT_SWING_ID,
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
