extends "res://src/tests/stadium_receiver_test.gd"
## Target-only prototype routing. This fixture does not authorize a saved target/net pair.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _traces()
	for left: bool in [false, true]:
		var baseline: Array = await _calls(false, left)
		var target: Array = await _calls(true, left)
		_check(baseline == target and baseline.size() == 13,
			"actual center, edge, corner and outside calls match default for both hands")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro target receiver checks passed: "
			+ "unchanged calls, named sweeps, one post-call hit and batted containment.")
	get_tree().quit(0 if _failures == 0 else 1)


func _traces() -> void:
	var target: Node3D = StadiumTargetModels.create()
	target.position = StadiumTargetModels.POSITION
	target.set_meta("owned_copy", "target-sweep-fixture")
	for body: Node in target.get_node("Collision").get_children():
		body.set_meta("owned_copy", "target-sweep-fixture")
	add_child(target)
	var receiver: StadiumTargetReceiver = StadiumTargetReceiver.new()
	add_child(receiver)
	_check(receiver.configure(target), "target-only router configuration")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for speed: float in [10.0, 40.0, 120.0]:
		for sample: Array in [[Vector3(0, 1.05, 0), "ST026_PANEL"],
			[Vector3(-0.5, 1.05, 0), "ST026_FRAME_SIDE"],
			[Vector3(0.5, 1.05, 0), "ST026_FRAME_SIDE"],
			[Vector3(0.5, 0.25, 0), "ST026_LEGS"], [Vector3(0.5, 0.04, 0), "ST026_BASE"]]:
			var path: Dictionary = receiver.trace(sample[0], Vector3(0, 0, -speed), 0.0365)
			_check(not path.hit.is_empty()
				and String(path.hit.get("surface", "")).begins_with(sample[1]),
				"actual high/low-speed sweep selects " + sample[1] + " speed=" + str(speed))
			_check(path.times[-1] <= 0.24, "post-call contact is bounded")
	for point: Vector3 in [Vector3(0, 2.1, 0), Vector3(1, 1.05, 0)]:
		var miss: Dictionary = receiver.trace(point, Vector3(0, 0, -10), 0.0365)
		_check(miss.hit.is_empty() and miss.reason == "receiver_cleanup"
			and is_equal_approx(miss.points[-1].z, -1.85), "target-only miss uses its own silent cleanup")
	var slow: Dictionary = receiver.trace(Vector3(1, 1.05, 0), Vector3(0, 0, -0.5), 0.0365)
	_check(slow.hit.is_empty() and slow.reason == "receiver_presentation_timeout",
		"slow miss has no phantom impact")
	_check(receiver.contacts.is_empty(), "trace queries do not emit presentation contacts themselves")
	target.queue_free()
	receiver.queue_free()
	await get_tree().physics_frame


func _calls(installed: bool, left: bool) -> Array:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(StadiumPropertyRuntime.install_lab(lab, StadiumStarterLayout.empty(),
		StadiumStock.new_club()), "actual default lab baseline")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var receiver: StadiumTargetReceiver
	if installed:
		receiver = _install_target(lab, property)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var samples: Array[Vector2] = [Vector2(0, 1.05),
		Vector2(-0.43, 1.05), Vector2(0.43, 1.05), Vector2(0, 0.55), Vector2(0, 1.55),
		Vector2(-0.43, 0.55), Vector2(0.43, 0.55), Vector2(-0.43, 1.55), Vector2(0.43, 1.55),
		Vector2(-0.48, 1.05), Vector2(0.48, 1.05), Vector2(0, 0.50), Vector2(0, 1.60)]
	var calls: Array = []
	for sample: Vector2 in samples:
		lab._start_new_match()
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
			else PlayerDefinition.Handedness.RIGHT
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
			_check(actor.global_position == paused and receiver.contacts.is_empty(),
				"pause prevents hidden receiver advancement")
			get_tree().paused = false
		for frame in range(40):
			await get_tree().process_frame
		_check(call == Vector2i(lab._match_state.balls, lab._match_state.strikes),
			"receiver presentation cannot revise the z=0 call")
		_check(not actor.visible, "called pitch presentation finishes")
		if receiver != null:
			_check(receiver.contacts.size() <= 1, "at most one physical target contact per called pitch")
			if sample == samples[0]:
				_check(receiver.contacts.size() == 1
					and receiver.contacts[0].surface == "ST026_PANEL"
					and lab._sounds.last_cue == &"target_panel", "real center hit gives soft panel feedback")
	if receiver != null:
		for speed: float in [8.0, 40.0, 120.0]:
			await _backward_ball(lab, receiver, speed)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	return calls


func _install_target(lab: PitchBatLab, property: StadiumPropertyGeometry) -> StadiumTargetReceiver:
	# Explicit authoring fixture: exact paid stock is checked, but no production layout is fabricated.
	var quote: Dictionary = StadiumStock.new_club().quote("ST-026", 1,
		{"seasons": 1, "strikeouts": 40}, "target-fixture")
	_check(quote.ok, "target blueprint/copy synthetic authoring receipt")
	var target: Node3D = StadiumTargetModels.create()
	target.position = StadiumTargetModels.POSITION
	target.set_meta("owned_copy", "purchase:target-fixture:0")
	for body: Node in target.get_node("Collision").get_children():
		body.set_meta("owned_copy", "purchase:target-fixture:0")
	property.add_child(target)
	property.objects["purchase:target-fixture:0"] = target
	var receiver: StadiumTargetReceiver = StadiumTargetReceiver.new()
	receiver.name = "PitchReceiverPresentation"
	property.add_child(receiver)
	_check(receiver.configure(target, lab._sounds), "actual target presentation configured")
	lab._pitch_actor.receiver_router = receiver.route
	return receiver


func _backward_ball(lab: PitchBatLab, receiver: StadiumTargetReceiver, speed: float) -> void:
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	receiver.contacts.clear()
	_check(lab._match_state.begin_pitch(), "actual backward ball begins from pitch")
	var outcomes: Array = []
	lab._ball_play_resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
		outcomes.append(outcome))
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 1.1, 0.2)
	launch.velocity = Vector3(0, 0, -speed)
	launch.is_foul = true
	lab._start_ball_in_play(launch)
	_check(receiver.chair.get_node("Visual").visible,
		"target reveals before first batted physics step")
	for frame in range(45):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.dead:
			break
	_check(outcomes.size() == 1 and outcomes[0].result == BallPlayOutcome.Result.FOUL,
		"actual backward target contact is one terminal Foul, not a defensive Out")
	_check(receiver.contacts.size() == 1 and receiver.contacts[0].kind == "batted",
		"one matching batted presentation contact")
