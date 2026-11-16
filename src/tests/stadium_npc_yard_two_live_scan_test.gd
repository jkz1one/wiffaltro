extends "res://src/tests/stadium_npc_yard_two_runtime_test.gd"
## Supplemental R8 live-scan regressions; original runtime and reference suites stay intact.
# gdlint: disable=max-file-lines

const G = preload("res://src/presentation/stadium/stadium_npc_yard_two_installed_geometry_v1.gd")
const Oracle = preload("res://src/tests/stadium_npc_yard_two_live_scan_oracle.gd")
const REQUIRED: Array[String] = [
	"SCAN-01/plain",
	"SCAN-01/configured",
	"SCAN-01/shape_replacement",
	"SCAN-01/material_replacement",
	"SCAN-01/node_replacement",
	"SCAN-01/shape_content",
	"SCAN-01/material_content",
	"SCAN-01/field_content",
	"SCAN-01/process_mode",
	"SCAN-01/process_priority",
	"SCAN-01/physics_priority",
	"SCAN-01/disable_mode",
	"SCAN-01/child_order",
	"SCAN-01/restored",
	"SCAN-03/same_turn",
	"SCAN-03/scratch_retention",
	"SCAN-02/array_sharing",
	"SCAN-02/dictionary_sharing",
	"SCAN-02/property_sharing",
	"SCAN-02/self_cycle",
	"SCAN-02/mutual_cycle",
	"SCAN-02/scripted_getters",
	"SCAN-02/script_before_seen",
	"SCAN-04/decorative_prerequisite",
	"SCAN-04/decorative_cold",
	"SCAN-04/install",
	"SCAN-04/callback_shape",
	"SCAN-04/callback_restore",
	"SCAN-04/callback_nested",
	"SCAN-04/callback_nested_restore",
	"SCAN-04/teardown",
	"SCAN-04/reinstall",
	"SCAN-04/reinstall_teardown",
	"SCAN-04/presentation_positive",
	"SCAN-04/property_inline",
	"SCAN-04/actor_inline",
	"SCAN-04/camera_refusal",
	"SCAN-04/actor_refusal",
	"SCAN-04/property_refusal",
	"SCAN-04/receiver_refusal",
	"SCAN-04/virtual_lab_fallback",
	"SCAN-04/virtual_lab_teardown",
]


const SCHEMA_REQUIRED: Array[String] = [
	"SCHEMA-01/eligible", "SCHEMA-01/identity", "SCHEMA-01/content",
	"SCHEMA-02/selectors", "SCHEMA-02/types_scripts_metadata", "SCHEMA-02/default_scope",
	"SCHEMA-03/later_selector", "SCHEMA-03/fresh_key", "SCHEMA-03/current_snapshot",
	"SCHEMA-03/current_script", "SCHEMA-04/fresh_admission", "SCHEMA-04/scratch_names",
]
const LIGHT_UNITS: String = "rendering/lights_and_shadows/use_physical_light_units"


class MaterialReads:
	extends StandardMaterial3D
	var events: Array = []

	func _get(property: StringName) -> Variant:
		events.append("get:" + String(property))
		return null


class SchemaGetter:
	extends StandardMaterial3D
	@export var observed: Resource:
		get:
			events.append("nested")
			if action.is_valid():
				action.call()
			return payload
		set(value):
			payload = value
	var events: Array = []
	var action: Callable
	var payload: Resource


class StoredGetter:
	extends Resource
	@export var observed: Resource:
		get:
			reads += 1
			return payload
		set(value):
			payload = value
	var reads: int = 0
	var payload: Resource


class MutatingLab:
	extends PitchBatLab
	var target: BoxShape3D
	var armed: bool = false
	var mutations: int = 0

	func _ball_in_play_is_live() -> bool:
		var live: bool = super._ball_in_play_is_live()
		if armed:
			armed = false
			mutations += 1
			target.size += Vector3(0.125, 0, 0)
		return live


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		push_error("AY02 live scan requires no user arguments")
		get_tree().quit(2)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detached_scan()
	_resource_scans()
	_schema_eligible()
	_schema_fallbacks()
	_schema_mutations()
	_schema_admissions()
	_installed_scan()
	_virtual_lab_scan()
	await TestAudioDrain.finish(get_tree())
	var required: Array[String] = REQUIRED + SCHEMA_REQUIRED
	for id: String in required:
		if not _seen.has(id) or _seen[id].size() != 1:
			_failures += 1
	for id: String in _seen:
		if not required.has(id):
			_failures += 1
	print("AY02_CASE_REPORT ", JSON.stringify({"schema": "ay02-reconstructed-cases-v1",
		"scene": "live_scan", "required": required, "assertions": _seen,
		"failures": _failures, "rendered_qualification": false}))
	if _failures == 0:
		print("AY02_LIVE_SCAN_PASS")
	get_tree().quit(0 if _failures == 0 else 1)


func _parity(property: StadiumNpcYardTwoPropertyV1, full: bool, content: bool) -> bool:
	# Eager samples: a failed comparison cannot hide any of the other implementations.
	var old_identities: Array = Oracle.identities(property.construction)
	var old_identity: bool = property._identities == old_identities
	var old_content: bool = Oracle.same(property)
	var old_full: bool = old_identity and old_content
	var new_full: bool = G.intact(property)
	var public_full: bool = property.geometry_intact()
	var new_content: bool = G.same(property)
	return old_full == full and new_full == full and public_full == full \
		and old_content == content and new_content == content


func _scan_matches(root: Node, expected_resources: Array, expected_nodes: Array) -> bool:
	var old_ids: Array = Oracle.identities(root)
	var public_ids: Array = G.identities(root)
	var ids: Array = []
	var nodes: Array = []
	G._collect_live(root, ids, nodes)
	var resources: Array = []
	for row: Array in ids:
		if row[0] is Resource:
			resources.append(row[0])
	return ids == old_ids and ids == public_ids and resources == expected_resources \
		and nodes == expected_nodes


func _detached_scan() -> void:
	var property: StadiumNpcYardTwoPropertyV1 = R._construct(null)
	_assert("SCAN-01/plain", _parity(property, true, true),
		"Plain full identity-plus-content oracle and independent new entries all accept")
	var configured: bool = R._bind_components(null, property)
	var configured_parity: bool = _parity(property, true, true)
	_assert("SCAN-01/configured", configured and configured_parity,
		"Configured geometry retains the original full admission semantics")
	var chair: Node3D = property.objects[P + "RECEIVER-PRIMARY"]
	var mesh: MeshInstance3D = chair.get_node("Visual/ST079_BACK")
	var body: StaticBody3D = chair.get_node("Collision/ST079_BACK")
	var shape: CollisionShape3D = body.get_child(0)
	var box: BoxShape3D = shape.shape
	var size: Vector3 = box.size
	shape.shape = box.duplicate(true)
	_assert("SCAN-01/shape_replacement", _parity(property, false, true),
		"Same-content shape replacement refuses full identity admission; public same stays true")
	shape.shape = box
	var material: StandardMaterial3D = mesh.material_override
	mesh.material_override = material.duplicate(true)
	_assert("SCAN-01/material_replacement", _parity(property, false, true),
		"Same-content material replacement refuses full admission; public same stays true")
	mesh.material_override = material
	var shape_index: int = shape.get_index()
	var shape_name: StringName = shape.name
	var node_state: Array = [shape.shape, shape.get_parent(), shape.get_index(),
		shape.get_script(), shape.get_child_count(), shape.process_mode,
		shape.process_priority, shape.process_physics_priority,
		var_to_bytes(StadiumNpcRetainedGeometry._geometry(shape))]
	var node_base: bool = _parity(property, true, true)
	var node_base_stable: bool = [shape.shape, shape.get_parent(), shape.get_index(),
		shape.get_script(), shape.get_child_count(), shape.process_mode,
		shape.process_priority, shape.process_physics_priority,
		var_to_bytes(StadiumNpcRetainedGeometry._geometry(shape))] == node_state
	# A native unnamed node preserves the same-content premise; duplicate sanitizes its name.
	var replacement: CollisionShape3D = CollisionShape3D.new()
	replacement.shape = box
	replacement.transform = shape.transform
	replacement.visible = shape.visible
	replacement.top_level = shape.top_level
	replacement.disabled = shape.disabled
	replacement.process_mode = shape.process_mode
	replacement.process_priority = shape.process_priority
	replacement.process_physics_priority = shape.process_physics_priority
	body.remove_child(shape)
	body.add_child(replacement)
	body.move_child(replacement, shape_index)
	var replacement_precondition: bool = replacement != shape and replacement.shape == box \
		and String(shape_name).begins_with("@") and String(replacement.name).begins_with("@") \
		and shape.get_parent() == null and replacement.get_parent() == body
	var replacement_state: Array = [replacement.shape, replacement.get_parent(),
		replacement.get_index(), replacement.get_script(), replacement.get_child_count(),
		replacement.process_mode, replacement.process_priority, replacement.process_physics_priority,
		var_to_bytes(StadiumNpcRetainedGeometry._geometry(replacement))]
	var replacement_parity: bool = _parity(property, false, true)
	var replacement_stable: bool = [replacement.shape, replacement.get_parent(),
		replacement.get_index(), replacement.get_script(), replacement.get_child_count(),
		replacement.process_mode, replacement.process_priority, replacement.process_physics_priority,
		var_to_bytes(StadiumNpcRetainedGeometry._geometry(replacement))] == replacement_state
	body.remove_child(replacement)
	body.add_child(shape)
	body.move_child(shape, shape_index)
	replacement.free()
	var restored_state: Array = [shape.shape, shape.get_parent(), shape.get_index(),
		shape.get_script(), shape.get_child_count(), shape.process_mode,
		shape.process_priority, shape.process_physics_priority,
		var_to_bytes(StadiumNpcRetainedGeometry._geometry(shape))]
	var node_restored: bool = _parity(property, true, true)
	var node_restored_stable: bool = [shape.shape, shape.get_parent(), shape.get_index(),
		shape.get_script(), shape.get_child_count(), shape.process_mode,
		shape.process_priority, shape.process_physics_priority,
		var_to_bytes(StadiumNpcRetainedGeometry._geometry(shape))] == restored_state
	_assert("SCAN-01/node_replacement", node_base and node_base_stable
		and replacement_precondition and replacement_state == node_state
		and replacement_parity and replacement_stable
		and not is_instance_valid(replacement) and shape.name == shape_name
		and restored_state == node_state and node_restored and node_restored_stable,
		"Same-content node with original shape cannot inherit the removed node's identity")
	box.size.x += 0.125
	_assert("SCAN-01/shape_content", _parity(property, false, false),
		"Applied live collider mutation refuses both content and full comparisons")
	box.size = size
	var roughness: float = material.roughness
	material.roughness = 0.33
	_assert("SCAN-01/material_content", _parity(property, false, false),
		"Live material content is sampled after the full identity traversal")
	material.roughness = roughness
	var field_z: float = property.field.back_wall_z_m
	property.field.back_wall_z_m += 0.125
	_assert("SCAN-01/field_content", _parity(property, false, false),
		"Current typed field content cannot reuse a previous accepted scan")
	property.field.back_wall_z_m = field_z
	var mode: Node.ProcessMode = body.process_mode
	body.process_mode = Node.PROCESS_MODE_DISABLED
	_assert("SCAN-01/process_mode", _parity(property, false, false),
		"Live process mode is still read after identity admission")
	body.process_mode = mode
	body.process_priority = 1
	_assert("SCAN-01/process_priority", _parity(property, false, false),
		"Live ordinary process priority remains exact")
	body.process_priority = 0
	body.process_physics_priority = 1
	_assert("SCAN-01/physics_priority", _parity(property, false, false),
		"Live physics process priority remains exact")
	body.process_physics_priority = 0
	var disable: CollisionObject3D.DisableMode = body.disable_mode
	body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	_assert("SCAN-01/disable_mode", _parity(property, false, false),
		"Collision-object disable policy remains independently checked")
	body.disable_mode = disable
	var visual: Node = chair.get_node("Visual")
	var visual_index: int = visual.get_index()
	chair.move_child(visual, 1)
	_assert("SCAN-01/child_order", _parity(property, false, false),
		"Node traversal preserves child order in both identity and content admission")
	chair.move_child(visual, visual_index)
	_assert("SCAN-01/restored", _parity(property, true, true),
		"Restoring original nodes, resources, policies and fields restores acceptance")
	_same_turn_scans(property, box)
	_scripted_resources(property)
	property.free()


func _same_turn_scans(property: StadiumNpcYardTwoPropertyV1, box: BoxShape3D) -> void:
	# There are deliberately no awaits between admission, mutation, refusal and restoration.
	var size: Vector3 = box.size
	var accepted: bool = _parity(property, true, true)
	box.size.x += 0.125
	var refused: bool = _parity(property, false, false)
	box.size = size
	var restored: bool = _parity(property, true, true)
	_assert("SCAN-03/same_turn", accepted and refused and restored,
		"Accept, mutate, reject, restore and accept all occur in one synchronous turn")
	var retained_ids: Array = G.identities(property.construction)
	var scratch_ids: Array = []
	var scratch_nodes: Array = []
	G._collect_live(property.construction, scratch_ids, scratch_nodes)
	var originally_equal: bool = retained_ids == property._identities \
		and scratch_ids == property._identities and not scratch_nodes.is_empty()
	box.size.x += 0.125
	# Alter and retain caller-owned scan outputs; none is an argument to the next admission.
	retained_ids.clear()
	scratch_ids.assign(property._identities)
	scratch_nodes.clear()
	var scratch_refused: bool = _parity(property, false, false)
	box.size = size
	var scratch_restored: bool = _parity(property, true, true)
	_assert("SCAN-03/scratch_retention", originally_equal and scratch_refused and scratch_restored,
		"Retained or edited scratch identity arrays cannot authorize a later admission")


func _resource_scans() -> void:
	var root: Node = Node.new()
	var branch: Resource = Resource.new()
	var leaf: Resource = Resource.new()
	branch.set_meta("leaf", leaf)
	root.set_meta("first", [branch, branch, leaf])
	_assert("SCAN-02/array_sharing", _scan_matches(root,
		[branch, leaf, branch, leaf], [[root, true]]),
		"Repeated array resources append before seen; each per-property graph descends once")
	root.set_meta("first", {"a": branch, "b": branch, "c": leaf})
	_assert("SCAN-02/dictionary_sharing", _scan_matches(root,
		[branch, leaf, branch, leaf], [[root, true]]),
		"Dictionary values retain their exact old depth-first identity order")
	root.set_meta("first", branch)
	root.set_meta("second", branch)
	_assert("SCAN-02/property_sharing", _scan_matches(root,
		[branch, leaf, branch, leaf], [[root, true]]),
		"Sharing across stored metadata properties resets the seen set for each property")
	root.remove_meta("second")
	branch.remove_meta("leaf")
	branch.set_meta("self", branch)
	_assert("SCAN-02/self_cycle", _scan_matches(root, [branch, branch], [[root, true]]),
		"A native Resource metadata self-cycle terminates after appending the repeated identity")
	branch.remove_meta("self")
	branch.set_meta("next", leaf)
	leaf.set_meta("next", branch)
	_assert("SCAN-02/mutual_cycle", _scan_matches(root,
		[branch, leaf, branch], [[root, true]]),
		"A native Resource metadata mutual cycle terminates with the exact original order")
	# Break all resource cycles before dropping the fixtures.
	branch.remove_meta("next")
	leaf.remove_meta("next")
	root.free()


func _scripted_resources(property: StadiumNpcYardTwoPropertyV1) -> void:
	var root: Node = Node.new()
	var child: Node = Node.new()
	root.add_child(child)
	var first: StoredGetter = StoredGetter.new()
	var last: StoredGetter = StoredGetter.new()
	first.payload = Resource.new()
	last.payload = Resource.new()
	var tail: Resource = Resource.new()
	root.set_meta("first", [first, first, tail])
	child.set_meta("last", last)
	first.reads = 0
	last.reads = 0
	var old_ids: Array = Oracle.identities(root)
	var old_reads: Array = [first.reads, last.reads]
	first.reads = 0
	last.reads = 0
	var ids: Array = []
	var nodes: Array = []
	G._collect_live(root, ids, nodes)
	var new_reads: Array = [first.reads, last.reads]
	var old_policies: Array = []
	var new_policies: Array = []
	var old_policy: bool = Oracle._policy_data(root, old_policies)
	var new_policy: bool = G._live_policy_data(nodes, new_policies)
	# Native get_parent() returns OBJECT-null; literal null is NIL inside strict Array equality.
	var expected_parent: Node = root.get_parent()
	var expected_parent_is_detached: bool = expected_parent == null \
		and typeof(expected_parent) == TYPE_OBJECT
	var expected: Array = [[root, expected_parent, null], [first, first.get_script()],
		[first.payload, null], [first, first.get_script()], [tail, null],
		[child, root, null], [last, last.get_script()], [last.payload, null]]
	var policies_do_not_read: bool = [first.reads, last.reads] == new_reads
	property.construction.set_meta("scan_first", [first, first, tail])
	property.construction.set_meta("scan_last", last)
	first.reads = 0
	last.reads = 0
	var full_old_ids: Array = Oracle.identities(property.construction)
	var full_old_reads: Array = [first.reads, last.reads]
	first.reads = 0
	last.reads = 0
	var full_new: bool = G.intact(property)
	var full_new_reads: Array = [first.reads, last.reads]
	property.construction.remove_meta("scan_first")
	property.construction.remove_meta("scan_last")
	_assert("SCAN-02/scripted_getters", ids == old_ids and ids == expected
		and old_reads == [1, 1] and new_reads == old_reads
		and nodes == [[root, false], [child, false]] and not old_policy and not new_policy
		and policies_do_not_read and full_old_ids != property._identities
		and not full_new and full_old_reads == old_reads and full_new_reads == full_old_reads
		and expected_parent_is_detached,
		"Script refusal never truncates later stored getters, resources or child identities")
	var seen: Array[int] = [first.get_instance_id()]
	var repeated: Array = []
	var old_repeat: bool = StadiumNpcYardThreeInstalledGeometryV1._resources(first, seen)
	var new_repeat: bool = G._live_resources(first, repeated, seen)
	_assert("SCAN-02/script_before_seen", not old_repeat and not new_repeat
		and repeated == [[first, first.get_script()]] and first.reads == 1,
		"Script rejection and the repeated identity append precede the seen-resource guard")
	root.free()


func _installed_scan() -> void:
	# Each rejected installed mutation consumes its own lifetime.
	_installed_mutation(false)
	_installed_mutation(true)
	_decorative_scope()
	var lab: PitchBatLab = _lab()
	var original: Dictionary = _snapshot(lab)
	var installed: bool = R.install(lab)
	_assert("SCAN-04/install", installed and R.installed(lab),
		"A fresh clean property passes complete callback admission")
	if not installed:
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var body: StaticBody3D = property.receiver.chair.get_node("Collision/ST079_BACK")
	var shape: CollisionShape3D = body.get_child(0)
	_presentation_scans(lab, property, shape.shape)
	_assert("SCAN-04/teardown", R.teardown(lab) and original == _snapshot(lab)
		and not is_instance_valid(property), "Clean teardown restores the original lab exactly")
	var reinstalled: bool = R.install(lab)
	_assert("SCAN-04/reinstall", reinstalled and R.installed(lab),
		"A clean new property lifetime installs without retained live-scan authority")
	if reinstalled:
		_assert("SCAN-04/reinstall_teardown", R.teardown(lab) and original == _snapshot(lab),
			"The replacement lifetime also tears down to the exact original snapshot")
	lab.free()


func _installed_mutation(nested: bool) -> void:
	var lab: PitchBatLab = _lab()
	var installed: bool = R.install(lab)
	if not installed:
		_failures += 1
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	if nested:
		lab._pitch_actor.trace_sampled.connect(_strict_trace)
	var accepted: bool = property.callback_intact()
	if nested:
		accepted = accepted and not property.hot_eligible() and not property.ordinary_callbacks()
	var chair: Node3D = property.receiver.chair
	var body: StaticBody3D = chair.get_node("Collision/ST079_BACK")
	var shape: CollisionShape3D = body.get_child(0)
	var box: BoxShape3D = shape.shape
	var size: Vector3 = box.size
	var mesh: MeshInstance3D = chair.get_node("Visual/ST079_BACK")
	var material: StandardMaterial3D = mesh.material_override
	var original_next: Material = material.next_pass
	if nested:
		material.next_pass = StandardMaterial3D.new()
	else:
		box.size.x += 0.125
	var parity: bool = _parity(property, false, false)
	var callback: bool = property.callback_intact()
	print("INSTALLED_MUTATION_DIAGNOSTIC ", JSON.stringify({"nested": nested,
		"accepted": accepted, "parity": parity, "callback": callback,
		"phase": property.phase, "reason": property._retirement_reason}))
	var id: String = "callback_nested" if nested else "callback_shape"
	_assert("SCAN-04/" + id, accepted and parity and not callback
		and property.contact_identity(body).is_empty()
		and property.clip(Vector3.ZERO, Vector3(1, 0, 1)) == Vector3.ZERO,
		"Fresh accepted lifetime rejects its first applied mutation and contact/clip entry")
	if nested:
		material.next_pass = original_next
	else:
		box.size = size
	_assert("SCAN-04/" + ("callback_nested_restore" if nested else "callback_restore"),
		not property.callback_intact() and property.phase == &"retired"
		and property.contact_identity(body).is_empty()
		and lab.has_meta("stadium_npc_runtime_interrupted"),
		"Restoring live data cannot revive interrupted installed callback authority")
	lab.free()


func _strict_trace(_point: Vector3) -> void:
	pass


func _decorative_scope() -> void:
	var lab: PitchBatLab = _lab()
	if not R.install(lab):
		_failures += 1
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var accepted: bool = property.callback_intact() and property.hot_eligible()
	var material: StandardMaterial3D = property.receiver.chair.get_node(
		"Visual/ST079_BACK").material_override
	var original_next: Material = material.next_pass
	material.next_pass = StandardMaterial3D.new()
	var parity: bool = _parity(property, false, false)
	var hot_admitted: bool = property.callback_intact()
	print("DECORATIVE_HOT_DIAGNOSTIC ", JSON.stringify({"admitted": hot_admitted}))
	_assert("SCAN-04/decorative_prerequisite", accepted and parity,
		"Fresh ordinary owner accepts before edit; canonical scans reject changed decoration")
	var refused: bool = not R.installed(lab)
	material.next_pass = original_next
	_assert("SCAN-04/decorative_cold", refused and _parity(property, true, true)
		and not property.callback_intact() and property.phase == &"retired"
		and lab.has_meta("stadium_npc_runtime_interrupted"),
		"Explicit cold audit rejects nested material; exact raw restoration cannot revive authority")
	lab.free()


func _actor_sample(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> Array:
	var rows: Array = []
	for row: Array in Proof.actor_materials(lab):
		rows.append([row[0], StadiumNpcRetainedGeometry._resource(row[1]), row[2]])
	return [rows, property.actor_cutaway.last_hits.duplicate(true)]


func _presentation_scans(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1,
	_box: BoxShape3D) -> void:
	var state: BallPlayState = lab._ball_play_resolver.state
	lab._ball_play_resolver.state = BallPlayState.new()
	var rows: Array = Proof.actor_materials(lab)
	var pose: Transform3D = lab._camera.global_transform
	var faded: bool = Proof.fade_actual(lab, property)
	var camera_sample: Array = _actor_sample(lab, property)
	_assert("SCAN-04/presentation_positive", faded and not Proof.actor_same(rows)
		and lab._ball_in_play_is_live() and property.callback_intact(),
		"The public camera control genuinely fades actual actor materials during a live ball")
	property.restore_presentations()
	var before_property: bool = Proof.actor_same(rows)
	property.refresh_receiver_presentation(lab, true)
	_assert("SCAN-04/property_inline", before_property and not Proof.actor_same(rows)
		and _actor_sample(lab, property) == camera_sample and property.callback_intact(),
		"Exact native-lab property inline effects equal the independently guarded camera path")
	property.restore_presentations()
	var before_actor: bool = Proof.actor_same(rows)
	property.actor_presentation._process(0.0)
	_assert("SCAN-04/actor_inline", before_actor and not Proof.actor_same(rows)
		and _actor_sample(lab, property) == camera_sample and property.callback_intact(),
		"Exact native-lab actor inline effects equal the independently guarded camera path")
	_clean_fade(lab, property, pose)
	lab._ball_play_resolver.state = state
	for entry: String in ["camera", "actor", "property", "receiver"]:
		_assert("SCAN-04/" + entry + "_refusal", _presentation_refusal(entry),
			"Fresh direct entry rejects mutation, restores actual fades and stays retired")


func _presentation_refusal(entry: String) -> bool:
	var lab: PitchBatLab = _lab()
	if not R.install(lab):
		lab.free()
		return false
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var body: StaticBody3D = property.receiver.chair.get_node("Collision/ST079_BACK")
	var shape: CollisionShape3D = body.get_child(0)
	var box: BoxShape3D = shape.shape
	lab._ball_play_resolver.state = BallPlayState.new()
	var rows: Array = Proof.actor_materials(lab)
	var pose: Transform3D = lab._camera.global_transform
	var size: Vector3 = box.size
	var accepted: bool = property.callback_intact()
	var faded: bool = Proof.fade_actual(lab, property) and not Proof.actor_same(rows)
	box.size.x += 0.125
	match entry:
		"camera":
			property.camera.refresh_actor_cutaway(lab._camera, true)
		"actor":
			property.actor_presentation._process(0.0)
		"property":
			property.refresh_actor_presentation(lab)
		"receiver":
			property.refresh_receiver_presentation(lab, true)
	var refused: bool = not property.callback_intact() and Proof.actor_same(rows)
	box.size = size
	var retired: bool = not property.callback_intact() and property.phase == &"retired"
	_clean_fade(lab, property, pose)
	lab.free()
	return accepted and faded and refused and retired


func _clean_fade(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1,
	pose: Transform3D) -> void:
	property.restore_presentations()
	var ball: BattedBallBody = lab._batted_ball
	lab._cleanup_batted_ball()
	if is_instance_valid(ball):
		ball.free()
	lab._camera.global_transform = pose
	property.camera.set_shot(MatchCameraDirector.Shot.BATTING)


func _virtual_lab_scan() -> void:
	var lab: MutatingLab = MutatingLab.new()
	lab._sky_backdrop_enabled = false
	lab.set_meta("stadium_npc_retained_lab_only", true)
	lab.set_meta("stadium_npc_ay02_installed_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var original: Dictionary = _snapshot(lab)
	var installed: bool = R.install(lab)
	if not installed:
		_failures += 1
		push_error("AY02 live scan subclass lab must first install")
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var body: StaticBody3D = property.receiver.chair.get_node("Collision/ST079_BACK")
	var shape: CollisionShape3D = body.get_child(0)
	lab.target = shape.shape as BoxShape3D
	var size: Vector3 = lab.target.size
	var state: BallPlayState = lab._ball_play_resolver.state
	lab._ball_play_resolver.state = BallPlayState.new()
	var rows: Array = Proof.actor_materials(lab)
	var pose: Transform3D = lab._camera.global_transform
	var faded: bool = Proof.fade_actual(lab, property) and not Proof.actor_same(rows)
	var before: bool = property.callback_intact() and lab._ball_in_play_is_live()
	lab.armed = true
	property.refresh_receiver_presentation(lab, true)
	var refused: bool = not property.callback_intact()
	var materials_restored: bool = Proof.actor_same(rows)
	var mutated: bool = lab.mutations == 1 and not lab.armed and lab.target.size != size
	lab.target.size = size
	var restored: bool = not property.callback_intact() and property.phase == &"retired"
	_assert("SCAN-04/virtual_lab_fallback", before and faded and mutated and refused
		and materials_restored and restored,
		"Virtual mutation crosses fallback revalidation and restoration cannot revive authority")
	_clean_fade(lab, property, pose)
	lab._ball_play_resolver.state = state
	var quarantined: bool = lab.has_meta("stadium_npc_runtime_interrupted") \
		and property.phase == &"retired" and not R.install(lab)
	lab.free()
	# Preserve exact subclass teardown on a separate clean subclass lifetime.
	var clean: MutatingLab = MutatingLab.new()
	clean._sky_backdrop_enabled = false
	clean.set_meta("stadium_npc_retained_lab_only", true)
	clean.set_meta("stadium_npc_ay02_installed_lab_only", true)
	add_child(clean)
	clean.set_process(false)
	clean.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(clean)
	var clean_original: Dictionary = _snapshot(clean)
	var clean_installed: bool = R.install(clean)
	_assert("SCAN-04/virtual_lab_teardown", quarantined and clean_installed
		and R.installed(clean) and R.teardown(clean) and clean_original == _snapshot(clean),
		"Rejected subclass stays quarantined; separate clean subclass tears down exactly")
	clean.free()


func _stored_names(value: Object) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in value.get_property_list():
		if item.name != "script" and int(item.usage) & PROPERTY_USAGE_STORAGE != 0:
			result.append(item.name)
	return result


func _schema_eligible() -> void:
	var previous: Variant = ProjectSettings.get_setting(LIGHT_UNITS)
	var first: StandardMaterial3D = StandardMaterial3D.new()
	var second: StandardMaterial3D = StandardMaterial3D.new()
	second.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	first.resource_name = "identity-only-first"
	second.resource_name = "identity-only-second"
	second.resource_local_to_scene = true
	var schemas: Dictionary = {}
	var okay: bool = true
	for physical: bool in [false, true]:
		ProjectSettings.set_setting(LIGHT_UNITS, physical)
		var names: Variant = StadiumNpcRetainedGeometry._ordinary_stored_names(first, schemas)
		var shared: Variant = StadiumNpcRetainedGeometry._ordinary_stored_names(second, schemas)
		okay = names is Array and shared is Array and okay
		if names is Array and shared is Array:
			okay = names.is_read_only() and is_same(names, shared) \
				and is_same(names, schemas[physical]) and names == _stored_names(first) \
				and shared == _stored_names(second) and names.has("resource_name") \
				and names.has("resource_local_to_scene") \
				and names.has("emission_intensity") == physical and okay
	_assert("SCHEMA-01/eligible", okay and schemas.size() == 2
		and schemas[false] != schemas[true],
		"Both exact native transparency modes reuse immutable ordered names for each fresh key")
	ProjectSettings.set_setting(LIGHT_UNITS, previous)
	var root: Node = Node.new()
	first.next_pass = second
	root.set_meta("first", [first, first, {"second": second}])
	root.set_meta("second", first)
	var old: Array = Oracle.identities(root)
	var ids: Array = []
	var nodes: Array = []
	var fresh: Dictionary = {}
	G._collect_live(root, ids, nodes, fresh)
	var resources: Array = []
	for row: Array in ids:
		if row[0] is Resource:
			resources.append(row[0])
	# The self-cycle is metadata on the fallback branch; never send a cycle to _geometry.
	second.set_meta("cycle", second)
	var old_cycle: Array = Oracle.identities(root)
	var cycle_ids: Array = []
	var cycle_nodes: Array = []
	G._collect_live(root, cycle_ids, cycle_nodes, {})
	second.remove_meta("cycle")
	_assert("SCHEMA-01/identity", ids == old and nodes == [[root, true]] and fresh.size() == 1
		and resources == [first, second, first, second, first, second]
		and cycle_ids == old_cycle and cycle_nodes == nodes,
		"Scoped identity traversal preserves shared occurrences, dictionary order and property cycles")
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.material_override = first
	mesh_node.material_overlay = second
	mesh_node.mesh = BoxMesh.new()
	mesh_node.mesh.surface_set_material(0, second)
	mesh_node.set_surface_override_material(0, first)
	root.add_child(mesh_node)
	var plain: Dictionary = StadiumNpcRetainedGeometry._geometry(root)
	var geometry_schemas: Dictionary = {}
	var scoped: Dictionary = StadiumNpcRetainedGeometry._geometry(root, geometry_schemas)
	var stored: Dictionary = StadiumNpcRetainedGeometry._stored(first, {})
	_assert("SCHEMA-01/content", var_to_bytes(scoped) == var_to_bytes(plain)
		and geometry_schemas.size() == 1
		and var_to_bytes(stored) == var_to_bytes(StadiumNpcRetainedGeometry._stored(first))
		and not stored.has("resource_name") and not stored.has("resource_local_to_scene"),
		"Scoped geometry retains exact fresh content and its distinct identity-only name exclusions")
	root.free()


func _fallback_matches(value: Resource) -> bool:
	var schemas: Dictionary = {}
	var selected: Variant = StadiumNpcRetainedGeometry._ordinary_stored_names(value, schemas)
	var old: Array = []
	Oracle._resources(value, old, [])
	var ids: Array = []
	var valid: bool = G._live_resources(value, ids, [], schemas)
	var plain: Dictionary = StadiumNpcRetainedGeometry._stored(value)
	var scoped: Dictionary = StadiumNpcRetainedGeometry._stored(value, schemas)
	return selected == null and ids == old and valid == (value.get_script() == null) \
		and var_to_bytes(plain) == var_to_bytes(scoped)


func _schema_fallbacks() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var okay: bool = true
	for mode: int in [BaseMaterial3D.BILLBOARD_ENABLED, BaseMaterial3D.BILLBOARD_FIXED_Y,
		BaseMaterial3D.BILLBOARD_PARTICLES]:
		material.billboard_mode = mode
		okay = _fallback_matches(material) and okay
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	for mode: int in [BaseMaterial3D.SHADING_MODE_UNSHADED, BaseMaterial3D.SHADING_MODE_PER_VERTEX]:
		material.shading_mode = mode
		okay = _fallback_matches(material) and okay
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for mode: int in [BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,
		BaseMaterial3D.TRANSPARENCY_ALPHA_HASH, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]:
		material.transparency = mode
		okay = _fallback_matches(material) and okay
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.heightmap_deep_parallax = true
	okay = _fallback_matches(material) and okay
	material.heightmap_deep_parallax = false
	material.set_flag(BaseMaterial3D.FLAG_SUBSURFACE_MODE_SKIN, true)
	okay = _fallback_matches(material) and okay
	material.set_flag(BaseMaterial3D.FLAG_SUBSURFACE_MODE_SKIN, false)
	var previous: Variant = ProjectSettings.get_setting(LIGHT_UNITS)
	ProjectSettings.set_setting(LIGHT_UNITS, 0)
	okay = _fallback_matches(material) and okay
	ProjectSettings.set_setting(LIGHT_UNITS, previous)
	_assert("SCHEMA-02/selectors", okay,
		"Every excluded selector and unexpected light-unit type uses the exact reflective traversal")
	material.set_meta("nested", Resource.new())
	var scripted: SchemaGetter = SchemaGetter.new()
	scripted.payload = Resource.new()
	var old_events: Array = []
	scripted.events = old_events
	var old_ids: Array = []
	Oracle._resources(scripted, old_ids, [])
	var new_events: Array = []
	scripted.events = new_events
	var ids: Array = []
	var schemas: Dictionary = {}
	var valid: bool = G._live_resources(scripted, ids, [], schemas)
	_assert("SCHEMA-02/types_scripts_metadata", _fallback_matches(material)
		and _fallback_matches(ShaderMaterial.new()) and _fallback_matches(ORMMaterial3D.new())
		and _fallback_matches(Resource.new()) and not valid and ids == old_ids
		and old_events == ["nested"] and new_events == old_events and schemas.is_empty(),
		"Metadata, unknown native classes and scripted materials retain ordered fallback getters")
	material.remove_meta("nested")
	var null_names: Variant = StadiumNpcRetainedGeometry._ordinary_stored_names(material, null)
	var legacy_ids: Array = []
	var explicit_ids: Array = []
	var legacy: bool = G._live_resources(material, legacy_ids, [])
	var explicit: bool = G._live_resources(material, explicit_ids, [], null)
	_assert("SCHEMA-02/default_scope", null_names == null and legacy and explicit
		and legacy_ids == explicit_ids
		and var_to_bytes(StadiumNpcRetainedGeometry._stored(material)) == var_to_bytes(
			StadiumNpcRetainedGeometry._stored(material, null)),
		"Default and explicit-null calls preserve the original non-scoped paths")


func _schema_mutation_pair(kind: String) -> Array:
	var previous: Variant = ProjectSettings.get_setting(LIGHT_UNITS)
	var root: Node = Node.new()
	var current: StandardMaterial3D = StandardMaterial3D.new()
	var later: StandardMaterial3D = StandardMaterial3D.new()
	var trigger: SchemaGetter = SchemaGetter.new()
	trigger.payload = Resource.new()
	current.next_pass = trigger
	root.set_meta("first", current)
	root.set_meta("later", later)
	root.set_meta("again", current)
	var observer: MaterialReads = MaterialReads.new()
	var observer_script: Script = observer.get_script()
	var samples: Array = []
	# Reuse the exact objects, resetting every mutation before the independent old/new walks.
	for scoped: bool in [false, true]:
		current.set_script(null)
		current.remove_meta("nested")
		current.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		later.remove_meta("nested")
		later.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		ProjectSettings.set_setting(LIGHT_UNITS, false)
		var events: Array = []
		trigger.events = events
		var snapshot_names: Array[String] = _stored_names(current)
		trigger.action = func() -> void:
			events.append("mutate:" + kind)
			match kind:
				"later":
					later.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					later.set_meta("nested", trigger.payload)
				"key":
					ProjectSettings.set_setting(LIGHT_UNITS, true)
				"current":
					current.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					current.set_meta("nested", trigger.payload)
				"script":
					if current.get_script() == null:
						current.set_script(observer_script)
						current.set("events", events)
		var schemas: Dictionary = {}
		var ids: Array = []
		var nodes: Array = []
		if scoped:
			G._collect_live(root, ids, nodes, schemas)
		else:
			ids = Oracle.identities(root)
		samples.append({"root": root, "rows": ids, "events": events.duplicate(),
			"node_valid": nodes[0][1] if scoped else false, "schemas": schemas,
			"snapshot": snapshot_names, "current_names": _stored_names(current)})
	trigger.action = Callable()
	current.next_pass = null
	current.set_script(null)
	current.remove_meta("nested")
	later.remove_meta("nested")
	ProjectSettings.set_setting(LIGHT_UNITS, previous)
	return samples

func _schema_mutations() -> void:
	var pair: Array = _schema_mutation_pair("later")
	var old: Dictionary = pair[0]
	var fresh: Dictionary = pair[1]
	_assert("SCHEMA-03/later_selector", fresh.rows == old.rows and fresh.events == old.events
		and fresh.events == ["nested", "mutate:later", "nested", "mutate:later"]
		and not fresh.node_valid and fresh.schemas.size() == 1,
		"A nested getter changes a later material before its fresh schema eligibility check")
	old.root.free()
	pair = _schema_mutation_pair("key")
	old = pair[0]
	fresh = pair[1]
	_assert("SCHEMA-03/fresh_key", fresh.rows == old.rows and fresh.events == old.events
		and not fresh.node_valid and fresh.schemas.size() == 2
		and not fresh.schemas[false].has("emission_intensity")
		and fresh.schemas[true].has("emission_intensity"),
		"One identity scan re-reads changed physical light units and holds both exact name schemas")
	old.root.free()
	pair = _schema_mutation_pair("current")
	old = pair[0]
	fresh = pair[1]
	_assert("SCHEMA-03/current_snapshot", fresh.rows == old.rows and fresh.events == old.events
		and fresh.snapshot != fresh.current_names and not fresh.node_valid
		and fresh.schemas.size() == 1,
		"Containing-material changes keep entry-time names while its next occurrence reflects anew")
	old.root.free()
	pair = _schema_mutation_pair("script")
	old = pair[0]
	fresh = pair[1]
	_assert("SCHEMA-03/current_script", fresh.rows == old.rows and fresh.events == old.events
		and fresh.events.has("get:roughness") and not fresh.node_valid
		and fresh.schemas.size() == 1,
		"A script attached mid-walk observes every later scalar getter in original order")
	old.root.free()


func _schema_admissions() -> void:
	var property: StadiumNpcYardTwoPropertyV1 = R._construct(null)
	var chair: Node3D = property.objects[P + "RECEIVER-PRIMARY"]
	var mesh: MeshInstance3D = chair.get_node("Visual/ST079_BACK")
	var material: StandardMaterial3D = mesh.material_override
	var roughness: float = material.roughness
	var accepted: bool = _parity(property, true, true)
	material.roughness = 0.33
	var refused: bool = _parity(property, false, false)
	material.roughness = roughness
	var restored: bool = _parity(property, true, true)
	_assert("SCHEMA-04/fresh_admission", accepted and refused and restored,
		"Fresh scoped admissions reject and restore same-turn material values without retained success")
	var scratch: Dictionary = {}
	var names: Variant = StadiumNpcRetainedGeometry._ordinary_stored_names(material, scratch)
	var immutable: bool = names is Array and names.is_read_only() and scratch.size() == 1
	# Only a mutable copy can be edited; external scratch is never accepted by intact().
	var copy: Array = names.duplicate() if names is Array else []
	copy.clear()
	scratch.clear()
	scratch[false] = copy
	material.roughness = 0.33
	var scratch_refused: bool = _parity(property, false, false)
	material.roughness = roughness
	var scratch_restored: bool = _parity(property, true, true)
	_assert("SCHEMA-04/scratch_names", immutable and scratch_refused and scratch_restored,
		"Retained name arrays and edited caller scratch cannot authorize the next admission")
	property.free()
