extends RefCounted
## Independent literal contract; never reads Models.PARTS or a generated reference copy.

const EXPECTED: Dictionary = {
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


static func valid(root: Node3D) -> bool:
	if root.get_child_count() != 21 or root.get_class() != "Node3D" \
		or not _clean(root):
		return false
	for id: String in EXPECTED:
		var node: MeshInstance3D = root.get_node_or_null(id) as MeshInstance3D
		if node == null or not _clean(node) or node.get_child_count() != 0 \
			or node.transform != Transform3D(Basis.IDENTITY, EXPECTED[id][0]) \
			or not node.mesh is BoxMesh or node.mesh.size != EXPECTED[id][1] \
			or node.mesh.get_script() != null or node.mesh.flip_faces or node.mesh.subdivide_width != 0 \
			or node.mesh.subdivide_height != 0 or node.mesh.subdivide_depth != 0 \
			or node.mesh.material != null or node.material_overlay != null \
			or node.get_surface_override_material(0) != null or node.layers != 1 \
			or node.transparency != 0.0:
			return false
		if not _material(node.material_override, Color(EXPECTED[id][2])) \
			or not _render_state(node):
			return false
	return true


static func _clean(node: Node3D) -> bool:
	return node.get_script() == null and node.visible and not node.top_level \
		and node.process_mode == Node.PROCESS_MODE_INHERIT


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
