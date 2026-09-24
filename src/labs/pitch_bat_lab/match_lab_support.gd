class_name MatchLabSupport
extends RefCounted

const MIN_EFFORT: float = 0.82
const MAX_EFFORT: float = 1.12


static func create_match(
	debug_player_id: StringName, player_team_name: String, rival_team_name: String
) -> MatchState:
	var player_roster: Array[PlayerDefinition] = _build_roster(debug_player_id, "Player", false)
	var rival_roster: Array[PlayerDefinition] = _build_roster(debug_player_id, "Rival", true)
	return MatchState.create(
		TeamMatchState.create(player_team_name, player_roster),
		TeamMatchState.create(rival_team_name, rival_roster)
	)


static func rated_pitch(
	pitch: PitchDefinition, pitcher: PlayerDefinition, effort: float, release_overdrive: float = 0.0
) -> PitchDefinition:
	var result: PitchDefinition = pitch.duplicate() as PitchDefinition
	var bounded_effort: float = clampf(effort, MIN_EFFORT, MAX_EFFORT)
	var velocity_factor: float = (0.90 + float(pitcher.velocity) * 0.02) * bounded_effort
	var effort_break_factor: float = lerpf(
		0.92, 1.06, inverse_lerp(MIN_EFFORT, MAX_EFFORT, bounded_effort)
	)
	var break_factor: float = (0.85 + float(pitcher.break_rating) * 0.03) * effort_break_factor
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
		cost_multiplier = lerpf(0.68, 1.0, inverse_lerp(MIN_EFFORT, 1.0, bounded_effort))
	else:
		cost_multiplier = lerpf(1.0, 1.38, inverse_lerp(1.0, MAX_EFFORT, bounded_effort))
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
	if not can_edit_pitch_plan(lab) or not lab._match_state.can_change_defense():
		lab._status_label.text = ("Pitching changes are allowed only between batters.")
		return
	var team: TeamMatchState = lab._match_state.defensive_team()
	if not team.select_pitcher(roster_index):
		return
	lab._selected_pitch_index = 0
	lab._apply_defensive_assignment()
	lab._status_label.text = (
		"%s is now pitching."
		% [
			team.current_pitcher().definition.display_name,
		]
	)
	lab._refresh_config()


static func cycle_pitcher(lab: PitchBatLab, direction: int) -> void:
	if lab._match_state == null:
		return
	var team: TeamMatchState = lab._match_state.defensive_team()
	select_pitcher(lab, team.next_available_pitcher(direction))


static func cycle_primary_fielder(lab: PitchBatLab) -> void:
	if not can_edit_pitch_plan(lab) or not lab._match_state.can_change_defense():
		lab._status_label.text = ("Fielder changes are allowed only between batters.")
		return
	lab._match_state.defensive_team().cycle_fielder(1)
	lab._apply_defensive_assignment()
	lab._refresh_config()


static func toggle_field_setup(lab: PitchBatLab) -> void:
	if lab._field_setup_active:
		lab._field_setup_active = false
		lab._apply_role_camera()
		lab._status_label.text = ""
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
	lab._pitching_staff_active = false
	lab._camera_director.set_shot(MatchCameraDirector.Shot.FIELD_SETUP)
	lab._status_label.text = ""
	lab._refresh_config()


static func toggle_pitching_staff(lab: PitchBatLab) -> void:
	if lab._pitching_staff_active:
		lab._pitching_staff_active = false
		lab._apply_role_camera()
		lab._status_label.text = ""
		lab._refresh_config()
		return
	if (
		not lab._player_is_pitching()
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or (lab._pitch_actor != null and lab._pitch_actor.running)
		or lab._release_controller.active
	):
		lab._status_label.text = ("Pitching staff is available before a defensive Pitch.")
		return
	lab._pitching_staff_active = true
	lab._field_setup_active = false
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING_STAFF)
	lab._status_label.text = ""
	lab._refresh_config()


static func select_fielder_anchor(lab: PitchBatLab, anchor_index: int) -> void:
	if lab._match_mode and not can_edit_pitch_plan(lab):
		lab._status_label.text = "Fielder position is locked during delivery."
		return
	if (lab._pitch_actor != null and lab._pitch_actor.running) or lab._ball_in_play_is_live():
		lab._status_label.text = "Fielder position is locked during the play."
		return
	var requested_index: int = clampi(anchor_index, 0, 8)
	if not lab._field_definition.is_fielder_anchor_available(requested_index):
		lab._status_label.text = "That center lane is reserved for the Pitcher."
		return
	lab._fielder_anchor_index = requested_index
	if lab._primary_fielder != null:
		lab._primary_fielder.set_anchor(
			lab._field_definition.fielder_anchor(lab._fielder_anchor_index)
		)
	lab._status_label.text = (
		"Primary Fielder: %s"
		% [
			lab._field_definition.fielder_anchor_name(lab._fielder_anchor_index),
		]
	)
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
	consider_ai_pitching_change(lab)
	assign_ai_fielder_anchor(lab)


static func consider_ai_pitching_change(lab: PitchBatLab) -> void:
	if not lab._player_is_batting() or not lab._match_state.can_change_defense():
		return
	var team: TeamMatchState = lab._match_state.defensive_team()
	if team.current_pitcher().stamina_percent() > 0.17:
		return
	var best: int = team.pitcher_index
	var best_stamina: float = team.current_pitcher().stamina_percent()
	for index in range(team.roster.size()):
		var candidate: PlayerMatchState = team.roster[index]
		if not candidate.pitching_finished and candidate.stamina_percent() > best_stamina:
			best = index
			best_stamina = candidate.stamina_percent()
	if best != team.pitcher_index and team.select_pitcher(best):
		lab._selected_pitch_index = 0
		lab._last_ai_pitch_index = -1
		lab._ai_pitch_preselected = false


static func assign_ai_fielder_anchor(lab: PitchBatLab) -> void:
	if not lab._player_is_batting() or lab._match_state == null:
		return
	var batter: PlayerDefinition = lab._match_state.batter().definition
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (
		lab._match_state.inning * 1009
		+ lab._match_state.plate_appearance_number * 313
		+ batter.power * 43
		+ batter.contact * 17
	)
	var depth_row: int = 1
	if batter.power >= 8:
		depth_row = 2 if rng.randf() < 0.72 else 1
	elif batter.power <= 5:
		depth_row = 0 if rng.randf() < 0.58 else 1
	var pull_column: int = (
		0 if batter.bats == PlayerDefinition.Handedness.LEFT else 2
	)
	var column_roll: float = rng.randf()
	var column: int = 1
	if column_roll >= 0.46 and column_roll < 0.84:
		column = pull_column
	elif column_roll >= 0.84:
		column = 2 - pull_column
	var anchor_index: int = depth_row * 3 + column
	if not lab._field_definition.is_fielder_anchor_available(anchor_index):
		# Preserve the chosen depth but move toward the Batter's pull side so
		# opponent defense never stacks directly in the Pitcher's sightline.
		anchor_index = depth_row * 3 + pull_column
	lab._fielder_anchor_index = anchor_index


static func ai_pitch_choice(
	option_count: int,
	throw_number: int,
	inning: int,
	balls: int = 0,
	strikes: int = 0,
	previous_pitch_index: int = -1
) -> Dictionary:
	var options: Array[PitchDefinition] = []
	for index in range(mini(option_count, PitchBatLab.PITCH_IDS.size())):
		options.append(ContentDB.get_pitch(PitchBatLab.PITCH_IDS[index]))
	if options.is_empty():
		return {"pitch_index": 0, "target": Vector2(0, 1.05), "effort": 1.0}
	return PitchingStrategy.choose(options, ContentDB.get_player(PitchBatLab.DEBUG_PLAYER_ID),
		balls, strikes, previous_pitch_index, (throw_number + 1) * 7919 + inning * 101,
		0.45, false)


static func apply_ai_pitch_choice(lab: PitchBatLab) -> void:
	var options: Array[PitchDefinition] = lab._current_pitch_options()
	if options.is_empty():
		return
	var choice: Dictionary = PitchingStrategy.choose(
		options,
		lab._match_state.pitcher().definition,
		lab._match_state.balls,
		lab._match_state.strikes,
		lab._last_ai_pitch_index,
		(lab._throw_number + 1) * 7919 + lab._match_state.inning * 101,
		lab._match_state.ai_tactical_quality,
		lab._match_state.batter().bats_left()
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
	if lab._batter_approach.plate_appearance_number != lab._match_state.plate_appearance_number:
		lab._batter_approach.begin_plate_appearance(lab._match_state.plate_appearance_number)
	var batter_state: PlayerMatchState = lab._match_state.batter()
	var decision: Dictionary = lab._batter_approach.track_pitch(
		pitch, lab._pitch_actor.state, batter_state.definition,
		lab._match_state.balls, lab._match_state.strikes,
		lab._throw_number * 3571 + lab._match_state.plate_appearance_number * 97,
		batter_state.batting_hand(), ContentDB.get_swing(lab.CONTACT_SWING_ID),
		ContentDB.get_swing(lab.POWER_SWING_ID)
	)
	if decision.is_empty():
		return
	lab._ai_swing_decided = true
	var ball_xy: Vector2 = decision.plate_read
	lab._last_ai_awareness = float(decision["awareness"])
	if lab._active_play_record != null:
		var record: PlayRecord = lab._active_play_record
		record.ai_decision_recorded = true
		record.ai_swung = bool(decision["swing"])
		record.ai_awareness = float(decision["awareness"])
		record.ai_swing_chance = float(decision["swing_chance"])
		record.ai_aim_sigma = float(decision["aim_sigma"])
		record.ai_plate_read = ball_xy
	lab._last_ai_read_text = (
		"%s • swing %.0f%% • aim σ %.0f cm"
		% [
			String(decision["location_read"]),
			float(decision["swing_chance"]) * 100.0,
			float(decision["aim_sigma"]) * 100.0,
		]
	)
	if not bool(decision["swing"]):
		return
	var ai_aim: Vector2 = decision["aim"]
	lab._resolve_swing(
		lab.POWER_SWING_ID if bool(decision["use_power"]) else lab.CONTACT_SWING_ID, ai_aim
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
		"DEBUG BIP — %s\nJolt launch with live field rules and defense" % preset_name
	)
	lab._start_ball_in_play(launch)


static func _build_roster(
	debug_player_id: StringName, prefix: String, mirror_handedness: bool
) -> Array[PlayerDefinition]:
	var result: Array[PlayerDefinition] = []
	var template: PlayerDefinition = ContentDB.get_player(debug_player_id)
	var role_names: Array[String] = ["Ace", "Slugger", "Glove", "Utility"]
	for index in range(TeamMatchState.ROSTER_SIZE):
		var player: PlayerDefinition = template.duplicate() as PlayerDefinition
		player.id = StringName("player.lab_%s_%d" % [prefix.to_lower(), index])
		player.display_name = "%s %s" % [prefix, role_names[index]]
		var is_left_handed: bool = (
			(index == 2 and not mirror_handedness)
			or (index == 3 and mirror_handedness)
		)
		player.bats = (
			PlayerDefinition.Handedness.LEFT
			if is_left_handed
			else PlayerDefinition.Handedness.RIGHT
		)
		player.throws = (
			PlayerDefinition.Handedness.LEFT
			if is_left_handed
			else PlayerDefinition.Handedness.RIGHT
		)
		_configure_player(player, index, mirror_handedness)
		result.append(player)
	return result


static func _configure_player(player: PlayerDefinition, index: int, rival: bool) -> void:
	var pitch_ids: Array[StringName]
	match index:
		0:
			_set_stats(player, [5, 5, 6, 8, 7, 7, 8])
			if rival:
				pitch_ids = [
					&"pitch.overhand_four_seam",
					&"pitch.overhand_slider",
					&"pitch.overhand_sinker",
				]
			else:
				pitch_ids = [
					&"pitch.overhand_four_seam",
					&"pitch.overhand_slider",
					&"pitch.overhand_sinker",
					&"pitch.eephus",
					&"pitch.knuckleball",
					&"pitch.riser",
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
