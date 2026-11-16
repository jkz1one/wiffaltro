extends "res://src/tests/stadium_grand_three_stack_geometry_test_support.gd"
## Isolated structural neighborhood only, not a Grand III venue or runtime admission.

var _grand_bases: Array[Array] = []
var _grand_bowls: Array[Array] = []
var _grand_hosts: Array[Node3D] = []
var _grand_audience: Array[Node3D] = []
var _grand_roofs: Array[Node3D] = []
var _grand_joins: Array[Dictionary] = []
var _grand_circulation: Array[Node3D] = []
var _grand_rays: Array[Dictionary] = []
var _grand_frozen: Array[String] = []


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_grand_lower_controls()
	_grand_empty_controls()
	if not _init_net_witness():
		await _grand_finish()
		return
	var net: Node3D = StadiumReceiverNetModels.create()
	add_child(net)
	_actual_net_clearance(net)
	if not _grand_build_hosts():
		await _grand_finish()
		return
	await _grand_settle()
	if not await _net_visual_controls(net):
		await _grand_finish()
		return
	_grand_record_paths(net)
	await _grand_path_control(net)
	await _sightline_controls(net)
	_setup_view()
	await _capture("GrandIII-compatibility-before-nine-roofs", Vector3(43, 37, 33),
		Vector3(0, 5, -8), 72)
	_grand_freeze()
	if not _grand_install_roofs():
		await _grand_finish()
		return
	_grand_check_frozen()
	await _grand_settle()
	_grand_compare_paths(net)
	_grand_layer_controls(_grand_bases[2], "BASE-R1")
	for hosts: Dictionary in _grand_joins:
		var bowl: Array = _grand_bowls[0 if hosts.right else 4]
		var base: Array = _grand_bases[2 if hosts.right else 0]
		var optional: Array[Node3D] = [bowl[2], bowl[3], base[2], base[3]]
		_grand_neighbor_controls(hosts, optional)
	await _capture("GrandIII-nine-roofs-legal-open-joins", Vector3(43, 37, 33),
		Vector3(0, 5, -8), 72)
	_grand_freeze()
	for index in range(2):
		if not _grand_install_transition(index):
			await _grand_finish()
			return
		await _grand_settle()
		_grand_compare_paths(net)
		var hand: float = 1 if index == 0 else -1
		await _capture("GrandIII-%s-roofless-join" % ("right" if index == 0 else "left"),
			Vector3(hand * 38, 23, 13), Vector3(hand * 23, 6, -4), 29)
	_grand_check_frozen()
	_grand_final_geometry()
	_grand_record_paths(net)
	await _capture("GrandIII-nine-roofs-two-roofless-concourses", Vector3(43, 37, 33),
		Vector3(0, 5, -8), 72)
	var pose: Transform3D = StadiumBaselineSites.pose("BASE-R1")
	await _capture("GrandIII-straight-upper-roof-front-clearance", pose * Vector3(13, 19, -12),
		pose * Vector3(0, 7, 5), 25)
	await _capture("GrandIII-straight-roof-rear-pylon-contact", pose * Vector3(-14, 20, 23),
		pose * Vector3(0, 8, 5.5), 25)
	await _grand_finish()


func _grand_finish() -> void:
	_check(_native._failures == 0, "native resize and actual draw-readback failures propagate")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro Grand III stack compatibility passed: "
			+ "four guard-v2 stacks, nine separate roofs, two roofless joins and1680 clear whole paths.")
	get_tree().quit(0 if _failures == 0 else 1)


func _grand_build_hosts() -> bool:
	for site: String in StadiumBaselineSites.SITES:
		var lower: Node3D = StadiumBaselineSightlineModels.lower()
		_check(lower != null, "construct genuine existing guard-only v2 lower")
		if lower == null:
			return false
		add_child(lower)
		lower.transform = StadiumBaselineSites.pose(site)
		_grand_guard_delta(lower)
		var concourse: Node3D = GM.create_concourse(lower, site)
		_check(concourse != null, "exact guard-v2 site accepts independently purchased concourse")
		if concourse == null:
			return false
		add_child(concourse)
		var upper: Node3D = GM.create_upper(lower, concourse, site)
		_check(upper != null, "actual matching two purchases admit one upper")
		if upper == null:
			return false
		add_child(upper)
		var stack: Array[Node3D] = [lower, concourse, upper]
		_grand_bases.append(stack)
		_grand_hosts.append_array(stack)
		_grand_audience.append_array([lower, upper])
		_grand_same_art(concourse, SM._concourse(), "straight concourse art remains byte-equivalent")
		_grand_same_art(upper, SM._upper(true), "straight upper art remains byte-equivalent")
		_check(GM.create_concourse(lower, site) == null
			and GM.create_upper(lower, concourse, site) == null,
			"same site never grants a duplicate concourse or upper")
	for site: String in StadiumCurvedLowerSites.SITES:
		var lower: Node3D = StadiumCurvedLowerModels.create()
		add_child(lower)
		lower.transform = StadiumCurvedLowerSites.pose(site)
		var concourse: Node3D = StadiumCurvedStackModels.create_concourse(lower, site)
		_check(concourse != null, "existing genuine curved concourse constructs at exact frozen site")
		if concourse == null:
			return false
		add_child(concourse)
		var upper: Node3D = StadiumCurvedStackModels.create_upper(lower, concourse, site)
		_check(upper != null, "existing genuine curved upper constructs on real purchased concourse")
		if upper == null:
			return false
		add_child(upper)
		var stack: Array[Node3D] = [lower, concourse, upper]
		_grand_bowls.append(stack)
		_grand_hosts.append_array(stack)
		_grand_audience.append_array([lower, upper])
	for right: bool in [true, false]:
		var join: Node3D = TM.create_right() if right else TM.create_left()
		add_child(join)
		var bowl: Array = _grand_bowls[0 if right else 4]
		var base: Array = _grand_bases[2 if right else 0]
		_grand_hosts.append(join)
		_grand_audience.append(join)
		_grand_joins.append({"right": right, "root": self,
			"bowl_site": "BOWL-01" if right else "BOWL-05",
			"base_site": "BASE-R1" if right else "BASE-L1",
			"inputs": [join, bowl[0], bowl[1], base[0], base[1]]})
	_check(_count_item("ST-029") == 4 and _count_item("ST-030") == 4 and _count_item("ST-031") == 4
		and _count_item("ST-081") == 5 and _count_item("ST-082") == 5 and _count_item("ST-083") == 5,
		"all four separate straight and all five separate curved stacks coexist at their exact sites")
	return true


func _grand_same_art(actual: Node3D, reference: Node3D, label: String) -> void:
	_check(reference != null, "frozen source art exists for independent comparison")
	if reference == null:
		return
	for branch: String in ["Visual", "Collision"]:
		_check(_grand_snapshot(actual.get_node(branch)) == _grand_snapshot(reference.get_node(branch)),
			label + ": " + branch)
	reference.free()


func _grand_install_roofs() -> bool:
	for index in range(4):
		var stack: Array = _grand_bases[index]
		var site: String = StadiumBaselineSites.SITES[index]
		var roof: Node3D = GM.create_roof(stack[0], stack[1], stack[2], site)
		_check(roof != null, "each exact genuine straight upper admits one separate new upper canopy")
		if roof == null:
			return false
		add_child(roof)
		stack.append(roof)
		_grand_roofs.append(roof)
		_check(GS.valid_roof(stack[0], stack[1], stack[2], roof, site), "installed roof canonical proof")
		_check(GM.create_roof(stack[0], stack[1], stack[2], site) == null, "duplicate upper roof rejects")
		_grand_roof_geometry(roof)
	for index in range(5):
		var stack: Array = _grand_bowls[index]
		var site: String = StadiumCurvedLowerSites.SITES[index]
		var roof: Node3D = StadiumCurvedCanopyModels.create(stack[0], stack[1], stack[2], site)
		_check(roof != null, "all five curved roofs come from the unchanged genuine existing factory")
		if roof == null:
			return false
		add_child(roof)
		stack.append(roof)
		_grand_roofs.append(roof)
		_grand_same_art(roof, GM._curved_roof_reference(),
			"adapter curved-roof witness equals the genuine unchanged factory geometry/material/collision")
	_check(_count_item("ST-053") == 4 and _count_item("ST-084") == 5,
		"exactly nine separately purchased neighboring canopies, no transition roof")
	_check(_count_item("ST-086") == 0 and _count_item("ST-089") == 0,
		"absent roofless transition purchases contain no hidden bridge")
	return true


func _grand_install_transition(index: int) -> bool:
	var hosts: Dictionary = _grand_joins[index]
	var root: Node3D = _grand_transition(hosts)
	_check(root != null, "exact roof-neighbor compatibility admits independently purchased transition")
	if root == null:
		return false
	add_child(root)
	_grand_circulation.append(root)
	_grand_same_art(root, CM._model("JOIN-R" if hosts.right else "JOIN-L"),
		"transition geometry remains unchanged despite explicit compatibility version")
	_concourse_geometry(root)
	_check(root.get_meta("model_version") == 2
		and root.get_meta("model_variant") == "TRANSITION-ROOF-NEIGHBOR-v2"
		and root.get_meta("interface") == GS.TRANSITION_INTERFACE,
		"new transition compatibility is explicitly versioned and separately identified")
	_grand_reject(hosts, "installed same-hand transition consumes exactly its own socket")
	return true


func _grand_record_paths(net: Node3D) -> void:
	_grand_rays.clear()
	var audience: int = 0
	for phase: float in [-PI / 2, 0, PI / 2]:
		for root: Node3D in _grand_audience:
			_animate_host(root, phase)
			_grand_reservation(root)
			var eyes: int = 0
			for anchor: Node3D in root.get_node("Visual").get_children():
				if not anchor.get_meta("represented_audience", false):
					continue
				eyes += 1
				var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
				var target: Vector3 = Vector3(0, 1, 8)
				var hits: Array[RID] = _opaque_path(eye, target, net)
				_grand_rays.append({"eye": eye, "target": target, "blockers": hits})
				_check(hits.is_empty(), "every actual eye clears all opaque bodies across the full ray")
			_check(eyes == root.get_meta("represented_seats"), "all actual audience anchors counted")
			audience += eyes
	for root: Node3D in _grand_audience:
		_animate_host(root, 0)
	_check(audience == 1680 and _grand_rays.size() == 1680,
		"all560 actual audience eyes at rest and both sway extrema, with no filtered seats")
	print("Grand III whole-path audit: 1680 rays; every opaque-hit list must be empty.")


func _grand_compare_paths(net: Node3D) -> void:
	for record: Dictionary in _grand_rays:
		var hits: Array[RID] = _opaque_path(record.eye, record.target, net)
		_check(hits == record.blockers and hits.is_empty(),
			"all1680 full ordered opaque-hit sequences remain clear after each independent addition")


func _grand_path_control(net: Node3D) -> void:
	_check(not _grand_rays.is_empty(), "actual audience ray available for full traversal control")
	if _grand_rays.is_empty():
		return
	var record: Dictionary = _grand_rays[0]
	var root: Node3D = StadiumBaselineStandModels._root("DIAGNOSTIC")
	add_child(root)
	for index in range(2):
		StadiumSeatingModels._box(root, "OpaqueControl%d" % index,
			record.eye.lerp(record.target, 0.35 + index * 0.25), Vector3.ONE * 0.15, Color.RED)
	await _grand_settle()
	var hits: Array[RID] = _opaque_path(record.eye, record.target, net)
	_check(hits.size() == 2, "whole path reports both physical opaque blockers, including farther one")
	for body: StaticBody3D in root.get_node("Collision").get_children():
		_check(body.get_rid() in hits, "both exact real body identities are retained in opacity evidence")
	root.free()
	await _grand_settle()
	_check(_opaque_path(record.eye, record.target, net).is_empty(), "removing controls restores ray")


func _grand_freeze() -> void:
	_grand_frozen.clear()
	for root: Node3D in _grand_hosts + _grand_roofs:
		_grand_frozen.append(_grand_snapshot(root))


func _grand_check_frozen() -> void:
	var roots: Array[Node3D] = _grand_hosts + _grand_roofs
	for index in range(_grand_frozen.size()):
		_check(_grand_frozen[index] == _grand_snapshot(roots[index]),
			"independent additions preserve every prior host node visual material collider and metadata")


func _grand_final_geometry() -> void:
	var all_roots: Array[Node3D] = _grand_hosts + _grand_roofs + _grand_circulation
	for root: Node3D in all_roots:
		_grand_reservation(root)
	for stack: Array in _grand_bases:
		for root: Node3D in [stack[1], stack[2], stack[3]]:
			_grand_boxes(root)
		_grand_straight_support(stack)
	for stack: Array in _grand_bowls:
		_grand_curved_stack_support(stack)
		_grand_curved_roof_support(stack[2], stack[3])
	for index in range(2):
		_concourse_support(_grand_circulation[index], _grand_joins[index])
	for root: Node3D in all_roots:
		_grand_no_penetration(root, all_roots)
	_check(_count_item("ST-085") == 1 and _count_item("ST-088") == 1
		and _count_item("ST-086") == 1 and _count_item("ST-089") == 1,
		"exactly one distinct lower and roofless circulation purchase per transition hand")
	for side: int in [-1, 1]:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(side * 1.2, 1.6, -1), Vector3(0, 1.1, 9), 1)
		_check(get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			"both actual batting pitch corridors remain physically clear")

	for eye: Vector3 in [Vector3(-1.2, 1.6, -1), Vector3(1.2, 1.6, -1),
		Vector3(0, 4, 11), Vector3(0, 8, 18)]:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.3
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform.origin = eye
		query.collision_mask = 1
		_check(get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
			"all four actual near gameplay-camera occupied volumes remain clear")


func _grand_settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
