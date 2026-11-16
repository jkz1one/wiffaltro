extends "res://src/tests/stadium_target_receiver_test.gd"
## Explicit paired authoring fixture; no production ownership/layout enablement.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _traces()
	for left: bool in [false, true]:
		var baseline: Array = await _calls(false, left)
		var paired: Array = await _calls(true, left)
		_check(baseline == paired and baseline.size() == 13, "pair never changes logical calls")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro paired receiver checks passed: first physical hit, calls and batted net fouls.")
	get_tree().quit(0 if _failures == 0 else 1)


func _model(net: bool, copy: String) -> Node3D:
	var model: Node3D = StadiumNetModels.create() if net else StadiumTargetModels.create()
	model.position = StadiumNetModels.POSITION if net else StadiumTargetModels.POSITION
	model.set_meta("owned_copy", copy)
	for body: Node in model.get_node("Collision").get_children():
		body.set_meta("owned_copy", copy)
	return model


func _traces() -> void:
	var target: Node3D = _model(false, "target-fixture")
	var net: Node3D = _model(true, "net-fixture")
	add_child(target)
	add_child(net)
	var receiver: StadiumPairedReceiver = StadiumPairedReceiver.new()
	add_child(receiver)
	_check(not receiver.configure(net) and not receiver.configure(target),
		"pair cannot be configured with only one item")
	_check(not receiver.configure_pair(null, net), "net-only pairing rejected")
	_check(receiver.configure_pair(target, net), "two distinct owned roots accepted")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for speed: float in [10.0, 40.0, 120.0]:
		for sample: Array in [[Vector3(0, 1.3, 0), "ST026_PANEL"],
			[Vector3(1, 1.3, 0), "ST025_NET"], [Vector3(-1, 1.3, 0), "ST025_NET"],
			[Vector3(1.8, 1.3, 0), "ST025_FRAME_SIDE"],
			[Vector3(1.8, 0.3, -0.5), "ST025_FRAME_SIDE"]]:
			var path: Dictionary = receiver.trace(sample[0], Vector3(0, 0, -speed), 0.0365)
			_check(not path.hit.is_empty()
				and String(path.hit.get("surface", "")).begins_with(sample[1]),
				"pair chooses earliest physical " + sample[1] + " speed=" + str(speed))
			_check(path.times[-1] <= 0.24, "pair trace bounded")
		var miss: Dictionary = receiver.trace(Vector3(2.4, 1.3, 0),
			Vector3(0, 0, -speed), 0.0365)
		_check(miss.hit.is_empty(), "miss both never fabricates physical impact")
		if speed > 10:
			_check(miss.reason == "receiver_cleanup"
				and is_equal_approx(miss.points[-1].z, -3.10), "paired rear cleanup")
		else:
			_check(miss.reason == "receiver_presentation_timeout", "slow miss timeout precedes rear")
	_check(receiver.contacts.is_empty(), "query itself never emits presentation")
	target.queue_free()
	net.queue_free()
	receiver.queue_free()
	await get_tree().physics_frame


func _install_target(lab: PitchBatLab, property: StadiumPropertyGeometry) -> StadiumTargetReceiver:
	var target: Node3D = _model(false, "pair-target-authoring")
	var net: Node3D = _model(true, "pair-net-authoring")
	property.add_child(target)
	property.add_child(net)
	property.objects["pair-target-authoring"] = target
	property.objects["pair-net-authoring"] = net
	var receiver: StadiumPairedReceiver = StadiumPairedReceiver.new()
	receiver.name = "PitchReceiverPresentation"
	property.add_child(receiver)
	_check(receiver.configure_pair(target, net, lab._sounds), "explicit paired fixture configured")
	lab._pitch_actor.receiver_router = receiver.route
	return receiver


func _backward_ball(lab: PitchBatLab, receiver: StadiumTargetReceiver, speed: float) -> void:
	await super._backward_ball(lab, receiver, speed)
	await _net_ball(lab, receiver, speed)


func _net_ball(lab: PitchBatLab, receiver: StadiumTargetReceiver, speed: float) -> void:
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	receiver.contacts.clear()
	_check(lab._match_state.begin_pitch(), "actual backward ball begins from pitch")
	var outcomes: Array = []
	lab._ball_play_resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
		outcomes.append(outcome))
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(1.1, 1.3, 0.2)
	launch.velocity = Vector3(0, 0, -speed)
	launch.is_foul = true
	lab._start_ball_in_play(launch)
	_check((receiver as StadiumPairedReceiver).net.get_node("Visual").visible,
		"net reveals before first batted physics step")
	for frame in range(45):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.dead:
			break
	_check(outcomes.size() == 1 and outcomes[0].result == BallPlayOutcome.Result.FOUL,
		"actual backward net contact is one terminal Foul, not a defensive Out")
	_check(receiver.contacts.size() == 1 and receiver.contacts[0].kind == "batted",
		"one matching batted presentation contact")

	_check(receiver.contacts.size() == 1 and receiver.contacts[0].surface == "ST025_NET",
		"target-width miss contacts net exactly once")
