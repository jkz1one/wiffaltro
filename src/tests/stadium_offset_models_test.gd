extends "res://src/tests/stadium_wall_models_test.gd"
## New fixed closures reuse the original material builders without altering frozen old spans.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	for item: String in StadiumWallRecipes.BACK_IDS:
		var rows: Array[Dictionary] = StadiumOffsetWallRecipes.back(item)
		_check(rows.size() == 27, "exact twenty-seven candidate back copies")
		_check(rows[0].a.is_equal_approx(Vector2(StadiumWallRecipes.BACK_X, 23.4))
			and rows[-1].b.is_equal_approx(Vector2(-StadiumWallRecipes.BACK_X, 23.4)),
			"candidate retains side-return joints")
		_validate(rows)
		for span: String in StadiumOffsetWallRecipes.LENGTHS:
			if span != "full":
				_check(StadiumWallPanelModels.create(item, span) == null,
					"new fixed closures cannot impersonate the frozen original model catalog")
	_check(StadiumOffsetWallModels.create("ST-022", "full") == null
		and StadiumOffsetWallModels.create("ST-024", "custom") == null,
		"candidate does not allow arbitrary scaling or side-panel conversion")
	await _capture()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro offset model checks passed: exact candidate spans and all material bounds.")
	get_tree().quit(0 if _failures == 0 else 1)


func _validate(rows: Array[Dictionary]) -> void:
	var sockets: Array[String] = []
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		_check(not sockets.has(row.socket), "unique exact-copy socket")
		sockets.append(row.socket)
		if index > 0:
			_check(rows[index - 1].b.distance_to(row.a) < 0.00001, "closed contiguous joins")
		var size: Vector3 = StadiumOffsetWallModels.dimensions(row.item, row.span)
		_check(absf(row.a.distance_to(row.b) - size.x) < 0.00001, "authored span fits without scaling")
		var placement: Transform3D = StadiumWallRecipes.placement(row)
		_check(placement.basis.get_scale().is_equal_approx(Vector3.ONE), "unit placement basis")
		_check((placement * Vector3(-size.x / 2, 0, 0)).distance_to(
			Vector3(row.a.x, 0, row.a.y)) < 0.00001, "panel endpoints share exact face")
		var inward: Vector3 = placement.basis.z
		_check(inward.dot(Vector3(0, 0, 8) - placement.origin) > 0, "play face points inward")
		var panel: Node3D = StadiumOffsetWallModels.create(row.item, row.span)
		var envelope: AABB = AABB(Vector3(-size.x / 2, 0, -size.z), size).grow(0.00001)
		for mesh: MeshInstance3D in panel.find_children("*", "MeshInstance3D", true, false):
			_bounds(mesh.get_aabb(), mesh.transform, envelope)
		for mesh: MultiMeshInstance3D in panel.find_children("*", "MultiMeshInstance3D", true, false):
			var authored: Array = mesh.get_meta("authored_transforms")
			for instance in range(mesh.multimesh.instance_count):
				_bounds(mesh.multimesh.mesh.get_aabb(), authored[instance], envelope)
				if DisplayServer.get_name() != "headless":
					_check(mesh.multimesh.get_instance_transform(instance).is_equal_approx(
						authored[instance]), "native instancing matches authored transform")
		var collision: CollisionShape3D = panel.get_node("PanelCollision/CollisionShape3D")
		_check(collision.shape.size.is_equal_approx(size), "continuous solid wall despite visual seams")
		panel.free()


func _capture() -> void:
	if _capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	get_window().size = Vector2i(1280, 720)
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("202e37")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("d5ddca")
	world.environment.ambient_light_energy = 0.65
	add_child(world)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -25, 0)
	add_child(light)
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 57
	camera.position = Vector3(0, 45, -32)
	camera.look_at(Vector3(0, 0, 12))
	camera.make_current()
	var label: Label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)
	for item: String in StadiumWallRecipes.BACK_IDS:
		for shape: String in ["offset_gables"]:
			var assembly: Node3D = Node3D.new()
			add_child(assembly)
			StadiumWallRenderQuality.attach(assembly)
			var rows: Array[Dictionary] = StadiumOffsetWallRecipes.back(item)
			rows.append_array(StadiumWallRecipes.side(false))
			rows.append_array(StadiumWallRecipes.side(true))
			for row: Dictionary in rows:
				var panel: Node3D = StadiumOffsetWallModels.create(row.item, row.span) if (
					StadiumWallRecipes.BACK_IDS.has(row.item)) else StadiumWallPanelModels.create(
						row.item, row.span)
				panel.transform = StadiumWallRecipes.placement(row)
				assembly.add_child(panel)
			label.text = item + " | " + shape + " | fixed-span authoring prototype"
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_check(get_viewport().get_texture().get_image().save_png(
				_capture_dir.path_join(item + "-" + shape + ".png")) == OK, "native assembly captured")
			assembly.queue_free()
			await get_tree().process_frame

	await _showroom(camera, label)
