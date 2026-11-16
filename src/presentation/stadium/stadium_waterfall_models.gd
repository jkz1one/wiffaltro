class_name StadiumWaterfallModels
extends RefCounted
## ST-046 static off-field authoring study. No water physics, particles or game authority.

const PARTS: Dictionary = {
	"BasinFloor": [Vector3(0, 0.1, 0), Vector3(8.4, 0.2, 3.8), "5c6261"],
	"BasinFront": [Vector3(0, 0.4, -1.75), Vector3(8.4, 0.6, 0.3), "77786d"],
	"BasinLeft": [Vector3(-4.05, 0.4, 0), Vector3(0.3, 0.6, 3.2), "77786d"],
	"BasinRight": [Vector3(4.05, 0.4, 0), Vector3(0.3, 0.6, 3.2), "77786d"],
	"BasinBack": [Vector3(0, 0.4, 1.75), Vector3(8.4, 0.6, 0.3), "77786d"],
	"Pool": [Vector3(0, 0.33, -0.95), Vector3(7.8, 0.06, 1.3), "387f91"],
	"RockLower": [Vector3(0, 0.75, 0.5), Vector3(7.6, 1.1, 2.2), "7d8073"],
	"RockMiddle": [Vector3(-0.15, 1.8, 0.65), Vector3(6.7, 1.0, 1.9), "696f67"],
	"RockCrownLeft": [Vector3(-1.9, 2.85, 0.85), Vector3(2.7, 1.1, 1.5), "969887"],
	"RockCrownRight": [Vector3(1.2, 3.05, 0.85), Vector3(3.2, 1.5, 1.5), "838b7c"],
	"RockShoulderLeft": [Vector3(-3.15, 1.65, 0.75), Vector3(0.9, 0.7, 1.5), "93937e"],
	"RockShoulderRight": [Vector3(3.05, 1.55, 0.75), Vector3(0.9, 0.5, 1.5), "93937e"],
	"SpillLip": [Vector3(0.5, 3.05, -0.02), Vector3(2.3, 0.16, 0.7), "a8aa96"],
	"UpperWater": [Vector3(0.5, 2.33, -0.385), Vector3(1.9, 1.6, 0.05), "69b2bc"],
	"CatchLedge": [Vector3(0.35, 1.5, -0.48), Vector3(2.8, 0.2, 0.55), "949982"],
	"LowerWater": [Vector3(0.35, 0.9, -0.78), Vector3(2.4, 1.1, 0.05), "69b2bc"],
	"Foam": [Vector3(0.35, 0.38, -0.95), Vector3(2.7, 0.06, 0.5), "c1ded6"],
	"UpperRillA": [Vector3(0.0, 2.33, -0.416), Vector3(0.09, 1.55, 0.012), "aedbd5"],
	"UpperRillB": [Vector3(0.9, 2.33, -0.416), Vector3(0.07, 1.55, 0.012), "aedbd5"],
	"LowerRillA": [Vector3(-0.35, 0.92, -0.811), Vector3(0.08, 1.04, 0.012), "aedbd5"],
	"LowerRillB": [Vector3(0.75, 0.92, -0.811), Vector3(0.10, 1.04, 0.012), "aedbd5"],
}


static func create() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ST046"
	root.set_meta("stadium_item", "ST-046")
	root.set_meta("working_geometry_only", true)
	root.set_meta("geometry_version", 1)
	root.set_meta("obstacle_units", 0)
	root.set_meta("night_qualified", false)
	for id: String in PARTS:
		var part: MeshInstance3D = MeshInstance3D.new()
		part.name = id
		part.position = PARTS[id][0]
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = PARTS[id][1]
		part.mesh = mesh
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(PARTS[id][2])
		material.roughness = 0.85
		part.material_override = material
		root.add_child(part)
	return root


static func valid(root: Node3D) -> bool:
	if root == null or root.get_class() != "Node3D" or not _clean(root) \
		or root.get_child_count() != PARTS.size() \
		or not _meta(root, "stadium_item", TYPE_STRING, "ST-046") \
		or not _meta(root, "working_geometry_only", TYPE_BOOL, true) \
		or not _meta(root, "geometry_version", TYPE_INT, 1) \
		or not _meta(root, "obstacle_units", TYPE_INT, 0) \
		or not _meta(root, "night_qualified", TYPE_BOOL, false):
		return false
	for id: String in PARTS:
		var part: MeshInstance3D = root.get_node_or_null(id) as MeshInstance3D
		if part == null or not _clean(part) or part.get_child_count() != 0 \
			or part.transform != Transform3D(Basis.IDENTITY, PARTS[id][0]) \
			or not part.mesh is BoxMesh or part.mesh.size != PARTS[id][1] \
			or part.mesh.get_script() != null or part.mesh.flip_faces or part.mesh.subdivide_width != 0 \
			or part.mesh.subdivide_height != 0 or part.mesh.subdivide_depth != 0 \
			or part.material_overlay != null or part.get_surface_override_material(0) != null \
			or part.mesh.material != null or part.layers != 1 or part.transparency != 0.0:
			return false
		if not _material(part.material_override, Color(PARTS[id][2])) \
			or not _render_state(part):
			return false
	return true


static func _clean(node: Node3D) -> bool:
	return node.get_script() == null and node.visible and not node.top_level \
		and node.process_mode == Node.PROCESS_MODE_INHERIT


static func _meta(node: Node, key: String, kind: int, expected: Variant) -> bool:
	if not node.has_meta(key) or typeof(node.get_meta(key)) != kind:
		return false
	return node.get_meta(key) == expected


static func _material(actual: Material, color: Color) -> bool:
	if not actual is StandardMaterial3D or actual.get_script() != null:
		return false
	var expected: StandardMaterial3D = StandardMaterial3D.new()
	expected.albedo_color = color
	expected.roughness = 0.85
	# Bind every persisted material setting, including GPU deformation and depth behavior.
	# Resource names/locality do not affect presentation and may differ in imported copies.
	for property: Dictionary in expected.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name in [
			"resource_name", "resource_local_to_scene"]:
			continue
		var value: Variant = actual.get(property.name)
		var canonical: Variant = expected.get(property.name)
		if typeof(value) != typeof(canonical) or value != canonical:
			return false
	return true


static func _render_state(node: MeshInstance3D) -> bool:
	var expected: MeshInstance3D = MeshInstance3D.new()
	var valid: bool = true
	for property: String in ["cast_shadow", "extra_cull_margin", "ignore_occlusion_culling",
		"lod_bias", "gi_mode", "visibility_range_begin", "visibility_range_begin_margin",
		"visibility_range_end", "visibility_range_end_margin", "visibility_range_fade_mode",
		"sorting_offset", "sorting_use_aabb_center", "custom_aabb"]:
		if node.get(property) != expected.get(property):
			valid = false
	expected.free()
	return valid
