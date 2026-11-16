extends Node3D
## Actual concave boundary faces, contacts, exits and exact original panel placement.

var _failures: int = 0
var _outcomes: Array[BallPlayOutcome] = []
var _capture_dir: String = ""
var _shape: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	for shape: String in StadiumWallRecipes.SHAPES:
		_shape = shape
		await _physical(shape)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro recipe physical checks passed: joined faces, actual contacts and exits.")
	get_tree().quit(0 if _failures == 0 else 1)


func _physical(shape: String) -> void:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"isolated field substrate")
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumRecipeBoundaryBody = StadiumRecipeBoundaryBody.new()
	property.add_child(boundary)
	_check(boundary.build(shape, "ST-077") and not boundary.build(shape), "one exact joined graph")
	var stock: StadiumStock = StadiumStock.new_club()
	for id: String in ["ST-063c", "ST-063g"]:
		var quote: Dictionary = stock.quote(id, 1, {"seasons": 50, "wins": 200}, id)
		_check(quote.ok, "exact authoring-only style entitlement")
		stock = StadiumStock.from_data(quote.state)
	var selection: Dictionary = {"grass": "ST-063c", "line": ""}
	_check(StadiumInfieldModels.apply(property, "ST-063g", selection, stock)
		and StadiumRecipeFieldStyles.apply(property, boundary.graph, selection, "ST-063g", stock),
		"pattern and dirt fit the actual recipe independently")
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
	var back_z: float = 26 if shape == "deeper_center" else 23.4
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


func _resolver(foul: bool = false) -> BallPlayResolver:
	_outcomes.clear()
	var result: BallPlayResolver = BallPlayResolver.new()
	result.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
	result.play_resolved.connect(func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome))
	return result


func _flight(boundary: StadiumRecipeBoundaryBody, row: Dictionary, from: Vector3,
	velocity: Vector3, foul: bool) -> void:
	var resolver: BallPlayResolver = _resolver(foul)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	boundary.bind_ball(ball, resolver)
	boundary.bind_ball(ball, resolver)
	var count: int = boundary.contacts.size()
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = from
	launch.velocity = velocity
	ball.launch(launch)
	for frame in range(120):
		await get_tree().physics_frame
		if boundary.contacts.size() > count:
			break
	_check(boundary.contacts.size() == count + 1
		and boundary.contacts[-1].segment == row.id, "actual ball records one named contact " + row.id)
	_check(resolver.state.dead == (row.role != "SIDE_RETURN_LIVE"),
		"actual side contact stays live; rear/back contacts end once")
	if row.role == "SIDE_RETURN_LIVE":
		await get_tree().physics_frame
		_check(ball.linear_velocity.dot(-velocity.normalized()) > 0.1
			and resolver.state.is_foul_play == foul and not resolver.state.has_grounded,
			"actual live face rebounds without replacing contact classification or ground history")
	else:
		_check(_outcomes.size() == 1 and _outcomes[0].result == (BallPlayOutcome.Result.FOUL
			if foul or row.role == "REAR_PERIMETER_DEAD" else BallPlayOutcome.Result.TRIPLE),
			"actual terminal contact uses its assigned fair/foul result exactly once")
	ball.queue_free()
	await get_tree().physics_frame


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, 1))


func _capture_scene(property: Node3D) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "boundary review requires native rendering")
	if DisplayServer.get_name() == "headless":
		return
	get_window().size = Vector2i(1280, 720)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("142520")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.5
	property.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_energy = 0.7
	light.shadow_enabled = true
	property.add_child(light)
	var camera: Camera3D = Camera3D.new()
	property.add_child(camera)
	camera.position = Vector3(-28, 38, -22)
	camera.look_at(Vector3(0, 0, 11))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 46
	camera.make_current()
	var label: Label = Label.new()
	label.text = "BACKYARD • " + _shape + " wall prototype"
	label.position = Vector2(32, 24)
	label.add_theme_font_size_override("font_size", 28)
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for frame in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join("backyard-" + _shape + "-walls.png")) == OK,
		"actual candidate field saved")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


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
	var observed: Dictionary = {}
	for frame in range(30):
		await get_tree().physics_frame
		observed = boundary.graph.observe(resolver, previous, ball.global_position)
		previous = ball.global_position
		if resolver.state.dead:
			break
	_check(observed.get("role") == role and boundary.contacts.size() == contact_count,
		"actual above-wall flight crosses the proper graph without a phantom face hit")
	var result: BallPlayOutcome.Result = BallPlayOutcome.Result.FOUL if (
		foul or role == "REAR_PERIMETER_DEAD") else BallPlayOutcome.Result.HOME_RUN if (
		role == "BACK_CLEAR") else BallPlayOutcome.Result.SINGLE
	_check(_outcomes.size() == 1 and _outcomes[0].result == result,
		"actual high-speed exit has its fair/foul-specific outcome")
	ball.queue_free()
	await get_tree().physics_frame
