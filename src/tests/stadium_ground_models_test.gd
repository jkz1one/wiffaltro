extends Node3D
## Visual-only surface prototypes on the real property; synthetic ownership is not a grant.

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_subtraction()
	var stock: StadiumStock = StadiumStock.new_club()
	var ids: Array = StadiumGroundModels.IDS.duplicate()
	ids.append_array(StadiumFieldStyleModels.CHANNELS.grass)
	ids.append("ST-062b")
	for id: String in ids:
		var quote: Dictionary = stock.quote(id, 1, {"seasons": 20, "wins": 100}, id)
		_check(quote.ok, "synthetic authoring entitlement " + id)
		stock = StadiumStock.from_data(quote.state)
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"actual full-scale field")
	_check(StadiumBoundaryRuntime.assemble(property) != null, "complete boundary")
	var bodies: Array = property.find_children("*", "CollisionObject3D", true, false)
	for id: String in StadiumGroundModels.IDS:
		for grass: String in StadiumFieldStyleModels.CHANNELS.grass:
			_check(StadiumGroundModels.apply(property, id, {"line": "ST-062b", "grass": grass},
				stock), "ground and remaining grass coexist " + id + grass)
			_check(property.find_children("*", "CollisionObject3D", true, false) == bodies,
				"ground does not touch physics")
			_measure(property, id, grass)
			await get_tree().process_frame
	var prior: Node = property.get_node("GroundTreatment")
	_check(not StadiumGroundModels.apply(property, "ST-063h", {"line": "", "grass": ""}, stock)
		and property.get_node("GroundTreatment") == prior, "unauthored treatment cannot replace ground")
	_check(not StadiumGroundModels.apply(property, "ST-063e", {"line": "", "grass": ""},
		StadiumStock.new_club()), "unowned ground is rejected")
	_check(property.get_node("Safe").visible and property.get_node("Deep").visible,
		"required scoring guides remain visible")
	_check(StadiumGroundModels.apply(property, "", {"line": "", "grass": ""}, stock)
		and property.get_node_or_null("GroundTreatment") == null, "clear restores template")
	await _capture(property, stock)
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro ground treatment checks passed: "
			+ "exact masks, preserved guides, no physics changes.")
	get_tree().quit(0 if _failures == 0 else 1)


func _subtraction() -> void:
	var square: PackedVector2Array = [Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]
	var hole: PackedVector2Array = [Vector2(4, 4), Vector2(6, 4), Vector2(6, 6), Vector2(4, 6)]
	var area: float = 0
	for piece: PackedVector2Array in StadiumSurfaceMask.subtract(square, [hole]):
		area += _area(piece)
	_check(absf(area - 96) < 0.0001,
		"interior hole is subtracted rather than refilled by triangulation")
	_check(StadiumSurfaceMask.subtract(square, [square]).is_empty(), "full coverage removes all grass")


func _area(points: PackedVector2Array) -> float:
	var area: float = 0
	for index in range(points.size()):
		area += points[index].cross(points[(index + 1) % points.size()])
	return absf(area) / 2


func _measure(property: StadiumPropertyGeometry, id: String, grass: String) -> void:
	var mesh: MeshInstance3D = property.get_node("GroundTreatment/SurfaceVisual")
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(not vertices.is_empty(), "authored ground has visible triangles")
	var max_outside: float = 0
	for point: Vector3 in vertices:
		_check(point.y >= 0.008 and point.y < 0.009, "surface remains below scoring guides and plate")
		var violation: float = INF
		for mask: PackedVector2Array in StadiumGroundModels.masks(id):
			var outside: float = 0
			for edge in range(mask.size()):
				var a: Vector2 = mask[edge]
				var direction: Vector2 = (mask[(edge + 1) % mask.size()] - a).normalized()
				outside = maxf(outside, -direction.cross(Vector2(point.x, point.z) - a))
			violation = minf(violation, outside)
		max_outside = maxf(max_outside, violation)
	print("GROUND_MASK ", id, " max_outside_m=", max_outside)
	_check(max_outside < 0.0001, "ground stays within 0.1mm numeric mask tolerance")
	mesh = property.get_node("FieldStylePreview/" + grass.replace("-", "") + "/StyleVisual")
	vertices = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var overlap: float = 0
	var grass_area: float = 0
	for index in range(0, vertices.size(), 3):
		var triangle: PackedVector2Array = []
		for offset in range(3):
			triangle.append(Vector2(vertices[index + offset].x, vertices[index + offset].z))
		grass_area += _area(triangle)
		for mask: PackedVector2Array in StadiumGroundModels.masks(id):
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(triangle, mask):
				overlap += _area(piece)
	var expected: float = _area(StadiumFieldStyleModels.polygon())
	for mask: PackedVector2Array in StadiumGroundModels.masks(id):
		expected -= _area(mask)
	print("GROUND_AREA ", id, " ", grass, " error_m2=", absf(grass_area - expected))
	_check(absf(grass_area - expected) < 0.005, "remaining grass conserves the exact mask area")
	_check(overlap < 0.001, "grass genuinely excludes treatment masks, overlap=" + str(overlap))


func _capture(property: StadiumPropertyGeometry, stock: StadiumStock) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "native ground review requires rendering")
	if DisplayServer.get_name() == "headless":
		return
	get_window().size = Vector2i(1280, 720)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("13251e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d5ddca")
	environment.environment.ambient_light_energy = 0.55
	property.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 0.75
	property.add_child(light)
	var camera: Camera3D = Camera3D.new()
	property.add_child(camera)
	camera.position = Vector3(-4, 7, -5)
	camera.look_at(Vector3(0, 0, 1))
	camera.make_current()
	var label: Label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 25)
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for id: String in StadiumGroundModels.IDS:
		_check(StadiumGroundModels.apply(property, id, {"line": "ST-062b", "grass": "ST-063b"},
			stock), "native mixed-channel review")
		label.text = "GROUND DETAIL • " + StadiumCatalog.item(id).name
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check(get_viewport().get_texture().get_image().save_png(
			_capture_dir.path_join(id + ".png")) == OK, "ground image saved")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
