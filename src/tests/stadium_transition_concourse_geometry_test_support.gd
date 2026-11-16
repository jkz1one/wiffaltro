extends "res://src/tests/stadium_transition_concourse_host_test_support.gd"
## Independent exact-volume, owned-footprint and physical support assertions.


func _concourse_geometry(root: Node3D) -> void:
	_check(root.transform == Transform3D.IDENTITY, "separate world-shaped hand installs at identity")
	_check(root.get_child_count() == 2 and root.has_node("Visual") and root.has_node("Collision"),
		"complete purchased model has only its own Visual and Collision branches")
	_check(root.get_meta("represented_seats", -1) == 0, "circulation purchase grants no extra crowd")
	_check(root.get_node("Collision").get_child_count() == 62
		and root.get_node("Visual").get_child_count() == 62,
		"nine supported terraces and guards, saddle and two handed access interfaces only")
	for node: Node3D in root.find_children("*", "Node3D", true, false):
		_check(node.transform == Transform3D.IDENTITY,
			"all actual owned branches are world-baked without reflection or hidden offsets")
		_check(not node.get_meta("represented_audience", false), "no free represented spectator")
	var right: bool = root.get_meta("site") == "JOIN-R"
	for point: Vector3 in _all_points(root):
		_check(CS.contains(root.get_meta("site"), point),
			"full actual mesh and hull in owned reservation")
		_check(_owned_footprint(right, point), "independently bounded strip and explicit attachments")
		_check(point.y >= -0.001 and point.y <= 7.851, "whole purchased height including every guard")
		_check(StadiumProperty.contains("mogul", AABB(point, Vector3.ZERO)),
			"every actual mesh and collision vertex fits legal Mogul property")
		_check(not StadiumReceiverNetModels.ENVELOPE.grow(0.25).has_point(point),
			"full owned circulation remains clear of actual receiver reserve")
	for body: StaticBody3D in root.get_node("Collision").get_children():
		_exact_convex_solid(root, body)
	for index in range(9):
		var minimum: float = _prefix_height(root, "Terrace%d" % index, true)
		var maximum: float = _prefix_height(root, "Terrace%d" % index, false)
		_check(is_zero_approx(minimum) and absf(maximum - (5.5 + index * 0.2)) < 0.001,
			"every main circulation terrace owns a solid grounded mass at its authored step height")
	_check(absf(_prefix_height(root, "BowlBridge", true) - 5.35) < 0.001
		and absf(_prefix_height(root, "BaselineBridge", true) - 6.95) < 0.001,
		"bridges cross above intact actual neighbor end caps rather than cutting them")
	for step in range(4):
		_check(absf(_prefix_height(root, "BowlTread%d" % step, false)
			- (5.31 - step * 0.19)) < 0.001, "bowl return provides explicit supported descending treads")
		_check(absf(_prefix_height(root, "BaselineTread%d" % step, false)
			- (6.91 - step * 0.19)) < 0.001, "baseline return has its own handed supported treads")


func _owned_footprint(right: bool, point: Vector3) -> bool:
	if _in_join_patch(right, point, Vector2(0, 1), Vector2(7, 10)):
		return true
	if point.y <= 6.151 and _in_join_patch(right, point, Vector2(0.45, 0.55), Vector2(6.75, 7.15)):
		return true
	var radial: Vector2 = Vector2(absf(point.x), point.z)
	var angle: float = rad_to_deg(atan2(radial.x, radial.y))
	# Full convex arc interiors have chord minima; this independent broad polar bound
	# complements the exact per-segment site containment above, without moving a site.
	if point.y >= 4.549 and point.y <= 5.501 and radial.length() >= 26.198 \
		and radial.length() <= 27.401 and angle >= 104.999 and angle <= 108.301:
		return true
	var site: String = "BASE-R1" if right else "BASE-L1"
	var local: Vector3 = StadiumBaselineSites.pose(site).affine_inverse() * point
	if local.y < 6.149 or local.y > 7.101:
		return false
	if right:
		return local.x >= 2.399 and local.x <= 3.051 and local.z >= 8.199 and local.z <= 8.451 \
			or local.x >= 2.399 and local.x <= 2.781 and local.z >= 8.449 and local.z <= 9.651
	return local.x >= -3.051 and local.x <= -1.449 and local.z >= 8.299 and local.z <= 9.501


func _in_join_patch(right: bool, point: Vector3, t: Vector2, u: Vector2) -> bool:
	var polygon: PackedVector2Array = []
	for pair: Vector2 in [Vector2(t.x, u.x), Vector2(t.y, u.x),
		Vector2(t.y, u.y), Vector2(t.x, u.y)]:
		polygon.append(_independent_join_point(right, pair.x, pair.y))
	var probe: Vector2 = Vector2(point.x, point.z)
	var sign_value: float = 1 if right else -1
	for index in range(4):
		var first: Vector2 = polygon[index]
		var second: Vector2 = polygon[(index + 1) % 4]
		if sign_value * (second - first).cross(probe - first) > 0.002:
			return false
	return true


func _independent_join_point(right: bool, t: float, u: float) -> Vector2:
	var tangent: Vector2 = Vector2(16, 29.4).normalized()
	var normal: Vector2 = Vector2(tangent.y, -tangent.x)
	var bowl: Vector2 = Vector2(sin(deg_to_rad(105)), cos(deg_to_rad(105))) * (18 + u)
	var baseline: Vector2 = Vector2(8, -6) + 12 * tangent + (3.5 + u) * normal
	var point: Vector2 = bowl.lerp(baseline, t)
	if not right:
		point.x = -point.x
	return point


func _exact_convex_solid(root: Node3D, body: StaticBody3D) -> void:
	_check(body.get_child_count() == 1 and body.collision_layer == 1 and body.collision_mask == 2,
		"one actual scenery shape per visible owned solid")
	var shape: CollisionShape3D = body.get_child(0)
	_check(shape.shape is ConvexPolygonShape3D and shape.shape.margin == 0 and not shape.disabled,
		"exact enabled convex hull with no artificial inflation")
	if not shape.shape is ConvexPolygonShape3D:
		return
	var hull: PackedVector3Array = shape.shape.points
	_member_reservation(root, str(body.name), hull)
	var mesh: MeshInstance3D = root.get_node("Visual/" + str(body.name))
	_check(mesh.mesh.get_surface_count() == 1, "each solid has one full rendered triangle surface")
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	_check(hull.size() in [6, 8] and vertices.size() == (24 if hull.size() == 6 else 36),
		"every actual solid is an exact six-corner prism or planar eight-corner hexahedron")
	var center: Vector3 = Vector3.ZERO
	for point: Vector3 in hull:
		center += point / hull.size()
		_check(point in vertices, "each actual convex corner occurs in the visible solid")
	for index in range(vertices.size()):
		_check(vertices[index] in hull, "visible solid has no unmatched geometry outside its hull")
		_check(normals[index].length() > 0.99
			and normals[index].dot(vertices[index] - center) > -0.0001,
			"independently authored hand has outward visible normals on all triangles")
	var planes: Array[Plane] = _hull_planes(hull)
	_check(planes.size() == (5 if hull.size() == 6 else 6),
		"convex solid has only five prism or six planar hexahedron faces")
	for plane: Plane in planes:
		_check_face(hull, vertices, plane)


func _member_reservation(root: Node3D, member: String, hull: PackedVector3Array) -> void:
	var right: bool = root.get_meta("site") == "JOIN-R"
	if member.begins_with("Terrace") or member.begins_with("RearGuard"):
		for point: Vector3 in hull:
			_check(_in_join_patch(right, point, Vector2(0, 1), Vector2(7, 10)),
				"whole convex main solid stays in original u7..10 strip, without borrowing attachments")
		return
	if member.begins_with("LowerSaddle"):
		for point: Vector3 in hull:
			_check(_in_join_patch(right, point, Vector2(0.45, 0.55), Vector2(6.75, 7.15))
				and point.y <= 6.151, "whole convex saddle stays in its explicit local attachment")
		return
	if member.begins_with("Bowl"):
		var angles: Vector2 = Vector2(105, 106.3)
		if member.begins_with("BowlLanding"):
			angles = Vector2(106, 106.3)
		elif member.begins_with("BowlTread"):
			var step: int = int(member.trim_prefix("BowlTread").left(1))
			angles = Vector2(106.3 + step * 0.5, 106.8 + step * 0.5)
		var polygon: PackedVector2Array = []
		for pair: Vector2 in [Vector2(26.2, angles.x), Vector2(27.4, angles.x),
			Vector2(27.4, angles.y), Vector2(26.2, angles.y)]:
			polygon.append(Vector2(sin(deg_to_rad(pair.y)), cos(deg_to_rad(pair.y))) * pair.x)
		for point: Vector3 in hull:
			var probe: Vector2 = Vector2(absf(point.x), point.z)
			_check(_convex_polygon_contains(polygon, probe) and point.y >= 4.549 and point.y <= 5.501,
				"whole convex bowl member fits its exact chord segment and explicit vertical reserve")
		return
	_check(member.begins_with("Baseline"), "no anonymous solid may borrow another attachment reserve")
	var pose: Transform3D = StadiumBaselineSites.pose("BASE-R1" if right else "BASE-L1")
	for point: Vector3 in hull:
		var local: Vector3 = pose.affine_inverse() * point
		var x: Vector2 = Vector2(2.4, 3.05) if right else Vector2(-3.05, -1.45)
		var z: Vector2 = Vector2(8.2, 9.65) if right else Vector2(8.3, 9.5)
		_check(local.x >= x.x - 0.001 and local.x <= x.y + 0.001
			and local.z >= z.x - 0.001 and local.z <= z.y + 0.001
			and local.y >= 6.149 and local.y <= 7.101,
			"whole convex baseline member stays in the separately authored handed return reserve")


func _convex_polygon_contains(polygon: PackedVector2Array, probe: Vector2) -> bool:
	var positive: bool = false
	var negative: bool = false
	for index in range(polygon.size()):
		var first: Vector2 = polygon[index]
		var second: Vector2 = polygon[(index + 1) % polygon.size()]
		var signed_distance: float = (second - first).cross(probe - first)
		positive = positive or signed_distance > 0.002
		negative = negative or signed_distance < -0.002
	return not (positive and negative)


func _hull_planes(hull: PackedVector3Array) -> Array[Plane]:
	var result: Array[Plane] = []
	for a in range(hull.size() - 2):
		for b in range(a + 1, hull.size() - 1):
			for c in range(b + 1, hull.size()):
				var normal: Vector3 = (hull[b] - hull[a]).cross(hull[c] - hull[a])
				if normal.length() < 0.00001:
					continue
				normal = normal.normalized()
				var positive: bool = false
				var negative: bool = false
				for point: Vector3 in hull:
					var distance: float = normal.dot(point - hull[a])
					positive = positive or distance > 0.00002
					negative = negative or distance < -0.00002
				if positive and negative:
					continue
				if positive:
					normal = -normal
				var plane: Plane = Plane(normal, normal.dot(hull[a]))
				var duplicate: bool = false
				for old: Plane in result:
					duplicate = duplicate or (old.normal.dot(normal) > 0.99999
						and absf(old.d - plane.d) < 0.0001)
				if not duplicate:
					result.append(plane)
	return result


func _check_face(hull: PackedVector3Array, vertices: PackedVector3Array, plane: Plane) -> void:
	var face: Array[Vector3] = []
	var center: Vector3 = Vector3.ZERO
	for point: Vector3 in hull:
		if absf(plane.distance_to(point)) < 0.00005:
			face.append(point)
			center += point
	_check(face.size() in [3, 4], "every independent convex face is triangle or coplanar quad")
	if face.size() < 3:
		return
	center /= face.size()
	var axis: Vector3 = (face[0] - center).normalized()
	var across: Vector3 = plane.normal.cross(axis)
	face.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return atan2((a - center).dot(across), (a - center).dot(axis)) \
			< atan2((b - center).dot(across), (b - center).dot(axis)))
	var expected: float = 0
	for index in range(face.size()):
		var edge: Vector3 = face[(index + 1) % face.size()] - center
		expected += (face[index] - center).cross(edge).length() / 2
	var actual: float = 0
	var count: int = 0
	var edges: Dictionary = {}
	for index in range(0, vertices.size(), 3):
		var triangle: Array[Vector3] = [vertices[index], vertices[index + 1], vertices[index + 2]]
		if not (absf(plane.distance_to(triangle[0])) < 0.00005
			and absf(plane.distance_to(triangle[1])) < 0.00005
			and absf(plane.distance_to(triangle[2])) < 0.00005):
			continue
		count += 1
		actual += (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).length() / 2
		for corner in range(3):
			var a: int = face.find(triangle[corner])
			var b: int = face.find(triangle[(corner + 1) % 3])
			var edge: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			edges[edge] = edges.get(edge, 0) + 1
	_check(count == face.size() - 2 and absf(actual - expected) < 0.0002,
		"rendered triangles exactly cover each actual convex face with matching area")
	for index in range(face.size()):
		var next: int = (index + 1) % face.size()
		var boundary: Vector2i = Vector2i(mini(index, next), maxi(index, next))
		_check(edges.get(boundary, 0) == 1, "every convex face boundary appears exactly once")
	for edge: Vector2i in edges:
		var outer: bool = edge.y - edge.x == 1 or (edge.x == 0 and edge.y == face.size() - 1)
		_check(edges[edge] == (1 if outer else 2),
			"internal triangulation edges pair without ghost volume")


func _prefix_bodies(root: Node3D, prefix: String) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for body: Node3D in root.get_node("Collision").get_children():
		if str(body.name).begins_with(prefix):
			result.append(body)
	return result


func _prefix_height(root: Node3D, prefix: String, minimum: bool) -> float:
	var result: float = INF if minimum else -INF
	for body: Node3D in _prefix_bodies(root, prefix):
		var shape: CollisionShape3D = body.get_child(0)
		for point: Vector3 in shape.shape.points:
			result = minf(result, point.y) if minimum else maxf(result, point.y)
	return result


func _contact(first: Node3D, second: Node3D) -> bool:
	for shape: CollisionShape3D in second.get_children():
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.margin = 0.003
		query.collision_mask = 1
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 256):
			if hit.collider == first:
				return true
	return false


func _prefix_contact(root: Node3D, prefix: String, host: Node3D, member: String) -> bool:
	var support: Node3D = host.get_node("Collision/" + member)
	for body: Node3D in _prefix_bodies(root, prefix):
		if _contact(support, body):
			return true
	return false


func _concourse_support(root: Node3D, hosts: Dictionary) -> void:
	var inputs: Array = hosts.inputs
	_check(_prefix_contact(root, "LowerSaddle", inputs[0], "RearRim"),
		"own saddle contacts the actual frozen lower transition rear rim")
	_check(_prefix_contact(root, "BowlLanding", inputs[2], "ConcourseDeck"),
		"bowl landing rests on actual purchased curved concourse floor")
	_check(_prefix_contact(root, "BowlBridge", inputs[2],
		"FinishedEnd-1" if hosts.right else "FinishedEnd1"),
		"bowl bridge bears on intact actual handed end cap")
	_check(_prefix_contact(root, "BaselineLanding", inputs[4], "ConcourseDeck"),
		"handed straight landing rests on actual purchased baseline concourse floor")
	_check(_prefix_contact(root, "BaselineBridge", inputs[4],
		"FinishedEnd1" if hosts.right else "FinishedEnd-1"),
		"baseline bridge contacts intact actual stair-side or solid-side end cap")
	for step in range(4):
		_check(_prefix_contact(root, "BowlTread%d" % step, inputs[2], "ConcourseDeck"),
			"each owned bowl return tread has actual host-floor support")
		_check(_prefix_contact(root, "BaselineTread%d" % step, inputs[4], "ConcourseDeck"),
			"each owned straight return tread has actual host-floor support")
	_connected_structure(root)


func _connected_structure(root: Node3D) -> void:
	var graph: Dictionary = {}
	var reached: Array[RID] = []
	var bodies: Array[Node] = root.get_node("Collision").get_children()
	for body: StaticBody3D in bodies:
		var shape: CollisionShape3D = body.get_child(0)
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.margin = 0.003
		query.collision_mask = 1
		var contacts: Array[RID] = []
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 256):
			if hit.collider in bodies and hit.collider != body:
				contacts.append(hit.rid)
		graph[body.get_rid()] = contacts
		for point: Vector3 in shape.shape.points:
			if absf((shape.global_transform * point).y) < 0.001:
				if body.get_rid() not in reached:
					reached.append(body.get_rid())
	for iteration in range(bodies.size()):
		var added: bool = false
		for rid: RID in graph:
			if rid in reached:
				continue
			for neighbor: RID in graph[rid]:
				if neighbor in reached:
					reached.append(rid)
					added = true
					break
		if not added:
			break
	_check(reached.size() == bodies.size(),
		"every owned guard, saddle, cap crossing and return tread joins a real grounded owned mass")


func _no_host_penetration(root: Node3D, hosts: Array[Node3D]) -> void:
	var protected: Array[RID] = []
	for host: Node3D in hosts:
		for body: StaticBody3D in host.get_node("Collision").get_children():
			protected.append(body.get_rid())
	for body: StaticBody3D in root.get_node("Collision").get_children():
		var shape: CollisionShape3D = body.get_child(0)
		var hull: PackedVector3Array = shape.shape.points
		var center: Vector3 = Vector3.ZERO
		for point: Vector3 in hull:
			center += point / hull.size()
		var clearance: float = INF
		for plane: Plane in _hull_planes(hull):
			clearance = minf(clearance, absf(plane.distance_to(center)))
		var contraction: float = maxf(0.5, 1 - 0.001 / clearance)
		var inner: PackedVector3Array = []
		for point: Vector3 in hull:
			inner.append(center.lerp(point, contraction))
		var probe: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		probe.points = inner
		probe.margin = 0
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = probe
		query.transform = shape.global_transform
		query.margin = 0
		query.collision_mask = 1
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 256):
			_check(hit.rid not in protected,
				"actual concourse interior never penetrates any frozen host or optional upper")
