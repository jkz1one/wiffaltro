extends RefCounted
## Conservative ball-center occlusion, independent of physics collision geometry.
## Only undeformed triangle meshes with ordinary opaque materials can prove a hit.
## Unknown shaders, fades, skinning and transparency deliberately yield false negatives.
## Supports non-mirrored PrimitiveMesh/ArrayMesh triangle surfaces; not a full-shell proof.
## Visibility-parent/HLOD, automatic surface LODs, deformation and custom shaders are skipped.
## Reads live surfaces/materials each sample: resource edits cannot leave a stale cache.
# gdlint: disable=max-returns


static func blocked(root: Node3D, camera: Camera3D, ball: Node3D) -> bool:
	if not is_instance_valid(root) or not is_instance_valid(camera) or not is_instance_valid(ball):
		return false
	if not root.is_inside_tree() or not camera.is_inside_tree() or not ball.is_inside_tree():
		return false
	var target: Vector3 = ball.global_position
	if not target.is_finite() or not camera.is_position_in_frustum(target):
		return false
	# project_position handles perspective, orthographic and off-center frustum cameras.
	var start: Vector3 = camera.project_position(camera.unproject_position(target), camera.near)
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node: Node in meshes:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance == ball or ball.is_ancestor_of(instance):
			continue
		if _mesh_blocks(instance, camera, start, target):
			return true
	return false


static func _mesh_blocks(
	instance: MeshInstance3D, camera: Camera3D, start: Vector3, end: Vector3
) -> bool:
	var mesh: Mesh = instance.mesh
	if (
		mesh == null
		or not instance.is_visible_in_tree()
		or (instance.layers & camera.cull_mask) == 0
	):
		return false
	if (
		instance.transparency > 0.0
		or instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		or instance.material_overlay != null
		or not instance.visibility_parent.is_empty()
		or instance.skin != null
		or (mesh is ArrayMesh and (mesh as ArrayMesh).get_blend_shape_count() > 0)
		or instance.visibility_range_begin != 0.0
		or instance.visibility_range_end != 0.0
		or instance.global_basis.determinant() <= 0.000001
	):
		return false
	var inverse: Transform3D = instance.global_transform.affine_inverse()
	var local_start: Vector3 = inverse * start
	var local_end: Vector3 = inverse * end
	var box: AABB = mesh.get_aabb()
	if not box.has_point(local_start) and not box.has_point(local_end):
		if box.intersects_segment(local_start, local_end) == null:
			return false
	# Normalize small authored geometry before Godot's fixed-epsilon triangle test.
	var center: Vector3 = box.get_center()
	var radius: float = box.size.length() * 0.5
	var factor: float = 1.0 / radius if radius > 0.0 and radius < 1.0 else 1.0
	local_start = (local_start - center) * factor
	local_end = (local_end - center) * factor
	for surface: int in range(mesh.get_surface_count()):
		if not _triangles(mesh, surface):
			continue
		# The renderer can select different indices from the full-detail surface arrays.
		# Without its exact LOD decision those triangles cannot prove a current blocker.
		if (
			mesh is ArrayMesh
			and not (
				RenderingServer.mesh_get_surface(mesh.get_rid(), surface).get("lods", []).is_empty()
			)
		):
			continue
		var material: Material = instance.get_active_material(surface)
		if not _opaque(material):
			continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		if arrays[Mesh.ARRAY_BONES] != null and not arrays[Mesh.ARRAY_BONES].is_empty():
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		var count: int = vertices.size() if indices.is_empty() else indices.size()
		var cull: int = (
			BaseMaterial3D.CULL_BACK if material == null else (material as BaseMaterial3D).cull_mode
		)
		for index: int in range(0, count - 2, 3):
			var a: Vector3 = (
				(vertices[index if indices.is_empty() else indices[index]] - center) * factor
			)
			var b: Vector3 = (
				(vertices[index + 1 if indices.is_empty() else indices[index + 1]] - center)
				* factor
			)
			var c: Vector3 = (
				(vertices[index + 2 if indices.is_empty() else indices[index + 2]] - center)
				* factor
			)
			# Godot front faces use clockwise winding, hence this sign (in mesh space).
			var facing: float = (b - a).cross(c - a).dot(local_end - local_start)
			if (
				(cull == BaseMaterial3D.CULL_BACK and facing <= 0.0)
				or (cull == BaseMaterial3D.CULL_FRONT and facing >= 0.0)
			):
				continue
			var hit: Variant = Geometry3D.segment_intersects_triangle(
				local_start, local_end, a, b, c
			)
			if hit != null and (hit as Vector3).distance_to(local_end) > 0.000001 * factor:
				return true
	return false


static func _opaque(material: Material) -> bool:
	if material == null:
		return true
	if not material is BaseMaterial3D:
		return false
	var base: BaseMaterial3D = material as BaseMaterial3D
	return (
		base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		and base.albedo_color.a >= 1.0
		and base.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED
		and not base.grow
		and not base.proximity_fade_enabled
		and base.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED
		and not base.no_depth_test
		and not base.use_point_size
		and base.next_pass == null
	)


static func _triangles(mesh: Mesh, surface: int) -> bool:
	if mesh is ArrayMesh:
		return (mesh as ArrayMesh).surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES
	return mesh is PrimitiveMesh and not mesh is PointMesh
