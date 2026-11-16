extends Node3D
## Joined fixed-height prisms, real sphere radius and first-event precedence.

var _failures: int = 0
var _samples: int = 0
var _outcomes: Array[BallPlayOutcome] = []


func _ready() -> void:
	_check(StadiumHeightWallRecipes.requirements("left_loft", "ST-024")
		== {"low": 0, "standard": 13, "tall": 12}, "left loft uses twelve distinct tall pieces")
	_check(StadiumHeightWallRecipes.requirements("right_shelf", "ST-024")
		== {"low": 7, "standard": 19, "tall": 0}, "right shelf uses seven distinct low pieces")
	_check(StadiumHeightBoundary.candidate("invented") == null
		and StadiumHeightSweep.event(null, Vector3.ZERO, Vector3.ONE).is_empty(),
		"unknown or absent candidates fail closed")
	for shape: String in StadiumHeightWallRecipes.SHAPES:
		var boundary: StadiumHeightBoundaryBody = StadiumHeightBoundaryBody.new()
		add_child(boundary)
		_check(boundary.build(shape), "candidate fixed-height assembly builds")
		_check(not boundary.build(shape), "repeated build cannot duplicate geometry")
		await get_tree().physics_frame
		await get_tree().physics_frame
		_faces(boundary)
		_steps(boundary)
		_rules(boundary)
		_geometry(boundary)
		_movement(boundary.graph)
		await _flight_probes(boundary)
		_check(StadiumRecipeBoundary.create(shape) == null,
			"saved runtime factories cannot accidentally accept the prototype")
		boundary.queue_free()
		await get_tree().process_frame
	print("HEIGHT_SWEEP_SAMPLES ", _samples)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro height sweep checks passed: real radius, step precedence and separate pieces.")
	get_tree().quit(0 if _failures == 0 else 1)


func _faces(boundary: StadiumHeightBoundaryBody) -> void:
	for row: Dictionary in boundary.graph.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		var normal: Vector2 = StadiumRecipeBoundary.inward(row)
		for along: float in [0.2, 0.5, 0.8]:
			var center: Vector2 = row.a.lerp(row.b, along)
			for dy: float in [-0.05, 0.01825, 0.05]:
				for distance: float in [0.5, 20.0, 150.0]:
					var start: Vector2 = center + normal * 0.2
					var end: Vector2 = center - normal * distance
					var event: Dictionary = StadiumHeightSweep.event(boundary,
						Vector3(start.x, row.height + dy, start.y),
						Vector3(end.x, row.height + dy, end.y))
					_check(not event.is_empty(), "fast trajectory always yields a boundary event")
					if event.is_empty():
						continue
					_check(event.role == ("BACK_CLEAR" if dy > 0.0365 else "BACK_WALL_TERMINAL"),
						"radius-aware top grazing differs from center-only clearance: " + str(event))
					_samples += 1


func _steps(boundary: StadiumHeightBoundaryBody) -> void:
	var rows: Array[Dictionary] = boundary.graph.segments()
	for index in range(3, rows.size() - 3):
		var low: Dictionary = rows[index]
		var high: Dictionary = rows[index + 1]
		if low.height >= high.height:
			continue
		var joint: Vector2 = low.b
		var tangent: Vector2 = low.a.direction_to(low.b)
		var normal: Vector2 = StadiumRecipeBoundary.inward(low)
		for distance: float in [0.5, 20.0, 150.0]:
			for offset: float in [0.0, 0.01, 0.03, 0.06]:
				var center: Vector2 = joint - tangent * offset
				var a: Vector2 = center + normal * 0.2
				var b: Vector2 = center - normal * distance
				var start: Vector3 = Vector3(a.x, low.height + 0.3, a.y)
				var end: Vector3 = Vector3(b.x, low.height + 0.3, b.y)
				var event: Dictionary = StadiumHeightSweep.event(boundary, start, end)
				_check(not event.is_empty(), "step sweep has a result")
				if offset < 0.0365:
					_check(event.get("swept_contact", false) and event.segment == high.id,
						"neighbor contact precedes low-wall clear, independent of segment IDs: " + str(event))
				else:
					_check(event.role == "BACK_CLEAR", "later outside contact cannot undo first valid clear")
				_samples += 1
		var near: Vector2 = joint + normal * 0.01
		var at: Vector3 = Vector3(near.x, low.height + 0.3, near.y)
		for direction: float in [-1.0, 1.0]:
			var event: Dictionary = StadiumHeightSweep.event(boundary, at,
				at + Vector3(tangent.x, 0, tangent.y) * direction)
			_check(event.get("swept_contact", false) and event.fraction == 0,
				"initial overlap is explicitly detected in both travel directions")


func _rules(boundary: StadiumHeightBoundaryBody) -> void:
	var row: Dictionary = boundary.graph.segments()[4]
	var center: Vector2 = (row.a + row.b) / 2
	var normal: Vector2 = StadiumRecipeBoundary.inward(row)
	for foul: bool in [false, true]:
		for grounded: bool in [false, true]:
			for touched: bool in [false, true]:
				for clear: bool in [false, true]:
					_outcomes.clear()
					var resolver: BallPlayResolver = BallPlayResolver.new()
					resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
					resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
						_outcomes.append(outcome))
					resolver.state.has_grounded = grounded
					resolver.state.defender_touched = touched
					var a: Vector2 = center + normal * 0.2
					var b: Vector2 = center - normal * 3
					var y: float = row.height + 0.1 if clear else 0.6
					var event: Dictionary = StadiumHeightSweep.observe(boundary, resolver,
						Vector3(a.x, y, a.y), Vector3(b.x, y, b.y))
					var expected: int = BallPlayOutcome.Result.FOUL if foul else (
						BallPlayOutcome.Result.HOME_RUN if clear and not grounded else (
							BallPlayOutcome.Result.DOUBLE if grounded or touched else BallPlayOutcome.Result.TRIPLE))
					_check(_outcomes.size() == 1 and _outcomes[0].result == expected,
						"height candidate preserves terminal foul/ground/touch scoring")
					_check(not boundary.graph.apply(resolver, event) and _outcomes.size() == 1,
						"already resolved clear/contact cannot award twice")
					_check(StadiumHeightSweep.observe(boundary, resolver,
						Vector3(b.x, y, b.y), Vector3(a.x, y, a.y)).is_empty(),
						"a later re-entry after a valid clear cannot change the terminal result")


func _geometry(boundary: StadiumHeightBoundaryBody) -> void:
	for row: Dictionary in boundary.graph.segments():
		var body: StaticBody3D = boundary.get_node(row.id)
		var shape: CollisionShape3D = body.get_child(0)
		var points: PackedVector3Array = shape.shape.points
		_check(points.size() == 8, "joined convex prism retains eight literal corners")
		for point: Vector3 in points:
			_check(is_zero_approx(point.y) or is_equal_approx(point.y, row.height),
				"collision top matches the actual section")
	for box: AABB in boundary.visibility_bounds():
		_check(is_equal_approx(box.size.y, 1.2) or box.size.y in [1.625, 3.25, 4.875],
			"visibility prisms retain actual heights")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _flight_probes(boundary: StadiumHeightBoundaryBody) -> void:
	var rows: Array[Dictionary] = boundary.graph.segments()
	for index in range(3, rows.size() - 3):
		var low: Dictionary = rows[index]
		if low.height >= rows[index + 1].height:
			continue
		for offset: float in [0.01, 0.06]:
			for speed: float in [15.0, 60.0, 120.0]:
				for physical: bool in [false, true]:
					await _probe(boundary, low, offset, speed, physical)


func _probe(boundary: StadiumHeightBoundaryBody, low: Dictionary,
	offset: float, speed: float, physical: bool) -> void:
	var tangent: Vector2 = low.a.direction_to(low.b)
	var normal: Vector2 = StadiumRecipeBoundary.inward(low)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	ball.collision_mask = 1 if physical else 0
	var point: Vector2 = low.b - tangent * offset + normal * 0.8
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(point.x, low.height + 0.3, point.y)
	launch.velocity = Vector3(-normal.x, 0, -normal.y) * speed
	ball.launch(launch)
	_outcomes.clear()
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID))
	resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome))
	if physical:
		boundary.bind_ball(ball, resolver)
	var previous: Vector3 = launch.position
	for frame in range(120):
		await get_tree().physics_frame
		StadiumHeightSweep.observe(boundary, resolver, previous, ball.global_position)
		previous = ball.global_position
		if resolver.state.dead:
			break
	if physical:
		print("HEIGHT_PHYSICAL_PROBE ", boundary.graph.identity(), " offset=", offset,
			" speed=", speed, " center=", ball.global_position,
			" contacts=", resolver.state.stadium_contacts)
	_check(_outcomes.size() == 1 and _outcomes[0].result == (
		BallPlayOutcome.Result.TRIPLE if offset < ball.radius_m else BallPlayOutcome.Result.HOME_RUN),
		"engine-step " + ("physical" if physical else "free") + " probe at " + str(speed)
		+ " offset=" + str(offset) + " preserves contact/clear precedence")
	var completed_contacts: Array = resolver.state.stadium_contacts.duplicate(true)
	for frame in range(3):
		await get_tree().physics_frame
	_check(resolver.state.stadium_contacts == completed_contacts and _outcomes.size() == 1,
		"later physical callbacks cannot rewrite a completed boundary result")
	ball.queue_free()
	await get_tree().physics_frame


func _movement(graph: StadiumRecipeBoundary) -> void:
	var helper: Node = load("res://src/tests/stadium_recipe_boundary_test.gd").new()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 6100615
	var samples: int = 0
	for index in range(600):
		var from: Vector3 = Vector3(random.randf_range(-23, 23), 0, random.randf_range(-5, 27))
		if not helper._clear(graph, from):
			continue
		var to: Vector3 = Vector3(random.randf_range(-50, 50), 0, random.randf_range(-30, 60))
		var clipped: Vector3 = graph.clip(from, to)
		for step in range(21):
			_check(helper._clear(graph, from.lerp(clipped, float(step) / 20)),
				"complete defender motion retains clearance from the new outline")
		samples += 1
	_check(samples > 300, "substantial deterministic movement coverage")
	_check(graph.signature() == StadiumHeightBoundary.candidate(graph.candidate_shape).signature(),
		"candidate signature is deterministic")
	print("HEIGHT_DEFENDER_PATHS ", graph.identity(), " paths=", samples, " samples=", samples * 21)
	helper.free()
