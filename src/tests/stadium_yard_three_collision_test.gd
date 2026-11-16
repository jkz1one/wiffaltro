extends "res://src/tests/stadium_boundary_lab_test.gd"
## Actual gravity-on complete-yard outcomes, free receiver lifecycle and contained defender routes.


func _ready() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_yard_three_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	if not StadiumYardThreeLab.install(lab):
		_check(false, "exact AY-03 isolated adapter")
		lab.queue_free()
		await get_tree().process_frame
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	for sample: Array in [[Vector3(23, 2, 22.7), Vector3(0, 0, 36), false,
		BallPlayOutcome.Result.SINGLE], [Vector3(23, 2, 22.7), Vector3(0, 0, 36), true,
		BallPlayOutcome.Result.FOUL], [Vector3(0, 2, -5.5), Vector3(0, 0, -36), false,
		BallPlayOutcome.Result.FOUL], [Vector3(0, 2, -0.5), Vector3(0, 0, -36), false,
		BallPlayOutcome.Result.FOUL], [Vector3(0, 4, 22.7), Vector3(0, 0, 36), false,
		BallPlayOutcome.Result.HOME_RUN], [Vector3(0, 0.05, 23), Vector3(0, 0, 12), false,
		BallPlayOutcome.Result.DOUBLE]]:
		await _lab_flight(lab, sample)
	await _routes_in_graph()
	await _chairs(lab.get_meta("stadium_property"))
	await _poles(lab.get_meta("stadium_property"))
	var actor: PitchFlightActor = lab._pitch_actor
	actor.visible = true
	actor._begin_plate_follow_through(Vector3(0, 1.1, 0), Vector3(0, 0, -12))
	await get_tree().create_timer(0.5).timeout
	_check(not actor.visible and actor._plate_follow_tween == null,
		"free receiver completes follow-through and cleans up its tween")
	actor.visible = true
	actor._begin_plate_follow_through(Vector3(0, 1.1, 0), Vector3(0, 0, -12))
	actor._cancel_plate_follow_through()
	_check(actor._plate_follow_tween == null, "receiver restart cancels the old follow-through")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro yard-three collision passed: "
			+ "full template outcomes, chair/pole contacts and receiver cleanup.")
	get_tree().quit(0 if _failures == 0 else 1)


func _chairs(property: StadiumPropertyGeometry) -> void:
	for sign_value: int in [-1, 1]:
		var resolver: BallPlayResolver = BallPlayResolver.new()
		resolver.start_play(property.field)
		var ball: BattedBallBody = BattedBallBody.new()
		ball.aero_drag_coefficient = 0
		ball.aero_magnus_scale = 0
		ball.aero_perforation_force_scale = 0
		add_child(ball)
		var contacts: Array[Dictionary] = []
		ball.body_entered.connect(func(body: Node) -> void:
			if body.has_meta("candidate_instance"):
				contacts.append({"ended": resolver.state.dead,
					"instance": body.get_meta("candidate_instance")})
				_check(not StadiumSurfaceRules.apply(resolver, "DECORATIVE_AFTER_TERMINAL",
					body.get_meta("candidate_instance"), ball.global_position),
					"chair collision cannot create another outcome"))
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = Vector3(sign_value * 17, 1.3, 12)
		launch.velocity = Vector3(sign_value * 18, 0, 0)
		ball.launch(launch)
		var previous: Vector3 = launch.position
		for frame in range(120):
			await get_tree().physics_frame
			StadiumBoundaryObserver.observe(resolver, previous, ball.global_position)
			previous = ball.global_position
			if not contacts.is_empty():
				break
		_check(not contacts.is_empty() and contacts[0].ended,
			"real chair contact occurs only after the side boundary ends play")
		ball.queue_free()
		await get_tree().physics_frame


func _poles(property: StadiumPropertyGeometry) -> void:
	for rear: bool in [false, true]:
		for sign_value: int in [-1, 1]:
			var resolver: BallPlayResolver = BallPlayResolver.new()
			resolver.start_play(property.field)
			var ball: BattedBallBody = BattedBallBody.new()
			ball.aero_drag_coefficient = 0
			ball.aero_magnus_scale = 0
			ball.aero_perforation_force_scale = 0
			add_child(ball)
			var contacts: Array[Dictionary] = []
			ball.body_entered.connect(func(body: Node) -> void:
				if body.get_meta("stadium_item", "") == "ST-037":
					contacts.append({"ended": resolver.state.dead,
						"instance": body.get_meta("candidate_instance", "")})
					_check(not StadiumSurfaceRules.apply(resolver, "DECORATIVE_AFTER_TERMINAL",
						body.get_meta("candidate_instance"), ball.global_position),
						"post-terminal pole contact cannot create a second outcome"))
			var launch: BattedBallLaunch = BattedBallLaunch.new()
			launch.position = Vector3(0, 4, 22 if rear else 0)
			launch.velocity = Vector3(sign_value * 36, 0, 4.32 if rear else 0)
			ball.launch(launch)
			var previous: Vector3 = launch.position
			for frame in range(120):
				await get_tree().physics_frame
				StadiumBoundaryObserver.observe(resolver, previous, ball.global_position)
				previous = ball.global_position
				if not contacts.is_empty():
					break
			var site: String = "YLIGHT-" + ("R" if rear else "F") + ("L" if sign_value < 0 else "R")
			_check(not contacts.is_empty() and contacts[0].ended
				and contacts[0].instance == "npc-candidate:AY-03:" + site,
				"real gravity-on pole contact follows terminal boundary " + site)
			ball.queue_free()
			await get_tree().physics_frame
