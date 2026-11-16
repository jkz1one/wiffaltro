extends Node3D
## Real receiver physics and complete-field terminal outcomes, without production reports.

var _failures: int = 0


func _ready() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_expanded_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(StadiumExpandedLab.install(lab), "explicit full AE-01 installation")
	if _failures > 0:
		get_tree().quit(1)
		return
	var property: StadiumExpandedProperty = lab.get_meta("stadium_property")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var receiver: StadiumPairedReceiver = property.get_node("PitchReceiverPresentation")
	for speed: float in [10, 40, 120]:
		for sample: Array in [
			[Vector3(0, 1.3, 0), "ST026_PANEL"],
			[Vector3(1, 1.3, 0), "ST025_NET"],
			[Vector3(-1, 1.3, 0), "ST025_NET"]
		]:
			var path: Dictionary = receiver.trace(sample[0], Vector3(0, 0, -speed), 0.0365)
			_check(
				not path.hit.is_empty() and path.hit.surface == sample[1],
				"earliest real pair contact"
			)
		var miss: Dictionary = receiver.trace(Vector3(2.4, 1.3, 0), Vector3(0, 0, -speed), 0.0365)
		_check(miss.hit.is_empty(), "true pair miss")
		_check(
			miss.reason == ("receiver_cleanup" if speed > 10 else "receiver_presentation_timeout"),
			"bounded rear cleanup or timeout"
		)
	lab._start_new_match()
	property._process(0)
	lab._match_state.inning = 3
	lab._match_state.home_team.runs = 7
	property.display._process(0)
	_check(
		(
			property.display._match == lab._match_state
			and property.display.shown.inning == 3
			and property.display.shown.home == 7
		),
		"manual board rebinds actual replacement match"
	)
	_routes(lab, property)
	for sample: Array in [
		[Vector3(0, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(1.1, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(0, 4, 25), Vector3(0, 0, 36), false, BallPlayOutcome.Result.HOME_RUN]
	]:
		await _flight(lab, property, sample)
	_check(PhysicalMatchReport.capture(lab).is_empty(), "isolated play cannot issue public report")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro expanded lab passed: physical receiver, board, defenders and real outcomes."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _routes(lab: PitchBatLab, property: StadiumExpandedProperty) -> void:
	var fielder: FielderController = lab._primary_fielder
	var original: Vector3 = fielder.global_position
	fielder.set_physics_process(false)
	for target: Vector3 in [
		Vector3(100, 0, 13),
		Vector3(-100, 0, 13),
		Vector3(0, 0, 100),
		Vector3(0, 0, -100),
		Vector3(1.5, 0, -4.5)
	]:
		fielder.set_anchor(Vector3(0, 0, 10))
		fielder.begin_play()
		fielder.target_position = target
		for step in range(120):
			var before: Vector3 = fielder.global_position
			fielder._physics_process(1.0 / 30)
			var current: Vector3 = fielder.global_position
			_check(
				(property.get_node("BoundaryGraph") as StadiumExpandedBoundary).graph.contains(
					Vector2(current.x, current.z)
				),
				"defender never shortcuts through the installed polygon"
			)
			_check(
				StadiumDefenderRoutes.clear(before, current, property.route_obstacles()),
				"defender body path clears receiver footprint"
			)
		fielder.end_play()
	fielder.set_anchor(original)
	lab._pitcher_marker.global_position = Vector3(0, 0, 14)
	var clipped: Vector3 = StadiumPropertyRuntime.pitcher_step(
		lab, Vector3(100, 0, 14), 100, Vector3(100, 0, 14)
	)
	_check(
		(property.get_node("BoundaryGraph") as StadiumExpandedBoundary).graph.contains(
			Vector2(clipped.x, clipped.z)
		),
		"actual pitcher adapter also respects complete graph"
	)


func _flight(lab: PitchBatLab, property: StadiumExpandedProperty, sample: Array) -> void:
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	(property.get_node("PitchReceiverPresentation") as StadiumPairedReceiver).contacts.clear()
	_check(lab._match_state.begin_pitch(), "real candidate play begins from a pitch")
	var outcomes: Array[BallPlayOutcome] = []
	var callback: Callable = func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome)
	lab._ball_play_resolver.play_resolved.connect(callback)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = sample[0]
	launch.velocity = sample[1]
	launch.is_foul = sample[2]
	lab._start_ball_in_play(launch)
	# Crossings are observed by the real lab physics callback; disabling it tests only collisions.
	lab.set_physics_process(true)
	_check(
		lab._batted_ball.physics_contact_router.is_valid(), "real game ball uses candidate physics"
	)
	for frame in range(120):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.dead:
			break
	_check(
		outcomes.size() == 1 and outcomes[0].result == sample[3],
		"one actual candidate terminal outcome at " + str(sample[0])
	)
	if sample[0].z < 1:
		_check(
			(
				(
					(property.get_node("PitchReceiverPresentation") as StadiumPairedReceiver)
					. contacts
					. size()
				)
				== 1
			),
			"physical target and net containment each produce exactly one response"
		)
	lab.set_physics_process(false)
	lab._ball_play_resolver.play_resolved.disconnect(callback)
	lab._cleanup_batted_ball()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
