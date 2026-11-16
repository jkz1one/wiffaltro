class_name StadiumTransitionConcourseModels
extends RefCounted
## Two separate Working purchases; roofless represented access, never a free bundle.

const S = preload("res://src/gameplay/stadium/stadium_transition_concourse_sites.gd")
const L = preload("res://src/gameplay/stadium/stadium_lower_transition_sites.gd")
const BREAKS: Array[float] = [0, 0.1, 0.2, 0.3, 0.4, 0.6, 0.7, 0.8, 0.9, 1]


static func create_right(join: Node3D, bowl: Node3D, curved: Node3D,
	base: Node3D, straight: Node3D) -> Node3D:
	return _create("JOIN-R", join, bowl, curved, base, straight)


static func create_left(join: Node3D, bowl: Node3D, curved: Node3D,
	base: Node3D, straight: Node3D) -> Node3D:
	return _create("JOIN-L", join, bowl, curved, base, straight)


static func _create(site: String, join: Node3D, bowl: Node3D, curved: Node3D,
	base: Node3D, straight: Node3D) -> Node3D:
	if not S.valid_hosts(site, join, bowl, curved, base, straight):
		return null
	var root: Node3D = _model(site)
	if root == null:
		return null
	root.set_meta("lower_instance", join.get_instance_id())
	root.set_meta("bowl_instance", bowl.get_instance_id())
	root.set_meta("curved_concourse_instance", curved.get_instance_id())
	root.set_meta("baseline_instance", base.get_instance_id())
	root.set_meta("straight_concourse_instance", straight.get_instance_id())
	return root


static func _model(site: String) -> Node3D:
	var root: Node3D = StadiumBaselineStandModels._root(S.item(site))
	root.name = "ST086RightConcourseWorking" if site == "JOIN-R" else "ST089LeftConcourseWorking"
	root.set_meta("model_version", 1)
	root.set_meta("authoring_status", "Working")
	root.set_meta("site", site)
	root.set_meta("interface", S.INTERFACE)
	root.set_meta("represented_seats", 0)
	root.set_meta("access", "stylized stepped cap crossings; not full-width traversable circulation")
	for index in range(9):
		_patch(root, "Terrace%d" % index, BREAKS[index], BREAKS[index + 1],
			7, 10, 0, 5.50 + index * 0.20)
		_patch(root, "RearGuard%d" % index, BREAKS[index], BREAKS[index + 1],
			9.82, 10, 5.50 + index * 0.20, 6.25 + index * 0.20, "bbc2ae")
	# Exact affine underside touches the actual frozen lower RearRim over u6.75..6.88.
	var bottom: PackedVector3Array = []
	var top: PackedVector3Array = []
	for pair: Vector2 in [Vector2(0.45, 6.75), Vector2(0.55, 6.75),
		Vector2(0.55, 7.15), Vector2(0.45, 7.15)]:
		bottom.append(L.point(site, pair.x, pair.y,
			StadiumLowerTransitionModels.deck(site, 5, pair.x, pair.y) + 0.75))
		top.append(L.point(site, pair.x, pair.y, 6.15))
	_quad(root, "LowerSaddle", bottom, top, "64796e")
	_bowl(root)
	_baseline(root)
	if not complete(root):
		root.free()
		return null
	return root


static func _patch(root: Node3D, id: String, t0: float, t1: float, u0: float,
	u1: float, low: float, high: float, color: String = "c5b38d") -> void:
	var bottom: PackedVector3Array = []
	var top: PackedVector3Array = []
	for pair: Vector2 in [Vector2(t0, u0), Vector2(t1, u0), Vector2(t1, u1), Vector2(t0, u1)]:
		bottom.append(L.point(root.get_meta("site"), pair.x, pair.y, low))
		top.append(L.point(root.get_meta("site"), pair.x, pair.y, high))
	_quad(root, id, bottom, top, color)


static func _bowl(root: Node3D) -> void:
	_arc(root, "BowlBridge", 105, 106.3, 5.35, 5.50)
	_arc(root, "BowlLanding", 106.0, 106.3, 4.55, 5.35)
	# Four raised treads plus the actual host floor give five 0.19m drops.
	for step in range(4):
		_arc(root, "BowlTread%d" % step, 106.3 + step * 0.5,
			106.8 + step * 0.5, 4.55, 5.31 - step * 0.19)


static func _arc(root: Node3D, id: String, a0: float, a1: float,
	low: float, high: float) -> void:
	var bottom: PackedVector3Array = []
	var top: PackedVector3Array = []
	for pair: Vector2 in [Vector2(26.2, a0), Vector2(27.4, a0),
		Vector2(27.4, a1), Vector2(26.2, a1)]:
		var point: Vector3 = StadiumCurvedLowerModels.polar(pair.x, pair.y, low)
		if root.get_meta("site") == "JOIN-L":
			point.x = -point.x
		bottom.append(point)
		point.y = high
		top.append(point)
	_quad(root, id, bottom, top, "a5b3a1")


static func _baseline(root: Node3D) -> void:
	if root.get_meta("site") == "JOIN-R":
		_base_box(root, "BaselineBridge", 2.40, 3.05, 8.20, 8.45, 6.95, 7.10)
		_base_box(root, "BaselineLanding", 2.40, 2.78, 8.20, 8.45, 6.15, 6.95)
		for step in range(4):
			_base_box(root, "BaselineTread%d" % step, 2.40, 2.78,
				8.45 + step * 0.30, 8.75 + step * 0.30, 6.15, 6.91 - step * 0.19)
	else:
		_base_box(root, "BaselineBridge", -3.05, -2.65, 8.30, 9.50, 6.95, 7.10)
		_base_box(root, "BaselineLanding", -2.80, -2.65, 8.30, 9.50, 6.15, 6.95)
		for step in range(4):
			_base_box(root, "BaselineTread%d" % step, -2.65 + step * 0.30,
				-2.35 + step * 0.30, 8.30, 9.50, 6.15, 6.91 - step * 0.19)


static func _base_box(root: Node3D, id: String, x0: float, x1: float,
	z0: float, z1: float, low: float, high: float) -> void:
	var pose: Transform3D = StadiumBaselineSites.pose(S.base_site(root.get_meta("site")))
	var bottom: PackedVector3Array = []
	var top: PackedVector3Array = []
	for pair: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]:
		bottom.append(pose * Vector3(pair.x, low, pair.y))
		top.append(pose * Vector3(pair.x, high, pair.y))
	_quad(root, id, bottom, top, "a5b3a1")


static func _quad(root: Node3D, id: String, bottom: PackedVector3Array,
	top: PackedVector3Array, color: String) -> void:
	# Each rendered triangular prism is EXACTLY its convex collider, including the
	# affine saddle. No nonplanar rendered quad is substituted with a convex hull.
	for index in range(2):
		var corners: Array[int] = []
		corners.assign([0, 1, 2] if index == 0 else [0, 2, 3])
		var points: PackedVector3Array = []
		for layer: PackedVector3Array in [bottom, top]:
			for corner: int in corners:
				points.append(layer[corner])
		_prism(root, id + ("A" if index == 0 else "B"), points, color)


static func _prism(root: Node3D, id: String, points: PackedVector3Array, color: String) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center: Vector3 = Vector3.ZERO
	for point: Vector3 in points:
		center += point / 6
	for face: Array in [[0, 1, 2], [3, 4, 5], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]]:
		if (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]]).dot(
			points[face[0]] - center) > 0:
			face.reverse()
		var order: Array[int] = []
		order.assign([0, 1, 2] if face.size() == 3 else [0, 1, 2, 0, 2, 3])
		for corner: int in order:
			surface.add_vertex(points[face[corner]])
	surface.generate_normals()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = id
	mesh.mesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.9
	mesh.material_override = material
	root.get_node("Visual").add_child(mesh)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("stadium_item", root.get_meta("stadium_item"))
	body.set_meta("surface_id", id)
	body.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
	body.set_meta("ball_surface", &"stadium_scenery")
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = ConvexPolygonShape3D.new()
	shape.shape.points = points
	shape.shape.margin = 0
	body.add_child(shape)
	root.get_node("Collision").add_child(body)


static func complete(root: Node3D) -> bool:
	# Script execution can return a non-null partial Node after a construction error.
	# Never bind or return that partial model as a valid purchased assembly.
	if not is_instance_valid(root) or root.get_child_count() != 2 \
		or not root.has_node("Visual") or not root.has_node("Collision"):
		return false
	if root.get_node("Visual").get_child_count() != 62 \
		or root.get_node("Collision").get_child_count() != 62:
		return false
	for node: Node in root.get_node("Collision").get_children():
		var body: StaticBody3D = node as StaticBody3D
		if body == null or body.get_child_count() != 1:
			return false
		var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
		var mesh: MeshInstance3D = root.get_node_or_null("Visual/" + str(body.name)) as MeshInstance3D
		if shape == null or not shape.shape is ConvexPolygonShape3D or mesh == null \
			or not mesh.mesh is ArrayMesh or mesh.mesh.get_surface_count() != 1:
			return false
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array \
			or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			return false
		if shape.shape.points.size() != 6 or arrays[Mesh.ARRAY_VERTEX].size() != 24 \
			or arrays[Mesh.ARRAY_NORMAL].size() != 24 or mesh.material_override == null \
			or mesh.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
			return false
	return true
