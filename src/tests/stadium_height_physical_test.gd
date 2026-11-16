extends "res://src/tests/stadium_recipe_physical_test.gd"
## Original asymmetric candidate, actual joined collisions and native isolated review.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	for shape: String in StadiumHeightWallRecipes.SHAPES:
		_shape = shape
		await _physical(_shape)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro height physical checks passed: isolated actual faces, contacts and exits.")
	get_tree().quit(0 if _failures == 0 else 1)


func _physical(shape: String) -> void:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"isolated field substrate")
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumRecipeBoundaryBody = StadiumHeightBoundaryBody.new()
	property.add_child(boundary)
	_check(boundary.build(shape, "ST-077") and not boundary.build(shape), "one exact joined graph")
	var stock: StadiumStock = StadiumStock.new_club()
	for id: String in ["ST-063b", "ST-063g"]:
		var quote: Dictionary = stock.quote(id, 1, {"seasons": 50, "wins": 200}, id)
		_check(quote.ok, "exact authoring-only style entitlement")
		stock = StadiumStock.from_data(quote.state)
	var selection: Dictionary = {"grass": "", "line": ""}
	_check(StadiumRecipeFieldStyles.apply(property, boundary.graph, selection, "", stock),
		"field lines follow the actual candidate")
	property.add_child(StadiumSurfaceFinish.build(boundary.graph,
		"grass", "short", "ST-063b", "ST-063g"))
	StadiumWallRenderQuality.attach(boundary)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for row: Dictionary in boundary.graph.segments():
		var normal: Vector2 = boundary.graph.inward(row)
		var center: Vector2 = (row.a + row.b) / 2
		var from: Vector3 = Vector3(center.x + normal.x * 0.5, 0.75, center.y + normal.y * 0.5)
		var to: Vector3 = from - Vector3(normal.x, 0, normal.y) * 1.5
		var hit: Dictionary = _ray(from, to)
		_check(not hit.is_empty() and hit.collider.get_meta("boundary_segment", "") == row.id,
			"actual inward collision face " + row.id)
		for foul: bool in [false, true]:
			await _flight(boundary, row, from, Vector3(-normal.x, 0, -normal.y) * 6, foul)
	for vertex: Vector2 in boundary.graph.polygon():
		var inside: Vector2 = vertex.lerp(Vector2(0, 10), 0.1)
		var outside: Vector2 = vertex + (vertex - inside).normalized()
		_check(not _ray(Vector3(inside.x, 0.6, inside.y),
			Vector3(outside.x, 0.6, outside.y)).is_empty(), "convex and concave joins have no hole")
	var back_z: float = 27.0 if shape == "left_loft" else 26.1666666667
	for foul: bool in [false, true]:
		await _exit_flight(boundary, Vector3(23, 2, 22.7), Vector3(0, 0, 36),
			"SIDE_EXIT_DEAD", foul)
		await _exit_flight(boundary, Vector3(0, 4, back_z - 0.7), Vector3(0, 0, 36),
			"BACK_CLEAR", foul)
		await _exit_flight(boundary, Vector3(0, 2, -5.5), Vector3(0, 0, -36),
			"REAR_PERIMETER_DEAD", foul)
	await _capture_scene(property)
	property.queue_free()
	await get_tree().physics_frame


func _exit_flight(boundary: StadiumRecipeBoundaryBody, from: Vector3, velocity: Vector3,
	role: String, foul: bool) -> void:
	var resolver: BallPlayResolver = _resolver(foul)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	boundary.bind_ball(ball, resolver)
	var contact_count: int = boundary.contacts.size()
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = from
	launch.velocity = velocity
	ball.launch(launch)
	var previous: Vector3 = from
	for frame in range(30):
		await get_tree().physics_frame
		StadiumHeightSweep.observe(boundary, resolver, previous, ball.global_position)
		previous = ball.global_position
		if resolver.state.dead:
			break
	var records: Array = resolver.state.stadium_contacts
	_check(not records.is_empty() and records[-1].role == role
		and boundary.contacts.size() == contact_count,
		"actual above-wall flight crosses the proper graph without a phantom face hit")
	var result: BallPlayOutcome.Result = BallPlayOutcome.Result.FOUL if (
		foul or role == "REAR_PERIMETER_DEAD") else BallPlayOutcome.Result.HOME_RUN if (
		role == "BACK_CLEAR") else BallPlayOutcome.Result.SINGLE
	_check(_outcomes.size() == 1 and _outcomes[0].result == result,
		"actual high-speed exit has its fair/foul-specific outcome")
	ball.queue_free()
	await get_tree().physics_frame
