class_name StadiumPoolCompactV43LegacyOracle
extends RefCounted
## Owned-only policy 2. Exact finite gameplay state; rendering resources are not authority.
# gdlint: disable=max-returns

const VERSION: int = 2
const POLICY: String = "PAID_POOL_GAMEPLAY_INTEGRITY_v2"
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


static func capture(
	lab: Node3D, property: Node3D, model: Node3D, boundary: Node3D, ground: StaticBody3D,
	receiver_chair: Node3D
) -> StadiumPoolCompactV43LegacyOracle:
	if not _alive(lab) or not _alive(property) or not _alive(model) or not _alive(boundary):
		return null
	if (
		not _alive(ground) or not _alive(receiver_chair)
		or not property.is_ancestor_of(model)
	):
		return null
	var result: StadiumPoolCompactV43LegacyOracle = StadiumPoolCompactV43LegacyOracle.new()
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
	result._boundary_bytes = var_to_bytes(boundary_rows)
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
	return {
		"policy": POLICY, "version": VERSION, "source_sha256": _source,
		"descriptor_scope": "INSTALLATION_FINITE_GAMEPLAY_SEALS",
		"live_comparison_not_performed": true,
		"model_descriptor_sha256": _model_bytes.hex_encode().sha256_text(),
		"boundary_descriptor_sha256": _boundary_bytes.hex_encode().sha256_text(),
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
		var meta: Array = _metadata(node)
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
	var meta: Array = _metadata(node)
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
