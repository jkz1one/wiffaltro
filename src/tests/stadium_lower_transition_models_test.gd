extends "res://src/tests/stadium_curved_lower_models_test.gd"
## Working handed lower studies; inherits actual-panel-only LOS and native draw handshake.

const TS = preload("res://src/gameplay/stadium/stadium_lower_transition_sites.gd")
const TM = preload("res://src/presentation/stadium/stadium_lower_transition_models.gd")
var _transitions: Array[Node3D] = []
var _neighbors: Array[Node3D] = []
var _baseline_rays: Array[Dictionary] = []


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var net: Node3D = StadiumReceiverNetModels.create()
	add_child(net)
	_actual_net_clearance(net)
	_setup_view()
	for site: String in TS.SITES:
		_check(TS.fits(site, "mogul") and not TS.fits(site, "club"), "Mogul ground site")
		var root: Node3D = TM.create_right() if site == "JOIN-R" else TM.create_left()
		add_child(root)
		root.transform = TS.pose(site)
		_transitions.append(root)
		_check(root.get_meta("stadium_item") == ("ST-085" if site == "JOIN-R" else "ST-088"),
			"each hand is a distinct complete identity")
		_check(root.get_meta("represented_seats") == 18, "only owned represented lower crowd")
		_check(root.get_meta("baseline_end") == ("stair" if site == "JOIN-R" else "solid"),
			"different real baseline end treatments")
		_check(root.get_child_count() == 2 and root.get_node("Collision").get_child_count() == 20,
			"complete lower assembly only: six terraces, twelve ends, two rims, no free layers")
		_standalone(root)
		_convex_correspondence(root)
		for phase: float in [-PI / 2, 0, PI / 2]:
			StadiumCurvedLowerModels.animate_crowd(root, phase)
			_transition_points(root)
		StadiumCurvedLowerModels.animate_crowd(root, 0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_sightlines(root, net)
		var hand: float = 1 if site == "JOIN-R" else -1
		await _capture("%s-standalone-finished-ends" % root.get_meta("stadium_item"),
			Vector3(hand * 9, 12, 9), Vector3(hand * 20, 3, -2), 13)
	_check(not TS.fits("JOIN-X", "mogul") and TS.item("JOIN-X").is_empty(),
		"no arbitrary joins or implicit mirrored item")
	# Remove both real transition bodies: absent is a real legal state, not hidden collision.
	for root: Node3D in _transitions:
		remove_child(root)
	var frozen: Array[String] = []
	for site: String in StadiumCurvedLowerSites.SITES:
		var lower: Node3D = StadiumCurvedLowerModels.create()
		add_child(lower)
		lower.transform = StadiumCurvedLowerSites.pose(site)
		_neighbors.append(lower)
		frozen.append(_neighbor_signature(lower))
		_ground_and_ends(lower)
		if site in StadiumCurvedLowerSites.GRAND_I:
			var concourse: Node3D = StadiumCurvedStackModels.create_concourse(lower, site)
			_check(concourse != null, "central lower accepts separate concourse")
			if concourse != null:
				add_child(concourse)
				var upper: Node3D = StadiumCurvedStackModels.create_upper(lower, concourse, site)
				_check(upper != null, "only central three get independently supported upper")
				if upper != null:
					add_child(upper)
	for site: String in StadiumBaselineSites.SITES:
		var baseline: Node3D = StadiumBaselineStandModels.lower()
		add_child(baseline)
		baseline.transform = StadiumBaselineSites.pose(site)
		_neighbors.append(baseline)
		frozen.append(_neighbor_signature(baseline))
		_check(baseline.has_node("Collision/SolidRow0")
			and baseline.has_node("Collision/EntryStep39"), "absent transition leaves finished baseline")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_count_item("ST-085") == 0 and _count_item("ST-088") == 0,
		"both absent joins contain no invisible bridge or audience copy")
	_record_baseline_paths(net)
	await _baseline_path_control(net)
	await _capture("ST085-088-absent-legal-breaks", Vector3(42, 34, 28), Vector3(0, 3, -8), 64)
	for root: Node3D in _transitions:
		add_child(root)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_standalone(root)
		var right: bool = root.get_meta("site") == "JOIN-R"
		var bowl: Node3D = _neighbors[0 if right else 4]
		var base: Node3D = _neighbors[7 if right else 5]
		for phase: float in [-PI / 2, 0, PI / 2]:
			StadiumCurvedLowerModels.animate_crowd(root, phase)
			StadiumCurvedLowerModels.animate_crowd(bowl, phase)
			_transition_points(root)
			_separating_planes(root, bowl, base)
		StadiumCurvedLowerModels.animate_crowd(root, 0)
		StadiumCurvedLowerModels.animate_crowd(bowl, 0)
		_no_physical_overlap(root)
		_sightlines(root, net)
	_check(_count_item("ST-081") == 5 and _count_item("ST-083") == 3
		and _count_item("ST-082") == 3 and _count_item("ST-029") == 4,
		"five complete lowers, three central stacks, four frozen baseline bays")
	_check(_count_item("ST-085") == 1 and _count_item("ST-088") == 1
		and _count_item("ST-086") == 0 and _count_item("ST-089") == 0,
		"Grand II lower-only join pair, never a free concourse")
	for index in range(_neighbors.size()):
		_check(frozen[index] == _neighbor_signature(_neighbors[index]),
			"installed transitions never stretch, lift or cut neighbors")
	for root: Node3D in _transitions:
		_sightlines(root, net)
	for child: Node in get_children():
		if child.get_meta("stadium_item", "") in ["ST-081", "ST-082"]:
			_sightlines(child, net)
	_compare_baseline_paths(net)
	await _sightline_controls(net)
	await _capture("ST085-088-grand-II-lower-joins-overview", Vector3(42, 34, 28),
		Vector3(0, 3, -8), 64)
	for hand: int in [-1, 1]:
		await _capture("ST085-088-%s-actual-interface" % ("right-stair" if hand == 1 else "left-solid"),
			Vector3(hand * 31, 14, 6), Vector3(hand * 20, 3.2, -2), 17)
	_check(_native._failures == 0, "native handshake failures propagate")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro lower transition models passed: "
			+ "separate hands, actual neighbors, ground support.")
	get_tree().quit(0 if _failures == 0 else 1)


func _count_item(item: String) -> int:
	var count: int = 0
	for child: Node in get_children():
		if child.get_meta("stadium_item", "") == item:
			count += 1
	return count


func _standalone(root: Node3D) -> void:
	_check(root.transform == Transform3D.IDENTITY,
		"positive unit identity pose without free reflection")
	for node: Node3D in root.find_children("*", "Node3D", true, false):
		_check(node.transform.basis.determinant() > 0.999, "all actual branches positive-handed")
	for row in range(TM.ROWS):
		var terrace: MeshInstance3D = root.get_node("Visual/SolidTerrace%d" % row)
		_check(is_zero_approx(terrace.get_aabb().position.y), "every terrace reaches ground itself")
		for end: String in ["Bowl", "Baseline"]:
			_check(root.has_node("Visual/Finished%sEnd%d" % [end, row])
				and root.has_node("Collision/Finished%sEnd%d" % [end, row]),
				"every exposed stepped end has its own solid finish")
		_check(root.has_node("Visual/AccessAccent%d" % row), "simple represented access on solid base")
		var cap: MeshInstance3D = root.get_node("Visual/FinishedBaselineEnd%d" % row)
		var points: PackedVector3Array = cap.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var height: float = 0.40 if root.get_meta("site") == "JOIN-R" else 0.75
		var offsets: Array[float] = []
		var tangent: Vector2 = Vector2(16, 29.4).normalized()
		var u: float = 0.35 + row * 1.05 + 0.525
		var start: Vector2 = Vector2(sin(deg_to_rad(105)), cos(deg_to_rad(105))) * (18 + u)
		var first: float = (start - Vector2(8, -6)).dot(tangent)
		for point: Vector3 in points:
			var station: float = (Vector2(absf(point.x), point.z) - Vector2(8, -6)).dot(tangent)
			var expected: float = lerpf(1.30 + row * 0.45, 3.0 + row * 0.60,
				(station - first) / (12 - first))
			offsets.append(point.y - expected)
		_check(absf(offsets.min()) < 0.001 and absf(offsets.max() - height) < 0.001,
			"independently measured handed cap rests on its actual terrace")


func _all_points(root: Node3D) -> PackedVector3Array:
	var result: PackedVector3Array = []
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var points: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				result.append(mesh.global_transform * point)
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		var debug: Mesh = shape.shape.get_debug_mesh()
		for surface in range(debug.get_surface_count()):
			var points: PackedVector3Array = debug.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				result.append(shape.global_transform * point)
	return result


func _transition_points(root: Node3D) -> void:
	for point: Vector3 in _all_points(root):
		_check(TS.contains(root.get_meta("site"), point),
			"full solid, audience and sway inside retained footprint")
		_check(not StadiumReceiverNetModels.ENVELOPE.grow(0.25).has_point(point),
			"whole join clear of actual receiver reserve")
	for child: Node3D in root.get_node("Visual").get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh == null:
			continue
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var center: Vector3 = mesh.get_aabb().get_center()
		for index in range(points.size()):
			_check(normals[index].length() > 0.99
				and normals[index].dot(points[index] - center) > -0.001,
				"both independently wound convex hands have outward normals")
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		_check(shape.shape is ConvexPolygonShape3D and shape.shape.margin == 0,
			"matching exact convex solids with zero inflation")


func _separating_planes(root: Node3D, bowl: Node3D, baseline: Node3D) -> void:
	var right: bool = root.get_meta("site") == "JOIN-R"
	var hand: float = 1 if right else -1
	# Independently evaluate geometric planes using exact current rail and bowl site axes.
	var normal: Vector3 = Vector3(hand * cos(deg_to_rad(105)), 0, -sin(deg_to_rad(105)))
	var tangent: Vector3 = Vector3(hand * 16, 0, 29.4).normalized()
	var origin: Vector3 = Vector3(hand * 8, 0, -6)
	var join_bowl: float = -INF
	var join_base: float = -INF
	for point: Vector3 in _all_points(root):
		join_bowl = maxf(join_bowl, point.dot(normal))
		join_base = maxf(join_base, (point - origin).dot(tangent))
	var bowl_min: float = INF
	for point: Vector3 in _all_points(bowl):
		bowl_min = minf(bowl_min, point.dot(normal))
	var base_min: float = INF
	for point: Vector3 in _all_points(baseline):
		base_min = minf(base_min, (point - origin).dot(tangent))
	_check(bowl_min - join_bowl > 0.25, "actual inset bowl and complete transition have >25cm gap")
	_check(base_min - join_base > 0.18, "actual stair/solid near edge has >18cm full-hull gap")
	print("Transition %s actual gaps: bowl %.5f m; baseline %.5f m" %
		[root.get_meta("site"), bowl_min - join_bowl, base_min - join_base])


func _no_physical_overlap(root: Node3D) -> void:
	var own: Array[RID] = []
	for body: StaticBody3D in root.get_node("Collision").get_children():
		own.append(body.get_rid())
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.collision_mask = 1
		query.margin = 0
		query.exclude = own
		_check(get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
			"actual transition collider does not overlap any installed neighbor or other hand")


func _neighbor_signature(root: Node3D) -> String:
	# Include actual box debug geometry too; the stack-specific hash accepts only convex hosts.
	return var_to_bytes([StadiumCurvedStackSites.geometry_signature(root),
		_all_points(root)]).hex_encode().sha256_text()


func _opaque_path(from: Vector3, to: Vector3, net: Node3D) -> Array[RID]:
	var result: Array[RID] = []
	var excluded: Array[RID] = []
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	# Traverse the entire original segment repeatedly, including beyond old opaque guards.
	# Only identity-verified original transparent receiver panels are omitted from evidence.
	for layer in range(1024):
		query.exclude = excluded
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return result
		var body: CollisionObject3D = hit.collider
		var rid: RID = body.get_rid()
		_check(rid not in excluded, "full opaque traversal advances by exact body identity")
		if rid in excluded:
			return result
		excluded.append(rid)
		if not _verified_panel(hit, net):
			result.append(rid)
	_check(false, "full opaque traversal exhausted its bound instead of proving completion")
	return result


func _record_baseline_paths(net: Node3D) -> void:
	var blocked: int = 0
	for root: Node3D in _neighbors:
		if root.get_meta("stadium_item") != "ST-029":
			continue
		for anchor: Node3D in root.get_node("Visual").get_children():
			if not anchor.get_meta("represented_audience", false):
				continue
			var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
			var target: Vector3 = Vector3(0, 1, 8)
			var blockers: Array[RID] = _opaque_path(eye, target, net)
			_baseline_rays.append({"eye": eye, "target": target, "blockers": blockers})
			if not blockers.is_empty():
				blocked += 1
	_check(_baseline_rays.size() == 200, "all actual baseline audience eyes recorded before joins")
	_check(blocked > 0, "frozen baseline v1 opaque guard failures remain visible in evidence")
	print("Transition baseline before/after proof: 200 eyes; %d existing blocked rays" % blocked)


func _compare_baseline_paths(net: Node3D) -> void:
	for record: Dictionary in _baseline_rays:
		var actual: Array[RID] = _opaque_path(record.eye, record.target, net)
		_check(actual == record.blockers,
			"both transitions preserve the full opaque hit sequence for every baseline spectator")
		for transition: Node3D in _transitions:
			for body: StaticBody3D in transition.get_node("Collision").get_children():
				_check(body.get_rid() not in actual,
					"no transition solid hides behind any preexisting baseline obstruction")


func _baseline_path_control(net: Node3D) -> void:
	var blocked_record: Dictionary = {}
	for record: Dictionary in _baseline_rays:
		if not record.blockers.is_empty():
			blocked_record = record
			break
	_check(not blocked_record.is_empty(), "physical layered baseline control has an old opaque hit")
	if blocked_record.is_empty():
		return
	var control: Node3D = StadiumBaselineStandModels._root("ST-085")
	add_child(control)
	var center: Vector3 = blocked_record.eye.lerp(blocked_record.target, 0.5)
	StadiumSeatingModels._box(control, "FartherOpaqueBaselineControl", center,
		Vector3(0.2, 0.2, 0.2), Color.RED)
	var body: StaticBody3D = control.get_node("Collision/FartherOpaqueBaselineControl")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var changed: Array[RID] = _opaque_path(blocked_record.eye, blocked_record.target, net)
	_check(changed != blocked_record.blockers and body.get_rid() in changed,
		"full baseline traversal detects a real added opaque body despite an existing blocker")
	for previous: RID in blocked_record.blockers:
		_check(previous in changed, "old opaque evidence is retained, never globally exempted")
	control.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_opaque_path(blocked_record.eye, blocked_record.target, net) == blocked_record.blockers,
		"removing physical extra blocker restores the original complete opaque sequence")


func _convex_correspondence(root: Node3D) -> void:
	var faces: Array = [[0, 1, 2, 3], [4, 5, 6, 7], [0, 4, 5, 1],
		[1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]
	for body: StaticBody3D in root.get_node("Collision").get_children():
		var shape: CollisionShape3D = body.get_child(0)
		var hull: PackedVector3Array = shape.shape.points
		var mesh: MeshInstance3D = root.get_node("Visual/" + str(body.name))
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_check(hull.size() == 8 and vertices.size() == 36,
			"every actual solid has eight hull corners and twelve rendered triangles")
		if hull.size() != 8 or vertices.size() != 36:
			continue
		for point: Vector3 in hull:
			_check(point in vertices, "every actual collider corner is present in rendered mesh")
		for point: Vector3 in vertices:
			_check(point in hull, "rendered solid contains only its exact collider corners")
		for face: Array in faces:
			var a: Vector3 = hull[face[0]]
			var b: Vector3 = hull[face[1]]
			var c: Vector3 = hull[face[2]]
			var d: Vector3 = hull[face[3]]
			var normal: Vector3 = (b - a).cross(c - a).normalized()
			_check(absf(normal.dot(d - a)) < 0.00001,
				"all six actual quad faces are coplanar, including affine ramp tops")
			var expected_area: float = ((b - a).cross(c - a).length()
				+ (c - a).cross(d - a).length()) / 2
			var actual_area: float = 0
			var count: int = 0
			for index in range(0, vertices.size(), 3):
				var va: Vector3 = vertices[index]
				var vb: Vector3 = vertices[index + 1]
				var vc: Vector3 = vertices[index + 2]
				if absf(normal.dot(va - a)) < 0.00001 \
					and absf(normal.dot(vb - a)) < 0.00001 \
					and absf(normal.dot(vc - a)) < 0.00001:
					count += 1
					actual_area += (vb - va).cross(vc - va).length() / 2
			_check(count == 2 and absf(actual_area - expected_area) < 0.0001,
				"each collider face has exactly two covering triangles, no diagonal ghost volume")
