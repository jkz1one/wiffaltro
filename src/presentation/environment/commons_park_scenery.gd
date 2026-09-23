class_name CommonsParkScenery
extends RefCounted


# Decorative meshes only. The shared field geometry owns every collision and rule.
static func build(geometry: StarterFieldLabGeometry, field: FieldDefinition) -> void:
	var root: Node3D = Node3D.new()
	root.name = "CommonsParkScenery"
	geometry.add_child(root)
	_recolor(geometry.get_node("Ground"), Color("24483b"))
	_shape_wall(geometry.get_node("BackWall"), field)
	_tree(root, Vector3(24.0, 0.0, 21.0))
	for strip in range(6):
		_box(root, "TurfStripe%d" % strip, Vector3(0, 0.003, 2.0 + strip * 4.0),
			Vector3(44, 0.004, 2), Color("284d3f"))
	for side in [-1, 1]:
		# Keep structures beyond the playing surface and both pitch-camera sightlines.
		for row in range(3):
			_box(root, "Bleacher%d_%d" % [side, row], Vector3(side * (24.0 + row),
				0.45 + row * 0.5, 10), Vector3(0.8, 0.16, 9), Color("8b9c9d"))
			for z in [6.0, 10.0, 14.0]:
				_box(root, "Support", Vector3(side * (24.0 + row), (0.45 + row * 0.5) / 2, z),
					Vector3(0.16, 0.45 + row * 0.5, 0.16), Color("455b60"))
		_box(root, "WallAccent", Vector3(side * 14.5, 1.3, field.back_wall_z_m - 0.012),
			Vector3(7.5, 1.8, 0.016), Color("95684b"))
		_box(root, "DugoutRoof", Vector3(side * 25, 2.4, 0.5),
			Vector3(4, 0.16, 5.5), Color("375d64"))
		for z in [-1.7, 2.7]:
			_box(root, "DugoutPost", Vector3(side * 26.4, 1.2, z),
				Vector3(0.15, 2.4, 0.15), Color("687b79"))
	_box(root, "Clubhouse", Vector3(-24, 2.0, 35), Vector3(11, 4, 7), Color("c0b9a1"))
	_box(root, "ClubhouseRoof", Vector3(-24, 4.15, 35), Vector3(12, 0.3, 8), Color("45626a"))
	for x in [-27.0, -24.0, -21.0]:
		_box(root, "ClubhouseWindow", Vector3(x, 2.2, 31.48),
			Vector3(1.5, 1.1, 0.03), Color("344d5b"))
	var sign: Label3D = Label3D.new()
	sign.name = "ParkName"
	sign.text = "COMMONS PARK"
	sign.position = Vector3(14.5, 1.45, field.back_wall_z_m - 0.035)
	sign.rotation.y = PI
	sign.font_size = 64
	sign.pixel_size = 0.008
	sign.modulate = Color("f0e2bd")
	sign.outline_size = 0
	root.add_child(sign)


static func _recolor(body: Node, color: Color) -> void:
	for child in body.get_children():
		if child is MeshInstance3D:
			var material: StandardMaterial3D = child.material_override.duplicate()
			material.albedo_color = color
			child.material_override = material


static func _box(
	parent: Node3D, node_name: String, at: Vector3, dimensions: Vector3, color: Color
) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = at
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	instance.material_override = material
	parent.add_child(instance)


static func _shape_wall(wall: StaticBody3D, field: FieldDefinition) -> void:
	# Front elevation is an isosceles trapezoid. Keep the scoring plane and
	# level HR height; only the far ends taper, outside the central wall face.
	var points: PackedVector3Array = PackedVector3Array()
	var half_height: float = field.home_run_height_m * 0.5
	for z in [-0.25, 0.25]:
		points.append(Vector3(-19.0, -half_height, z))
		points.append(Vector3(19.0, -half_height, z))
		points.append(Vector3(17.8, half_height, z))
		points.append(Vector3(-17.8, half_height, z))
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = points
	var collision: CollisionShape3D = wall.get_child(0)
	collision.shape = shape
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0, 1, 2, 3], [7, 6, 5, 4], [4, 5, 1, 0],
		[3, 2, 6, 7], [4, 0, 3, 7], [1, 5, 6, 2]]:
		for index in [0, 1, 2, 0, 2, 3]:
			surface.add_vertex(points[face[index]])
	surface.generate_normals()
	var mesh: MeshInstance3D = wall.get_child(1)
	mesh.mesh = surface.commit()
	_recolor(wall, Color("193a49"))


static func _tree(parent: Node3D, at: Vector3) -> void:
	var tree: Node3D = Node3D.new()
	tree.name = "SmallTree"
	tree.position = at
	parent.add_child(tree)
	_box(tree, "Trunk", Vector3(0, 1.0, 0), Vector3(0.32, 2.0, 0.32), Color("71523a"))
	for offset in [Vector3(0, 2.7, 0), Vector3(-0.7, 2.25, 0.15), Vector3(0.7, 2.4, 0)]:
		var canopy: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 1.05
		mesh.height = 1.9
		mesh.radial_segments = 8
		mesh.rings = 4
		canopy.mesh = mesh
		canopy.position = offset
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color("46754b")
		material.roughness = 1.0
		canopy.material_override = material
		tree.add_child(canopy)
