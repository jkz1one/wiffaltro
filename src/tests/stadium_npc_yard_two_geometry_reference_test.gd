extends "res://src/tests/stadium_npc_yard_two_runtime_test.gd"
## Supplemental R6 differential regression. The inherited original suites remain untouched.
# gdlint: disable=max-file-lines

const G = preload("res://src/presentation/stadium/stadium_npc_yard_two_installed_geometry_v1.gd")
const REQUIRED: Array[String] = [
	"REF-01/plain",
	"REF-01/immutable",
	"REF-01/decoded_copy",
	"REF-01/replacement",
	"REF-01/preconfigure_tamper",
	"REF-02/configured",
	"REF-02/shape_content",
	"REF-02/shape_identity",
	"REF-02/mesh_identity",
	"REF-02/mesh_content",
	"REF-02/material_identity",
	"REF-02/material_content",
	"REF-02/process_priority",
	"REF-02/physics_priority",
	"REF-02/field_content",
	"REF-02/restored",
	"REF-01/freed_snapshot",
	"REF-03/visible",
	"REF-03/hidden",
	"REF-03/faded",
	"REF-03/color_tamper",
	"REF-03/shadow_tamper",
	"REF-03/visibility_tamper",
	"REF-03/state_tamper",
	"REF-04/install",
	"REF-04/genuine_rock",
	"REF-04/rock_tamper",
	"REF-04/rock_restored",
	"REF-04/teardown",
	"REF-04/reinstall",
	"REF-04/distinct_cache",
	"REF-04/reinstall_teardown",
]


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		push_error("AY02 geometry reference requires no user arguments")
		get_tree().quit(2)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detached_reference()
	_lazy_mesh_reentrancy()
	await _installed_reference()
	await TestAudioDrain.finish(get_tree())
	var required: Array[String] = REQUIRED.duplicate()
	required.append("SCHEMA-REF/lazy_reentrant")
	for id: String in required:
		if not _seen.has(id) or _seen[id].size() != 1:
			_failures += 1
	for id: String in _seen:
		if not required.has(id):
			_failures += 1
	print("AY02_CASE_REPORT ", JSON.stringify({"schema": "ay02-reconstructed-cases-v1",
		"scene": "geometry_reference", "required": required, "assertions": _seen,
		"failures": _failures, "rendered_qualification": false}))
	if _failures == 0:
		print("AY02_GEOMETRY_REFERENCE_PASS")
	get_tree().quit(0 if _failures == 0 else 1)


func _equivalent(property: StadiumNpcYardTwoPropertyV1, accepted: bool) -> bool:
	return _fresh_same(property) == accepted and G.same(property) == accepted


func _immutable(value: Variant) -> bool:
	if value is Dictionary:
		if not value.is_read_only():
			return false
		for item: Variant in value.values():
			if not _immutable(item):
				return false
		return true
	return typeof(value) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]


func _detached_reference() -> void:
	var property: StadiumNpcYardTwoPropertyV1 = R._construct(null)
	var frozen: Dictionary = property._geometry_reference
	_assert("REF-01/plain", _equivalent(property, true) and property.geometry_intact(),
		"Independent plain snapshot matches the untouched fresh-reference oracle")
	_assert("REF-01/immutable", _immutable(frozen),
		"Every cached container is read-only and every leaf is an immutable scalar")
	var decoded: PackedByteArray = frozen.plain.geometry.hex_decode()
	decoded[0] = decoded[0] ^ 1
	var chair_copy: Dictionary = bytes_to_var(frozen.plain.chair.hex_decode())
	chair_copy.transform.origin.x = 1
	_assert("REF-01/decoded_copy", decoded.hex_encode() != frozen.plain.geometry
		and var_to_bytes(chair_copy).hex_encode() != frozen.plain.chair
		and _equivalent(property, true), "Mutable decoded copies cannot poison cached authority")
	var poison: Dictionary = {"plain": {"geometry": "poison"}, "configured": {}}
	property.set("_geometry_reference", poison)
	_assert("REF-01/replacement", is_same(property._geometry_reference, frozen)
		and _equivalent(property, true), "Object.set cannot replace the initialized authority")
	property.construction.position.x = 0.125
	_assert("REF-01/preconfigure_tamper", _equivalent(property, false),
		"Mutating the detached construction cannot redefine the independent baseline")
	property.construction.position.x = 0
	var configured: bool = R._bind_components(null, property)
	_assert("REF-02/configured", configured and is_same(property._geometry_reference, frozen)
		and _equivalent(property, true) and property.geometry_intact(),
		"Receiver configuration selects the independent configured snapshot without repinning")
	var chair: Node3D = property.objects[P + "RECEIVER-PRIMARY"]
	var mesh: MeshInstance3D = chair.get_node("Visual/ST079_BACK")
	var body: StaticBody3D = chair.get_node("Collision/ST079_BACK")
	var shape: CollisionShape3D = body.get_child(0)
	var box: BoxShape3D = shape.shape
	var size: Vector3 = box.size
	box.size.x = Proof.next_f32(box.size.x)
	_assert("REF-02/shape_content", _equivalent(property, false) and not property.geometry_intact(),
		"One-ULP live collider change refuses after cache creation")
	box.size = size
	var original_shape: Shape3D = shape.shape
	shape.shape = original_shape.duplicate(true)
	_assert("REF-02/shape_identity", _equivalent(property, true) and not property.geometry_intact(),
		"Equal shape content still fails the unchanged resource-identity join")
	shape.shape = original_shape
	var original_mesh: Mesh = mesh.mesh
	mesh.mesh = original_mesh.duplicate(true)
	_assert("REF-02/mesh_identity", _equivalent(property, true) and not property.geometry_intact(),
		"Equal mesh replacement cannot inherit the original resource identity")
	mesh.mesh = original_mesh
	var box_mesh: BoxMesh = mesh.mesh as BoxMesh
	var mesh_size: Vector3 = box_mesh.size
	# The one-ULP BoxMesh request is a diagnosed setter no-op; prove an applied change.
	var mesh_base_old: bool = _fresh_same(property)
	var mesh_base: Dictionary = StadiumNpcRetainedGeometry._mesh(box_mesh)
	var mesh_base_bytes: PackedByteArray = var_to_bytes(mesh_base)
	var mesh_base_arrays: PackedByteArray = var_to_bytes(mesh_base.surfaces[0].arrays)
	var mesh_base_bounds: PackedByteArray = var_to_bytes(mesh_base.aabb)
	var mesh_base_new: bool = G.same(property)
	var mesh_base_stable: bool = (
		var_to_bytes(StadiumNpcRetainedGeometry._mesh(box_mesh)) == mesh_base_bytes)
	var mesh_requested: Vector3 = mesh_size
	mesh_requested.x += 0.125
	box_mesh.size = mesh_requested
	var mesh_applied_size: PackedByteArray = var_to_bytes(box_mesh.size)
	# Eager calls keep either comparator from hiding the other's result.
	var mesh_applied_old: bool = _fresh_same(property)
	var mesh_applied: Dictionary = StadiumNpcRetainedGeometry._mesh(box_mesh)
	var mesh_applied_bytes: PackedByteArray = var_to_bytes(mesh_applied)
	var mesh_applied_new: bool = G.same(property)
	var mesh_applied_stable: bool = (
		var_to_bytes(StadiumNpcRetainedGeometry._mesh(box_mesh)) == mesh_applied_bytes)
	box_mesh.size = mesh_size
	var mesh_restored_size: PackedByteArray = var_to_bytes(box_mesh.size)
	var mesh_restored_old: bool = _fresh_same(property)
	var mesh_restored_bytes: PackedByteArray = (
		var_to_bytes(StadiumNpcRetainedGeometry._mesh(box_mesh)))
	var mesh_restored_new: bool = G.same(property)
	var mesh_restored_stable: bool = (
		var_to_bytes(StadiumNpcRetainedGeometry._mesh(box_mesh)) == mesh_restored_bytes)
	_assert("REF-02/mesh_content", mesh_base_old and mesh_base_new and mesh_base_stable
		and mesh_applied_size == var_to_bytes(mesh_requested)
		and mesh_applied_size != var_to_bytes(mesh_size)
		and mesh_applied_bytes != mesh_base_bytes
		and var_to_bytes(mesh_applied.surfaces[0].arrays) != mesh_base_arrays
		and var_to_bytes(mesh_applied.aabb) != mesh_base_bounds
		and not mesh_applied_old and not mesh_applied_new and mesh_applied_stable
		and mesh_restored_size == var_to_bytes(mesh_size)
		and mesh_restored_bytes == mesh_base_bytes
		and mesh_restored_old and mesh_restored_new and mesh_restored_stable,
		"Applied mesh arrays and bounds reject; exact authored and sampled restore accepts")
	var material: StandardMaterial3D = mesh.material_override
	mesh.material_override = material.duplicate(true)
	_assert("REF-02/material_identity", _equivalent(property, true)
		and not property.geometry_intact(), "Equal material replacement remains identity-invalid")
	mesh.material_override = material
	var roughness: float = material.roughness
	material.roughness = 0.33
	_assert("REF-02/material_content", _equivalent(property, false),
		"Live stored material values are never replaced with cached values")
	material.roughness = roughness
	body.process_priority = 1
	_assert("REF-02/process_priority", _equivalent(property, false),
		"Current live ordinary process priority remains exact")
	body.process_priority = 0
	body.process_physics_priority = 1
	_assert("REF-02/physics_priority", _equivalent(property, false),
		"Current live physics priority remains exact")
	body.process_physics_priority = 0
	var old_field: float = property.field.back_wall_z_m
	property.field.back_wall_z_m += 0.125
	_assert("REF-02/field_content", _equivalent(property, false),
		"Typed field comparisons use the independent construction values")
	property.field.back_wall_z_m = old_field
	_style_equivalence(property, chair)
	_assert("REF-02/restored", _equivalent(property, true) and property.geometry_intact(),
		"Restoring genuine data restores positive full geometry validation")
	property.free()
	_assert("REF-01/freed_snapshot", _immutable(frozen),
		"A retained snapshot alias after property destruction contains no native object or resource")


func _style_equivalence(property: StadiumNpcYardTwoPropertyV1, chair: Node3D) -> void:
	property._style_state = "visible"
	property._style_alpha = 1.0
	StadiumReceiverVisibility._style(chair, false, 1.0)
	_assert("REF-03/visible", _equivalent(property, true), "Visible style matches fresh reproduction")
	property._style_state = "hidden"
	StadiumReceiverVisibility._style(chair, true, 1.0)
	_assert("REF-03/hidden", _equivalent(property, true), "Hidden style matches fresh reproduction")
	property._style_state = "faded"
	property._style_alpha = StadiumReceiverVisibility.FADED_ALPHA
	StadiumReceiverVisibility._style(chair, false, property._style_alpha)
	_assert("REF-03/faded", _equivalent(property, true), "Faded style matches fresh reproduction")
	var mesh: MeshInstance3D = chair.get_node("Visual/ST079_BACK")
	var color: Color = mesh.material_override.albedo_color
	mesh.material_override.albedo_color = Color(color.r + 0.125, color.g, color.b, color.a)
	_assert("REF-03/color_tamper", _equivalent(property, false),
		"Allowed alpha never normalizes a foreign RGB change")
	mesh.material_override.albedo_color = color
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_assert("REF-03/shadow_tamper", _equivalent(property, false),
		"The owned faded shadow policy is compared, not skipped")
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chair.get_node("Visual").visible = false
	_assert("REF-03/visibility_tamper", _equivalent(property, false),
		"The owned visible/faded container visibility remains exact")
	chair.get_node("Visual").visible = true
	chair.set_meta("receiver_render_state", "foreign")
	_assert("REF-03/state_tamper", _equivalent(property, false),
		"The original owned metadata guard still rejects a foreign render state")
	property._style_state = "visible"
	property._style_alpha = 1.0
	StadiumReceiverVisibility._style(chair, false, 1.0)


func _installed_reference() -> void:
	var lab: PitchBatLab = _lab()
	var original: Dictionary = _snapshot(lab)
	var installed: bool = R.install(lab)
	_assert("REF-04/install", installed and R.installed(lab),
		"Fresh installation reaches the unchanged complete callback join")
	if not installed:
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var frozen: Dictionary = property._geometry_reference
	lab._pitch_actor.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._match_state.begin_pitch()
	lab._pitch_actor.start_pitch(Proof.parameters(0.65))
	lab._pitch_actor._physics_process(0.2)
	for frame in range(40):
		await get_tree().create_timer(0.01).timeout
		if property.receiver.contacts.size() == 1:
			break
	var receiver: StadiumNpcYardTwoReceiverV1 = property.receiver
	var rock: Tween = receiver._owned_rock
	var genuine: bool = receiver.contacts.size() == 1 and rock != null and rock.is_valid()
	if genuine:
		rock.pause()
		rock.custom_step(0.07)
	_assert("REF-04/genuine_rock", genuine and not receiver._applied.is_empty()
		and receiver._last_visual != receiver._baseline_visual and _equivalent(property, true)
		and property.callback_intact(), "A genuinely issued non-rest rock matches the old oracle")
	var visual: Node3D = receiver._visual
	var pose: Transform3D = visual.transform
	visual.position.x += 0.125
	_assert("REF-04/rock_tamper", _equivalent(property, false) and not property.callback_intact(),
		"Foreign geometry during an owned rock cannot be normalized away")
	visual.transform = pose
	_assert("REF-04/rock_restored", _equivalent(property, true) and not property.callback_intact()
		and property.phase == &"retired" and lab.has_meta("stadium_npc_runtime_interrupted"),
		"Restored pose cannot revive a retired installed rock lifetime")
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	receiver.cancel_owned()
	# Interruption is sticky; clean teardown/reinstall belong to a separate untouched lab.
	lab.free()
	await get_tree().process_frame
	await _clean_reference_lifetime()


func _clean_reference_lifetime() -> void:
	var lab: PitchBatLab = _lab()
	var original: Dictionary = _snapshot(lab)
	var installed: bool = R.install(lab)
	if not installed:
		_assert("REF-04/teardown", false, "Clean control must install first")
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var frozen: Dictionary = property._geometry_reference
	_assert("REF-04/teardown", R.teardown(lab) and original == _snapshot(lab)
		and not is_instance_valid(property), "Clean teardown frees owner and restores exact originals")
	var reinstalled: bool = R.install(lab)
	_assert("REF-04/reinstall", reinstalled and R.installed(lab),
		"A second clean property installs without stale cache or member authority")
	if reinstalled:
		property = lab.get_meta("stadium_property")
		_assert("REF-04/distinct_cache", not is_same(frozen, property._geometry_reference)
			and frozen == property._geometry_reference and _equivalent(property, true),
			"Reinstall independently rebuilds an equal snapshot with a distinct lifetime")
		_assert("REF-04/reinstall_teardown", R.teardown(lab) and original == _snapshot(lab),
			"Reinstalled property restores exactly without retained reference Nodes")
	lab.free()
	await get_tree().process_frame


# Original R5 function, changed only by its name and qualification of expected().
static func _fresh_same(property: StadiumNpcYardTwoPropertyV1) -> bool:
	if not is_instance_valid(property.construction):
		return false
	var reference: StadiumNpcYardTwoV1 = G.expected(property.receiver_configured)
	var chair: Node3D = reference.objects[StadiumNpcYardTwoV1.PREFIX + "RECEIVER-PRIMARY"]
	var receiver: StadiumNpcYardTwoReceiverV1 = property._owned_receiver()
	var allowed: bool = property.copy_owned_style(chair)
	if property.receiver_configured:
		allowed = allowed and is_instance_valid(receiver) and receiver.copy_owned_rock(chair)
	var result: bool = allowed and StadiumNpcYardThreeInstalledGeometryV1._policies(
		property.construction, reference) and var_to_bytes(
		StadiumNpcRetainedGeometry._geometry(property.construction)) == var_to_bytes(
		StadiumNpcRetainedGeometry._geometry(reference))
	for key: String in StadiumNpcYardV1.FIELD:
		result = result and typeof(property.field.get(key)) == typeof(reference.field.get(key)) \
			and property.field.get(key) == reference.field.get(key)
	result = result and property.field.id == reference.field.id \
		and property.field.display_name == reference.field.display_name
	reference.free()
	return result



func _lazy_mesh_sample(property: StadiumNpcYardTwoPropertyV1, scoped: bool) -> Dictionary:
	var previous: Variant = ProjectSettings.get_setting(
		"rendering/lights_and_shadows/use_physical_light_units")
	ProjectSettings.set_setting("rendering/lights_and_shadows/use_physical_light_units", false)
	var chair: Node3D = property.objects[P + "RECEIVER-PRIMARY"]
	var node: MeshInstance3D = chair.get_node("Visual/ST079_BACK")
	var material: StandardMaterial3D = node.material_override
	var transparency: int = material.transparency
	var lazy: BoxMesh = BoxMesh.new()
	lazy.material = material
	var events: Array = []
	var scope: Dictionary = {}
	# Seed only the old schema before the native pending mesh emits its synchronous signal.
	var seed: Variant = StadiumNpcRetainedGeometry._ordinary_stored_names(material, scope)
	var listener: Callable = func() -> void:
		events.append("changed")
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		ProjectSettings.set_setting("rendering/lights_and_shadows/use_physical_light_units", true)
		var old_full: bool = StadiumNpcYardTwoLiveScanOracle.identities(property.construction) \
			== property._identities and StadiumNpcYardTwoLiveScanOracle.same(property)
		var reentrant: bool = G.intact(property)
		events.append([old_full, reentrant])
	lazy.changed.connect(listener)
	var before: bool = events.is_empty()
	var sample: Dictionary = StadiumNpcRetainedGeometry._mesh(lazy, scope if scoped else null)
	# Native _update clears pending before changed, so this read must not emit a second time.
	var stable: bool = var_to_bytes(sample) == var_to_bytes(
		StadiumNpcRetainedGeometry._mesh(lazy, scope if scoped else null))
	var fallback: bool = StadiumNpcRetainedGeometry._ordinary_stored_names(material, scope) == null
	var ordinary: StandardMaterial3D = StandardMaterial3D.new()
	var names: Variant = StadiumNpcRetainedGeometry._ordinary_stored_names(ordinary, scope)
	lazy.changed.disconnect(listener)
	material.transparency = transparency
	ProjectSettings.set_setting("rendering/lights_and_shadows/use_physical_light_units", previous)
	var restored_old: bool = _fresh_same(property)
	var restored_new: bool = G.intact(property)
	return {"sample": var_to_bytes(sample), "events": events, "before": before,
		"stable": stable, "fallback": fallback, "restored": restored_old and restored_new,
		"seeded": seed is Array and seed.is_read_only(),
		"fresh_key": names is Array and names.has("emission_intensity") and scope.size() == 2}


func _lazy_mesh_reentrancy() -> void:
	var property: StadiumNpcYardTwoPropertyV1 = R._construct(null)
	var old: Dictionary = _lazy_mesh_sample(property, false)
	var scoped: Dictionary = _lazy_mesh_sample(property, true)
	_assert("SCHEMA-REF/lazy_reentrant", old == scoped and scoped.before and scoped.seeded
		and scoped.events == ["changed", [false, false]] and scoped.stable
		and scoped.fallback and scoped.fresh_key and scoped.restored,
		"Native lazy mesh changed preserves fresh material sampling and reentrant guard refusal/restore")
	property.free()
