class_name PitchBatLabInput
extends RefCounted

static func handle(lab: PitchBatLab, event: InputEvent) -> void:
	if event is InputEventKey:
		var debug_key: InputEventKey = event as InputEventKey
		if (
			debug_key.pressed
			and not debug_key.echo
			and _handle_debug_key(lab, debug_key.keycode)
		):
			lab.get_viewport().set_input_as_handled()
			return
	if lab._debug_paused:
		lab.get_viewport().set_input_as_handled()
		return
	if (
		lab._match_presentation_director != null
		and lab._match_presentation_director.blocks_gameplay()
	):
		if event is InputEventKey:
			var presentation_key: InputEventKey = event as InputEventKey
			if (
				presentation_key.pressed
				and not presentation_key.echo
				and presentation_key.keycode == KEY_R
				and lab._match_presentation_director.mode
				== MatchPresentationDirector.Mode.OUTRO_HOLD
			):
				lab._start_new_match()
			elif (
				presentation_key.pressed
				and not presentation_key.echo
				and (
					presentation_key.keycode == KEY_SPACE
					or presentation_key.keycode == KEY_ESCAPE
				)
			):
				PitchBatLabFeelSupport.skip_match_presentation(lab)
		elif event is InputEventMouseButton:
			var presentation_click: InputEventMouseButton = (
				event as InputEventMouseButton
			)
			if presentation_click.pressed:
				PitchBatLabFeelSupport.skip_match_presentation(lab)
		elif event.is_action_pressed(&"match_advance", false, true):
			PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab.get_viewport().set_input_as_handled()
		return
	if _handle_pointer_event(lab, event):
		lab.get_viewport().set_input_as_handled()
		return
	if _handle_action_event(lab, event):
		lab.get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var handled: bool
	if lab._match_mode:
		handled = _handle_match_key(lab, key_event.keycode)
	else:
		handled = _handle_lab_key(lab, key_event.keycode)
	if handled:
		lab.get_viewport().set_input_as_handled()

static func _handle_pointer_event(
	lab: PitchBatLab,
	event: InputEvent
) -> bool:
	if lab._match_mode and event is InputEventMouseButton:
		var advance_click: InputEventMouseButton = event as InputEventMouseButton
		if (
			advance_click.pressed
			and lab._match_state != null
			and (
				lab._match_state.phase == MatchState.Phase.PLAY_DEAD
				or lab._match_state.phase == MatchState.Phase.INNING_TRANSITION
				or lab._match_state.phase == MatchState.Phase.GAME_END
			)
		):
			return true
	if lab._match_mode and lab._player_is_pitching():
		if lab._field_setup_active:
			return false
		if (
			lab._match_state == null
			or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		):
			return false
		if event is InputEventMouseMotion:
			if lab._release_controller.active:
				return true
			var pitch_motion: InputEventMouseMotion = event as InputEventMouseMotion
			return PitchBatLabFeelSupport.set_pitch_target_from_screen(
				lab,
				pitch_motion.position
			)
		if event is InputEventMouseButton:
			var pitch_click: InputEventMouseButton = event as InputEventMouseButton
			if pitch_click.button_index != MOUSE_BUTTON_LEFT:
				return false
			if pitch_click.pressed:
				if not PitchBatLabFeelSupport.set_pitch_target_from_screen(
					lab,
					pitch_click.position
				):
					return false
				PitchBatLabFeelSupport.begin_pitch_release(lab)
				return true
			if lab._release_controller.active:
				PitchBatLabFeelSupport.commit_pitch_release(lab)
				return true
		return false
	if lab._match_mode and lab._player_is_batting() and lab._awaiting_batter_confirm:
		if event is InputEventMouseButton:
			var ready_click: InputEventMouseButton = event as InputEventMouseButton
			if ready_click.pressed and ready_click.button_index == MOUSE_BUTTON_LEFT:
				PitchBatLabFeelSupport.confirm_batter_ready(lab)
			return true
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		return PitchBatLabFeelSupport.set_batting_aim_from_screen(
			lab,
			motion.position
		)
	if not event is InputEventMouseButton:
		return false
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_button.pressed:
		return false
	var profile_id: StringName
	match mouse_button.button_index:
		MOUSE_BUTTON_LEFT:
			profile_id = lab.CONTACT_SWING_ID
		MOUSE_BUTTON_RIGHT:
			profile_id = lab.POWER_SWING_ID
		_:
			return false
	if not PitchBatLabFeelSupport.set_batting_aim_from_screen(
		lab,
		mouse_button.position
	):
		return false
	lab._attempt_swing(profile_id)
	return true

static func _handle_action_event(
	lab: PitchBatLab,
	event: InputEvent
) -> bool:
	if (
		lab._match_mode
		and lab._player_is_batting()
		and lab._awaiting_batter_confirm
		and (
			event.is_action_pressed(&"match_advance", false, true)
			or event.is_action_pressed(&"swing_contact", false, true)
		)
	):
		PitchBatLabFeelSupport.confirm_batter_ready(lab)
		return true
	if event.is_action_pressed(&"swing_contact", false, true):
		if not lab._match_mode or lab._player_is_batting():
			lab._attempt_swing(lab.CONTACT_SWING_ID)
			return true
	if event.is_action_pressed(&"swing_power", false, true):
		if not lab._match_mode or lab._player_is_batting():
			lab._attempt_swing(lab.POWER_SWING_ID)
			return true
	if event.is_action_pressed(&"pitch_release", false, true):
		if (
			lab._match_mode
			and lab._player_is_pitching()
			and lab._match_state.phase == MatchState.Phase.PRE_PITCH
		):
			PitchBatLabFeelSupport.begin_pitch_release(lab)
			return true
	if event.is_action_pressed(&"match_advance", false, true):
		if not lab._match_mode:
			lab._throw_pitch()
		return true
	if event.is_action_released(&"pitch_release", true):
		if lab._match_mode and lab._player_is_pitching():
			PitchBatLabFeelSupport.commit_pitch_release(lab)
		return true
	return false

static func _handle_debug_key(lab: PitchBatLab, keycode: Key) -> bool:
	match keycode:
		KEY_F1:
			lab._toggle_debug_overlay()
		KEY_F2:
			lab._toggle_match_mode()
		KEY_F3:
			PitchBatLabFeelSupport.dump_records(lab)
		KEY_P:
			PitchBatLabFeelSupport.toggle_debug_pause(lab)
		_:
			return false
	return true

static func _handle_match_key(lab: PitchBatLab, keycode: Key) -> bool:
	if keycode >= KEY_1 and keycode <= KEY_9:
		if MatchLabSupport.can_edit_pitch_plan(lab):
			var requested_index: int = int(keycode - KEY_1)
			var options: Array[PitchDefinition] = lab._current_pitch_options()
			if requested_index < options.size():
				lab._selected_pitch_index = requested_index
				lab._refresh_config()
		return true

	match keycode:
		KEY_R:
			lab._start_new_match()
		KEY_V:
			lab._cycle_camera()
		KEY_C:
			lab._cycle_fielder_anchor()
		KEY_Q:
			MatchLabSupport.cycle_pitcher(lab, -1)
		KEY_E:
			MatchLabSupport.cycle_pitcher(lab, 1)
		KEY_F:
			MatchLabSupport.cycle_primary_fielder(lab)
		KEY_MINUS:
			if MatchLabSupport.can_edit_pitch_plan(lab):
				lab._adjust_pitch_effort(-0.05)
		KEY_EQUAL:
			if MatchLabSupport.can_edit_pitch_plan(lab):
				lab._adjust_pitch_effort(0.05)
		KEY_BRACKETLEFT:
			lab._fatigue = clampf(lab._fatigue - 0.10, 0.0, 1.0)
			lab._refresh_config()
		KEY_BRACKETRIGHT:
			lab._fatigue = clampf(lab._fatigue + 0.10, 0.0, 1.0)
			lab._refresh_config()
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
		_:
			return false
	return true
