extends "res://src/tests/stadium_npc_yard_two_runtime_test.gd"
## Issued-play controls: each event owns a fresh lab and ordinary launch.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for route: String in ["observer", "manifold"]:
		await _positive(route)
	await TestAudioDrain.finish(get_tree())
	print("AY02_CURRENT_CALLBACK_REPORT ", JSON.stringify({"assertions": _seen,
		"failures": _failures, "rendered_qualification": false}))
	get_tree().quit(0 if _failures == 0 else 1)


func _positive(route: String) -> void:
	var lab: PitchBatLab = _lab()
	var original: Dictionary = _snapshot(lab)
	var installed: bool = R.install(lab)
	_assert(route + "/install", installed and R.installed(lab), "Fresh installed lifetime")
	if not installed:
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var fresh: bool = Proof.fresh(self, lab)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 3, 10)
	lab._start_ball_in_play(launch)
	var ball: BattedBallBody = lab._batted_ball
	if not is_instance_valid(ball):
		_assert(route + "/issued", false, "Ordinary launch must issue a real ball")
		lab.free()
		return
	ball.freeze = true
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var state: BallPlayState = resolver.state
	var generation: int = property.play_generation
	_assert(route + "/issued", fresh and property.callback_intact()
		and property.phase == &"playing" and property._play_kind == &"ball"
		and property._play_ball == ball and property._play_state == state
		and not state.dead and state.stadium_contacts.is_empty(),
		"Ordinary issuance pins the exact live ball and resolver state")
	var count: int = property.boundary.contacts.size()
	var outcomes: Array = []
	var hook: Callable = func(value: BallPlayOutcome) -> void:
		outcomes.append([value.result, value.reason])
	resolver.play_resolved.connect(hook)
	var event: Dictionary = {}
	if route == "observer":
		event = property.observe(resolver, Vector3(0, 0.6, 22), Vector3(0, 0.6, 25))
	else:
		var batch: Array[Dictionary] = [{"body": property.boundary.get_node(
			"BACK-TERMINAL-01"), "position": Vector3(0, 0.6, 23.4)}]
		ball.physics_contact_router.call(ball, batch)
	resolver.play_resolved.disconnect(hook)
	_assert(route + "/outcome", state.dead and outcomes == [[
		BallPlayOutcome.Result.TRIPLE, &"back_wall_on_fly"]]
		and state.stadium_contacts.size() == 1
		and (not event.is_empty() if route == "observer" else
			property.boundary.contacts.size() == count + 1
			and property.boundary.contacts[-1].segment == "BACK-TERMINAL-01"),
		"Exact original observer/manifold triple and one contact history")
	_assert(route + "/ownership", resolver.state == state and property._play_state == state
		and property._play_ball == ball and property.play_generation == generation
		and property.callback_intact() and not lab.has_meta("stadium_npc_runtime_interrupted"),
		"Callback retains issued owners without replacing resolver state")
	lab._cleanup_batted_ball()
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	_assert(route + "/teardown", R.teardown(lab) and original == _snapshot(lab),
		"Clean ordinary lifetime restores exact original lab")
	lab.free()
	await get_tree().process_frame
