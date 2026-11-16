extends "res://src/tests/stadium_transition_concourse_net_test_support.gd"
## New bounded host-admission proof. Frozen v1 helpers remain unchanged.

const GS = preload("res://src/gameplay/stadium/stadium_grand_three_stack_sites.gd")
const GM = preload("res://src/presentation/stadium/stadium_grand_three_stack_models.gd")


func _grand_transition(hosts: Dictionary) -> Node3D:
	var inputs: Array = hosts.inputs
	return GM.create_transition("JOIN-R" if hosts.right else "JOIN-L",
		inputs[0], inputs[1], inputs[2], inputs[3], inputs[4])


func _grand_transition_valid(hosts: Dictionary) -> bool:
	var inputs: Array = hosts.inputs
	return GS.valid_transition_hosts("JOIN-R" if hosts.right else "JOIN-L",
		inputs[0], inputs[1], inputs[2], inputs[3], inputs[4])


func _grand_reject(hosts: Dictionary, label: String) -> void:
	_check(not _grand_transition_valid(hosts), label)
	var candidate: Node3D = _grand_transition(hosts)
	_check(candidate == null, "factory also rejects: " + label)
	if candidate != null:
		candidate.free()


func _grand_canonical_controls(piece: Node3D, valid: Callable) -> void:
	_check(valid.call(), "authentic complete purchase is admitted before mutation")
	var pose: Transform3D = piece.transform
	piece.position.y += 0.1
	_check(not valid.call(), "translated actual purchase rejects")
	piece.transform = pose
	piece.scale *= 1.01
	_check(not valid.call(), "scaled actual purchase rejects")
	piece.transform = pose
	piece.visible = false
	_check(not valid.call(), "hidden actual purchase rejects")
	piece.visible = true
	piece.top_level = true
	_check(not valid.call(), "top-level branch rejects canonical admission")
	piece.top_level = false
	piece.transform = pose
	var mesh: MeshInstance3D = piece.get_node("Visual").get_child(0)
	var visual_pose: Transform3D = mesh.transform
	mesh.position.y += 0.01
	_check(not valid.call(), "actual visible geometry translation rejects")
	mesh.transform = visual_pose
	var material: StandardMaterial3D = mesh.material_override
	var color: Color = material.albedo_color
	material.albedo_color = Color.MAGENTA
	_check(not valid.call(), "actual material color participates in canonical proof")
	material.albedo_color = color
	material.next_pass = StandardMaterial3D.new()
	_check(not valid.call(), "additional opaque material pass rejects")
	material.next_pass = null
	mesh.material_overlay = StandardMaterial3D.new()
	_check(not valid.call(), "extra opaque material overlay rejects")
	mesh.material_overlay = null
	var body: StaticBody3D = piece.get_node("Collision").get_child(0)
	var shape: CollisionShape3D = body.get_child(0)
	shape.disabled = true
	_check(not valid.call(), "disabled actual collider rejects")
	shape.disabled = false
	body.collision_layer = 0
	_check(not valid.call(), "missing scenery collision layer rejects")
	body.collision_layer = 1
	body.collision_mask = 0
	_check(not valid.call(), "changed actual collision mask rejects")
	body.collision_mask = 2
	var original: Shape3D = shape.shape
	shape.shape = original.duplicate()
	if shape.shape is BoxShape3D:
		shape.shape.size.x += 0.05
	else:
		var points: PackedVector3Array = shape.shape.points
		points[0].y += 0.05
		shape.shape.points = points
	_check(not valid.call(), "changed actual shape volume rejects")
	shape.shape = original
	var bias: float = shape.shape.custom_solver_bias
	shape.shape.custom_solver_bias = 0.25
	_check(not valid.call(), "changed actual collision solver bias rejects")
	shape.shape.custom_solver_bias = bias
	var extra: Node3D = Node3D.new()
	extra.name = "CrowdAnchorUnauthorized"
	piece.get_node("Visual").add_child(extra)
	_check(not valid.call(), "crowd-named unexpected branches cannot hide from validation")
	piece.get_node("Visual").remove_child(extra)
	extra.free()
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node3D\n"
	_check(script.reload() == OK, "anonymous-script adversarial witness compiles")
	piece.set_script(script)
	_check(not valid.call(), "anonymous executable root script rejects")
	piece.set_script(null)
	mesh.set_script(script)
	_check(not valid.call(), "anonymous executable descendant script rejects")
	mesh.set_script(null)
	for key: String in ["model_version", "site", "lower_instance", "interface"]:
		if not piece.has_meta(key):
			continue
		var stored: Variant = piece.get_meta(key)
		piece.set_meta(key, str(stored) if typeof(stored) == TYPE_INT else StringName(str(stored)))
		_check(not valid.call(), "required host metadata preserves exact raw type: " + key)
		piece.set_meta(key, stored)
	var mesh_script: GDScript = GDScript.new()
	mesh_script.source_code = "extends " + mesh.mesh.get_class() + "\n"
	_check(mesh_script.reload() == OK, "actual mesh-resource script witness compiles")
	mesh.mesh.set_script(mesh_script)
	_check(not valid.call(), "anonymous actual mesh-resource script rejects")
	mesh.mesh.set_script(null)
	var shape_script: GDScript = GDScript.new()
	shape_script.source_code = "extends " + shape.shape.get_class() + "\n"
	_check(shape_script.reload() == OK, "actual shape-resource script witness compiles")
	shape.shape.set_script(shape_script)
	_check(not valid.call(), "anonymous actual shape-resource script rejects")
	shape.shape.set_script(null)
	_check(valid.call(), "restoring geometry material collision and script restores exact admission")


func _grand_lower_controls() -> void:
	var parent: Node3D = Node3D.new()
	add_child(parent)
	var site: String = "BASE-R1"
	var legacy: Node3D = StadiumBaselineStandModels.lower()
	parent.add_child(legacy)
	legacy.transform = StadiumBaselineSites.pose(site)
	_check(not GS.valid_lower(legacy, site), "guard-v1 is not silently admitted by guard-v2 adapter")
	legacy.set_meta("model_version", 2)
	legacy.set_meta("model_variant", StadiumBaselineSightlineModels.VARIANT)
	_check(not GS.valid_lower(legacy, site), "v2 labels cannot launder actual old guard geometry")
	legacy.free()
	var lower: Node3D = StadiumBaselineSightlineModels.lower()
	_check(lower != null, "authentic guard-only v2 constructor exists")
	if lower == null:
		parent.free()
		return
	parent.add_child(lower)
	lower.transform = StadiumBaselineSites.pose(site)
	_check(not SS.valid_lower(lower, site), "unchanged frozen straight adapter still rejects guard-v2")
	_check(SM.create_concourse(lower, site) == null, "old factory remains explicitly v1-only")
	_grand_canonical_controls(lower, func() -> bool: return GS.valid_lower(lower, site))
	for phase: float in [-PI / 2, 0, PI / 2]:
		SS.animate_crowd(lower, phase)
		_check(GS.valid_lower(lower, site), "actual canonical lower crowd sway remains legal")
	SS.animate_crowd(lower, 0)
	var crowd: Node3D = lower.get_node("Visual/CrowdAnchor0")
	var rest: Vector3 = crowd.position
	crowd.position.y += 0.05
	_check(not GS.valid_lower(lower, site), "out-of-bound actual audience sway rejects")
	crowd.position = rest
	crowd.set_meta("rest_position", rest + Vector3.UP * 100)
	_check(not GS.valid_lower(lower, site), "invented crowd rest metadata cannot redefine geometry")
	crowd.remove_meta("rest_position")
	parent.position.y = 0.1
	_check(not GS.valid_lower(lower, site), "nonidentity common ancestor rejects exact site")
	parent.position = Vector3.ZERO
	for wrong_site: String in ["BASE-L1", "JOIN-R", "BOWL-01", "BASE-X"]:
		_check(not GS.valid_lower(lower, wrong_site), "wrong hand or unsupported socket rejects")
	_check(GM.create_upper(lower, null, site) == null, "missing purchased concourse rejects upper")
	_check(GM.create_roof(lower, null, null, site) == null, "lower alone cannot gain upper roof")
	parent.free()


func _grand_layer_controls(stack: Array[Node3D], site: String) -> void:
	var lower: Node3D = stack[0]
	var concourse: Node3D = stack[1]
	var upper: Node3D = stack[2]
	var roof: Node3D = stack[3]
	_grand_canonical_controls(concourse,
		func() -> bool: return GS.valid_concourse(lower, concourse, site))
	_grand_canonical_controls(upper,
		func() -> bool: return GS.valid_upper(lower, concourse, upper, site))
	_grand_canonical_controls(roof,
		func() -> bool: return GS.valid_roof(lower, concourse, upper, roof, site))
	for piece: Node3D in [concourse, upper, roof]:
		var bound: Variant = piece.get_meta("lower_instance")
		piece.set_meta("lower_instance", 0)
		_check(not GS.valid_roof(lower, concourse, upper, roof, site),
			"every layer binds its actual authentic lower instance")
		piece.set_meta("lower_instance", bound)
	for piece: Node3D in [upper, roof]:
		var bound: Variant = piece.get_meta("concourse_instance")
		piece.set_meta("concourse_instance", 0)
		_check(not GS.valid_roof(lower, concourse, upper, roof, site),
			"upper and roof bind actual purchased concourse instance")
		piece.set_meta("concourse_instance", bound)
	var upper_id: Variant = roof.get_meta("upper_instance")
	roof.set_meta("upper_instance", 0)
	_check(not GS.valid_roof(lower, concourse, upper, roof, site), "roof binds actual upper instance")
	roof.set_meta("upper_instance", upper_id)
	_check(GS.valid_roof(lower, concourse, upper, roof, site), "restoring bindings restores roof")


func _grand_neighbor_controls(hosts: Dictionary, neighbors: Array[Node3D]) -> void:
	_check(_grand_transition_valid(hosts), "roofed neighbors admit an authentic roofless transition")
	_check(_make_concourse(hosts) == null, "unchanged transition-v1 adapter still rejects this state")
	for index in range(5):
		var host: Node3D = hosts.inputs[index]
		hosts.inputs[index] = null
		_grand_reject(hosts, "each of five actual purchased hosts is mandatory")
		hosts.inputs[index] = host
	for neighbor: Node3D in neighbors:
		_grand_canonical_controls(neighbor,
			func() -> bool: return _grand_transition_valid(hosts))
		var duplicate: Node3D = neighbor.duplicate()
		add_child(duplicate)
		_grand_reject(hosts, "duplicate neighbor cannot masquerade as a single purchased layer")
		for key: StringName in duplicate.get_meta_list():
			duplicate.remove_meta(key)
		_grand_reject(hosts, "pose-only duplicate cannot hide by omitting all identifying metadata")
		remove_child(duplicate)
		duplicate.free()
	for item: String in ["ST-053", "ST-055", "ST-057", "ST-087", "ST-090"]:
		var conflict: Node3D = Node3D.new()
		conflict.set_meta("stadium_item", item)
		conflict.set_meta("site", "JOIN-R" if hosts.right else "JOIN-L")
		add_child(conflict)
		_grand_reject(hosts, "transition never gains a roof upper or service socket")
		remove_child(conflict)
		conflict.free()
	_check(_grand_transition_valid(hosts), "restored roofed neighbors regain exact admission")


func _grand_empty_controls() -> void:
	for right: bool in [true, false]:
		var parent: Node3D = Node3D.new()
		add_child(parent)
		var base_site: String = "BASE-R1" if right else "BASE-L1"
		var bowl_site: String = "BOWL-01" if right else "BOWL-05"
		var base: Node3D = StadiumBaselineSightlineModels.lower(false)
		var bowl: Node3D = StadiumCurvedLowerModels.create(false)
		var join: Node3D = TM.create_right(false) if right else TM.create_left(false)
		parent.add_child(base)
		parent.add_child(bowl)
		parent.add_child(join)
		base.transform = StadiumBaselineSites.pose(base_site)
		bowl.transform = StadiumCurvedLowerSites.pose(bowl_site)
		var straight: Node3D = GM.create_concourse(base, base_site)
		var curved: Node3D = StadiumCurvedStackModels.create_concourse(bowl, bowl_site)
		_check(straight != null and curved != null, "empty lowers support purchased concourses")
		if straight == null or curved == null:
			if straight != null:
				straight.free()
			if curved != null:
				curved.free()
			parent.free()
			continue
		parent.add_child(straight)
		parent.add_child(curved)
		var upper: Node3D = GM.create_upper(base, straight, base_site, false)
		var bowl_upper: Node3D = StadiumCurvedStackModels.create_upper(bowl, curved, bowl_site, false)
		_check(upper != null and bowl_upper != null, "empty authentic hosts support purchased uppers")
		if upper == null or bowl_upper == null:
			if upper != null:
				upper.free()
			if bowl_upper != null:
				bowl_upper.free()
			parent.free()
			continue
		parent.add_child(upper)
		parent.add_child(bowl_upper)
		var old_canopy: Node3D = StadiumBaselineStandModels.lower_canopy()
		parent.add_child(old_canopy)
		old_canopy.transform = base.transform
		_check(GM.create_roof(base, straight, upper, base_site) == null,
			"genuine old lower canopy conflicts with the authentic upper-roof socket")
		old_canopy.free()
		for item: String in ["ST-055", "ST-057"]:
			var service: Node3D = StadiumBaselineStandModels._root(item)
			parent.add_child(service)
			service.transform = base.transform
			_check(GM.create_roof(base, straight, upper, base_site) == null,
				"actual same-bay service occupant rejects independently purchased upper roof")
			service.free()
		var roof: Node3D = GM.create_roof(base, straight, upper, base_site)
		var bowl_roof: Node3D = StadiumCurvedCanopyModels.create(bowl, curved, bowl_upper, bowl_site)
		_check(roof != null and bowl_roof != null, "empty authentic stacks support both roof kinds")
		if roof == null or bowl_roof == null:
			if roof != null:
				roof.free()
			if bowl_roof != null:
				bowl_roof.free()
			parent.free()
			continue
		parent.add_child(roof)
		parent.add_child(bowl_roof)
		var hosts: Dictionary = {"right": right, "inputs": [join, bowl, curved, base, straight]}
		_check(_grand_transition_valid(hosts), "both unoccupied complete roofed neighbor hands are legal")
		_grand_non_spatial_siblings(hosts, base, straight, upper, roof, base_site)
		var transition: Node3D = _grand_transition(hosts)
		_check(transition != null, "unoccupied roofed hosts independently construct roofless transition")
		if transition != null:
			parent.add_child(transition)
		for purchase: Node in parent.get_children():
			for anchor: Node in purchase.get_node("Visual").get_children():
				_check(not anchor.get_meta("represented_audience", false),
					"unoccupied models and circulation never grant hidden audience")
		parent.free()


func _grand_non_spatial_siblings(hosts: Dictionary, base: Node3D, straight: Node3D,
	upper: Node3D, roof: Node3D, site: String) -> void:
	# WorldEnvironment is a Node, not a Node3D. Typed-array membership must never
	# inspect it before the type guard, and related declarations must still reject.
	var allowed: Array[Node3D] = [base, straight, upper, roof]
	var siblings: Array[Node] = [WorldEnvironment.new(), Node.new()]
	for sibling: Node in siblings:
		base.get_parent().add_child(sibling)
	_check(GS.vacant(base, site, allowed) and _grand_transition_valid(hosts),
		"unrelated WorldEnvironment and plain Node siblings leave authentic hosts valid")
	for sibling: Node in siblings:
		sibling.set_meta("site", site)
		_check(not GS.vacant(base, site, allowed),
			"non-spatial sibling claiming a purchased baseline site rejects vacancy")
		_grand_reject(hosts, "non-spatial sibling claiming a neighboring host site rejects")
		sibling.remove_meta("site")
		_check(GS.vacant(base, site, allowed) and _grand_transition_valid(hosts),
			"removing non-spatial site claim restores actual canonical host admission")
		sibling.set_meta("lower_instance", base.get_instance_id())
		_check(not GS.vacant(base, site, allowed),
			"non-spatial sibling claiming the actual lower instance rejects vacancy")
		_grand_reject(hosts, "non-spatial sibling claiming actual dependency rejects")
		sibling.remove_meta("lower_instance")
		_check(GS.vacant(base, site, allowed) and _grand_transition_valid(hosts),
			"removing non-spatial dependency claim restores actual canonical host admission")
		sibling.set_meta("upper_instance", upper.get_instance_id())
		_check(not GS.vacant(base, site, allowed),
			"non-spatial sibling claiming the actual upper instance rejects vacancy")
		_grand_reject(hosts, "second neighbor scan rejects non-spatial optional-upper dependency")
		sibling.remove_meta("upper_instance")
		_check(GS.vacant(base, site, allowed) and _grand_transition_valid(hosts),
			"removing optional-upper claim restores both neighbor scans")
	for sibling: Node in siblings:
		sibling.free()
	_check(GS.vacant(base, site, allowed) and _grand_transition_valid(hosts),
		"removing both non-spatial witnesses retains exact positive admission")
