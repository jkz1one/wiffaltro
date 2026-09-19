class_name PitchBatLabInput
extends RefCounted

static func handle(lab: PitchBatLab, event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_F1:
		lab._toggle_debug_overlay()
		lab.get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_F2:
		lab._toggle_match_mode()
		lab.get_viewport().set_input_as_handled()
		return

	var handled: bool
	if lab._match_mode:
		handled = _handle_match_key(lab, key_event.keycode)
	else:
		handled = _handle_lab_key(lab, key_event.keycode)
	if handled:
		lab.get_viewport().set_input_as_handled()

static func _handle_match_key(lab: PitchBatLab, keycode: Key) -> bool:
	if keycode >= KEY_1 and keycode <= KEY_9:
		if lab._player_is_pitching():
			var requested_index: int = int(keycode - KEY_1)
			var options: Array[PitchDefinition] = lab._current_pitch_options()
			if requested_index < options.size():
				lab._selected_pitch_index = requested_index
				lab._refresh_config()
		return true

	match keycode:
		KEY_SPACE:
			lab._handle_match_advance()
		KEY_R:
			lab._start_new_match()
		KEY_V:
			lab._cycle_camera()
		KEY_C:
			lab._cycle_fielder_anchor()
		KEY_Q:
			lab._cycle_pitcher(-1)
		KEY_E:
			lab._cycle_pitcher(1)
		KEY_F:
			lab._cycle_primary_fielder()
		KEY_MINUS:
			if lab._player_is_pitching():
				lab._adjust_pitch_effort(-0.05)
		KEY_EQUAL:
			if lab._player_is_pitching():
				lab._adjust_pitch_effort(0.05)
		KEY_LEFT:
			if lab._player_is_pitching():
				lab._adjust_pitch_target(Vector2(-lab.AIM_STEP_M, 0.0))
		KEY_RIGHT:
			if lab._player_is_pitching():
				lab._adjust_pitch_target(Vector2(lab.AIM_STEP_M, 0.0))
		KEY_UP:
			if lab._player_is_pitching():
				lab._adjust_pitch_target(Vector2(0.0, lab.AIM_STEP_M))
		KEY_DOWN:
			if lab._player_is_pitching():
				lab._adjust_pitch_target(Vector2(0.0, -lab.AIM_STEP_M))
		KEY_A:
			if lab._player_is_batting():
				lab._adjust_batting_aim(Vector2(-lab.AIM_STEP_M, 0.0))
		KEY_D:
			if lab._player_is_batting():
				lab._adjust_batting_aim(Vector2(lab.AIM_STEP_M, 0.0))
		KEY_W:
			if lab._player_is_batting():
				lab._adjust_batting_aim(Vector2(0.0, lab.AIM_STEP_M))
		KEY_S:
			if lab._player_is_batting():
				lab._adjust_batting_aim(Vector2(0.0, -lab.AIM_STEP_M))
		KEY_BRACKETLEFT:
			lab._fatigue = clampf(lab._fatigue - 0.10, 0.0, 1.0)
			lab._refresh_config()
		KEY_BRACKETRIGHT:
			lab._fatigue = clampf(lab._fatigue + 0.10, 0.0, 1.0)
			lab._refresh_config()
		KEY_Z:
			if lab._player_is_batting():
				lab._attempt_swing(lab.CONTACT_SWING_ID)
		KEY_X:
			if lab._player_is_batting():
				lab._attempt_swing(lab.POWER_SWING_ID)
		_:
			return false
	return true

static func _handle_lab_key(lab: PitchBatLab, keycode: Key) -> bool:
	if keycode >= KEY_1 and keycode <= KEY_9:
		var requested_index: int = int(keycode - KEY_1)
		if requested_index < lab.PITCH_IDS.size():
			lab._selected_pitch_index = requested_index
			lab._refresh_config()
		return true

	match keycode:
		KEY_SPACE:
			lab._throw_pitch()
		KEY_R:
			lab._reset_lab()
		KEY_V:
			lab._cycle_camera()
		KEY_C:
			lab._cycle_fielder_anchor()
		KEY_G:
			lab._cycle_base_preset()
		KEY_B:
			MatchLabSupport.launch_debug_batted_ball(lab)
		KEY_MINUS:
			lab._adjust_pitch_effort(-0.05)
		KEY_EQUAL:
			lab._adjust_pitch_effort(0.05)
		KEY_LEFT:
			lab._adjust_pitch_target(Vector2(-lab.AIM_STEP_M, 0.0))
		KEY_RIGHT:
			lab._adjust_pitch_target(Vector2(lab.AIM_STEP_M, 0.0))
		KEY_UP:
			lab._adjust_pitch_target(Vector2(0.0, lab.AIM_STEP_M))
		KEY_DOWN:
			lab._adjust_pitch_target(Vector2(0.0, -lab.AIM_STEP_M))
		KEY_A:
			lab._adjust_batting_aim(Vector2(-lab.AIM_STEP_M, 0.0))
		KEY_D:
			lab._adjust_batting_aim(Vector2(lab.AIM_STEP_M, 0.0))
		KEY_W:
			lab._adjust_batting_aim(Vector2(0.0, lab.AIM_STEP_M))
		KEY_S:
			lab._adjust_batting_aim(Vector2(0.0, -lab.AIM_STEP_M))
		KEY_COMMA:
			lab._execution_quality = clampf(
				lab._execution_quality - 0.10,
				0.0,
				1.0
			)
			lab._refresh_config()
		KEY_PERIOD:
			lab._execution_quality = clampf(
				lab._execution_quality + 0.10,
				0.0,
				1.0
			)
			lab._refresh_config()
		KEY_BRACKETLEFT:
			lab._fatigue = clampf(lab._fatigue - 0.10, 0.0, 1.0)
			lab._refresh_config()
		KEY_BRACKETRIGHT:
			lab._fatigue = clampf(lab._fatigue + 0.10, 0.0, 1.0)
			lab._refresh_config()
		KEY_Z:
			lab._attempt_swing(lab.CONTACT_SWING_ID)
		KEY_X:
			lab._attempt_swing(lab.POWER_SWING_ID)
		_:
			return false
	return true
