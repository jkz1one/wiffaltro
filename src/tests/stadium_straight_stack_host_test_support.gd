extends "res://src/tests/stadium_lower_transition_models_test.gd"
## Adversarial straight attachment controls, not a separately runnable scene.

const SS = preload("res://src/gameplay/stadium/stadium_straight_stack_sites.gd")
const SM = preload("res://src/presentation/stadium/stadium_straight_stack_models.gd")


func _reject(lower: Node3D, label: String) -> void:
	var candidate: Node3D = SM.create_concourse(lower, "BASE-R1")
	_check(candidate == null, label)
	if candidate != null:
		candidate.free()


func _reject_upper(lower: Node3D, concourse: Node3D, label: String) -> void:
	var candidate: Node3D = SM.create_upper(lower, concourse, "BASE-R1")
	_check(candidate == null, label)
	if candidate != null:
		candidate.free()


func _negative_hosts() -> void:
	var parent: Node3D = Node3D.new()
	add_child(parent)
	var lower: Node3D = StadiumBaselineStandModels.lower()
	parent.add_child(lower)
	lower.transform = StadiumBaselineSites.pose("BASE-R1")
	parent.position.y = 0.1
	_reject(lower, "transformed parent rejects")
	parent.position = Vector3.ZERO
	lower.scale *= 1.01
	_reject(lower, "scaled lower rejects")
	lower.transform = StadiumBaselineSites.pose("BASE-L1")
	_reject(lower, "wrong handed site rejects")
	lower.transform = StadiumBaselineSites.pose("BASE-R1")
	lower.top_level = true
	_check(not SS.valid_lower(lower, "BASE-R1"), "top-level host rejects canonical signature")
	lower.top_level = false
	lower.transform = StadiumBaselineSites.pose("BASE-R1")
	lower.set_meta("stadium_item", "ST-081")
	_reject(lower, "curved host does not substitute")
	lower.set_meta("stadium_item", "ST-029")
	var anonymous: GDScript = GDScript.new()
	anonymous.source_code = "extends Node3D\n"
	_check(anonymous.reload() == OK and anonymous.resource_path.is_empty(),
		"adversarial script is valid but has no resource path")
	lower.set_script(anonymous)
	_reject(lower, "anonymous root script cannot masquerade as script-free canonical host")
	lower.set_script(null)
	lower.get_node("Visual").set_script(anonymous)
	_reject(lower, "anonymous descendant script cannot hide under canonical geometry")
	lower.get_node("Visual").set_script(null)
	for phase: float in [-PI / 2, 0, PI / 2]:
		SS.animate_crowd(lower, phase)
		_check(SS.valid_lower(lower, "BASE-R1"), "authentic canonical bounded sway accepted")
	SS.animate_crowd(lower, 0)
	var crowd: Node3D = lower.get_node("Visual/CrowdAnchor0")
	var rest: Vector3 = crowd.position
	_check(not crowd.has_meta("rest_position"), "frozen lower was not retrofitted with rest metadata")
	crowd.scale *= 8
	_reject(lower, "audience scale included")
	crowd.scale = Vector3.ONE
	crowd.position.x += 0.1
	_reject(lower, "audience horizontal drift included")
	crowd.position = rest + Vector3.UP * 0.05
	_reject(lower, "out-of-bound sway rejects")
	crowd.position = Vector3(NAN, 0, 0)
	_reject(lower, "nonfinite audience transform rejects")
	crowd.position = rest
	crowd.set_meta("rest_position", rest + Vector3.UP * 100)
	_reject(lower, "invented rest metadata cannot redefine canonical frozen audience")
	crowd.remove_meta("rest_position")
	crowd.rotation.y = 0
	_reject(lower, "audience orientation included")
	crowd.rotation.y = PI
	var head: MeshInstance3D = crowd.get_node("Head")
	var original: Mesh = head.mesh
	var enlarged: SphereMesh = SphereMesh.new()
	enlarged.radius = 2
	enlarged.height = 4
	head.mesh = enlarged
	_reject(lower, "full audience mesh signature rejects changed head")
	head.mesh = original
	var spoof: StaticBody3D = StaticBody3D.new()
	spoof.name = "CrowdAnchorSpoof"
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	spoof.add_child(shape)
	lower.get_node("Collision").add_child(spoof)
	_reject(lower, "crowd-named solid never omitted")
	lower.get_node("Collision").remove_child(spoof)
	spoof.free()
	var deck: StaticBody3D = lower.get_node("Collision/SolidRow9")
	var deck_shape: CollisionShape3D = deck.get_child(0)
	var old_size: Vector3 = deck_shape.shape.size
	deck_shape.shape.size *= 1.1
	_reject(lower, "actual BoxShape dimensions participate, never collapsed to invalid-shape token")
	deck_shape.shape.size = old_size
	deck_shape.disabled = true
	_reject(lower, "disabled lower shape rejects")
	deck_shape.disabled = false
	deck.collision_layer = 0
	_reject(lower, "altered lower collision layer rejects")
	deck.collision_layer = 1
	deck.collision_mask = 0
	_reject(lower, "altered lower collision mask rejects")
	deck.collision_mask = 2
	var deck_position: Vector3 = deck.position
	deck.position.x += 0.1
	_reject(lower, "actual lower support collider transform included")
	deck.position = deck_position
	_wrong_class(lower, deck)
	var stair: MeshInstance3D = lower.get_node("Visual/EntryStep39")
	var stair_size: Vector3 = stair.mesh.size
	stair.mesh.size.y += 0.05
	_reject(lower, "changed saddle host mesh rejects")
	stair.mesh.size = stair_size
	_check(SS.valid_lower(lower, "BASE-R1"), "restored authentic host accepted")
	_conflict_controls(parent, lower, null)
	var concourse: Node3D = SM.create_concourse(lower, "BASE-R1")
	_check(concourse != null, "valid restored lower creates concourse")
	if concourse != null:
		parent.add_child(concourse)
		_concourse_controls(parent, lower, concourse)
	var empty: Node3D = StadiumBaselineStandModels.lower(false)
	parent.add_child(empty)
	empty.transform = StadiumBaselineSites.pose("BASE-L2")
	_check(SS.valid_lower(empty, "BASE-L2"), "complete unoccupied canonical lower accepted")
	var empty_concourse: Node3D = SM.create_concourse(empty, "BASE-L2")
	_check(empty_concourse != null, "unoccupied lower remains a complete legal host")
	if empty_concourse != null:
		empty_concourse.free()
	parent.queue_free()
	await get_tree().process_frame


func _wrong_class(lower: Node3D, body: Node3D) -> void:
	var collision: Node = lower.get_node("Collision")
	var index: int = body.get_index()
	collision.remove_child(body)
	var fake: Node3D = Node3D.new()
	fake.name = body.name
	fake.transform = body.transform
	for key: StringName in body.get_meta_list():
		fake.set_meta(key, body.get_meta(key))
	collision.add_child(fake)
	collision.move_child(fake, index)
	for child: Node in body.get_children():
		body.remove_child(child)
		fake.add_child(child)
	_reject(lower, "identical geometry under nonphysical node class rejects")
	for child: Node in fake.get_children():
		fake.remove_child(child)
		body.add_child(child)
	collision.remove_child(fake)
	fake.free()
	collision.add_child(body)
	collision.move_child(body, index)


func _conflict_controls(parent: Node3D, lower: Node3D, concourse: Node3D) -> void:
	for item: String in ["ST-053", "ST-055", "ST-057"]:
		var conflict: Node3D = StadiumBaselineStandModels.lower_canopy() if item == "ST-053" \
			else StadiumBaselineStandModels._root(item)
		parent.add_child(conflict)
		conflict.transform = lower.transform
		if concourse == null:
			_reject(lower, "actual same-site roof/service occupant rejects concourse")
		else:
			_reject_upper(lower, concourse, "roof/service conflicts reject upper")
		conflict.position += Vector3(100, 0, 0)
		conflict.set_meta("lower_instance", lower.get_instance_id())
		if concourse != null:
			_reject_upper(lower, concourse, "explicit attachment conflict cannot hide by moved geometry")
		conflict.remove_meta("lower_instance")
		conflict.set_meta("site", "BASE-R1")
		if concourse != null:
			_reject_upper(lower, concourse, "declared same-site conflict rejects without proximity")
		parent.remove_child(conflict)
		conflict.free()
	for state: String in ["BASE-LOWER-ROOF-v1", "BASE-SERVICE-v1", "BASE-UPPER-ROOF-v1"]:
		lower.set_meta("assembly_state", state)
		if concourse == null:
			_reject(lower, "unsupported declared assembly state rejects")
		else:
			_reject_upper(lower, concourse, "conflicting declared assembly state rejects upper")
	lower.remove_meta("assembly_state")


func _concourse_controls(parent: Node3D, lower: Node3D, concourse: Node3D) -> void:
	var anonymous: GDScript = GDScript.new()
	anonymous.source_code = "extends Node3D\n"
	_check(anonymous.reload() == OK, "valid anonymous concourse script control")
	concourse.set_script(anonymous)
	_reject_upper(lower, concourse, "anonymous support root script rejects")
	concourse.set_script(null)
	concourse.get_node("Collision/ConcourseDeck").set_script(anonymous)
	_reject_upper(lower, concourse, "anonymous support collider script rejects")
	concourse.get_node("Collision/ConcourseDeck").set_script(null)
	concourse.set_meta("stadium_item", "ST-083")
	_reject_upper(lower, concourse, "curved concourse cannot substitute")
	concourse.set_meta("stadium_item", "ST-031")
	concourse.set_meta("lower_instance", 0)
	_reject_upper(lower, concourse, "wrong lower instance rejects")
	concourse.set_meta("lower_instance", lower.get_instance_id())
	concourse.set_meta("interface", "invented interface")
	_reject_upper(lower, concourse, "wrong rear interface rejects")
	concourse.set_meta("interface", SS.INTERFACE)
	concourse.set_meta("model_version", 2)
	_reject_upper(lower, concourse, "unauthored support version rejects")
	concourse.set_meta("model_version", 1)
	concourse.position.y += 0.1
	_reject_upper(lower, concourse, "raised support rejected")
	concourse.transform = lower.transform
	var deck: StaticBody3D = concourse.get_node("Collision/ConcourseDeck")
	var shape: CollisionShape3D = deck.get_child(0)
	shape.disabled = true
	_reject_upper(lower, concourse, "disabled purchased support rejects")
	shape.disabled = false
	var size_value: Vector3 = shape.shape.size
	shape.shape.size.x += 0.1
	_reject_upper(lower, concourse, "changed actual concourse collider rejects")
	shape.shape.size = size_value
	var visual: MeshInstance3D = concourse.get_node("Visual/RearSaddle")
	var visual_position: Vector3 = visual.position
	visual.position.x += 0.1
	_reject_upper(lower, concourse, "changed real saddle mesh rejects")
	visual.position = visual_position
	var extra: Node3D = Node3D.new()
	extra.name = "CrowdAnchorExtra"
	concourse.get_node("Visual").add_child(extra)
	_reject_upper(lower, concourse, "extra crowd-named support branch rejects")
	concourse.get_node("Visual").remove_child(extra)
	extra.free()
	_conflict_controls(parent, lower, concourse)
	var upper: Node3D = SM.create_upper(lower, concourse, "BASE-R1", false)
	_check(upper != null, "restoration permits unoccupied upper without granting extra audience")
	if upper != null:
		_check(upper.get_node("Visual").find_children("CrowdAnchor*", "Node3D", false, false).is_empty(),
			"unoccupied upper has no hidden crowd")
		parent.add_child(upper)
		_reject_upper(lower, concourse, "one upper invariant enforced")
