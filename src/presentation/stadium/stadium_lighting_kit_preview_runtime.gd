class_name StadiumLightingKitPreviewRuntime
extends Node3D
## Explicit, reversible authoring preview only. No season, fixture or inventory authority.
## Property integration must use the narrow hooks in PREVIEW_HOOKS.md.

const KIT = preload("stadium_lighting_kit_models.gd")
const PALETTE = preload("stadium_lighting_kit_night_palette.gd")
const LEASE: StringName = &"st111_lighting_preview_lease"
const GROUP: StringName = &"st111_lighting_preview_leases"

var active: bool = false
var profile: String = ""
var sources: Array[SpotLight3D] = []
var _property: Node3D
var _kit: Node3D
var _poles: Array[Node3D] = []
var _environment: WorldEnvironment
var _sun: DirectionalLight3D
var _viewport: Viewport
var _property_pose: Transform3D
var _objects: Dictionary = {}
var _changes: Array[Dictionary] = []
var _change_index: Dictionary = {}  # Exact node -> field -> the same mutable row as _changes.
var _resources: Array[Dictionary] = []
var _resource_seen: Dictionary = {}
var _external: Array[Dictionary] = []
var _source_environment: Environment
var _working_environment: Environment
var _source_shadows: Dictionary = {}
var _expected_shadows: Dictionary = {}
var _attached: bool = false
var _restoring: bool = false
var _retired: bool = false
var _scope: Array[Node3D] = []
var _palette_profile: String = ""
var _palette_signature: String = ""
var _fixture_owner: WeakRef


static func install(
	property: Node3D,
	environment: WorldEnvironment,
	sun: DirectionalLight3D,
	kit: Node3D,
	rear_poles: Array[Node3D] = [],
	palette_profile: String = PALETTE.BASELINE
) -> StadiumLightingKitPreviewRuntime:
	return _install(property, environment, sun, kit, rear_poles, palette_profile, null)


static func prepare_fixture(
	owner: StadiumSurfaceNightRuntime,
	property: StadiumPropertyGeometry,
	environment: WorldEnvironment,
	sun: DirectionalLight3D,
	kit: Node3D,
	rear_poles: Array[Node3D],
	palette_profile: String
) -> StadiumLightingKitPreviewRuntime:
	if (
		not is_instance_valid(owner)
		or owner.get_script() != StadiumSurfaceNightRuntime
		or not owner._kit_mode
		or owner._phase != StadiumSurfaceNightRuntime.Phase.CONFIGURED
		or owner._property != property
		or property.get_parent() != null
	):
		return null
	return _install(property, environment, sun, kit, rear_poles, palette_profile, owner)


static func _install(
	property: Node3D,
	environment: WorldEnvironment,
	sun: DirectionalLight3D,
	kit: Node3D,
	rear_poles: Array[Node3D],
	palette_profile: String,
	fixture_owner: StadiumSurfaceNightRuntime
) -> StadiumLightingKitPreviewRuntime:
	var fixture: bool = fixture_owner != null
	if (
		not PALETTE.PROFILES.has(palette_profile)
		or not is_instance_valid(property)
		or (property.get_parent() != null if fixture else not property.is_inside_tree())
		or not property.has_method("props_intact")
		or not property.has_method("attach_lighting_preview")
		or not property.has_method("detach_lighting_preview")
		or not property.props_intact()
		or not is_instance_valid(kit)
		or kit.get_parent() != property
		or not KIT.valid(kit)
		or not is_instance_valid(environment)
		or not environment.is_inside_tree()
		or environment.environment == null
		or not is_instance_valid(sun)
		or not sun.is_inside_tree()
		or not PALETTE.sun_geometry_valid(sun)
		or environment.get_viewport() != sun.get_viewport()
		or (not fixture and property.get_viewport() != environment.get_viewport())
		or not (property.basis if fixture else property.global_basis).is_equal_approx(
			Basis.IDENTITY
		)
	):
		return null
	var objects: Variant = property.get("objects")
	if not objects is Dictionary or objects.get(kit.get_meta("owned_copy", "")) != kit:
		return null
	var pattern: String = kit.get_meta("site")
	if (
		(pattern == "MIXED_EDGE" and rear_poles.size() != 2)
		or (pattern != "MIXED_EDGE" and not rear_poles.is_empty())
	):
		return null
	var copies: Array[String] = [kit.get_meta("owned_copy")]
	var sites: Array[String] = []
	for pole: Node3D in rear_poles:
		if not _exact_pole(pole, property, objects):
			return null
		var copy: String = pole.get_meta("owned_copy")
		var site: String = pole.get_meta("site")
		if copies.has(copy) or sites.has(site):
			return null
		copies.append(copy)
		sites.append(site)
	sites.sort()
	if pattern == "MIXED_EDGE" and sites != ["YLIGHT-RL", "YLIGHT-RR"]:
		return null
	for model: Variant in objects.values():
		if (
			model is Node3D
			and model.get_meta("stadium_item", "") in ["ST-036", "ST-037", "ST-111"]
			and model != kit
			and not rear_poles.has(model)
		):
			return null  # Never hide an additional installed lighting assembly by passing a subset.
	var viewport: Viewport = environment.get_viewport()
	for target: Object in [environment, sun, viewport]:
		if target.has_meta(LEASE):
			return null
	if viewport.has_meta(&"owned_surface_night_atlas_owner"):
		return null
	for other: Node in environment.get_tree().get_nodes_in_group(&"dg1_string_night_study_lease"):
		if other.get("active") == true and other.get_viewport() == viewport:
			return null
	var rig: StadiumLightingKitPreviewRuntime = StadiumLightingKitPreviewRuntime.new()
	rig.name = "ST111ExplicitLightingPreview"
	rig.profile = pattern
	rig._palette_profile = palette_profile
	rig._palette_signature = PALETTE.signature(palette_profile)
	rig._property = property
	rig._property_pose = property.transform if fixture else property.global_transform
	rig._fixture_owner = weakref(fixture_owner) if fixture else null
	rig._objects = objects.duplicate()
	rig._kit = kit
	rig._poles = rear_poles.duplicate()
	rig._environment = environment
	rig._sun = sun
	rig._viewport = viewport
	rig._scope = [kit]
	rig._scope.append_array(rear_poles)
	rig.set_meta("night_qualified", false)
	rig.set_meta("grants_inventory", false)
	rig.set_meta("qualification_status", "EXPLICIT_PREVIEW_UNQUALIFIED")
	# Sibling, not a component of the sealed owned kit.
	if not fixture:
		property.get_parent().add_child(rig)
	if not rig._prepare() or not property.props_intact():
		rig.free()
		return null
	if fixture:
		rig.set_process(false)
		return rig  # Detached and dormant; owner must explicitly attach before any writes.
	# The property captures ONLY the verified rear poles that lack a prior infrastructure seal.
	if not property.attach_lighting_preview(rig, kit, rear_poles):
		rig.free()
		return null
	rig._attached = true
	for target: Object in [environment, sun, viewport]:
		target.set_meta(LEASE, rig)
	rig.add_to_group(GROUP)
	if not rig.intact():
		rig.restore()
		rig.free()
		return null
	return rig  # Explicitly dormant until set_night(true).


func attach_fixture(owner: StadiumSurfaceNightRuntime) -> bool:
	if (
		_fixture_owner == null
		or _fixture_owner.get_ref() != owner
		or _attached
		or not owner._kit_lease_context(self, false)
		or not _property.props_intact()
		or not _property.attach_lighting_preview(self, _kit, _poles)
	):
		return false
	_attached = true
	for target: Object in [_environment, _sun, _viewport]:
		if target.has_meta(LEASE):
			restore()
			return false
		target.set_meta(LEASE, self)
	return intact()


func _property_context(require_claim: bool) -> bool:
	if _fixture_owner != null:
		var owner: Variant = _fixture_owner.get_ref()
		return (
			is_instance_valid(owner)
			and owner.get_script() == StadiumSurfaceNightRuntime
			and _property.transform == _property_pose
			and owner._kit_lease_context(self, require_claim)
		)
	return _property.is_inside_tree() and _property.global_transform == _property_pose


func _transaction_context() -> bool:
	if _fixture_owner == null:
		return true
	var owner: Variant = _fixture_owner.get_ref()
	return is_instance_valid(owner) and owner._kit_transaction_intact(self)


func property_owner() -> Node3D:
	return _property


func kit_owner() -> Node3D:
	return _kit


func pole_owners() -> Array[Node3D]:
	return _poles.duplicate()


func ready_for_attach() -> bool:
	if (
		_attached
		or _retired
		or not is_instance_valid(_property)
		or not _property.props_intact()
		or not KIT.valid(_kit)
		or not presentation_intact(false)
	):
		return false
	for pole: Node3D in _poles:
		if not _exact_pole(pole, _property, _objects):
			return false
	return true


func _prepare() -> bool:
	_source_environment = _environment.environment
	_working_environment = PALETTE.environment()
	if _working_environment == null:
		return false
	if not _seal_resource(_source_environment) or not _seal_resource(_working_environment):
		return false
	if not _change(_environment, &"environment", _working_environment, false):
		return false
	if not _change(_sun, &"light_color", PALETTE.sun_values().light_color, false):
		return false
	if not _change(_sun, &"light_energy", PALETTE.sun_values().light_energy, false):
		return false
	return _prepare_remaining_checks()


func _prepare_remaining_checks() -> bool:
	# Save every immutable sun/environment node field, including transforms and direction.
	for node: Node in [_environment, _sun]:
		var values: Dictionary = {}
		for descriptor: Dictionary in node.get_property_list():
			if (
				int(descriptor.usage) & PROPERTY_USAGE_STORAGE
				and not String(descriptor.name).begins_with("metadata/")
			):
				values[descriptor.name] = node.get(descriptor.name)
		_external.append({"node": node, "parent": node.get_parent(), "values": values})
	var clones: Dictionary = {}
	for mesh: Node in _kit.get_node("Visual").get_children():
		if String(mesh.name).contains("Bulb"):
			if not _prepare_lens(mesh, clones):
				return false
	for source: SpotLight3D in _kit.get_node("Sources").get_children():
		sources.append(source)
		if not _change(source, &"visible", true, true):
			return false
		# Optional source fields are limited to the named kit-only bias or shadow-fill trial.
		for field: StringName in PALETTE.kit_source_values(_palette_profile):
			if not _change(source, field, PALETTE.kit_source_values(_palette_profile)[field], true):
				return false
	for pole: Node3D in _poles:
		if not _prepare_lens(pole.get_node("Visual/LampLens"), clones):
			return false
		var source: SpotLight3D = pole.get_node("FieldLight")
		sources.append(source)
		if not _change(source, &"visible", true, true):
			return false
	_source_shadows = _shadows()
	_expected_shadows = _source_shadows.duplicate(true)
	return sources.size() == (5 if profile == "MIXED_EDGE" else 3)


func _prepare_lens(mesh: MeshInstance3D, clones: Dictionary) -> bool:
	if not mesh.material_override is StandardMaterial3D:
		return false
	var original: StandardMaterial3D = mesh.material_override
	if not clones.has(original):
		var working: StandardMaterial3D = PALETTE.lens(original)
		if working == null:
			return false
		clones[original] = working
		if not _seal_resource(original) or not _seal_resource(working):
			return false
	return _change(mesh, &"material_override", clones[original], true)


func _change(node: Object, field: StringName, working: Variant, property_allowed: bool) -> bool:
	if _change_index.has(node) and _change_index[node].has(field):
		return false  # No exact operand may acquire competing presentation rows.
	var row: Dictionary = {
		"node": node,
		"field": field,
		"original": node.get(field),
		"working": working,
		"expected": node.get(field),
		"property_allowed": property_allowed
	}
	_changes.append(row)
	if not _change_index.has(node):
		_change_index[node] = {}
	_change_index[node][field] = row  # The same dictionary is updated by set_night/restore.
	return true


func allows_change(node: Object, field: StringName, original: Variant, actual: Variant) -> bool:
	# Exact lookup, never cached guard success. Scalar exception is only the authored kit trial.
	if (
		not _attached
		or _retired
		or not _change_index.has(node)
		or not _change_index[node].has(field)
	):
		return false
	if (
		field not in [&"visible", &"material_override"]
		and not (
			node is SpotLight3D
			and is_instance_valid(_kit)
			and node.get_parent() == _kit.get_node("Sources")
			and (
				(field == &"shadow_normal_bias" and _palette_profile == "ATLAS4096_KITBIAS2")
				or (field == &"shadow_enabled" and _palette_profile == "KIT_FILL2048")
			)
		)
	):
		return false
	var row: Dictionary = _change_index[node][field]
	return (
		row.node == node
		and row.field == field
		and row.property_allowed
		and original == row.original
		and actual == row.expected
		and actual == row.working
	)


func presentation_intact(require_claim: bool = true) -> bool:
	# Deliberately does not call property.props_intact(), avoiding recursive guard callbacks.
	if (
		_retired
		or _palette_signature.is_empty()
		or _palette_signature != PALETTE.signature(_palette_profile)
		or not is_instance_valid(_property)
		or not _property_context(require_claim)
		or _property.get("objects") != _objects
		or not is_instance_valid(_kit)
		or _kit.get_parent() != _property
		or not is_instance_valid(_environment)
		or not is_instance_valid(_sun)
		or not is_instance_valid(_viewport)
	):
		return false
	if require_claim:
		for target: Object in [_environment, _sun, _viewport]:
			if not target.has_meta(LEASE) or not is_same(target.get_meta(LEASE), self):
				return false
	for row: Dictionary in _changes:
		if not is_instance_valid(row.node) or row.node.get(row.field) != row.expected:
			return false
	for row: Dictionary in _external:
		if not is_instance_valid(row.node) or row.node.get_parent() != row.parent:
			return false
		for field: String in row.values:
			var current: Variant = row.node.get(field)
			if current != row.values[field] and not _expected_change(row.node, field, current):
				return false
	return _presentation_intact_remaining_checks()


func _presentation_intact_remaining_checks() -> bool:
	for row: Dictionary in _resources:
		if (
			not is_instance_valid(row.resource)
			or row.resource.get_meta_list().size() != row.metadata.size()
		):
			return false
		for field: String in row.values:
			if row.resource.get(field) != row.values[field]:
				return false
		for key: StringName in row.metadata:
			if not row.resource.has_meta(key) or row.resource.get_meta(key) != row.metadata[key]:
				return false
	return _shadows() == _expected_shadows


func _expected_change(node: Object, field: StringName, actual: Variant) -> bool:
	if not _change_index.has(node) or not _change_index[node].has(field):
		return false
	var row: Dictionary = _change_index[node][field]
	return row.node == node and row.field == field and actual == row.expected


func intact() -> bool:
	return _attached and presentation_intact() and _property.props_intact()


func canonical_night_state() -> bool:
	if not active or _shadows() != PALETTE.shadows(_palette_profile):
		return false
	for row: Dictionary in _changes:
		if not StadiumSurfaceNightRuntime._kit_value_equal(row.expected, row.working):
			return false
	return true


func set_night(enabled: bool) -> bool:
	if _fixture_owner != null:
		var owner: Variant = _fixture_owner.get_ref()
		if not is_instance_valid(owner) or not owner._kit_toggle_allowed(self, enabled):
			return false  # Authoring callers cannot toggle a fixed fixture or retire it.
	if _retired or not intact():
		restore()
		return false
	if active == enabled:
		return true
	return _set_night_remaining_checks(enabled)


func _set_night_remaining_checks(enabled: bool) -> bool:
	for row: Dictionary in _changes:
		if not presentation_intact():
			restore()
			return false
		var target: Variant = row.working if enabled else row.original
		row.expected = target  # Seal the planned value before any synchronous native callback.
		row.node.set(row.field, target)
		# Visibility has synchronous callbacks: recheck the complete property's immutable seal.
		# Other writes still recheck all owned presentation identities/resources immediately;
		# the full immutable property is checked both before and after the bounded transaction.
		if (
			not presentation_intact()
			or (
				row.field == &"visible"
				and (not _property.props_intact() or not _transaction_context())
			)
		):
			restore()
			return false
	# Five-source mixed preview needs more than the old four one-map quadrants.
	var desired: Dictionary = PALETTE.shadows(_palette_profile) if enabled else _source_shadows
	for index in range(4):
		_expected_shadows.quadrants[index] = desired.quadrants[index]
		_viewport.set_positional_shadow_atlas_quadrant_subdiv(index, desired.quadrants[index])
	_expected_shadows.size = desired.size
	_viewport.positional_shadow_atlas_size = desired.size
	_expected_shadows.precision = desired.precision
	_viewport.positional_shadow_atlas_16_bits = desired.precision
	active = enabled
	if not intact() or not _transaction_context():
		restore()
		return false
	return true


func restore() -> void:
	# Explicit lease teardown revokes its fixture issuance before any native write.
	if _fixture_owner != null:
		var fixture: Variant = _fixture_owner.get_ref()
		if is_instance_valid(fixture):
			fixture._invalidate_kit_issue()
	# Terminal lease release. Use set_night(false) for a reversible Day toggle.
	if _restoring or _retired:
		return
	if not _attached:
		_retired = true
		return  # Failed preparation never changed presentation or claimed external objects.
	_restoring = true
	active = false
	for row: Dictionary in _changes:
		# Value equality alone does not transfer ownership from a replacement token.
		# Recheck claims for every write: prior native writes may synchronously call out.
		if _restore_claims_owned(row.node) and row.node.get(row.field) == row.expected:
			row.expected = row.original
			row.node.set(row.field, row.original)
	for index in range(4):
		if (
			_restore_claims_owned(_viewport)
			and (
				_viewport.get_positional_shadow_atlas_quadrant_subdiv(index)
				== _expected_shadows.quadrants[index]
			)
		):
			_viewport.set_positional_shadow_atlas_quadrant_subdiv(
				index, _source_shadows.quadrants[index]
			)
	if (
		_restore_claims_owned(_viewport)
		and _viewport.positional_shadow_atlas_size == _expected_shadows.size
	):
		_viewport.positional_shadow_atlas_size = _source_shadows.size
	if (
		_restore_claims_owned(_viewport)
		and _viewport.positional_shadow_atlas_16_bits == _expected_shadows.precision
	):
		_viewport.positional_shadow_atlas_16_bits = _source_shadows.precision
	if _attached and is_instance_valid(_property):
		_property.detach_lighting_preview(self)
	_attached = false
	for target: Object in [_environment, _sun, _viewport]:
		if (
			is_instance_valid(target)
			and target.has_meta(LEASE)
			and is_same(target.get_meta(LEASE), self)
		):
			target.remove_meta(LEASE)
	_retired = true
	_restoring = false
	set_process(false)


func _restore_claims_owned(target: Object) -> bool:
	if not is_instance_valid(target):
		return false
	if _fixture_owner != null:
		var owner: Variant = _fixture_owner.get_ref()
		if (
			not is_instance_valid(owner)
			or owner.get_script() != StadiumSurfaceNightRuntime
			or not is_same(owner._kit_lease, self)
			or not is_instance_valid(_viewport)
			or not _viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
			or not is_same(_viewport.get_meta(StadiumSurfaceNightRuntime.ATLAS), owner)
		):
			return false
	if target == _environment or target == _sun or target == _viewport:
		return target.has_meta(LEASE) and is_same(target.get_meta(LEASE), self)
	return (
		is_instance_valid(_property)
		and is_same(_property.get("_lighting_preview"), self)
		and target is Node
		and _property.is_ancestor_of(target)
	)


func coverage(point: Vector3) -> int:
	if not active or not point.is_finite() or not intact():
		return 0
	var result: int = 0
	for source: SpotLight3D in sources:
		var delta: Vector3 = point - source.global_position
		if (
			not source.is_visible_in_tree()
			or delta.length() < 0.001
			or delta.length() > source.spot_range
			or (-source.global_basis.z).dot(delta.normalized()) < cos(deg_to_rad(source.spot_angle))
		):
			continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			source.global_position, point, 1
		)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			result += 1
	return result


func _process(_delta: float) -> void:
	if _attached and not intact():
		restore()


func _exit_tree() -> void:
	restore()


func _shadows() -> Dictionary:
	if not is_instance_valid(_viewport):
		return {}
	var result: Dictionary = {
		"size": _viewport.positional_shadow_atlas_size,
		"precision": _viewport.positional_shadow_atlas_16_bits,
		"quadrants": []
	}
	for index in range(4):
		result.quadrants.append(_viewport.get_positional_shadow_atlas_quadrant_subdiv(index))
	return result


func _seal_resource(resource: Resource, depth: int = 0) -> bool:
	if resource == null or resource.get_script() != null or depth > 8:
		return false
	if _resource_seen.has(resource):
		return true
	_resource_seen[resource] = true
	var values: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		if (
			int(property.usage)
			& (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP)
		):
			continue
		if (
			not resource is StandardMaterial3D
			and not (int(property.usage) & PROPERTY_USAGE_STORAGE)
		):
			continue
		if property.name in ["resource_name", "resource_path", "resource_local_to_scene"]:
			continue
		var value: Variant = resource.get(property.name)
		values[property.name] = (
			value.duplicate(true) if value is Dictionary or value is Array else value
		)
		if value is Resource and not _seal_resource(value, depth + 1):
			return false
	var metadata: Dictionary = {}
	for key: StringName in resource.get_meta_list():
		metadata[key] = resource.get_meta(key)
	_resources.append({"resource": resource, "values": values, "metadata": metadata})
	return true


static func _exact_pole(pole: Node3D, property: Node3D, objects: Dictionary) -> bool:
	if (
		not is_instance_valid(pole)
		or pole.get_parent() != property
		or pole.get_meta("stadium_item", "") != "ST-037"
		or pole.get_meta("site", "") not in ["YLIGHT-RL", "YLIGHT-RR"]
		or not pole.has_meta("owned_copy")
		or not pole.get_meta("owned_copy") is String
		or String(pole.get_meta("owned_copy")).is_empty()
		or objects.get(pole.get_meta("owned_copy")) != pole
		or (
			pole.has_meta("paid_copy") and pole.get_meta("paid_copy") != pole.get_meta("owned_copy")
		)
	):
		return false
	var factory: Script = (
		load("res://src/presentation/stadium/stadium_yard_light_models.gd") as Script
	)
	if factory == null:
		return false
	var expected: Node3D = factory.create()
	factory.place(expected, pole.get_meta("site"))
	var accepted: bool = _same_tree(pole, expected, true)
	if not accepted:
		# install_bound applies this canonical Day state (disabled lens energy 0).
		# Compare the entire second factory state; arbitrary disabled values stay invalid.
		factory.night(expected, false)
		accepted = _same_tree(pole, expected, true)
	expected.free()
	return accepted


static func _same_tree(actual: Node3D, expected: Node3D, root: bool = false) -> bool:
	if (
		actual.get_class() != expected.get_class()
		or actual.get_script() != null
		or (
			not root and not String(expected.name).begins_with("@") and actual.name != expected.name
		)
		or actual.transform != expected.transform
		or actual.visible != expected.visible
		or actual.top_level != expected.top_level
		or actual.process_mode != expected.process_mode
		or actual.get_child_count() != expected.get_child_count()
	):
		return false
	var fields: Array[StringName] = []
	if actual is MeshInstance3D:
		if not KIT._render_defaults(actual) or actual.get_surface_override_material(0) != null:
			return false
		fields = [
			&"mesh",
			&"material_override",
			&"material_overlay",
			&"cast_shadow",
			&"layers",
			&"transparency"
		]
	elif actual is StaticBody3D:
		fields = [
			&"collision_layer",
			&"collision_mask",
			&"disable_mode",
			&"physics_material_override",
			&"constant_linear_velocity",
			&"constant_angular_velocity"
		]
	elif actual is CollisionShape3D:
		fields = [&"shape", &"disabled"]
	elif actual is Light3D:
		for descriptor: Dictionary in expected.get_property_list():
			if (
				int(descriptor.usage) & PROPERTY_USAGE_STORAGE
				and not String(descriptor.name).begins_with("metadata/")
			):
				fields.append(descriptor.name)
	for field: StringName in fields:
		var a: Variant = actual.get(field)
		var b: Variant = expected.get(field)
		if a is Resource and b is Resource:
			if not KIT._resource_matches(a, b):
				return false
		elif a != b:
			return false
	for index in range(actual.get_child_count()):
		if (
			not actual.get_child(index) is Node3D
			or not _same_tree(actual.get_child(index), expected.get_child(index))
		):
			return false
	return true


func issued_presentation_intact(owner: StadiumSurfaceNightRuntime) -> bool:
	# Candidate3 fixture hot path only. Full resource fields and palette signatures
	# remain in presentation_intact at issuance, transitions, restoration and proof.
	if (
		(
			(
					_fixture_owner == null
					or not is_same(_fixture_owner.get_ref(), owner)
					or not _attached
					or _retired
					or _restoring
					or not active
					or not is_instance_valid(_property)
					or _property._lighting_preview != self
					or _property.transform != _property_pose
					or _property.objects != _objects
					or not is_instance_valid(_kit)
					or _kit.is_queued_for_deletion()
					or _kit.get_parent() != _property
				)
		)
		or (
			owner._world.environment != _environment.environment
		)
	):
		return false
	for target: Object in [_environment, _sun, _viewport]:
		if (
			not is_instance_valid(target)
			or not target.has_meta(LEASE)
			or not is_same(target.get_meta(LEASE), self)
		):
			return false
	for row: Dictionary in _changes:
		if (
			not is_instance_valid(row.node)
			or not StadiumSurfaceNightRuntime._kit_value_equal(
				row.node.get(row.field), row.expected
			)
		):
			return false
	for row: Dictionary in _external:
		if not is_instance_valid(row.node) or row.node.get_parent() != row.parent:
			return false
		for field: String in row.values:
			var actual: Variant = row.node.get(field)
			if (
				not StadiumSurfaceNightRuntime._kit_value_equal(actual, row.values[field])
				and not _expected_change(row.node, field, actual)
			):
				return false
	return _shadows() == _expected_shadows


func invalidate_fixture_issue() -> void:
	if _fixture_owner != null:
		var owner: Variant = _fixture_owner.get_ref()
		if is_instance_valid(owner):
			owner._invalidate_kit_issue()


func issued_owner_intact(owner: StadiumSurfaceNightRuntime) -> bool:
	# New fixed-fixture lifecycle contract only. Full native resources, source
	# scalars and bulb bindings remain in presentation_intact at deep boundaries.
	if (
		_fixture_owner == null
		or not is_same(_fixture_owner.get_ref(), owner)
		or not _attached
		or _retired
		or _restoring
		or not active
		or not is_instance_valid(_property)
		or _property._lighting_preview != self
		or not is_instance_valid(_kit)
		or _kit.is_queued_for_deletion()
		or _kit.get_parent() != _property
		or _property.objects != _objects
	):
		return false
	for target: Object in [_environment, _sun, _viewport]:
		if (
			not is_instance_valid(target)
			or (target is Node and target.is_queued_for_deletion())
			or not target.has_meta(LEASE)
			or not is_same(target.get_meta(LEASE), self)
		):
			return false
	return (
		is_same(_environment.environment, _working_environment)
		and is_same(owner._world.environment, _working_environment)
	)
