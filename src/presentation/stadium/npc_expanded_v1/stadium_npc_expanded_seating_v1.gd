class_name StadiumNpcExpandedSeatingV1
extends RefCounted
## Retained AE-01/r1 correspondence copy.
## Original: src/presentation/stadium/stadium_seating_models.gd
## Original seating blockouts. Represented audience is not player-card inventory.

const VERSION: int = 1
const PALETTE: Array[Color] = [Color("58798d"), Color("bd7548"), Color("42685c"),
	Color("b8ab7b"), Color("795b72")]


static func create(id: String, occupied: bool = true) -> Node3D:
	if id not in ["ST-080", "ST-027"]:
		return null
	var root: Node3D = Node3D.new()
	root.name = id.replace("-", "")
	root.set_meta("stadium_item", id)
	root.set_meta("represented_seats", 1 if id == "ST-080" else 10)
	for name_value: String in ["Visual", "Collision"]:
		var node: Node3D = Node3D.new()
		node.name = name_value
		root.add_child(node)
	if id == "ST-080":
		_chair(root, occupied)
	else:
		_bleachers(root, occupied)
	return root


static func _chair(root: Node3D, occupied: bool) -> void:
	var plastic: Color = Color("d8ddcc")
	_box(root, "SpectatorSeat", Vector3(0, 0.42, 0.015), Vector3(0.44, 0.06, 0.43), plastic)
	_box(root, "SpectatorBack", Vector3(0, 0.65, -0.23), Vector3(0.46, 0.40, 0.045), plastic)
	for side in [-1, 1]:
		for end in [-1, 1]:
			_box(root, "SpectatorLeg%d_%d" % [side, end], Vector3(side * 0.20, 0.205, end * 0.20),
				Vector3(0.045, 0.41, 0.045), plastic)
	for rib in range(4):
		_box(root, "BackRib%d" % rib, Vector3(-0.15 + rib * 0.10, 0.65, -0.202),
			Vector3(0.018, 0.29, 0.01), Color("b4c3ac"), false)
	if occupied:
		_person(root, 0, Vector3(0, 0.45, 0.035))


static func _bleachers(root: Node3D, occupied: bool) -> void:
	var timber: Color = Color("866044")
	var seat: Color = Color("bd9568")
	var dark: Color = Color("614936")
	_box(root, "LowerBench", Vector3(0, 0.55, 0.68), Vector3(5.10, 0.10, 0.42), seat)
	_box(root, "UpperBench", Vector3(0, 1.20, -0.55), Vector3(5.10, 0.10, 0.42), seat)
	_box(root, "LowerFootboard", Vector3(0, 0.16, 1.10), Vector3(5.80, 0.10, 0.60), timber)
	_box(root, "UpperFootboard", Vector3(0, 0.80, -0.05), Vector3(5.80, 0.12, 0.80), timber)
	for support in range(3):
		var x: float = [-2.65, 0.0, 2.65][support]
		_box(root, "GroundRunner%d" % support, Vector3(x, 0.08, 0), Vector3(0.14, 0.16, 2.8), dark)
		_box(root, "LowSupport%d" % support, Vector3(x, 0.30, 0.68), Vector3(0.12, 0.60, 0.12), timber)
		_box(root, "HighSupport%d" % support, Vector3(x, 0.60, -0.55),
			Vector3(0.12, 1.20, 0.12), timber)
		_segment(root, "Diagonal%d" % support, Vector3(x, 0.12, 1.2),
			Vector3(x, 1.15, -0.8), 0.10, dark)
	for side in [-1, 1]:
		_box(root, "RearGuardPost%d" % side, Vector3(side * 2.78, 1.02, -1.32),
			Vector3(0.12, 2.04, 0.12), timber)
		_box(root, "FinishedEnd%d" % side, Vector3(side * 2.78, 1.0, -0.05),
			Vector3(0.12, 0.12, 2.55), timber)
	_box(root, "RearGuardRail", Vector3(0, 2.02, -1.32), Vector3(5.68, 0.12, 0.12), timber)
	for step in range(4):
		var height: float = (step + 1) * 0.2
		_box(root, "AccessStep%d" % step, Vector3(2.72, height / 2, 1.05 - step * 0.4),
			Vector3(0.44, height, 0.36), seat)
	if occupied:
		for row in range(2):
			for place in range(5):
				_person(root, row * 5 + place, Vector3(-2.04 + place * 1.02,
					0.60 if row == 0 else 1.25, 0.70 if row == 0 else -0.53))


static func _person(root: Node3D, index: int, seat: Vector3) -> void:
	var anchor: Node3D = Node3D.new()
	anchor.name = "CrowdAnchor%d" % index
	anchor.position = seat
	anchor.set_meta("represented_audience", true)
	root.get_node("Visual").add_child(anchor)
	var body: CapsuleMesh = CapsuleMesh.new()
	body.radius = 0.15
	body.height = 0.42
	body.radial_segments = 8
	body.rings = 2
	_mesh(anchor, "Body", body, Vector3(0, 0.23, 0), PALETTE[index % PALETTE.size()])
	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	head.radial_segments = 8
	head.rings = 4
	_mesh(anchor, "Head", head, Vector3(0, 0.57, 0), Color("cdb48c"))
	for side in [-1, 1]:
		var hand: SphereMesh = SphereMesh.new()
		hand.radius = 0.06
		hand.height = 0.12
		hand.radial_segments = 8
		hand.rings = 4
		_mesh(anchor, "Hand%d" % side, hand, Vector3(side * 0.18, 0.23, 0.10), Color("cdb48c"))


static func _segment(root: Node3D, id: String, from: Vector3, to: Vector3,
	width: float, color: Color) -> void:
	_box(root, id, (from + to) / 2, Vector3(width, from.distance_to(to), width), color)
	var rotation: Quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	root.get_node("Visual/" + id).quaternion = rotation
	root.get_node("Collision/" + id).quaternion = rotation


static func _box(root: Node3D, id: String, center: Vector3, size: Vector3, color: Color,
	solid: bool = true) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_mesh(root.get_node("Visual"), id, mesh, center, color)
	if not solid:
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("stadium_item", root.get_meta("stadium_item"))
	body.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
	body.set_meta("surface_id", id)
	body.set_meta("ball_surface", &"stadium_scenery")
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	collider.shape.size = size
	body.add_child(collider)
	root.get_node("Collision").add_child(body)


static func _mesh(parent: Node3D, id: String, mesh: Mesh, center: Vector3, color: Color) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = id
	instance.mesh = mesh
	instance.position = center
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	instance.material_override = material
	parent.add_child(instance)
