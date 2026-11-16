class_name StadiumStraightStackSites
extends RefCounted
## Additive Working interface; frozen ST-029 has no retrofitted socket or metadata.

const INTERFACE: String = "ST029-v1_REAR-STAIR-SADDLE-v1"
const UPPER_INTERFACE: String = "ST031-v1_STRAIGHT-CANTILEVER-v1"
const SWAY: float = 0.04
const BOUNDS: AABB = AABB(Vector3(-3, 0, 0), Vector3(6, 12.2, 10))


static func fits(site: String, land: String) -> bool:
	return site in StadiumBaselineSites.SITES and land in ["club", "mogul"] \
		and StadiumProperty.contains(land, StadiumBaselineSites.pose(site) * BOUNDS)


static func valid_pose(piece: Node3D, site: String) -> bool:
	if site not in StadiumBaselineSites.SITES or not piece.is_inside_tree():
		return false
	var expected: Transform3D = StadiumBaselineSites.pose(site)
	var parent: Node3D = piece.get_parent() as Node3D
	return parent != null and parent.global_transform.is_equal_approx(Transform3D.IDENTITY) \
		and piece.transform.is_equal_approx(expected) \
		and piece.global_transform.is_equal_approx(expected)


static func valid_lower(lower: Node3D, site: String) -> bool:
	if not is_instance_valid(lower) or not lower.is_inside_tree() \
		or lower.get_meta("stadium_item", "") != "ST-029" or not valid_pose(lower, site):
		return false
	for occupied_value: bool in [false, true]:
		var reference: Node3D = StadiumBaselineStandModels.lower(occupied_value)
		var actual: String = geometry_signature(lower, reference)
		var matches: bool = not actual.is_empty() \
			and actual == geometry_signature(reference, reference)
		reference.free()
		if matches:
			return true
	return false


static func occupied(lower: Node3D, item: String, site: String) -> bool:
	for child: Node in lower.get_parent().get_children():
		if child.get_meta("stadium_item", "") != item:
			continue
		if child.get_meta("lower_instance", 0) == lower.get_instance_id() \
			or child.get_meta("site", "") == site \
			or (child is Node3D and child.transform.is_equal_approx(StadiumBaselineSites.pose(site))):
			return true
	return false


static func conflicting(lower: Node3D, site: String) -> bool:
	# No roof coexistence or service/upper combination has been authored in this slice.
	for item: String in ["ST-053", "ST-055", "ST-057"]:
		if occupied(lower, item, site):
			return true
	return lower.get_meta("assembly_state", "BASE-LOWER-v1") \
		not in ["BASE-LOWER-v1", "BASE-CONCOURSE-v1"]


static func geometry_signature(root: Node3D, canonical: Node3D = null) -> String:
	# Every node participates. Only direct, actual canonical audience anchors may sway.
	# Frozen ST-029 has no rest metadata: its independently constructed reference is truth.
	if root.get_child_count() != 2 or not root.has_node("Visual") or not root.has_node("Collision"):
		return ""
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if root.get_script() != null:
		return ""
	context.update(var_to_bytes([root.get_class(), root.top_level, root.visible,
		root.get_meta("represented_seats", 0)]))
	for branch: String in ["Visual", "Collision"]:
		var reference: Node = canonical.get_node(branch) if canonical != null else null
		if not _signature_node(root.get_node(branch), reference, context, branch, 0):
			return ""
	return context.finish().hex_encode()


static func _signature_node(node: Node, reference: Node, context: HashingContext,
	branch: String, depth: int) -> bool:
	var identity: String = "CollisionShape" if node is CollisionShape3D else str(node.name)
	if node.get_script() != null:
		return false
	context.update(var_to_bytes([identity, node.get_class(), node.get_child_count()]))
	var keys: Array[StringName] = node.get_meta_list()
	keys.sort()
	for key: StringName in keys:
		context.update(var_to_bytes([key, node.get_meta(key)]))
	if node is Node3D:
		var transform_value: Transform3D = node.transform
		if not transform_value.is_finite():
			return false
		if branch == "Visual" and depth == 1 and reference is Node3D \
			and reference.name == node.name and reference.get_meta("represented_audience", false):
			if absf(transform_value.origin.y - reference.position.y) > SWAY + 0.00001:
				return false
			transform_value.origin.y = reference.position.y
		context.update(var_to_bytes([transform_value, node.top_level, node.visible]))
	if node is MeshInstance3D:
		if node.mesh == null:
			return false
		context.update(var_to_bytes([node.mesh.get_class(), node.mesh.get_surface_count(),
			node.cast_shadow, node.layers]))
		for surface in range(node.mesh.get_surface_count()):
			context.update(var_to_bytes(node.mesh.surface_get_arrays(surface)))
		var material: StandardMaterial3D = node.material_override as StandardMaterial3D
		if material == null:
			return false
		context.update(var_to_bytes([material.albedo_color, material.roughness,
			material.transparency, material.cull_mode, material.shading_mode]))
	if node is CollisionObject3D:
		context.update(var_to_bytes([node.collision_layer, node.collision_mask]))
	if node is CollisionShape3D:
		if not node.shape is BoxShape3D:
			return false
		context.update(var_to_bytes([node.disabled, node.shape.get_class(),
			node.shape.size, node.shape.margin]))
	for index in range(node.get_child_count()):
		var child_reference: Node = reference.get_child(index) \
			if reference != null and index < reference.get_child_count() else null
		if not _signature_node(node.get_child(index), child_reference, context, branch, depth + 1):
			return false
	return true


static func animate_crowd(root: Node3D, phase: float) -> void:
	# This does not write to frozen source or add metadata to frozen runtime hosts.
	var canonical: Node3D = StadiumBaselineStandModels.lower() \
		if root.get_meta("stadium_item", "") == "ST-029" else StadiumStraightStackModels._upper(true)
	for anchor: Node3D in canonical.get_node("Visual").get_children():
		if anchor.get_meta("represented_audience", false) and root.has_node("Visual/" + str(anchor.name)):
			root.get_node("Visual/" + str(anchor.name)).position.y = anchor.position.y + sin(phase) * SWAY
	canonical.free()
