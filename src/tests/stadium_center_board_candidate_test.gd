extends Node3D
## New-file candidate checks. Never registered in the production verification gate.

var _failures: int = 0
var _capture_dir: String = ""
var _captures_saved: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	if DisplayServer.get_name() == "headless":
		get_window().size = Vector2i(1280, 720)
	else:
		await _settle_native_window()
		await _resize_native_window(Vector2i(1280, 720))
	var frozen: Dictionary = _frozen()
	_check(StadiumCenterBoardCandidate.create() == null, "explicit candidate opt-in required")
	_check(not StadiumCenterBoardCandidate.inspect(null).ok, "null boundary rejects")
	var board: Node3D = StadiumCenterBoardCandidate.create(true)
	_check(board != null, "electronic-v2 instance builds")
	if board == null:
		get_tree().quit(1)
		return
	board.transform = StadiumCenterBoardCandidate.pose()
	add_child(board)
	_check(board.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"candidate creates no physical or trigger obstacle")
	_check(board.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"candidate contains no latent collision shapes")
	_bounds(board)
	_clearance()
	_identity(board)
	_readouts(board)
	_cameras(board)
	_check(_frozen() == frozen, "frozen saved contracts unchanged by the entire study")
	board.free()
	await _native_captures()
	_check(_frozen() == frozen, "native prototype captures preserve frozen saved contracts")
	if _failures == 0:
		print("Wiffaltro center board candidate passed: isolated bounds, readouts and frozen inputs.")
	get_tree().quit(0 if _failures == 0 else 1)


func _frozen() -> Dictionary:
	return {"sites": StadiumScoreboardSites.signature(),
		"models": StadiumScoreboardModels.signature(),
		"layout": StadiumScoreboardLayout.signature(),
		"catalog": StadiumScoreboardPurchases.signature(),
		"backyard": StadiumProperty.signature("backyard"),
		"site_rows": StadiumScoreboardSites.SITES.duplicate(true)}


func _bounds(board: Node3D) -> void:
	var actual: AABB
	var first: bool = true
	for mesh: MeshInstance3D in board.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = board.global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = local * mesh.get_aabb()
		actual = box if first else actual.merge(box)
		first = false
		var allowed: AABB = StadiumCenterBoardCandidate.CABINET_ENVELOPE \
			if board.get_node("Visual/ElectronicV2Cabinet").is_ancestor_of(mesh) \
			else StadiumCenterBoardCandidate.SUPPORT_ENVELOPE
		for index in range(8):
			_check(allowed.grow(0.0001).has_point(box.get_endpoint(index)),
				"all transformed model corners fit their reserved component: " + mesh.name)
	_check(actual.position.is_equal_approx(Vector3(-4.4, 0, -1.1)),
		"measured mesh minimum is exact")
	_check(actual.end.is_equal_approx(Vector3(4.4, 10.755, 1.1)),
		"measured mesh maximum is exact")
	print("CENTER_BOARD_LOCAL_MESH_BOUNDS ", actual)
	print("CENTER_BOARD_WORLD_RESERVATION ", board.transform * StadiumCenterBoardCandidate.ENVELOPE)


func _clearance() -> void:
	for shape: String in StadiumCenterBoardCandidate.SHAPES:
		var graph: StadiumRecipeBoundary = StadiumCenterBoardCandidate.graph_for(shape)
		var before: String = graph.signature()
		for eye: Vector3 in [Vector3(0, 1.5, -1), Vector3(0.18, 2.1, -3.38),
			Vector3(-0.18, 2.1, -3.38)]:
			var checked: Dictionary = StadiumCenterBoardCandidate.inspect(graph, "backyard", eye)
			_check(checked.ok, "all nine authored readout regions clear: " + shape)
			if checked.ok:
				_check(checked.outer_wall_setback >= 1.2999, "full joined-wall setback: " + shape)
				print("CENTER_BOARD_SETBACK ", shape, " ", checked.outer_wall_setback)
		_check(not StadiumCenterBoardCandidate.inspect(graph, "unknown").ok,
			"unknown property rejects")
		for start: Vector3 in [Vector3(0, 0, 10), Vector3(-5, 0, 12), Vector3(5, 0, 12)]:
			var clipped: Vector3 = graph.clip(start, Vector3(0, 0, 40))
			_check(graph.contains(Vector2(clipped.x, clipped.z)),
				"unchanged route stays on the live side of the support")
			_check(clipped.z < 29.65, "no defender route reaches the decorative support")
		_check(before == graph.signature(), "candidate never edits a boundary graph")


func _identity(board: Node3D) -> void:
	var original: Node3D = StadiumScoreboardModels.create("ST-090", "electronic-v2")
	var raised: Node3D = board.get_node("Visual/ElectronicV2Cabinet")
	_check(raised.position == Vector3(0, 2.4, 0), "existing art has only a rigid vertical lift")
	var retained: Array[Node3D] = []
	for source: Node3D in original.get_node("Visual").get_children():
		if String(source.name) in ["Support-1", "Support1", "Foot-1", "Foot1"]:
			_check(not raised.has_node("Visual/" + String(source.name)), "old floating feet removed")
			continue
		retained.append(source)
	var actual: Array[Node] = raised.get_node("Visual").get_children()
	_check(actual.size() == retained.size(), "only the four old support nodes were removed")
	# Unnamed Label3D instances receive unique generated names; compare stable child order.
	for index in range(mini(actual.size(), retained.size())):
		var source: Node3D = retained[index]
		var target: Node3D = actual[index] as Node3D
		_check(source.transform == target.transform, "all cabinet/readout transforms preserved")
		if source is MeshInstance3D:
			var target_mesh: MeshInstance3D = target as MeshInstance3D
			_check(target_mesh != null and source.get_aabb() == target_mesh.get_aabb(),
				"electronic-v2 mesh dimensions unchanged")
		elif source is Label3D:
			var target_label: Label3D = target as Label3D
			_check(target_label != null and source.text == target_label.text \
				and source.font_size == target_label.font_size \
				and source.pixel_size == target_label.pixel_size, "existing text styling preserved")
	original.free()


func _readouts(board: Node3D) -> void:
	var display: StadiumScoreboardTierDisplay = StadiumCenterBoardCandidate.display(board)
	var state: MatchState = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD CLUB")
	state.home_team.runs = 12
	state.balls = 2
	display.bind_match(state)
	_check(display.shown.home == 12 and display.details.balls == "2", "existing readout binds")
	state.home_team.runs = 13
	state.balls = 3
	for phase: int in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY]:
		state.phase = phase
		display._process(0)
		_check(display.shown.home == 12 and display.details.balls == "2", "whole display holds")
	state.phase = MatchState.Phase.PLAY_DEAD
	display._process(0)
	_check(display.shown.home == 13 and display.details.balls == "3", "safe state releases held data")
	display.bind_match(null)
	_check(display.shown.is_empty(), "unbound study has no stale match readout")


func _cameras(board: Node3D) -> void:
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	var director: MatchCameraDirector = MatchCameraDirector.new()
	for left: bool in [false, true]:
		director.set_batter_handedness(left)
		director.set_shot(MatchCameraDirector.Shot.BATTING)
		director.snap(camera)
		var slots: Dictionary = StadiumScoreboardTiers.readouts("electronic")
		slots.merge(StadiumScoreboardTiers.detail_slots("electronic"))
		for slot: Dictionary in slots.values():
			for x: float in [-0.5, 0.5]:
				for y: float in [-0.5, 0.5]:
					var point: Vector3 = board.global_transform * (slot.point \
						+ Vector3(x * slot.width, StadiumCenterBoardCandidate.LIFT + y * slot.height, 0))
					_check(not camera.is_position_behind(point), "readout faces both batting cameras")
					_check(get_viewport().get_visible_rect().grow(-16).has_point(
						camera.unproject_position(point)), "both-handed readout corners remain framed")
	camera.free()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _native_captures() -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var created: Error = DirAccess.make_dir_recursive_absolute(_capture_dir)
	_check(created == OK, "native prototype capture directory is writable")
	if created != OK:
		return
	var original_size: Vector2i = get_window().size
	var scene: PackedScene = load(
		"res://src/labs/stadium_center_board/stadium_center_board_study.tscn")
	for shape: String in StadiumCenterBoardCandidate.SHAPES:
		if not await _resize_native_window(Vector2i(1280, 720)):
			break
		var study: Node3D = scene.instantiate()
		study.set("wall_shape", shape)
		_check(study.get("enable_center_board") == true, "standalone preview opts in explicitly")
		add_child(study)
		var camera: Camera3D = study.get("_camera")
		var board: Node3D = study.get("_board")
		_check(camera != null and board != null and study.get_meta("stadium_candidate_only", false),
			"native capture builds only the isolated candidate study")
		if camera != null and board != null:
			await _capture_views(study, shape, Vector2i(1280, 720))
			if shape == "offset_gables":
				if await _resize_native_window(Vector2i(700, 400)):
					await _capture_views(study, shape, Vector2i(700, 400))
		study.free()
		await get_tree().process_frame
	await _resize_native_window(original_size)
	_check(_captures_saved == 18,
		"five native wall studies plus three deepest-shape small views saved")
	print("CENTER_BOARD_PROTOTYPE_CAPTURES ", _captures_saved)


func _capture_views(study: Node3D, shape: String, extent: Vector2i) -> void:
	var camera: Camera3D = study.get("_camera")
	var director: MatchCameraDirector = study.get("_director")
	study.call("_review_camera")
	await _capture_frame(camera, shape, "overview", extent)
	for left: bool in [false, true]:
		director.set_batter_handedness(left)
		director.set_shot(MatchCameraDirector.Shot.BATTING)
		director.snap(camera)
		await _capture_frame(camera, shape, "batting-left" if left else "batting-right", extent)


func _capture_frame(camera: Camera3D, shape: String, view: String, extent: Vector2i) -> void:
	# This entire path runs only on a real rendering display. Headless pure checks never wait
	# for frame_post_draw, and screenshots are static prototype views, not live-game evidence.
	for frame in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(camera.global_transform.is_finite(), "prototype camera transform is finite")
	_check(get_viewport().get_camera_3d() == camera, "capture uses the standalone study camera")
	var bounds: AABB = StadiumCenterBoardCandidate.pose() * StadiumCenterBoardCandidate.ENVELOPE
	var frame_rect: Rect2 = get_viewport().get_visible_rect().grow(-16)
	for index in range(8):
		var point: Vector3 = bounds.get_endpoint(index)
		var projected: Vector2 = camera.unproject_position(point)
		_check(projected.is_finite() and not camera.is_position_behind(point)
			and frame_rect.has_point(projected), "complete prototype reservation is framed: " + view)
	var image: Image = get_viewport().get_texture().get_image()
	var content: Vector2i = _expected_content_size(extent)
	_check(get_window().size == extent
		and DisplayServer.window_get_size(get_window().get_window_id()) == extent,
		"requested native window extent survives through capture")
	_check(not image.is_empty() and image.get_size() == content,
		"rendered content matches project stretch/aspect geometry")
	print("CENTER_BOARD_CAPTURE_SIZE requested_window=", extent,
		" actual_window=", get_window().size,
		" display_server=", DisplayServer.window_get_size(get_window().get_window_id()),
		" texture_size=", get_viewport().get_texture().get_size(), " expected_content=", content,
		" actual_content=", image.get_size(), " aspect=", get_window().content_scale_aspect)
	var file_name: String = "center-board-prototype-%s-%s-%dx%d.png" % [
		shape, view, image.get_width(), image.get_height()]
	var saved: Error = image.save_png(_capture_dir.path_join(file_name))
	_check(saved == OK, "native prototype capture saved: " + file_name)
	if saved == OK:
		_captures_saved += 1


func _settle_native_window() -> void:
	# Let the native window manager map and constrain the initial project window before
	# issuing our first explicit size. Fixed-fps frame counts alone are not elapsed time.
	var started: int = Time.get_ticks_msec()
	var prior: Vector2i = get_window().size
	var stable: int = 0
	for frame in range(180):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var actual: Vector2i = DisplayServer.window_get_size(get_window().get_window_id())
		stable = stable + 1 if actual == prior and get_window().size == actual else 0
		prior = actual
		if stable >= 8 and Time.get_ticks_msec() - started >= 150:
			return
	_check(false, "native initial window settles within the bounded startup handshake")


func _resize_native_window(extent: Vector2i) -> bool:
	var expected: Vector2i = _expected_content_size(extent)
	var stable: int = 0
	var actual: Vector2i = Vector2i.ZERO
	var window_size: Vector2i = Vector2i.ZERO
	var texture_size: Vector2 = Vector2.ZERO
	var content: Vector2i = Vector2i.ZERO
	for frame in range(120):
		# Reissue only while the manager has not acknowledged this exact request.
		if frame == 0 or (frame % 12 == 0 and get_window().size != extent):
			get_window().size = extent
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		actual = DisplayServer.window_get_size(get_window().get_window_id())
		window_size = get_window().size
		texture_size = get_viewport().get_texture().get_size()
		# Validate the same physical readback saved by _capture_frame. Texture metadata can
		# describe a logical viewport size and is retained separately for diagnostics.
		var image: Image = get_viewport().get_texture().get_image()
		content = image.get_size() if image != null else Vector2i.ZERO
		stable = stable + 1 if actual == extent and window_size == extent \
			and image != null and not image.is_empty() and content == expected else 0
		if stable >= 6:
			print("CENTER_BOARD_RESIZE requested_window=", extent, " window=", window_size,
				" display_server=", actual, " texture_size=", texture_size,
				" image_size=", content, " expected_content=", expected,
				" settled_frames=", frame + 1)
			return true
	print("CENTER_BOARD_RESIZE_FAILED requested_window=", extent, " window=", window_size,
		" display_server=", actual, " texture_size=", texture_size, " image_size=", content,
		" expected_content=", expected, " consecutive_valid_frames=", stable)
	_check(false, "native resize handshake did not establish requested window and content sizes")
	return false


func _expected_content_size(extent: Vector2i) -> Vector2i:
	var window: Window = get_window()
	var base: Vector2i = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height")))
	var mode: String = str(ProjectSettings.get_setting("display/window/stretch/mode", "disabled"))
	var aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect", "keep"))
	var modes: Dictionary = {"keep": Window.CONTENT_SCALE_ASPECT_KEEP,
		"ignore": Window.CONTENT_SCALE_ASPECT_IGNORE,
		"keep_width": Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH,
		"keep_height": Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT,
		"expand": Window.CONTENT_SCALE_ASPECT_EXPAND}
	_check(mode == "canvas_items"
		and window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		and base.x > 0 and base.y > 0 and window.content_scale_size == base,
		"capture derives content geometry from the actual canvas-items project settings")
	_check(modes.has(aspect) and window.content_scale_aspect == modes.get(aspect, -1)
		and window.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL,
		"runtime aspect/stretch matches the inspected project configuration")
	if base.x <= 0 or base.y <= 0:
		return Vector2i.ZERO
	# Window::_update_viewport_size floors the aspect-fitted screen rectangle for canvas_items.
	# A 700x400 keep-aspect window therefore renders 700x393 content, with letterbox margins.
	var desired: float = float(base.x) / base.y
	var actual: float = float(extent.x) / extent.y
	if aspect == "ignore" or is_equal_approx(desired, actual) or aspect == "expand":
		return extent
	if desired < actual and aspect != "keep_height":
		return Vector2i(floori(extent.y * desired), extent.y)
	if desired > actual and aspect != "keep_width":
		return Vector2i(extent.x, floori(extent.x / desired))
	return extent
