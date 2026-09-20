class_name PitchBatLabFeelSupport
extends RefCounted

const AIM_SPEED_MPS: float = 0.82


static func adjust_pitch_target(lab: PitchBatLab, delta_xy: Vector2) -> void:
	lab._pitch_target.x = clampf(
		lab._pitch_target.x + delta_xy.x, lab.PITCH_AIM_MIN_X, lab.PITCH_AIM_MAX_X
	)
	lab._pitch_target.y = clampf(
		lab._pitch_target.y + delta_xy.y, lab.PITCH_AIM_MIN_Y, lab.PITCH_AIM_MAX_Y
	)
	lab._refresh_markers()
	lab._refresh_config()


static func adjust_pitch_effort(lab: PitchBatLab, delta: float) -> void:
	lab._pitch_effort = clampf(
		lab._pitch_effort + delta, MatchLabSupport.MIN_EFFORT, MatchLabSupport.MAX_EFFORT
	)
	lab._refresh_config()


static func adjust_batting_aim(lab: PitchBatLab, delta_xy: Vector2) -> void:
	lab._batting_aim.x = clampf(
		lab._batting_aim.x + delta_xy.x, lab.BATTING_AIM_MIN_X, lab.BATTING_AIM_MAX_X
	)
	lab._batting_aim.y = clampf(
		lab._batting_aim.y + delta_xy.y, lab.BATTING_AIM_MIN_Y, lab.BATTING_AIM_MAX_Y
	)
	lab._refresh_markers()
	lab._refresh_config()


static func initialize(lab: PitchBatLab) -> void:
	lab._release_controller = PitchReleaseController.new()
	lab._at_bat_cadence = AtBatCadenceController.new()
	lab._batter_approach = BatterApproachModel.new()
	lab._swing_tracker = SwingContactTracker.new()
	lab._match_presentation_director = MatchPresentationDirector.new()
	if lab._camera_director == null:
		lab._camera_director = MatchCameraDirector.new()
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
	lab._camera_director.snap(lab._camera)


static func update(lab: PitchBatLab, delta_seconds: float) -> void:
	if _update_match_presentation(lab, delta_seconds):
		_update_camera(lab, delta_seconds)
		PitchBatLabPresentation.refresh_event(lab)
		return
	_update_continuous_input(lab, delta_seconds)
	_update_pitch_release(lab, delta_seconds)
	_update_at_bat_cadence(lab, delta_seconds)
	_update_pitcher_telegraph(lab)
	_update_camera(lab, delta_seconds)
	PitchBatLabPresentation.refresh_event(lab)


static func begin_match_intro(lab: PitchBatLab) -> void:
	if lab._match_presentation_director == null:
		lab._match_presentation_director = MatchPresentationDirector.new()
	lab._at_bat_cadence.stop()
	lab._status_label.text = ""
	PitchBatLabPresentation.refresh_event(lab)
	lab._match_presentation_director.begin_intro(int(Time.get_ticks_usec() & 0x7fffffff))
	lab._camera_director.set_shot(lab._match_presentation_director.current_shot())
	_sync_presentation_camera(lab)
	lab._camera_director.snap(lab._camera)
	PitchBatLabPresentation.show_match_intro(lab)


static func begin_match_outro(lab: PitchBatLab) -> void:
	if (
		lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.GAME_END
		or lab._match_presentation_director == null
		or lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO
		or lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD
	):
		return
	lab._at_bat_cadence.stop()
	lab._status_label.text = ""
	PitchBatLabPresentation.refresh_event(lab)
	lab._match_presentation_director.begin_outro(int(Time.get_ticks_usec() & 0x7fffffff))
	lab._camera_director.set_shot(lab._match_presentation_director.current_shot())
	_sync_presentation_camera(lab)
	PitchBatLabPresentation.show_match_outro(
		lab, lab._match_state.winner_name == lab.PLAYER_TEAM_NAME
	)


static func skip_match_presentation(lab: PitchBatLab) -> void:
	if lab._match_presentation_director == null:
		return
	var event: MatchPresentationDirector.Event = lab._match_presentation_director.skip()
	if event == MatchPresentationDirector.Event.INTRO_COMPLETE:
		_finish_intro(lab, true)
	elif event == MatchPresentationDirector.Event.OUTRO_COMPLETE:
		lab._camera_director.clear_presentation_motion()


static func _update_camera(lab: PitchBatLab, delta_seconds: float) -> void:
	var ball_live: bool = lab._ball_in_play_is_live()
	var ball_position: Vector3 = (
		lab._batted_ball.global_position if lab._batted_ball != null else Vector3.ZERO
	)
	lab._camera_director.update(lab._camera, delta_seconds, ball_live, ball_position)


static func _update_match_presentation(lab: PitchBatLab, delta_seconds: float) -> bool:
	if (
		lab._match_presentation_director == null
		or not lab._match_presentation_director.blocks_gameplay()
	):
		return false
	var event: MatchPresentationDirector.Event = lab._match_presentation_director.advance(
		delta_seconds
	)
	match event:
		MatchPresentationDirector.Event.SHOT_CHANGED:
			lab._camera_director.set_shot(lab._match_presentation_director.current_shot())
		MatchPresentationDirector.Event.RETURN_TO_GAMEPLAY:
			lab._camera_director.clear_presentation_motion()
			lab._apply_role_camera()
		MatchPresentationDirector.Event.INTRO_COMPLETE:
			_finish_intro(lab, false)
		MatchPresentationDirector.Event.OUTRO_COMPLETE:
			lab._camera_director.clear_presentation_motion()
		_:
			pass
	if (
		lab._match_presentation_director.mode == MatchPresentationDirector.Mode.INTRO
		or lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO
	):
		_sync_presentation_camera(lab)
	return true


static func _sync_presentation_camera(lab: PitchBatLab) -> void:
	lab._camera_director.set_presentation_motion(
		lab._match_presentation_director.current_motion(),
		lab._match_presentation_director.shot_progress()
	)


static func _finish_intro(lab: PitchBatLab, snap_camera: bool) -> void:
	lab._camera_director.clear_presentation_motion()
	lab._apply_role_camera()
	if snap_camera:
		lab._camera_director.snap(lab._camera)
	PitchBatLabPresentation.hide_match_presentation(lab)
	if lab._player_is_batting():
		lab._awaiting_batter_confirm = true
		lab._status_label.text = (
			"%s steps in\nLeft click, SPACE, or controller A to begin the at-bat."
			% lab._match_state.batter().definition.display_name
		)
		lab._refresh_config()
	else:
		lab._awaiting_batter_confirm = false
		lab._status_label.text = ""
		lab._refresh_config()


static func confirm_batter_ready(lab: PitchBatLab) -> void:
	if (
		not lab._awaiting_batter_confirm
		or not lab._player_is_batting()
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
	):
		return
	lab._awaiting_batter_confirm = false
	begin_ai_delivery(lab)


static func begin_ai_delivery(lab: PitchBatLab) -> void:
	if (
		not lab._player_is_batting()
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or (lab._pitch_actor != null and lab._pitch_actor.running)
		or lab._at_bat_cadence == null
		or lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY
	):
		return
	MatchLabSupport.apply_ai_pitch_choice(lab)
	lab._ai_pitch_preselected = true
	_begin_ai_delivery_cadence(lab)


static func _begin_ai_delivery_cadence(lab: PitchBatLab, seed_offset: int = 0) -> void:
	if lab._at_bat_cadence == null or lab._match_state == null:
		return
	lab._at_bat_cadence.begin_delivery(
		(
			lab._throw_number * 811
			+ lab._match_state.plate_appearance_number * 131
			+ lab._match_state.inning * 17
			+ seed_offset
		)
	)
	lab._status_label.text = ""
	lab._refresh_config()


static func handle_match_advance(lab: PitchBatLab) -> void:
	if lab._match_state == null or lab._ball_in_play_is_live():
		return
	match lab._match_state.phase:
		MatchState.Phase.PRE_PITCH:
			if lab._player_is_batting():
				confirm_batter_ready(lab)
			else:
				lab._throw_pitch()
		MatchState.Phase.PLAY_DEAD, MatchState.Phase.INNING_TRANSITION:
			lab._at_bat_cadence.stop()
			var changed_half: bool = lab._match_state.phase == MatchState.Phase.INNING_TRANSITION
			var completed_plate_appearance: bool = lab._match_state.between_batters
			lab._cleanup_batted_ball()
			lab._match_state.continue_after_dead_ball()
			lab._base_state = lab._match_state.bases
			if completed_plate_appearance and lab._batter_approach != null:
				lab._batter_approach.reset(lab._match_state.plate_appearance_number)
				lab._last_ai_awareness = 0.0
				lab._last_ai_read_text = "New batter"
			if changed_half:
				lab._field_setup_active = false
				lab._pitching_staff_active = false
				lab._selected_pitch_index = 0
				lab._pitch_effort = 1.0
				MatchLabSupport.assign_ai_defense_for_half(lab)
			elif completed_plate_appearance and lab._player_is_batting():
				MatchLabSupport.assign_ai_fielder_anchor(lab)
			lab._awaiting_batter_confirm = (
				lab._player_is_batting() and (completed_plate_appearance or changed_half)
			)
			lab._apply_defensive_assignment()
			lab._apply_role_camera()
			if lab._match_state.phase == MatchState.Phase.GAME_END:
				begin_match_outro(lab)
			else:
				lab._status_label.text = lab._match_state.last_event
				if lab._awaiting_batter_confirm:
					lab._status_label.text += "\nClick to begin the next at-bat"
			lab._refresh_markers()
			lab._refresh_config()
			if (
				lab._player_is_batting()
				and lab._match_state.phase == MatchState.Phase.PRE_PITCH
				and not lab._awaiting_batter_confirm
			):
				begin_ai_delivery(lab)
		MatchState.Phase.GAME_END:
			begin_match_outro(lab)


static func notify_pitch_dead(lab: PitchBatLab) -> void:
	_reset_pitcher_telegraph(lab)
	if lab._match_state != null and lab._match_state.phase == MatchState.Phase.GAME_END:
		lab._at_bat_cadence.stop()
		begin_match_outro(lab)
		return
	if (
		lab._match_state != null
		and (
			lab._match_state.phase == MatchState.Phase.PLAY_DEAD
			or lab._match_state.phase == MatchState.Phase.INNING_TRANSITION
		)
	):
		lab._at_bat_cadence.hold_dead_ball(
			lab._throw_number * 457 + lab._match_state.plate_appearance_number * 73,
			lab._match_state.between_batters,
			lab._match_state.phase == MatchState.Phase.INNING_TRANSITION
		)
		return
	lab._at_bat_cadence.stop()


static func recover_failed_pitch(lab: PitchBatLab, pitch: PitchDefinition) -> void:
	if lab._match_mode and lab._match_state != null:
		lab._match_state.cancel_pitch()
		if lab._at_bat_cadence != null:
			lab._at_bat_cadence.stop()
	lab._pending_release_quality = 1.0
	lab._pending_release_overdrive = 0.0
	if (
		lab._match_mode
		and lab._player_is_batting()
		and lab._match_state.phase == MatchState.Phase.PRE_PITCH
		and not lab._current_pitch_options().is_empty()
	):
		lab._selected_pitch_index = 0
		lab._pitch_target = lab.DEFAULT_TARGET
		lab._pitch_effort = 1.0
		lab._last_ai_pitch_index = 0
		lab._ai_pitch_preselected = true
		lab._awaiting_batter_confirm = false
		_begin_ai_delivery_cadence(lab, 7919)
		lab._status_label.text = (
			"%s flight reset safely. Pitcher preparing a center fallback." % pitch.display_name
		)
		lab._refresh_markers()
		lab._refresh_config()
		return
	lab._status_label.text = (
		"%s could not produce a valid flight. Adjust effort/target and retry." % pitch.display_name
	)
	lab._refresh_config()


static func set_batting_aim_from_screen(lab: PitchBatLab, screen_position: Vector2) -> bool:
	if lab._camera == null:
		return false
	var ray_origin: Vector3 = lab._camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = lab._camera.project_ray_normal(screen_position)
	if absf(ray_direction.z) <= 0.000001:
		return false
	var distance: float = (ContactResolver.CONTACT_PLANE_Z - ray_origin.z) / ray_direction.z
	if distance <= 0.0:
		return false
	var world_point: Vector3 = ray_origin + ray_direction * distance
	lab._batting_aim = Vector2(
		clampf(world_point.x, lab.BATTING_AIM_MIN_X, lab.BATTING_AIM_MAX_X),
		clampf(world_point.y, lab.BATTING_AIM_MIN_Y, lab.BATTING_AIM_MAX_Y)
	)
	lab._refresh_markers()
	return true


static func set_pitch_target_from_screen(lab: PitchBatLab, screen_position: Vector2) -> bool:
	if lab._camera == null:
		return false
	var ray_origin: Vector3 = lab._camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = lab._camera.project_ray_normal(screen_position)
	if absf(ray_direction.z) <= 0.000001:
		return false
	var distance: float = -ray_origin.z / ray_direction.z
	if distance <= 0.0:
		return false
	var world_point: Vector3 = ray_origin + ray_direction * distance
	lab._pitch_target = Vector2(
		clampf(world_point.x, lab.PITCH_AIM_MIN_X, lab.PITCH_AIM_MAX_X),
		clampf(world_point.y, lab.PITCH_AIM_MIN_Y, lab.PITCH_AIM_MAX_Y)
	)
	lab._refresh_markers()
	lab._refresh_config()
	return true


static func toggle_debug_pause(lab: PitchBatLab) -> void:
	lab._debug_paused = not lab._debug_paused
	lab.get_tree().paused = lab._debug_paused
	if lab._debug_paused:
		lab._status_before_pause = lab._status_label.text
		lab._status_label.text = "DEBUG PAUSED — P to resume"
	else:
		lab._status_label.text = lab._status_before_pause
	lab._refresh_config()


static func reset_debug_pause(lab: PitchBatLab) -> void:
	if not lab._debug_paused:
		return
	lab._debug_paused = false
	lab.get_tree().paused = false


static func toggle_match_mode(lab: PitchBatLab) -> void:
	reset_debug_pause(lab)
	if lab._match_mode:
		if not _can_suspend_match_for_lab(lab):
			lab._status_label.text = ("MECHANICS LAB\nAvailable before a Pitch, while play is stopped.")
			lab._refresh_config()
			return
		_suspend_match_for_lab(lab)
	else:
		_resume_suspended_match(lab)
	lab._apply_role_camera()
	lab._refresh_markers()
	lab._refresh_config()


static func _can_suspend_match_for_lab(lab: PitchBatLab) -> bool:
	return (
		lab._match_state != null
		and lab._match_state.phase == MatchState.Phase.PRE_PITCH
		and not lab._field_setup_active
		and not lab._pitching_staff_active
		and (lab._pitch_actor == null or not lab._pitch_actor.running)
		and not lab._ball_in_play_is_live()
		and (lab._release_controller == null or not lab._release_controller.active)
		and (
			lab._at_bat_cadence == null
			or lab._at_bat_cadence.state == AtBatCadenceController.State.IDLE
		)
		and (
			lab._match_presentation_director == null
			or not lab._match_presentation_director.blocks_gameplay()
		)
	)


static func _suspend_match_for_lab(lab: PitchBatLab) -> void:
	lab._match_suspend_snapshot = {
		"selected_pitch_index": lab._selected_pitch_index,
		"pitch_target": lab._pitch_target,
		"batting_aim": lab._batting_aim,
		"fatigue": lab._fatigue,
		"pitch_effort": lab._pitch_effort,
		"fielder_anchor_index": lab._fielder_anchor_index,
		"awaiting_batter_confirm": lab._awaiting_batter_confirm,
		"ai_pitch_preselected": lab._ai_pitch_preselected,
		"last_ai_pitch_index": lab._last_ai_pitch_index,
		"last_ai_awareness": lab._last_ai_awareness,
		"last_ai_read_text": lab._last_ai_read_text,
		"debug_overlay_visible": lab._debug_overlay_visible,
		"status_text": lab._status_label.text,
	}
	lab._match_mode = false
	lab._debug_overlay_visible = true
	lab._base_state = lab._debug_base_state
	lab._reset_lab()
	lab._status_label.text = "MECHANICS LAB\nF2 resumes the suspended match."


static func _resume_suspended_match(lab: PitchBatLab) -> void:
	cancel_release(lab)
	PitchBatLabSwingSupport.reset(lab)
	if lab._pitch_actor != null:
		lab._pitch_actor.reset_pitch()
	lab._cleanup_batted_ball()
	if lab._match_state == null or lab._match_suspend_snapshot.is_empty():
		lab._match_mode = true
		lab._start_new_match()
		return
	lab._match_mode = true
	lab._base_state = lab._match_state.bases
	lab._selected_pitch_index = int(lab._match_suspend_snapshot["selected_pitch_index"])
	lab._pitch_target = lab._match_suspend_snapshot["pitch_target"] as Vector2
	lab._batting_aim = lab._match_suspend_snapshot["batting_aim"] as Vector2
	lab._fatigue = float(lab._match_suspend_snapshot["fatigue"])
	lab._pitch_effort = float(lab._match_suspend_snapshot["pitch_effort"])
	lab._fielder_anchor_index = int(lab._match_suspend_snapshot["fielder_anchor_index"])
	lab._awaiting_batter_confirm = bool(lab._match_suspend_snapshot["awaiting_batter_confirm"])
	lab._ai_pitch_preselected = bool(lab._match_suspend_snapshot["ai_pitch_preselected"])
	lab._last_ai_pitch_index = int(lab._match_suspend_snapshot["last_ai_pitch_index"])
	lab._last_ai_awareness = float(lab._match_suspend_snapshot["last_ai_awareness"])
	lab._last_ai_read_text = String(lab._match_suspend_snapshot["last_ai_read_text"])
	lab._debug_overlay_visible = bool(lab._match_suspend_snapshot["debug_overlay_visible"])
	lab._status_label.text = String(lab._match_suspend_snapshot["status_text"])
	lab._match_suspend_snapshot.clear()
	lab._field_setup_active = false
	lab._pitching_staff_active = false
	lab._apply_defensive_assignment()


static func begin_pitch_release(lab: PitchBatLab) -> void:
	if (
		not lab._player_is_pitching()
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or lab._release_controller.active
		or lab._field_setup_active
		or lab._pitching_staff_active
	):
		return
	lab._release_controller.begin()
	lab._status_label.text = ""
	lab._refresh_config()


static func commit_pitch_release(lab: PitchBatLab) -> void:
	if not lab._release_controller.active or lab._match_state == null:
		return
	var pitcher_state: PlayerMatchState = lab._match_state.pitcher()
	var fatigue: float = maxf(pitcher_state.fatigue_ratio(), lab._fatigue)
	lab._pending_release_overdrive = lab._release_controller.overdrive_amount()
	lab._pending_release_quality = lab._release_controller.release(
		pitcher_state.definition.control, fatigue
	)
	lab._last_release_quality = lab._pending_release_quality
	lab._last_release_offset_seconds = (lab._release_controller.last_offset_seconds)
	lab._throw_pitch()


static func cancel_release(lab: PitchBatLab) -> void:
	if lab._release_controller != null:
		lab._release_controller.cancel()
	lab._pending_release_quality = 1.0
	lab._pending_release_overdrive = 0.0
	lab._last_release_offset_seconds = 0.0
	if lab._at_bat_cadence != null:
		lab._at_bat_cadence.stop()
	_reset_pitcher_telegraph(lab)


static func release_meter_text(lab: PitchBatLab) -> String:
	if lab._release_controller == null or not lab._release_controller.active:
		return ""
	var progress: float = lab._release_controller.meter_progress()
	var marker_distance: float = absf(progress - lab._release_controller.ideal_progress())
	var cue: String = "●" if marker_distance <= 0.055 else "○"
	if marker_distance <= 0.055:
		return "RELEASE  %s" % cue
	if progress > lab._release_controller.ideal_progress():
		return "OVERCOOK  %s" % cue
	return "HOLD  %s" % cue


static func start_record(
	lab: PitchBatLab,
	pitch: PitchDefinition,
	fatigue: float,
	execution_quality: float,
	play_seed: int,
	release_overdrive: float = 0.0
) -> void:
	var record: PlayRecord = PlayRecord.new()
	record.play_number = lab._throw_number
	record.pitch_id = pitch.id
	record.intended_target = lab._pitch_target
	record.effort = lab._pitch_effort
	record.fatigue = fatigue
	record.execution_quality = execution_quality
	record.release_offset_seconds = lab._last_release_offset_seconds
	record.release_overdrive = release_overdrive
	record.seed = play_seed
	if lab._match_mode and lab._match_state != null:
		record.inning = lab._match_state.inning
		record.top_half = lab._match_state.top_half
		record.balls_before = lab._match_state.balls
		record.strikes_before = lab._match_state.strikes
		record.outs_before = lab._match_state.outs
		record.batter_id = lab._match_state.batter().definition.id
		record.pitcher_id = lab._match_state.pitcher().definition.id
	lab._active_play_record = record


static func note_crossing(lab: PitchBatLab, point: Vector3, speed_mps: float) -> void:
	if lab._active_play_record == null:
		return
	lab._active_play_record.crossed_plate = true
	lab._active_play_record.crossing_point = Vector2(point.x, point.y)
	lab._active_play_record.plate_speed_mps = speed_mps


static func note_swing(
	lab: PitchBatLab, profile_id: StringName, aim_point: Vector2, result: ContactResult
) -> void:
	if lab._active_play_record == null:
		return
	lab._active_play_record.swing_profile_id = profile_id
	lab._active_play_record.swing_aim = aim_point
	lab._active_play_record.contact_outcome = result.outcome
	lab._active_play_record.contact_quality = result.quality
	lab._active_play_record.timing_error_m = result.timing_error_m
	lab._active_play_record.horizontal_error_m = result.horizontal_error_m
	lab._active_play_record.vertical_error_m = result.vertical_error_m
	lab._active_play_record.exit_speed_mps = result.exit_velocity.length()
	lab._active_play_record.launch_angle_degrees = result.launch_angle_degrees
	lab._active_play_record.spray_degrees = result.spray_degrees


static func note_first_ground(lab: PitchBatLab, position: Vector3) -> void:
	if lab._active_play_record == null or lab._active_play_record.has_first_ground:
		return
	lab._active_play_record.has_first_ground = true
	lab._active_play_record.first_ground_position = position


static func note_ball_play_outcome(
	lab: PitchBatLab,
	outcome: BallPlayOutcome,
	last_defender_touch: StringName,
	result_floor: BallPlayState.ResultFloor
) -> void:
	if lab._active_play_record == null:
		return
	lab._active_play_record.resolution_reason = outcome.reason
	lab._active_play_record.resolution_position = outcome.resolution_position
	lab._active_play_record.last_defender_touch = last_defender_touch
	lab._active_play_record.result_floor = int(result_floor)


static func record_clean_fielding_control(
	lab: PitchBatLab,
	defender_id: StringName,
	resolved_position: Vector3,
	ball_was_moving: bool
) -> void:
	var is_airborne: bool = not lab._ball_play_resolver.state.has_grounded
	if defender_id == &"pitcher":
		lab._ball_play_resolver.record_pitcher_clean_control(
			resolved_position, is_airborne, ball_was_moving
		)
	else:
		lab._ball_play_resolver.record_clean_control(
			defender_id, resolved_position, is_airborne, ball_was_moving
		)


static func finish_record(lab: PitchBatLab, result: StringName, runs_scored: int = 0) -> void:
	if lab._active_play_record == null:
		return
	lab._active_play_record.result = result
	lab._active_play_record.runs_scored = runs_scored
	lab._play_records.append(lab._active_play_record)
	lab._active_play_record = null


static func clear_records(lab: PitchBatLab) -> void:
	lab._active_play_record = null
	lab._play_records.clear()


static func dump_records(lab: PitchBatLab) -> void:
	var serialized: Array[Dictionary] = []
	for record in lab._play_records:
		serialized.append(record.to_dict())
	print("WIFFALTRO_PLAY_RECORDS ", JSON.stringify(serialized))
	if lab._status_label != null:
		lab._status_label.text = (
			"Printed %d deterministic play record(s) to Output." % serialized.size()
		)


static func measure_nominal_pitch(
	lab: PitchBatLab, base_parameters: PitchLaunchParameters, target_position: Vector3
) -> void:
	lab._last_nominal_release_speed_mps = base_parameters.velocity.length()
	var nominal: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
		base_parameters, target_position.z
	)
	var neutral: PitchLaunchParameters = base_parameters.copy()
	neutral.magnus_scale = 0.0
	neutral.perforation_force_scale = 0.0
	neutral.instability_strength = 0.0
	var neutral_crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
		neutral, target_position.z
	)
	if nominal.crossed and neutral_crossing.crossed:
		lab._last_movement_x_m = nominal.point.x - neutral_crossing.point.x
		lab._last_movement_y_m = nominal.point.y - neutral_crossing.point.y
	else:
		lab._last_movement_x_m = 0.0
		lab._last_movement_y_m = 0.0


static func _update_pitch_release(lab: PitchBatLab, delta_seconds: float) -> void:
	if lab._release_controller == null or not lab._release_controller.active:
		return
	if lab._release_controller.advance(delta_seconds):
		commit_pitch_release(lab)
	else:
		lab._refresh_config()


static func _update_at_bat_cadence(lab: PitchBatLab, delta_seconds: float) -> void:
	if lab._at_bat_cadence == null:
		return
	var event: AtBatCadenceController.Event = lab._at_bat_cadence.advance(delta_seconds)
	match event:
		AtBatCadenceController.Event.THROW_PITCH:
			_reset_pitcher_telegraph(lab)
			lab._throw_pitch()
		AtBatCadenceController.Event.CONTINUE_PLAY:
			lab._handle_match_advance()
		_:
			pass


static func _update_pitcher_telegraph(lab: PitchBatLab) -> void:
	if lab._pitcher_marker == null or lab._match_state == null:
		return
	var progress: float = -1.0
	var ai_delivery: bool = false
	if (
		lab._at_bat_cadence != null
		and lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY
	):
		progress = lab._at_bat_cadence.delivery_progress()
		ai_delivery = true
	elif (
		lab._player_is_pitching()
		and lab._release_controller != null
		and lab._release_controller.active
	):
		progress = lab._release_controller.meter_progress()
	if progress < 0.0:
		return
	var lift: float = sin(progress * PI)
	var selected_pitch: PitchDefinition = lab._selected_pitch()
	var slot_amount: float = 0.08
	var sidearm: bool = false
	if (
		selected_pitch != null
		and selected_pitch.delivery_profile != null
		and selected_pitch.delivery_profile.delivery >= DeliveryProfileDefinition.Delivery.SIDEARM
	):
		slot_amount = 0.22
		sidearm = true
	var handedness: float = (
		-1.0
		if (lab._match_state.pitcher().definition.throws == PlayerDefinition.Handedness.LEFT)
		else 1.0
	)
	lab._pitcher_marker.position = (
		lab.MOUND_ORIGIN
		+ Vector3(
			handedness * slot_amount * lift, 0.16 * lift, -0.18 * smoothstep(0.55, 1.0, progress)
		)
	)
	lab._pitcher_marker.rotation.z = handedness * slot_amount * lift
	if lab._pitcher_avatar != null:
		lab._pitcher_avatar.set_pitch_delivery_progress(progress, sidearm)
	if ai_delivery and lab._action_label != null:
		lab._action_label.text = lab._at_bat_cadence.delivery_cue()


static func _reset_pitcher_telegraph(lab: PitchBatLab) -> void:
	if lab._pitcher_marker == null:
		return
	lab._pitcher_marker.position = lab.MOUND_ORIGIN
	lab._pitcher_marker.rotation = Vector3.ZERO
	if lab._pitcher_avatar != null:
		lab._pitcher_avatar.reset_pose()


static func _update_continuous_input(lab: PitchBatLab, delta_seconds: float) -> void:
	var amount: float = AIM_SPEED_MPS * delta_seconds
	if lab._match_mode:
		if (
			lab._player_is_pitching()
			and lab._match_state.phase == MatchState.Phase.PRE_PITCH
			and not lab._release_controller.active
		):
			_apply_pitch_aim(lab, amount)
		elif lab._player_is_batting() and not lab._swing_consumed:
			_apply_bat_aim(lab, amount)
		return
	_apply_pitch_aim(lab, amount)
	_apply_bat_aim(lab, amount)


static func _apply_pitch_aim(lab: PitchBatLab, amount: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"pitch_aim_left", &"pitch_aim_right", &"pitch_aim_down", &"pitch_aim_up"
	)
	if direction.length_squared() > 0.0001:
		lab._adjust_pitch_target(direction * amount)


static func _apply_bat_aim(lab: PitchBatLab, amount: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"bat_aim_left", &"bat_aim_right", &"bat_aim_down", &"bat_aim_up"
	)
	if direction.length_squared() > 0.0001:
		lab._adjust_batting_aim(direction * amount)
