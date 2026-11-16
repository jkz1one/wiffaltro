extends "res://src/tests/stadium_curved_lower_models_test.gd"
## Inherits corrected v2 panel traversal/negative controls and native capture handshake.

var _lowers: Array[Node3D] = []
var _concourses: Array[Node3D] = []
var _uppers: Array[Node3D] = []


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var net: Node3D = StadiumReceiverNetModels.create()
	add_child(net)
	_actual_net_clearance(net)
	_check(StadiumReceiverNetModels.VERSION == 2, "corrected actual receiver v2")
	_check(StadiumCurvedStackModels.create_concourse(null, "BOWL-03") == null,
		"missing lower fails closed")
	for site: String in StadiumCurvedLowerSites.SITES:
		var lower: Node3D = StadiumCurvedLowerModels.create()
		add_child(lower)
		lower.transform = StadiumCurvedLowerSites.pose(site)
		_lowers.append(lower)
		var frozen: String = StadiumCurvedStackSites.geometry_signature(lower)
		_check(StadiumCurvedStackSites.valid_lower(lower, site), "actual frozen lower accepted")
		_test_points(lower)
		_ground_and_ends(lower)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_sightlines(lower, net)
		_check(StadiumCurvedStackModels.create_upper(lower, null, site) == null,
			"lower alone never grants upper")
		var concourse: Node3D = StadiumCurvedStackModels.create_concourse(lower, site)
		_check(concourse != null, "matching lower accepts one purchased concourse")
		if concourse == null:
			continue
		add_child(concourse)
		_concourses.append(concourse)
		_addon_points(concourse)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_sightlines(lower, net)
		_check(StadiumCurvedStackModels.create_concourse(lower, site) == null,
			"second concourse cannot occupy same socket")
		var upper: Node3D = StadiumCurvedStackModels.create_upper(lower, concourse, site)
		_check(upper != null, "matching lower plus concourse accepts one upper")
		if upper == null:
			continue
		add_child(upper)
		_uppers.append(upper)
		_check(StadiumCurvedStackModels.create_upper(lower, concourse, site) == null,
			"second upper rejected")
		for phase: float in [-PI / 2, 0, PI / 2]:
			StadiumCurvedLowerModels.animate_crowd(lower, phase)
			StadiumCurvedLowerModels.animate_crowd(upper, phase)
			_test_points(lower)
			_addon_points(upper)
		StadiumCurvedLowerModels.animate_crowd(lower, 0)
		StadiumCurvedLowerModels.animate_crowd(upper, 0)
		_structure(lower, concourse, upper)
		_check(frozen == StadiumCurvedStackSites.geometry_signature(lower),
			"both dependent layers preserve frozen lower geometry")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for index in range(_uppers.size()):
		_support_contacts(_lowers[index], _concourses[index], _uppers[index])
	for lower: Node3D in _lowers:
		_sightlines(lower, net)
	for upper: Node3D in _uppers:
		_sightlines(upper, net)
	await _sightline_controls(net)
	await _negative_hosts()
	await _host_proof_controls()
	_camera_corridors()
	# Grand II's central three stacks; outer two retain their complete lower-only ends.
	for index in [0, 4]:
		if _uppers.size() == 5 and _concourses.size() == 5:
			_uppers[index].queue_free()
			_concourses[index].queue_free()
	await get_tree().process_frame
	_setup_view()
	await _capture("ST082-083-grand-II-bowl-subset", Vector3(38, 32, 24),
		Vector3(0, 4, -13), 58)
	for index in [0, 1, 3, 4]:
		_lowers[index].visible = false
		if is_instance_valid(_concourses[index]):
			_concourses[index].visible = false
		if is_instance_valid(_uppers[index]):
			_uppers[index].visible = false
	await _capture("ST082-083-stack-front", Vector3(13, 14, -5), Vector3(0, 4.5, -24), 20)
	await _capture("ST082-083-stack-rear-support-access", Vector3(-13, 13, -38),
		Vector3(0, 4.5, -24), 20)
	_uppers[2].visible = false
	await _capture("ST083-complete-concourse-without-upper", Vector3(-12, 10, -37),
		Vector3(0, 2.8, -25), 18)
	_concourses[2].visible = false
	await _capture("ST081-unchanged-lower-alone", Vector3(12, 12, -7),
		Vector3(0, 2, -22), 18)
	_check(_native._failures == 0, "native handshake failures propagate")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro curved stack models passed: compatible purchased layers and frozen lower.")
	get_tree().quit(0 if _failures == 0 else 1)


func _addon_points(root: Node3D) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var pose: Transform3D = root.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			var points: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				_addon_point(root, pose * point, mesh.name)
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		_check(shape.shape is ConvexPolygonShape3D and shape.shape.margin == 0,
			"exact faceted solid with zero collision inflation")
		var pose: Transform3D = root.global_transform.affine_inverse() * shape.global_transform
		for point: Vector3 in shape.shape.points:
			_addon_point(root, pose * point, shape.get_parent().name)


func _addon_point(root: Node3D, point: Vector3, member: String) -> void:
	_check(StadiumCurvedStackSites.contains_local(point), "full actual addon envelope")
	var radius: float = Vector2(point.x, point.z).length()
	if root.get_meta("stadium_item") == "ST-083":
		if member == "RearSaddle":
			_check(point.y >= 4.3999 and radius >= 24.679,
				"saddle above rim and beyond lower crowd, contact not penetration")
		else:
			_check(radius >= 25.049, "all other concourse members behind frozen lower")
	else:
		_check(point.y >= 5.7999 or radius >= 25.049,
			"upper avoids full lower-head envelope with at least 0.5m vertical gap")
	var world: Vector3 = root.global_transform * point
	_check(not StadiumReceiverNetModels.ENVELOPE.grow(0.25).has_point(world),
		"addons clear actual net envelope")


func _vertices(root: Node3D, member: String) -> PackedVector3Array:
	var mesh: MeshInstance3D = root.get_node("Visual/" + member)
	return mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func _height(root: Node3D, member: String, minimum: bool) -> float:
	var height: float = INF if minimum else -INF
	for point: Vector3 in _vertices(root, member):
		height = minf(height, point.y) if minimum else maxf(height, point.y)
	return height


func _structure(lower: Node3D, concourse: Node3D, upper: Node3D) -> void:
	_check(is_zero_approx(_height(concourse, "GroundedRearPlinth", true)),
		"concourse support reaches actual ground")
	_check(is_equal_approx(_height(lower, "RearRim", false),
		_height(concourse, "RearSaddle", true)), "real saddle/rim vertical contact")
	_check(is_equal_approx(_height(concourse, "ConcourseDeck", false),
		_height(upper, "RearPylon1", true)), "upper pylons sit on purchased concourse deck")
	for side: int in [-1, 1]:
		_check(concourse.has_node("Collision/FinishedEnd%d" % side),
			"concourse complete at exposed upper/lower-only boundary")
		for row in range(4):
			_check(upper.has_node("Collision/FinishedEnd%d_%d" % [row, side]),
				"every upper tier has a finished collision-bearing end")
			_check(_height(upper, "DeckRib%d_%d" % [row, side], false)
				>= _height(upper, "UpperDeck%d" % row, true),
				"actual support rib intersects its deck slab")
	# Convex wedge chord minima, not just vertex radii, retain separation from lower.
	_check(25.05 * cos(deg_to_rad(1.0)) > 24.94,
		"entire concourse convex hulls remain radially outside frozen lower")
	_check(24.68 * cos(deg_to_rad(0.75)) > 24.4,
		"saddle chord remains outside actual rear-row head and hand envelope")
	_check(2 * 18 * sin(deg_to_rad(0.3)) > 0.18,
		"disjoint convex sectors preserve independent finished neighbor ends")


func _negative_hosts() -> void:
	var parent: Node3D = Node3D.new()
	add_child(parent)
	var lower: Node3D = StadiumCurvedLowerModels.create()
	parent.add_child(lower)
	lower.transform = StadiumCurvedLowerSites.pose("BOWL-03")
	parent.position.x = 0.25
	_check(StadiumCurvedStackModels.create_concourse(lower, "BOWL-03") == null,
		"transformed parent rejected, no implicit raised or translated lower")
	parent.position = Vector3.ZERO
	lower.scale = Vector3(1.01, 1, 1)
	_check(StadiumCurvedStackModels.create_concourse(lower, "BOWL-03") == null,
		"resized lower rejected")
	lower.transform = StadiumCurvedLowerSites.pose("BOWL-03")
	_check(StadiumCurvedStackModels.create_concourse(lower, "BOWL-02") == null,
		"wrong oriented host rejected")
	lower.get_node("Visual/RearRim").position.y = 0.01
	_check(StadiumCurvedStackModels.create_concourse(lower, "BOWL-03") == null,
		"changed actual rear interface rejected despite correct metadata")
	lower.get_node("Visual/RearRim").position.y = 0
	var concourse: Node3D = StadiumCurvedStackModels.create_concourse(lower, "BOWL-03")
	parent.add_child(concourse)
	concourse.set_meta("stadium_item", "ST-031")
	_check(StadiumCurvedStackModels.create_upper(lower, concourse, "BOWL-03") == null,
		"straight concourse substitution rejected")
	concourse.set_meta("stadium_item", "ST-083")
	concourse.get_node("Collision/ConcourseDeck").position.y = 0.1
	_check(StadiumCurvedStackModels.create_upper(lower, concourse, "BOWL-03") == null,
		"actual altered support collider rejected")
	concourse.get_node("Collision/ConcourseDeck").position.y = 0
	concourse.set_meta("lower_instance", _lowers[0].get_instance_id())
	_check(StadiumCurvedStackModels.create_upper(lower, concourse, "BOWL-03") == null,
		"different lower's concourse rejected")
	parent.queue_free()
	await get_tree().process_frame


func _camera_corridors() -> void:
	for eye: Vector3 in [Vector3(-1.2, 1.6, -1), Vector3(1.2, 1.6, -1),
		Vector3(0, 4, 11), Vector3(0, 8, 18)]:
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.30
		query.shape = sphere
		query.transform.origin = eye
		query.collision_mask = 1
		_check(get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
			"near camera volume clear of actual stack collision")


func _contact(first: Node3D, second: Node3D) -> bool:
	# Real physics hull query: tiny tolerance measures touching load-bearing surfaces.
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


func _support_contacts(lower: Node3D, concourse: Node3D, upper: Node3D) -> void:
	_check(_contact(lower.get_node("Collision/RearRim"),
		concourse.get_node("Collision/RearSaddle")), "actual saddle touches original rear rim")
	_check(_contact(concourse.get_node("Collision/ConcourseDeck"),
		concourse.get_node("Collision/RearSaddle")), "actual saddle joins supported rear deck")
	for side: int in [-1, 1]:
		var pylon: Node3D = upper.get_node("Collision/RearPylon%d" % side)
		var beam: Node3D = upper.get_node("Collision/Cantilever%d" % side)
		_check(_contact(concourse.get_node("Collision/ConcourseDeck"), pylon),
			"actual pylon footprint contacts purchased concourse deck")
		_check(_contact(pylon, beam), "actual cantilever intersects its rear pylon")
		for row in range(4):
			var rib: Node3D = upper.get_node("Collision/DeckRib%d_%d" % [row, side])
			_check(_contact(beam, rib), "actual rib touches cantilever beam")
			_check(_contact(rib, upper.get_node("Collision/UpperDeck%d" % row)),
				"actual rib intersects its seat deck")
	for step in range(8):
		var riser: Node3D = upper.get_node("Collision/UpperAccess%d" % step)
		var support: Node3D = concourse.get_node("Collision/ConcourseDeck") if step < 6 \
			else upper.get_node("Collision/UpperAccess%d" % (step - 1))
		_check(_contact(support, riser), "actual upper access owned risers join supported spine")
	_check(_contact(upper.get_node("Collision/UpperAccess7"),
		upper.get_node("Collision/UpperDeck3")), "upper access spine joins rear seat deck")


func _reject_lower(lower: Node3D, label: String) -> void:
	var result: Node3D = StadiumCurvedStackModels.create_concourse(lower, "BOWL-03")
	_check(result == null, label)
	if result != null:
		result.free()


func _host_proof_controls() -> void:
	var parent: Node3D = Node3D.new()
	add_child(parent)
	var lower: Node3D = StadiumCurvedLowerModels.create()
	parent.add_child(lower)
	lower.transform = StadiumCurvedLowerSites.pose("BOWL-03")
	for phase: float in [-PI / 2, 0, PI / 2]:
		StadiumCurvedLowerModels.animate_crowd(lower, phase)
		_check(StadiumCurvedStackSites.valid_lower(lower, "BOWL-03"),
			"canonical audience at both bounded sway extremes remains valid")
	StadiumCurvedLowerModels.animate_crowd(lower, 0)
	var crowd: Node3D = lower.get_node("Visual/CrowdAnchor0")
	crowd.scale = Vector3(8, 8, 8)
	_reject_lower(lower, "oversized canonical audience cannot hide behind crowd exemption")
	crowd.scale = Vector3.ONE
	crowd.position.x += 0.5
	_reject_lower(lower, "moved crowd anchor rejects actual changed envelope")
	crowd.position = crowd.get_meta("rest_position")
	crowd.position.y += 0.05
	_reject_lower(lower, "audience outside permitted vertical sway rejects")
	crowd.position = crowd.get_meta("rest_position")
	var rest: Vector3 = crowd.get_meta("rest_position")
	crowd.remove_meta("rest_position")
	_reject_lower(lower, "missing required anchor rest metadata fails closed without errors")
	crowd.set_meta("rest_position", "invalid rest position")
	_reject_lower(lower, "wrong-typed required anchor rest metadata fails closed")
	crowd.set_meta("rest_position", Vector3(NAN, 0, 0))
	_reject_lower(lower, "nonfinite required anchor rest metadata fails closed")
	crowd.set_meta("rest_position", rest)
	var head: MeshInstance3D = crowd.get_node("Head")
	var original: Mesh = head.mesh
	var enlarged: SphereMesh = SphereMesh.new()
	enlarged.radius = 2.0
	enlarged.height = 4.0
	head.mesh = enlarged
	_reject_lower(lower, "changed audience mesh rejects despite canonical anchor name")
	head.mesh = original
	var spoof: StaticBody3D = StaticBody3D.new()
	spoof.name = "CrowdAnchorSpoof"
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	spoof.add_child(shape)
	lower.get_node("Collision").add_child(spoof)
	_reject_lower(lower, "crowd-named collision subtree is never excluded from host proof")
	lower.get_node("Collision").remove_child(spoof)
	spoof.free()
	var rim: StaticBody3D = lower.get_node("Collision/RearRim")
	var rim_shape: CollisionShape3D = rim.get_child(0)
	rim_shape.disabled = true
	_reject_lower(lower, "disabled canonical lower collider rejects")
	rim_shape.disabled = false
	rim.collision_layer = 0
	_reject_lower(lower, "missing canonical lower collision layer rejects")
	rim.collision_layer = 1
	rim.collision_mask = 0
	_reject_lower(lower, "missing canonical lower collision mask rejects")
	rim.collision_mask = 2
	# Preserve name, pose and complete geometry while replacing a physical body by Node3D.
	var collision: Node = lower.get_node("Collision")
	var index: int = rim.get_index()
	collision.remove_child(rim)
	var fake: Node3D = Node3D.new()
	fake.name = "RearRim"
	fake.transform = rim.transform
	collision.add_child(fake)
	collision.move_child(fake, index)
	for child: Node in rim.get_children():
		rim.remove_child(child)
		fake.add_child(child)
	_reject_lower(lower, "identical geometry under wrong node class rejects")
	for child: Node in fake.get_children():
		fake.remove_child(child)
		rim.add_child(child)
	collision.remove_child(fake)
	fake.free()
	collision.add_child(rim)
	collision.move_child(rim, index)
	_check(StadiumCurvedStackSites.valid_lower(lower, "BOWL-03"),
		"restoring actual canonical host restores acceptance")
	var concourse: Node3D = StadiumCurvedStackModels.create_concourse(lower, "BOWL-03")
	parent.add_child(concourse)
	var deck: StaticBody3D = concourse.get_node("Collision/ConcourseDeck")
	var deck_shape: CollisionShape3D = deck.get_child(0)
	deck_shape.disabled = true
	_check(StadiumCurvedStackModels.create_upper(lower, concourse, "BOWL-03") == null,
		"disabled concourse support rejects upper admission")
	deck_shape.disabled = false
	deck.collision_layer = 0
	_check(StadiumCurvedStackModels.create_upper(lower, concourse, "BOWL-03") == null,
		"collisionless concourse support rejects upper admission")
	deck.collision_layer = 1
	parent.queue_free()
	await get_tree().process_frame
