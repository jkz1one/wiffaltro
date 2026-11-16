extends "res://src/tests/stadium_recipe_field_test.gd"
## Independent mowing/dirt channels follow the asymmetric prototype's real field shape.


func _ready() -> void:
	var graph: StadiumRecipeBoundary = StadiumOffsetBoundary.new()
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
		_check(quote.ok, "exact authoring entitlement only")
		stock = StadiumStock.from_data(quote.state)
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"unchanged property substrate")
	var samples: int = 0
	for grass: String in StadiumFieldStyleModels.CHANNELS.grass:
		for ground: String in grounds:
			_check(StadiumRecipeFieldStyles.apply(property, graph,
				{"grass": grass, "line": "ST-062b"}, ground, stock), "independent owned channels")
			var mesh: MeshInstance3D = property.get_node(
				"FieldStylePreview/" + grass.replace("-", "") + "/StyleVisual")
			var masks: Array = StadiumInfieldModels.masks(ground) if (
				StadiumInfieldModels.IDS.has(ground)) else StadiumGroundModels.masks(ground)
			_measure(mesh, graph, masks)
			samples += 1
	for side: int in [-1, 1]:
		var end: Vector3 = StadiumRecipeFieldStyles.foul_end(field, graph, side)
		_check(absf(absf(end.x) / end.z - tan(deg_to_rad(42))) < 0.00001,
			"asymmetric outline does not change logical foul angle")
		_check(graph.crossing(end * 0.99, end * 1.01).get("role") == "BACK_WALL_TERMINAL",
			"foul rays reach the finite asymmetric wall")
	_check(samples == 28, "all twenty-eight independent combinations covered")
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro offset field checks passed: 28 independent masks and exact foul rays.")
	get_tree().quit(0 if _failures == 0 else 1)
