extends Node3D
## Actual property seating; synthetic authoring stock is not a real career grant.

var _failures: int = 0
var _capture_dir: String = ""
var _outcomes: Array[BallPlayOutcome] = []


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var stock: StadiumStock = StadiumStock.new_club()
	var chairs: Dictionary = stock.quote("ST-080", 4, {"seasons": 3, "wins": 8}, "seat-fixture")
	_check(chairs.ok, "explicit synthetic chair fixture")
	stock = StadiumStock.from_data(chairs.state)
	var benches: Dictionary = stock.quote("ST-027", 1, {"seasons": 3, "wins": 8}, "bench-fixture")
	_check(benches.ok, "explicit synthetic bleacher fixture")
	stock = StadiumStock.from_data(benches.state)
	var mixed: Array = [{"copy": "purchase:seat-fixture:2", "site": "SC-R1"},
		{"copy": "purchase:seat-fixture:3", "site": "SC-R2"},
		{"copy": "purchase:bench-fixture:0", "site": "SIDE-SEAT-L"}]
	_contracts(stock, mixed)
	for id: String in ["ST-080", "ST-027"]:
		var model: Node3D = StadiumSeatingModels.create(id)
		add_child(model)
		_check(StadiumSeatingLayout.envelope(id).grow(0.001).encloses(_bounds(model, model)),
			"actual occupied model fits its complete authored envelope " + id)
		_check(model.get_node("Visual").find_children("CrowdAnchor*", "Node3D", false, false).size()
			== (1 if id == "ST-080" else 10), "represented audience anchors belong to the parent item")
		for body: Node in model.get_node("Collision").get_children():
			_check(body.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL",
				"seating never borrows live-obstacle or receiver rules")
		model.queue_free()
	await get_tree().process_frame
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"actual unchanged Backyard dimensions")
	_check(StadiumBoundaryRuntime.assemble(property) != null, "complete protective field boundary")
	var seating: StadiumSeatingPrototype = StadiumSeatingPrototype.new()
	property.add_child(seating)
	_check(seating.build(mixed, stock), "independent left bleacher/right chairs arrangement")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _after_terminal(seating)
	await _capture(property, seating)
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro seating checks passed: "
			+ "owned identities, measured sites, storage preview and post-terminal contacts.")
	get_tree().quit(0 if _failures == 0 else 1)


func _contracts(stock: StadiumStock, mixed: Array) -> void:
	var before: Array = [{"copy": "purchase:seat-fixture:0", "site": "SC-L1"},
		{"copy": "purchase:seat-fixture:1", "site": "SC-L2"},
		{"copy": "purchase:seat-fixture:2", "site": "SC-R1"},
		{"copy": "purchase:seat-fixture:3", "site": "SC-R2"}]
	var owned: Dictionary = stock.to_data()
	var preview: Dictionary = StadiumSeatingLayout.preview(before, mixed, stock)
	_check(preview.ok and preview.cost == 0 and preview.live_units == 0
		and preview.stored == ["purchase:seat-fixture:0", "purchase:seat-fixture:1"],
		"left bleacher previews only its same-side chairs going into free storage")
	_check(stock.to_data() == owned, "authoring preview never consumes or duplicates owned copies")
	var conflict: Array = mixed.duplicate(true)
	conflict.push_front(before[0])
	_check(not StadiumSeatingLayout.validate(conflict, stock).ok,
		"a side cannot simultaneously contain chairs and bleachers")
	_check(not StadiumSeatingLayout.validate([
		{"copy": "starter-v1:ST-003", "site": "SC-L1"}], stock).ok,
		"live lawn chair does not become spectator inventory")
	_check(not StadiumSeatingLayout.validate([
		{"copy": "starter-v1:ST-079", "site": "SC-L1"}], stock).ok,
		"backstop chair does not become spectator inventory")
	var third: Array = [{"copy": "purchase:seat-fixture:0", "site": "SC-L3"}]
	_check(not StadiumSeatingLayout.validate(third, stock, "backyard").ok
		and StadiumSeatingLayout.validate(third, stock, "expanded").ok,
		"third socket needs the higher property despite physically fitting inside the old ground")
	var removed: Array = mixed.slice(0, 2)
	var store: Dictionary = StadiumSeatingLayout.preview(mixed, removed, stock)
	_check(store.ok and store.stored == ["purchase:bench-fixture:0"]
		and store.placements.size() == 2, "removing bleachers never automatically recreates old chairs")
	_check(StadiumSeatingModels.create("ST-079") == null
		and StadiumSeatingModels.create("ST-051") == null, "four chair identities remain separate")


func _after_terminal(seating: StadiumSeatingPrototype) -> void:
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID))
	resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome))
	_check(not StadiumSurfaceRules.apply(resolver, "DECORATIVE_AFTER_TERMINAL", "seat", Vector3.ZERO),
		"decorative furniture cannot itself create a live award")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	var contacts: Array[Dictionary] = []
	ball.body_entered.connect(func(body: Node) -> void:
		if seating.is_ancestor_of(body):
			contacts.append({"ended": resolver.state.dead, "copy": body.get_meta("owned_copy", "")})
			StadiumSurfaceRules.apply(resolver, body.get_meta("surface_role", ""),
				body.get_meta("owned_copy", ""), ball.global_position))
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(-17, 1.9, 12.5)
	launch.velocity = Vector3(-18, 0, 0)
	ball.launch(launch)
	var previous: Vector3 = launch.position
	for frame in range(120):
		await get_tree().physics_frame
		StadiumBoundaryObserver.observe(resolver, previous, ball.global_position)
		previous = ball.global_position
		if not contacts.is_empty():
			break
	_check(not contacts.is_empty() and contacts[0].ended
		and contacts[0].copy == "purchase:bench-fixture:0",
		"actual ball reaches the seating only after its side exit ended play")
	_check(_outcomes.size() == 1 and _outcomes[0].result == BallPlayOutcome.Result.SINGLE,
		"post-terminal furniture bounce cannot add another result or crowd-income bonus")
	ball.queue_free()
	await get_tree().physics_frame


func _bounds(root: Node3D, node: Node) -> AABB:
	var result: AABB
	var first: bool = true
	if node is MeshInstance3D:
		result = root.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		first = false
	for child: Node in node.get_children():
		var box: AABB = _bounds(root, child)
		if box.size.is_zero_approx():
			continue
		result = box if first else result.merge(box)
		first = false
	return result


func _capture(property: Node3D, seating: StadiumSeatingPrototype) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "seating review requires native rendering")
	if DisplayServer.get_name() == "headless":
		return
	get_window().size = Vector2i(1280, 720)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("142520")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.45
	property.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_energy = 0.7
	light.shadow_enabled = true
	property.add_child(light)
	var camera: Camera3D = Camera3D.new()
	property.add_child(camera)
	camera.make_current()
	var label: Label = Label.new()
	label.position = Vector2(30, 22)
	label.add_theme_font_size_override("font_size", 28)
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for item: Array in [["bleachers", "purchase:bench-fixture:0", Vector3(6, 3, 5)],
		["spectator-chair", "purchase:seat-fixture:2", Vector3(-1.6, 1.2, 1.5)]]:
		var model: Node3D = seating.objects[item[1]]
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 48
		camera.position = model.position + item[2]
		camera.look_at(model.position + Vector3(0, 0.7, 0))
		label.text = "SEATING BLOCKOUT • " + str(item[0])
		await _shot(item[0])
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 48
	camera.position = Vector3(-28, 38, -22)
	camera.look_at(Vector3(0, 0, 11))
	label.text = "BACKYARD • Mixed seating at its actual sites"
	await _shot("mixed-seating-property")


func _shot(name_value: String) -> void:
	for frame in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join(name_value + ".png")) == OK, "actual seating image saved")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
