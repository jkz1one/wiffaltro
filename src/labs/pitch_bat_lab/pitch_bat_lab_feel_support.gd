class_name PitchBatLabFeelSupport
extends RefCounted

const AIM_SPEED_MPS: float = 0.82

static func initialize(lab: PitchBatLab) -> void:
	lab._release_controller = PitchReleaseController.new()
	if lab._camera_director == null:
		lab._camera_director = MatchCameraDirector.new()
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
	lab._camera_director.snap(lab._camera)

static func update(lab: PitchBatLab, delta_seconds: float) -> void:
	_update_continuous_input(lab, delta_seconds)
	_update_pitch_release(lab, delta_seconds)
	var ball_live: bool = lab._ball_in_play_is_live()
	var ball_position: Vector3 = (
		lab._batted_ball.global_position
		if lab._batted_ball != null
		else Vector3.ZERO
	)
	lab._camera_director.update(
		lab._camera,
		delta_seconds,
		ball_live,
		ball_position
	)

static func begin_pitch_release(lab: PitchBatLab) -> void:
	if (
		not lab._player_is_pitching()
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or lab._release_controller.active
	):
		return
	lab._release_controller.begin()
	lab._status_label.text = "DELIVERY — release at the center mark"
	lab._refresh_config()

static func commit_pitch_release(lab: PitchBatLab) -> void:
	if not lab._release_controller.active or lab._match_state == null:
		return
	var pitcher_state: PlayerMatchState = lab._match_state.pitcher()
	var fatigue: float = maxf(
		pitcher_state.fatigue_ratio(),
		lab._fatigue
	)
	lab._pending_release_quality = lab._release_controller.release(
		pitcher_state.definition.control,
		fatigue
	)
	lab._last_release_quality = lab._pending_release_quality
	lab._last_release_offset_seconds = (
		lab._release_controller.last_offset_seconds
	)
	lab._throw_pitch()

static func cancel_release(lab: PitchBatLab) -> void:
	if lab._release_controller != null:
		lab._release_controller.cancel()
	lab._pending_release_quality = 1.0
	lab._last_release_offset_seconds = 0.0

static func release_meter_text(lab: PitchBatLab) -> String:
	if lab._release_controller == null or not lab._release_controller.active:
		return ""
	var progress: float = lab._release_controller.meter_progress()
	var marker_distance: float = absf(
		progress - lab._release_controller.ideal_progress()
	)
	var cue: String = "●" if marker_distance <= 0.055 else "○"
	return "RELEASE %s %3.0f%%   ideal at %3.0f%%" % [
		cue,
		progress * 100.0,
		lab._release_controller.ideal_progress() * 100.0,
	]

static func start_record(
	lab: PitchBatLab,
	pitch: PitchDefinition,
	fatigue: float,
	execution_quality: float,
	seed: int
) -> void:
	var record: PlayRecord = PlayRecord.new()
	record.play_number = lab._throw_number
	record.pitch_id = pitch.id
	record.intended_target = lab._pitch_target
	record.effort = lab._pitch_effort
	record.fatigue = fatigue
	record.execution_quality = execution_quality
	record.release_offset_seconds = lab._last_release_offset_seconds
	record.seed = seed
	if lab._match_mode and lab._match_state != null:
		record.inning = lab._match_state.inning
		record.top_half = lab._match_state.top_half
		record.balls_before = lab._match_state.balls
		record.strikes_before = lab._match_state.strikes
		record.outs_before = lab._match_state.outs
		record.batter_id = lab._match_state.batter().definition.id
		record.pitcher_id = lab._match_state.pitcher().definition.id
	lab._active_play_record = record

static func note_crossing(
	lab: PitchBatLab,
	point: Vector3,
	speed_mps: float
) -> void:
	if lab._active_play_record == null:
		return
	lab._active_play_record.crossed_plate = true
	lab._active_play_record.crossing_point = Vector2(point.x, point.y)
	lab._active_play_record.plate_speed_mps = speed_mps

static func note_swing(
	lab: PitchBatLab,
	profile_id: StringName,
	aim_point: Vector2,
	result: ContactResult
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

static func finish_record(
	lab: PitchBatLab,
	result: StringName,
	runs_scored: int = 0
) -> void:
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
			"Printed %d deterministic play record(s) to Output."
			% serialized.size()
		)

static func measure_nominal_pitch(
	lab: PitchBatLab,
	base_parameters: PitchLaunchParameters,
	target_position: Vector3
) -> void:
	lab._last_nominal_release_speed_mps = base_parameters.velocity.length()
	var nominal: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(base_parameters, target_position.z)
	)
	var neutral: PitchLaunchParameters = base_parameters.copy()
	neutral.magnus_scale = 0.0
	neutral.perforation_force_scale = 0.0
	neutral.instability_strength = 0.0
	var neutral_crossing: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(neutral, target_position.z)
	)
	if nominal.crossed and neutral_crossing.crossed:
		lab._last_movement_x_m = nominal.point.x - neutral_crossing.point.x
		lab._last_movement_y_m = nominal.point.y - neutral_crossing.point.y
	else:
		lab._last_movement_x_m = 0.0
		lab._last_movement_y_m = 0.0

static func _update_pitch_release(
	lab: PitchBatLab,
	delta_seconds: float
) -> void:
	if lab._release_controller == null or not lab._release_controller.active:
		return
	if lab._release_controller.advance(delta_seconds):
		commit_pitch_release(lab)
	else:
		lab._refresh_config()

static func _update_continuous_input(
	lab: PitchBatLab,
	delta_seconds: float
) -> void:
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
		&"pitch_aim_left",
		&"pitch_aim_right",
		&"pitch_aim_down",
		&"pitch_aim_up"
	)
	if direction.length_squared() > 0.0001:
		lab._adjust_pitch_target(direction * amount)

static func _apply_bat_aim(lab: PitchBatLab, amount: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"bat_aim_left",
		&"bat_aim_right",
		&"bat_aim_down",
		&"bat_aim_up"
	)
	if direction.length_squared() > 0.0001:
		lab._adjust_batting_aim(direction * amount)
