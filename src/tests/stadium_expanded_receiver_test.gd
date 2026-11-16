extends "res://src/tests/stadium_paired_receiver_test.gd"
## Logical calls and post-call physical presentation tested in the complete AE-01 assembly.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for left: bool in [false, true]:
		var baseline: Array = await _calls(false, left)
		var candidate: Array = await _calls(true, left)
		_check(
			candidate == baseline and candidate.size() == 13,
			"complete park preserves center/edge/corner/outside logical calls for both hands"
		)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro expanded receiver passed: unchanged calls and complete-field pair ordering."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _calls(installed: bool, left: bool) -> Array:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var receiver: StadiumTargetReceiver
	if installed:
		lab.set_meta("stadium_expanded_lab_only", true)
		_check(StadiumExpandedLab.install(lab), "full candidate receiver installation")
		var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
		receiver = property.get_node("PitchReceiverPresentation")
	else:
		_check(
			StadiumPropertyRuntime.install_lab(
				lab, StadiumStarterLayout.empty(), StadiumStock.new()
			),
			"unchanged free reference baseline"
		)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var samples: Array[Vector2] = [
		Vector2(0, 1.05),
		Vector2(-0.43, 1.05),
		Vector2(0.43, 1.05),
		Vector2(0, 0.55),
		Vector2(0, 1.55),
		Vector2(-0.43, 0.55),
		Vector2(0.43, 0.55),
		Vector2(-0.43, 1.55),
		Vector2(0.43, 1.55),
		Vector2(-0.48, 1.05),
		Vector2(0.48, 1.05),
		Vector2(0, 0.50),
		Vector2(0, 1.60)
	]
	var calls: Array = []
	for sample: Vector2 in samples:
		lab._start_new_match()
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		var actor: PitchFlightActor = lab._pitch_actor
		actor.set_physics_process(false)
		if receiver != null:
			receiver.contacts.clear()
		var parameters: PitchLaunchParameters = _parameters(sample.y + 4.903325 * 0.04 * 0.04)
		parameters.position.x = sample.x
		_check(lab._match_state.begin_pitch(), "fresh actual called pitch")
		actor.start_pitch(parameters)
		actor._physics_process(0.2)
		var call: Vector2i = Vector2i(lab._match_state.balls, lab._match_state.strikes)
		calls.append(call)
		if receiver != null and sample == samples[0]:
			get_tree().paused = true
			var paused: Vector3 = actor.global_position
			for frame in range(4):
				await get_tree().process_frame
			_check(
				actor.global_position == paused and receiver.contacts.is_empty(),
				"pause prevents hidden receiver advancement"
			)
			get_tree().paused = false
		for frame in range(40):
			await get_tree().process_frame
		_check(
			call == Vector2i(lab._match_state.balls, lab._match_state.strikes),
			"receiver presentation cannot revise the z=0 call"
		)
		_check(not actor.visible, "called pitch presentation finishes")
		if receiver != null:
			_check(
				receiver.contacts.size() <= 1,
				"at most one physical target contact per called pitch"
			)
			if sample == samples[0]:
				_check(
					(
						receiver.contacts.size() == 1
						and receiver.contacts[0].surface == "ST026_PANEL"
						and lab._sounds.last_cue == &"target_panel"
					),
					"real center hit gives soft panel feedback"
				)
	if receiver != null:
		for speed: float in [8.0, 40.0, 120.0]:
			await _backward_ball(lab, receiver, speed)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	return calls
