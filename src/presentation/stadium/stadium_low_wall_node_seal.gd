class_name StadiumLowWallNodeSeal
extends RefCounted
# Candidate3 critical hot schema. Full serialized state remains at transitions.
var node: Node3D
var parent: Node
var node_name: StringName
var children: Array[Node]
var metadata: Dictionary
var visual: MeshInstance3D
var body: StaticBody3D
var collision: CollisionShape3D
var surface_materials: Array[Material] = []
var n_transform: Transform3D
var n_top_level: bool
var n_visible: bool
var n_process_mode: int
var n_visibility_parent: NodePath
var n_physics_interpolation_mode: int
var v_mesh: Mesh
var v_material_override: Material
var v_material_overlay: Material
var v_transparency: float
var v_cast_shadow: int
var v_layers: int
var v_extra_cull_margin: float
var v_custom_aabb: AABB
var v_lod_bias: float
var v_ignore_occlusion_culling: bool
var v_visibility_range_begin: float
var v_visibility_range_begin_margin: float
var v_visibility_range_end: float
var v_visibility_range_end_margin: float
var v_visibility_range_fade_mode: int
var v_sorting_offset: float
var v_sorting_use_aabb_center: bool
var v_gi_mode: int
var v_gi_lightmap_texel_scale: int
var v_skin: Skin
var v_skeleton: NodePath
var b_collision_layer: int
var b_collision_mask: int
var b_collision_priority: float
var b_disable_mode: int
var b_physics_material_override: PhysicsMaterial
var b_constant_linear_velocity: Vector3
var b_constant_angular_velocity: Vector3
var c_shape: Shape3D
var c_disabled: bool


func _init(source: Node3D) -> void:
	node = source
	parent = node.get_parent()
	node_name = node.name
	children.assign(node.get_children(true))
	metadata = _metadata(node)
	n_transform = node.transform
	n_top_level = node.top_level
	n_visible = node.visible
	n_process_mode = node.process_mode
	n_visibility_parent = node.visibility_parent
	n_physics_interpolation_mode = node.physics_interpolation_mode
	if node is MeshInstance3D:
		visual = node as MeshInstance3D
		v_mesh = visual.mesh
		v_material_override = visual.material_override
		v_material_overlay = visual.material_overlay
		v_transparency = visual.transparency
		v_cast_shadow = visual.cast_shadow
		v_layers = visual.layers
		v_extra_cull_margin = visual.extra_cull_margin
		v_custom_aabb = visual.custom_aabb
		v_lod_bias = visual.lod_bias
		v_ignore_occlusion_culling = visual.ignore_occlusion_culling
		v_visibility_range_begin = visual.visibility_range_begin
		v_visibility_range_begin_margin = visual.visibility_range_begin_margin
		v_visibility_range_end = visual.visibility_range_end
		v_visibility_range_end_margin = visual.visibility_range_end_margin
		v_visibility_range_fade_mode = visual.visibility_range_fade_mode
		v_sorting_offset = visual.sorting_offset
		v_sorting_use_aabb_center = visual.sorting_use_aabb_center
		v_gi_mode = visual.gi_mode
		v_gi_lightmap_texel_scale = visual.gi_lightmap_texel_scale
		v_skin = visual.skin
		v_skeleton = visual.skeleton
		for index in range(visual.mesh.get_surface_count()):
			surface_materials.append(visual.get_surface_override_material(index))
	if node is StaticBody3D:
		body = node as StaticBody3D
		b_collision_layer = body.collision_layer
		b_collision_mask = body.collision_mask
		b_collision_priority = body.collision_priority
		b_disable_mode = body.disable_mode
		b_physics_material_override = body.physics_material_override
		b_constant_linear_velocity = body.constant_linear_velocity
		b_constant_angular_velocity = body.constant_angular_velocity
	if node is CollisionShape3D:
		collision = node as CollisionShape3D
		c_shape = collision.shape
		c_disabled = collision.disabled


func intact() -> bool:
	if (
		not is_instance_valid(node)
		or node.is_queued_for_deletion()
		or node.get_script() != null
		or not is_same(node.get_parent(), parent)
		or node.name != node_name
		or node.get_children(true) != children
		or _metadata(node) != metadata
	):
		return false
	if (
		node.transform != n_transform
		or node.top_level != n_top_level
		or node.visible != n_visible
		or node.process_mode != n_process_mode
		or node.visibility_parent != n_visibility_parent
		or node.physics_interpolation_mode != n_physics_interpolation_mode
	):
		return false
	if visual != null and not _visual_intact():
		return false
	if body != null:
		if (
			body.collision_layer != b_collision_layer
			or body.collision_mask != b_collision_mask
			or body.collision_priority != b_collision_priority
			or body.disable_mode != b_disable_mode
			or not is_same(body.physics_material_override, b_physics_material_override)
			or body.constant_linear_velocity != b_constant_linear_velocity
			or body.constant_angular_velocity != b_constant_angular_velocity
		):
			return false
	if collision != null:
		if not is_same(collision.shape, c_shape) or collision.disabled != c_disabled:
			return false
	return true


func _visual_intact() -> bool:
	if (
		not is_same(visual.mesh, v_mesh)
		or not is_same(visual.material_override, v_material_override)
		or not is_same(visual.material_overlay, v_material_overlay)
		or visual.transparency != v_transparency
		or visual.cast_shadow != v_cast_shadow
		or visual.layers != v_layers
		or visual.extra_cull_margin != v_extra_cull_margin
		or visual.custom_aabb != v_custom_aabb
		or visual.lod_bias != v_lod_bias
		or visual.ignore_occlusion_culling != v_ignore_occlusion_culling
		or visual.visibility_range_begin != v_visibility_range_begin
		or visual.visibility_range_begin_margin != v_visibility_range_begin_margin
		or visual.visibility_range_end != v_visibility_range_end
		or visual.visibility_range_end_margin != v_visibility_range_end_margin
		or visual.visibility_range_fade_mode != v_visibility_range_fade_mode
		or visual.sorting_offset != v_sorting_offset
		or visual.sorting_use_aabb_center != v_sorting_use_aabb_center
		or visual.gi_mode != v_gi_mode
		or visual.gi_lightmap_texel_scale != v_gi_lightmap_texel_scale
		or not is_same(visual.skin, v_skin)
		or visual.skeleton != v_skeleton
	):
		return false
	if visual.mesh.get_surface_count() != surface_materials.size():
		return false
	for index in range(surface_materials.size()):
		if not is_same(visual.get_surface_override_material(index), surface_materials[index]):
			return false
	return true


static func _metadata(object: Object) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in object.get_meta_list():
		var value: Variant = object.get_meta(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result
