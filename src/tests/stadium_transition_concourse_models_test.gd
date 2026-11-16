extends "res://src/tests/stadium_transition_concourse_net_test_support.gd"
## Whole-scene before/after qualification of separately purchased ST086 and ST089.

var _bowl_lowers: Array[Node3D] = []
var _bowl_concourses: Array[Node3D] = []
var _base_lowers: Array[Node3D] = []
var _base_concourses: Array[Node3D] = []
var _all_hosts: Array[Node3D] = []
var _audience_roots: Array[Node3D] = []
var _installed_concourses: Array[Node3D] = []
var _hand_hosts: Array[Dictionary] = []
var _full_rays: Array[Dictionary] = []
var _frozen_hosts: Array[String] = []


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var witness_ready: bool = _init_net_witness()
	_check(witness_ready, "qualified strict receiver witness is available")
	if not witness_ready:
		await _finish_concourse_test()
		return
	var net: Node3D = StadiumReceiverNetModels.create()
	_check(net != null, "actual receiver fixture is constructed")
	if net == null:
		await _finish_concourse_test()
		return
	add_child(net)
	_check(StadiumReceiverNetModels.VERSION == 2, "qualified actual receiver model v2")
	_actual_net_clearance(net)
	if not await _negative_concourse_hosts():
		await _finish_concourse_test()
		return
	if not _build_full_hosts():
		await _finish_concourse_test()
		return
	await _run_concourse_proof(net)
	await _finish_concourse_test()


func _run_concourse_proof(net: Node3D) -> void:
	_freeze_hosts()
	await _settle_physics()
	if not await _net_visual_controls(net):
		return
	_record_every_eye(net, false)
	await _baseline_path_control(net)
	await _sightline_controls(net)
	_setup_view()
	await _capture("ST086-089-absent-complete-purchased-hosts", Vector3(42, 34, 28),
		Vector3(0, 4, -8), 66)
	var right: Node3D = _install_concourse(0)
	if right == null:
		return
	await _settle_physics()
	_compare_every_eye(net)
	await _capture("ST086-right-only-supported-interfaces", Vector3(34, 17, 7),
		Vector3(23, 4, -4), 21)
	remove_child(right)
	await _settle_physics()
	if _install_concourse(1) == null:
		return
	await _settle_physics()
	_compare_every_eye(net)
	await _capture("ST089-left-only-supported-interfaces", Vector3(-34, 17, 7),
		Vector3(-23, 4, -4), 21)
	add_child(right)
	await _settle_physics()
	_compare_every_eye(net)
	_audit_installed(false)
	_check_frozen_hosts()
	_check(_count_item("ST-085") == 1 and _count_item("ST-088") == 1
		and _count_item("ST-086") == 1 and _count_item("ST-089") == 1,
		"each hand is one separately identified actual lower and one purchased circulation model")
	await _capture("ST086-089-both-concourses-no-uppers", Vector3(42, 34, 28),
		Vector3(0, 4, -8), 66)
	for side: int in [-1, 1]:
		await _capture("ST086-089-%s-cap-crossing-detail" % ("right" if side == 1 else "left"),
			Vector3(side * 33, 14, -14), Vector3(side * 25, 5.6, -4), 15)
	# Rebuild real transition purchases only after optional host uppers exist. This
	# checks admission as well as actual geometry; reattaching stale objects is insufficient.
	for root: Node3D in _installed_concourses:
		if root.get_parent() == self:
			remove_child(root)
		root.free()
	_installed_concourses.clear()
	if not _add_optional_uppers():
		return
	if not _optional_upper_controls():
		return
	_freeze_hosts()
	await _settle_physics()
	_record_every_eye(net, true)
	for index in range(2):
		if _install_concourse(index) == null:
			return
		await _settle_physics()
		_compare_every_eye(net)
	_audit_installed(true)
	_check_frozen_hosts()
	_camera_corridors()
	await _capture("ST086-089-both-with-independent-neighbor-uppers", Vector3(43, 36, 32),
		Vector3(0, 5, -8), 69)


func _finish_concourse_test() -> void:
	# Detached purchases can exist in an interrupted right-only/left-only proof.
	for root: Node3D in _installed_concourses:
		if is_instance_valid(root) and root.get_parent() == null:
			root.free()
	_check(_native._failures == 0, "native resize and draw-readback handshake failures propagate")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro transition concourse models passed: "
			+ "two purchases, exact five-host proof, complete opaque paths and supported cap crossings.")
	get_tree().quit(0 if _failures == 0 else 1)


func _build_full_hosts() -> bool:
	for site: String in StadiumCurvedLowerSites.SITES:
		var lower: Node3D = StadiumCurvedLowerModels.create()
		_check(lower != null, "construct full actual bowl lower")
		if lower == null:
			return false
		add_child(lower)
		lower.transform = StadiumCurvedLowerSites.pose(site)
		_bowl_lowers.append(lower)
		_all_hosts.append(lower)
		_audience_roots.append(lower)
		var concourse: Node3D = StadiumCurvedStackModels.create_concourse(lower, site)
		_check(concourse != null, "each full actual bowl lower accepts its own separate concourse")
		if concourse == null:
			return false
		add_child(concourse)
		_bowl_concourses.append(concourse)
		_all_hosts.append(concourse)
	for site: String in StadiumBaselineSites.SITES:
		var lower: Node3D = StadiumBaselineStandModels.lower()
		_check(lower != null, "construct full actual baseline lower")
		if lower == null:
			return false
		add_child(lower)
		lower.transform = StadiumBaselineSites.pose(site)
		_base_lowers.append(lower)
		_all_hosts.append(lower)
		_audience_roots.append(lower)
		var concourse: Node3D = SM.create_concourse(lower, site)
		_check(concourse != null, "each full actual baseline lower accepts its own separate concourse")
		if concourse == null:
			return false
		add_child(concourse)
		_base_concourses.append(concourse)
		_all_hosts.append(concourse)
	for right: bool in [true, false]:
		var join: Node3D = TM.create_right() if right else TM.create_left()
		_check(join != null, "construct full actual handed lower transition")
		if join == null:
			return false
		add_child(join)
		_transitions.append(join)
		_all_hosts.append(join)
		_audience_roots.append(join)
		var bowl_index: int = 0 if right else 4
		var base_index: int = 2 if right else 0
		_hand_hosts.append({"right": right, "root": self,
			"bowl_site": "BOWL-01" if right else "BOWL-05",
			"base_site": "BASE-R1" if right else "BASE-L1",
			"inputs": [join, _bowl_lowers[bowl_index], _bowl_concourses[bowl_index],
				_base_lowers[base_index], _base_concourses[base_index]]})
	_check(_count_item("ST-081") == 5 and _count_item("ST-083") == 5
		and _count_item("ST-029") == 4 and _count_item("ST-031") == 4,
		"all five complete bowl and four complete baseline purchased neighbor pairs installed")
	_check(_count_item("ST-086") == 0 and _count_item("ST-089") == 0,
		"absent transition purchases create no invisible collision bridge")
	return true


func _install_concourse(index: int) -> Node3D:
	_check(index >= 0 and index < _hand_hosts.size(), "requested hand has a complete host record")
	if index < 0 or index >= _hand_hosts.size():
		return null
	var root: Node3D = _make_concourse(_hand_hosts[index])
	_check(root != null, "matching five real purchased hosts admit exactly their handed concourse")
	if root == null:
		return null
	add_child(root)
	_installed_concourses.append(root)
	_check(root.get_meta("stadium_item", "") == ("ST-086" if index == 0 else "ST-089"),
		"right and left circulation are different stable identities, never an implicit mirror")
	_concourse_geometry(root)
	_reject_concourse(_hand_hosts[index], "actual installed concourse occupies exactly its own socket")
	return root


func _add_optional_uppers() -> bool:
	var complete: bool = _bowl_lowers.size() == 5 and _bowl_concourses.size() == 5 \
		and _base_lowers.size() == 4 and _base_concourses.size() == 4
	_check(complete, "optional upper installation requires the full actual lower/concourse host set")
	if not complete:
		return false
	for index in range(5):
		var upper: Node3D = StadiumCurvedStackModels.create_upper(_bowl_lowers[index],
			_bowl_concourses[index], StadiumCurvedLowerSites.SITES[index])
		_check(upper != null, "separate actual curved upper remains independently purchased")
		if upper == null:
			return false
		add_child(upper)
		_all_hosts.append(upper)
		_audience_roots.append(upper)
	for index in range(4):
		var upper: Node3D = SM.create_upper(_base_lowers[index],
			_base_concourses[index], StadiumBaselineSites.SITES[index])
		_check(upper != null, "separate actual straight upper remains independently purchased")
		if upper == null:
			return false
		add_child(upper)
		_all_hosts.append(upper)
		_audience_roots.append(upper)
	_check(_count_item("ST-082") == 5 and _count_item("ST-030") == 4,
		"optional neighbors add only their own explicit upper models and audience")
	return true


func _optional_upper_controls() -> bool:
	for hosts: Dictionary in _hand_hosts:
		if not _accept_concourse(hosts, "both actual same-host neighbor upper types may coexist"):
			return false
		for upper: Node3D in _all_hosts:
			if upper.get_meta("stadium_item", "") not in ["ST-082", "ST-030"]:
				continue
			if upper.get_meta("site", "") not in [hosts.bowl_site, hosts.base_site]:
				continue
			for phase: float in [-PI / 2, 0, PI / 2]:
				_animate_host(upper, phase)
				if not _accept_concourse(hosts,
					"authentic optional upper crowd sway remains a valid coexistence"):
					return false
			_animate_host(upper, 0)
			var pose: Transform3D = upper.transform
			upper.position.y += 0.1
			_reject_concourse(hosts, "displaced optional upper is not an authored coexistence state")
			upper.transform = pose
			var identity: Variant = upper.get_meta("concourse_instance")
			upper.set_meta("concourse_instance", 0)
			_reject_concourse(hosts, "optional upper must bind its actual purchased support instance")
			upper.set_meta("concourse_instance", identity)
			var shape: CollisionShape3D = upper.get_node("Collision").get_child(0).get_child(0)
			shape.disabled = true
			_reject_concourse(hosts,
				"malformed optional upper support does not bypass strict geometry proof")
			shape.disabled = false
			var duplicate: Node3D = upper.duplicate()
			add_child(duplicate)
			_reject_concourse(hosts, "two optional upper occupants cannot hide behind identical geometry")
			remove_child(duplicate)
			duplicate.free()
		if not _accept_concourse(hosts, "restoring actual optional uppers restores admission"):
			return false
	return true


func _record_every_eye(net: Node3D, with_uppers: bool) -> void:
	_full_rays.clear()
	_baseline_rays.clear()
	var blocked: int = 0
	var frontguard: int = 0
	for phase: float in [-PI / 2, 0, PI / 2]:
		for root: Node3D in _audience_roots:
			_animate_host(root, phase)
			var eye_count: int = 0
			for anchor: Node3D in root.get_node("Visual").get_children():
				if not anchor.get_meta("represented_audience", false):
					continue
				eye_count += 1
				var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
				var target: Vector3 = Vector3(0, 1, 8)
				var opaque: Array[RID] = _opaque_path(eye, target, net)
				var record: Dictionary = {"eye": eye, "target": target, "blockers": opaque}
				_full_rays.append(record)
				if root.get_meta("stadium_item") == "ST-029":
					_baseline_rays.append(record)
					if not opaque.is_empty():
						blocked += 1
					var guard: StaticBody3D = root.get_node("Collision/FrontGuard")
					if guard.get_rid() in opaque:
						frontguard += 1
			_check(eye_count == root.get_meta("represented_seats"),
				"every actual audience anchor counted, no selected-eye or missing-rest filter")
	for root: Node3D in _audience_roots:
		_animate_host(root, 0)
	_check(_full_rays.size() == (1680 if with_uppers else 1248),
		"all actual bowl baseline transition and optional upper eyes at rest and both sway extremes")
	_check(_baseline_rays.size() == 600 and blocked > 0 and frontguard > 0,
		"known frozen v1 FrontGuard blockers are explicitly retained in every before proof")
	print(("Transition concourse whole-ray before proof: %d rays; "
		+ "%d baseline blockers; %d FrontGuard hits") % [_full_rays.size(), blocked, frontguard])


func _compare_every_eye(net: Node3D) -> void:
	var new_bodies: Array[RID] = []
	for root: Node3D in _installed_concourses:
		if not root.is_inside_tree():
			continue
		for body: StaticBody3D in root.get_node("Collision").get_children():
			new_bodies.append(body.get_rid())
	for record: Dictionary in _full_rays:
		var actual: Array[RID] = _opaque_path(record.eye, record.target, net)
		_check(actual == record.blockers,
			"each complete original opaque-hit sequence is unchanged after circulation installation")
		for rid: RID in new_bodies:
			_check(rid not in actual,
				"new circulation solid cannot hide behind any preexisting opaque obstruction")


func _freeze_hosts() -> void:
	_frozen_hosts.clear()
	for root: Node3D in _all_hosts:
		_frozen_hosts.append(_full_host_signature(root))


func _check_frozen_hosts() -> void:
	for index in range(_all_hosts.size()):
		_check(_frozen_hosts[index] == _full_host_signature(_all_hosts[index]),
			"all actual purchased host poses visuals colliders and audience stay completely frozen")


func _full_host_signature(root: Node3D) -> String:
	var entries: Array = [root.transform, root.visible, _neighbor_signature(root)]
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		var body: CollisionObject3D = shape.get_parent()
		entries.append([body.get_class(), body.transform, body.collision_layer, body.collision_mask,
			shape.transform, shape.disabled, shape.shape.get_class(), shape.shape.margin])
	return var_to_bytes(entries).hex_encode().sha256_text()


func _audit_installed(with_uppers: bool) -> void:
	for index in range(_installed_concourses.size()):
		var root: Node3D = _installed_concourses[index]
		_concourse_support(root, _hand_hosts[index])
		var protected: Array[Node3D] = _all_hosts.duplicate()
		for other: Node3D in _installed_concourses:
			if other != root:
				protected.append(other)
		_no_host_penetration(root, protected)
		_check(root.get_meta("represented_seats", -1) == 0,
			"optional upper coexistence grants no transition audience or structural sockets")
	_check(_count_item("ST-082") == (5 if with_uppers else 0)
		and _count_item("ST-030") == (4 if with_uppers else 0),
		"concourse never manufactures a neighboring upper purchase")


func _camera_corridors() -> void:
	for side: int in [-1, 1]:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(side * 1.2, 1.6, -1), Vector3(0, 1.1, 9), 1)
		_check(get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			"both batting-side pitch corridors remain clear of all actual purchased models")
	for eye: Vector3 in [Vector3(-1.2, 1.6, -1), Vector3(1.2, 1.6, -1),
		Vector3(0, 4, 11), Vector3(0, 8, 18)]:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.3
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform.origin = eye
		query.collision_mask = 1
		_check(get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
			"real near gameplay-camera probe volumes clear full installed collision")


func _settle_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
