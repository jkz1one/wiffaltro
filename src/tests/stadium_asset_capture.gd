class_name StadiumAssetCapture
extends RefCounted
## Native diagnostic views, never a gameplay camera or readiness certificate.


static func directory() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			return argument.trim_prefix("--ui-capture-dir=")
	return ""


static func save(host: Node3D, bounds: AABB, name_value: String,
	direction: Vector3 = Vector3(1, 0.65, 1)) -> bool:
	var folder: String = directory()
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		return true
	DirAccess.make_dir_recursive_absolute(folder)
	host.get_window().size = Vector2i(1280, 720)
	var rig: Node3D = Node3D.new()
	host.add_child(rig)
	StadiumWallRenderQuality.attach(rig)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("263b37")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.7
	rig.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	rig.add_child(light)
	var camera: Camera3D = Camera3D.new()
	rig.add_child(camera)
	var center: Vector3 = bounds.get_center()
	camera.position = center + direction.normalized() * bounds.size.length() * 2
	camera.look_at(center)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = bounds.size.length()
	camera.current = true
	for frame in range(8):
		await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: Error = host.get_viewport().get_texture().get_image().save_png(
		folder.path_join(name_value + ".png"))
	rig.queue_free()
	await host.get_tree().process_frame
	return result == OK
