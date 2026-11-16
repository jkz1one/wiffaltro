class_name StadiumMogulTwoIntegrity
extends RefCounted
## Pre-install seal for the exact just-built assembly. Never a production certificate.


static func signature(property: StadiumPropertyGeometry) -> String:
	if (
		property == null
		or not property.is_inside_tree()
		or not StadiumMogulTwoStudy.identity_chain(property)
		or property.objects.size() != 91
	):
		return ""
	var boundary: StadiumMogulTwoBoundary = property.get_node_or_null("ClubBoundary")
	if (
		boundary == null
		or boundary.graph == null
		or (
			boundary.graph.get_script()
			!= preload("res://src/gameplay/stadium/stadium_mogul_two_graph.gd")
		)
	):
		return ""
	var rows: Array = [StadiumMogulTwoStudy.graph_record(boundary.graph)]
	for registered: Array in [boundary.items, boundary.bodies]:
		var paths: Array[NodePath] = []
		for member: Node in registered:
			if not is_instance_valid(member) or not boundary.is_ancestor_of(member):
				return ""
			paths.append(boundary.get_path_to(member))
		rows.append(paths)
	var keys: Array = property.objects.keys()
	keys.sort()
	for key: String in keys:
		var model: Node3D = property.objects.get(key)
		if (
			not is_instance_valid(model)
			or not property.is_ancestor_of(model)
			or model.get_meta("candidate_instance", "") != key
		):
			return ""
		rows.append([key, property.get_path_to(model)])
	if not _node(property, rows):
		return ""
	return var_to_bytes(rows).hex_encode().sha256_text()


static func _node(node: Node, rows: Array) -> bool:
	var entry: Array = [node.get_class(), node.name, node.get_child_count(), node.process_mode]
	var script: Script = node.get_script() as Script
	entry.append(StadiumCurvedCanopySites._resource(script))
	var keys: Array[StringName] = node.get_meta_list()
	keys.sort()
	for key: StringName in keys:
		if key != &"candidate_venue":
			entry.append([key, node.get_meta(key)])
	if node is Node3D:
		if not node.transform.is_finite():
			return false
		entry.append([node.transform, node.visible, node.top_level])
	if node is MeshInstance3D:
		if node.mesh == null:
			return false
		entry.append(
			[
				node.mesh.get_class(),
				node.transparency,
				node.cast_shadow,
				node.layers,
				StadiumCurvedCanopySites._resource(node.material_override),
				StadiumCurvedCanopySites._resource(node.material_overlay)
			]
		)
		entry.append(StadiumCurvedCanopySites._resource(node.mesh.get_script()))
		for type_name: StringName in [
			&"VisualInstance3D", &"GeometryInstance3D", &"MeshInstance3D"
		]:
			for property: Dictionary in ClassDB.class_get_property_list(type_name, true):
				if not (int(property.usage) & PROPERTY_USAGE_STORAGE):
					continue
				var value: Variant = node.get(property.name)
				if value is Resource:
					value = StadiumCurvedCanopySites._resource(value)
				entry.append([type_name, property.name, value])
		for property: Dictionary in node.get_property_list():
			if String(property.name).begins_with("instance_shader_parameters/"):
				entry.append([property.name, node.get(property.name)])
		for surface in range(node.mesh.get_surface_count()):
			entry.append(
				(
					node.mesh.surface_get_primitive_type(surface)
					if node.mesh is ArrayMesh
					else Mesh.PRIMITIVE_TRIANGLES
				)
			)
			entry.append(
				[
					node.mesh.surface_get_arrays(surface),
					StadiumCurvedCanopySites._resource(node.mesh.surface_get_material(surface)),
					StadiumCurvedCanopySites._resource(node.get_surface_override_material(surface))
				]
			)
	if node is CollisionObject3D:
		entry.append([node.collision_layer, node.collision_mask, node.disable_mode])
	if node is CollisionShape3D:
		if node.shape == null:
			return false
		entry.append([node.disabled, StadiumCurvedCanopySites._resource(node.shape)])
	if node is Label3D:
		entry.append([node.text, node.font_size, node.pixel_size, node.modulate])
	rows.append(entry)
	for child: Node in node.get_children():
		if not _node(child, rows):
			return false
	return true
