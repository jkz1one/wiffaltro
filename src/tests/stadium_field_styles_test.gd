extends Node3D
## Six authored visual variants on the real field; synthetic style stock is not a free grant.

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var stock: StadiumStock = StadiumStock.new_club()
	for channel: String in StadiumFieldStyleModels.CHANNELS:
		for id: String in StadiumFieldStyleModels.CHANNELS[channel]:
			var quote: Dictionary = stock.quote(id, 1, {"seasons": 20, "wins": 100}, id)
			_check(quote.ok, "synthetic authoring entitlement " + id)
			stock = StadiumStock.from_data(quote.state)
	_check(stock.copies.size() == 3 and stock.styles.size() == 6,
		"style entitlement never creates physical copies")
	_check(not stock.quote("ST-062a", 1, {"seasons": 20}, "again").ok,
		"style unlock cannot be purchased twice")
	_check(not StadiumFieldStylePrototype.validate({"line": "ST-062a", "grass": ""},
		StadiumStock.new_club()), "unowned appearance is not selectable")
	_check(not StadiumFieldStylePrototype.validate({"line": "ST-063a", "grass": ""}, stock),
		"grass pattern cannot replace a baseline channel")
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"real scaled reference property")
	_check(StadiumBoundaryRuntime.assemble(property) != null, "actual complete field boundary")
	var bodies: Array = property.find_children("*", "CollisionObject3D", true, false)
	var selection: Dictionary = {"line": "", "grass": ""}
	for channel: String in StadiumFieldStyleModels.CHANNELS:
		for id: String in StadiumFieldStyleModels.CHANNELS[channel]:
			selection[channel] = id
			_check(StadiumFieldStylePrototype.apply(property, selection, stock), "apply owned style " + id)
			_check(property.find_children("*", "CollisionObject3D", true, false) == bodies,
				"styles do not add, remove or replace physics bodies")
			_measure(property.get_node("FieldStylePreview"), id)
			await get_tree().process_frame
	_check(property.get_node("Safe").visible and property.get_node("Deep").visible,
		"Single and Double scoring guides survive every appearance")
	_check(StadiumFieldStylePrototype.apply(property, {"line": "", "grass": ""}, stock)
		and property.get_node("FoulLine1").visible, "removing style restores functional template lines")
	await _capture(property, stock)
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro field style checks passed: "
			+ "exact entitlements, visual masks and no physics changes.")
	get_tree().quit(0 if _failures == 0 else 1)


func _measure(root: Node3D, id: String) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_check(not vertices.is_empty(), "authored visible triangles " + id)
		for point: Vector3 in vertices:
			_check(point.y <= 0.04 and point.y > 0,
				"flat visual geometry cannot act as an upright occluder")
			if mesh.get_parent().get_meta("field_style").begins_with("ST-063"):
				_check(_inside(Vector2(point.x, point.z)),
					"grass pattern stays inside the actual field boundary mask")


func _inside(point: Vector2) -> bool:
	for id: String in StadiumBoundaryGraph.IDS:
		var segment: Dictionary = StadiumBoundaryGraph.segment(id)
		if (point - segment.a).dot(StadiumBoundaryGraph.inward(segment)) < -0.001:
			return false
	return true


func _capture(property: StadiumPropertyGeometry, stock: StadiumStock) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "field-style review needs native rendering")
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
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 36
	camera.position = Vector3(-20, 34, -18)
	camera.look_at(Vector3(0, 0, 9))
	camera.make_current()
	var label: Label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 25)
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for id: String in StadiumFieldStyleModels.CHANNELS.grass:
		_check(StadiumFieldStylePrototype.apply(property, {"line": "ST-062b", "grass": id}, stock),
			"native mixed-channel preview")
		label.text = "FIELD STYLE • " + StadiumCatalog.item(id).name
		await _shot(id)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = Vector3(-4, 5, -3)
	camera.look_at(Vector3(4, 0, 5))
	for id: String in StadiumFieldStyleModels.CHANNELS.line:
		_check(StadiumFieldStylePrototype.apply(property, {"line": id, "grass": ""}, stock),
			"native baseline detail")
		label.text = "BASELINE DETAIL • " + StadiumCatalog.item(id).name
		await _shot(id)


func _shot(id: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join(id + ".png")) == OK, "native field style image saved")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
