class_name StadiumLandscapeModels
extends RefCounted
## BN1/2/4 and BR: four complete, static, off-field scenery purchases.
## No live surface, water result, treehouse mount or independently owned component.
## Reservations include the entire crown/root assembly, not merely the trunk.

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-013", "ST-014", "ST-018", "ST-019"]
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"


static func create(item: String) -> Node3D:
	if item not in ITEMS:
		return null
	var root: Node3D = Node3D.new()
	root.name = item.replace("-", "") + "Landscape"
	root.set_meta("stadium_item", item)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("authoring_source", "BN-BR-static-landscape-v1")
	root.set_meta("surface_role", ROLE)
	root.set_meta("physics_profile", ROLE)
	root.set_meta("scenery_only", true)
	root.set_meta("static_geometry", true)
	root.set_meta("treehouse_support", false)
	root.set_meta("water_scoring", false)
	root.set_meta("envelope", bounds(item))
	for branch: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = branch
		root.add_child(child)
	match item:
		"ST-013":
			_tree(root)
		"ST-014":
			_hedge(root)
		"ST-018":
			_pond(root)
		"ST-019":
			_rock_garden(root)
	return root


static func bounds(item: String) -> AABB:
	match item:
		"ST-013":
			return AABB(Vector3(-3.5, 0, -3.5), Vector3(7, 7, 7))
		"ST-014":
			return AABB(Vector3(-1, 0, -0.5), Vector3(2, 1.8, 1))
		"ST-018":
			return AABB(Vector3(-2.75, 0, -2.75), Vector3(5.5, 1, 5.5))
		"ST-019":
			return AABB(Vector3(-2.5, 0, -2.25), Vector3(5, 1.8, 4.5))
	return AABB()


static func envelope(item: String) -> AABB:
	return bounds(item)


static func _tree(root: Node3D) -> void:
	_stem(root, "TreeTrunk", Vector3.ZERO, Vector3(0, 3.9, 0), 0.48, 0.24, Color("75543b"))
	for index in range(6):
		var angle: float = TAU * index / 6.0 + 0.18
		var radial: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var side: Vector3 = Vector3(-sin(angle), 0, cos(angle))
		var points: PackedVector3Array = [
			radial * 0.22 - side * 0.20,
			radial * 0.22 + side * 0.20,
			radial * 1.32 + side * 0.09,
			radial * 1.32 - side * 0.09,
			radial * 0.32 + Vector3(0, 0.68, 0),
			radial * 1.12 + Vector3(0, 0.12, 0)
		]
		_poly(
			root,
			"TreeRoot%d" % index,
			points,
			[[0, 3, 2, 1], [0, 1, 4], [0, 4, 5, 3], [1, 2, 5, 4], [2, 3, 5]],
			Color("6a5038")
		)
		var fork: Vector3 = radial * 1.12 + Vector3(0, 3.30 + 0.14 * (index % 2), 0)
		_stem(
			root,
			"TreeBranch%d" % index,
			Vector3(0, 1.9 + 0.21 * index, 0),
			fork,
			0.18,
			0.105,
			Color("805d40")
		)
		for hand in [-1, 1]:
			_stem(
				root,
				"TreeFork%d_%d" % [index, hand],
				fork,
				radial * 2.12 + side * hand * 0.47 + Vector3(0, 4.38 + 0.14 * (index % 3), 0),
				0.10,
				0.035,
				Color("79583c")
			)
		_stem(
			root,
			"BarkRidge%d" % index,
			radial * 0.424 + Vector3(0, 0.20, 0),
			radial * 0.282 + Vector3(0, 2.95, 0),
			0.028,
			0.018,
			Color("604731")
		)
	_sphere(root, "CrownCore", Vector3(0, 4.92, 0), Vector3(2.68, 1.52, 2.68), Color("476d39"))
	_sphere(
		root, "CrownTop", Vector3(0.10, 5.42, -0.08), Vector3(1.82, 1.53, 1.82), Color("648448")
	)
	for index in range(8):
		var angle: float = TAU * index / 8.0
		var radial: Vector3 = Vector3(cos(angle), 0, sin(angle))
		_sphere(
			root,
			"CrownLobe%d" % index,
			radial * 1.70 + Vector3(0, 4.64 + 0.13 * (index % 3), 0),
			Vector3(1.65, 1.28, 1.65),
			Color("527a3e") if index % 2 == 0 else Color("3f6536")
		)
		_sphere(
			root,
			"CrownHighlight%d" % index,
			radial * 1.92 + Vector3(0, 5.44 + 0.10 * (index % 2), 0),
			Vector3(0.98, 0.72, 0.98),
			Color("6d8b4b") if index % 2 == 0 else Color("5d8042")
		)


static func _hedge(root: Node3D) -> void:
	StadiumGroundPropsModels._art_box(
		root, "HedgeSoil", Vector3(0, 0.03, 0), Vector3(1.90, 0.06, 0.50), Color("64553c")
	)
	# Bevelled foliage has its own closed end faces. Included caps finish any subset.
	var points: PackedVector3Array = []
	for level: Vector3 in [
		Vector3(0.94, 0.10, 0.24),
		Vector3(0.98, 0.32, 0.30),
		Vector3(0.98, 1.35, 0.30),
		Vector3(0.94, 1.48, 0.22)
	]:
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			points.append(Vector3(corner.x * level.x, level.y, corner.y * level.z))
	var faces: Array = [[0, 3, 2, 1], [12, 13, 14, 15]]
	for ring in range(3):
		for side in range(4):
			var next: int = (side + 1) % 4
			faces.append(
				[ring * 4 + side, ring * 4 + next, (ring + 1) * 4 + next, (ring + 1) * 4 + side]
			)
	_poly(root, "HedgeCore", points, faces, Color("416735"))
	for side in [-1, 1]:
		StadiumGroundPropsModels._art_box(
			root,
			"HedgeFinishedEnd%d" % side,
			Vector3(side * 0.98, 0.80, 0),
			Vector3(0.04, 1.30, 0.54),
			Color("54783e")
		)
	for index in range(4):
		_stem(
			root,
			"HedgeStem%d" % index,
			Vector3(-0.72 + index * 0.48, 0.04, 0),
			Vector3(-0.68 + index * 0.45, 0.56, 0),
			0.035,
			0.018,
			Color("725738")
		)
	for index in range(6):
		var x: float = -0.72 + index * 0.288
		for side in [-1, 1]:
			_sphere(
				root,
				"HedgeLeaf%d_%d" % [index, side],
				Vector3(x, 0.68 + 0.32 * (index % 2), side * 0.26),
				Vector3(0.21, 0.23, 0.035),
				Color("5d8043") if index % 2 == 0 else Color("4c733a")
			)
		_sphere(
			root,
			"HedgeTop%d" % index,
			Vector3(x, 1.40, 0),
			Vector3(0.24, 0.10, 0.20),
			Color("648348")
		)


static func _pond(root: Node3D) -> void:
	StadiumGroundPropsModels._cylinder(
		root, "PondBasin", Vector3(0, 0.04, 0), 2.5, 0.08, Color("7d8270"), false
	)
	StadiumGroundPropsModels._cylinder(
		root, "PondWater", Vector3(0, 0.105, 0), 2.12, 0.02, Color("4c9392"), false
	)
	var water: StandardMaterial3D = (
		root.get_node("Visual/PondWater").material_override as StandardMaterial3D
	)
	water.roughness = 0.22
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 2.13
	rim.outer_radius = 2.43
	rim.rings = 48
	rim.ring_segments = 8
	StadiumStarterModels._mesh(root, "PondStoneBacking", Vector3(0, 0.16, 0), rim, Color("72796c"))
	for index in range(24):
		var angle: float = TAU * index / 24.0
		var center: Vector3 = Vector3(cos(angle) * 2.20, 0.06, sin(angle) * 2.20)
		_boulder(
			root,
			"PondEdgeStone%d" % index,
			center,
			Vector3(0.28, 0.32 + 0.025 * (index % 3), 0.32),
			-angle,
			(
				Color("a3a38d")
				if index % 3 == 0
				else (Color("8b9282") if index % 3 == 1 else Color("b0aa90"))
			)
		)
	_fish(root, 0, Vector3(-0.78, 0.139, -0.30), -0.35, Color("ede4cb"), Color("d66a35"))
	_fish(root, 1, Vector3(0.48, 0.139, 0.42), 0.80, Color("d87a35"), Color("f0dbb5"))
	_fish(root, 2, Vector3(0.73, 0.139, -0.80), 2.10, Color("ece4cf"), Color("b84732"))
	for index in range(3):
		var ripple: TorusMesh = TorusMesh.new()
		ripple.inner_radius = 0.31 + index * 0.045
		ripple.outer_radius = ripple.inner_radius + 0.008
		ripple.rings = 28
		ripple.ring_segments = 4
		StadiumStarterModels._mesh(
			root,
			"PondRipple%d" % index,
			Vector3(-0.55 + index * 0.61, 0.119, 0.88 - index * 0.70),
			ripple,
			Color("75b1aa")
		)
		var pad: Vector3 = Vector3(-1.45 + index * 0.27, 0.121, 0.64 + 0.24 * (index % 2))
		StadiumGroundPropsModels._cylinder(
			root, "LilyPad%d" % index, pad, 0.22, 0.01, Color("486f42"), false
		)
		_sphere(
			root,
			"LilyBloom%d" % index,
			pad + Vector3(0.035, 0.026, -0.035),
			Vector3(0.065, 0.025, 0.065),
			Color("e9d8b7")
		)


static func _fish(
	root: Node3D, index: int, center: Vector3, yaw: float, body: Color, patch: Color
) -> void:
	var prefix: String = "Koi%d" % index
	_sphere(root, prefix + "Body", Vector3.ZERO, Vector3(0.28, 0.025, 0.09), body)
	_sphere(root, prefix + "Patch", Vector3(-0.045, 0.021, 0), Vector3(0.11, 0.013, 0.072), patch)
	StadiumGroundPropsModels._leaf(
		root, prefix + "Tail", Vector3(-0.23, 0, 0), Vector3(-0.47, 0, 0), 0.12, patch
	)
	for side in [-1, 1]:
		StadiumGroundPropsModels._leaf(
			root,
			prefix + "Fin%d" % side,
			Vector3(0.025, 0, side * 0.055),
			Vector3(-0.065, 0, side * 0.175),
			0.035,
			body
		)
		_sphere(
			root,
			prefix + "Eye%d" % side,
			Vector3(0.205, 0.012, side * 0.047),
			Vector3(0.012, 0.010, 0.012),
			Color("303d35")
		)
	var turn: Basis = Basis(Vector3.UP, yaw)
	for mesh: MeshInstance3D in root.get_node("Visual").get_children():
		if str(mesh.name).begins_with(prefix):
			mesh.position = center + turn * mesh.position
			mesh.basis = turn * mesh.basis


static func _rock_garden(root: Node3D) -> void:
	var outline: Array[Vector2] = [
		Vector2(-2.25, -1.25),
		Vector2(-1.80, -1.75),
		Vector2(1.68, -1.75),
		Vector2(2.25, -1.12),
		Vector2(2.25, 1.18),
		Vector2(1.72, 1.75),
		Vector2(-1.72, 1.75),
		Vector2(-2.25, 1.10)
	]
	var points: PackedVector3Array = []
	for y: float in [0.0, 0.08]:
		for point: Vector2 in outline:
			points.append(Vector3(point.x, y, point.y))
	var faces: Array = [[7, 6, 5, 4, 3, 2, 1, 0], [8, 9, 10, 11, 12, 13, 14, 15]]
	for index in range(8):
		var next: int = (index + 1) % 8
		faces.append([index, next, next + 8, index + 8])
	_poly(root, "RockGravelBed", points, faces, Color("b7ad8c"))
	var centers: Array[Vector3] = [
		Vector3(-0.63, 0.08, 0.02),
		Vector3(0.63, 0.08, -0.40),
		Vector3(1.30, 0.08, 0.53),
		Vector3(-1.40, 0.08, -0.66),
		Vector3(-0.90, 0.08, 0.97),
		Vector3(0.12, 0.08, 1.02)
	]
	var sizes: Array[Vector3] = [
		Vector3(0.79, 1.32, 0.68),
		Vector3(0.68, 0.98, 0.72),
		Vector3(0.52, 0.66, 0.56),
		Vector3(0.47, 0.54, 0.49),
		Vector3(0.43, 0.47, 0.44),
		Vector3(0.40, 0.37, 0.36)
	]
	for index in range(centers.size()):
		_boulder(
			root,
			"GardenBoulder%d" % index,
			centers[index],
			sizes[index],
			index * 0.61,
			(
				Color("8d9182")
				if index % 3 == 0
				else (Color("a0a18d") if index % 3 == 1 else Color("7b8377"))
			)
		)
	for index in range(18):
		var angle: float = TAU * index / 18.0
		_sphere(
			root,
			"GardenPebble%d" % index,
			Vector3(cos(angle) * 1.86, 0.115, sin(angle) * 1.40),
			Vector3(0.12 + 0.018 * (index % 3), 0.035, 0.095),
			Color("d0c6a5") if index % 2 == 0 else Color("989b85")
		)
	for index in range(4):
		var base: Vector3 = Vector3(-1.58 + index * 0.96, 0.085, -1.10 + 0.15 * (index % 2))
		for leaf in range(3):
			StadiumGroundPropsModels._leaf(
				root,
				"GardenGrass%d_%d" % [index, leaf],
				base,
				base + Vector3(-0.12 + leaf * 0.12, 0.24 + 0.055 * (leaf % 2), 0.10),
				0.022,
				Color("687d47")
			)


static func _stem(
	root: Node3D,
	name: String,
	start: Vector3,
	end: Vector3,
	bottom: float,
	top: float,
	color: Color
) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 12
	StadiumStarterModels._mesh(root, name, (start + end) * 0.5, mesh, color)
	root.get_node("Visual/" + name).quaternion = Quaternion(Vector3.UP, (end - start).normalized())


static func _sphere(
	root: Node3D, name: String, center: Vector3, radii: Vector3, color: Color
) -> void:
	StadiumGroundPropsModels._ellipsoid(root, name, center, radii, color, false)


static func _poly(
	root: Node3D, name: String, points: PackedVector3Array, faces: Array, color: Color
) -> void:
	StadiumStarterModels._mesh(
		root, name, Vector3.ZERO, StadiumGroundPropsModels._poly_mesh(points, faces), color
	)


static func _boulder(
	root: Node3D, name: String, center: Vector3, size: Vector3, yaw: float, color: Color
) -> void:
	var points: PackedVector3Array = []
	for layer in range(3):
		var radius: float = 0.70 if layer == 0 else (1.0 if layer == 1 else 0.58)
		var y: float = 0.0 if layer == 0 else (0.38 if layer == 1 else 0.88)
		for corner in range(8):
			var angle: float = TAU * corner / 8.0
			var uneven: float = 0.90 + 0.05 * ((corner + layer) % 3)
			points.append(
				Vector3(
					cos(angle) * size.x * radius * uneven,
					size.y * y,
					sin(angle) * size.z * radius * uneven
				)
			)
	points.append(Vector3(size.x * 0.10, size.y, -size.z * 0.08))
	var faces: Array = [[7, 6, 5, 4, 3, 2, 1, 0]]
	for layer in range(2):
		for corner in range(8):
			var next: int = (corner + 1) % 8
			faces.append(
				[
					layer * 8 + corner,
					layer * 8 + next,
					(layer + 1) * 8 + next,
					(layer + 1) * 8 + corner
				]
			)
	for corner in range(8):
		faces.append([16 + corner, 16 + (corner + 1) % 8, 24])
	_poly(root, name, points, faces, color)
	var instance: MeshInstance3D = root.get_node("Visual/" + name) as MeshInstance3D
	instance.position = center
	instance.rotation.y = yaw
