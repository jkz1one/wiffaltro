extends "res://src/tests/stadium_low_wall_boundary_test.gd"


# Contract3 successor: retain every inherited native physics/issuance probe.
# Out-of-API cosmetic/resource mutation is checked at deep transitions.
func _mutation_guards() -> void:
	for mutation: String in [
		"panel_transform",
		"panel_copy",
		"panel_socket",
		"nested_transform",
		"nested_material",
		"material_value",
		"mesh_size",
		"shape_points",
		"node_order",
		"extra_child",
		"root_metadata",
		"root_visible",
		"graph_metadata",
		"graph_profile",
		"graph_identity"
	]:
		var boundary: StadiumLowWallBoundaryRuntime = _build()
		if boundary == null:
			continue
		var art: Node3D = boundary.get_node("PanelVisuals")
		var panel: Node3D = art.get_child(art.get_child_count() - 1)
		var mesh: MeshInstance3D = panel.find_children("*", "MeshInstance3D", true, false)[0]
		match mutation:
			"panel_transform":
				panel.position.x += 0.001
			"panel_copy":
				panel.set_meta("owned_copy", "wall-piece:foreign:0")
			"panel_socket":
				panel.set_meta("wall_socket", "wrong-socket")
			"nested_transform":
				mesh.position.y += 0.001
			"nested_material":
				mesh.material_override = mesh.material_override.duplicate(true)
			"material_value":
				mesh.material_override.albedo_color = Color.RED
			"mesh_size":
				mesh.mesh.size.y += 0.001
			"shape_points":
				var collider: CollisionShape3D = boundary.bodies[0].get_node("Shape")
				var points: PackedVector3Array = collider.shape.points
				points[0].x += 0.001
				collider.shape.points = points
			"node_order":
				art.move_child(panel, 0)
			"extra_child":
				mesh.add_child(Node3D.new())
			"root_metadata":
				boundary.set_meta("boundary_layout_hash", "forged")
			"root_visible":
				boundary.visible = false
			"graph_metadata":
				boundary.graph.set_meta("forged", true)
			"graph_profile":
				boundary.graph.profile = "low_flanks"
			"graph_identity":
				boundary.graph = StadiumLowWallLayout.graph_for(_fixture.layout)
		_check(not boundary.deep_intact(), "contract3 deep-transition fail-closed: " + mutation)
		_check(
			boundary.event(Vector3(17, 2, 23), Vector3(17, 2, 24), 0.0365).is_empty(),
			"retired boundary issues no score: " + mutation
		)
		boundary.get_parent().free()


func _owned_models() -> void:
	var original: Dictionary = _fixture
	for pair: Array in [["ST-032", "ST-020"], ["ST-074", "ST-071"]]:
		_fixture = original.duplicate(true)
		_fixture["tier"] = "expanded"
		var stock: StadiumStock = _fixture.stock
		var progress: Dictionary = {"seasons": 50, "wins": 200, "homers": 200, "strikeouts": 200}
		for entry: Array in [[pair[0], 2], [pair[1], 8]]:
			var quote: Dictionary = stock.quote(entry[0], entry[1], progress, entry[0])
			_check(quote.ok, "unchanged paid boundary stock quotes: " + entry[0])
			stock = StadiumStock.from_data(quote.state)
		_fixture.stock = stock
		_fixture.layout.boundary = []
		for side: String in ["L", "R"]:
			_fixture.layout.boundary.append(
				{
					"copy": "purchase:" + pair[0] + (":0" if side == "L" else ":1"),
					"item": pair[0],
					"site": "DUGOUT-" + side,
					"host": ""
				}
			)
		for index: int in range(8):
			_fixture.layout.boundary.append(
				{
					"copy": "purchase:" + pair[1] + ":" + str(index),
					"item": pair[1],
					"site": "REAR-%02d" % index,
					"host": ""
				}
			)
		_fixture.checked = StadiumLowWallLayout.validate(
			_fixture.layout, stock, _fixture.pieces, _fixture.access, _fixture.tier
		)
		_check(
			_fixture.checked.ok,
			"inherited paired dugouts and complete rear fence coexist: " + _fixture.checked.error
		)
		if not _fixture.checked.ok:
			continue
		var boundary: StadiumLowWallBoundaryRuntime = _build()
		if boundary == null:
			continue
		_check(
			boundary.intact() and boundary.owned_models.size() == 10,
			"all exact paid boundary models retain ownership and complete visual/native seals"
		)
		_check(
			not boundary.has_node("REAR-01"),
			"paid fence replaces template rear collider without duplication"
		)
		for key: String in boundary.owned_models:
			_check(
				boundary.owns_model(key, boundary.get_parent().objects[key]),
				"exact boundary-copy property registry preserved"
			)
		var dugout: Node3D = boundary.owned_models["purchase:" + pair[0] + ":0"]
		var mesh: MeshInstance3D = dugout.find_children("*", "MeshInstance3D", true, false)[0]
		mesh.position.x += 0.001
		_check(
			not boundary.deep_intact(),
			"contract3 deep transition retires mutated inherited paid model"
		)
		boundary.get_parent().free()
	_fixture = original
