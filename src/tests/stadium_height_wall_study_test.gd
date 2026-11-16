extends "res://src/tests/stadium_wall_models_test.gd"
## Isolated art envelope review. No mixed-height gameplay or inventory conversion claim.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	for shape: String in StadiumHeightWallStudy.SHAPES:
		for item: String in StadiumWallRecipes.BACK_IDS:
			var rows: Array[Dictionary] = StadiumHeightWallStudy.rows(shape, item)
			_check(rows.size() == (25 if shape == "left_loft" else 26), "fixed art bay count")
			_check(rows[0].a.is_equal_approx(Vector2(StadiumWallRecipes.BACK_X, 23.4))
				and rows[-1].b.is_equal_approx(Vector2(-StadiumWallRecipes.BACK_X, 23.4)),
				"retained side-return joints")
			_validate(rows)
			_check(StadiumWallRecipes.back(shape, item).is_empty()
				and StadiumRecipeBoundary.create(shape) == null,
				"art candidate cannot enter a frozen saved runtime factory")
	_check(StadiumHeightWallStudy.create("ST-022", 2, 3.25) == null
		and StadiumHeightWallStudy.create("ST-024", 1.234, 3.25) == null
		and StadiumHeightWallStudy.create("ST-024", 2, 4) == null,
		"only authored material, width and height combinations are accepted")
	await _capture()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro height wall study passed: fixed original art, no runtime activation.")
	get_tree().quit(0 if _failures == 0 else 1)


func _validate(rows: Array[Dictionary]) -> void:
	var sockets: Array[String] = []
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		_check(not sockets.has(row.socket), "unique art bay")
		sockets.append(row.socket)
		if index > 0:
			_check(rows[index - 1].b.distance_to(row.a) < 0.00001, "closed contiguous joins")
		var size: Vector3 = Vector3(row.width, row.height, 0.35)
		_check(absf(row.a.distance_to(row.b) - size.x) < 0.00001, "fixed width matches face")
		var placement: Transform3D = StadiumWallRecipes.placement(row)
		_check(placement.basis.get_scale().is_equal_approx(Vector3.ONE), "no node scaling")
		_check((placement * Vector3(-size.x / 2, 0, 0)).distance_to(
			Vector3(row.a.x, 0, row.a.y)) < 0.00001, "literal endpoints align")
		var panel: Node3D = StadiumHeightWallStudy.create(row.item, row.width, row.height)
		_check(panel != null and panel.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"art-only assembly has no game collision")
		var envelope: AABB = AABB(Vector3(-size.x / 2, 0, -size.z), size).grow(0.00001)
		for mesh: MeshInstance3D in panel.find_children("*", "MeshInstance3D", true, false):
			_bounds(mesh.get_aabb(), mesh.transform, envelope)
		for mesh: MultiMeshInstance3D in panel.find_children("*", "MultiMeshInstance3D", true, false):
			var authored: Array = mesh.get_meta("authored_transforms")
			for instance in range(mesh.multimesh.instance_count):
				_bounds(mesh.multimesh.mesh.get_aabb(), authored[instance], envelope)
				if DisplayServer.get_name() != "headless":
					_check(mesh.multimesh.get_instance_transform(instance).is_equal_approx(
						authored[instance]), "native instances match authored transforms")
		for corner in range(8):
			var point: Vector3 = placement * envelope.get_endpoint(corner)
			_check(absf(point.x) < 28 and point.z > -8 and point.z < 32,
				"full mesh envelope stays within the property")
		panel.free()


func _capture() -> void:
	if _capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	get_window().size = Vector2i(1280, 720)
	for shape: String in StadiumHeightWallStudy.SHAPES:
		for item: String in StadiumWallRecipes.BACK_IDS:
			var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
			add_child(property)
			_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
				"retained original substrate for art preview")
			property.get_node("TemplateBackWall").free()
			StadiumWallRenderQuality.attach(property)
			var graph: StadiumRecipeBoundary = StadiumHeightWallStudy.outline(shape)
			_check(StadiumRecipeFieldStyles.apply(property, graph,
				{"line": "", "grass": ""}, "", StadiumStock.new_club()), "actual outline foul rays")
			property.add_child(StadiumSurfaceFinish.build(graph, "grass", "short", "ST-063b", "ST-063g"))
			for row: Dictionary in StadiumHeightWallStudy.rows(shape, item):
				var panel: Node3D = StadiumHeightWallStudy.create(row.item, row.width, row.height)
				panel.transform = StadiumWallRecipes.placement(row)
				property.add_child(panel)
			await _show(property, shape + "-" + item)
			property.queue_free()
			await get_tree().process_frame


func _show(property: Node3D, title: String) -> void:
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
	label.text = "WALL ART STUDY / " + title
	label.position = Vector2(32, 24)
	label.add_theme_font_size_override("font_size", 28)
	property.add_child(label)
	for frame in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join(title + ".png")) == OK, "native art preview saved")
