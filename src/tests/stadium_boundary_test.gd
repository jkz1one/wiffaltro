extends Node3D
## Isolated perimeter authoring, rule fixtures and physical probes; no save activation.

var _failures: int = 0
var _outcomes: Array[BallPlayOutcome] = []
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_graph()
	_rules()
	_observer_rules()
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}]
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", layout, StadiumStock.new_club()), "same full-scale property")
	# This isolated candidate replaces its own old wall, never an active season's geometry.
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumBoundaryPrototype = StadiumBoundaryPrototype.new()
	property.add_child(boundary)
	_check(boundary.build() and not boundary.build(), "one complete six-segment construction")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for row: Dictionary in StadiumBoundaryGraph.segments():
		var normal: Vector2 = StadiumBoundaryGraph.inward(row)
		var center: Vector2 = (row.a + row.b) / 2
		var from: Vector3 = Vector3(center.x + normal.x, 0.75, center.y + normal.y)
		var to: Vector3 = Vector3(center.x - normal.x, 0.75, center.y - normal.y)
		var hit: Dictionary = _ray(from, to)
		_check(not hit.is_empty() and hit.collider.get_meta("boundary_segment", "") == row.id,
			"actual named scoring/live/dead face " + row.id)
		for foul: bool in [false, true]:
			await _flight(boundary, row, from, Vector3(-normal.x, 0, -normal.y) * 6, foul)
	for vertex: Vector2 in StadiumBoundaryGraph.VERTICES:
		var inside: Vector2 = vertex.lerp(Vector2(0, 10), 0.1)
		var outside: Vector2 = vertex + (vertex - inside).normalized()
		_check(not _ray(Vector3(inside.x, 0.6, inside.y),
			Vector3(outside.x, 0.6, outside.y)).is_empty(), "shared collider corner has no hole")
	for foul: bool in [false, true]:
		await _exit_flight(boundary, Vector3(23, 2, 22.7), Vector3(0, 0, 36),
			"SIDE_EXIT_DEAD", foul)
		await _exit_flight(boundary, Vector3(0, 4, 22.7), Vector3(0, 0, 36),
			"BACK_CLEAR", foul)
		await _exit_flight(boundary, Vector3(0, 2, -5.5), Vector3(0, 0, -36),
			"REAR_PERIMETER_DEAD", foul)
	await _capture_scene(property)
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro boundary prototype checks passed: "
			+ "six joined faces, precedence, exits and physical contacts.")
	get_tree().quit(0 if _failures == 0 else 1)


func _graph() -> void:
	var rows: Array[Dictionary] = StadiumBoundaryGraph.segments()
	_check(rows.size() == 6 and StadiumBoundaryGraph.contains(Vector2.ZERO), "closed template graph")
	for index in range(rows.size()):
		_check(rows[index].b == rows[(index + 1) % rows.size()].a, "shared exact graph endpoints")
		var corner: Vector2 = StadiumBoundaryGraph.outer_vertex(index)
		_check(StadiumProperty.contains("backyard", AABB(Vector3(corner.x, 0, corner.y),
			Vector3(0.001, 3.25, 0.001))), "full backing and joins fit actual land")
	_check(not StadiumBoundaryGraph.contains(Vector2(24, 10))
		and StadiumBoundaryGraph.contains(Vector2(8, 14)), "spectator sites and live sites are distinct")
	for sample: Array in [[0.0, "BACK-TERMINAL-01"], [23.0, "RETURN-R-01"],
		[-23.0, "RETURN-L-01"], [StadiumBoundaryGraph.BACK_HALF, "BACK-TERMINAL-01"],
		[StadiumBoundaryGraph.BACK_HALF + 0.001, "RETURN-R-01"],
		[-StadiumBoundaryGraph.BACK_HALF, "BACK-TERMINAL-01"]]:
		var event: Dictionary = StadiumBoundaryGraph.crossing(
			Vector3(sample[0], 0.6, 22), Vector3(sample[0], 0.6, 25))
		_check(not event.is_empty() and event.segment == sample[1], "back/return endpoint owner")
	for index in [0, 1, 2, 5]:
		var corner: Vector2 = StadiumBoundaryGraph.VERTICES[index]
		var inner: Vector2 = corner.lerp(Vector2(0, 10), 0.1)
		var outer: Vector2 = corner + (corner - inner)
		var event: Dictionary = StadiumBoundaryGraph.crossing(
			Vector3(inner.x, 0.6, inner.y), Vector3(outer.x, 0.6, outer.y))
		_check(event.get("segment") == ("REAR-DEAD-01" if index < 2 else
			"RETURN-R-01" if index == 2 else "RETURN-L-01"), "rear/side/return corner owner")
	_check(StadiumBoundaryGraph.crossing(Vector3.ZERO, Vector3(0, 1, 10)).is_empty(),
		"interior travel cannot invent a boundary event")
	_check(StadiumBoundaryGraph.crossing(Vector3.INF, Vector3.ZERO).is_empty(), "invalid path rejects")


func _resolver(foul: bool = false) -> BallPlayResolver:
	_outcomes.clear()
	var result: BallPlayResolver = BallPlayResolver.new()
	result.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
	result.play_resolved.connect(func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome))
	return result


func _rules() -> void:
	for foul: bool in [false, true]:
		for grounded: bool in [false, true]:
			if foul and grounded:
				continue
			for touched: bool in [false, true]:
				var resolver: BallPlayResolver = _resolver(foul)
				resolver.state.has_grounded = grounded
				resolver.state.defender_touched = touched
				resolver.state.raise_result_floor(BallPlayState.ResultFloor.DOUBLE)
				var event: Dictionary = {"segment": "SIDE-R-01", "role": "SIDE_RETURN_LIVE",
					"position": Vector3(16, 0.6, 8.7)}
				_check(StadiumBoundaryGraph.apply(resolver, event) and not resolver.state.dead
					and resolver.state.has_grounded == grounded and resolver.state.is_foul_play == foul
					and resolver.state.defender_touched == touched
					and resolver.state.result_floor == BallPlayState.ResultFloor.DOUBLE,
					"side rebound preserves classification, actual history and earned floor")
				event.role = "SIDE_EXIT_DEAD"
				_check(not StadiumBoundaryGraph.apply(resolver, event), "below-top exit role rejects")
				event.position.y = 2
				_check(StadiumBoundaryGraph.apply(resolver, event) and _outcomes.size() == 1
					and _outcomes[0].result == (BallPlayOutcome.Result.FOUL if foul else
					BallPlayOutcome.Result.DOUBLE), "side exit preserves a previously earned Double")
				_check(not StadiumBoundaryGraph.apply(resolver, event) and _outcomes.size() == 1,
					"later boundary event cannot change or duplicate a terminal outcome")
	for sample: Array in [[Vector3(0, 0.6, 22), Vector3(0, 0.6, 25), false, false,
		BallPlayOutcome.Result.TRIPLE], [Vector3(0, 0.6, 22), Vector3(0, 0.6, 25), true, false,
		BallPlayOutcome.Result.DOUBLE], [Vector3(0, 4, 22), Vector3(0, 4, 25), false, false,
		BallPlayOutcome.Result.HOME_RUN], [Vector3(23, 2, 22), Vector3(23, 2, 25), false, false,
		BallPlayOutcome.Result.SINGLE], [Vector3(23, 2, 22), Vector3(23, 2, 25), false, true,
		BallPlayOutcome.Result.FOUL], [Vector3(0, 1, -5), Vector3(0, 1, -7), false, false,
		BallPlayOutcome.Result.FOUL]]:
		var resolver: BallPlayResolver = _resolver(sample[3])
		resolver.state.has_grounded = sample[2]
		_check(StadiumBoundaryGraph.apply(resolver, StadiumBoundaryGraph.crossing(sample[0], sample[1]))
			and _outcomes.size() == 1 and _outcomes[0].result == sample[4], "exact terminal surface rule")


func _flight(boundary: StadiumBoundaryPrototype, row: Dictionary, from: Vector3,
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
	label.text = "BACKYARD • Perimeter blockout"
	label.position = Vector2(32, 24)
	label.add_theme_font_size_override("font_size", 28)
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for frame in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join("backyard-perimeter-blockout.png")) == OK, "actual candidate field saved")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _exit_flight(boundary: StadiumBoundaryPrototype, from: Vector3, velocity: Vector3,
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
		observed = StadiumBoundaryObserver.observe(resolver, previous, ball.global_position)
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


func _observer_rules() -> void:
	var resolver: BallPlayResolver = _resolver()
	var event: Dictionary = StadiumBoundaryObserver.observe(resolver,
		Vector3(23, 0.6, 22), Vector3(23, 0.6, 25))
	_check(event.get("role") == "SIDE_RETURN_LIVE" and not resolver.state.dead
		and resolver.state.result_floor == BallPlayState.ResultFloor.NONE,
		"foul-side return has no obsolete infinite back-wall award")
	for foul: bool in [false, true]:
		for touched: bool in [false, true]:
			resolver = _resolver(foul)
			resolver.state.defender_touched = touched
			StadiumBoundaryObserver.observe(resolver, Vector3(0, 2, 5), Vector3(0, 2, 22))
			_check(not resolver.state.dead and resolver.state.result_floor == (
				BallPlayState.ResultFloor.NONE if foul else BallPlayState.ResultFloor.SINGLE
				if touched else BallPlayState.ResultFloor.DOUBLE),
				"graph observation preserves original eligible scoring bands")
			StadiumBoundaryObserver.observe(resolver, Vector3(0, 2, 22), Vector3(0, 2, 25))
			_check(_outcomes.size() == 1 and _outcomes[0].result == (BallPlayOutcome.Result.FOUL
				if foul else BallPlayOutcome.Result.DOUBLE if touched else BallPlayOutcome.Result.TRIPLE),
				"new graph applies the original air/ground/touch wall table")
