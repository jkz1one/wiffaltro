extends Node3D
## Isolated physical shape/visibility and graybox rendering; not whole-game placement acceptance.

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	var models: Array[Node3D] = []
	var expected: Array[AABB] = [
		AABB(Vector3(-0.175, 0, -0.175), Vector3(0.35, 0.50, 0.35)),
		AABB(Vector3(-0.35, 0, -0.4), Vector3(0.70, 0.95, 0.80)),
		AABB(Vector3(-0.30, 0, -0.18), Vector3(0.60, 0.88, 0.61))
	]
	for index in range(3):
		var id: String = StadiumCatalog.STARTERS[index]
		var model: Node3D = StadiumStarterModels.create(id)
		model.position.x = (index - 1) * 1.5
		add_child(model)
		models.append(model)
		_check(expected[index].grow(0.001).encloses(_bounds(model)), "authored visible envelope " + id)
		var surface_count: int = model.get_node("Collision").get_child_count()
		_check(surface_count >= 2, "separate recognizable collision parts " + id)
		for body: StaticBody3D in model.get_node("Collision").get_children():
			_check(body.get_meta("stadium_item") == id and body.get_child_count() == 1,
				"stable item and one explicitly authored shape per named surface")
			_check(body.get_meta("surface_role") == (
				"RECEIVER_CONTAINMENT_FOUL" if id == "ST-079" else "LIVE_RICOCHET"),
				"different chair roles never substituted")
		var label: Label3D = Label3D.new()
		label.text = id + "\n" + {"ST-001": "Orange traffic cone",
			"ST-003": "Woven folding\nlawn chair", "ST-079": "Plastic backstop\nchair"}[id]
		label.position = model.position + Vector3(0, 1.28, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 42
		label.pixel_size = 0.0028
		add_child(label)
	_check(StadiumStarterModels.create("ST-080") == null, "no spectator chair substituted")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var chair: Node3D = models[2]
	var hit: Dictionary = _ray(chair, Vector3(0, 0.65, 1), Vector3(0, 0.65, -0.4))
	_check(not hit.is_empty() and hit.collider.get_meta("surface_id") == "ST079_BACK",
		"actual physics ray hits chair back surface")
	_check(_ray(chair, Vector3(0, 1.1, 1), Vector3(0, 1.1, -0.4)).is_empty(),
		"above-chair path has no stretched invisible receiver")
	StadiumStarterModels.pitch_view(chair, true)
	_check(not chair.get_node("Visual").visible and not _ray(
		chair, Vector3(0, 0.65, 1), Vector3(0, 0.65, -0.4)).is_empty(),
		"batting-view hide preserves physical surfaces")
	var rest: Transform3D = chair.get_node("Collision/ST079_BACK").transform
	for step in range(29):
		StadiumStarterModels.receiver_rock(chair, 0.1, step * 0.01)
		_check(absf(chair.get_node("Visual").rotation.z) <= deg_to_rad(6.001), "bounded chair rock")
		_check(chair.get_node("Collision/ST079_BACK").transform == rest, "wobble never moves collider")
	_check(is_zero_approx(chair.get_node("Visual").rotation.z), "chair settles within 0.28 seconds")
	StadiumStarterModels.pitch_view(chair, false)
	_check(_ray(models[1], Vector3(0, 0.25, 1), Vector3(0, 0.25, -1)).is_empty(),
		"no full invisible lawn-chair box under the seat")
	_check(not _ray(models[0], Vector3(0, 0.25, 1), Vector3(0, 0.25, -1)).is_empty(),
		"tapered cone has actual explicit collision")
	_scene()
	for frame in range(4):
		await get_tree().process_frame
	if not _capture_dir.is_empty():
		_check(DisplayServer.get_name() != "headless", "native graybox capture requires a display")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(_capture_dir)
			var image: Image = get_viewport().get_texture().get_image()
			_check(image.save_png(_capture_dir.path_join("stadium-starter-grayboxes.png")) == OK,
				"native graybox image saved")
	if _failures == 0:
		print("Wiffaltro stadium model checks passed: "
			+ "bounds, named collisions and independent visibility.")
	get_tree().quit(0 if _failures == 0 else 1)


func _ray(model: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		model.global_transform * from, model.global_transform * to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _bounds(model: Node3D) -> AABB:
	var result: AABB
	var first: bool = true
	for mesh: MeshInstance3D in model.get_node("Visual").get_children():
		var bounds: AABB = mesh.transform * mesh.mesh.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result


func _scene() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(7, 7)
	ground.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("314a40")
	ground.material_override = material
	add_child(ground)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.shadow_enabled = true
	light.light_energy = 0.70
	add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("111e1c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.35
	add_child(environment)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(2.6, 2.2, 4.2)
	camera.fov = 50
	add_child(camera)
	camera.look_at(Vector3(0, 0.45, 0))
	camera.make_current()
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var title: Label = Label.new()
	title.text = "STADIUM STARTERS • WORKING GRAYBOX\n" \
		+ "Independent models; not installed into live seasons."
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 22)
	canvas.add_child(title)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
