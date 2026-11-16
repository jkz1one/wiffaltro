extends "res://src/tests/stadium_straight_stack_host_test_support.gd"
## Reuse exact original-panel transparency, whole-ray audit and native handshake only.

var _straight_lowers: Array[Node3D] = []
var _straight_concourses: Array[Node3D] = []
var _straight_uppers: Array[Node3D] = []


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var net: Node3D = StadiumReceiverNetModels.create()
	add_child(net)
	_actual_net_clearance(net)
	_check(StadiumReceiverNetModels.VERSION == 2, "corrected actual receiver v2")
	_check(SM.create_concourse(null, "BASE-R1") == null, "missing lower rejects")
	var signatures: Array[String] = []
	for site: String in StadiumBaselineSites.SITES:
		_check(SS.fits(site, "club") and SS.fits(site, "mogul")
			and not SS.fits(site, "expanded"), "full stack legal property reservation at every rail site")
		var lower: Node3D = StadiumBaselineStandModels.lower()
		add_child(lower)
		lower.transform = StadiumBaselineSites.pose(site)
		_straight_lowers.append(lower)
		signatures.append(SS.geometry_signature(lower))
		_check(not signatures.back().is_empty(), "frozen lower signature is substantive")
		_check(SS.valid_lower(lower, site), "all four authentic rail sites accepted")
		_check(SM.create_upper(lower, null, site) == null, "lower alone never grants upper")
		_check(lower.basis.get_scale().is_equal_approx(Vector3.ONE)
			and is_equal_approx(lower.basis.determinant(), 1), "positive unit handed rail pose")
		_audit_lower(lower)
	await _settle_physics()
	_record_straight_paths(net)
	await _baseline_path_control(net)
	_setup_view()
	await _capture("ST029-four-frozen-lowers", Vector3(36, 31, 32), Vector3(0, 4, 6), 59)
	for index in range(_straight_lowers.size()):
		var lower: Node3D = _straight_lowers[index]
		var site: String = StadiumBaselineSites.SITES[index]
		var concourse: Node3D = SM.create_concourse(lower, site)
		_check(concourse != null, "matching lower accepts complete independent concourse")
		if concourse == null:
			continue
		add_child(concourse)
		_straight_concourses.append(concourse)
		_addon_geometry(concourse)
		_check(SM.create_concourse(lower, site) == null, "one concourse per socket")
	await _settle_physics()
	_compare_straight_paths(net)
	await _capture("ST031-four-concourses-without-uppers", Vector3(38, 29, 30),
		Vector3(0, 4, 6), 61)
	for index in range(_straight_concourses.size()):
		var lower: Node3D = _straight_lowers[index]
		var concourse: Node3D = _straight_concourses[index]
		var site: String = StadiumBaselineSites.SITES[index]
		var upper: Node3D = SM.create_upper(lower, concourse, site)
		_check(upper != null, "matching actual purchased support admits one upper")
		if upper == null:
			continue
		add_child(upper)
		_straight_uppers.append(upper)
		_check(SM.create_upper(lower, concourse, site) == null, "second upper rejects")
		_addon_geometry(upper)
		_check(signatures[index] == SS.geometry_signature(lower),
			"attachment does not mutate any frozen lower node or geometry")
	await _settle_physics()
	_compare_straight_paths(net)
	for addon: Node3D in _straight_concourses + _straight_uppers:
		_no_lower_penetration(addon)
	for index in range(_straight_uppers.size()):
		_support(_straight_lowers[index], _straight_concourses[index], _straight_uppers[index])
	for phase: float in [-PI / 2, 0, PI / 2]:
		for upper: Node3D in _straight_uppers:
			SS.animate_crowd(upper, phase)
			_addon_geometry(upper)
			_upper_sightlines(upper, net)
	for upper: Node3D in _straight_uppers:
		SS.animate_crowd(upper, 0)
	await _sightline_controls(net)
	await _negative_hosts()
	_camera_probes()
	await _capture("ST030-031-four-baseline-stacks", Vector3(38, 32, 33), Vector3(0, 6, 6), 64)
	if _straight_uppers.size() == 4:
		for index in [0, 1, 3]:
			_straight_lowers[index].visible = false
			_straight_concourses[index].visible = false
			_straight_uppers[index].visible = false
		var pose: Transform3D = StadiumBaselineSites.pose("BASE-R1")
		await _capture("ST030-031-front-supported-tier", pose * Vector3(11, 15, -13),
			pose * Vector3(0, 6, 4.5), 21)
		await _capture("ST030-031-rear-saddle-access", pose * Vector3(-12, 14, 21),
			pose * Vector3(0, 6, 6), 21)
		_straight_uppers[2].visible = false
		await _capture("ST031-complete-independent-concourse", pose * Vector3(-10, 11, 20),
			pose * Vector3(0, 3.5, 7), 17)
	_check(_native._failures == 0, "native capture handshake failures propagate")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro straight stack models passed: frozen lower and authentic purchased layers.")
	get_tree().quit(0 if _failures == 0 else 1)


func _settle_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _audit_lower(lower: Node3D) -> void:
	var maximum: float = 0
	for phase: float in [-PI / 2, 0, PI / 2]:
		SS.animate_crowd(lower, phase)
		_check(SS.valid_lower(lower, StadiumBaselineSites.SITES[_straight_lowers.find(lower)]),
			"genuine canonical crowd sway remains a valid frozen host")
		for world: Vector3 in _all_points(lower):
			var point: Vector3 = lower.global_transform.affine_inverse() * world
			_check(StadiumBaselineSites.LOWER_BOUNDS.grow(0.0001).has_point(point),
				"all frozen visual/collider/audience vertices fit at both sway extremes")
			maximum = maxf(maximum, point.y)
	SS.animate_crowd(lower, 0)
	_check(maximum <= 7.4 and 7.9 - maximum >= 0.49,
		"actual upper underside clears measured full lower occupied envelope")
	print("Straight frozen lower measured occupied height: ", maximum)


func _record_straight_paths(net: Node3D) -> void:
	var blocked: int = 0
	for phase: float in [-PI / 2, 0, PI / 2]:
		for lower: Node3D in _straight_lowers:
			SS.animate_crowd(lower, phase)
			for anchor: Node3D in lower.get_node("Visual").get_children():
				if not anchor.get_meta("represented_audience", false):
					continue
				var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
				var target: Vector3 = Vector3(0, 1, 8)
				var blockers: Array[RID] = _opaque_path(eye, target, net)
				_baseline_rays.append({"eye": eye, "target": target, "blockers": blockers})
				if not blockers.is_empty():
					blocked += 1
	for lower: Node3D in _straight_lowers:
		SS.animate_crowd(lower, 0)
	_check(_baseline_rays.size() == 600, "all200 frozen eyes at rest and both sway extremes")
	_check(blocked > 0, "old frozen FrontGuard blockers remain explicit evidence")
	print("Straight baseline whole-ray audit: 600 rays; existing blocked rays: ", blocked)


func _compare_straight_paths(net: Node3D) -> void:
	for record: Dictionary in _baseline_rays:
		var actual: Array[RID] = _opaque_path(record.eye, record.target, net)
		_check(actual == record.blockers, "all farther opaque hits unchanged after purchased layers")
		for addon: Node3D in _straight_concourses + _straight_uppers:
			for body: StaticBody3D in addon.get_node("Collision").get_children():
				_check(body.get_rid() not in actual, "new blocker cannot hide behind old FrontGuard")


func _upper_sightlines(upper: Node3D, net: Node3D) -> void:
	var count: int = 0
	for anchor: Node3D in upper.get_node("Visual").get_children():
		if anchor.get_meta("represented_audience", false):
			count += 1
			_check(_sightline_clear(anchor.global_position + Vector3.UP * 0.57,
				Vector3(0, 1, 8), net), "every upper eye clears actual opaque scene geometry")
	_check(count == 16, "all actual upper spectators audited, no metadata-skipped audience")


func _addon_geometry(root: Node3D) -> void:
	for point_world: Vector3 in _all_points(root):
		var point: Vector3 = root.global_transform.affine_inverse() * point_world
		_check(SS.BOUNDS.grow(0.0001).has_point(point),
			"every mesh/collider/sway vertex in own reservation")
		for land: String in ["club", "mogul"]:
			_check(StadiumProperty.contains(land, AABB(point_world, Vector3.ZERO)),
				"every actual vertex including socket fits legal property")
		_check(not StadiumReceiverNetModels.ENVELOPE.grow(0.25).has_point(point_world),
			"full actual addon remains outside receiver occupied envelope")
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var pose: Transform3D = root.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				_separation(root, str(mesh.name), pose * vertex)
	for body: StaticBody3D in root.get_node("Collision").get_children():
		var shape: CollisionShape3D = body.get_child(0)
		var visual: MeshInstance3D = root.get_node("Visual/" + str(body.name))
		_check(shape.shape is BoxShape3D and visual.mesh is BoxMesh,
			"all physical solids use exact box mesh/hull correspondence")
		_check(body.transform.is_equal_approx(visual.transform)
			and shape.transform == Transform3D.IDENTITY
			and shape.shape.size.is_equal_approx(visual.mesh.size) and shape.shape.margin == 0,
			"exact complete collider volume and transform match visible purchased solid")
		for vertex: Vector3 in visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			_separation(root, str(body.name), body.transform * vertex)
	for side: int in [-1, 1]:
		if root.get_meta("stadium_item") == "ST-031":
			_check(root.has_node("Collision/FinishedEnd%d" % side), "independent concourse ends")
		else:
			for row in range(4):
				_check(root.has_node("Collision/FinishedEnd%d_%d" % [row, side]), "complete upper ends")


func _separation(root: Node3D, member: String, point: Vector3) -> void:
	if root.get_meta("stadium_item") == "ST-031":
		if member == "RearSaddle":
			_check(point.y >= 5.9999 and point.x >= 2.3999 and point.z >= 6.8999,
				"owned saddle contacts top stair without penetrating seating or crowd")
		else:
			_check(point.z >= 6.9999, "concourse volume lies behind complete frozen lower")
	else:
		_check(point.z >= 6.9999 or point.y >= 7.8999,
			"whole convex upper box above7.9 or entirely behind lower depth7")


func _contact(first: Node3D, second: Node3D) -> bool:
	for shape: CollisionShape3D in second.get_children():
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.margin = 0.003
		query.collision_mask = 1
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 128):
			if hit.collider == first:
				return true
	return false


func _support(lower: Node3D, concourse: Node3D, upper: Node3D) -> void:
	var saddle: Node3D = concourse.get_node("Collision/RearSaddle")
	var deck: Node3D = concourse.get_node("Collision/ConcourseDeck")
	var plinth: MeshInstance3D = concourse.get_node("Visual/GroundedRearPlinth")
	_check(is_zero_approx(plinth.position.y - plinth.mesh.size.y / 2),
		"solid concourse reaches ground")
	_check(_contact(lower.get_node("Collision/EntryStep39"), saddle), "real stair/saddle contact")
	_check(_contact(deck, saddle), "saddle joins actual concourse deck")
	_check(_contact(concourse.get_node("Collision/GroundedRearPlinth"), deck), "deck rests on base")
	for side: int in [-1, 1]:
		var pylon: Node3D = upper.get_node("Collision/RearPylon%d" % side)
		var beam: Node3D = upper.get_node("Collision/Cantilever%d" % side)
		_check(_contact(deck, pylon), "upper support contacts purchased concourse")
		_check(_contact(pylon, beam), "beam meets rear pylon")
		for row in range(4):
			var rib: Node3D = upper.get_node("Collision/DeckRib%d_%d" % [row, side])
			_check(_contact(beam, rib), "cantilever carries each tier rib")
			_check(_contact(rib, upper.get_node("Collision/UpperDeck%d" % row)), "rib meets tier deck")
	for step in range(10):
		var access: Node3D = upper.get_node("Collision/UpperAccess%d" % step)
		_check(_contact(deck, access), "each rear access block rests on purchased concourse")
		if step > 0:
			_check(_contact(upper.get_node("Collision/UpperAccess%d" % (step - 1)), access),
				"access accents form physically connected ascent")
	_check(_contact(upper.get_node("Collision/UpperAccess9"),
		upper.get_node("Collision/UpperDeck3")), "access terminates at rear upper deck")


func _camera_probes() -> void:
	for side: int in [-1, 1]:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(side * 1.2, 1.6, -1), Vector3(0, 1.1, 9), 1)
		_check(get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			"both batting rays clear")
	for eye: Vector3 in [Vector3(-1.2, 1.6, -1), Vector3(1.2, 1.6, -1),
		Vector3(0, 4, 11), Vector3(0, 8, 18)]:
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.3
		query.shape = sphere
		query.transform.origin = eye
		query.collision_mask = 1
		_check(get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
			"actual camera volume clear")


func _no_lower_penetration(addon: Node3D) -> void:
	var lower_bodies: Array[RID] = []
	for lower: Node3D in _straight_lowers:
		for body: StaticBody3D in lower.get_node("Collision").get_children():
			lower_bodies.append(body.get_rid())
	for body: StaticBody3D in addon.get_node("Collision").get_children():
		var shape: CollisionShape3D = body.get_child(0)
		var interior: BoxShape3D = shape.shape.duplicate()
		interior.size -= Vector3.ONE * 0.002
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = interior
		query.transform = shape.global_transform
		query.margin = 0
		query.collision_mask = 1
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 256):
			_check(hit.rid not in lower_bodies,
				"actual purchased collider interior never penetrates any frozen lower collider")
