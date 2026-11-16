class_name StadiumMountedScoreboardIntegrity
extends RefCounted
## Frozen assembly identities and geometry, excluding only changing live score text.


static func capture(property: StadiumScoreboardPropertyGeometry, layout: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in layout.scoreboards:
		var model: Variant = property.board_objects.get(row.copy)
		if not model is Node3D or not is_instance_valid(model):
			return {}
		var display: StadiumScoreboardTierDisplay = StadiumScoreboardAssembly.display(model, row)
		if display == null or display.tier != StadiumScoreboardCatalog.TIERS[row.item]:
			return {}
		var tree: Dictionary = _node(model, display)
		var labels: Dictionary = _labels(display)
		if tree.is_empty() or labels.is_empty():
			return {}
		result[row.copy] = {"tree": tree, "labels": labels}
	return {"boards": result}


static func matches(property: StadiumScoreboardPropertyGeometry, layout: Dictionary,
	identity: Variant) -> bool:
	var actual: Dictionary = capture(property, layout)
	return not actual.is_empty() and equal(actual, identity)


static func camera_capture(camera: BallTrackingVisibility) -> Dictionary:
	if camera == null:
		return {}
	var prisms: StadiumWallViewPrisms = camera._wall_prisms
	return {"id": camera.get_instance_id(), "script": _resource_id(camera.get_script()),
		"obstacles": camera._obstacles.duplicate(), "uprights": camera._uprights.duplicate(),
		"walls": camera._wall_bounds.duplicate(), "field_wall_z": camera.field_wall_z,
		"prisms": {"id": prisms.get_instance_id() if prisms != null else 0,
			"script": _resource_id(prisms.get_script()) if prisms != null else 0,
			"walls": prisms.walls.duplicate(true) if prisms != null else []},
		"mount_policy": StadiumMountedCameraVisibility.POLICY,
		"mounted_meshes": camera._mounted_meshes.duplicate(true) \
			if camera is StadiumMountedCameraVisibility else []}


static func camera_matches(camera: BallTrackingVisibility, host: Node, frozen: Variant) -> bool:
	if not camera is StadiumMountedCameraVisibility or not frozen is Dictionary:
		return false
	var actual: Dictionary = camera_capture(camera)
	if not equal(actual, frozen):
		return false
	# Re-derive every bound from actual transformed meshes, never trust a saved valid flag.
	var expected: StadiumMountedCameraVisibility = StadiumMountedCameraVisibility.new()
	expected.configure(host)
	var derived: Dictionary = camera_capture(expected)
	derived.id = camera.get_instance_id()
	if actual.prisms.id != 0 and derived.prisms.id != 0:
		derived.prisms.id = actual.prisms.id
	return equal(actual, derived)


static func _node(node: Node, display: StadiumScoreboardTierDisplay) -> Dictionary:
	if not node is Node3D or node.get_parent() == null \
		or node is CollisionObject3D or node is CollisionShape3D \
		or node is CollisionPolygon3D or node.top_level or not node.visible:
		return {}
	for key: StringName in node.get_meta_list():
		if key == &"stadium_candidate_only" or "authoring" in String(key) \
			or "lab_only" in String(key):
			return {}
	var metadata: Dictionary = {}
	for key: StringName in node.get_meta_list():
		metadata[String(key)] = node.get_meta(key)
	var children: Array[Dictionary] = []
	for child: Node in node.get_children():
		var part: Dictionary = _node(child, display)
		if part.is_empty():
			return {}
		children.append(part)
	var result: Dictionary = {"id": node.get_instance_id(),
		"parent": node.get_parent().get_instance_id(),
		"name": String(node.name), "class": node.get_class(), "pose": node.transform,
		"top_level": node.top_level, "visible": node.visible, "children": children,
		"script": _resource_id(node.get_script()), "metadata": metadata,
		"process_mode": node.process_mode}
	if node is GeometryInstance3D:
		result["render"] = _render(node)
	if node is MeshInstance3D:
		var mesh: Dictionary = _mesh(node)
		if mesh.is_empty():
			return {}
		result["mesh"] = mesh
	elif node is Label3D:
		result["label"] = _label(node)
		if not display._labels.values().has(node) and not display._detail_labels.values().has(node):
			result.label["text"] = node.text
	elif node != display and node.get_script() != null:
		return {}
	return result


static func _render(node: GeometryInstance3D) -> Dictionary:
	return {"layers": node.layers, "transparency": node.transparency,
		"cast_shadow": node.cast_shadow, "custom_aabb": node.custom_aabb,
		"extra_cull_margin": node.extra_cull_margin,
		"visibility_begin": node.visibility_range_begin, "visibility_end": node.visibility_range_end,
		"begin_margin": node.visibility_range_begin_margin,
		"end_margin": node.visibility_range_end_margin,
		"fade_mode": node.visibility_range_fade_mode,
		"material": _material(node.material_override), "overlay": _material(node.material_overlay)}


static func _mesh(node: MeshInstance3D) -> Dictionary:
	if not node.mesh is BoxMesh and not node.mesh is SphereMesh:
		return {}
	var dimensions: Dictionary = {}
	var keys: Array[String] = []
	keys.assign(["size", "subdivide_width", "subdivide_height", "subdivide_depth"]
		if node.mesh is BoxMesh else ["radius", "height", "radial_segments", "rings", "is_hemisphere"])
	keys.append_array(["flip_faces", "add_uv2", "uv2_padding"])
	for key: String in keys:
		dimensions[key] = node.mesh.get(key)
	var surfaces: Array = []
	for index in range(node.mesh.get_surface_count()):
		surfaces.append(node.mesh.surface_get_arrays(index).duplicate(true))
	return {"id": node.mesh.get_instance_id(), "class": node.mesh.get_class(),
		"bounds": node.mesh.get_aabb(), "dimensions": dimensions, "surfaces": surfaces,
		"mesh_material": _material(node.mesh.material)}


static func _material(value: Material) -> Dictionary:
	if value == null:
		return {"id": 0}
	var data: Dictionary = {"id": value.get_instance_id(), "class": value.get_class()}
	for row: Dictionary in value.get_property_list():
		if (int(row.usage) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var field: Variant = value.get(row.name)
		data[String(row.name)] = _resource_id(field) if field is Resource else field
	return data


static func _label(label: Label3D) -> Dictionary:
	return {"font": _resource_id(label.font), "font_size": label.font_size,
		"pixel_size": label.pixel_size, "outline_size": label.outline_size,
		"modulate": label.modulate, "outline_modulate": label.outline_modulate,
		"offset": label.offset, "horizontal_alignment": label.horizontal_alignment,
		"vertical_alignment": label.vertical_alignment, "billboard": label.billboard,
		"no_depth_test": label.no_depth_test, "fixed_size": label.fixed_size,
		"alpha_cut": label.alpha_cut, "render_priority": label.render_priority}


static func _labels(display: StadiumScoreboardTierDisplay) -> Dictionary:
	var result: Dictionary = {}
	for channel: String in ["_labels", "_detail_labels"]:
		var actual: Dictionary = display.get(channel)
		var expected: Dictionary = StadiumScoreboardTiers.readouts(display.tier) \
			if channel == "_labels" else StadiumScoreboardTiers.detail_slots(display.tier)
		if actual.size() != expected.size():
			return {}
		var ids: Dictionary = {}
		for key: String in expected:
			var label: Variant = actual.get(key)
			var slot: Dictionary = expected[key]
			if not label is Label3D or not is_instance_valid(label) \
				or label.get_parent() != display or label.position != slot.point \
				or label.font_size != slot.font_size or not is_equal_approx(label.pixel_size, slot.pixels) \
				or ids.values().has(label.get_instance_id()):
				return {}
			ids[key] = label.get_instance_id()
		result[channel] = ids
	return result


static func _resource_id(value: Resource) -> int:
	return value.get_instance_id() if value != null else 0


static func equal(actual: Variant, frozen: Variant) -> bool:
	if typeof(actual) != typeof(frozen):
		return false
	if actual is Dictionary:
		if actual.size() != frozen.size():
			return false
		for key: Variant in actual:
			if not frozen.has(key) or not equal(actual[key], frozen[key]):
				return false
		return true
	if actual is Array:
		if actual.size() != frozen.size():
			return false
		for index in range(actual.size()):
			if not equal(actual[index], frozen[index]):
				return false
		return true
	return false if actual is Object or actual is Callable or actual is Signal else actual == frozen
