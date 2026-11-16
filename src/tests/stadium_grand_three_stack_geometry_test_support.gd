extends "res://src/tests/stadium_grand_three_stack_host_test_support.gd"
## Independent geometry, support and clearance proof for the nine-roof neighborhood.


func _grand_snapshot(root: Node) -> String:
	var state: Array = []
	_grand_node_state(root, state)
	return var_to_bytes(state).hex_encode().sha256_text()


func _grand_node_state(node: Node, state: Array) -> void:
	var node_name: String = node.get_class() if node is CollisionShape3D else str(node.name)
	var entry: Array = [node_name, node.get_class(), node.process_mode,
		StadiumCurvedCanopySites._resource(node.get_script()), node.get_child_count()]
	for key: StringName in node.get_meta_list():
		entry.append([key, node.get_meta(key)])
	if node is Node3D:
		entry.append([node.transform, node.visible, node.top_level])
	if node is MeshInstance3D:
		entry.append([node.mesh.get_class(), node.transparency, node.cast_shadow, node.layers,
			StadiumCurvedCanopySites._resource(node.material_override),
			StadiumCurvedCanopySites._resource(node.material_overlay)])
		for surface in range(node.mesh.get_surface_count()):
			entry.append([node.mesh.surface_get_arrays(surface),
				StadiumCurvedCanopySites._resource(node.mesh.surface_get_material(surface)),
				StadiumCurvedCanopySites._resource(node.get_surface_override_material(surface))])
	if node is CollisionObject3D:
		entry.append([node.collision_layer, node.collision_mask, node.disable_mode])
	if node is CollisionShape3D:
		entry.append([node.disabled, StadiumCurvedCanopySites._resource(node.shape)])
	state.append(entry)
	for child: Node in node.get_children():
		_grand_node_state(child, state)


func _grand_guard_delta(lower: Node3D) -> void:
	var reference: Node3D = StadiumBaselineStandModels.lower()
	for branch: String in ["Visual", "Collision"]:
		var actual: Node = lower.get_node(branch)
		var original: Node = reference.get_node(branch)
		_check(actual.get_child_count() == original.get_child_count(), "guard-v2 adds no hidden branches")
		for index in range(original.get_child_count()):
			var previous: Node = original.get_child(index)
			var current: Node = actual.get_child(index)
			if str(previous.name) != "FrontGuard":
				_check(_grand_snapshot(current) == _grand_snapshot(previous),
					"all non-guard lower geometry crowd materials and physical state remain frozen")
			else:
				_check(current.position == Vector3(-0.35, 3.45, 0.06),
					"guard-only correction changes center from3.5 to3.45")
				var size_value: Vector3 = current.mesh.size if current is MeshInstance3D \
					else current.get_child(0).shape.size
				_check(size_value == Vector3(5.3, 0.9, 0.12),
					"guard-only correction has exact visible and physical0.9m height")
	reference.free()


func _grand_boxes(root: Node3D) -> void:
	for body: StaticBody3D in root.get_node("Collision").get_children():
		_check(body.get_child_count() == 1 and body.collision_layer == 1 and body.collision_mask == 2,
			"one enabled scenery collider for every purchased solid")
		var shape: CollisionShape3D = body.get_child(0)
		var mesh: MeshInstance3D = root.get_node("Visual/" + str(body.name))
		_check(mesh.mesh is BoxMesh and shape.shape is BoxShape3D,
			"actual straight visible and collision volumes are exact boxes")
		if not mesh.mesh is BoxMesh or not shape.shape is BoxShape3D:
			continue
		_check(body.transform == mesh.transform and shape.transform == Transform3D.IDENTITY
			and shape.shape.size == mesh.mesh.size and shape.shape.margin == 0 and not shape.disabled,
			"every complete box collider exactly matches the visible solid with zero inflation")
		_check(mesh.material_override is StandardMaterial3D and mesh.material_overlay == null,
			"canonical opaque purchased solids have real plain materials")
		var material: StandardMaterial3D = mesh.material_override
		_check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			and material.albedo_color.a == 1 and material.next_pass == null,
			"new structural solids are fully opaque with no hidden pass")


func _grand_roof_geometry(roof: Node3D) -> void:
	_grand_boxes(roof)
	_check(roof.get_node("Collision").get_child_count() == 9
		and roof.get_node("Visual").get_child_count() == 9,
		"separate upper roof owns nine complete solids and grants no audience")
	var members: Dictionary = {
		"RoofSlab": [Vector3(0, 13.4, 5.05), Vector3(5.9, 0.3, 6.1)],
		"FrontRoofFascia": [Vector3(0, 13.375, 2.075), Vector3(5.9, 0.55, 0.15)],
		"RearRoofFascia": [Vector3(0, 13.375, 8.025), Vector3(5.9, 0.55, 0.15)]}
	for side: int in [-1, 1]:
		members["RoofPost%d" % side] = [Vector3(side * 2.6, 12.175, 7.7), Vector3(0.4, 2.15, 0.8)]
		members["RoofBeam%d" % side] = [Vector3(side * 2.6, 13, 5.05), Vector3(0.4, 0.5, 6.1)]
		members["FinishedRoofEnd%d" % side] = [Vector3(side * 2.875, 13.375, 5.05),
			Vector3(0.15, 0.55, 6.1)]
	for member: String in members:
		var mesh: MeshInstance3D = roof.get_node("Visual/" + member)
		_check(mesh.position.is_equal_approx(members[member][0])
			and mesh.mesh.size.is_equal_approx(members[member][1]),
			"roof dimensions independently match exact supported authored member")
	for world: Vector3 in _all_points(roof):
		var local: Vector3 = roof.global_transform.affine_inverse() * world
		_check(local.x >= -2.951 and local.x <= 2.951 and local.z >= 1.999 and local.z <= 8.101
			and local.y >= 11.099 and local.y <= 13.651,
			"actual whole roof leaves independent bay ends and exact depth/height envelope")
		_check(local.z >= 7.299 or local.y >= 12.749,
			"full roof over audience is at least0.55m above occupied upper reserve12.2")


func _grand_reservation(root: Node3D) -> void:
	for point: Vector3 in _all_points(root):
		_check(StadiumProperty.contains("mogul", AABB(point, Vector3.ZERO)),
			"all actual visible collision and audience vertices fit legal Mogul property")
		_check(not StadiumReceiverNetModels.ENVELOPE.grow(0.25).has_point(point),
			"all purchased geometry clears corrected receiver occupied reserve")
		_check(point.is_finite(), "all measured occupied geometry remains finite")
	if root.get_meta("stadium_item", "") not in ["ST-029", "ST-030", "ST-031"]:
		return
	for world: Vector3 in _all_points(root):
		var local: Vector3 = root.global_transform.affine_inverse() * world
		var bounds: AABB = StadiumBaselineSites.LOWER_BOUNDS \
			if root.get_meta("stadium_item") == "ST-029" else SS.BOUNDS
		_check(bounds.grow(0.001).has_point(local), "all straight geometry fits frozen reserve")


func _grand_straight_support(stack: Array[Node3D]) -> void:
	var lower: Node3D = stack[0]
	var concourse: Node3D = stack[1]
	var upper: Node3D = stack[2]
	var roof: Node3D = stack[3]
	var deck: Node3D = concourse.get_node("Collision/ConcourseDeck")
	var saddle: Node3D = concourse.get_node("Collision/RearSaddle")
	var plinth: MeshInstance3D = concourse.get_node("Visual/GroundedRearPlinth")
	_check(is_zero_approx(plinth.position.y - plinth.mesh.size.y / 2), "concourse owns grounded mass")
	_check(_contact(lower.get_node("Collision/EntryStep39"), saddle), "real stair supports saddle")
	_check(_contact(deck, saddle), "actual saddle contacts complete concourse deck")
	_check(_contact(concourse.get_node("Collision/GroundedRearPlinth"), deck), "deck rests on base")
	for side: int in [-1, 1]:
		var pylon: Node3D = upper.get_node("Collision/RearPylon%d" % side)
		var beam: Node3D = upper.get_node("Collision/Cantilever%d" % side)
		_check(_contact(deck, pylon) and _contact(pylon, beam), "upper rests on purchased deck")
		for row in range(4):
			var rib: Node3D = upper.get_node("Collision/DeckRib%d_%d" % [row, side])
			_check(_contact(beam, rib) and _contact(rib, upper.get_node("Collision/UpperDeck%d" % row)),
				"every tier has physical cantilever to rib to actual deck support")
		var post: Node3D = roof.get_node("Collision/RoofPost%d" % side)
		var roof_beam: Node3D = roof.get_node("Collision/RoofBeam%d" % side)
		_check(_contact(pylon, post), "separate roof bears on actual upper pylon top")
		_check(_contact(post, roof_beam) and _contact(roof_beam, roof.get_node("Collision/RoofSlab")),
			"each real roof support reaches full supported slab")
	for member: String in ["FinishedRoofEnd-1", "FinishedRoofEnd1",
		"FrontRoofFascia", "RearRoofFascia"]:
		_check(_contact(roof.get_node("Collision/" + member), roof.get_node("Collision/RoofSlab")),
			"every independent exposed roof finish joins supported slab")
	for step in range(10):
		var access: Node3D = upper.get_node("Collision/UpperAccess%d" % step)
		_check(_contact(deck, access), "every represented access step rests on purchased concourse")
		if step > 0:
			_check(_contact(upper.get_node("Collision/UpperAccess%d" % (step - 1)), access),
				"access steps form physically connected ascent")
	_check(_contact(upper.get_node("Collision/UpperAccess9"), upper.get_node("Collision/UpperDeck3")),
		"represented access terminates at actual rear upper deck")


func _grand_curved_roof_support(upper: Node3D, roof: Node3D) -> void:
	for side: int in [-1, 1]:
		var post: Node3D = roof.get_node("Collision/RoofPost%d" % side)
		var beam: Node3D = roof.get_node("Collision/RoofBeam%d" % side)
		_check(_contact(upper.get_node("Collision/RearPylon%d" % side), post),
			"actual unchanged curved upper pylon supports genuine curved roof post")
		_check(_contact(post, beam) and _contact(beam, roof.get_node("Collision/RoofSlab")),
			"genuine curved roof beams physically connect posts and slab")
	for world: Vector3 in _all_points(roof):
		var local: Vector3 = roof.global_transform.affine_inverse() * world
		_check(StadiumCurvedCanopySites.contains_local(local), "curved canopy fits original reserve")
		_check(local.y >= 9.7999 or Vector2(local.x, local.z).length() >= 25.199,
			"genuine curved roof retains its own full occupied-head clearance")


func _grand_no_penetration(root: Node3D, neighbors: Array[Node3D]) -> void:
	var protected: Array[RID] = []
	for neighbor: Node3D in neighbors:
		if neighbor == root:
			continue
		for body: StaticBody3D in neighbor.get_node("Collision").get_children():
			protected.append(body.get_rid())
	for body: StaticBody3D in root.get_node("Collision").get_children():
		for shape: CollisionShape3D in body.get_children():
			var inner: Shape3D
			if shape.shape is BoxShape3D:
				inner = shape.shape.duplicate()
				inner.size -= Vector3.ONE * 0.002
			else:
				var hull: PackedVector3Array = shape.shape.points
				var center: Vector3 = Vector3.ZERO
				for point: Vector3 in hull:
					center += point / hull.size()
				var clearance: float = INF
				for plane: Plane in _hull_planes(hull):
					clearance = minf(clearance, absf(plane.distance_to(center)))
				var fraction: float = maxf(0.5, 1 - 0.001 / clearance)
				var points: PackedVector3Array = []
				for point: Vector3 in hull:
					points.append(center.lerp(point, fraction))
				inner = ConvexPolygonShape3D.new()
				inner.points = points
			inner.margin = 0
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = inner
			query.transform = shape.global_transform
			query.margin = 0
			query.collision_mask = 1
			for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 1024):
				_check(hit.rid not in protected,
					"actual contracted solid never penetrates another independently purchased host")


func _grand_curved_stack_support(stack: Array) -> void:
	var lower: Node3D = stack[0]
	var concourse: Node3D = stack[1]
	var upper: Node3D = stack[2]
	var deck: Node3D = concourse.get_node("Collision/ConcourseDeck")
	var saddle: Node3D = concourse.get_node("Collision/RearSaddle")
	_check(_contact(lower.get_node("Collision/RearRim"), saddle) and _contact(deck, saddle),
		"curved saddle physically contacts genuine lower rim and purchased rear deck")
	for side: int in [-1, 1]:
		var pylon: Node3D = upper.get_node("Collision/RearPylon%d" % side)
		var beam: Node3D = upper.get_node("Collision/Cantilever%d" % side)
		_check(_contact(deck, pylon) and _contact(pylon, beam),
			"genuine curved deck physically supports pylon and cantilever")
		for row in range(4):
			var rib: Node3D = upper.get_node("Collision/DeckRib%d_%d" % [row, side])
			_check(_contact(beam, rib) and _contact(rib, upper.get_node("Collision/UpperDeck%d" % row)),
				"each genuine curved row has full purchased deck-rib-cantilever support")
	for step in range(8):
		var access: Node3D = upper.get_node("Collision/UpperAccess%d" % step)
		var support: Node3D = deck if step < 6 \
			else upper.get_node("Collision/UpperAccess%d" % (step - 1))
		_check(_contact(support, access), "curved upper access joins actual supported spine")
	_check(_contact(upper.get_node("Collision/UpperAccess7"), upper.get_node("Collision/UpperDeck3")),
		"curved upper access terminates at actual rear deck")
