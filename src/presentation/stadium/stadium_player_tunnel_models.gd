class_name StadiumPlayerTunnelModels
extends RefCounted
## CI4 one symmetric complete shell. All geometry is beyond the dugout dead boundary.
## The same authored shell opens one existing lateral cap under a proper rigid pose.

const VERSION: int = 1
const ITEM: String = "ST-058"
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const ENVELOPE: AABB = AABB(Vector3(-1, 0, 0), Vector3(2, 2.7, 4.6))
const REAR_PORT: AABB = AABB(Vector3(-0.75, 0, 0), Vector3(1.5, 2.4, 0))
const LATERAL_Z: Vector2 = Vector2(2.6, 4.6)
const ROOF_UNDERSIDE: float = 2.4
const PORT_CAPS: Array[String] = ["LateralCapNegative", "LateralCapPositive"]
const CONCRETE: Color = Color("87988a")
const TRIM: Color = Color("435e56")
const INNER: Color = Color("b6bcaa")


static func create(item: String = ITEM, placement: Dictionary = {}) -> Node3D:
	if item != ITEM:
		return null
	if not placement.is_empty() and (not placement.get("left") is bool \
		or not placement.get("copy") is String or str(placement.copy).is_empty() \
		or not placement.get("dugout") is String or str(placement.dugout).is_empty() \
		or not placement.get("lower") is String or str(placement.lower).is_empty() \
		or placement.get("site") != ("TUNNEL-L" if placement.left else "TUNNEL-R")):
		return null
	var root: Node3D = Node3D.new()
	root.name = "ST058CoveredPlayerTunnel"
	for branch: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = branch
		root.add_child(child)
	root.set_meta("stadium_item", ITEM)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("final_art_accepted", false)
	root.set_meta("envelope", ENVELOPE)
	root.set_meta("surface_role", ROLE)
	root.set_meta("physics_profile", ROLE)
	root.set_meta("scenery_only", true)
	root.set_meta("obstacle_units", 0)
	root.set_meta("walkout_simulation", false)
	root.set_meta("new_live_passage", false)
	root.set_meta("bundled_roof_supports_caps", true)
	root.set_meta("symmetric_shell", true)
	root.set_meta("active_host_side", 0 if placement.is_empty() else (1 if placement.left else -1))
	root.set_meta("rear_port", REAR_PORT)
	root.set_meta("lateral_port_z", LATERAL_Z)
	_box(root, "Roof", Vector3(-1, 2.4, 0), Vector3(2, 0.3, 4.6), CONCRETE)
	for side: int in [-1, 1]:
		var x: float = -1.0 if side < 0 else 0.88
		_box(root, "SideWall%d" % side, Vector3(x, 0, 0), Vector3(0.12, 2.4, 2.6), CONCRETE)
		_box(root, "EntryJamb%d" % side, Vector3(-0.88 if side < 0 else 0.75, 0, 0),
			Vector3(0.13, 2.4, 0.25), TRIM)
		var cap: String = PORT_CAPS[0 if side < 0 else 1]
		# Both caps belong to the one source assembly. Only the exact active port is omitted.
		if placement.is_empty() or side != (1 if placement.left else -1):
			_box(root, cap, Vector3(x, 0, 2.6), Vector3(0.12, 2.4, 2), CONCRETE)
	# Bevelled rear corners keep the exact x=+/-1, z=2.6..4.6 interface plane clear.
	# Every back-wall point remains inside the reservation; no unsealed corner slots.
	_prism(root, "RearWall", PackedVector2Array([Vector2(-1, 4.6), Vector2(1, 4.6),
		Vector2(0.88, 4.48), Vector2(-0.88, 4.48)]), 0, 2.4, INNER)
	if not placement.is_empty():
		root.set_meta("owned_copy", placement.copy)
		root.set_meta("site", placement.site)
		root.set_meta("dugout_copy", placement.dugout)
		root.set_meta("lower_copy", placement.lower)
		_bind(root, placement)
	return root


static func envelope(item: String = ITEM) -> AABB:
	return ENVELOPE if item == ITEM else AABB()


static func path_points(left: bool) -> PackedVector3Array:
	# Measured presentation path only; no actor, navmesh, fielder route or score is created.
	return PackedVector3Array([Vector3(0, 1.2, -0.7), Vector3(0, 1.2, 0.5),
		Vector3(0, 1.2, 3.6), Vector3(1.35 if left else -1.35, 1.2, 3.6)])


static func support_points() -> PackedVector3Array:
	return PackedVector3Array([Vector3(-0.94, 0, 1.3), Vector3(0.94, 0, 1.3),
		Vector3(0, 0, 4.54), Vector3(-0.815, 0, 0.125), Vector3(0.815, 0, 0.125)])


static func _bind(node: Node, placement: Dictionary) -> void:
	node.set_meta("stadium_item", ITEM)
	node.set_meta("owned_copy", placement.copy)
	node.set_meta("paid_copy", placement.copy)
	node.set_meta("site", placement.site)
	node.set_meta("dugout_copy", placement.dugout)
	node.set_meta("lower_copy", placement.lower)
	node.set_meta("surface_role", ROLE)
	for child: Node in node.get_children():
		_bind(child, placement)


static func _box(root: Node3D, id: String, low: Vector3, size: Vector3, color: Color) -> void:
	StadiumSeatingModels._box(root, id, low + size / 2, size, color)
	var body: StaticBody3D = root.get_node("Collision/" + id)
	body.get_child(0).name = "Shape"
	body.get_child(0).shape.margin = 0


static func _prism(root: Node3D, id: String, outline: PackedVector2Array,
	bottom: float, top: float, color: Color) -> void:
	var points: PackedVector3Array = []
	for y: float in [bottom, top]:
		for point: Vector2 in outline:
			points.append(Vector3(point.x, y, point.y))
	var mesh: SurfaceTool = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1],
		[1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		for index: int in [face[0], face[1], face[2], face[0], face[2], face[3]]:
			mesh.add_vertex(points[index])
	mesh.generate_normals()
	mesh.index()
	StadiumSeatingModels._mesh(root.get_node("Visual"), id, mesh.commit(), Vector3.ZERO, color)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("stadium_item", ITEM)
	body.set_meta("surface_role", ROLE)
	body.set_meta("surface_id", id)
	body.set_meta("ball_surface", &"stadium_scenery")
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Shape"
	collision.shape = ConvexPolygonShape3D.new()
	collision.shape.margin = 0
	collision.shape.points = points
	body.add_child(collision)
	root.get_node("Collision").add_child(body)
