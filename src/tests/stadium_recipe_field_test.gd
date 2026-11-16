extends Node3D
## Every retained mowing pattern follows the real polygon, with independent dirt masks.

var _failures: int = 0


func _ready() -> void:
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var grounds: Array[String] = [""]
	grounds.append_array(StadiumGroundModels.IDS)
	grounds.append_array(StadiumInfieldModels.IDS)
	var stock: StadiumStock = StadiumStock.new_club()
	var ids: Array[String] = []
	ids.assign(StadiumFieldStyleModels.CHANNELS.grass)
	ids.append_array(StadiumFieldStyleModels.CHANNELS.line)
	ids.append_array(grounds.slice(1))
	for id: String in ids:
		var quote: Dictionary = stock.quote(id, 1, {"seasons": 50, "wins": 200}, id)
		_check(quote.ok, "exact synthetic authoring entitlement")
		stock = StadiumStock.from_data(quote.state)
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"unchanged substrate")
	for shape: String in StadiumWallRecipes.SHAPES:
		var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create(shape)
		for grass: String in StadiumFieldStyleModels.CHANNELS.grass:
			for ground: String in grounds:
				_check(StadiumRecipeFieldStyles.apply(property, graph,
					{"grass": grass, "line": "ST-062b"}, ground, stock), "owned independent channels")
				var model: MeshInstance3D = property.get_node(
					"FieldStylePreview/" + grass.replace("-", "") + "/StyleVisual")
				var masks: Array = StadiumInfieldModels.masks(ground) if (
					StadiumInfieldModels.IDS.has(ground)) else StadiumGroundModels.masks(ground)
				_measure(model, graph, masks)
		for side: int in [-1, 1]:
			var end: Vector3 = StadiumRecipeFieldStyles.foul_end(field, graph, side)
			_check(absf(absf(end.x) / end.z - tan(deg_to_rad(field.fair_half_angle_degrees)))
				< 0.00001, "same logical fair angle")
			_check(end.z > 23.48 if shape == "deeper_center" else absf(end.z - 23.4) < 0.00001,
				"foul ray reaches the actual shoulder instead of the obsolete scalar depth")
			_check(graph.crossing(end * 0.99, end * 1.01).get("role") == "BACK_WALL_TERMINAL",
				"foul-line endpoint belongs to real terminal wall")
		_check(StadiumRecipeFieldStyles.apply(property, graph,
			{"grass": "", "line": ""}, "", stock), "unpatterned option stays available")
		_check(property.get_node("FieldStylePreview").get_child_count() == 0,
			"clearing style does not force a mowing pattern")
	_check(not StadiumRecipeFieldStyles.apply(property, StadiumRecipeBoundary.create("straight"),
		{"grass": "ST-063a", "line": ""}, "", StadiumStock.new_club()), "no unowned style grant")
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro recipe field checks passed: 56 polygon/mask combinations and exact foul rays.")
	get_tree().quit(0 if _failures == 0 else 1)


func _measure(mesh: MeshInstance3D, graph: StadiumRecipeBoundary, masks: Array) -> void:
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var area: float = 0
	for index in range(0, vertices.size(), 3):
		var triangle: PackedVector2Array = []
		for offset in range(3):
			var point: Vector2 = Vector2(vertices[index + offset].x, vertices[index + offset].z)
			_check(graph.contains(point), "grass vertex %s stays within real field outline" % point)
			triangle.append(point)
		area += StadiumSurfaceMask.area(triangle)
	var dirt: float = 0
	var prior: Array = []
	for mask: PackedVector2Array in masks:
		for piece: PackedVector2Array in StadiumSurfaceMask.subtract(mask, prior):
			dirt += StadiumSurfaceMask.area(piece)
		prior.append(mask)
	_check(absf(area + dirt - StadiumSurfaceMask.area(graph.polygon())) < 0.01,
		"full pattern reaches deeper pocket without overlap or unpainted area")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
