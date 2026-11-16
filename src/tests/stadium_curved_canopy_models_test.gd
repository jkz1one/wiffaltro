extends "res://src/tests/stadium_curved_stack_models_test.gd"
## Isolated additive roof study; native handshake inherited without engine shortcuts.

var _roofs: Array[Node3D] = []
var _net_witness: Node3D


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_net_witness = StadiumReceiverNetModels.create()
	for id: String in StadiumReceiverNetModels.PANELS:
		var panel: MeshInstance3D = _net_witness.get_node("Visual/" + id)
		_check(StadiumReceiverNetModels.flex(_net_witness, id, 0.275,
			panel.transform * Vector3(0, 3.375, 0)), "canonical exact peak-flex witness")
	var net: Node3D = StadiumReceiverNetModels.create()
	add_child(net)
	_actual_net_clearance(net)
	_check(StadiumCurvedCanopyModels.create(null, null, null, "BOWL-03") == null,
		"missing complete curved stack rejects roof")
	for site: String in StadiumCurvedLowerSites.SITES:
		var lower: Node3D = StadiumCurvedLowerModels.create()
		add_child(lower)
		lower.transform = StadiumCurvedLowerSites.pose(site)
		_lowers.append(lower)
		var concourse: Node3D = StadiumCurvedStackModels.create_concourse(lower, site)
		if concourse == null:
			await _abort_construction("canonical concourse construction failed")
			return
		add_child(concourse)
		_concourses.append(concourse)
		var upper: Node3D = StadiumCurvedStackModels.create_upper(lower, concourse, site)
		if upper == null:
			await _abort_construction("canonical upper construction failed")
			return
		add_child(upper)
		_uppers.append(upper)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_sightlines(lower, net)
		_sightlines(upper, net)
		var before: Array[String] = []
		for host: Node3D in [lower, concourse, upper]:
			before.append(StadiumCurvedCanopySites.signature(host))
		var roof: Node3D = StadiumCurvedCanopyModels.create(lower, concourse, upper, site)
		_check(roof != null, "all five authentic rigid bowl stacks accept one upper canopy")
		if roof == null:
			await _abort_construction("canonical roof construction failed")
			return
		add_child(roof)
		_roofs.append(roof)
		_check(StadiumCurvedCanopyModels.create(lower, concourse, upper, site) == null,
			"duplicate roof cannot create an additional paid copy")
		_roof_points(roof)
		for index in range(3):
			var host: Node3D = [lower, concourse, upper][index]
			_check(before[index] == StadiumCurvedCanopySites.signature(host),
				"adding canopy leaves actual lower/concourse/upper bytes and state unchanged")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for index in range(_roofs.size()):
		_roof_contacts(_uppers[index], _roofs[index])
		_support_contacts(_lowers[index], _concourses[index], _uppers[index])
	for phase: float in [-PI / 2, 0, PI / 2]:
		for lower: Node3D in _lowers:
			StadiumCurvedLowerModels.animate_crowd(lower, phase)
			_test_points(lower)
			_sightlines(lower, net)
		for upper: Node3D in _uppers:
			StadiumCurvedLowerModels.animate_crowd(upper, phase)
			_addon_points(upper)
			_sightlines(upper, net)
	for host: Node3D in _lowers + _uppers:
		StadiumCurvedLowerModels.animate_crowd(host, 0)
	await _sightline_controls(net)
	_net_visual_controls(net)
	await _canopy_host_controls()
	await _host_proof_controls()
	_camera_corridors()
	_setup_view()
	await _capture("ST084-five-independent-upper-roofs", Vector3(38, 35, 25),
		Vector3(0, 5, -13), 60)
	for index in [0, 1, 3, 4]:
		for piece: Node3D in [_lowers[index], _concourses[index],
			_uppers[index], _roofs[index]]:
			piece.visible = false
	await _capture("ST084-standalone-front-finished-ends", Vector3(13, 16, -4),
		Vector3(0, 5.5, -24), 22)
	await _capture("ST084-rear-post-contact", Vector3(-13, 15, -38),
		Vector3(0, 6, -24), 22)
	_roofs[2].visible = false
	await _capture("ST084-unchanged-stack-control", Vector3(-13, 15, -38),
		Vector3(0, 5, -24), 22)
	_check(_native._failures == 0, "native resize and capture failures propagate")
	_net_witness.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro curved canopy models passed: supported separate roof and frozen stack.")
	get_tree().quit(0 if _failures == 0 else 1)


func _abort_construction(label: String) -> void:
	_check(false, label)
	_net_witness.free()
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(1)


func _roof_points(roof: Node3D) -> void:
	for mesh: MeshInstance3D in roof.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = roof.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				_roof_point(local * point)
	for shape: CollisionShape3D in roof.find_children("*", "CollisionShape3D", true, false):
		_check(shape.shape is ConvexPolygonShape3D and shape.shape.margin == 0,
			"roof actual convex wedges match zero-margin authored envelope")
		var local: Transform3D = roof.global_transform.affine_inverse() * shape.global_transform
		for point: Vector3 in shape.shape.points:
			_roof_point(local * point)


func _roof_point(point: Vector3) -> void:
	_check(StadiumCurvedCanopySites.contains_local(point), "actual roof in Mogul reservation")
	_check(point.y >= 9.7999 or Vector2(point.x, point.z).length() >= 25.199,
		"all roof members over audience have at least0.50m reserved-head clearance")


func _roof_contacts(upper: Node3D, roof: Node3D) -> void:
	for side: int in [-1, 1]:
		var post: Node3D = roof.get_node("Collision/RoofPost%d" % side)
		var beam: Node3D = roof.get_node("Collision/RoofBeam%d" % side)
		_check(_contact(upper.get_node("Collision/RearPylon%d" % side), post),
			"real roof post hull contacts exact purchased upper pylon top")
		_check(is_equal_approx(_height(upper, "RearPylon%d" % side, false),
			_height(roof, "RoofPost%d" % side, true)), "mesh post contact without penetration")
		_check(_contact(post, beam), "real beam intersects supported roof post")
		_check(_contact(beam, roof.get_node("Collision/RoofSlab")),
			"real full canopy slab contacts its two support beams")
		_check(_contact(roof.get_node("Collision/FinishedRoofEnd%d" % side),
			roof.get_node("Collision/RoofSlab")), "finished exposed ends belong to supported roof")
	for id: String in ["FrontRoofFascia", "RearRoofFascia"]:
		_check(_contact(roof.get_node("Collision/" + id), roof.get_node("Collision/RoofSlab")),
			"finished fascias join slab")
	_check(25.20 * cos(deg_to_rad(0.55)) > 24.65,
		"whole post hulls stay behind upper deck/parapet and occupied crowd")


func _verified_panel(hit: Dictionary, net: Node3D) -> bool:
	if not super._verified_panel(hit, net):
		return false
	var body: StaticBody3D = hit.collider
	var id: String = body.get_meta("surface_id")
	var reference: StaticBody3D = _net_witness.get_node("Collision/" + id)
	var shape: CollisionShape3D = body.get_child(0)
	var ref_shape: CollisionShape3D = reference.get_child(0)
	if body.transform != reference.transform or shape.transform != ref_shape.transform \
		or shape.shape.size != ref_shape.shape.size or shape.disabled \
		or shape.shape.margin != 0 or body.collision_layer != reference.collision_layer \
		or body.get_script() != null or shape.get_script() != null:
		return false
	return _strand_visual(net.get_node("Visual/" + id),
		_net_witness.get_node("Visual/" + id))


func _strand_visual(actual: MeshInstance3D, reference: MeshInstance3D) -> bool:
	# Actual canonical strand triangles, not panel-width/rest-vertex metadata, prove holes.
	if not actual.mesh is ArrayMesh or actual.mesh.get_surface_count() != 1 \
		or actual.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES \
		or not actual.is_visible_in_tree() or actual.visible != reference.visible \
		or actual.transform != reference.transform or actual.get_child_count() != 0 \
		or actual.get_script() != null or actual.material_overlay != null \
		or actual.get_surface_override_material(0) != null \
		or actual.mesh.surface_get_material(0) != null \
		or StadiumCurvedCanopySites._resource(actual.material_override) \
			!= StadiumCurvedCanopySites._resource(reference.material_override):
		return false
	var actual_state: HashingContext = HashingContext.new()
	var reference_state: HashingContext = HashingContext.new()
	actual_state.start(HashingContext.HASH_SHA256)
	reference_state.start(HashingContext.HASH_SHA256)
	StadiumCurvedCanopySites._state(actual, actual_state)
	StadiumCurvedCanopySites._state(reference, reference_state)
	if actual_state.finish() != reference_state.finish():
		return false
	var arrays: Array = actual.mesh.surface_get_arrays(0)
	var expected: Array = reference.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if arrays != expected or not actual.has_meta("rest_vertices") \
		or actual.get_meta("rest_vertices") != reference.get_meta("rest_vertices"):
		return false
	if points.size() % 3 != 0:
		return false
	var projected_area: float = 0
	for index in range(points.size()):
		var p: Vector3 = points[index]
		if not p.is_finite():
			return false
		if index % 3 == 0:
			var a: Vector2 = Vector2(points[index].x, points[index].y)
			var b: Vector2 = Vector2(points[index + 1].x, points[index + 1].y)
			var c: Vector2 = Vector2(points[index + 2].x, points[index + 2].y)
			projected_area += absf((b - a).cross(c - a)) * 0.5
	var extent: AABB = reference.mesh.get_aabb()
	return projected_area < extent.size.x * extent.size.y * 0.15


func _net_visual_controls(net: Node3D) -> void:
	var panel: MeshInstance3D = net.get_node("Visual/ST073_CENTER_NET")
	var original: Mesh = panel.mesh
	panel.visible = false
	_check(not _sightline_clear(Vector3(0, 3, -6), Vector3(0, 3, 0), net),
		"hidden strand panel cannot serve as authentic visible net witness")
	panel.visible = true
	panel.transparency = 0.5
	_check(not _sightline_clear(Vector3(0, 3, -6), Vector3(0, 3, 0), net),
		"changed panel instance render state rejects witness")
	panel.transparency = 0
	var filled: QuadMesh = QuadMesh.new()
	filled.size = Vector2(4, 6.25)
	panel.mesh = filled
	_check(not _sightline_clear(Vector3(0, 3, -6), Vector3(0, 3, 0), net),
		"filled opaque visual rejects despite authentic thin body and spoofable metadata")
	var wrong_topology: ArrayMesh = ArrayMesh.new()
	wrong_topology.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP,
		original.surface_get_arrays(0))
	panel.mesh = wrong_topology
	_check(not _sightline_clear(Vector3(0, 3, -6), Vector3(0, 3, 0), net),
		"same strand arrays with hole-bridging triangle-strip primitive reject")
	panel.mesh = original
	var material: StandardMaterial3D = panel.material_override
	material.next_pass = StandardMaterial3D.new()
	_check(not _sightline_clear(Vector3(0, 3, -6), Vector3(0, 3, 0), net),
		"changed actual material pass rejects transparency witness")
	material.next_pass = null
	_check(_sightline_clear(Vector3(0, 3, -6), Vector3(0, 3, 0), net),
		"restored genuine sparse strand visual restores full traversal")


func _reject_roof(lower: Node3D, concourse: Node3D, upper: Node3D, label: String) -> void:
	var result: Node3D = StadiumCurvedCanopyModels.create(lower, concourse, upper, "BOWL-03")
	_check(result == null, label)
	if result != null:
		result.free()


func _canopy_host_controls() -> void:
	var parent: Node3D = Node3D.new()
	add_child(parent)
	var lower: Node3D = StadiumCurvedLowerModels.create()
	parent.add_child(lower)
	lower.transform = StadiumCurvedLowerSites.pose("BOWL-03")
	var concourse: Node3D = StadiumCurvedStackModels.create_concourse(lower, "BOWL-03")
	parent.add_child(concourse)
	var upper: Node3D = StadiumCurvedStackModels.create_upper(lower, concourse, "BOWL-03")
	parent.add_child(upper)
	for site: String in ["BOWL-06", "JOIN-L", "JOIN-R", "BASE-L1"]:
		_check(StadiumCurvedCanopyModels.create(lower, concourse, upper, site) == null,
			"unsupported site and transition never gain canopy socket")
	upper.scale = Vector3(1.01, 1, 1)
	_reject_roof(lower, concourse, upper, "scaled upper cannot fit by stretching")
	upper.transform = StadiumCurvedLowerSites.pose("BOWL-03")
	_reject_roof(lower, concourse, null, "lower roof is explicitly unavailable")
	_reject_roof(lower, null, upper, "missing matching concourse rejects")
	_reject_roof(lower, _concourses[2], upper, "different assembly's concourse rejects")
	for phase: float in [-PI / 2, 0, PI / 2]:
		for host: Node3D in [lower, upper]:
			StadiumCurvedLowerModels.animate_crowd(host, phase)
		_check(StadiumCurvedCanopySites.valid_hosts(lower, concourse, upper, "BOWL-03"),
			"actual canonical occupied hosts accept both bounded crowd sway extremes")
	for host: Node3D in [lower, upper]:
		StadiumCurvedLowerModels.animate_crowd(host, 0)
	for host: Node3D in [lower, concourse, upper]:
		var mesh: MeshInstance3D = host.get_node("Visual").get_child(0)
		var material: StandardMaterial3D = mesh.material_override
		var color: Color = material.albedo_color
		var script: GDScript = GDScript.new()
		script.source_code = "extends Node3D\n"
		_check(script.reload() == OK, "negative-control script compiles")
		host.set_script(script)
		_reject_roof(lower, concourse, upper, "unexpected executable host script rejects")
		host.set_script(null)
		material.albedo_color = Color.MAGENTA
		_reject_roof(lower, concourse, upper, "changed actual host material rejects")
		material.albedo_color = color
		var shape: CollisionShape3D = host.get_node("Collision").get_child(0).get_child(0)
		shape.disabled = true
		_reject_roof(lower, concourse, upper, "disabled host physical support rejects")
		shape.disabled = false
		var points: PackedVector3Array = shape.shape.points
		var changed: PackedVector3Array = points.duplicate()
		changed[0].y += 0.25
		shape.shape.points = changed
		_reject_roof(lower, concourse, upper, "changed actual support hull rejects")
		shape.shape.points = points
		var original_pose: Transform3D = mesh.transform
		mesh.position.y += 0.02
		_reject_roof(lower, concourse, upper, "altered actual host mesh pose rejects")
		mesh.transform = original_pose
		_check(mesh.transform == original_pose, "negative-control mesh pose restored exactly")
		var spoof: Node3D = Node3D.new()
		spoof.name = "CrowdAnchorExtra"
		host.get_node("Visual").add_child(spoof)
		_reject_roof(lower, concourse, upper, "no broad crowd-named branch exclusions")
		host.get_node("Visual").remove_child(spoof)
		spoof.free()
		_check(StadiumCurvedCanopySites.canonical(host, host.get_meta("stadium_item")),
			"each mutated host returns to exact canonical state before next controls")
	var crowd: Node3D = upper.get_node("Visual/CrowdAnchor0")
	crowd.position.y += 0.05
	_reject_roof(lower, concourse, upper, "upper crowd beyond actual sway rejects")
	crowd.position = crowd.get_meta("rest_position")
	upper.set_meta("stadium_item", "ST-030")
	_reject_roof(lower, concourse, upper, "straight upper never substitutes")
	upper.set_meta("stadium_item", "ST-082")
	upper.transform = StadiumCurvedLowerSites.pose("BOWL-02")
	_reject_roof(lower, concourse, upper, "wrong upper site orientation rejects")
	upper.transform = StadiumCurvedLowerSites.pose("BOWL-03")
	parent.position.y = 0.1
	_reject_roof(lower, concourse, upper, "transformed host parent rejects")
	parent.position.y = 0
	for item: String in ["ST-084", "ST-053", "ST-055", "ST-057", "ST-082"]:
		var conflict: Node3D = Node3D.new()
		conflict.set_meta("stadium_item", item)
		conflict.set_meta("site", "BOWL-03")
		parent.add_child(conflict)
		_reject_roof(lower, concourse, upper, "roof/service/duplicate layer conflict rejects")
		parent.remove_child(conflict)
		conflict.free()
	_check(StadiumCurvedCanopySites.valid_hosts(lower, concourse, upper, "BOWL-03"),
		"restoring canonical hosts restores admission")
	parent.queue_free()
	await get_tree().process_frame
	var empty_parent: Node3D = Node3D.new()
	add_child(empty_parent)
	var empty_lower: Node3D = StadiumCurvedLowerModels.create(false)
	empty_parent.add_child(empty_lower)
	empty_lower.transform = StadiumCurvedLowerSites.pose("BOWL-03")
	var empty_concourse: Node3D = StadiumCurvedStackModels.create_concourse(
		empty_lower, "BOWL-03")
	empty_parent.add_child(empty_concourse)
	var empty_upper: Node3D = StadiumCurvedStackModels.create_upper(
		empty_lower, empty_concourse, "BOWL-03", false)
	empty_parent.add_child(empty_upper)
	_check(StadiumCurvedCanopySites.valid_hosts(
		empty_lower, empty_concourse, empty_upper, "BOWL-03"),
		"canonical unoccupied hosts also admit upper roof")
	empty_parent.queue_free()
	await get_tree().process_frame
