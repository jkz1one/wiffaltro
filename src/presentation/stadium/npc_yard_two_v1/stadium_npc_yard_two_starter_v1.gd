class_name StadiumNpcYardTwoStarterV1
extends RefCounted
## Retained byte-corresponding starter leaf from the qualified AY02 source.
## Prototype art; rest-pose collision stays separate from visual animation and route clearance.


const VERSION: int = 1


static func create(id: String) -> Node3D:
	if id not in ["ST-001", "ST-079"]:
		return null
	var root: Node3D = Node3D.new()
	root.name = id.replace("-", "")
	root.set_meta("stadium_item", id)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("prototype_only", true)
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var collision: Node3D = Node3D.new()
	collision.name = "Collision"
	root.add_child(collision)
	match id:
		"ST-001": _cone(root)
		"ST-003": _lawn_chair(root)
		"ST-079": _receiver_chair(root)
	return root


static func pitch_view(root: Node3D, batting: bool) -> void:
	if root.get_meta("stadium_item") != "ST-079":
		return
	root.get_node("Visual").visible = not batting
	# Visibility never removes, disables or moves a physical surface.


static func receiver_rock(
	root: Node3D, local_x: float, elapsed: float, event_index: int = 0
) -> void:
	if root.get_meta("stadium_item") != "ST-079":
		return
	var direction: float = signf(local_x) if local_x != 0 else (
		1.0 if event_index % 2 == 0 else -1.0)
	var progress: float = clampf(elapsed / 0.28, 0, 1)
	root.get_node("Visual").rotation.z = direction * deg_to_rad(6) \
		* sin(progress * TAU) * (1.0 - progress)


static func _cone(root: Node3D) -> void:
	_box(root, "CONE_BASE", Vector3(0, 0.02, 0), Vector3(0.35, 0.04, 0.35),
		Color("d94e16"), "LIVE_RICOCHET")
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.025
	cone.bottom_radius = 0.15
	cone.height = 0.46
	cone.radial_segments = 12
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	var points: PackedVector3Array = []
	for step in range(12):
		var angle: float = TAU * step / 12.0
		for ring: Vector2 in [Vector2(0.15, -0.23), Vector2(0.025, 0.23)]:
			points.append(Vector3(cos(angle) * ring.x, ring.y, sin(angle) * ring.x))
	shape.points = points
	_part(root, "CONE_BODY", Vector3(0, 0.27, 0), cone, shape, Color("f47a25"), "LIVE_RICOCHET")
	var stripe: CylinderMesh = CylinderMesh.new()
	stripe.top_radius = 0.067
	stripe.bottom_radius = 0.085
	stripe.height = 0.065
	stripe.radial_segments = 12
	_mesh(root, "ConeStripe", Vector3(0, 0.315, 0), stripe, Color("eee6ca"))


static func _lawn_chair(root: Node3D) -> void:
	var metal: Color = Color("a5b5ac")
	var fabric: Color = Color("315f57")
	_box(root, "LAWN_SEAT", Vector3(0, 0.40, 0.02), Vector3(0.62, 0.04, 0.70),
		fabric, "LIVE_RICOCHET")
	_box(root, "LAWN_BACK", Vector3(0, 0.685, -0.36), Vector3(0.62, 0.53, 0.045),
		fabric, "LIVE_RICOCHET")
	for side in [-1, 1]:
		_box(root, "LAWN_SIDE%d" % side, Vector3(side * 0.325, 0.42, 0.02),
			Vector3(0.04, 0.04, 0.74), metal, "LIVE_RICOCHET")
		_box(root, "LAWN_BACK_RAIL%d" % side, Vector3(side * 0.325, 0.69, -0.36),
			Vector3(0.04, 0.52, 0.04), metal, "LIVE_RICOCHET")
		for slope in [-1, 1]:
			_segment(root, "LAWN_SUPPORT%d_%d" % [side, slope],
				Vector3(side * 0.29, 0.025, slope * 0.35),
				Vector3(side * 0.29, 0.40, -slope * 0.30), 0.045, metal)
	for band in range(9):
		var color: Color = Color("e8dec0") if band % 2 == 0 else Color("54877a")
		var seat: BoxMesh = BoxMesh.new()
		seat.size = Vector3(0.043, 0.005, 0.67)
		_mesh(root, "SeatWeave%d" % band, Vector3(-0.272 + band * 0.068, 0.423, 0.02), seat, color)
		var back: BoxMesh = BoxMesh.new()
		back.size = Vector3(0.043, 0.50, 0.006)
		_mesh(root, "BackWeave%d" % band, Vector3(-0.272 + band * 0.068, 0.685, -0.333), back, color)


static func _receiver_chair(root: Node3D) -> void:
	var plastic: Color = Color("d5ddca")
	var role: String = "RECEIVER_CONTAINMENT_FOUL"
	_box(root, "ST079_BACK", Vector3(0, 0.665, -0.02), Vector3(0.55, 0.37, 0.04), plastic, role)
	_box(root, "ST079_SEAT", Vector3(0, 0.42, 0.19), Vector3(0.51, 0.04, 0.38), plastic, role)
	for side in [-1, 1]:
		_box(root, "ST079_ARM%d" % side, Vector3(side * 0.27, 0.6125, 0.14),
			Vector3(0.04, 0.035, 0.32), plastic, role)
		_box(root, "ST079_ARM_SUPPORT%d" % side, Vector3(side * 0.27, 0.52, 0.27),
			Vector3(0.035, 0.18, 0.035), plastic, role)
		_box(root, "ST079_FRONT_LEG%d" % side, Vector3(side * 0.22, 0.20, 0.33),
			Vector3(0.055, 0.40, 0.055), plastic, role)
		_box(root, "ST079_REAR_LEG%d" % side, Vector3(side * 0.23, 0.215, -0.12),
			Vector3(0.055, 0.43, 0.055), plastic, role)
	for rib in range(5):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.024, 0.28, 0.01)
		_mesh(root, "MoldedRib%d" % rib, Vector3(-0.20 + rib * 0.10, 0.68, 0.005),
			mesh, Color("b8c6af"))


static func _box(root: Node3D, id: String, center: Vector3, size: Vector3,
	color: Color, role: String) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	_part(root, id, center, mesh, shape, color, role)


static func _segment(root: Node3D, id: String, from: Vector3, to: Vector3,
	width: float, color: Color) -> void:
	_box(root, id, (from + to) / 2, Vector3(width, from.distance_to(to), width),
		color, "LIVE_RICOCHET")
	var rotation: Quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	root.get_node("Visual/" + id).quaternion = rotation
	root.get_node("Collision/" + id).quaternion = rotation


static func _part(root: Node3D, id: String, center: Vector3, mesh: Mesh,
	shape: Shape3D, color: Color, role: String) -> void:
	_mesh(root, id, center, mesh, color)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface_id", id)
	body.set_meta("surface_role", role)
	body.set_meta("stadium_item", root.get_meta("stadium_item"))
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	root.get_node("Collision").add_child(body)


static func _mesh(root: Node3D, id: String, center: Vector3, mesh: Mesh, color: Color) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = id
	instance.mesh = mesh
	instance.position = center
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	instance.material_override = material
	root.get_node("Visual").add_child(instance)


static func surfaces(id: String) -> Array[String]:
	var result: Array[String] = []
	if id == "ST-001":
		return ["CONE_BASE", "CONE_BODY"]
	if id == "ST-003":
		result.assign(["LAWN_SEAT", "LAWN_BACK"])
		for side in [-1, 1]:
			result.append("LAWN_SIDE%d" % side)
			result.append("LAWN_BACK_RAIL%d" % side)
			for slope in [-1, 1]:
				result.append("LAWN_SUPPORT%d_%d" % [side, slope])
	elif id == "ST-079":
		result.assign(["ST079_BACK", "ST079_SEAT"])
		for side in [-1, 1]:
			for part: String in ["ARM", "ARM_SUPPORT", "FRONT_LEG", "REAR_LEG"]:
				result.append("ST079_%s%d" % [part, side])
	return result
