extends RefCounted
## Stateless boundary operations for the existing surface-night runtime owner.


static func _kit_value_equal(actual: Variant, expected: Variant) -> bool:
	# Typed foreign metadata must refuse, not throw during cleanup/guard comparison.
	return (
		typeof(actual) == typeof(expected)
		and (is_same(actual, expected) if actual is Object else actual == expected)
	)


static func _kit_no_internal_children(root: Node) -> bool:
	if not is_instance_valid(root):
		return false
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var children: Array[Node] = node.get_children()
		if node.get_child_count(true) != children.size():
			return false
		pending.append_array(children)
	return true


static func _kit_boundary_visual_fingerprint(owner: StadiumSurfaceNightRuntime) -> String:
	var resources: Array[Dictionary] = []
	var seen: Dictionary = {}
	var rows: Array = []
	for node: Node in owner._boundary.find_children("*", "", true, false):
		var fields: Array = []
		var values: Array = []
		for property: Dictionary in node.get_property_list():
			if (
				not int(property.usage) & PROPERTY_USAGE_STORAGE
				or property.name in ["script", "owner"]
			):
				continue
			var value: Variant = node.get(property.name)
			fields.append(property.name)
			values.append(value)
			if (
				value is Resource
				and not StadiumFloodlightOwnedModels._capture_resource(
					value, resources, seen, 0, true
				)
			):
				return ""
		rows.append(
			[
				String(node.name),
				String(node.get_parent().name),
				node.get_index(),
				fields,
				values,
				StadiumSurfaceNightRuntime._metadata(node)
			]
		)
	var hashes: Dictionary = {}
	for row: Dictionary in resources:
		var values: Array = []
		for value: Variant in row.values:
			if value is Resource:
				if not hashes.has(value):
					return ""
				values.append({"resource": hashes[value]})
			else:
				values.append(value)
		hashes[row.resource] = (
			StadiumSurfaceNightRuntime
			. _data(
				[
					row.resource.get_class(),
					row.keys,
					values,
					StadiumSurfaceNightRuntime._metadata(row.resource)
				]
			)
			. sha256_text()
		)
	for row: Array in rows:
		for index in range(row[4].size()):
			if row[4][index] is Resource:
				row[4][index] = {"resource": hashes[row[4][index]]}
	return StadiumSurfaceNightRuntime._data(rows).sha256_text()


static func _pool_kit_boundary_visuals(owner: StadiumSurfaceNightRuntime) -> bool:
	# Candidate3 instance-local preparation only. Never changes a historical factory,
	# collider resource or source asset. Full native-value equality proves each merge.
	if not StadiumSurfaceNightRuntime._kit_no_internal_children(owner._boundary):
		return false
	var before: String = owner._kit_boundary_visual_fingerprint()
	if before.is_empty():
		return false
	var resources: Array[Dictionary] = []
	var seen: Dictionary = {}
	var visuals: Array[MeshInstance3D] = []
	for node: Node in owner._boundary.find_children("*", "MeshInstance3D", true, false):
		var visual: MeshInstance3D = node as MeshInstance3D
		if visual == null or not visual.mesh is BoxMesh:
			return false
		visuals.append(visual)
		for resource: Resource in [visual.mesh, visual.material_override, visual.material_overlay]:
			if (
				resource != null
				and not StadiumFloodlightOwnedModels._capture_resource(
					resource, resources, seen, 0, true
				)
			):
				return false
		for index in range(visual.mesh.get_surface_count()):
			var material: Material = visual.get_surface_override_material(index)
			if (
				material != null
				and not StadiumFloodlightOwnedModels._capture_resource(
					material, resources, seen, 0, true
				)
			):
				return false
	return _merge_kit_boundary_resources(owner, before, resources, visuals)


static func _merge_kit_boundary_resources(
	owner: StadiumSurfaceNightRuntime,
	before: String,
	resources: Array[Dictionary],
	visuals: Array[MeshInstance3D]
) -> bool:
	var canonical: Dictionary = {}
	var buckets: Dictionary = {}
	var unique: int = 0
	# Capture emits referenced materials before their parent meshes.
	for row: Dictionary in resources:
		var resource: Resource = row.resource
		if not resource is StandardMaterial3D and not resource is BoxMesh:
			return false  # This exact default boundary has no textures or custom shaders.
		for index in range(row.keys.size()):
			var value: Variant = row.values[index]
			if value is Resource and canonical.has(value) and not is_same(value, canonical[value]):
				resource.set(row.keys[index], canonical[value])
				row.values[index] = canonical[value]
		var values: Array = []
		for value: Variant in row.values:
			values.append({"resource_id": value.get_instance_id()} if value is Resource else value)
		var fingerprint: String = (
			StadiumSurfaceNightRuntime
			. _data(
				[
					resource.get_class(),
					row.keys,
					values,
					StadiumSurfaceNightRuntime._metadata(resource)
				]
			)
			. sha256_text()
		)
		var match_row: Dictionary = {}
		for candidate: Dictionary in buckets.get(fingerprint, []):
			if (
				candidate.keys != row.keys
				or (
					StadiumSurfaceNightRuntime._metadata(candidate.resource)
					!= StadiumSurfaceNightRuntime._metadata(resource)
				)
			):
				continue
			var equal: bool = true
			for index in range(row.keys.size()):
				equal = (
					equal
					and StadiumSurfaceNightRuntime._kit_value_equal(
						candidate.values[index], row.values[index]
					)
				)
			if equal:
				match_row = candidate
				break
		if match_row.is_empty():
			if not buckets.has(fingerprint):
				buckets[fingerprint] = []
			buckets[fingerprint].append(row)
			canonical[resource] = resource
			unique += 1
		else:
			canonical[resource] = match_row.resource
	for visual: MeshInstance3D in visuals:
		visual.mesh = canonical[visual.mesh]
		if visual.material_override != null:
			visual.material_override = canonical[visual.material_override]
		if visual.material_overlay != null:
			visual.material_overlay = canonical[visual.material_overlay]
		for index in range(visual.mesh.get_surface_count()):
			var material: Material = visual.get_surface_override_material(index)
			if material != null:
				visual.set_surface_override_material(index, canonical[material])
	owner._kit_boundary_pool = {
		"before": resources.size(),
		"after": unique,
		"visuals": visuals.size(),
		"proof": "exact-full-native-values-and-resource-reference-equality-before-merge",
		"before_fingerprint": before,
		"after_fingerprint": owner._kit_boundary_visual_fingerprint()
	}
	return not visuals.is_empty() and owner._kit_boundary_pool.after_fingerprint == before


static func _capture_kit_boundary_visuals(owner: StadiumSurfaceNightRuntime) -> bool:
	# Candidate3 additionally binds its measured default wall appearance. The
	# existing boundary owner keeps dynamic contact state and collision authority.
	if (
		not is_instance_valid(owner._boundary)
		or not owner._boundary.has_node("PanelVisuals")
		or not StadiumSurfaceNightRuntime._kit_no_internal_children(owner._boundary)
	):
		return false
	var rows: Array[Dictionary] = []
	var hot: Array[StadiumSurfaceNightRuntime.KitBoundaryNodeSeal] = []
	var resources: Array[Dictionary] = []
	var seen: Dictionary = {}
	for node: Node in owner._boundary.find_children("*", "", true, false):
		if not node is Node3D or node.get_script() != null or node is Light3D:
			return false
		var fields: Array[StringName] = [&"transform", &"top_level", &"visible", &"process_mode"]
		if node is MeshInstance3D:
			fields.append_array(
				[
					&"mesh",
					&"material_override",
					&"material_overlay",
					&"cast_shadow",
					&"layers",
					&"transparency"
				]
			)
		elif node is StaticBody3D:
			fields.append_array(
				[
					&"collision_layer",
					&"collision_mask",
					&"disable_mode",
					&"physics_material_override",
					&"constant_linear_velocity",
					&"constant_angular_velocity"
				]
			)
		elif node is CollisionShape3D:
			fields.append_array([&"shape", &"disabled"])
		# Native property-list schema includes visibility_range_*, occlusion, LOD,
		# GI, AABB and render-layer controls. No fixed shortlist may hide a wall.
		for property: Dictionary in node.get_property_list():
			var field: StringName = property.name
			if (
				int(property.usage) & PROPERTY_USAGE_STORAGE
				and not String(field).begins_with("metadata/")
				and field not in [&"script", &"owner"]
				and not fields.has(field)
			):
				fields.append(field)
		var values: Array = []
		for field: StringName in fields:
			var value: Variant = node.get(field)
			values.append(value.duplicate(true) if value is Array or value is Dictionary else value)
			if (
				value is Resource
				and not StadiumFloodlightOwnedModels._capture_resource(
					value, resources, seen, 0, true
				)
			):
				return false
		hot.append(StadiumSurfaceNightRuntime.KitBoundaryNodeSeal.new(node))
		rows.append(
			{
				"node": node,
				"parent": node.get_parent(),
				"name": node.name,
				"children": node.get_children(true),
				"fields": fields,
				"values": values,
				"metadata": StadiumSurfaceNightRuntime._metadata(node)
			}
		)
	owner._kit_boundary_visuals = {
		"root": owner._boundary,
		"children": owner._boundary.get_children(true),
		"metadata": StadiumSurfaceNightRuntime._metadata(owner._boundary),
		"visible": owner._boundary.visible,
		"top_level": owner._boundary.top_level,
		"rows": rows,
		"resources": resources,
		"hot": hot,
		"process_mode": owner._boundary.process_mode,
		"visibility_parent": owner._boundary.visibility_parent,
		"interpolation": owner._boundary.physics_interpolation_mode,
		"script": owner._boundary.get_script()
	}
	return not rows.is_empty() and owner._kit_boundary_visuals_intact(true)


static func _kit_boundary_visuals_intact(
	owner: StadiumSurfaceNightRuntime, deep: bool = false
) -> bool:
	if (
		owner._kit_boundary_visuals.is_empty()
		or not is_instance_valid(owner._boundary)
		or owner._boundary.is_queued_for_deletion()
		or owner._kit_boundary_visuals.root != owner._boundary
		or owner._boundary.get_children(true) != owner._kit_boundary_visuals.children
		or owner._boundary.visible != owner._kit_boundary_visuals.visible
		or owner._boundary.top_level != owner._kit_boundary_visuals.top_level
		or owner._boundary.process_mode != owner._kit_boundary_visuals.process_mode
		or owner._boundary.visibility_parent != owner._kit_boundary_visuals.visibility_parent
		or owner._boundary.physics_interpolation_mode != owner._kit_boundary_visuals.interpolation
		or not is_same(owner._boundary.get_script(), owner._kit_boundary_visuals.script)
		or (
			StadiumSurfaceNightRuntime._metadata(owner._boundary)
			!= owner._kit_boundary_visuals.metadata
		)
	):
		return false
	if deep:
		for row: Dictionary in owner._kit_boundary_visuals.rows:
			var node: Node = row.node
			if (
				not is_instance_valid(node)
				or node.is_queued_for_deletion()
				or node.get_script() != null
				or node.get_parent() != row.parent
				or node.name != row.name
				or node.get_children(true) != row.children
				or StadiumSurfaceNightRuntime._metadata(node) != row.metadata
			):
				return false
			for index in range(row.fields.size()):
				if not StadiumSurfaceNightRuntime._kit_value_equal(
					node.get(row.fields[index]), row.values[index]
				):
					return false
	else:
		for row: StadiumSurfaceNightRuntime.KitBoundaryNodeSeal in owner._kit_boundary_visuals.hot:
			if not row.intact():
				return false
	return _kit_boundary_resources_intact(owner)


static func _kit_boundary_resources_intact(owner: StadiumSurfaceNightRuntime) -> bool:
	for row: Dictionary in owner._kit_boundary_visuals.resources:
		var resource: Resource = row.resource
		if (
			not is_instance_valid(resource)
			or (
				row.has("metadata")
				and StadiumSurfaceNightRuntime._metadata(resource) != row.metadata
			)
		):
			return false
		for index in range(row.keys.size()):
			if not StadiumSurfaceNightRuntime._kit_value_equal(
				resource.get(row.keys[index]), row.values[index]
			):
				return false
	return true
