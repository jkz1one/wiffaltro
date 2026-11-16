class_name StadiumCurvedStackSites
extends RefCounted
## Additive Working rear-saddle interface. Does not modify frozen ST-081-v1.

const VERSION: int = 1
const INTERFACE: String = "ST081-v1_REAR-SADDLE-v1"
const UPPER_INTERFACE: String = "ST083-v1_CANTILEVER-v1"
const HEIGHT: float = 9.3
const OUTER: float = 28.0
const CENTRAL: Array[String] = ["BOWL-02", "BOWL-03", "BOWL-04"]


static func contains_local(point: Vector3) -> bool:
	var radius: float = Vector2(point.x, point.z).length()
	return radius >= 18.0 - 0.001 and radius <= OUTER + 0.001 \
		and absf(rad_to_deg(atan2(point.x, point.z))) <= 14.701 \
		and point.y >= -0.001 and point.y <= HEIGHT + 0.001


static func valid_lower(lower: Node3D, site: String) -> bool:
	if not is_instance_valid(lower) or not lower.is_inside_tree():
		return false
	if lower.get_meta("stadium_item", "") != "ST-081" \
		or lower.get_meta("model_version", 0) != 1 or not valid_pose(lower, site):
		return false
	var actual: String = geometry_signature(lower)
	for occupied_value: bool in [false, true]:
		var reference: Node3D = StadiumCurvedLowerModels.create(occupied_value)
		var matches: bool = actual == geometry_signature(reference)
		reference.free()
		if matches:
			return true
	return false


static func valid_pose(piece: Node3D, site: String) -> bool:
	if site not in StadiumCurvedLowerSites.SITES or not piece.is_inside_tree():
		return false
	var expected: Transform3D = StadiumCurvedLowerSites.pose(site)
	var parent: Node3D = piece.get_parent() as Node3D
	return parent != null and parent.global_transform.is_equal_approx(Transform3D.IDENTITY) \
		and piece.transform.is_equal_approx(expected) \
		and piece.global_transform.is_equal_approx(expected)


static func occupied(lower: Node3D, item: String) -> bool:
	for child: Node in lower.get_parent().get_children():
		if child.get_meta("stadium_item", "") == item \
			and child.get_meta("lower_instance", 0) == lower.get_instance_id():
			return true
	return false


static func geometry_signature(root: Node3D) -> String:
	# Every branch and mesh/collider participates. Only canonical bounded crowd Y sway
	# is normalized; matching the complete occupied/unoccupied reference proves identity.
	if root.get_child_count() != 2:
		return ""
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for branch: String in ["Visual", "Collision"]:
		if not root.has_node(branch):
			return ""
		if not _signature_node(root.get_node(branch), context, branch, 0):
			return ""
	return context.finish().hex_encode()


static func _signature_node(node: Node, context: HashingContext, branch: String,
	depth: int) -> bool:
	var identity: String = "CollisionShape" if node is CollisionShape3D else str(node.name)
	context.update(var_to_bytes([identity, node.get_class(), node.get_child_count()]))
	if node is Node3D:
		var pose: Transform3D = node.transform
		var anchor: bool = branch == "Visual" and depth == 1 \
			and node.name.begins_with("CrowdAnchor") \
			and str(node.name).trim_prefix("CrowdAnchor").is_valid_int()
		# Missing required anchor metadata is a malformed host, not a get_meta error.
		if anchor and not node.has_meta("rest_position"):
			return false
		var rest: Variant = null
		if node.has_meta("rest_position"):
			rest = node.get_meta("rest_position")
		if anchor:
			if not rest is Vector3:
				return false
			if not rest.is_finite() or not pose.origin.is_finite() \
				or absf(pose.origin.y - rest.y) > StadiumCurvedLowerModels.SWAY + 0.00001:
				return false
			pose.origin.y = rest.y
		context.update(var_to_bytes([pose, rest, node.top_level, node.visible]))
	if node is MeshInstance3D:
		if node.mesh == null:
			context.update(var_to_bytes("missing mesh"))
		else:
			context.update(var_to_bytes(node.mesh.get_surface_count()))
			for surface in range(node.mesh.get_surface_count()):
				context.update(var_to_bytes(node.mesh.surface_get_arrays(surface)))
	if node is StaticBody3D:
		context.update(var_to_bytes([node.collision_layer, node.collision_mask]))
	if node is CollisionShape3D:
		context.update(var_to_bytes(node.disabled))
		if not node.shape is ConvexPolygonShape3D:
			context.update(var_to_bytes("invalid shape"))
		else:
			context.update(var_to_bytes([node.shape.get_class(), node.shape.points,
				node.shape.margin]))
	for child: Node in node.get_children():
		if not _signature_node(child, context, branch, depth + 1):
			return false
	return true
