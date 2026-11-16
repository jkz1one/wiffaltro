class_name StadiumCurvedCanopySites
extends RefCounted
## Additive upper-pylon-cap attachment; frozen hosts acquire no retrofit sockets.

const INTERFACE: String = "ST082-v1_PYLON-CAP-v1"
const HEIGHT: float = 10.8


static func contains_local(point: Vector3) -> bool:
	return Vector2(point.x, point.z).length() >= 18.0 - 0.001 \
		and Vector2(point.x, point.z).length() <= 28.0 + 0.001 \
		and absf(rad_to_deg(atan2(point.x, point.z))) <= 14.701 \
		and point.y >= 0 and point.y <= HEIGHT


static func valid_hosts(lower: Node3D, concourse: Node3D, upper: Node3D,
	site: String) -> bool:
	if not StadiumCurvedStackSites.valid_lower(lower, site):
		return false
	for piece: Node3D in [concourse, upper]:
		if not is_instance_valid(piece) or not piece.is_inside_tree() \
			or piece.get_parent() != lower.get_parent() \
			or not StadiumCurvedStackSites.valid_pose(piece, site) \
			or piece.get_meta("lower_instance", 0) != lower.get_instance_id() \
			or piece.get_meta("model_version", 0) != 1 \
			or piece.get_meta("site", "") != site:
			return false
	if concourse.get_meta("stadium_item", "") != "ST-083" \
		or upper.get_meta("stadium_item", "") != "ST-082" \
		or concourse.get_meta("interface", "") != StadiumCurvedStackSites.INTERFACE \
		or upper.get_meta("interface", "") != StadiumCurvedStackSites.UPPER_INTERFACE \
		or upper.get_meta("concourse_instance", 0) != concourse.get_instance_id():
		return false
	if not canonical(lower, "ST-081") or not canonical(concourse, "ST-083") \
		or not canonical(upper, "ST-082"):
		return false
	# Reject a second layer, either roof state, or a service occupant in this assembly.
	for sibling: Node in lower.get_parent().get_children():
		if sibling in [lower, concourse, upper]:
			continue
		var same: bool = sibling.get_meta("lower_instance", 0) == lower.get_instance_id() \
			or sibling.get_meta("site", "") == site
		if same and sibling.get_meta("stadium_item", "") in \
			["ST-081", "ST-083", "ST-082", "ST-084", "ST-053", "ST-055", "ST-057"]:
			return false
	return true


static func canonical(piece: Node3D, item: String) -> bool:
	var actual: String = signature(piece)
	if actual.is_empty():
		return false
	for occupied: bool in [false, true]:
		var reference: Node3D
		match item:
			"ST-081": reference = StadiumCurvedLowerModels.create(occupied)
			"ST-083": reference = StadiumCurvedStackModels._concourse()
			"ST-082": reference = StadiumCurvedStackModels._upper(occupied)
			_: return false
		var matches: bool = actual == signature(reference)
		reference.free()
		if matches:
			return true
	return false


static func signature(piece: Node3D) -> String:
	var geometry: String = StadiumCurvedStackSites.geometry_signature(piece)
	if geometry.is_empty() or piece.get_class() != "Node3D" or piece.top_level \
		or not piece.visible:
		return ""
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(geometry.to_utf8_buffer())
	_state(piece, context)
	return context.finish().hex_encode()


static func _state(node: Node, context: HashingContext) -> void:
	# No name exclusions: root and every descendant's execution/render state participate.
	context.update(var_to_bytes([_resource(node.get_script()), node.process_mode]))
	if node is MeshInstance3D:
		context.update(var_to_bytes([_resource(node.material_override),
			_resource(node.material_overlay), node.transparency, node.cast_shadow,
			node.layers, node.skeleton, node.extra_cull_margin, node.ignore_occlusion_culling,
			node.visibility_range_begin, node.visibility_range_end, node.lod_bias]))
		if node.mesh != null:
			for index in range(node.mesh.get_surface_count()):
				var primitive: Variant = node.mesh.get_class()
				if node.mesh is ArrayMesh:
					primitive = node.mesh.surface_get_primitive_type(index)
				context.update(var_to_bytes([primitive,
					_resource(node.mesh.surface_get_material(index)),
					_resource(node.get_surface_override_material(index))]))
	for child: Node in node.get_children():
		_state(child, context)


static func _resource(value: Resource, depth: int = 0) -> Variant:
	if value == null:
		return null
	if depth > 8:
		return "unsupported recursive resource"
	var result: Array = [value.get_class()]
	if value is Script:
		return [value.get_class(), value.resource_path, value.source_code]
	for property: Dictionary in value.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) \
			or property.name in ["resource_name", "resource_path", "resource_local_to_scene"]:
			continue
		var field: Variant = value.get(property.name)
		if field is Resource:
			field = _resource(field, depth + 1)
		result.append([property.name, field])
	return result
