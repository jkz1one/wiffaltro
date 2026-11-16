extends Node3D
## Full physical assemblies, explicit counts and free template edges. No gameplay activation.

var _failures: int = 0


func _ready() -> void:
	var property: StadiumExpandedProperty = StadiumExpandedVenueStudy.build()
	_check(property != null, "complete Expanded property builds")
	if property == null:
		get_tree().quit(1)
		return
	add_child(property)
	var record: Dictionary = property.get_meta("candidate_venue")
	_check(record.items.size() == 27 and record.live_units == 0, "exact 27-copy zero-live manifest")
	_check(
		record.endowment.total_value == 3530 and not record.endowment.spendable,
		"3530 is nonspendable content comparison"
	)
	var costs: Vector2i = Vector2i.ZERO
	for item: String in StadiumExpandedVenueStudy.COUNTS:
		var price: Dictionary = StadiumCatalog.item(item)
		costs += Vector2i(
			price.blueprint_price,
			int(price.copy_price) * int(StadiumExpandedVenueStudy.COUNTS[item])
		)
	_check(costs == Vector2i(1710, 1220), "entitlements and copies independently reconcile")
	_check(property.objects.size() == 5, "five original nonwall assemblies")
	var boundary: StadiumExpandedBoundary = property.get_node("BoundaryGraph")
	var models: Array[Node] = boundary.get_node("PanelVisuals").get_children()
	_check(models.size() == 22, "exact back pieces without 38 unrequested paid side panels")
	var recipes: Array[Dictionary] = StadiumWallRecipes.back("deeper_center", "ST-024")
	for index in range(models.size()):
		var model: Node3D = models[index]
		_check(
			model.transform == StadiumWallRecipes.placement(recipes[index]), "exact wall transform"
		)
		_check(model.get_meta("wall_span") == recipes[index].span, "exact full or end panel")
		_check(not model.has_node("PanelCollision"), "joined slabs replace overlapping panel boxes")
		_check(
			not model.find_children("*", "MeshInstance3D", true, false).is_empty(),
			"actual panel art"
		)
	_check(boundary.graph.polygon().size() == 8, "complete deeper-center eight-edge polygon")
	for row: Dictionary in boundary.graph.segments():
		var body: StaticBody3D = boundary.get_node(row.id)
		_check(body.get_child(0) is CollisionShape3D, "real joined slab collider")
		_check(
			body.get_node("TemplateWallVisual").visible == (row.role != "BACK_WALL_TERMINAL"),
			"template side and rear meshes retained, paid back has its authored art"
		)
	var net: Node3D = property.objects["npc-candidate:AE-01:RECEIVER-CATCH"]
	var target: Node3D = property.objects["npc-candidate:AE-01:RECEIVER-PRIMARY"]
	var nb: AABB = net.global_transform * StadiumNetModels.ENVELOPE
	var tb: AABB = target.global_transform * StadiumTargetModels.ENVELOPE
	_check(
		(
			is_equal_approx(nb.position.z, -3.05)
			and is_equal_approx(nb.end.z, -2.16)
			and is_equal_approx(tb.position.z - nb.end.z, 0.435)
		),
		"corrected v2 net envelope and gap"
	)
	for model: Node3D in property.objects.values():
		var site: String = model.get_meta("candidate_site")
		_check(
			model.transform == StadiumExpandedVenueStudy.pose(site),
			"exact original fixture transform"
		)
		_check(model.get_node("Collision").get_child_count() > 0, "real fixture collision parts")
		_check(
			not model.find_children("*", "MeshInstance3D", true, false).is_empty(),
			"real fixture meshes"
		)
		_check(
			StadiumProperty.contains("expanded", _bounds(model)),
			"actual fixture mesh fits property"
		)
	_check(net.get_meta("site") == "RECEIVER-NET", "archival CATCH explicitly aliases runtime NET")
	_check(
		record.environment.certificates.is_empty() and not record.environment.night_eligible,
		"clear afternoon intent has no invented certification"
	)
	_check(record.boundary.foul_intersections.size() == 2, "both mathematical foul intersections")
	for socket: Dictionary in StadiumFoulPoleSites.rows(boundary.graph):
		var end: Vector3 = (
			property.get_node("FoulLine" + str(-1 if socket.site.ends_with("L") else 1)).position
		)
		_check(
			(end * 2 - Vector3(0, 0.04, 0)).is_equal_approx(socket.position),
			"line reaches mathematical back"
		)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	property.queue_free()
	await get_tree().process_frame
	if _failures == 0:
		print("Wiffaltro expanded assembly passed: 27 exact copies, free edges, corrected pair.")
	get_tree().quit(0 if _failures == 0 else 1)


func _bounds(model: Node3D) -> AABB:
	var result: AABB
	var first: bool = true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
