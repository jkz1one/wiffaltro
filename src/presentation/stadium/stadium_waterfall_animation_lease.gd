class_name StadiumWaterfallAnimationLease
extends RefCounted
## One exact installed-model lease. Only the eight CPU-owned phase uniforms can move.
## Every expected infrastructure/trap value is advanced with its matching material.
const PHASE: StringName = &"shader_parameter/phase"
const SPEED: float = StadiumWaterfallMotionOwner.CYCLES_PER_SECOND
var phase: float = 0.0
var retired: bool = false
var _property: StadiumPropertyGeometry
var _copies: Array[String] = []
var _models: Array[Dictionary] = []
var _tokens: Array[Dictionary] = []
var _writing: bool = false
var _runtime: WeakRef
var _runtime_bound: bool = false
var _phase_captured: bool = false
var _phase_property: StadiumPropertyGeometry
var _phase_copies: Array[String] = []
var _phase_rows: Array[Dictionary] = []
var _expected_phase: float = 0.0


static func capture(
	property: StadiumPropertyGeometry, copies: Array[String]
) -> StadiumWaterfallAnimationLease:
	if property == null or copies.is_empty() or copies.size() > 3:
		return null
	var lease: StadiumWaterfallAnimationLease = StadiumWaterfallAnimationLease.new()
	lease._property = property
	lease._copies = copies.duplicate()
	var unique: Dictionary = {}
	for copy: String in copies:
		var root: Node3D = property.objects.get(copy)
		if (
			unique.has(copy)
			or root == null
			or root.get_parent() != property
			or root.get_meta("owned_copy", "") != copy
			or not _no_internal_children(root)
			or not StadiumWaterfallAnimatedModels.valid(root)
		):
			return null
		unique[copy] = true
		var visual: Node3D = StadiumWaterfallAnimatedModels.visual(root)
		var nodes: Array[Dictionary] = []
		for id: String in StadiumWaterfallModels.PARTS:
			var part: MeshInstance3D = visual.get_node(id)
			var water: bool = id in StadiumWaterfallMotionModels.WATER
			var fields: Dictionary = {}
			for key: String in StadiumWaterfallMotionOwner.NODE_FIELDS:
				fields[key] = part.get(key)
			nodes.append(
				{
					"id": id,
					"node": part,
					"fields": fields,
					"mesh": part.mesh,
					"mesh_fields": StadiumWaterfallMotionOwner._resource_fields(part.mesh),
					"material": part.material_override,
					"material_fields":
					StadiumWaterfallMotionOwner._resource_fields(part.material_override, water)
				}
			)
			if water:
				var token: Dictionary = lease._token(root, part)
				if token.is_empty():
					return null
				lease._tokens.append(token)
		var metadata: Dictionary = {}
		for key: StringName in root.get_meta_list():
			metadata[key] = root.get_meta(key)
		lease._models.append(
			{
				"copy": copy,
				"root": root,
				"pose": root.transform,
				"visual": visual,
				"visual_parent": visual.get_parent(),
				"nodes": nodes,
				"metadata": metadata
			}
		)
	if not lease.presentation_intact() or not lease._capture_phase_records():
		return null
	return lease if lease._phase_records_intact() else null


static func _no_internal_children(root: Node) -> bool:
	if not is_instance_valid(root):
		return false
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node.get_child_count(true) != node.get_child_count():
			return false
		for child: Node in node.get_children(true):
			pending.append(child)
	return true


func _token(root: Node3D, part: MeshInstance3D) -> Dictionary:
	var material: ShaderMaterial = part.material_override
	var refs: Array[Dictionary] = []
	for seal: Dictionary in _property._infrastructure:
		if seal.root != root:
			continue
		for row: Dictionary in seal.resources:
			if row.resource == material:
				var index: int = row.keys.find(PHASE)
				if index < 0 or row.values[index] != 0.0:
					return {}
				refs.append({"kind": "array", "row": row, "index": index})
	if refs.size() != 1:
		return {}
	var callback: Callable = _property._retire_props
	var live: bool = root.get_meta("live_furnishing", false)
	if live:
		var trap: Dictionary = _property._waterfall_traps.get(root.get_meta("owned_copy"), {})
		if trap.is_empty() or trap.retire != callback:
			return {}
		for row: Dictionary in trap.resources:
			if row.resource == material:
				if not row.fields.has(PHASE) or row.fields[PHASE] != 0.0:
					return {}
				refs.append({"kind": "dictionary", "row": row})
		if refs.size() != 2:
			return {}
	var result: Dictionary = {
		"part": part,
		"material": material,
		"shader": material.shader,
		"shader_fields": StadiumWaterfallMotionOwner._resource_fields(material.shader),
		"refs": refs,
		"live": live,
		"callback": callback
	}
	return result if _listeners_intact(result) else {}


func presentation_intact() -> bool:
	if _phase_captured and not _phase_records_intact():
		return false
	if (
		retired
		or _writing
		or not is_instance_valid(_property)
		or not _property._props_live
		or _property._waterfall_animation_copies != _copies
		or not is_finite(phase)
		or phase < 0.0
		or phase >= 1.0
	):
		return false
	for model: Dictionary in _models:
		var root: Node3D = model.root
		var visual: Node3D = model.visual
		if (
			not is_instance_valid(root)
			or not is_instance_valid(visual)
			or root.get_parent() != _property
			or _property.objects.get(model.copy) != root
			or root.transform != model.pose
			or not StadiumWaterfallModels._clean(root)
			or visual.get_parent() != model.visual_parent
			or not _no_internal_children(root)
			or visual.get_child_count(true) != model.nodes.size()
			or root.get_meta_list().size() != model.metadata.size()
		):
			return false
		for key: StringName in model.metadata:
			if not root.has_meta(key) or root.get_meta(key) != model.metadata[key]:
				return false
		for row: Dictionary in model.nodes:
			var part: MeshInstance3D = row.node
			if (
				not is_instance_valid(part)
				or visual.get_node_or_null(row.id) != part
				or part.get_parent() != visual
				or not StadiumWaterfallModels._clean(part)
				or part.get_child_count(true) != 0
				or part.mesh != row.mesh
				or part.material_override != row.material
				or part.get_surface_override_material(0) != null
				or not StadiumWaterfallMotionOwner._fields_equal(part, row.fields)
				or not StadiumWaterfallMotionOwner._fields_equal(row.mesh, row.mesh_fields)
				or not StadiumWaterfallMotionOwner._fields_equal(row.material, row.material_fields)
			):
				return false
	return _presentation_intact_remaining_checks()


func _presentation_intact_remaining_checks() -> bool:
	for token: Dictionary in _tokens:
		if (
			token.part.material_override != token.material
			or token.material.shader != token.shader
			or not StadiumWaterfallMotionOwner._fields_equal(token.shader, token.shader_fields)
			or token.material.get_shader_parameter("phase") != phase
			or not _listeners_intact(token)
		):
			return false
		for ref: Dictionary in token.refs:
			if (
				(ref.row.values[ref.index] if ref.kind == "array" else ref.row.fields[PHASE])
				!= phase
			):
				return false
	return true


static func _listeners_intact(token: Dictionary) -> bool:
	var listeners: Array = token.material.changed.get_connections()
	if not token.live:
		return listeners.is_empty()
	return (
		listeners.size() == 1
		and listeners[0].callable == token.callback
		and listeners[0].flags == 0
	)


func _capture_phase_records() -> bool:
	if _phase_captured:
		return false
	_phase_property = _property
	_phase_copies = _copies.duplicate()
	_phase_copies.make_read_only()
	for model: Dictionary in _models:
		for node: Dictionary in model.nodes:
			if node.id not in StadiumWaterfallMotionModels.WATER:
				continue
			var source: Dictionary = {}
			for token: Dictionary in _tokens:
				if token.part == node.node:
					if not source.is_empty():
						return false
					source = token
			if source.is_empty():
				return false
			var refs: Array[Dictionary] = []
			for ref: Dictionary in source.refs:
				var pinned: Dictionary = _capture_phase_ref(ref, model.root, source.material)
				if pinned.is_empty():
					return false
				# Shallow only: row/values/fields remain the original writable expected
				# phase destinations. Never recursively freeze the property/trap seals.
				pinned.make_read_only()
				refs.append(pinned)
			refs.make_read_only()
			var row: Dictionary = {
				"copy": model.copy,
				"root": model.root,
				"visual": model.visual,
				"visual_parent": model.visual_parent,
				"id": node.id,
				"part": node.node,
				"mesh": node.mesh,
				"material": source.material,
				"shader": source.shader,
				"mesh_fields": _frozen_phase_copy(node.mesh_fields),
				"material_fields": _frozen_phase_copy(node.material_fields),
				"shader_fields": _frozen_phase_copy(source.shader_fields),
				"live": source.live,
				"callback": source.callback,
				"refs": refs
			}
			row.make_read_only()
			_phase_rows.append(row)
	if _phase_rows.size() != _copies.size() * StadiumWaterfallMotionModels.WATER.size():
		return false
	_phase_rows.make_read_only()
	_expected_phase = phase
	_phase_captured = true
	return true


func _capture_phase_ref(ref: Dictionary, root: Node3D, material: ShaderMaterial) -> Dictionary:
	if ref.kind == "array":
		for seal_index: int in range(_property._infrastructure.size()):
			var seal: Dictionary = _property._infrastructure[seal_index]
			if seal.root != root:
				continue
			for index: int in range(seal.resources.size()):
				var row: Dictionary = seal.resources[index]
				if not is_same(row, ref.row):
					continue
				if row.resource != material or row.keys[ref.index] != PHASE:
					return {}
				return {
					"kind": "array",
					"owner": _property._infrastructure,
					"seal": seal,
					"root": root,
					"seal_index": seal_index,
					"resources": seal.resources,
					"resource_index": index,
					"row": row,
					"keys": row.keys,
					"values": row.values,
					"phase_index": ref.index,
					"fixed_keys": _frozen_phase_copy(row.keys),
					"fixed_values": _frozen_phase_copy(row.values)
				}
	elif ref.kind == "dictionary":
		var copy: String = root.get_meta("owned_copy", "")
		var trap: Dictionary = _property._waterfall_traps.get(copy, {})
		for index: int in range(trap.get("resources", []).size()):
			var row: Dictionary = trap.resources[index]
			if not is_same(row, ref.row):
				continue
			if row.resource != material or not row.fields.has(PHASE):
				return {}
			var fixed: Dictionary = row.fields.duplicate(true)
			fixed.erase(PHASE)
			return {
				"kind": "dictionary",
				"owner": _property._waterfall_traps,
				"copy": copy,
				"root": root,
				"trap": trap,
				"resources": trap.resources,
				"resource_index": index,
				"row": row,
				"fields": row.fields,
				"fixed_fields": _frozen_phase_copy(fixed)
			}
	return {}


static func _frozen_phase_copy(value: Variant) -> Variant:
	# This helper receives comparison values only, never expected-row references.
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _frozen_phase_copy(value[key])
		result.make_read_only()
		return result
	if value is Array:
		var result: Array = value.duplicate()
		for index: int in range(result.size()):
			result[index] = _frozen_phase_copy(result[index])
		result.make_read_only()
		return result
	return value


func _phase_presentation_intact() -> bool:
	# The detached preview keeps the full original proof. Only an explicitly
	# runtime-bound NEW47 lease may use the narrow phase-resource proof.
	return _phase_records_intact() if _runtime_bound else presentation_intact()


func _phase_records_intact() -> bool:
	if (
		not _phase_captured
		or retired
		or _writing
		or not is_instance_valid(_property)
		or _property != _phase_property
		or _property.is_queued_for_deletion()
		or not _property._props_live
		or _property._waterfall_animation_copies != _phase_copies
		or not is_finite(phase)
		or phase < 0.0
		or phase >= 1.0
		or phase != _expected_phase
	):
		return false
	for row: Dictionary in _phase_rows:
		if (
			not is_instance_valid(row.root)
			or row.root.is_queued_for_deletion()
			or row.root.get_parent() != _property
			or _property.objects.get(row.copy) != row.root
			or not is_instance_valid(row.visual)
			or row.visual.is_queued_for_deletion()
			or row.visual.get_parent() != row.visual_parent
			or not is_instance_valid(row.part)
			or row.part.is_queued_for_deletion()
			or row.part.get_parent() != row.visual
			or row.visual.get_node_or_null(row.id) != row.part
			or row.part.get_script() != null
			or row.part.get_child_count(true) != 0
			or row.part.mesh != row.mesh
			or row.part.material_override != row.material
			or row.part.get_surface_override_material(0) != null
			or not is_instance_valid(row.material)
			or row.material.shader != row.shader
			or not StadiumWaterfallMotionOwner._fields_equal(row.mesh, row.mesh_fields)
			or not StadiumWaterfallMotionOwner._fields_equal(row.material, row.material_fields)
			or not StadiumWaterfallMotionOwner._fields_equal(row.shader, row.shader_fields)
			or row.material.get_shader_parameter("phase") != _expected_phase
			or not _listeners_intact(row)
		):
			return false
		for ref: Dictionary in row.refs:
			if not _phase_ref_intact(ref, row.material):
				return false
	return true


func _phase_ref_intact(ref: Dictionary, material: ShaderMaterial) -> bool:
	if ref.kind == "array":
		if (
			not is_same(_property._infrastructure, ref.owner)
			or ref.owner.size() <= ref.seal_index
			or not is_same(ref.owner[ref.seal_index], ref.seal)
			or ref.seal.get("root") != ref.root
			or not is_same(ref.seal.get("resources"), ref.resources)
			or ref.resources.size() <= ref.resource_index
			or not is_same(ref.resources[ref.resource_index], ref.row)
			or ref.row.get("resource") != material
			or not is_same(ref.row.get("keys"), ref.keys)
			or not is_same(ref.row.get("values"), ref.values)
			or ref.values.is_read_only()
			or ref.keys != ref.fixed_keys
			or ref.values.size() != ref.fixed_values.size()
			or ref.values[ref.phase_index] != _expected_phase
		):
			return false
		for index: int in range(ref.values.size()):
			if index != ref.phase_index and ref.values[index] != ref.fixed_values[index]:
				return false
		return true
	if (
		not is_same(_property._waterfall_traps, ref.owner)
		or not is_same(ref.owner.get(ref.copy), ref.trap)
		or ref.trap.get("model") != ref.root
		or not is_same(ref.trap.get("resources"), ref.resources)
		or ref.trap.get("retire") != _property._retire_props
		or ref.resources.size() <= ref.resource_index
		or not is_same(ref.resources[ref.resource_index], ref.row)
		or ref.row.get("resource") != material
		or not is_same(ref.row.get("fields"), ref.fields)
		or ref.fields.is_read_only()
		or ref.fields.size() != ref.fixed_fields.size() + 1
		or ref.fields.get(PHASE) != _expected_phase
	):
		return false
	for key: Variant in ref.fixed_fields:
		if not ref.fields.has(key) or ref.fields[key] != ref.fixed_fields[key]:
			return false
	return true


func bind_runtime(owner: StadiumWaterfallAnimationRuntime) -> bool:
	if (
		_runtime_bound
		or _runtime != null
		or not is_instance_valid(owner)
		or owner.get_script() != StadiumWaterfallAnimationRuntime
		or owner._lease != self
		or owner._property != _property
		or owner.get_parent() != _property
	):
		return false
	_runtime = weakref(owner)
	_runtime_bound = true
	return true


func runtime_owner() -> StadiumWaterfallAnimationRuntime:
	return _runtime.get_ref() as StadiumWaterfallAnimationRuntime if _runtime != null else null


func _runtime_gate() -> int:
	# Detached draft previews have no gameplay context. Once bound, callers cannot
	# bypass the live actor's gate by supplying false,false to advance or reset.
	if not _runtime_bound:
		return 1 if _runtime == null else -1
	var owner: StadiumWaterfallAnimationRuntime = runtime_owner()
	if (
		owner == null
		or owner._lease != self
		or owner._property != _property
		or not is_instance_valid(_property)
		or _property.get_script() != StadiumWaterfallAnimationProperty
		or not (_property as StadiumWaterfallAnimationProperty)._issued_ever
		or not (_property as StadiumWaterfallAnimationProperty)._issued_live
		or not owner._binding_intact()
	):
		return -1
	var lab: PitchBatLab = owner._lab.get_ref() as PitchBatLab
	if lab == null:
		return -1
	return 0 if owner.actionable() or lab._debug_paused or owner.get_tree().paused else 1


func _property_deep_intact() -> bool:
	if not is_instance_valid(_property):
		return false
	return (
		(_property as StadiumWaterfallAnimationProperty).deep_props_intact()
		if _property.get_script() == StadiumWaterfallAnimationProperty
		else _property.props_intact()
	)


func advance(delta: float, actionable: bool, paused: bool) -> bool:
	if (
		not is_finite(delta)
		or delta < 0
		or not _phase_presentation_intact()
		or (not _runtime_bound and not _property_deep_intact())
	):
		retire()
		return false
	var gate: int = _runtime_gate()
	if gate < 0:
		retire()
		return false
	if (
		gate == 0
		or delta > 0.25
		or actionable
		or paused
		or (_property.is_inside_tree() and _property.get_tree().paused)
	):
		return true
	return _write(fposmod(phase + delta * SPEED, 1.0))


func reset() -> bool:
	if not _phase_presentation_intact() or (not _runtime_bound and not _property_deep_intact()):
		retire()
		return false
	var gate: int = _runtime_gate()
	if gate < 0:
		retire()
		return false
	return true if gate == 0 else _write(0.0)


func _write(value: float) -> bool:
	if (
		_writing
		or not is_finite(value)
		or value < 0
		or value >= 1
		or not _phase_presentation_intact()
	):
		retire()
		return false
	var gate: int = _runtime_gate()
	if gate < 0:
		retire()
		return false
	if gate == 0:
		return true
	_writing = true
	# Always write the original sealed targets, never the mutable _tokens table.
	for token: Dictionary in _phase_rows:
		# No foreign listener can execute during this synchronous write. Only the
		# exact phase material's retirement callback is disconnected, then restored.
		# Meshes, shaders, collision shapes and other materials remain guarded.
		if token.live:
			token.material.changed.disconnect(token.callback)
		for ref: Dictionary in token.refs:
			if ref.kind == "array":
				ref.values[ref.phase_index] = value
			else:
				ref.fields[PHASE] = value
		token.material.set_shader_parameter("phase", value)
		if token.live and token.material.changed.connect(token.callback) != OK:
			_writing = false
			retire()
			return false
	_expected_phase = value
	phase = value
	_writing = false
	if not _phase_presentation_intact():
		retire()
		return false
	return true


func retire() -> void:
	retired = true
	if is_instance_valid(_property):
		_property._retire_props()
