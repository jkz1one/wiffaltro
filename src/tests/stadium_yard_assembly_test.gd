extends "res://src/tests/stadium_seating_test.gd"
## Complete four-chair AY-01 with no synthetic player ownership or optional catalog parts.


func _ready() -> void:
	var record: Dictionary = StadiumYardVenueStudy.canonical()
	var original: String = FileAccess.get_sha256("res://src/content/fields/starter_field.tres")
	var property: StadiumPropertyGeometry = StadiumYardVenueStudy.build()
	_check(property != null, "complete AY-01 builds from existing supported assets")
	if property == null:
		get_tree().quit(1)
		return
	add_child(property)
	_check(property.tier == "backyard" and property.objects.size() == 4,
		"Backyard owns exactly four spectator chairs")
	_check(property.get_node("BoundaryGraph").get_child_count() == 6
		and not property.has_node("TemplateBackWall"), "all six free template boundary segments")
	_prisms(property)
	_check(property.route_obstacles().is_empty(), "spectators never become live routing obstacles")
	_check(record.blueprint_entitlements == ["ST-080"] and record.live_units == 0,
		"only actual chair blueprint entitlement; no starter grant")
	_check(record.endowment.blueprint_value == 150 and record.endowment.copy_value == 160
		and record.endowment.land_value == 0 and record.endowment.total_value == 310
		and not record.endowment.spendable, "310 content endowment cannot become player money")
	_check(record.surface.styles.is_empty() and record.environment.certificates.is_empty()
		and not record.environment.night_eligible, "default surface and no unearned certificates")
	for row: Dictionary in record.items:
		var model: Node3D = property.objects[row.instance]
		_check(model.get_meta("stadium_item") == "ST-080"
			and model.get_meta("candidate_site") == row.site
			and StadiumYardVenueStudy.components(model.transform) == row.transform,
			"canonical exact instance/model/site/pose " + row.site)
		_check(not model.has_meta("owned_copy"), "NPC chair has no human owned-copy provenance")
		var bounds: AABB = model.transform * StadiumSeatingLayout.envelope("ST-080")
		_check(StadiumProperty.contains("backyard", bounds)
			and StadiumSeatingLayout._outside_play(bounds), "full chair envelope fits " + row.site)
		_check(StadiumSeatingLayout.envelope("ST-080").grow(0.001).encloses(_bounds(model, model)),
			"actual occupied frozen model fits declared bounds " + row.site)
		for body: Node in model.get_node("Collision").get_children():
			_check(body.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL"
				and body.get_meta("candidate_instance") == row.instance
				and not body.has_meta("owned_copy"), "decorative-only named provenance")
	_check(FileAccess.get_sha256("res://src/content/fields/starter_field.tres") == original,
		"authoring does not rewrite the field resource")
	_check(property.field != ContentDB.get_field(PitchBatLab.FIELD_ID),
		"property uses a duplicate of the immutable reference field")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	property.queue_free()
	await get_tree().process_frame
	if _failures == 0:
		print("Wiffaltro yard assembly passed: exact AY-01, default surfaces and NPC-only endowment.")
	get_tree().quit(0 if _failures == 0 else 1)


func _prisms(property: StadiumPropertyGeometry) -> void:
	var view: StadiumYardFieldVisibility.TemplateView = StadiumYardFieldVisibility.TemplateView.new()
	var prisms: StadiumWallViewPrisms = StadiumWallViewPrisms.new(view)
	var boundary: StadiumBoundaryPrototype = property.get_node("BoundaryGraph")
	_check(prisms.walls.size() == boundary.get_child_count(), "one exact prism per physical slab")
	for index in range(prisms.walls.size()):
		var body: StaticBody3D = boundary.get_child(index)
		var shape: CollisionShape3D = body.get_child(0)
		var points: PackedVector3Array = shape.shape.points
		var prism: Dictionary = prisms.walls[index]
		for corner in range(4):
			var at: Vector2 = prism.polygon[corner]
			# Geometry stores Vector3 float32 components; a Dictionary scalar is float64.
			# Compare full scene-space vectors in that same representation, still exactly.
			_check(points[corner] == Vector3(at.x, 0, at.y)
				and points[corner + 4] == Vector3(at.x, prism.height, at.y),
				"camera prism exactly matches template collider vertices " + body.name)
		var mesh: MeshInstance3D = body.get_child(1)
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			_check(points.has(vertex), "render triangle uses the same physical slab vertex")
			for plane: Plane in prism.planes:
				_check(plane.distance_to(vertex) <= 0.00001,
					"exact visibility half-spaces enclose actual rendered slab")
