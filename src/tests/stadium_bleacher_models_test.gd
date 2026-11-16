extends "res://src/tests/stadium_seating_test.gd"
## Larger complete seating candidates in their authored property sites.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var stock: StadiumStock = StadiumStock.new_club()
	for row: Array in [["ST-075", "bench-fixture"], ["ST-028", "aluminum-fixture"]]:
		var quote: Dictionary = stock.quote(row[0], 1, {"seasons": 10, "wins": 30}, row[1])
		_check(quote.ok, "synthetic independently purchased whole bleacher " + row[0])
		stock = StadiumStock.from_data(quote.state)
	_check(stock.copies.size() == 5 and not stock.blueprints.has("ST-027"),
		"roofed structure neither consumes nor grants the earlier wood bleacher")
	var rows: Array = [{"copy": "purchase:bench-fixture:0", "site": "SIDE-SEAT-L"},
		{"copy": "purchase:aluminum-fixture:0", "site": "SIDE-SEAT-R"}]
	_check(not StadiumBleacherSites.validate(rows, stock, "expanded").ok,
		"roofed timber requires Club grounds even though its envelope fits earlier land")
	_check(not StadiumBleacherSites.validate(rows.slice(1), stock, "backyard").ok
		and StadiumBleacherSites.validate(rows.slice(1), stock, "expanded").ok,
		"aluminum requires Expanded yard")
	_check(StadiumBleacherSites.validate(rows, stock, "club").ok, "independent mixed side assemblies")
	var repeated: Array = rows.duplicate(true)
	repeated[1].copy = repeated[0].copy
	_check(not StadiumBleacherSites.validate(repeated, stock, "club").ok,
		"one owned assembly cannot occupy both sides")
	_check(not StadiumSeatingLayout.validate(rows, stock, "club").ok,
		"new models cannot enter the old frozen seating grammar")
	for id: String in StadiumBleacherModels.IDS:
		var model: Node3D = StadiumBleacherModels.create(id)
		add_child(model)
		var bounds: AABB = _bounds(model, model)
		print("BLEACHER_BOUNDS ", id, " ", bounds)
		_check(StadiumBleacherModels.envelope(id).grow(0.001).encloses(bounds),
			"actual roof, supports and represented audience fit exact envelope " + id)
		_check(model.get_node("Visual").find_children("CrowdAnchor*", "Node3D", false, false).size()
			== (24 if id == "ST-028" else 10), "audience belongs to the parent assembly")
		for body: Node in model.get_node("Collision").get_children():
			_check(body.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL",
				"every named structure surface retains its outside-play role")
		model.queue_free()
	await get_tree().process_frame
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("club", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"actual Club property envelope with original field size")
	_check(StadiumBoundaryRuntime.assemble(property) != null, "complete unchanged field perimeter")
	var seating: StadiumBleacherPrototype = StadiumBleacherPrototype.new()
	property.add_child(seating)
	_check(seating.build(rows, stock, "club"), "build the two exact owned assemblies")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _after_terminal(seating)
	await _capture(property, seating)
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro advanced bleacher checks passed: "
			+ "independent copies, measured tiers and post-terminal scenery.")
	get_tree().quit(0 if _failures == 0 else 1)


func _capture(property: Node3D, seating: StadiumSeatingPrototype) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "native assembly review requires rendering")
	if DisplayServer.get_name() == "headless":
		return
	get_window().size = Vector2i(1280, 720)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("142520")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.45
	property.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_energy = 0.7
	light.shadow_enabled = true
	property.add_child(light)
	var camera: Camera3D = Camera3D.new()
	property.add_child(camera)
	camera.make_current()
	var label: Label = Label.new()
	label.position = Vector2(30, 22)
	label.add_theme_font_size_override("font_size", 28)
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for item: Array in [["roofed-timber", "purchase:bench-fixture:0", Vector3(8, 4, 7)],
		["aluminum-four-row", "purchase:aluminum-fixture:0", Vector3(-8, 4, -7)]]:
		var model: Node3D = seating.objects[item[1]]
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 48
		camera.position = model.position + item[2]
		camera.look_at(model.position + Vector3(0, 1.4, 0))
		label.text = "SEATING BLOCKOUT • " + str(item[0])
		await _shot(item[0])
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 64
	camera.position = Vector3(-32, 42, -25)
	camera.look_at(Vector3(0, 0, 12))
	label.text = "CLUB GROUNDS • Mixed complete seating assemblies"
	await _shot("advanced-seating-property")
