class_name StadiumTargetModels
extends RefCounted
## BY's exact target-only blockout. Logical strike calls remain at the plate, not this panel.

const VERSION: int = 1
const POSITION: Vector3 = Vector3(0, 0, -1.05)
const ENVELOPE: AABB = AABB(Vector3(-0.6, 0, -0.675), Vector3(1.2, 1.645, 0.705))
const ROLE: String = "RECEIVER_CONTAINMENT_FOUL"


static func create() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ST026"
	root.set_meta("stadium_item", "ST-026")
	for name_value: String in ["Visual", "Collision"]:
		var node: Node3D = Node3D.new()
		node.name = name_value
		root.add_child(node)
	StadiumStarterModels._box(root, "ST026_PANEL", Vector3(0, 1.05, -0.0125),
		Vector3(0.86, 1.0, 0.025), Color("bbc9c0"), ROLE)
	for side in [-1, 1]:
		_tube(root, "ST026_FRAME_SIDE%d" % side, Vector3(side * 0.5, 1.05, 0),
			Vector3.UP, 1.14, 0.025)
		_tube(root, "ST026_FRAME_BAR%d" % side, Vector3(0, 1.05 + side * 0.57, 0),
			Vector3.RIGHT, 1.0, 0.025)
		_tube(root, "ST026_LEGS%d" % side, Vector3(side * 0.5, 0.255, -0.02),
			Vector3.UP, 0.45, 0.025)
		_tube(root, "ST026_BASE_SKID%d" % side, Vector3(side * 0.5, 0.03, -0.31),
			Vector3.BACK, 0.68, 0.025, true)
	_tube(root, "ST026_BASE_CROSS", Vector3(0, 0.03, -0.65),
		Vector3.RIGHT, 1.2, 0.025, true)
	# Suspended panel ties are visible authored parts, not extra containment surfaces.
	for side in [-1, 1]:
		for level in [-1, 1]:
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(0.07, 0.015, 0.015)
			StadiumStarterModels._mesh(root, "PanelTie%d_%d" % [side, level],
				Vector3(side * 0.465, 1.05 + level * 0.42, -0.01), mesh, Color("645b47"))
	for body: StaticBody3D in root.get_node("Collision").get_children():
		body.collision_mask = 2
		body.set_meta("ball_surface", &"stadium_receiver")
	return root


static func _tube(root: Node3D, id: String, center: Vector3, direction: Vector3,
	length: float, radius: float, rounded: bool = false) -> void:
	var mesh: PrimitiveMesh
	var shape: Shape3D
	if rounded:
		mesh = CapsuleMesh.new()
		mesh.set("radius", radius)
		mesh.set("height", length)
		shape = CapsuleShape3D.new()
		shape.set("radius", radius)
		shape.set("height", length)
	else:
		mesh = CylinderMesh.new()
		mesh.set("top_radius", radius)
		mesh.set("bottom_radius", radius)
		mesh.set("height", length)
		shape = CylinderShape3D.new()
		shape.set("radius", radius)
		shape.set("height", length)
	mesh.set("radial_segments", 12)
	StadiumStarterModels._part(root, id, center, mesh, shape, Color("d7d5bd"), ROLE)
	var rotation: Quaternion = Quaternion(Vector3.UP, direction.normalized())
	root.get_node("Visual/" + id).quaternion = rotation
	root.get_node("Collision/" + id).quaternion = rotation


static func pitch_view(root: Node3D, batting: bool) -> void:
	root.get_node("Visual").visible = not batting
	for mesh: MeshInstance3D in root.get_node("Visual").get_children():
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if batting \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func flex(root: Node3D, elapsed: float) -> void:
	var progress: float = clampf(elapsed / 0.18, 0, 1)
	root.get_node("Visual/ST026_PANEL").position.z = -0.0125 - sin(progress * PI) * 0.03


static func surfaces() -> Array[String]:
	var result: Array[String] = ["ST026_PANEL", "ST026_BASE_CROSS"]
	for side in [-1, 1]:
		for prefix: String in ["ST026_FRAME_SIDE", "ST026_FRAME_BAR", "ST026_LEGS", "ST026_BASE_SKID"]:
			result.append(prefix + str(side))
	return result
