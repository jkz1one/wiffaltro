extends Node
## Bounded independent r1/r2 native pixel equivalence, not a daylight certificate.
## Same exact cameras/lights/native content; both assemblies exist in separate worlds.

var _failures: int = 0
var _pairs: int = 0
var _capture_dir: String = ""
var _hidden_controls: int = 0
var _visible_controls: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--npc-r2-native-dir="):
			_capture_dir = argument.trim_prefix("--npc-r2-native-dir=")
	if DisplayServer.get_name() == "headless":
		push_error("Candidate r2 native correspondence requires a real rendering backend")
		get_tree().quit(1)
		return
	for id: String in ["AY-01", "AE-01", "AC-01"]:
		for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 393)]:
			await _venue(id, extent)
			if _failures > 0:
				await TestAudioDrain.finish(get_tree())
				get_tree().quit(1)
				return
	_check(
		_hidden_controls > 0 and _visible_controls == 12,
		"both canonical hidden-to-visible and visible-to-hidden controls executed"
	)
	_check(_pairs == 24, "all 24 independent native correspondence pairs were rendered")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro candidate NPC r2 native passed: 24 exact retained pixel pairs.")
	get_tree().quit(0 if _failures == 0 else 1)


func _venue(id: String, extent: Vector2i) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.set_meta("stadium_npc_retained_lab_only", true)
	var old: StadiumNpcRetainedProperty = StadiumNpcRetainedRuntime._stage(lab, id, 1)
	var candidate: StadiumNpcRetainedProperty = StadiumNpcCandidateRuntimeV2._stage(lab, id, 2)
	_check(old != null and candidate != null, "authentic independent native stages " + id)
	if old == null or candidate == null:
		if old != null:
			old.free()
		if candidate != null:
			candidate.free()
		lab.free()
		return
	var old_geometry: PackedByteArray = var_to_bytes(StadiumNpcRetainedGeometry._geometry(old))
	var new_geometry: PackedByteArray = var_to_bytes(
		StadiumNpcRetainedGeometry._geometry(candidate)
	)
	# Independent expected visibility comes from untouched r1 nodes before any viewport/setup.
	var expected_visibility: Dictionary = _visibility_map(old)
	_check(
		_visibility_map(candidate) == expected_visibility,
		"complete r1/r2 local/effective visibility and layer maps match exactly"
	)
	var first: SubViewport = _viewport(extent, old, expected_visibility)
	var second: SubViewport = _viewport(extent, candidate, expected_visibility)
	_visibility_controls(old, expected_visibility, first.get_node("Camera"))
	_visibility_controls(candidate, expected_visibility, second.get_node("Camera"))
	var points: Array[Vector3] = [
		Vector3(0, 18, -20), Vector3(-24, 12, 18), Vector3(24, 12, 18), Vector3(0, 15, 47)
	]
	for position: Vector3 in points:
		for viewport: SubViewport in [first, second]:
			var camera: Camera3D = viewport.get_node("Camera")
			camera.position = position
			camera.look_at(Vector3(0, 1, 12), Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var a: Image = first.get_texture().get_image()
		var b: Image = second.get_texture().get_image()
		if not _pair(a, b, id, extent, position):
			break
	_check(
		var_to_bytes(StadiumNpcRetainedGeometry._geometry(old)) == old_geometry,
		"native camera changes preserve every retained rendered/physical node value"
	)
	_check(
		var_to_bytes(StadiumNpcRetainedGeometry._geometry(candidate)) == new_geometry,
		"native camera changes preserve every candidate rendered/physical node value"
	)

	first.free()
	second.free()
	lab.free()


func _viewport(
	extent: Vector2i, property: StadiumNpcRetainedProperty, expected_visibility: Dictionary
) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = extent
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	property.set_process(false)
	viewport.add_child(property)
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 60
	# Rendering layers are not the camera director's physics-ray collision mask (80).
	# Preserve every actual mesh layer and use Camera3D's standard all-layer visibility.
	camera.cull_mask = 0xfffff
	viewport.add_child(camera)
	camera.make_current()
	_check(
		viewport.get_camera_3d() == camera and camera.is_current(),
		"the actual viewport camera is current"
	)
	_check(
		(
			property.get_world_3d() == viewport.find_world_3d()
			and camera.get_world_3d() == viewport.find_world_3d()
		),
		"actual property and active camera inhabit the same isolated rendering world"
	)
	_check(
		_visibility_valid(property, expected_visibility, camera),
		"canonical visibility preserved and every visible visual included in render mask"
	)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("668da5")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.75
	viewport.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.0
	viewport.add_child(sun)
	return viewport


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _pair(a: Image, b: Image, id: String, extent: Vector2i, position: Vector3) -> bool:
	var dimensions: bool = (
		a != null and b != null and a.get_size() == extent and b.get_size() == extent
	)
	_check(dimensions, "actual native content dimensions match " + str(extent))
	if not dimensions:
		return false
	# Keep diagnostic images even on a failure; only successful nonblank pairs gain a pair record.
	if not _capture_dir.is_empty():
		_check(
			DirAccess.make_dir_recursive_absolute(_capture_dir) == OK,
			"native capture directory exists"
		)
		for row: Array in [[a, "r1"], [b, "r2"]]:
			var path: String = _capture_dir.path_join(
				"%s-%dx%d-%d-%s.png" % [id.to_lower(), extent.x, extent.y, _pairs, row[1]]
			)
			_check(row[0].save_png(path) == OK, "actual native PNG saved " + path)
	var counts: Array[int] = []
	var nonblank: bool = true
	for actual: Image in [a, b]:
		var colors: Dictionary = {}
		for y in range(0, extent.y, 17):
			for x in range(0, extent.x, 17):
				colors[actual.get_pixel(x, y)] = true
		counts.append(colors.size())
		nonblank = nonblank and colors.size() > 16
		_check(colors.size() > 16, "visible geometry, not a blank/background equality")
	if _failures > 0:
		print(
			(
				"NPC_R2_PIXEL_DIAGNOSTIC rejected_nonblank "
				if not nonblank
				else "NPC_R2_PIXEL_DIAGNOSTIC rejected_setup_or_capture "
			),
			id,
			" ",
			extent,
			" camera=",
			position,
			" sampled_color_counts=",
			counts
		)
		return false
	var exact: bool = a.get_format() == b.get_format() and a.get_data() == b.get_data()
	_check(exact, "exact r1/r2 native pixels " + id + " " + str(extent) + " " + str(position))
	if not exact:
		return false
	print(
		"NPC_R2_PIXEL_PAIR ",
		JSON.stringify(
			{
				"id": id,
				"extent": [extent.x, extent.y],
				"camera": [position.x, position.y, position.z],
				"sampled_color_counts": counts,
				"r1": a.get_data().hex_encode().sha256_text(),
				"r2": b.get_data().hex_encode().sha256_text()
			},
			"",
			true,
			true
		)
	)
	_pairs += 1
	return true


func _visibility_map(root: Node) -> Dictionary:
	var result: Dictionary = {}
	_collect_visibility(root, "", true, result)
	return result


func _collect_visibility(node: Node, path: String, inherited: bool, result: Dictionary) -> void:
	var effective: bool = inherited
	if node is Node3D:
		effective = inherited and node.visible
		result[path] = {
			"local": node.visible,
			"effective": effective,
			"class": node.get_class(),
			"layers": node.layers if node is GeometryInstance3D else -1
		}
	for index in range(node.get_child_count()):
		_collect_visibility(node.get_child(index), path + "/" + str(index), effective, result)


func _visibility_valid(root: Node, expected: Dictionary, camera: Camera3D) -> bool:
	if _visibility_map(root) != expected:
		return false
	var rendered: int = 0
	for path: String in expected:
		var node: Node = _indexed_node(root, path)
		if node == null:
			return false
		if node is GeometryInstance3D:
			if node.is_visible_in_tree() != expected[path].effective:
				return false
			if expected[path].effective:
				if node.layers & camera.cull_mask == 0:
					return false
				rendered += 1
	return rendered > 0


func _indexed_node(root: Node, path: String) -> Node:
	var node: Node = root
	for component: String in path.split("/", false):
		var index: int = int(component)
		if index < 0 or index >= node.get_child_count():
			return null
		node = node.get_child(index)
	return node


func _visibility_controls(root: Node, expected: Dictionary, camera: Camera3D) -> void:
	var hidden_done: bool = false
	var visible_done: bool = false
	for path: String in expected:
		var node: Node = _indexed_node(root, path)
		if not node is GeometryInstance3D:
			continue
		var prior: bool = node.visible
		if not prior and not hidden_done:
			node.visible = true
			_check(
				not _visibility_valid(root, expected, camera),
				"canonical hidden template made visible is refused against independent map"
			)
			node.visible = prior
			hidden_done = true
			_hidden_controls += 1
		elif expected[path].effective and not visible_done:
			node.visible = false
			_check(
				not _visibility_valid(root, expected, camera),
				"canonical visible geometry made hidden is refused against independent map"
			)
			node.visible = prior
			visible_done = true
			_visible_controls += 1
	_check(
		visible_done and _visibility_valid(root, expected, camera),
		"exact canonical visibility restores after real negative controls"
	)
