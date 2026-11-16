class_name StadiumTreehouseModels
extends RefCounted
## Working BP treehouse blockout: one complete, grounded, static scenery parent.
## The support tree is bundled artwork, never a grant or consumption of ST-013.
## Door, windows, deck trunk opening and rail entry remain actual empty spaces.

const VERSION: int = 1
const SOLID_COUNT: int = 97
const MESH_COUNT: int = 101
const ITEM: String = "ST-045"
const ITEMS: Array[String] = [ITEM]
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const ENVELOPE: AABB = AABB(Vector3(-3, 0, -3), Vector3(6, 7, 6))
const VISIBLE: AABB = AABB(Vector3(-2.5, 0, -2.5), Vector3(5, 6, 5))
const APPROACH: AABB = AABB(Vector3(-0.60, 0, -2.5), Vector3(1.20, 3.2, 1.15))
const WOOD: Color = Color("ad8152")
const EDGE: Color = Color("765339")
const LIGHT_WOOD: Color = Color("c49a64")
const ROOF: Color = Color("637c70")
const BARK: Color = Color("73533a")
const PRISM_FACES: Array = [
	[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]
]


static func create(item: String = ITEM) -> Node3D:
	if item != ITEM:
		return null
	var root: Node3D = Node3D.new()
	root.name = "ST045Treehouse"
	root.set_meta("stadium_item", ITEM)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("authoring_source", "BP11411229-11243-treehouse-blockout-v1")
	root.set_meta("final_art_accepted", false)
	root.set_meta("envelope", ENVELOPE)
	root.set_meta("visible_bounds", VISIBLE)
	root.set_meta("local_approach_bounds", APPROACH)
	root.set_meta("static_geometry", true)
	root.set_meta("scenery_only", true)
	root.set_meta("surface_role", ROLE)
	root.set_meta("physics_profile", ROLE)
	root.set_meta("bundled_support_tree", true)
	root.set_meta("local_approach_only", true)
	root.set_meta("connected_pedestrian_route", false)
	root.set_meta("climbing_enabled", false)
	root.set_meta("obstacle_units", 0)
	root.set_meta("ambient_ball_count", 0)
	for id: String in ["Visual", "Collision"]:
		var branch: Node3D = Node3D.new()
		branch.name = id
		root.add_child(branch)
	_tree(root)
	_platform(root)
	_cabin(root)
	_guardrails(root)
	_ladder(root)
	return root


static func envelope(item: String = ITEM) -> AABB:
	return ENVELOPE if item == ITEM else AABB()


static func visible_bounds(item: String = ITEM) -> AABB:
	return VISIBLE if item == ITEM else AABB()


static func bounds(item: String = ITEM) -> AABB:
	return envelope(item)


static func local_approach_bounds(item: String = ITEM) -> AABB:
	return APPROACH if item == ITEM else AABB()


static func support_points() -> PackedVector3Array:
	return PackedVector3Array(
		[
			Vector3(0, 0, 1.4),
			Vector3(-1.65, 0, -1.4),
			Vector3(1.65, 0, -1.4),
			Vector3(-1.65, 0, 1.7),
			Vector3(1.65, 0, 1.7),
			Vector3(-0.47, 0, -2.42),
			Vector3(0.47, 0, -2.42)
		]
	)


static func _tree(root: Node3D) -> void:
	_stem(root, "BundledTrunk", Vector3(0, 0, 1.4), Vector3(0, 4.85, 1.4), 0.32, 0.18, BARK)
	for index in range(4):
		var angle: float = TAU * index / 4.0
		var radial: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var across: Vector3 = Vector3(-sin(angle), 0, cos(angle))
		var base: Vector3 = Vector3(0, 0, 1.4)
		var points: PackedVector3Array = [
			base + radial * 0.18 - across * 0.14,
			base + radial * 0.18 + across * 0.14,
			base + radial * 0.78 + across * 0.07,
			base + radial * 0.78 - across * 0.07,
			base + radial * 0.18 - across * 0.14 + Vector3(0, 0.42, 0),
			base + radial * 0.18 + across * 0.14 + Vector3(0, 0.42, 0)
		]
		_solid(
			root,
			"BundledRoot%d" % index,
			points,
			[[0, 3, 2, 1], [0, 1, 5, 4], [0, 4, 3], [1, 2, 5], [4, 5, 2, 3]],
			BARK
		)
	for side: int in [-1, 1]:
		_stem(
			root,
			"BundledBranch%d" % side,
			Vector3(0, 3.65, 1.4),
			Vector3(side * 1.45, 4.75, 0.8),
			0.15,
			0.06,
			BARK
		)
	_stem(
		root,
		"BundledForwardBranch",
		Vector3(0, 4.55, 1.4),
		Vector3(0, 5.30, -0.9),
		0.14,
		0.045,
		BARK
	)
	_crown(root, "CrownCore", Vector3(0, 5.05, 0.8), Vector3(1.65, 0.95, 1.7), Color("476d39"))
	_crown(root, "CrownLeft", Vector3(-1.45, 4.85, 0.8), Vector3(1.05, 0.75, 1.3), Color("5d8042"))
	_crown(root, "CrownRight", Vector3(1.45, 4.85, 0.8), Vector3(1.05, 0.75, 1.3), Color("527a3e"))
	_crown(root, "CrownFront", Vector3(0, 5.35, -0.9), Vector3(1.4, 0.65, 1.6), Color("648448"))


static func _platform(root: Node3D) -> void:
	for side: int in [-1, 1]:
		for end: int in [-1, 1]:
			var z: float = -1.4 if end == -1 else 1.7
			_box(
				root,
				"SupportPost%d_%d" % [side, end],
				Vector3(side * 1.65, 1.0, z),
				Vector3(0.20, 2.0, 0.20),
				EDGE
			)
			_beam(
				root,
				"KneeBrace%d_%d" % [side, end],
				Vector3(side * 1.65, 1.35, z),
				Vector3(side * 1.0, 1.96, z),
				0.12,
				EDGE
			)
		_box(
			root,
			"SupportBeam%d" % side,
			Vector3(0, 1.94, -1.4 if side == -1 else 1.7),
			Vector3(3.8, 0.16, 0.22),
			EDGE
		)
	# Four real slabs surround the trunk opening instead of filling it invisibly.
	_box(root, "DeckFront", Vector3(0, 2.1, -0.35), Vector3(3.8, 0.2, 2.6), WOOD)
	for side: int in [-1, 1]:
		_box(
			root,
			"DeckRearWing%d" % side,
			Vector3(side * 1.175, 2.1, 1.45),
			Vector3(1.45, 0.2, 1.0),
			WOOD
		)
	_box(root, "DeckRearLip", Vector3(0, 2.1, 1.90), Vector3(0.9, 0.2, 0.1), WOOD)
	for side: int in [-1, 1]:
		_box(
			root,
			"DeckSideFascia%d" % side,
			Vector3(side * 1.85, 2.08, 0.15),
			Vector3(0.1, 0.24, 3.6),
			LIGHT_WOOD
		)
	for end: int in [-1, 1]:
		_box(
			root,
			"DeckEndFascia%d" % end,
			Vector3(0, 2.08, -1.60 if end == -1 else 1.90),
			Vector3(3.8, 0.24, 0.1),
			LIGHT_WOOD
		)


static func _cabin(root: Node3D) -> void:
	# Open doorway, true side windows, complete back and gable roof; no solid room proxy.
	_box(root, "CabinRearWall", Vector3(0, 3.125, 0.86), Vector3(2.3, 1.85, 0.08), WOOD)
	for side: int in [-1, 1]:
		_box(
			root,
			"CabinDoorWing%d" % side,
			Vector3(side * 0.815, 3.125, -0.71),
			Vector3(0.67, 1.85, 0.08),
			WOOD
		)
		_box(
			root,
			"CabinSideLower%d" % side,
			Vector3(side * 1.11, 2.525, 0.075),
			Vector3(0.08, 0.65, 1.65),
			WOOD
		)
		_box(
			root,
			"CabinSideUpper%d" % side,
			Vector3(side * 1.11, 3.80, 0.075),
			Vector3(0.08, 0.50, 1.65),
			WOOD
		)
		_box(
			root,
			"CabinWindowFront%d" % side,
			Vector3(side * 1.11, 3.20, -0.55),
			Vector3(0.08, 0.70, 0.40),
			WOOD
		)
		_box(
			root,
			"CabinWindowRear%d" % side,
			Vector3(side * 1.11, 3.20, 0.675),
			Vector3(0.08, 0.70, 0.45),
			WOOD
		)
		_box(
			root,
			"WindowSill%d" % side,
			Vector3(side * 1.14, 2.85, 0.05),
			Vector3(0.18, 0.08, 0.88),
			LIGHT_WOOD
		)
		for end: int in [-1, 1]:
			_box(
				root,
				"CabinCorner%d_%d" % [side, end],
				Vector3(side * 1.12, 3.125, -0.72 if end == -1 else 0.87),
				Vector3(0.10, 1.85, 0.10),
				EDGE
			)
		for row in range(5):
			_box(
				root,
				"DoorWingBoard%d_%d" % [side, row],
				Vector3(side * 0.815, 2.45 + row * 0.30, -0.758),
				Vector3(0.67, 0.025, 0.016),
				LIGHT_WOOD
			)
	_box(root, "DoorHeader", Vector3(0, 3.985, -0.71), Vector3(0.96, 0.13, 0.08), EDGE)
	for end: int in [-1, 1]:
		var z: float = -0.75 if end == -1 else 0.82
		var points: PackedVector3Array = [
			Vector3(-1.15, 4.05, z),
			Vector3(1.15, 4.05, z),
			Vector3(0, 4.62, z),
			Vector3(-1.15, 4.05, z + 0.08),
			Vector3(1.15, 4.05, z + 0.08),
			Vector3(0, 4.62, z + 0.08)
		]
		_solid(
			root,
			"CabinGable%d" % end,
			points,
			[[0, 1, 2], [3, 5, 4], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]],
			WOOD
		)
	for side: int in [-1, 1]:
		var points: PackedVector3Array = []
		for z: float in [-0.95, 1.10]:
			points.append_array(
				PackedVector3Array(
					[
						Vector3(0, 4.62, z),
						Vector3(side * 1.35, 3.95, z),
						Vector3(side * 1.35, 4.05, z),
						Vector3(0, 4.72, z)
					]
				)
			)
		_solid(root, "RoofSlope%d" % side, points, PRISM_FACES, ROOF)
	_box(root, "RoofRidge", Vector3(0, 4.70, 0.075), Vector3(0.12, 0.08, 2.12), EDGE)


static func _guardrails(root: Node3D) -> void:
	for side: int in [-1, 1]:
		for index in range(5):
			_box(
				root,
				"SideGuardPost%d_%d" % [side, index],
				Vector3(side * 1.80, 2.68, -1.55 + index * 0.85),
				Vector3(0.10, 1.0, 0.10),
				EDGE
			)
		for level in range(2):
			_box(
				root,
				"SideGuardRail%d_%d" % [side, level],
				Vector3(side * 1.80, 2.65 + level * 0.48, 0.15),
				Vector3(0.10, 0.10, 3.50),
				LIGHT_WOOD
			)
			_box(
				root,
				"FrontGuardRail%d_%d" % [side, level],
				Vector3(side * 1.175, 2.65 + level * 0.48, -1.55),
				Vector3(1.35, 0.10, 0.10),
				LIGHT_WOOD
			)
		_box(
			root,
			"EntryGuardPost%d" % side,
			Vector3(side * 0.55, 2.68, -1.55),
			Vector3(0.10, 1.0, 0.10),
			EDGE
		)
	for index in range(3):
		_box(
			root,
			"RearGuardPost%d" % index,
			Vector3(-0.9 + index * 0.9, 2.68, 1.85),
			Vector3(0.10, 1.0, 0.10),
			EDGE
		)
	for level in range(2):
		_box(
			root,
			"RearGuardRail%d" % level,
			Vector3(0, 2.65 + level * 0.48, 1.85),
			Vector3(3.70, 0.10, 0.10),
			LIGHT_WOOD
		)


static func _ladder(root: Node3D) -> void:
	for side: int in [-1, 1]:
		_box(
			root,
			"LadderFoot%d" % side,
			Vector3(side * 0.47, 0.06, -2.42),
			Vector3(0.18, 0.12, 0.16),
			EDGE
		)
		_beam(
			root,
			"LadderStile%d" % side,
			Vector3(side * 0.47, 0.06, -2.42),
			Vector3(side * 0.47, 3.12, -1.40),
			0.10,
			LIGHT_WOOD
		)
	for index in range(9):
		var y: float = 0.25 + index * 0.24
		var z: float = -2.42 + (y - 0.06) / 3.0
		_box(root, "LadderRung%d" % index, Vector3(0, y, z), Vector3(0.94, 0.10, 0.16), WOOD)


static func _box(root: Node3D, id: String, center: Vector3, size: Vector3, color: Color) -> void:
	var low: Vector3 = center - size * 0.5
	var high: Vector3 = center + size * 0.5
	var points: PackedVector3Array = []
	for y: float in [low.y, high.y]:
		points.append_array(
			PackedVector3Array(
				[
					Vector3(low.x, y, low.z),
					Vector3(high.x, y, low.z),
					Vector3(high.x, y, high.z),
					Vector3(low.x, y, high.z)
				]
			)
		)
	_solid(root, id, points, PRISM_FACES, color)


static func _beam(
	root: Node3D, id: String, start: Vector3, end: Vector3, width: float, color: Color
) -> void:
	var direction: Vector3 = start.direction_to(end)
	var across: Vector3 = direction.cross(Vector3.FORWARD).normalized()
	var depth: Vector3 = across.cross(direction).normalized()
	var points: PackedVector3Array = []
	for center: Vector3 in [start, end]:
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			points.append(center + (across * corner.x + depth * corner.y) * width * 0.5)
	_solid(root, id, points, PRISM_FACES, color)


static func _stem(
	root: Node3D, id: String, start: Vector3, end: Vector3, bottom: float, top: float, color: Color
) -> void:
	var pose: Basis = Basis(Quaternion(Vector3.UP, start.direction_to(end)))
	var points: PackedVector3Array = []
	for level in range(2):
		for index in range(12):
			var angle: float = TAU * index / 12.0
			var radius: float = bottom if level == 0 else top
			points.append(
				(
					(start if level == 0 else end)
					+ pose * Vector3(cos(angle) * radius, 0, sin(angle) * radius)
				)
			)
	var faces: Array = []
	var lower: Array = []
	var upper: Array = []
	for index in range(12):
		lower.append(index)
		upper.append(index + 12)
		var next: int = (index + 1) % 12
		faces.append([index, next, next + 12, index + 12])
	faces.append(lower)
	faces.append(upper)
	_solid(root, id, points, faces, color)


static func _crown(root: Node3D, id: String, center: Vector3, radii: Vector3, color: Color) -> void:
	# A small faceted closed lobe, visual only: no broad foliage collision hull.
	var points: PackedVector3Array = [
		center + Vector3(0, radii.y, 0), center - Vector3(0, radii.y, 0)
	]
	for level in range(1, 4):
		var theta: float = PI * level / 4.0
		for index in range(12):
			var phi: float = TAU * index / 12.0
			points.append(
				(
					center
					+ Vector3(
						radii.x * sin(theta) * cos(phi),
						radii.y * cos(theta),
						radii.z * sin(theta) * sin(phi)
					)
				)
			)
	var faces: Array = []
	for index in range(12):
		var next: int = (index + 1) % 12
		faces.append([0, 2 + index, 2 + next])
		faces.append([1, 26 + next, 26 + index])
		for level in range(2):
			faces.append(
				[
					2 + level * 12 + index,
					2 + level * 12 + next,
					14 + level * 12 + next,
					14 + level * 12 + index
				]
			)
	_visual(root, id, points, faces, color)
	root.get_node("Visual/" + id).set_meta("visual_canopy_only", true)


static func _visual(
	root: Node3D, id: String, points: PackedVector3Array, faces: Array, color: Color
) -> void:
	var mesh: ArrayMesh = StadiumGroundPropsModels._poly_mesh(points, faces)
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_INDEX] == null or arrays[Mesh.ARRAY_INDEX].is_empty():
		var indices: PackedInt32Array = []
		for index in range(arrays[Mesh.ARRAY_VERTEX].size()):
			indices.append(index)
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	StadiumStarterModels._mesh(root, id, Vector3.ZERO, mesh, color)


static func _solid(
	root: Node3D, id: String, points: PackedVector3Array, faces: Array, color: Color
) -> void:
	_visual(root, id, points, faces, color)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("stadium_item", ITEM)
	body.set_meta("surface_id", id)
	body.set_meta("surface_role", ROLE)
	body.set_meta("ball_surface", &"stadium_scenery")
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Solid"
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = points.duplicate()
	shape.margin = 0.0
	collider.shape = shape
	body.add_child(collider)
	root.get_node("Collision").add_child(body)
