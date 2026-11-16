class_name StadiumNpcMogulTwoTowerV1
extends RefCounted
## Working ST-076 geometry only. No light nodes, photometry, runtime grants or night gate.

const VERSION: int = 1
const PROFILE: String = "MOGUL4-PREMIUM"
const GROUND_RADIUS: float = 1.25
const ENVELOPE_RADIUS: float = 1.75
const HEIGHT: float = 18.5
const HEAD_HEIGHT: float = 17.05
const HEAD_X: Array[float] = [-1.05, -0.35, 0.35, 1.05]
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"


static func create(profile: String = PROFILE) -> Node3D:
	if profile != PROFILE:
		return null
	var root: Node3D = Node3D.new()
	root.name = "ST076"
	root.set_meta("stadium_item", "ST-076")
	root.set_meta("geometry_version", VERSION)
	root.set_meta("working_geometry_only", true)
	root.set_meta("aim_profile", PROFILE)
	root.set_meta("obstacle_units", 0)
	root.set_meta("night_qualified", false)
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	_box(root, "Footing", Vector3(0, 0.18, 0), Vector3(1.1, 0.36, 1.1), true)
	_box(root, "BasePlate", Vector3(0, 0.41, 0), Vector3(0.6, 0.1, 0.6), true)
	var pole: CylinderMesh = CylinderMesh.new()
	pole.top_radius = 0.16
	pole.bottom_radius = 0.16
	pole.height = 17.1
	pole.radial_segments = 16
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.16
	shape.height = 17.1
	StadiumNpcClubPrimitivesV1._part(root, "Mast", Vector3(0, 8.98, 0), pole, shape,
		Color("697b80"), ROLE)
	for row in range(2):
		_box(root, "Crossbar%d" % row, Vector3(0, 16.7 + row * 0.8, 0),
			Vector3(2.8, 0.18, 0.22))
	for side: int in [-1, 1]:
		_box(root, "LadderRail%d" % side, Vector3(side * 0.23, 8.875, -0.27),
			Vector3(0.04, 16.75, 0.04))
	for height: float in [0.9, 8.8, 16.9]:
		_box(root, "LadderBracket%d" % int(height * 10), Vector3(0, height, -0.13),
			Vector3(0.5, 0.07, 0.30))
	for rung in range(56):
		_box(root, "LadderRung%02d" % rung, Vector3(0, 0.65 + rung * 0.3, -0.27),
			Vector3(0.46, 0.03, 0.04))
	for index in range(8):
		var row: int = 1 if index >= 4 else 0
		_box(root, "HeadStem%d" % index, Vector3(HEAD_X[index % 4], 16.88 + row * 0.8, 0),
			Vector3(0.07, 0.36, 0.07))
		var head: Node3D = Node3D.new()
		head.name = "Head%d" % index
		head.position = Vector3(HEAD_X[index % 4], HEAD_HEIGHT + row * 0.8, 0)
		root.get_node("Visual").add_child(head)
		_head_mesh(head, "Housing", Vector3.ZERO, Vector3(0.55, 0.44, 0.28),
			Color("31444d"))
		_head_mesh(head, "Lens", Vector3(0, 0, 0.147), Vector3(0.47, 0.36, 0.014),
			Color("f3ecd2"))
	_aim(root, Vector3(0, 1.5, 40))
	return root


static func _aim(root: Node3D, local_target: Vector3) -> void:
	# Only the fixed-site helper selects these authored transforms. Not user articulation.
	var heads: Array[Dictionary] = []
	for index in range(8):
		var head: Node3D = root.get_node("Visual/Head%d" % index)
		var direction: Vector3 = (local_target - head.position).normalized()
		head.quaternion = Quaternion(Vector3.BACK, direction)
		var origin: Vector3 = head.position + direction * 0.154
		heads.append({"id": "HEAD-%d" % (index + 1),
			"origin": root.transform * origin,
			"direction": (root.basis * direction).normalized()})
	root.set_meta("candidate_head_rays", heads)


static func _box(root: Node3D, id: String, point: Vector3, size: Vector3,
	physical: bool = false) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	if physical:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		StadiumNpcClubPrimitivesV1._part(root, id, point, mesh, shape, Color("697b80"), ROLE)
	else:
		StadiumNpcClubPrimitivesV1._mesh(root, id, point, mesh, Color("697b80"))


static func _head_mesh(root: Node3D, id: String, point: Vector3, size: Vector3,
	color: Color) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = id
	instance.position = point
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	instance.material_override = material
	root.add_child(instance)
