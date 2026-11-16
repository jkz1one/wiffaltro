class_name StadiumFourHeadTowerModels
extends RefCounted
## Working ST-038 geometry only. No light nodes, photometry, runtime grants or night gate.

const VERSION: int = 1
const PROFILE: String = "MOGUL6-STANDARD"
const GROUND_RADIUS: float = 1.0
const ENVELOPE_RADIUS: float = 1.35
const HEIGHT: float = 15.0
const HEAD_HEIGHT: float = 13.95
const HEAD_X: Array[float] = [-0.9, -0.3, 0.3, 0.9]
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"


static func create(profile: String = PROFILE) -> Node3D:
	if profile != PROFILE:
		return null
	var root: Node3D = Node3D.new()
	root.name = "ST038"
	root.set_meta("stadium_item", "ST-038")
	root.set_meta("geometry_version", VERSION)
	root.set_meta("working_geometry_only", true)
	root.set_meta("aim_profile", PROFILE)
	root.set_meta("obstacle_units", 0)
	root.set_meta("night_qualified", false)
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	_box(root, "Footing", Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.9), true)
	_box(root, "BasePlate", Vector3(0, 0.34, 0), Vector3(0.5, 0.08, 0.5), true)
	var pole: CylinderMesh = CylinderMesh.new()
	pole.top_radius = 0.13
	pole.bottom_radius = 0.13
	pole.height = 13.3
	pole.radial_segments = 16
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.13
	shape.height = 13.3
	StadiumStarterModels._part(root, "Mast", Vector3(0, 7.0, 0), pole, shape,
		Color("697b80"), ROLE)
	_box(root, "Crossbar", Vector3(0, 13.6, 0), Vector3(2.35, 0.16, 0.18))
	for side: int in [-1, 1]:
		_box(root, "LadderRail%d" % side, Vector3(side * 0.19, 6.85, -0.22),
			Vector3(0.035, 12.9, 0.035))
	for height: float in [0.7, 6.8, 12.9]:
		_box(root, "LadderBracket%d" % int(height * 10), Vector3(0, height, -0.11),
			Vector3(0.42, 0.06, 0.25))
	for rung in range(43):
		_box(root, "LadderRung%02d" % rung, Vector3(0, 0.55 + rung * 0.3, -0.22),
			Vector3(0.38, 0.025, 0.035))
	for index in range(4):
		_box(root, "HeadStem%d" % index, Vector3(HEAD_X[index], 13.78, 0),
			Vector3(0.07, 0.36, 0.07))
		var head: Node3D = Node3D.new()
		head.name = "Head%d" % index
		head.position = Vector3(HEAD_X[index], HEAD_HEIGHT, 0)
		root.get_node("Visual").add_child(head)
		_head_mesh(head, "Housing", Vector3.ZERO, Vector3(0.48, 0.42, 0.25),
			Color("31444d"))
		_head_mesh(head, "Lens", Vector3(0, 0, 0.132), Vector3(0.40, 0.34, 0.014),
			Color("f3ecd2"))
	_aim(root, Vector3(0, 1.5, 40))
	return root


static func _aim(root: Node3D, local_target: Vector3) -> void:
	# Only the fixed-site helper selects these authored transforms. Not user articulation.
	var heads: Array[Dictionary] = []
	for index in range(4):
		var head: Node3D = root.get_node("Visual/Head%d" % index)
		var direction: Vector3 = (local_target - head.position).normalized()
		head.quaternion = Quaternion(Vector3.BACK, direction)
		var origin: Vector3 = head.position + direction * 0.139
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
		StadiumStarterModels._part(root, id, point, mesh, shape, Color("697b80"), ROLE)
	else:
		StadiumStarterModels._mesh(root, id, point, mesh, Color("697b80"))


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
