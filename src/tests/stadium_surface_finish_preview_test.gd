extends "res://src/tests/stadium_recipe_physical_test.gd"
## Native whole-property finish previews; no active field or inventory migration.

var _caption: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	for row: Array in [["rough_dirt", "short", "", ""],
		["maintained_dirt", "short", "", ""], ["grass", "short", "", ""],
		["grass", "short", "ST-063b", "ST-063g"], ["grass", "long", "ST-063b", "ST-063g"],
		["grass", "short", "ST-063b", "ST-063h"], ["grass", "short", "ST-063b", "ST-063j"]]:
		var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
		add_child(property)
		_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
			"original unchanged substrate and collision")
		property.get_node("TemplateBackWall").free()
		var boundary: StadiumOffsetBoundaryBody = StadiumOffsetBoundaryBody.new()
		property.add_child(boundary)
		_check(boundary.build("offset_gables", "ST-024"), "same isolated reference wall")
		StadiumWallRenderQuality.attach(boundary)
		_check(StadiumRecipeFieldStyles.apply(property, boundary.graph,
			{"line": "", "grass": ""}, "", StadiumStock.new_club()), "exact independent foul endpoints")
		var finish: Node3D = StadiumSurfaceFinish.build(boundary.graph, row[0], row[1], row[2], row[3])
		_check(finish != null, "valid isolated finish")
		property.add_child(finish)
		_check(finish.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"surface finish does not imply terrain or grass physics")
		_shape = row[0] + "-" + row[1] + "-" + row[2] + "-" + row[3]
		_caption = ("Worn dirt lot" if row[0] == "rough_dirt" else "Maintained dirt" if (
			row[0] == "maintained_dirt") else row[1].capitalize() + " grass" + (
			" / 1.2m checkerboard / " + str({"ST-063g": "dirt paths",
			"ST-063h": "clay infield", "ST-063j": "raked dirt"}.get(row[3], "plain"))
			if not row[2].is_empty() else " / plain finish"))
		await _capture_scene(property)
		property.queue_free()
		await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro surface finish preview passed: isolated dirt, grass and smaller mowing.")
	get_tree().quit(0 if _failures == 0 else 1)


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
	label.text = "SURFACE STUDY • " + _caption
	label.position = Vector2(32, 24)
	label.add_theme_font_size_override("font_size", 28)
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for frame in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join("surface-" + _shape + ".png")) == OK,
		"actual candidate field saved")
