extends Node

var _failures: int = 0
var _fixture_number: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _test_paused_release()
	await _test_paused_mode_switch()
	await _test_setup_input()
	await _test_lab_return()
	await _test_batting(&"swing.contact")
	await _test_batting(&"swing.power")
	await _test_batting(&"swing.contact", true)
	await _test_early_swing()
	if _failures == 0:
		print("Wiffaltro player flow checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _new_lab(pitching: bool = false) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	_fixture_number += 1
	# Synthetic input fixtures must never become human F3 balance samples.
	lab._record_export.path = "user://player-flow-test-%d-%d.json" % [
		OS.get_process_id(), _fixture_number
	]
	_key(lab, KEY_ESCAPE)
	if pitching:
		lab._match_state.top_half = false
		lab._awaiting_batter_confirm = false
		lab._apply_defensive_assignment()
		lab._apply_role_camera()
		lab._camera_director.snap(lab._camera)
	return lab


func _free_lab(lab: PitchBatLab) -> void:
	var path: String = lab._record_export.path
	lab.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(path)


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame


func _key(lab: PitchBatLab, keycode: Key, pressed: bool = true) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	PitchBatLabInput.handle(lab, event)


func _mouse(lab: PitchBatLab, button: MouseButton, pressed: bool, point: Vector3) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = lab._camera.unproject_position(point)
	PitchBatLabInput.handle(lab, event)


func _release_input(lab: PitchBatLab, kind: int, pressed: bool) -> void:
	match kind:
		0:
			_key(lab, KEY_SPACE, pressed)
		1:
			_mouse(lab, MOUSE_BUTTON_LEFT, pressed, Vector3(0.0, 1.05, 0.0))
		2:
			var event: InputEventJoypadButton = InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_A
			event.pressed = pressed
			PitchBatLabInput.handle(lab, event)


func _test_paused_release() -> void:
	for kind in range(3):
		var lab: PitchBatLab = _new_lab(true)
		var stamina: float = lab._match_state.pitcher().stamina_remaining
		_release_input(lab, kind, true)
		_check(lab._release_controller.active, "release input must begin the meter")
		await _frames(8)
		_key(lab, KEY_P)
		var elapsed: float = lab._release_controller.elapsed_seconds
		await _frames(6)
		_check(lab._release_controller.elapsed_seconds == elapsed, "paused meter must freeze")
		_release_input(lab, kind, false)
		_check(not lab._release_controller.active, "release while paused must cancel delivery")
		_key(lab, KEY_P)
		await _frames(45)
		_check(lab._throw_number == 0, "resume must not throw an abandoned delivery")
		_check(lab._match_state.pitcher().stamina_remaining == stamina, "cancel must cost no stamina")
		_check(lab._play_records.is_empty(), "cancel must not finish a play record")
		_release_input(lab, kind, true)
		await _frames(27)
		_release_input(lab, kind, false)
		_check(lab._pitch_actor.running and lab._match_state.pitcher().pitch_count == 1,
			"a fresh delivery after cancellation must launch exactly once")
		await _free_lab(lab)


func _test_paused_mode_switch() -> void:
	var lab: PitchBatLab = _new_lab(true)
	_key(lab, KEY_SPACE)
	await _frames(27)
	_key(lab, KEY_SPACE, false)
	_check(lab._pitch_actor.running, "fixture must launch a live pitch")
	_key(lab, KEY_P)
	_key(lab, KEY_F2)
	_check(lab._debug_paused and get_tree().paused, "rejected Lab entry must preserve pause")
	_check(lab._match_mode, "live pitch must remain in Match mode")
	var elapsed: float = lab._pitch_actor.state.elapsed_time
	await _frames(6)
	_check(lab._pitch_actor.state.elapsed_time == elapsed, "rejected mode switch must freeze flight")
	if lab._debug_paused:
		_key(lab, KEY_P)
	await _free_lab(lab)


func _test_setup_input() -> void:
	var lab: PitchBatLab = _new_lab(true)
	for staff in [true, false]:
		lab._pitch_target = Vector2(0.31, 1.42)
		var target: Vector2 = lab._pitch_target
		if staff:
			lab._toggle_pitching_staff()
		else:
			lab._toggle_field_setup()
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = lab._camera.unproject_position(Vector3(-0.2, 0.6, 0.0))
		PitchBatLabInput.handle(lab, motion)
		_mouse(lab, MOUSE_BUTTON_LEFT, true, Vector3(-0.2, 0.6, 0.0))
		_mouse(lab, MOUSE_BUTTON_LEFT, false, Vector3(-0.2, 0.6, 0.0))
		_check(lab._pitch_target == target, "setup pointer input must preserve the pitch target")
		Input.action_press(&"pitch_aim_right")
		await _frames(6)
		Input.action_release(&"pitch_aim_right")
		_check(lab._pitch_target == target, "setup stick/key input must preserve the pitch target")
		_key(lab, KEY_SPACE)
		_key(lab, KEY_SPACE, false)
		_check(not lab._release_controller.active and lab._throw_number == 0,
			"setup input must not begin a delivery")
		lab._toggle_display_menu()
		_key(lab, KEY_ESCAPE)
		_check(not lab._display_menu_open, "Escape must close the display menu first")
		_check(lab._pitching_staff_active or lab._field_setup_active,
			"closing display options must preserve the setup screen underneath")
		_key(lab, KEY_ESCAPE)
		_check(not lab._pitching_staff_active and not lab._field_setup_active,
			"Escape must return from defensive setup")
		_check(lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING,
			"leaving setup must restore the pitching camera")
		# Recover after an assertion so each setup fixture is independent.
		lab._display_menu_open = false
		lab._pitching_staff_active = false
		lab._field_setup_active = false
		lab._apply_role_camera()
	await _free_lab(lab)


func _test_lab_return() -> void:
	var lab: PitchBatLab = _new_lab(true)
	var match_state: MatchState = lab._match_state
	match_state.balls = 2
	match_state.strikes = 1
	lab._pitch_target = Vector2(0.31, 1.42)
	lab._status_label.text = "Ready marker"
	_key(lab, KEY_P)
	_key(lab, KEY_F2)
	_check(not lab._match_mode and not get_tree().paused, "safe Lab entry must work from pause")
	_key(lab, KEY_SPACE)
	_check(lab._pitch_actor.running, "Lab fixture must have a live pitch to discard on return")
	_key(lab, KEY_F2)
	_check(lab._match_mode and lab._match_state == match_state, "Lab return must restore the match")
	_check(match_state.balls == 2 and match_state.strikes == 1, "Lab return must preserve count")
	_check(lab._pitch_target == Vector2(0.31, 1.42), "Lab return must preserve pitch plan")
	_check(lab._status_label.text == "Ready marker", "Lab return must not restore a stale pause cue")
	_check(not lab._pitch_actor.running, "Lab flight must not leak into resumed match")
	await _free_lab(lab)


func _start_batting_pitch(lab: PitchBatLab) -> void:
	_key(lab, KEY_SPACE)
	_check(not lab._swing_consumed, "batter confirmation must not also swing")
	# A known center pitch isolates player input/physics from AI plan selection.
	# Timing/aim below use full trajectory knowledge only in this test driver.
	lab._selected_pitch_index = 0
	lab._pitch_target = lab.DEFAULT_TARGET
	lab._pitch_effort = 1.0
	lab._ai_pitch_preselected = true
	for frame in range(240):
		await get_tree().physics_frame
		if lab._pitch_actor.running:
			return
	_check(false, "batter confirmation must lead to an actual pitch")


func _test_batting(profile_id: StringName, reset_live: bool = false) -> void:
	var lab: PitchBatLab = _new_lab()
	await _start_batting_pitch(lab)
	if not lab._pitch_actor.running:
		await _free_lab(lab)
		return
	var profile: SwingProfileDefinition = ContentDB.get_swing(profile_id)
	var crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
		lab._pitch_actor.parameters, ContactResolver.CONTACT_PLANE_Z
	)
	var swing_time: float = crossing.elapsed_seconds - profile.sweet_spot_seconds
	for frame in range(180):
		if not lab._pitch_actor.running or lab._pitch_actor.state.elapsed_time >= swing_time:
			break
		await get_tree().physics_frame
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = lab._camera.unproject_position(crossing.point)
	PitchBatLabInput.handle(lab, motion)
	if profile_id == &"swing.contact":
		_key(lab, KEY_Z)
	else:
		_mouse(lab, MOUSE_BUTTON_RIGHT, true, crossing.point)
	var intent: SwingIntent = lab._swing_tracker.intent
	_key(lab, KEY_X)
	_check(intent != null and lab._swing_tracker.intent == intent,
		"duplicate swing input must not replace the committed swing")
	var saw_live_ball: bool = false
	for frame in range(900):
		await get_tree().physics_frame
		if lab._ball_in_play_is_live() and not saw_live_ball:
			saw_live_ball = true
			_check(lab._match_state.phase == MatchState.Phase.BALL_IN_PLAY,
				"player contact must enter actual ball-in-play")
			_check(lab._camera_director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY,
				"player contact must select the live-ball camera")
			_key(lab, KEY_P)
			var position_before_pause: Vector3 = lab._batted_ball.global_position
			await _frames(6)
			_check(lab._batted_ball.global_position == position_before_pause,
				"pause must freeze the physical batted ball")
			_key(lab, KEY_P)
			if reset_live:
				await _check_live_reset(lab)
				break
		if not lab._play_records.is_empty():
			break
	_check(saw_live_ball, "timed " + String(profile_id) + " must produce a physical ball")
	if not reset_live:
		_check(lab._play_records.size() == 1, "player hit must finish exactly one record")
		if lab._play_records.size() == 1:
			var record: PlayRecord = lab._play_records[0]
			_check(record.swing_profile_id == profile_id and record.exit_speed_mps > 0.0,
				"completed record must retain player swing and actual exit speed")
			_check(record.result != &"pending", "player hit must resolve")
			var hold_time: float = lab._at_bat_cadence.elapsed_seconds
			_key(lab, KEY_SPACE)
			_mouse(lab, MOUSE_BUTTON_LEFT, true, crossing.point)
			_check(lab._at_bat_cadence.elapsed_seconds == hold_time,
				"extra clicks must not skip the readable result hold")
			for frame in range(240):
				await get_tree().physics_frame
				if lab._awaiting_batter_confirm:
					break
			_check(lab._awaiting_batter_confirm and lab._throw_number == 1,
				"next batter must wait for readiness after the automatic hold")
	await _free_lab(lab)


func _check_live_reset(lab: PitchBatLab) -> void:
	var old_export_path: String = lab._record_export.path
	_key(lab, KEY_R)
	# A reset rotates the exporter; keep any late callback in the same test file.
	lab._record_export.path = old_export_path
	_check(lab._batted_ball == null and not lab._pitch_actor.running,
		"restart must remove both live actors")
	_check(lab._match_state.phase == MatchState.Phase.PRE_PITCH and lab._throw_number == 0,
		"restart must create a fresh match")
	await _frames(120)
	_check(lab._play_records.is_empty() and lab._throw_number == 0,
		"old ball callbacks must not score or pitch into the restarted match")
	_check(lab._match_state.outs == 0 and lab._match_state.plate_appearance_number == 1,
		"old ball callbacks must not advance the new batter")


func _test_early_swing() -> void:
	var lab: PitchBatLab = _new_lab()
	await _start_batting_pitch(lab)
	_key(lab, KEY_Z)
	for frame in range(180):
		await get_tree().physics_frame
		if not lab._play_records.is_empty():
			break
	_check(lab._play_records.size() == 1 and lab._match_state.strikes == 1,
		"early swing must finish once as a swinging strike")
	for frame in range(360):
		await get_tree().physics_frame
		if lab._throw_number == 2:
			break
	_check(lab._throw_number == 2 and not lab._awaiting_batter_confirm,
		"same batter must receive the next pitch automatically after a miss")
	await _free_lab(lab)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
