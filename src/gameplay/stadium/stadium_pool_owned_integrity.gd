class_name StadiumPoolOwnedIntegrity
extends RefCounted
## Owned-only policy 2. Exact finite gameplay state; rendering resources are not authority.
# gdlint: disable=max-returns

const VERSION: int = 2
const POLICY: String = "PAID_POOL_GAMEPLAY_INTEGRITY_v2"
const INTERIOR_SOURCE_PATH: String = "res://src/gameplay/stadium/stadium_pool_interior_v2.gd"
const META_KEYS: Array[StringName] = [
	&"surface_id", &"surface_role", &"stadium_item", &"owned_copy", &"ball_surface",
	&"boundary_segment", &"geometry_version", &"model_id", &"placement_role",
	&"water_geometry_id", &"water_source_sha256", &"water_award_active", &"runtime_adapter",
	&"volume_id", &"volume_role", &"descriptor"
]

var _lab: WeakRef
var _property: WeakRef
var _model_ref: WeakRef
var _model_id: int = 0
var _boundary_id: int = 0
var _ground_id: int = 0
var _receiver_id: int = 0
var _receiver_visual_id: int = 0
var _node_scripts: Dictionary = {}
var _body_bytes: Dictionary = {}
var _inventory_ids: PackedByteArray
var _topology_bytes: PackedByteArray
var _ancestor_bytes: PackedByteArray
var _model_bytes: PackedByteArray
var _boundary_bytes: PackedByteArray
var _source: String = ""
var _compact_audit_captured: bool = false
var _audit_model_bytes: PackedByteArray
var _audit_boundary_bytes: PackedByteArray
# V71: this is an installation plan, never a cached successful live observation.
var _owner_scene_admitted: bool = false
var _owner_scene_model_id: int = 0
var _owner_scene_receiver_id: int = 0
var _owner_scene_receiver_visual_id: int = 0
var _owner_scene_nodes: Array[Dictionary] = []
var _owner_scene_index: Dictionary = {}
var _owner_scene_topology: PackedInt32Array
var _owner_scene_boundary: PackedInt32Array
# V74: separate membership; the original owner-only tree flags never grow.
var _owner_scene_model: PackedInt32Array
var _owner_scene_bodies: Dictionary = {}
var _owner_scene_ancestors: Array[Dictionary] = []
var _owner_scene_sources: Array[Dictionary] = []



static func capture(
	lab: Node3D, property: Node3D, model: Node3D, boundary: Node3D, ground: StaticBody3D,
	receiver_chair: Node3D
) -> StadiumPoolOwnedIntegrity:
	if not _alive(lab) or not _alive(property) or not _alive(model) or not _alive(boundary):
		return null
	if (
		not _alive(ground) or not _alive(receiver_chair)
		or not property.is_ancestor_of(model)
	):
		return null
	var result: StadiumPoolOwnedIntegrity = StadiumPoolOwnedIntegrity.new()
	result._lab = weakref(lab)
	result._property = weakref(property)
	result._model_ref = weakref(model)
	result._model_id = model.get_instance_id()
	result._boundary_id = boundary.get_instance_id()
	result._ground_id = ground.get_instance_id()
	result._receiver_id = receiver_chair.get_instance_id()
	var visual: Node3D = receiver_chair.get_node_or_null("Visual") as Node3D
	if not _alive(visual):
		return null
	result._receiver_visual_id = visual.get_instance_id()
	result._source = String(model.get_meta("water_source_sha256", ""))
	result._register_nodes(property)
	var ids: Array[int] = []
	for body: StaticBody3D in lab.find_children("*", "StaticBody3D", true, false):
		result._register_nodes(body)
		var rows: Array = result._tree(body)
		if rows.is_empty():
			return null
		ids.append(body.get_instance_id())
		result._body_bytes[body.get_instance_id()] = var_to_bytes(rows)
	var topology: Array = result._topology(property)
	var model_rows: Array = result._tree(model)
	var boundary_rows: Array = result._tree(boundary)
	if topology.is_empty() or model_rows.is_empty() or boundary_rows.is_empty():
		return null
	if not result._body_bytes.has(result._ground_id):
		return null
	result._inventory_ids = var_to_bytes(ids)
	result._topology_bytes = var_to_bytes(topology)
	result._ancestor_bytes = var_to_bytes(_ancestors(property))
	result._model_bytes = var_to_bytes(model_rows)
	result._audit_model_bytes = StadiumPoolOwnedIntegrity._tree_legacy_bytes(model_rows)
	result._boundary_bytes = var_to_bytes(boundary_rows)
	result._audit_boundary_bytes = StadiumPoolOwnedIntegrity._tree_legacy_bytes(boundary_rows)
	result._compact_audit_captured = true
	result._capture_owner_scene(lab, property, model, boundary)
	return result


func valid_inventory(lab: Node3D) -> bool:
	if not _alive(lab) or _lab == null or _lab.get_ref() != lab:
		return false
	var property: Node3D = _property.get_ref() as Node3D
	if not _alive(property) or var_to_bytes(_ancestors(property)) != _ancestor_bytes:
		return false
	var topology: Array = _topology(property)
	if topology.is_empty() or var_to_bytes(topology) != _topology_bytes:
		return false
	var bodies: Array[Node] = lab.find_children("*", "StaticBody3D", true, false)
	var ids: Array[int] = []
	for body: Node in bodies:
		ids.append(body.get_instance_id())
	if var_to_bytes(ids) != _inventory_ids:
		return false
	for body: StaticBody3D in bodies:
		if not valid_body(body):
			return false
	return true


func valid_body(body: StaticBody3D) -> bool:
	if not _alive(body) or not _body_bytes.has(body.get_instance_id()):
		return false
	var rows: Array = _tree(body)
	return not rows.is_empty() and var_to_bytes(rows) == _body_bytes[body.get_instance_id()]


func valid_ground(body: StaticBody3D) -> bool:
	return _alive(body) and body.get_instance_id() == _ground_id and valid_body(body)


func valid_boundary(boundary: Node3D) -> bool:
	if not _alive(boundary) or boundary.get_instance_id() != _boundary_id:
		return false
	var rows: Array = _tree(boundary)
	return not rows.is_empty() and var_to_bytes(rows) == _boundary_bytes


func valid_model(model: Node3D) -> bool:
	if not _alive(model) or model.get_instance_id() != _model_id:
		return false
	var rows: Array = _tree(model)
	return not rows.is_empty() and var_to_bytes(rows) == _model_bytes


func audit_receipt() -> Dictionary:
	# These are installation seals, never a claim of continuous whole-visual equality.
	var model_bytes: PackedByteArray = _model_bytes
	var boundary_bytes: PackedByteArray = _boundary_bytes
	if get_script() == StadiumPoolOwnedIntegrity and _compact_audit_captured:
		model_bytes = _audit_model_bytes
		boundary_bytes = _audit_boundary_bytes
	return {
		"policy": POLICY, "version": VERSION, "source_sha256": _source,
		"descriptor_scope": "INSTALLATION_FINITE_GAMEPLAY_SEALS",
		"live_comparison_not_performed": true,
		"model_descriptor_sha256": model_bytes.hex_encode().sha256_text(),
		"boundary_descriptor_sha256": boundary_bytes.hex_encode().sha256_text(),
		"inventory_ids_sha256": _inventory_ids.hex_encode().sha256_text(),
		"body_count": _body_bytes.size()
	}


func _register_nodes(node: Node) -> void:
	_node_scripts[node.get_instance_id()] = _script_id(node)
	for child: Node in node.get_children(true):
		_register_nodes(child)


func _known_node(node: Node) -> bool:
	return (
		_alive(node) and _node_scripts.has(node.get_instance_id())
		and _script_id(node) == _node_scripts[node.get_instance_id()]
	)


func _topology(node: Node) -> Array:
	# Only installed property descendants: genuine ball/actors are outside this exclusion.
	if not _known_node(node) or (node is CollisionObject3D and not node is StaticBody3D):
		return []
	var row: Array = [_node_row(node)]
	# Model/carrier pose and metadata stay at the original InteriorV2 boundary.
	# The original receiver Visual rotation.z is the only authored rocking motion.
	var model: Node = _model_ref.get_ref() as Node if _model_ref != null else null
	if not _alive(model):
		return []
	if node is Node3D and node != model and not model.is_ancestor_of(node):
		if node.get_instance_id() == _receiver_visual_id:
			row.append([node.position, node.scale, node.rotation.x, node.rotation.y])
		else:
			row.append([node.transform])
	if node.get_instance_id() == _receiver_id:
		var meta: Array
		if get_script() == StadiumPoolOwnedIntegrity:
			meta = StadiumPoolOwnedIntegrity._metadata_compact(node)
		else:
			meta = _metadata(node)
		if meta.is_empty():
			return []
		row.append(meta)
	var rows: Array = [row]
	for child: Node in node.get_children(true):
		var children: Array = _topology(child)
		if children.is_empty():
			return []
		rows.append_array(children)
	return rows


func _tree(node: Node) -> Array:
	if not _known_node(node) or (node is CollisionObject3D and not node is StaticBody3D):
		return []
	var meta: Array
	if get_script() == StadiumPoolOwnedIntegrity:
		meta = StadiumPoolOwnedIntegrity._metadata_compact(node)
	else:
		meta = _metadata(node)
	if meta.is_empty():
		return []
	var row: Array = [_node_row(node), meta]
	if node is Node3D:
		row.append([node.transform, node.global_transform])
	if node is StaticBody3D:
		var body: Array = _body(node)
		if body.is_empty():
			return []
		row.append(body)
	elif node is CollisionShape3D:
		if node.get_class() != "CollisionShape3D" or node.get_script() != null:
			return []
		var shape: Array = _shape(node.shape)
		if shape.is_empty():
			return []
		row.append([node.disabled, shape])
	var rows: Array = [row]
	for child: Node in node.get_children(true):
		var children: Array = _tree(child)
		if children.is_empty():
			return []
		rows.append_array(children)
	return rows


static func _node_row(node: Node) -> Array:
	var world: Array = []
	if node is Node3D:
		var value: World3D = node.get_world_3d()
		world = [value.get_instance_id(), value.space.get_id()]
	return [
		node.get_instance_id(), node.get_parent().get_instance_id(), node.get_class(), node.name,
		_script_id(node), node.process_mode, node.process_thread_group, world
	]


static func _metadata(node: Node) -> Array:
	var rows: Array = []
	rows.resize(META_KEYS.size())
	var index: int = 0
	for key: StringName in META_KEYS:
		var present: bool = node.has_meta(key)
		var value: Variant = node.get_meta(key) if present else null
		if present:
			if key == &"descriptor":
				if not _descriptor_shape(value):
					return []
			elif typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT,
				TYPE_STRING, TYPE_STRING_NAME]:
				return []
		rows[index] = [key, present, value]
		index += 1
	return rows


static func _metadata_compact(node: Node) -> Array:
	var rows: Array = []
	rows.resize(META_KEYS.size() * 2)
	var index: int = 0
	for key: StringName in META_KEYS:
		var present: bool = node.has_meta(key)
		var value: Variant = node.get_meta(key) if present else null
		if present:
			if key == &"descriptor":
				if not _descriptor_shape(value):
					return []
			elif typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT,
				TYPE_STRING, TYPE_STRING_NAME]:
				return []
		rows[index] = present
		rows[index + 1] = value
		index += 2
	return rows


static func _metadata_expand(rows: Array) -> Array:
	# Finite inverse of a successful compact block; values retain their native aliases.
	var expanded: Array = []
	expanded.resize(META_KEYS.size())
	for index: int in range(META_KEYS.size()):
		expanded[index] = [META_KEYS[index], rows[index * 2], rows[index * 2 + 1]]
	return expanded


static func _tree_legacy_bytes(rows: Array) -> PackedByteArray:
	# Capture-only provenance at the original serialization point, never live authority.
	var expanded: Array = []
	expanded.resize(rows.size())
	for index: int in range(rows.size()):
		var row: Array = rows[index].duplicate()
		row[1] = StadiumPoolOwnedIntegrity._metadata_expand(row[1])
		expanded[index] = row
	return var_to_bytes(expanded)


static func _descriptor_shape(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 12:
		return false
	for key: Variant in value:
		if not key is String:
			return false
		if typeof(value[key]) not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING,
			TYPE_PACKED_VECTOR2_ARRAY]:
			return false
	return true


static func _body(body: StaticBody3D) -> Array:
	if body.get_class() != "StaticBody3D" or body.get_script() != null:
		return []
	var material: Array = []
	var physical: PhysicsMaterial = body.physics_material_override
	if physical != null:
		if physical.get_class() != "PhysicsMaterial" or physical.get_script() != null:
			return []
		material = [physical.get_class(), physical.friction, physical.bounce,
			physical.rough, physical.absorbent]
	var exceptions: Array[int] = []
	for other: PhysicsBody3D in body.get_collision_exceptions():
		exceptions.append(other.get_instance_id() if is_instance_valid(other) else 0)
	var owners: Array = _owners(body)
	if owners.is_empty():
		return []
	return [
		body.collision_layer, body.collision_mask, body.collision_priority, body.disable_mode,
		body.constant_linear_velocity, body.constant_angular_velocity, material, exceptions, owners
	]


static func _owners(body: StaticBody3D) -> Array:
	var shapes: Array[CollisionShape3D] = []
	for child: Node in body.get_children(true):
		if child is CollisionShape3D:
			shapes.append(child)
	var ids: PackedInt32Array = body.get_shape_owners()
	if ids.size() != shapes.size() or ids.is_empty():
		return []
	var rows: Array = []
	for id: int in ids:
		var owner: CollisionShape3D = body.shape_owner_get_owner(id) as CollisionShape3D
		if owner == null or not shapes.has(owner) or owner.get_script() != null:
			return []
		if body.shape_owner_get_shape_count(id) != 1:
			return []
		var resource: Shape3D = body.shape_owner_get_shape(id, 0)
		if resource != owner.shape:
			return []
		var data: Array = _shape(resource)
		if data.is_empty():
			return []
		rows.append([id, owner.get_instance_id(), body.shape_owner_get_transform(id),
			body.is_shape_owner_disabled(id), data])
		shapes.erase(owner)
	return rows if shapes.is_empty() else []


static func _shape(shape: Shape3D) -> Array:
	if shape == null or shape.get_script() != null:
		return []
	var geometry: Array = []
	match shape.get_class():
		"BoxShape3D":
			geometry = [(shape as BoxShape3D).size]
		"ConvexPolygonShape3D":
			geometry = [(shape as ConvexPolygonShape3D).points]
		"ConcavePolygonShape3D":
			var concave: ConcavePolygonShape3D = shape as ConcavePolygonShape3D
			geometry = [concave.get_faces(), concave.backface_collision]
		_:
			return []
	return [shape.get_class(), shape.margin, shape.custom_solver_bias, geometry]


static func _script_id(object: Object) -> int:
	var script: Script = object.get_script() as Script
	return script.get_instance_id() if script != null else 0


static func _alive(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()


static func _ancestors(node: Node) -> Array:
	var rows: Array = []
	var ancestor: Node = node.get_parent()
	while ancestor != null:
		rows.append([ancestor.get_instance_id(), _script_id(ancestor),
			ancestor.process_mode, ancestor.process_thread_group,
			ancestor.is_queued_for_deletion()])
		ancestor = ancestor.get_parent()
	return rows


static func owner_scene_admitted(context: StadiumPoolOwnedIntegrity) -> bool:
	# Decide the fallback before any optimized scene reads. Subclasses keep virtual routes.
	return context != null and context.get_script() == StadiumPoolOwnedIntegrity \
		and context._owner_scene_admitted


static func owner_scene_matches(context: StadiumPoolOwnedIntegrity, lab: Node3D,
	property: Node3D, boundary: Node3D, ground: StaticBody3D,
	boundary_ids: PackedInt64Array, ground_ids: PackedInt64Array, include_model: bool = false,
	checked_model: Node3D = null, model_ids: PackedInt64Array = [],
	guard_request: Dictionary = {}) -> bool:
	# One fresh synchronous observation discharges overlapping role obligations. The
	# original repeated-read order/failure prefix is intentionally not preserved.
	if not StadiumPoolOwnedIntegrity.owner_scene_admitted(context):
		return false
	if not _alive(lab) or context._lab.get_ref() != lab \
		or not _alive(property) or context._property.get_ref() != property \
		or not _alive(boundary) or boundary.get_instance_id() != context._boundary_id \
		or not _alive(ground) or ground.get_instance_id() != context._ground_id \
		or ground.get_parent() != property:
		return false
	var model: Node = context._model_ref.get_ref() as Node if context._model_ref != null else null
	if not _alive(model) or model.get_instance_id() != context._owner_scene_model_id \
		or context._receiver_id != context._owner_scene_receiver_id \
		or context._receiver_visual_id != context._owner_scene_receiver_visual_id:
		return false
	if include_model and (model != checked_model or model.get_instance_id() != context._model_id):
		return false
	# All scripts and ancestor links are checked before named-property/metadata reads.
	# Source equality detects live edits, not arbitrary same-source compiled reloads.
	for record: Dictionary in context._owner_scene_sources:
		var script: GDScript = record.script
		if script.get_script() != null or script.get_base_script() != record.base \
			or script.source_code != record.source:
			return false
	var previous: Node = property
	for record: Dictionary in context._owner_scene_ancestors:
		var ancestor: Node = record.ref.get_ref() as Node
		if not is_instance_valid(ancestor) or previous.get_parent() != ancestor \
			or ancestor.get_instance_id() != record.id \
			or ancestor.get_script() != record.script or ancestor.get_class() != record.native:
			return false
		previous = ancestor
	if previous.get_parent() != null:
		return false
	var nodes: Array[Node] = []
	for record: Dictionary in context._owner_scene_nodes:
		var node: Node = record.ref.get_ref() as Node
		if not _alive(node) or node.get_instance_id() != record.id \
			or node.get_script() != record.script or node.get_class() != record.native \
			or not context._node_scripts.has(record.id) \
			or context._node_scripts[record.id] != _script_id(node) \
			or node.get_parent() == null or node.get_parent().get_instance_id() != record.parent \
			or not StadiumPoolOwnedIntegrity._owner_scene_plain_world(node):
			return false
		nodes.append(node)
	if var_to_bytes(_ancestors(property)) != context._ancestor_bytes:
		return false
	var observations: Array[Dictionary] = []
	for index: int in range(nodes.size()):
		var observed: Dictionary = StadiumPoolOwnedIntegrity._owner_scene_observe(
			nodes[index], context._owner_scene_nodes[index], include_model)
		if observed.is_empty():
			return false
		observations.append(observed)
	# Child geometry is observed once and reused by shape-owner attachment/geometry
	# comparisons. All observations remain local to this invocation.
	for index: int in range(nodes.size()):
		var record: Dictionary = context._owner_scene_nodes[index]
		if nodes[index] is StaticBody3D and (record.tree or (include_model and record.model_tree)):
			var body: Array = StadiumPoolOwnedIntegrity._owner_scene_body(
				nodes[index], observations[index].children, observations,
				context._owner_scene_index)
			if body.is_empty():
				return false
			observations[index].tree.append(body)
	if StadiumPoolOwnedIntegrity._owner_scene_ids(
		context._owner_scene_boundary, observations) != boundary_ids:
		return false
	var ground_role: PackedInt32Array = context._owner_scene_bodies[context._ground_id]
	if StadiumPoolOwnedIntegrity._owner_scene_ids(ground_role, observations) != ground_ids:
		return false
	if StadiumPoolOwnedIntegrity._owner_scene_bytes(context._owner_scene_boundary,
		observations, "tree") != context._boundary_bytes:
		return false
	if StadiumPoolOwnedIntegrity._owner_scene_bytes(context._owner_scene_topology,
		observations, "topology") != context._topology_bytes:
		return false
	# Required whole-lab live discovery: an installed-node-only scan cannot replace it.
	var bodies: Array[Node] = lab.find_children("*", "StaticBody3D", true, false)
	var ids: Array[int] = []
	for body: Node in bodies:
		ids.append(body.get_instance_id())
	if var_to_bytes(ids) != context._inventory_ids:
		return false
	for id: int in ids:
		if StadiumPoolOwnedIntegrity._owner_scene_bytes(context._owner_scene_bodies[id],
			observations, "tree") != context._body_bytes[id]:
			return false
	if include_model:
		if StadiumPoolOwnedIntegrity._owner_scene_ids(
			context._owner_scene_model, observations) != model_ids:
			return false
		if StadiumPoolOwnedIntegrity._owner_scene_bytes(context._owner_scene_model,
			observations, "tree") != context._model_bytes:
			return false
	if not guard_request.is_empty():
		if not include_model or guard_request.policy != context:
			return true
		for id: int in guard_request.bodies:
			if not ids.has(id) or nodes[context._owner_scene_index[id]] != guard_request.bodies[id]:
				return true
		guard_request.observed = true
	return true


func _capture_owner_scene(lab: Node3D, property: Node3D, model: Node3D,
	boundary: Node3D) -> void:
	# Cold eligibility only. Unsupported accessors select the complete original path.
	# The two edited scripts are authenticated by the reviewed external runtime map.
	var trusted: Dictionary = {
		"res://src/gameplay/stadium/stadium_pool_owned_integrity.gd": "",
		"res://src/presentation/stadium/stadium_pool_owned_property.gd": "",
		"res://src/presentation/stadium/stadium_pool_bound_property.gd":
			"d4aa763cac7a47376bd9b2e9768ac06061d98455c62d06f0b5420fd7c99382d1",
		"res://src/presentation/stadium/stadium_property_geometry.gd":
			"e2216c4b515f02794b577c0494248bd0f40503b86c099bcc2e2a734cf8a9fa16",
		"res://src/presentation/stadium/stadium_boundary_prototype.gd":
			"5b7e8fe60a44b875e5e0e66ce2fe3d8a995e4482c8de79dedbaabcb9adc0d88a",
		"res://src/presentation/stadium/stadium_pitch_receiver.gd":
			"743274083e25dbc6ff7c0bcb57a531d8e2c72c53ef43920a9f7a4afe167203a3"
	}
	var scripts: Dictionary = {}
	for path: String in trusted:
		var script: GDScript = load(path) as GDScript
		if script == null or script.get_script() != null or not script.has_source_code():
			return
		var digest: String = trusted[path]
		if not digest.is_empty() and script.source_code.sha256_text() != digest:
			return
		scripts[path] = script
		if not _owner_scene_source(script):
			return
	if property.get_script() != scripts[
		"res://src/presentation/stadium/stadium_pool_owned_property.gd"]:
		return
	var base: GDScript = scripts["res://src/presentation/stadium/stadium_pool_bound_property.gd"]
	var geometry: GDScript = scripts["res://src/presentation/stadium/stadium_property_geometry.gd"]
	if property.get_script().get_base_script() != base or base.get_base_script() != geometry \
		or geometry.get_base_script() != null:
		return
	for path: String in ["res://src/presentation/stadium/stadium_boundary_prototype.gd",
		"res://src/presentation/stadium/stadium_pitch_receiver.gd"]:
		if scripts[path].get_base_script() != null:
			return
	# Native method calls are direct MethodBind calls in the pinned engine. Named
	# ancestor properties are not: exclude all compiled instance/static hooks first.
	var ancestor: Node = property.get_parent()
	while ancestor != null:
		if ancestor.get_class() not in ["Node", "Node3D", "Control", "SubViewport", "Window"]:
			return
		var ancestor_script: Script = ancestor.get_script() as Script
		if ancestor_script != null and not _owner_scene_ancestor_script(ancestor_script):
			return
		_owner_scene_ancestors.append({"ref": weakref(ancestor),
			"id": ancestor.get_instance_id(), "script": ancestor_script,
			"native": ancestor.get_class()})
		ancestor = ancestor.get_parent()
	_owner_scene_topology = _owner_scene_add(property, model, true, false, scripts)
	_owner_scene_boundary = _owner_scene_add(boundary, model, false, true, scripts)
	if _owner_scene_topology.is_empty() or _owner_scene_boundary.is_empty():
		return
	var ids: Array[int] = []
	for body: StaticBody3D in lab.find_children("*", "StaticBody3D", true, false):
		var role: PackedInt32Array = _owner_scene_add(body, model, false, true, scripts)
		if role.is_empty():
			return
		ids.append(body.get_instance_id())
		_owner_scene_bodies[body.get_instance_id()] = role
	if var_to_bytes(ids) != _inventory_ids or not _owner_scene_bodies.has(_ground_id):
		return
	_owner_scene_model = _owner_scene_add(model, model, false, false, scripts, true)
	if _owner_scene_model.is_empty():
		return
	_owner_scene_model_id = model.get_instance_id()
	_owner_scene_receiver_id = _receiver_id
	_owner_scene_receiver_visual_id = _receiver_visual_id
	_owner_scene_admitted = true


func _owner_scene_source(script: GDScript) -> bool:
	if script.get_class() != "GDScript" or script.get_script() != null \
		or not script.has_source_code() or not script.can_instantiate():
		return false
	for record: Dictionary in _owner_scene_sources:
		if record.script == script:
			return true
	_owner_scene_sources.append({"script": script, "source": script.source_code,
		"base": script.get_base_script()})
	return true


func _owner_scene_ancestor_script(value: Script) -> bool:
	var current: Script = value
	while current != null:
		if not current is GDScript or not _owner_scene_source(current):
			return false
		# These native APIs enumerate compiled declarations without invoking getters.
		# get_script_property_list omits static members; get_property_list covers them.
		for method: Dictionary in current.get_script_method_list():
			if typeof(method.get("name")) not in [TYPE_STRING, TYPE_STRING_NAME]:
				return false
			if method.name == "_get":
				return false
		for fields: Array in [current.get_script_property_list(), current.get_property_list()]:
			for field: Dictionary in fields:
				if typeof(field.get("name")) not in [TYPE_STRING, TYPE_STRING_NAME]:
					return false
				if field.name in ["process_mode", "process_thread_group"]:
					return false
		current = current.get_base_script()
	return true


func _owner_scene_add(node: Node, model: Node3D, topology: bool, tree: bool,
	scripts: Dictionary, model_tree: bool = false) -> PackedInt32Array:
	if not _known_node(node) or not StadiumPoolOwnedIntegrity._owner_scene_plain_world(node) \
		or node.get_class() not in [
		"Node", "Node3D", "MeshInstance3D", "MultiMeshInstance3D",
		"StaticBody3D", "CollisionShape3D"]:
		return []
	var script: Script = node.get_script() as Script
	if script != null and script not in [
		scripts["res://src/presentation/stadium/stadium_pool_owned_property.gd"],
		scripts["res://src/presentation/stadium/stadium_boundary_prototype.gd"],
		scripts["res://src/presentation/stadium/stadium_pitch_receiver.gd"]]:
		return []
	if script != null and node.get_class() != "Node3D":
		return []
	var id: int = node.get_instance_id()
	var children: Array[Node] = node.get_children(true)
	var index: int
	if _owner_scene_index.has(id):
		index = _owner_scene_index[id]
		_owner_scene_nodes[index].tree = _owner_scene_nodes[index].tree or tree
		_owner_scene_nodes[index].model_tree = _owner_scene_nodes[index].model_tree or model_tree
	else:
		index = _owner_scene_nodes.size()
		_owner_scene_index[id] = index
		var child_ids: Array[int] = []
		for child: Node in children:
			child_ids.append(child.get_instance_id())
		var pose: int = 0
		if topology and node is Node3D and node != model and not model.is_ancestor_of(node):
			pose = 2 if id == _receiver_visual_id else 1
		_owner_scene_nodes.append({"ref": weakref(node), "id": id,
			"parent": node.get_parent().get_instance_id(), "native": node.get_class(),
			"script": script, "children": child_ids, "topology": topology,
			"pose": pose, "receiver": id == _receiver_id, "tree": tree,
			"model_tree": model_tree})
	var role: PackedInt32Array = [index]
	for child: Node in children:
		var child_role: PackedInt32Array = _owner_scene_add(
			child, model, topology, tree, scripts, model_tree)
		if child_role.is_empty():
			return []
		role.append_array(child_role)
	return role


static func _owner_scene_observe(node: Node, record: Dictionary,
	include_model: bool = false) -> Dictionary:
	var tree: bool = record.tree or (include_model and record.model_tree)
	var children: Array[Node] = node.get_children(true)
	var child_ids: Array[int] = []
	for child: Node in children:
		child_ids.append(child.get_instance_id())
	if child_ids != record.children:
		return {}
	var node_row: Array = _node_row(node)
	var meta: Array = []
	if tree or record.receiver:
		meta = StadiumPoolOwnedIntegrity._metadata_compact(node)
		if meta.is_empty():
			return {}
	var result: Dictionary = {"id": record.id, "children": children,
		"topology": [], "tree": [], "shape_ref": null, "shape": []}
	var local: Transform3D
	if node is Node3D and (tree or record.pose == 1):
		local = node.transform
	if record.topology:
		var row: Array = [node_row]
		if record.pose == 1:
			row.append([local])
		elif record.pose == 2:
			var rotation: Vector3 = node.rotation
			row.append([node.position, node.scale, rotation.x, rotation.y])
		if record.receiver:
			row.append(meta)
		result.topology = row
	if tree:
		var row: Array = [node_row, meta]
		if node is Node3D:
			row.append([local, node.global_transform])
		if node is CollisionShape3D:
			var resource: Shape3D = node.shape
			var shape: Array = _shape(resource)
			if shape.is_empty():
				return {}
			result.shape_ref = resource
			result.shape = shape
			row.append([node.disabled, shape])
		result.tree = row
	return result


static func _owner_scene_body(body: StaticBody3D, children: Array[Node],
	observations: Array[Dictionary], index: Dictionary) -> Array:
	var material: Array = []
	var physical: PhysicsMaterial = body.physics_material_override
	if physical != null:
		if physical.get_class() != "PhysicsMaterial" or physical.get_script() != null:
			return []
		material = [physical.get_class(), physical.friction, physical.bounce,
			physical.rough, physical.absorbent]
	var exceptions: Array[int] = []
	for other: PhysicsBody3D in body.get_collision_exceptions():
		exceptions.append(other.get_instance_id() if is_instance_valid(other) else 0)
	var shapes: Array[CollisionShape3D] = []
	for child: Node in children:
		if child is CollisionShape3D:
			shapes.append(child)
	var ids: PackedInt32Array = body.get_shape_owners()
	if ids.size() != shapes.size() or ids.is_empty():
		return []
	var owners: Array = []
	for id: int in ids:
		var owner: CollisionShape3D = body.shape_owner_get_owner(id) as CollisionShape3D
		if owner == null or not shapes.has(owner) or not index.has(owner.get_instance_id()):
			return []
		if body.shape_owner_get_shape_count(id) != 1:
			return []
		var observed: Dictionary = observations[index[owner.get_instance_id()]]
		if body.shape_owner_get_shape(id, 0) != observed.shape_ref or observed.shape.is_empty():
			return []
		owners.append([id, owner.get_instance_id(), body.shape_owner_get_transform(id),
			body.is_shape_owner_disabled(id), observed.shape])
		shapes.erase(owner)
	if not shapes.is_empty():
		return []
	return [
		body.collision_layer, body.collision_mask, body.collision_priority, body.disable_mode,
		body.constant_linear_velocity, body.constant_angular_velocity, material, exceptions, owners
	]


static func _owner_scene_bytes(role: PackedInt32Array, observations: Array[Dictionary],
	key: String) -> PackedByteArray:
	var rows: Array = []
	for index: int in role:
		rows.append(observations[index][key])
	return var_to_bytes(rows)


static func _owner_scene_ids(role: PackedInt32Array,
	observations: Array[Dictionary]) -> PackedInt64Array:
	var ids: PackedInt64Array = []
	for index: int in role:
		ids.append(observations[index].id)
	return ids



static func capture_owner_model_plan(interior: Variant,
	property: Variant, lab: Variant) -> Dictionary:
	# Unsupported installations keep the complete old route. This is a source/domain
	# plan only: no scene observations or successful validation survive an invocation.
	if not interior is RefCounted or interior.get_class() != "RefCounted" \
		or interior.get_script() != load(INTERIOR_SOURCE_PATH) \
		or not is_instance_valid(property) or not property is Node3D \
		or property.get_script() != load(
			"res://src/presentation/stadium/stadium_pool_owned_property.gd") \
		or not is_instance_valid(lab) or not lab is Node3D \
		or lab.get_script() != load("res://src/labs/pitch_bat_lab/pitch_bat_lab.gd"):
		return {}
	var trusted: Dictionary = {
		"res://src/gameplay/stadium/stadium_pool_interior_v2.gd": "",
		"res://src/gameplay/stadium/stadium_pool_owned_integrity.gd": "",
		"res://src/presentation/stadium/stadium_pool_owned_property.gd": "",
		"res://src/gameplay/stadium/stadium_pool_owned_field_integrity.gd":
			"9698c145eb3ac76a04e24d8ea2fd8d22c454bc970a7ec2fb4a7ab12a129929f1",
		"res://src/content/definitions/field_definition.gd":
			"39cf09ce92b00c8c0d784f5e738623b810b512a12c3b3c9294a5133b33f413d2",
		"res://src/content/definitions/definition_base.gd":
			"d03b3f1f855f51f1f2e3a99f1be99a626cfe523e39c76bd9576b16cb6af4876f",
		"res://src/presentation/fielding/fielder_controller.gd":
			"7990e084d114bff4d878607691aabdb3741d24eaff4e7fd017d053217ffa6d82",
		"res://src/gameplay/ball_in_play/ball_play_resolver.gd":
			"614f8f566e37d9317e6644384aa8ef7c382f6d0c9b5d448cacdf6d98ed9e83fd",
		"res://src/labs/pitch_bat_lab/pitch_bat_lab.gd":
			"95a9afd11cc1a05e8c6f0acc58bf795821958c1b211889c75a477261c16977b2",
		"res://src/gameplay/stadium/stadium_pool_owned_layout.gd":
			"afc12a99b34a8aa154ec76db718356589d88d72b3d6efa70b16f16d40e619fa9",
		"res://src/gameplay/season/season_ownership.gd":
			"73ca7c3b92da09e934d86be5d69f746017aefd0f6b9309cf801a31fb98968973",
		"res://src/gameplay/stadium/stadium_starter_layout.gd":
			"155d13d6f548abcaab99d13516d51540f443cff3b2fcdc357da9e138b16c4509",
		"res://src/gameplay/stadium/stadium_pool_bound_footprint.gd":
			"3ff1327858695251ba26e17b2c6d7bb7b23b2483c8123d8c576d5b35d6e63724",
		"res://src/gameplay/stadium/stadium_defender_routes.gd":
			"20ee83d92f23d2a021a34fd5b623793215f57157880dafbb95acb8febf813964",
		"res://src/gameplay/stadium/stadium_pool_contract.gd":
			"94f06f487e3d020d5b26441a252e3e1c38d493ec588df69cda8735f40e8db9bd",
		"res://src/gameplay/stadium/stadium_boundary_graph.gd":
			"0d7c7c9d81a3b5817bf6a04e66b092af946721b75e344134a90b1e0c1f4dcbda",
		"res://src/gameplay/stadium/stadium_boundary_observer.gd":
			"406b1050fd62c2077d6804ee28d23662dd88bf1b71c1ff786bab900d2391a08c"
	}
	var scripts: Dictionary = {}
	var sources: Array[Dictionary] = []
	for path: String in trusted:
		var script: GDScript = load(path) as GDScript
		if script == null or script.get_class() != "GDScript" or script.get_script() != null \
			or not script.has_source_code() or not script.can_instantiate():
			return {}
		var digest: String = trusted[path]
		if not digest.is_empty() and script.source_code.sha256_text() != digest:
			return {}
		var base: Script = script.get_base_script()
		if path == "res://src/content/definitions/field_definition.gd":
			if base != DefinitionBase:
				return {}
		elif path == "res://src/presentation/stadium/stadium_pool_owned_property.gd":
			if base != load("res://src/presentation/stadium/stadium_pool_bound_property.gd"):
				return {}
		elif base != null:
			return {}
		scripts[path] = script
		sources.append({"script": script, "source": script.source_code, "base": base})
	var integrity: StadiumPoolOwnedIntegrity = property.integrity_policy2
	if not StadiumPoolOwnedIntegrity.owner_scene_admitted(integrity):
		return {}
	# Include the already-authenticated property/base/geometry and ancestor sources
	# before accessing plain property members on any future combined-path selection.
	for record: Dictionary in integrity._owner_scene_sources:
		var found: bool = false
		for captured: Dictionary in sources:
			if captured.script == record.script:
				if captured.source != record.source or captured.base != record.base:
					return {}
				found = true
				break
		if not found:
			sources.append(record.duplicate())
	var plan: Dictionary = {"sources": sources, "scripts": scripts,
		"property": weakref(property), "lab": weakref(lab), "integrity": integrity}
	return plan if StadiumPoolOwnedIntegrity.owner_model_route(plan, interior) == 1 else {}


static func owner_model_route(plan: Dictionary, interior: Variant) -> int:
	# -1 means an admitted source breach; 0 means unsupported current objects and
	# selects the original route before observation; 1 admits one fresh combined call.
	# Check captured sources first so a custom replacement cannot hide a source edit.
	for record: Dictionary in plan.sources:
		var script: GDScript = record.script
		if script.get_class() != "GDScript" or script.get_script() != null \
			or script.get_base_script() != record.base or script.source_code != record.source:
			return -1
	if not interior is RefCounted or interior.get_class() != "RefCounted" \
		or interior.get_script() != plan.scripts[
			"res://src/gameplay/stadium/stadium_pool_interior_v2.gd"]:
		return 0
	var property: Variant = plan.property.get_ref()
	var lab: Variant = plan.lab.get_ref()
	if not is_instance_valid(property) or not property is Node3D \
		or property.get_script() != plan.scripts[
			"res://src/presentation/stadium/stadium_pool_owned_property.gd"] \
		or not is_instance_valid(lab) or not lab is Node3D \
		or lab.get_script() != plan.scripts["res://src/labs/pitch_bat_lab/pitch_bat_lab.gd"]:
		return 0
	if interior._owned_profile == null or interior._owned_profile.get_ref() != property \
		or interior._owned_lab == null or interior._owned_lab.get_ref() != lab \
		or property.integrity_policy2 != plan.integrity \
		or property.integrity_policy2.get_script() != plan.scripts[
			"res://src/gameplay/stadium/stadium_pool_owned_integrity.gd"] \
		or not StadiumPoolOwnedIntegrity.owner_scene_admitted(property.integrity_policy2):
		return 0
	var helper: Variant = property._field_integrity_v68
	if not is_instance_valid(helper) or helper.get_class() != "RefCounted" \
		or helper.get_script() != StadiumPoolOwnedFieldIntegrity \
		or not helper._admitted \
		or not StadiumPoolOwnedFieldIntegrity._plain_definition(property.field) \
		or not StadiumPoolOwnedFieldIntegrity._plain_definition(lab._field_definition):
		return 0
	if not StadiumPoolOwnedFieldIntegrity.sources_current(helper, property.field) \
		or not StadiumPoolOwnedFieldIntegrity.sources_current(helper, lab._field_definition):
		return -1
	if not is_instance_valid(lab._ball_play_resolver) \
		or lab._ball_play_resolver.get_class() != "RefCounted" \
		or lab._ball_play_resolver.get_script() != plan.scripts[
			"res://src/gameplay/ball_in_play/ball_play_resolver.gd"] \
		or not is_instance_valid(lab._primary_fielder) \
		or lab._primary_fielder.get_class() != "CharacterBody3D" \
		or lab._primary_fielder.get_script() != plan.scripts[
			"res://src/presentation/fielding/fielder_controller.gd"]:
		return 0
	return 1



static func capture_guard_body_plan(guard: Variant, interior: Variant) -> Dictionary:
	var script: GDScript = load("res://src/gameplay/stadium/stadium_pool_water_guard.gd") as GDScript
	if script == null or script.get_class() != "GDScript" or script.get_script() != null \
		or script.get_base_script() != null or not script.has_source_code() \
		or not script.can_instantiate() or not guard is RefCounted \
		or guard.get_class() != "RefCounted" or guard.get_script() != script \
		or not interior is RefCounted or interior.get_class() != "RefCounted" \
		or interior.get_script() != load(INTERIOR_SOURCE_PATH):
		return {}
	var model_plan: Dictionary = interior._owner_model_plan
	if model_plan.is_empty() or StadiumPoolOwnedIntegrity.owner_model_route(
		model_plan, interior) != 1:
		return {}
	return {"script": script, "source": script.source_code, "base": script.get_base_script(),
		"guard": weakref(guard), "interior": weakref(interior), "model_plan": model_plan}


static func guard_body_request(plan: Dictionary, guard: Variant) -> Dictionary:
	if plan.is_empty():
		return {}
	# Check source before named guard access; owner/model breaches still run Interior.valid.
	if not StadiumPoolOwnedIntegrity._guard_body_source_current(plan):
		return {"source_breach": true}
	if not guard is RefCounted or guard.get_class() != "RefCounted" \
		or guard.get_script() != plan.script or plan.guard.get_ref() != guard:
		return {}
	var interior: Variant = plan.interior.get_ref()
	if not is_instance_valid(interior) or guard._context != interior \
		or StadiumPoolOwnedIntegrity.owner_model_route(plan.model_plan, interior) != 1 \
		or plan.model_plan.integrity.get_class() != "RefCounted":
		return {}
	var policy: StadiumPoolOwnedIntegrity = plan.model_plan.integrity
	var bodies: Dictionary = guard._guard_body_refs(policy, guard._bodies)
	if bodies.size() != guard._bodies.size():
		return {}
	var request: Dictionary = {"plan": plan, "guard": guard, "interior": interior,
		"model": guard._model, "source": guard._source, "policy": policy, "bodies": bodies,
		"observed": false, "complete": false, "source_breach": false}
	return request if StadiumPoolOwnedIntegrity.guard_body_route(request) == 1 else {}


static func guard_body_route(request: Dictionary) -> int:
	var plan: Dictionary = request.plan
	if not StadiumPoolOwnedIntegrity._guard_body_source_current(plan):
		return -1
	var guard: Variant = request.guard
	var interior: Variant = request.interior
	if not guard is RefCounted or guard.get_class() != "RefCounted" \
		or guard.get_script() != plan.script or plan.guard.get_ref() != guard \
		or plan.interior.get_ref() != interior \
		or StadiumPoolOwnedIntegrity.owner_model_route(plan.model_plan, interior) != 1:
		return 0
	if guard._context != interior or guard._model != request.model \
		or guard._source != request.source or interior._owner_model_plan != plan.model_plan \
		or request.policy != plan.model_plan.integrity or request.policy.get_class() != "RefCounted":
		return 0
	var bodies: Dictionary = guard._guard_body_refs(request.policy, guard._bodies)
	if bodies.size() != guard._bodies.size() or bodies != request.bodies:
		return 0
	return 1


static func _guard_body_source_current(plan: Dictionary) -> bool:
	var script: GDScript = plan.script
	return script.get_class() == "GDScript" and script.get_script() == null \
		and script.get_base_script() == plan.base and script.source_code == plan.source


static func _owner_scene_plain_world(node: Node) -> bool:
	# _node_row reads World3D.space by name. Custom world getters keep the original
	# route at installation; live script attachment rejects before optimized reads.
	if not node is Node3D:
		return true
	var world: World3D = node.get_world_3d()
	return world != null and world.get_class() == "World3D" and world.get_script() == null
