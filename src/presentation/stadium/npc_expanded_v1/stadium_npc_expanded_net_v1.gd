class_name StadiumNpcExpandedNetV1
extends RefCounted
## Retained AE-01/r1 correspondence copy.
## Original: src/presentation/stadium/stadium_net_models.gd
## Corrected BZ blockout v2: the 0.04m-radius frame needs +0.04m front extent, not +0.03m.

const VERSION: int = 1
const BLOCKOUT: String = "RX-CATCH025-BLOCKOUT-v2"
const POSITION: Vector3 = Vector3(0, 0, -2.20)
const ENVELOPE: AABB = AABB(Vector3(-1.9, 0, -0.85), Vector3(3.8, 2.7, 0.89))
const FLEX_DEPTH: float = 0.16


static func create() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ST025"
	root.set_meta("stadium_item", "ST-025")
	for name_value: String in ["Visual", "Collision"]:
		var node: Node3D = Node3D.new()
		node.name = name_value
		root.add_child(node)
	var plane: BoxShape3D = BoxShape3D.new()
	plane.size = Vector3(3.44, 2.39, 0.006)
	var catch_surface: StaticBody3D = StaticBody3D.new()
	catch_surface.name = "ST025_NET"
	catch_surface.position = Vector3(0, 1.375, -0.003)
	catch_surface.collision_layer = 1
	catch_surface.collision_mask = 2
	catch_surface.set_meta("stadium_item", "ST-025")
	catch_surface.set_meta("surface_id", "ST025_NET")
	catch_surface.set_meta("surface_role", "RECEIVER_CONTAINMENT_FOUL")
	catch_surface.set_meta("ball_surface", &"stadium_receiver")
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = plane
	catch_surface.add_child(collider)
	root.get_node("Collision").add_child(catch_surface)
	_net(root)
	for side in [-1, 1]:
		_tube(root, "ST025_FRAME_SIDE%d" % side, Vector3(side * 1.8, 1.37, 0),
			Vector3.UP, 2.58, true)
		_tube(root, "ST025_FRAME_BAR%d" % side, Vector3(0, 1.37 + side * 1.25, 0),
			Vector3.RIGHT, 3.68, true)
		_tube(root, "ST025_BASE_SKID%d" % side, Vector3(side * 1.8, 0.04, -0.385),
			Vector3.BACK, 0.83, true)
		var from: Vector3 = Vector3(side * 1.8, 2.62, 0)
		var to: Vector3 = Vector3(side * 1.8, 0.04, -0.8)
		_tube(root, "ST025_SUPPORTS%d" % side, (from + to) / 2, to - from,
			from.distance_to(to) + 0.08, true)
	_tube(root, "ST025_BASE_CROSS", Vector3(0, 0.04, -0.8), Vector3.RIGHT, 3.8)
	for body: StaticBody3D in root.get_node("Collision").get_children():
		body.collision_mask = 2
		body.set_meta("ball_surface", &"stadium_receiver")
	return root


static func _tube(root: Node3D, id: String, center: Vector3, direction: Vector3,
	length: float, rounded: bool = false) -> void:
	StadiumNpcExpandedTargetV1._tube(root, id, center, direction, length, 0.04, rounded)
	var visual: MeshInstance3D = root.get_node("Visual/" + id)
	visual.material_override.albedo_color = Color("536d76")
	if id.begins_with("ST025_SUPPORTS"):
		# Bake this diagonal mesh's real vertices so its render AABB does not include the
		# empty corners of a rotated capsule box. The actual collision capsule stays rotated.
		var arrays: Array = visual.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in range(vertices.size()):
			vertices[index] = visual.basis * vertices[index]
			normals[index] = visual.basis * normals[index]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		var baked: ArrayMesh = ArrayMesh.new()
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		visual.mesh = baked
		visual.quaternion = Quaternion.IDENTITY


static func _net(root: Node3D) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in range(29):
		var x: float = -1.716 + column * 3.432 / 28
		for row in range(20):
			var y: float = 0.184 + row * 2.382 / 20
			_quad(surface, Vector2(x - 0.004, y), Vector2(x + 0.004, y + 2.382 / 20))
	for row in range(21):
		var y: float = 0.184 + row * 2.382 / 20
		for column in range(28):
			var x: float = -1.716 + column * 3.432 / 28
			_quad(surface, Vector2(x, y - 0.004), Vector2(x + 3.432 / 28, y + 0.004))
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "ST025_NET_STRANDS"
	mesh.mesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("b4ba9b")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1
	mesh.material_override = material
	root.get_node("Visual").add_child(mesh)
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array = []
	for point: Vector3 in vertices:
		weights.append(maxf(0, sin(PI * (point.x + 1.72) / 3.44)
			* sin(PI * (point.y - 0.18) / 2.39)))
	root.set_meta("net_rest_vertices", vertices)
	root.set_meta("net_pocket_weights", weights)


static func _quad(surface: SurfaceTool, low: Vector2, high: Vector2) -> void:
	var points: Array[Vector2] = [low, Vector2(high.x, low.y), high,
		low, high, Vector2(low.x, high.y)]
	for point: Vector2 in points:
		surface.set_normal(Vector3.BACK)
		surface.add_vertex(Vector3(point.x, point.y, 0))


static func pocket(root: Node3D, elapsed: float) -> void:
	var amount: float = sin(clampf(elapsed / 0.24, 0, 1) * PI) * FLEX_DEPTH
	var mesh: MeshInstance3D = root.get_node("Visual/ST025_NET_STRANDS")
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = root.get_meta("net_rest_vertices").duplicate()
	var weights: PackedFloat32Array = root.get_meta("net_pocket_weights")
	for index in range(vertices.size()):
		vertices[index].z = -amount * weights[index]
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.mesh.clear_surfaces()
	mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


static func surfaces() -> Array[String]:
	var result: Array[String] = ["ST025_NET", "ST025_BASE_CROSS"]
	for side in [-1, 1]:
		for prefix: String in ["ST025_FRAME_SIDE", "ST025_FRAME_BAR",
			"ST025_SUPPORTS", "ST025_BASE_SKID"]:
			result.append(prefix + str(side))
	return result
