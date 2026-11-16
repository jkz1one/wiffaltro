extends Node3D
## Four native material/height studies, each with the unchanged in-game ball visual.

var _failures: int = 0
var _capture_dir: String = ""

class PatchGraph:
	extends StadiumRecipeBoundary

	func polygon() -> PackedVector2Array:
		return PackedVector2Array([Vector2(2, 7), Vector2(4, 7), Vector2(4, 9), Vector2(2, 9)])


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	canvas.add_child(grid)
	var index: int = 0
	for length: String in StadiumGrassFinish.HEIGHTS:
		var container: SubViewportContainer = SubViewportContainer.new()
		container.custom_minimum_size = Vector2(640, 360)
		grid.add_child(container)
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(640, 360)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		container.add_child(viewport)
		_patch(viewport, length)
		var label: Label = Label.new()
		label.text = length.replace("_", " ").to_upper() + " • %dmm" % int(
			StadiumGrassFinish.HEIGHTS[length] * 1000)
		label.position = Vector2((index % 2) * 640 + 16, (index / 2) * 360 + 12)
		label.add_theme_font_size_override("font_size", 24)
		canvas.add_child(label)
		index += 1
	for frame in range(5):
		await get_tree().process_frame
	if not _capture_dir.is_empty():
		_check(DisplayServer.get_name() != "headless", "native grass study requires rendering")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(_capture_dir)
			_check(get_viewport().get_texture().get_image().save_png(
				_capture_dir.path_join("grass-height-study.png")) == OK, "native height study saved")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro grass closeup checks passed: "
			+ "four restrained visual heights and unchanged game ball visual.")
	get_tree().quit(0 if _failures == 0 else 1)


func _patch(viewport: SubViewport, length: String) -> void:
	var finish: Node3D = StadiumSurfaceFinish.build(PatchGraph.new(), "grass", length, "")
	_check(finish != null, "valid grass patch")
	viewport.add_child(finish)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	viewport.add_child(ball)
	# This is a static display: rest the unchanged 0.075m-radius game visual on the surface.
	# Its separate physical radius remains 0.0365m; no gameplay body is resized.
	ball.position = Vector3(3, 0.079, 8)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("17261e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c4cbb7")
	environment.environment.ambient_light_energy = 0.65
	viewport.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 0.75
	light.shadow_enabled = true
	viewport.add_child(light)
	var camera: Camera3D = Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(3, 0.65, 6.45)
	camera.look_at(Vector3(3, 0.015, 8))
	camera.fov = 62
	camera.near = 0.01
	camera.make_current()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
