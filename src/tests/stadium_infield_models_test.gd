extends "res://src/tests/stadium_ground_models_test.gd"
## Independent surface footprints, grass patterns and visual bases, before paid activation.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_subtraction()
	var stock: StadiumStock = StadiumStock.new_club()
	var ids: Array = StadiumInfieldModels.IDS.duplicate()
	ids.append_array(StadiumBaseMarkerModels.IDS)
	ids.append_array(StadiumFieldStyles.PRICES.keys())
	for id: String in ids:
		var quote: Dictionary = stock.quote(id, 1, {"seasons": 20, "wins": 100}, id)
		_check(quote.ok, "synthetic authoring entitlement " + id)
		stock = StadiumStock.from_data(quote.state)
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"unchanged shared home field")
	StadiumBoundaryRuntime.assemble(property)
	var bodies: Array = property.find_children("*", "CollisionObject3D", true, false)
	var anchors: Array[Vector2] = StadiumInfieldAnchors.bases()
	_check(anchors.size() == 3 and anchors[0].x > 0 and anchors[2].x < 0,
		"one coherent three-base visual diamond")
	for id: String in StadiumBaseMarkerModels.IDS:
		_check(StadiumBaseMarkerModels.apply(property, id, stock), "exact owned base set")
		var markers: Node3D = property.get_node("BaseMarkerSet")
		_check(markers.get_child_count() == 3, "no extra home plate or logical bases")
		for marker: MeshInstance3D in markers.get_children():
			var box: AABB = marker.get_aabb()
			for index in range(8):
				var point: Vector3 = marker.transform * box.get_endpoint(index)
				_check(absf(point.x) <= point.z * tan(deg_to_rad(42.0)) + 0.001,
					"entire marker remains on the fair side of the existing foul line")
			_check(absf(marker.position.z - property.field.safe_hit_z_m) > 0.5
				and absf(marker.position.z - property.field.deep_air_z_m) > 0.5,
				"base markers do not cover required scoring bands")
	for id: String in StadiumInfieldModels.IDS:
		for point: Vector2 in anchors:
			_check(_covered(point, StadiumInfieldModels.masks(id)), "all bases belong to the footprint")
		_check(_covered(Vector2(0, PitchBatLab.MOUND_ORIGIN.z), StadiumInfieldModels.masks(id)),
			"each footprint includes its authored mound treatment")
		for grass: String in StadiumFieldStyleModels.CHANNELS.grass:
			_check(StadiumInfieldModels.apply(property, id, {"line": "ST-062b", "grass": grass},
				stock), "independent footprint and grass selection")
			_measure_infield(property, id, grass)
			_check(property.find_children("*", "CollisionObject3D", true, false) == bodies,
				"base and ground styles add no collider or scoring changes")
			await get_tree().process_frame
	_check(not _covered(Vector2(0, 6), StadiumInfieldModels.masks("ST-063g")),
		"connected paths retain a genuine grass-centered diamond")
	_check(_covered(Vector2(10, 15), StadiumInfieldModels.masks("ST-063h"))
		and not _covered(Vector2(10, 15), StadiumInfieldModels.masks("ST-063j")),
		"full clay fan and rounded sand diamond have distinct outer footprints")
	_check(not StadiumBaseMarkerModels.apply(property, "ST-062c", StadiumStock.new_club())
		and not StadiumInfieldModels.apply(property, "ST-063g", {"line": "", "grass": ""},
			StadiumStock.new_club()), "no unowned authoring grant")
	_plain_and_clear(property, stock)
	await _capture(property, stock)
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro infield model checks passed: distinct footprints, independent grass and bases.")
	get_tree().quit(0 if _failures == 0 else 1)


func _covered(point: Vector2, masks: Array) -> bool:
	for mask: PackedVector2Array in masks:
		if Geometry2D.is_point_in_polygon(point, mask):
			return true
	return false


func _measure_infield(property: StadiumPropertyGeometry, id: String, grass: String) -> void:
	var ground: Array = StadiumInfieldModels.pieces(id)
	var masks: Array = StadiumInfieldModels.masks(id)
	var ground_area: float = 0
	for piece: PackedVector2Array in ground:
		ground_area += _area(piece)
		for point: Vector2 in piece:
			_check(StadiumBoundaryGraph.contains(point), "ground fits complete boundary")
	var mesh: MeshInstance3D = property.get_node(
		"FieldStylePreview/" + grass.replace("-", "") + "/StyleVisual")
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var grass_area: float = 0
	var overlap: float = 0
	for index in range(0, vertices.size(), 3):
		var triangle: PackedVector2Array = []
		for offset in range(3):
			triangle.append(Vector2(vertices[index + offset].x, vertices[index + offset].z))
		grass_area += _area(triangle)
		for mask: PackedVector2Array in masks:
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(triangle, mask):
				overlap += _area(piece)
	var drift: float = absf(grass_area + ground_area - _area(StadiumFieldStyleModels.polygon()))
	print("INFIELD_MASK ", id, " ", grass, " ground=", ground_area, " grass=", grass_area,
		" overlap=", overlap, " area_drift=", drift, " pieces=", ground.size())
	_check(drift < 0.01 and overlap < 0.001, "grass and dirt cover the exact complementary areas")
	_check(property.get_node("Safe").visible and property.get_node("Deep").visible
		and property.get_node("Plate").visible, "scoring guides and original plate stay visible")


func _capture(property: StadiumPropertyGeometry, stock: StadiumStock) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
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
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 35
	camera.position = Vector3(0, 38, -8)
	camera.look_at(Vector3(0, 0, 10))
	camera.make_current()
	var label: Label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 25)
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for id: String in StadiumInfieldModels.IDS:
		for grass: String in StadiumFieldStyleModels.CHANNELS.grass:
			_check(StadiumInfieldModels.apply(property, id, {"line": "ST-062b", "grass": grass},
				stock), "native independent-channel review")
			StadiumBaseMarkerModels.apply(property, "ST-062d", stock)
			label.text = StadiumCatalog.item(id).name + " • " + StadiumCatalog.item(grass).name
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_check(get_viewport().get_texture().get_image().save_png(
				_capture_dir.path_join(id + "-" + grass + ".png")) == OK, "infield image saved")


func _plain_and_clear(property: StadiumPropertyGeometry, stock: StadiumStock) -> void:
	for id: String in StadiumInfieldModels.IDS:
		_check(StadiumInfieldModels.apply(property, id, {"line": "", "grass": ""}, stock),
			"each footprint also supports unpatterned template grass")
		_check(property.get_node("FieldStylePreview").get_child_count() == 0,
			"footprint does not force any grass pattern")
	_check(StadiumInfieldModels.apply(property, "", {"line": "", "grass": ""}, stock)
		and property.get_node_or_null("InfieldTreatment") == null,
		"clearing footprint restores the original visible grass")
	_check(StadiumBaseMarkerModels.apply(property, "", stock)
		and property.get_node_or_null("BaseMarkerSet") == null,
		"base set can be removed independently without moving home plate")
