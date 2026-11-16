extends "res://src/tests/stadium_center_board_candidate_test.gd"
## Reuse the qualified native window/readback handshake without running its study scene.


func _ready() -> void:
	pass


func initialize() -> void:
	if DisplayServer.get_name() != "headless":
		await _settle_native_window()


func resize(extent: Vector2i) -> bool:
	if DisplayServer.get_name() == "headless":
		get_window().size = extent
		return true
	return await _resize_native_window(extent)


func capture(directory: String, label: String) -> bool:
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return true
	for frame in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var extent: Vector2i = get_window().size
	if image == null or image.is_empty() \
		or DisplayServer.window_get_size(get_window().get_window_id()) != extent \
		or image.get_size() != _expected_content_size(extent):
		return false
	DirAccess.make_dir_recursive_absolute(directory)
	var name: String = "%s-%dx%d.png" % [label, image.get_width(), image.get_height()]
	print("MOUNTED_NORMAL_CAPTURE window=", extent, " actual_content=", image.get_size(),
		" file=", name)
	return image.save_png(directory.path_join(name)) == OK
