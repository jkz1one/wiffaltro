extends RefCounted
## Independent actual-node comparison against a fresh retained construction.
## Only bounded receiver flex/fade and numeric scoreboard readout are dynamic.

const META: Array[String] = [
	"stadium_item", "ball_surface", "surface_role", "surface_id", "boundary_segment",
	"represented_seats", "represented_audience", "wall_item", "wall_span", "wall_model_version",
	"site", "net_rest_vertices", "net_pocket_weights", "npc_instance", "npc_site", "owned_copy",
	"npc_host", "club_surface", "surface_priority", "surface_kind", "wall_cap_height",
	"rest_vertices", "panel_width"
]
const SKIP_PROPERTIES: Array[String] = [
	"script", "resource_path", "resource_name", "resource_local_to_scene", "resource_scene_unique_id",
	"name", "unique_name_in_owner", "owner", "scene_file_path", "editor_description"
]


static func same(actual: Node, expected: Node) -> bool:
	return _club_flex(actual, expected) and _receiver_policies(actual) \
		and _receiver_policies(expected) \
		and var_to_bytes(_geometry(actual)) == var_to_bytes(_geometry(expected))


static func _club_flex(actual: Node, expected: Node) -> bool:
	if not actual is StadiumNpcRetainedProperty or actual.venue_id != "AC-01":
		return true
	if not actual.receiver is StadiumNpcRetainedClubReceiver \
		or not expected.receiver is StadiumNpcRetainedClubReceiver:
		return false
	var receiver: StadiumNpcRetainedClubReceiver = actual.receiver
	var reference: StadiumNpcRetainedClubReceiver = expected.receiver
	if receiver._rest_meshes.keys() != reference._rest_meshes.keys():
		return false
	for surface: String in reference._rest_meshes:
		if not receiver._rest_meshes[surface] is Mesh \
			or var_to_bytes(_mesh(receiver._rest_meshes[surface])) != var_to_bytes(
				_mesh(reference._rest_meshes[surface])):
			return false
	if receiver.flex_surface.is_empty():
		return true
	if not StadiumNpcClubNetV1.PANELS.has(receiver.flex_surface) \
		or not is_finite(receiver.flex_elapsed) or receiver.flex_elapsed < 0 \
		or receiver.flex_elapsed > StadiumNpcClubNetV1.SETTLE \
		or not receiver.flex_impact.is_finite():
		return false
	# Reproduce one genuine retained flex exactly on fresh geometry. No per-vertex tolerance,
	# rest-metadata substitution or arbitrary pocket deformation can pass the byte comparison.
	return StadiumNpcClubNetV1.flex(expected.receiver.net, receiver.flex_surface,
		receiver.flex_elapsed, receiver.flex_impact)


static func _receiver_policies(root: Node) -> bool:
	for model: Node in root.find_children("*", "Node3D", true, false):
		if not model.has_meta("npc_instance") or not model.has_node("Visual") \
			or model.get_meta("stadium_item", "") not in ["ST-026", "ST-025", "ST-073"]:
			continue
		var visual: Node3D = model.get_node("Visual")
		var state: String = String(model.get_meta("receiver_render_state", "visible"))
		if state not in ["hidden", "faded", "visible"] or visual.visible != (state != "hidden"):
			return false
		var alpha: float = StadiumReceiverVisibility.FADED_ALPHA if state == "faded" else 1.0
		var blend: int = BaseMaterial3D.TRANSPARENCY_ALPHA if state == "faded" else (
			BaseMaterial3D.TRANSPARENCY_DISABLED)
		var shadow: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if state == "visible" else (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		for node: Node3D in visual.find_children("*", "Node3D", true, false):
			# The real policy only hides the Visual container, never an individual part.
			if not node.visible:
				return false
			if node is MeshInstance3D:
				var material: StandardMaterial3D = node.material_override as StandardMaterial3D
				if material == null or not is_equal_approx(material.albedo_color.a, alpha) \
					or material.transparency != blend or node.cast_shadow != shadow:
					return false
	return true


static func _receiver_visual(node: Node) -> bool:
	var cursor: Node = node
	var visual: bool = false
	while cursor != null:
		visual = visual or cursor.name == &"Visual"
		if cursor.has_meta("npc_instance"):
			return visual and cursor.get_meta("stadium_item", "") in ["ST-026", "ST-025", "ST-073"]
		cursor = cursor.get_parent()
	return false


static func _normalize_pocket(node: MeshInstance3D, result: Dictionary) -> void:
	var root: Node = node.get_parent().get_parent()
	var rest: PackedVector3Array = root.get_meta("net_rest_vertices")
	var weights: PackedFloat32Array = root.get_meta("net_pocket_weights")
	if result.surfaces.size() != 1:
		return
	var vertices: PackedVector3Array = result.surfaces[0].arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() != rest.size() or weights.size() != rest.size():
		return
	var amount: float = -1
	for index in range(vertices.size()):
		if vertices[index].x != rest[index].x or vertices[index].y != rest[index].y:
			return
		if weights[index] == 0:
			if absf(vertices[index].z) > 0.000001:
				return
		else:
			var depth: float = -vertices[index].z / weights[index]
			if depth < -0.000001 or depth > 0.160001:
				return
			if amount >= 0 and absf(amount - depth) > 0.000001:
				return
			amount = depth
	result.surfaces[0].arrays[Mesh.ARRAY_VERTEX] = rest
	var bounds: AABB = AABB(rest[0], Vector3.ZERO)
	for vertex: Vector3 in rest:
		bounds = bounds.expand(vertex)
	result.aabb = bounds


static func _geometry(node: Node, schemas: Variant = null) -> Dictionary:
	# Traverse actual constructed data, excluding supplied signatures and ownership metadata.
	# Anonymous native names carry construction-specific IDs; explicit binding paths remain exact.
	var result: Dictionary = {"class": node.get_class(), "children": [],
		"script": node.get_script().resource_path if node.get_script() != null else "",
		"name": "" if String(node.name).begins_with("@") else String(node.name)}
	if node is Node3D:
		var pose: Transform3D = node.transform
		if node.name == &"ST026_PANEL" and _receiver_visual(node):
			if pose.origin.z >= -0.042501 and pose.origin.z <= -0.012499:
				pose.origin.z = -0.0125
		result["transform"] = pose
		result["visible"] = true if node.name == &"Visual" and _receiver_visual(node) else node.visible
		result["top_level"] = node.top_level
	if node is GeometryInstance3D:
		for key: String in ["layers", "cast_shadow", "gi_mode", "transparency", "sorting_offset",
			"sorting_use_aabb_center", "extra_cull_margin", "custom_aabb", "lod_bias",
			"visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin",
			"visibility_range_end_margin", "visibility_range_fade_mode", "ignore_occlusion_culling"]:
			result[key] = _content(node.get(key), schemas)
			if key == "cast_shadow" and _receiver_visual(node):
				result[key] = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		result["material_override"] = _resource(node.material_override, schemas)
		if _receiver_visual(node) and node.material_override is StandardMaterial3D:
			var props: Dictionary = result.material_override.properties
			var color: Color = props.albedo_color
			if is_equal_approx(color.a, 1.0) or is_equal_approx(
				color.a, StadiumReceiverVisibility.FADED_ALPHA):
				color.a = 1.0
				props.albedo_color = color
				props.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		result["material_overlay"] = _resource(node.material_overlay, schemas)
	if node is MeshInstance3D:
		result["mesh"] = _mesh(node.mesh, schemas)
		if node.name == &"ST025_NET_STRANDS" and _receiver_visual(node):
			_normalize_pocket(node, result.mesh)
		result["surface_overrides"] = []
		if node.mesh != null:
			for index in range(node.mesh.get_surface_count()):
				result.surface_overrides.append(_resource(node.get_surface_override_material(index), schemas))
	if node is MultiMeshInstance3D:
		# No such node is needed for ST-024, but never silently omit actual instance geometry.
		result["multimesh"] = _resource(node.multimesh, schemas)
		result["multimesh_mesh"] = _mesh(node.multimesh.mesh, schemas) if node.multimesh != null else {}
	if node is Label3D:
		# Label3D is not MeshInstance3D; font/text/style are physical presentation, not metadata.
		result["label"] = _stored(node, schemas)
		if (node.get_parent() is StadiumNpcExpandedDisplayV1 \
			or node.get_parent() is StadiumNpcClubDisplayV1) and node.get_index() % 2 == 1:
			if node.text.is_valid_int() and int(node.text) >= 0 and int(node.text) <= 9999:
				result.label.text = "<score>"
	if node is CollisionObject3D:
		result["collision"] = [node.collision_layer, node.collision_mask, node.collision_priority]
	if node is StaticBody3D:
		result["body_material"] = _resource(node.physics_material_override, schemas)
		result["body_velocity"] = [node.constant_linear_velocity, node.constant_angular_velocity]
	if node is CollisionShape3D:
		result["disabled"] = node.disabled
		result["shape"] = _resource(node.shape, schemas)
	for key: String in META:
		if node.has_meta(key):
			result[key] = _content(node.get_meta(key), schemas)
	for child: Node in node.get_children():
		result.children.append(_geometry(child, schemas))
	return result


static func _mesh(mesh: Mesh, schemas: Variant = null) -> Dictionary:
	if mesh == null:
		return {"null": true}
	var result: Dictionary = {"class": mesh.get_class(), "aabb": mesh.get_aabb(), "surfaces": []}
	for index in range(mesh.get_surface_count()):
		var row: Dictionary = {"arrays": mesh.surface_get_arrays(index),
			"blend_arrays": mesh.surface_get_blend_shape_arrays(index),
			"material": _resource(mesh.surface_get_material(index), schemas)}
		if mesh is ArrayMesh:
			row["primitive"] = mesh.surface_get_primitive_type(index)
		result.surfaces.append(row)
	return result


static func _resource(value: Resource, schemas: Variant = null) -> Dictionary:
	return {"null": true} if value == null else {
		"class": value.get_class(), "properties": _stored(value, schemas)}


static func _stored(value: Object, schemas: Variant = null) -> Dictionary:
	# All stored material parameters are covered, including shading/transparency/emission,
	# vertex-color/UV flags, texture resources, surface materials and null overrides.
	var result: Dictionary = {}
	var names: Variant = _ordinary_stored_names(value, schemas)
	if names != null:
		for key: String in names:
			if not SKIP_PROPERTIES.has(key) and not key.begins_with("metadata/"):
				result[key] = _content(value.get(key), schemas)
		return result
	for property: Dictionary in value.get_property_list():
		var key: String = property.name
		if int(property.usage) & PROPERTY_USAGE_STORAGE == 0 or SKIP_PROPERTIES.has(key) \
			or key.begins_with("metadata/"):
			continue
		result[key] = _content(value.get(key), schemas)
	return result


static func _content(value: Variant, schemas: Variant = null) -> Variant:
	if value is Resource:
		return _resource(value, schemas)
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_content(item, schemas))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _content(value[key], schemas)
		return result
	if value is Object or value is RID or value is Callable:
		push_error("Unreviewed opaque value in retained geometry")
		return "unreviewed-opaque-value"
	return value


static func _ordinary_stored_names(value: Object, schemas: Variant) -> Variant:
	# Only intact() owns a production scope. Legacy/reference callers keep reflection exactly.
	if schemas == null:
		return null
	# This schema proof is specific to the reviewed engine, native class and selector state.
	if Engine.is_editor_hint() or Engine.get_version_info().get("hash", "") != \
		"ed1daf0bf001b61586d9930840f2f1394092c079" or value.get_script() != null \
		or value.get_class() != "StandardMaterial3D" or not value.get_meta_list().is_empty():
		return null
	var material: StandardMaterial3D = value as StandardMaterial3D
	if material.get_billboard_mode() != BaseMaterial3D.BILLBOARD_DISABLED \
		or material.get_shading_mode() != BaseMaterial3D.SHADING_MODE_PER_PIXEL \
		or material.get_transparency() not in [BaseMaterial3D.TRANSPARENCY_DISABLED,
			BaseMaterial3D.TRANSPARENCY_ALPHA] \
		or material.is_heightmap_deep_parallax_enabled() \
		or material.get_flag(BaseMaterial3D.FLAG_SUBSURFACE_MODE_SKIN):
		return null
	var setting: String = "rendering/lights_and_shadows/use_physical_light_units"
	if not ProjectSettings.has_setting(setting):
		return null
	# Nested getters/signals may change this setting, so re-read it at every occurrence.
	var physical: Variant = ProjectSettings.get_setting_with_override(setting)
	if typeof(physical) != TYPE_BOOL:
		return null
	if not schemas.has(physical):
		var names: Array[String] = []
		for property: Dictionary in value.get_property_list():
			if property.name != "script" and int(property.usage) & PROPERTY_USAGE_STORAGE != 0:
				names.append(property.name)
		names.make_read_only()
		schemas[physical] = names
	# Names are an entry-time snapshot only; every subsequent value getter remains fresh.
	return schemas[physical]
