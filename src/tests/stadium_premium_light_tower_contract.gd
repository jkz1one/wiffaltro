extends RefCounted
## Independent literals: no factory constants or generated reference copy.


static func valid(root: Node3D) -> bool:
	if root.get_child_count() != 2 or not _clean(root) or not _active_ancestors(root) \
		or not root.has_node("Visual") or not root.has_node("Collision"):
		return false
	var visual: Node3D = root.get_node("Visual")
	var collision: Node3D = root.get_node("Collision")
	if visual.transform != Transform3D.IDENTITY or collision.transform != Transform3D.IDENTITY \
		or visual.get_child_count() != 82 or collision.get_child_count() != 3:
		return false
	var parts: Dictionary = {
		"Footing": [Vector3(0, 0.18, 0), Vector3(1.1, 0.36, 1.1)],
		"BasePlate": [Vector3(0, 0.41, 0), Vector3(0.6, 0.1, 0.6)],
		"Crossbar0": [Vector3(0, 16.7, 0), Vector3(2.8, 0.18, 0.22)],
		"Crossbar1": [Vector3(0, 17.5, 0), Vector3(2.8, 0.18, 0.22)],
	}
	for side: int in [-1, 1]:
		parts["LadderRail%d" % side] = [Vector3(side * 0.23, 8.875, -0.27),
			Vector3(0.04, 16.75, 0.04)]
	for height: float in [0.9, 8.8, 16.9]:
		parts["LadderBracket%d" % int(height * 10)] = [Vector3(0, height, -0.13),
			Vector3(0.5, 0.07, 0.30)]
	for rung in range(56):
		parts["LadderRung%02d" % rung] = [Vector3(0, 0.65 + rung * 0.3, -0.27),
			Vector3(0.46, 0.03, 0.04)]
	var target: Vector3 = Vector3(0, 1.5, 40)
	if root.has_meta("reference_target"):
		target = root.transform.affine_inverse() * root.get_meta("reference_target")
	var xs: Array[float] = [-1.05, -0.35, 0.35, 1.05]
	for index in range(8):
		var row: int = 1 if index >= 4 else 0
		parts["HeadStem%d" % index] = [Vector3(xs[index % 4], 16.88 + row * 0.8, 0),
			Vector3(0.07, 0.36, 0.07)]
		var head: Node3D = visual.get_node_or_null("Head%d" % index)
		if head == null or head.get_child_count() != 2 \
			or head.position != Vector3(xs[index % 4], 17.05 + row * 0.8, 0) \
			or not head.basis.is_conformal() or not head.scale.is_equal_approx(Vector3.ONE):
			return false
		var aim: Basis = Basis(Quaternion(Vector3.BACK, (target - head.position).normalized()))
		if not head.basis.is_equal_approx(aim):
			return false
		if not _box(head.get_node_or_null("Housing"), Vector3.ZERO,
			Vector3(0.55, 0.44, 0.28), Color("31444d"), 0.7) \
			or not _box(head.get_node_or_null("Lens"), Vector3(0, 0, 0.147),
				Vector3(0.47, 0.36, 0.014), Color("f3ecd2"), 0.7):
			return false
	for id: String in parts:
		if not _box(visual.get_node_or_null(id), parts[id][0], parts[id][1], Color("697b80"), 0.85):
			return false
	var mast: MeshInstance3D = visual.get_node_or_null("Mast")
	if mast == null or not mast.mesh is CylinderMesh \
		or mast.transform != Transform3D(Basis.IDENTITY, Vector3(0, 8.98, 0)) \
		or mast.mesh.top_radius != _f32(0.16) or mast.mesh.bottom_radius != _f32(0.16) \
		or mast.mesh.height != _f32(17.1) or mast.mesh.radial_segments != 16 \
		or mast.mesh.rings != 4 or not mast.mesh.cap_top or not mast.mesh.cap_bottom \
		or mast.mesh.flip_faces \
		or not _material(mast, Color("697b80"), 0.85):
		return false
	for id: String in ["Footing", "BasePlate", "Mast"]:
		var body: StaticBody3D = collision.get_node_or_null(id)
		if body == null or body.get_child_count() != 1 or body.collision_layer != 1 \
			or body.collision_mask != 0 or body.disable_mode != CollisionObject3D.DISABLE_MODE_REMOVE \
			or body.has_meta("ball_surface") \
			or body.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL" \
			or body.transform != visual.get_node(id).transform:
			return false
		var collider: CollisionShape3D = body.get_child(0) as CollisionShape3D
		if collider == null or collider.disabled or collider.transform != Transform3D.IDENTITY \
			or collider.shape == null or collider.shape.margin != Vector3(0.04, 0, 0).x:
			return false
		if id == "Mast":
			if not collider.shape is CylinderShape3D or collider.shape.radius != _f32(0.16) \
				or collider.shape.height != _f32(17.1):
				return false
		elif not collider.shape is BoxShape3D or collider.shape.size != parts[id][1]:
			return false
	return true


static func _box(node: Node, point: Vector3, size: Vector3, color: Color, rough: float) -> bool:
	return node is MeshInstance3D and node.mesh is BoxMesh \
		and node.transform == Transform3D(Basis.IDENTITY, point) and node.mesh.size == size \
		and node.mesh.subdivide_width == 0 and node.mesh.subdivide_height == 0 \
		and node.mesh.subdivide_depth == 0 and not node.mesh.flip_faces \
		and _material(node, color, rough)


static func _material(node: MeshInstance3D, color: Color, rough: float) -> bool:
	var material: StandardMaterial3D = node.material_override as StandardMaterial3D
	return material != null and material.albedo_color == color \
		and material.roughness == _f32(rough) and not material.emission_enabled \
		and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
		and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL \
		and material.cull_mode == BaseMaterial3D.CULL_BACK and material.next_pass == null \
		and not material.grow and material.grow_amount == 0.0 \
		and material.albedo_texture == null and node.material_overlay == null \
		and node.get_surface_override_material(0) == null and node.layers == 1 \
		and node.transparency == 0.0


static func _clean(node: Node) -> bool:
	if node.get_script() != null or node is Light3D or node.process_mode != Node.PROCESS_MODE_INHERIT \
		or (node is Node3D and (not node.visible or node.top_level)):
		return false
	if (node is MeshInstance3D or node is CollisionShape3D) and node.get_child_count() != 0:
		return false
	for child: Node in node.get_children():
		if not _clean(child):
			return false
	return true


static func _f32(value: float) -> float:
	# Engine CylinderMesh/CylinderShape3D and BaseMaterial3D store C++ float.
	# Convert only the independent expected literal, retaining exact property equality.
	return PackedFloat32Array([value])[0]


static func _active_ancestors(root: Node) -> bool:
	var parent: Node = root.get_parent()
	while parent != null:
		if parent.process_mode != Node.PROCESS_MODE_INHERIT:
			return parent.process_mode != Node.PROCESS_MODE_DISABLED
		parent = parent.get_parent()
	return true
