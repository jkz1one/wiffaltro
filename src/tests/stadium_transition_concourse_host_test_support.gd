extends "res://src/tests/stadium_transition_concourse_mesh_test_support.gd"
## Strict five-host admission controls; no engine-independent metadata shortcut.

const CM = preload("res://src/presentation/stadium/stadium_transition_concourse_models.gd")
const CS = preload("res://src/gameplay/stadium/stadium_transition_concourse_sites.gd")
const SS = preload("res://src/gameplay/stadium/stadium_straight_stack_sites.gd")
const SM = preload("res://src/presentation/stadium/stadium_straight_stack_models.gd")


func _make_concourse(hosts: Dictionary) -> Node3D:
	var inputs: Array = hosts.inputs
	if hosts.right:
		return CM.create_right(inputs[0], inputs[1], inputs[2], inputs[3], inputs[4])
	return CM.create_left(inputs[0], inputs[1], inputs[2], inputs[3], inputs[4])


func _new_hosts(right: bool, occupied_value: bool = true) -> Dictionary:
	var parent: Node3D = Node3D.new()
	add_child(parent)
	var join: Node3D = TM.create_right(occupied_value) if right else TM.create_left(occupied_value)
	_check(join != null, "construct actual handed lower fixture")
	if join == null:
		parent.free()
		return {}
	parent.add_child(join)
	var bowl_site: String = "BOWL-01" if right else "BOWL-05"
	var base_site: String = "BASE-R1" if right else "BASE-L1"
	var bowl: Node3D = StadiumCurvedLowerModels.create(occupied_value)
	_check(bowl != null, "construct actual bowl lower fixture")
	if bowl == null:
		parent.free()
		return {}
	parent.add_child(bowl)
	bowl.transform = StadiumCurvedLowerSites.pose(bowl_site)
	var bowl_concourse: Node3D = StadiumCurvedStackModels.create_concourse(bowl, bowl_site)
	_check(bowl_concourse != null, "construct actual purchased curved concourse fixture")
	if bowl_concourse == null:
		parent.free()
		return {}
	parent.add_child(bowl_concourse)
	var base: Node3D = StadiumBaselineStandModels.lower(occupied_value)
	_check(base != null, "construct actual baseline lower fixture")
	if base == null:
		parent.free()
		return {}
	parent.add_child(base)
	base.transform = StadiumBaselineSites.pose(base_site)
	var base_concourse: Node3D = SM.create_concourse(base, base_site)
	_check(base_concourse != null, "construct actual purchased straight concourse fixture")
	if base_concourse == null:
		parent.free()
		return {}
	parent.add_child(base_concourse)
	return {"root": parent, "right": right, "bowl_site": bowl_site, "base_site": base_site,
		"inputs": [join, bowl, bowl_concourse, base, base_concourse]}


func _reject_concourse(hosts: Dictionary, label: String) -> void:
	var candidate: Node3D = _make_concourse(hosts)
	_check(candidate == null, label)
	if candidate != null:
		candidate.free()


func _accept_concourse(hosts: Dictionary, label: String) -> bool:
	var candidate: Node3D = _make_concourse(hosts)
	var valid: bool = candidate != null and CM.complete(candidate)
	_check(valid, label)
	if candidate != null:
		candidate.free()
	return valid


func _negative_concourse_hosts() -> bool:
	for right: bool in [true, false]:
		if not _occupied_host_controls(right):
			return false
		await get_tree().process_frame
		var empty: Dictionary = _new_hosts(right, false)
		if empty.is_empty():
			return false
		var valid: bool = _accept_concourse(empty,
			"complete unoccupied hosts remain legal without audience grants")
		empty.root.queue_free()
		await get_tree().process_frame
		if not valid:
			return false
	return true


func _occupied_host_controls(right: bool) -> bool:
	var hosts: Dictionary = _new_hosts(right)
	if hosts.is_empty():
		return false
	var parent: Node3D = hosts.root
	if not _accept_concourse(hosts,
		"all five actual hosts produce a complete prism assembly before negative controls"):
		parent.queue_free()
		return false
	if not _partial_concourse_controls(hosts) or not _host_mutation_controls(hosts):
		parent.queue_free()
		return false
	var candidate: Node3D = _make_concourse(hosts)
	_check(candidate != null, "restored fixture constructs its actual transition concourse")
	if candidate == null:
		parent.queue_free()
		return false
	parent.add_child(candidate)
	_reject_concourse(hosts, "second transition concourse cannot occupy the same actual socket")
	parent.queue_free()
	return true


func _host_mutation_controls(hosts: Dictionary) -> bool:
	var parent: Node3D = hosts.root
	parent.position.y = 0.1
	_reject_concourse(hosts, "transformed common parent rejects world-shaped attachment")
	parent.position = Vector3.ZERO
	var parent_process: int = parent.process_mode
	parent.process_mode = Node.PROCESS_MODE_DISABLED
	_reject_concourse(hosts, "disabled common ancestor removes actual host participation")
	parent.process_mode = parent_process
	if not _accept_concourse(hosts, "restoring ancestor processing restores authentic host admission"):
		return false
	for index in range(5):
		if not _host_pose_controls(hosts, index) or not _host_geometry_controls(hosts, index):
			return false
	for index: int in [0, 1, 3]:
		if not _host_crowd_controls(hosts, index):
			return false
	_binding_controls(hosts)
	_conflicting_concourse_hosts(hosts)
	return _accept_concourse(hosts, "restoring all actual hosts restores valid admission")


func _host_pose_controls(hosts: Dictionary, index: int) -> bool:
	var host: Node3D = hosts.inputs[index]
	hosts.inputs[index] = null
	_reject_concourse(hosts, "every one of five purchased hosts is required")
	hosts.inputs[index] = host
	var parent: Node3D = hosts.root
	parent.remove_child(host)
	_reject_concourse(hosts, "detached host does not establish an installed interface")
	parent.add_child(host)
	var other: Node3D = Node3D.new()
	parent.add_child(other)
	parent.remove_child(host)
	other.add_child(host)
	_reject_concourse(hosts, "host under different identity parent cannot be silently reparented")
	other.remove_child(host)
	parent.add_child(host)
	parent.remove_child(other)
	other.free()
	var pose: Transform3D = host.transform
	host.position.y += 0.1
	_reject_concourse(hosts, "raised host rejected rather than stretching a connection")
	host.transform = pose
	host.scale.x *= 1.01
	_reject_concourse(hosts, "scaled host rejected rather than resizing frozen geometry")
	host.transform = pose
	host.scale.x *= -1
	_reject_concourse(hosts, "negative reflection cannot create the opposite handed interface")
	host.transform = pose
	host.top_level = true
	_reject_concourse(hosts, "top-level host cannot hide its inherited transform contract")
	host.top_level = false
	host.transform = pose
	host.visible = false
	_reject_concourse(hosts, "invisible purchased host is not complete visible support")
	host.visible = true
	var process: int = host.process_mode
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_reject_concourse(hosts, "disabled root process mode cannot deactivate authentic host support")
	host.process_mode = process
	if not _accept_concourse(hosts, "restoring root process mode restores actual host participation"):
		return false
	var item: Variant = host.get_meta("stadium_item")
	for value: Variant in ["ST-999", 85, null]:
		if value == null:
			host.remove_meta("stadium_item")
		else:
			host.set_meta("stadium_item", value)
		_reject_concourse(hosts, "missing wrong-typed or different item identity fails closed")
	host.set_meta("stadium_item", item)
	if host.has_meta("model_version"):
		var version: Variant = host.get_meta("model_version")
		for value: Variant in [0, "1"]:
			host.set_meta("model_version", value)
			_reject_concourse(hosts, "unknown or wrong-typed host version fails closed")
		host.set_meta("model_version", version)
	var anonymous: GDScript = GDScript.new()
	anonymous.source_code = "extends Node3D\n"
	_check(anonymous.reload() == OK, "valid anonymous script negative control")
	for node: Node in [host, host.get_node("Visual")]:
		node.set_script(anonymous)
		_reject_concourse(hosts, "anonymous root or descendant script participates in host proof")
		node.set_script(null)
	return true


func _host_geometry_controls(hosts: Dictionary, index: int) -> bool:
	var host: Node3D = hosts.inputs[index]
	var body: StaticBody3D = host.get_node("Collision").get_child(0)
	var shape: CollisionShape3D = body.get_child(0)
	var mesh: MeshInstance3D = host.get_node("Visual/" + str(body.name))
	var original_mesh: Mesh = mesh.mesh
	mesh.mesh = null
	_reject_concourse(hosts, "missing actual support mesh rejects without accepting metadata")
	mesh.mesh = original_mesh
	var position_value: Vector3 = mesh.position
	mesh.position.y += 0.01
	_reject_concourse(hosts, "changed actual support mesh pose rejects")
	mesh.position = position_value
	if not _host_render_controls(hosts, mesh):
		return false
	var original_shape: Shape3D = shape.shape
	shape.shape = null
	_reject_concourse(hosts, "missing actual support collider fails closed")
	shape.shape = original_shape
	shape.shape = original_shape.duplicate()
	if shape.shape is BoxShape3D:
		shape.shape.size.x += 0.1
	else:
		var changed: PackedVector3Array = shape.shape.points
		changed[0].x += 0.1
		shape.shape.points = changed
	_reject_concourse(hosts, "changed actual box or convex support volume rejects")
	shape.shape = original_shape
	shape.disabled = true
	_reject_concourse(hosts, "disabled actual support shape rejects")
	shape.disabled = false
	var layer: int = body.collision_layer
	body.collision_layer = 0
	_reject_concourse(hosts, "missing actual support collision layer rejects")
	body.collision_layer = layer
	var mask: int = body.collision_mask
	body.collision_mask = 0
	_reject_concourse(hosts, "changed actual support collision mask rejects")
	body.collision_mask = mask
	var process: int = body.process_mode
	body.process_mode = Node.PROCESS_MODE_DISABLED
	_reject_concourse(hosts, "disabled body process mode cannot remove actual collision participation")
	body.process_mode = process
	if not _accept_concourse(hosts, "restoring body process mode restores admission"):
		return false
	var disable: int = body.disable_mode
	body.disable_mode = (disable + 1) % 3
	_reject_concourse(hosts, "altered CollisionObject3D disable behavior is not canonical support")
	body.disable_mode = disable
	if not _accept_concourse(hosts, "restoring body disable mode restores admission"):
		return false
	var spoof: Node3D = Node3D.new()
	spoof.name = "CrowdAnchorExtraSupport"
	host.get_node("Collision").add_child(spoof)
	_reject_concourse(hosts, "extra crowd-named collision subtree is never exempted")
	host.get_node("Collision").remove_child(spoof)
	spoof.free()
	_host_wrong_class(hosts, body)
	return true


func _host_render_controls(hosts: Dictionary, mesh: MeshInstance3D) -> bool:
	if mesh.mesh is ArrayMesh and not _primitive_render_control(hosts, mesh):
		return false
	return _instance_render_controls(hosts, mesh) and _surface_material_control(hosts, mesh) \
		and _override_material_controls(hosts, mesh)


func _primitive_render_control(hosts: Dictionary, mesh: MeshInstance3D) -> bool:
	var source: ArrayMesh = mesh.mesh
	_report_decoded_roundtrip_once(source)
	var rebuilt: ArrayMesh = _rebuild_array_mesh(source, false)
	if rebuilt == null:
		return false
	mesh.mesh = rebuilt
	if not _accept_concourse(hosts,
		"byte-exact raw triangle reconstruction remains an authentic host"):
		_mesh_difference(rebuilt, source, "raw positive reconstruction rejected")
		mesh.mesh = source
		return false
	mesh.mesh = source
	var changed: ArrayMesh = _rebuild_array_mesh(source, true)
	if changed == null:
		return false
	mesh.mesh = changed
	_reject_concourse(hosts, "primitive-only triangle strip rejects with every raw buffer unchanged")
	mesh.mesh = source
	return _accept_concourse(hosts, "restoring actual triangle primitive restores host admission")


func _instance_render_controls(hosts: Dictionary, mesh: MeshInstance3D) -> bool:
	var overlay: Material = mesh.material_overlay
	mesh.material_overlay = StandardMaterial3D.new()
	_reject_concourse(hosts, "additional material overlay changes actual rendered host appearance")
	mesh.material_overlay = overlay
	if not _accept_concourse(hosts, "restoring material overlay restores host admission"):
		return false
	var override: Material = mesh.get_surface_override_material(0)
	mesh.set_surface_override_material(0, StandardMaterial3D.new())
	_reject_concourse(hosts,
		"per-surface material override participates despite unchanged mesh arrays")
	mesh.set_surface_override_material(0, override)
	if not _accept_concourse(hosts, "restoring per-surface override restores admission"):
		return false
	var transparency: float = mesh.transparency
	mesh.transparency = 0.5
	_reject_concourse(hosts, "instance transparency cannot make required support art partly disappear")
	mesh.transparency = transparency
	return _accept_concourse(hosts, "restoring mesh-instance transparency restores admission")


func _surface_material_control(hosts: Dictionary, mesh: MeshInstance3D) -> bool:
	var source: Mesh = mesh.mesh
	# Preserve the actual class, including PrimitiveMesh for boxes. This negative
	# control must not pass because rebuilding or conversion changed its geometry.
	mesh.mesh = source.duplicate()
	if mesh.mesh is PrimitiveMesh:
		mesh.mesh.material = StandardMaterial3D.new()
	else:
		mesh.mesh.surface_set_material(0, StandardMaterial3D.new())
	var exact: bool = mesh.mesh.get_class() == source.get_class() \
		and var_to_bytes(mesh.mesh.surface_get_arrays(0)) \
		== var_to_bytes(source.surface_get_arrays(0))
	_check(exact, "surface material control preserves actual class and byte-exact geometry arrays")
	if not exact:
		_mesh_difference(mesh.mesh, source, "surface material mutation changed geometry")
		mesh.mesh = source
		return false
	_reject_concourse(hosts, "changed material on actual mesh surface is not omitted from host proof")
	mesh.mesh = source
	return _accept_concourse(hosts, "restoring original surface material restores host admission")


func _override_material_controls(hosts: Dictionary, mesh: MeshInstance3D) -> bool:
	var original: StandardMaterial3D = mesh.material_override as StandardMaterial3D
	var cases: Array[Dictionary] = [
		{"key": "albedo_texture", "value": GradientTexture2D.new()},
		{"key": "next_pass", "value": StandardMaterial3D.new()},
		{"key": "no_depth_test", "value": true},
		{"key": "vertex_color_use_as_albedo", "value": true},
		{"key": "grow", "value": true},
		{"key": "grow_amount", "value": 0.25},
		{"key": "transparency", "value": BaseMaterial3D.TRANSPARENCY_ALPHA},
		{"key": "cull_mode", "value": BaseMaterial3D.CULL_DISABLED},
		{"key": "shading_mode", "value": BaseMaterial3D.SHADING_MODE_UNSHADED}]
	for control: Dictionary in cases:
		var changed: StandardMaterial3D = original.duplicate()
		changed.set(control.key, control.value)
		mesh.material_override = changed
		_reject_concourse(hosts, "noncanonical material %s changes real host rendering" % control.key)
		mesh.material_override = original
		if not _accept_concourse(hosts,
			"restoring original material %s restores admission" % control.key):
			return false
	return true


func _host_wrong_class(hosts: Dictionary, body: Node3D) -> void:
	var branch: Node = body.get_parent()
	var index: int = body.get_index()
	branch.remove_child(body)
	var fake: Node3D = Node3D.new()
	fake.name = body.name
	fake.transform = body.transform
	for key: StringName in body.get_meta_list():
		fake.set_meta(key, body.get_meta(key))
	branch.add_child(fake)
	branch.move_child(fake, index)
	for child: Node in body.get_children():
		body.remove_child(child)
		fake.add_child(child)
	_reject_concourse(hosts, "identical geometry under nonphysical node class rejects")
	for child: Node in fake.get_children():
		fake.remove_child(child)
		body.add_child(child)
	branch.remove_child(fake)
	fake.free()
	branch.add_child(body)
	branch.move_child(body, index)


func _host_crowd_controls(hosts: Dictionary, index: int) -> bool:
	var host: Node3D = hosts.inputs[index]
	for phase: float in [-PI / 2, 0, PI / 2]:
		_animate_host(host, phase)
		if not _accept_concourse(hosts, "actual canonical audience may use both bounded sway extremes"):
			return false
	_animate_host(host, 0)
	var crowd: Node3D = host.get_node("Visual/CrowdAnchor0")
	var rest: Vector3 = crowd.position
	crowd.scale = Vector3.ONE * 8
	_reject_concourse(hosts, "enlarged canonical crowd cannot hide behind audience exemption")
	crowd.scale = Vector3.ONE
	crowd.position.x += 0.1
	_reject_concourse(hosts, "audience horizontal drift changes the actual protected envelope")
	crowd.position = rest + Vector3.UP * 0.05
	_reject_concourse(hosts, "audience sway beyond authored range rejects")
	crowd.position = Vector3(NAN, 0, 0)
	_reject_concourse(hosts, "nonfinite audience transform fails closed")
	crowd.position = rest
	var head: MeshInstance3D = crowd.get_node("Head")
	var old_mesh: Mesh = head.mesh
	head.mesh = SphereMesh.new()
	head.mesh.radius = 2
	head.mesh.height = 4
	_reject_concourse(hosts, "changed real crowd mesh rejects despite original anchor identity")
	head.mesh = old_mesh
	if crowd.has_meta("rest_position"):
		var old_rest: Variant = crowd.get_meta("rest_position")
		for value: Variant in ["bad", Vector3(NAN, 0, 0), null]:
			if value == null:
				crowd.remove_meta("rest_position")
			else:
				crowd.set_meta("rest_position", value)
			_reject_concourse(hosts, "malformed or missing canonical rest metadata fails closed")
		crowd.set_meta("rest_position", old_rest)
	return true


func _binding_controls(hosts: Dictionary) -> void:
	for index: int in [0, 2, 4]:
		var host: Node3D = hosts.inputs[index]
		var site: Variant = host.get_meta("site")
		for value: Variant in ["JOIN-X", 1, null]:
			if value == null:
				host.remove_meta("site")
			else:
				host.set_meta("site", value)
			_reject_concourse(hosts, "missing wrong-typed or mismatched exact site rejects")
		host.set_meta("site", site)
	for index: int in [2, 4]:
		var host: Node3D = hosts.inputs[index]
		for key: String in ["lower_instance", "interface"]:
			var saved: Variant = host.get_meta(key)
			for value: Variant in [0, "wrong", null]:
				if value == null:
					host.remove_meta(key)
				else:
					host.set_meta(key, value)
				_reject_concourse(hosts, "concourse must bind exact real lower and authored interface")
			host.set_meta(key, saved)
	var base: Node3D = hosts.inputs[3]
	var pose: Transform3D = base.transform
	base.transform = StadiumBaselineSites.pose("BASE-R2" if hosts.right else "BASE-L2")
	_reject_concourse(hosts, "far baseline bay cannot substitute for the actual first-bay interface")
	base.transform = pose
	var bowl: Node3D = hosts.inputs[1]
	pose = bowl.transform
	bowl.transform = StadiumCurvedLowerSites.pose("BOWL-03")
	_reject_concourse(hosts, "central bowl cannot substitute for the exact outer-end interface")
	bowl.transform = pose
	hosts.right = not hosts.right
	_reject_concourse(hosts, "opposite complete host set cannot be treated as a free mirror")
	hosts.right = not hosts.right


func _conflicting_concourse_hosts(hosts: Dictionary) -> void:
	var parent: Node3D = hosts.root
	var base: Node3D = hosts.inputs[3]
	for item: String in ["ST-053", "ST-055", "ST-057"]:
		var conflict: Node3D = StadiumBaselineStandModels._root(item)
		parent.add_child(conflict)
		conflict.transform = base.transform
		_reject_concourse(hosts, "same-site roof or service state has no authored coexistence")
		conflict.position.x += 100
		conflict.set_meta("lower_instance", base.get_instance_id())
		_reject_concourse(hosts, "moved explicit conflicting attachment cannot hide its ownership")
		conflict.remove_meta("lower_instance")
		conflict.set_meta("site", hosts.base_site)
		_reject_concourse(hosts, "explicit same-site conflict rejects without a proximity shortcut")
		parent.remove_child(conflict)
		conflict.free()
	for state: String in ["BASE-LOWER-ROOF-v1", "BASE-SERVICE-v1", "BASE-UPPER-ROOF-v1"]:
		base.set_meta("assembly_state", state)
		_reject_concourse(hosts, "unsupported declared baseline assembly state rejects")
	base.remove_meta("assembly_state")
	var duplicate: Node3D = StadiumBaselineStandModels._root("ST-086" if hosts.right else "ST-089")
	parent.add_child(duplicate)
	duplicate.set_meta("site", "JOIN-R" if hosts.right else "JOIN-L")
	_reject_concourse(hosts, "declared existing same-handed concourse occupies its socket")
	parent.remove_child(duplicate)
	duplicate.free()


func _animate_host(host: Node3D, phase: float) -> void:
	if host.get_meta("stadium_item", "") in ["ST-029", "ST-030"]:
		SS.animate_crowd(host, phase)
	else:
		StadiumCurvedLowerModels.animate_crowd(host, phase)


func _partial_concourse_controls(hosts: Dictionary) -> bool:
	var candidate: Node3D = _make_concourse(hosts)
	_check(candidate != null and CM.complete(candidate), "complete construction preflight")
	if candidate == null:
		return false
	if not CM.complete(candidate):
		candidate.free()
		return false
	for branch: String in ["Visual", "Collision"]:
		var parent: Node = candidate.get_node(branch)
		var piece: Node = parent.get_child(0)
		parent.remove_child(piece)
		_check(not CM.complete(candidate), "missing actual prism branch cannot masquerade as complete")
		parent.add_child(piece)
		parent.move_child(piece, 0)
		_check(CM.complete(candidate), "restored exact prism branch restores completeness")
	candidate.free()
	return true
