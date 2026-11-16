extends "res://src/tests/stadium_recipe_physical_test.gd"
## Original asymmetric candidate, actual joined collisions and native isolated review.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_shape = "offset_gables"
	await _physical(_shape)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro offset physical checks passed: isolated actual faces, contacts and exits.")
	get_tree().quit(0 if _failures == 0 else 1)


func _physical(shape: String) -> void:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"isolated field substrate")
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumRecipeBoundaryBody = StadiumOffsetBoundaryBody.new()
	property.add_child(boundary)
	_check(boundary.build(shape, "ST-077") and not boundary.build(shape), "one exact joined graph")
	var stock: StadiumStock = StadiumStock.new_club()
	for id: String in ["ST-063c", "ST-063g"]:
		var quote: Dictionary = stock.quote(id, 1, {"seasons": 50, "wins": 200}, id)
		_check(quote.ok, "exact authoring-only style entitlement")
		stock = StadiumStock.from_data(quote.state)
	var selection: Dictionary = {"grass": "ST-063c", "line": ""}
	_check(StadiumInfieldModels.apply(property, "ST-063g", selection, stock)
		and StadiumRecipeFieldStyles.apply(property, boundary.graph, selection, "ST-063g", stock),
		"pattern and dirt fit the actual recipe independently")
	StadiumWallRenderQuality.attach(boundary)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for row: Dictionary in boundary.graph.segments():
		var normal: Vector2 = boundary.graph.inward(row)
		var center: Vector2 = (row.a + row.b) / 2
		var from: Vector3 = Vector3(center.x + normal.x * 0.5, 0.75, center.y + normal.y * 0.5)
		var to: Vector3 = from - Vector3(normal.x, 0, normal.y) * 1.5
		var hit: Dictionary = _ray(from, to)
		_check(not hit.is_empty() and hit.collider.get_meta("boundary_segment", "") == row.id,
			"actual inward collision face " + row.id)
		for foul: bool in [false, true]:
			await _flight(boundary, row, from, Vector3(-normal.x, 0, -normal.y) * 6, foul)
	for vertex: Vector2 in boundary.graph.polygon():
		var inside: Vector2 = vertex.lerp(Vector2(0, 10), 0.1)
		var outside: Vector2 = vertex + (vertex - inside).normalized()
		_check(not _ray(Vector3(inside.x, 0.6, inside.y),
			Vector3(outside.x, 0.6, outside.y)).is_empty(), "convex and concave joins have no hole")
	var back_z: float = 28.0
	for foul: bool in [false, true]:
		await _exit_flight(boundary, Vector3(23, 2, 22.7), Vector3(0, 0, 36),
			"SIDE_EXIT_DEAD", foul)
		await _exit_flight(boundary, Vector3(0, 4, back_z - 0.7), Vector3(0, 0, 36),
			"BACK_CLEAR", foul)
		await _exit_flight(boundary, Vector3(0, 2, -5.5), Vector3(0, 0, -36),
			"REAR_PERIMETER_DEAD", foul)
	await _capture_scene(property)
	property.queue_free()
	await get_tree().physics_frame
