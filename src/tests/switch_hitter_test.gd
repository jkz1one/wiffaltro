extends Node

var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PitchBatLabSettings.path = "user://switch-hitter-settings-%d.cfg" % OS.get_process_id()
	for id in [&"player.tess_vale", &"player.val_morgan"]:
		for left in [false, true]:
			await _test_side(id, left)
	DirAccess.remove_absolute(PitchBatLabSettings.path)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro switch hitter checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _test_side(id: StringName, left: bool) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab._record_export.path = "user://switch-hitter-record-%d.json" % OS.get_process_id()
	var batter: PlayerMatchState = lab._match_state.batter()
	batter.definition = ContentDB.get_player(id)
	batter.batting_hand_override = int(left)
	var throwing_hand: int = batter.definition.throws
	var controls: MatchRosterControls = lab.find_child("RosterControls", true, false)
	_key(lab, KEY_B)
	_check(batter.bats_left() == left, "intro must not permit switching")
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.sync_players(lab)
	await get_tree().process_frame
	for anchor in range(3):
		lab._hud_anchor_index = anchor
		lab._refresh_config()
		controls._process(0.0)
		var button: Rect2 = controls._switch.get_global_rect()
		_check(controls._switch.visible and controls._switch_hint.visible,
			"authored switch hitters must see both button and cue before readiness")
		_check(Rect2(0, 0, 1280, 720).encloses(button)
			and button.size.x >= controls._switch.get_combined_minimum_size().x,
			"switch button must fit without clipped text")
		_check(not button.intersects(lab._event_panel.get_global_rect())
			and not button.intersects(lab._scorebug.get_global_rect()),
			"switch button must clear the readiness prompt and every scorebug anchor")
	# Use viewport GUI dispatch, not just the signal: the click must not ready the batter.
	_click(controls._switch.get_global_rect().get_center())
	_check(batter.bats_left() != left and lab._awaiting_batter_confirm
		and not lab._ai_pitch_preselected and lab._throw_number == 0,
		"click must switch exactly once without committing an AI pitch or starting the at-bat")
	_check(("left-handed" if batter.bats_left() else "right-handed") in controls._switch_hint.text,
		"cue must immediately show the selected side")
	_key(lab, KEY_B)
	_check(batter.bats_left() == left, "B must switch back without starting the at-bat")
	_check(lab._bat_actor.bats_left == left and lab._batter_avatar.bats_left == left,
		"bat and avatar must use effective batting side")
	_check(signf(lab._batter_avatar.position.x) == (-1.0 if left else 1.0),
		"batter must stand on the correct physical plate side")
	_check(lab._scorebug._batter.text.begins_with("BAT L" if left else "BAT R"),
		"scorebug must agree with the selected side")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	controls._process(0.0)
	_key(lab, KEY_B)
	_check(not controls._switch.visible and batter.bats_left() == left,
		"pause must hide and lock side selection")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	_key(lab, KEY_SPACE)
	controls._process(0.0)
	_check(not controls._switch.visible and not controls._switch_hint.visible,
		"readiness must remove both controls from the pitch sightline")
	_check(PitchBatLabFeelSupport.request_batter_timeout(lab), "fixture must allow timeout")
	_key(lab, KEY_B)
	controls._switch_side()
	controls._process(0.0)
	_check(batter.bats_left() == left and not controls._switch.visible,
		"timeout must not reopen batting side selection")
	_key(lab, KEY_SPACE)
	lab._at_bat_cadence.stop()
	lab._throw_pitch()
	PitchBatLabSwingSupport.begin_swing(lab, lab.CONTACT_SWING_ID, Vector2(0, 1.05))
	_check(lab._swing_tracker.intent != null and lab._swing_tracker.intent.handedness_left == left,
		"actual launched pitch and swing must use the selected batting side")
	if lab._swing_tracker.intent != null:
		var point: Vector3 = Vector3(0, 1.05, ContactResolver.CONTACT_PLANE_Z + 0.04)
		var contact: ContactResult = ContactResolver._resolve_at_contact(
			lab._pitch_actor.state, point, point, lab._swing_tracker.intent,
			lab._swing_tracker.profile, batter.definition.contact, batter.definition.power)
		_check(contact.spray_degrees > 0 if left else contact.spray_degrees < 0,
			"same early contact must pull to opposite fields for opposite batting sides")
	_key(lab, KEY_B)
	_check(batter.bats_left() == left and batter.definition.throws == throwing_hand,
		"live input must not switch or modify the authored throwing hand")
	# A new plate appearance reopens selection; ordinary hitters must never see it.
	lab._pitch_actor.stop_pitch(&"test")
	lab._match_state.record_hit(BallPlayOutcome.Result.SINGLE)
	PitchBatLabFeelSupport.handle_match_advance(lab)
	var next_batter: PlayerMatchState = lab._match_state.batter()
	var ordinary: PlayerDefinition = ContentDB.get_player(&"player.casey_rivers")
	next_batter.definition = ordinary
	controls._process(0.0)
	_key(lab, KEY_B)
	_check(not controls._switch.visible and next_batter.batting_hand_override == -1,
		"ordinary hitter must not display or accept side switching")
	next_batter.definition = ContentDB.get_player(id)
	controls._process(0.0)
	_check(controls._switch.visible, "next switch-hitting batter must get a fresh choice")
	var path: String = lab._record_export.path
	lab.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(path)


func _click(point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		get_viewport().push_input(click, true)


static func _key(lab: PitchBatLab, code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	PitchBatLabInput.handle(lab, event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
