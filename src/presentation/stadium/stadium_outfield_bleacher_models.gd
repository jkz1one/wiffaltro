class_name StadiumOutfieldBleacherModels
extends RefCounted
## ST-054 is one complete four-row elevated outfield bleacher. The grounded
## supports, two-flight rear stair, left access walk, right stepped aisle and
## perimeter guards belong to this parent. No crowd, navigation or gameplay.

const VERSION: int = 1
const ITEM: String = "ST-054"
const ITEMS: Array[String] = [ITEM]
const ENVELOPE: AABB = AABB(Vector3(-8, 0, -4), Vector3(16, 8.6, 8))
const VISIBLE: AABB = AABB(Vector3(-7.8, 0, -3.5), Vector3(15.6, 8.25, 7.3))
const WORLD_CENTER: Vector3 = Vector3(-17, 0, 36)
const ROW_FLOOR: Array[float] = [5.80, 6.25, 6.70, 7.15]
const ROW_Z: Array[float] = [-3.0, -2.0, -1.0, 0.0]
const EYE_X: Array[float] = [-6.0, 0.0, 6.0]
const SUPPORT_X: Array[float] = [-6.15, -2.05, 2.05, 6.15]
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const FRAME: Color = Color("516d71")
const METAL: Color = Color("9aa9a3")
const DECK: Color = Color("b3b7a4")
const BENCH: Color = Color("d1bd8c")
const CONCRETE: Color = Color("8c968d")
const PRISM_FACES: Array = [
	[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]
]
# Source-derived counts: structure 97, seating 28, access 50, guards 152.
const MESH_COUNT: int = 327
const SOLID_COUNT: int = MESH_COUNT


static func create(item: String = ITEM) -> Node3D:
	if item != ITEM:
		return null
	var root: Node3D = Node3D.new()
	root.name = "ST054ElevatedOutfieldBleachers"
	root.set_meta("stadium_item", ITEM)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("envelope", ENVELOPE)
	root.set_meta("visible_bounds", VISIBLE)
	root.set_meta("surface_role", ROLE)
	root.set_meta("physics_profile", ROLE)
	root.set_meta("static_geometry", true)
	root.set_meta("scenery_only", true)
	root.set_meta("bundled_supports", true)
	root.set_meta("bundled_seating", true)
	root.set_meta("local_approach_only", true)
	root.set_meta("connected_pedestrian_route", false)
	root.set_meta("obstacle_units", 0)
	root.set_meta("represented_audience_count", 0)
	root.set_meta("ambient_ball_count", 0)
	root.set_meta("row_count", 4)
	root.set_meta("facing", Vector3.FORWARD)
	root.set_meta("supported_wall_height", 3.25)
	for id: String in ["Visual", "Collision"]:
		var branch: Node3D = Node3D.new()
		branch.name = id
		root.add_child(branch)
	_structure(root)
	_seating(root)
	_access(root)
	_guards(root)
	return root


static func envelope(item: String = ITEM) -> AABB:
	return ENVELOPE if item == ITEM else AABB()


static func visible_bounds(item: String = ITEM) -> AABB:
	return VISIBLE if item == ITEM else AABB()


static func bounds(item: String = ITEM) -> AABB:
	return envelope(item)


static func mesh_count(item: String = ITEM) -> int:
	return MESH_COUNT if item == ITEM else 0


static func solid_count(item: String = ITEM) -> int:
	return SOLID_COUNT if item == ITEM else 0


static func eye_points() -> PackedVector3Array:
	var result: PackedVector3Array = []
	for row in range(4):
		for x: float in EYE_X:
			result.append(Vector3(x, ROW_FLOOR[row] + 1.20, ROW_Z[row]))
	return result


static func support_points(item: String = ITEM) -> PackedVector3Array:
	var result: PackedVector3Array = []
	if item != ITEM:
		return result
	for row in range(4):
		for x: float in SUPPORT_X:
			result.append(Vector3(x, 0, ROW_Z[row] + 0.28))
	for x: float in SUPPORT_X:
		result.append(Vector3(x, 0, 0.80))
	for x: float in [-7.62, -6.58, 6.58, 7.62]:
		for z: float in [-3.22, -0.50, 0.80 if x > 0 else 2.05]:
			result.append(Vector3(x, 0, z))
	for z: float in [1.25, 2.10]:
		result.append(Vector3(-5.78, 0, z))
	# Each complete concrete stair block and turning landing reaches real ground.
	for index in range(15):
		result.append(Vector3(-5.80 + index * 0.40, 0, 3.175))
	for index in range(14):
		result.append(Vector3(-0.20 - index * 0.40, 0, 1.675))
	result.append(Vector3(0.70, 0, 2.425))
	result.append(Vector3(-6.60, 0, 3.175))
	return result


static func _structure(root: Node3D) -> void:
	for row in range(4):
		var y: float = ROW_FLOOR[row]
		var z: float = ROW_Z[row]
		for column in range(4):
			_post(
				root,
				"RowSupport%d_%d" % [row, column],
				Vector3(SUPPORT_X[column], 0, z + 0.28),
				y - 0.38
			)
		_box(
			root,
			"RowBeam%d" % row,
			Vector3(-6.4, y - 0.38, z + 0.13),
			Vector3(12.8, 0.20, 0.30),
			FRAME
		)
		_box(
			root,
			"RowDeck%d" % row,
			Vector3(-6.4, y - 0.18, z - 0.50),
			Vector3(12.8, 0.18, 1.0),
			DECK
		)
		if row < 3:
			_box(
				root,
				"RowRiser%d" % row,
				Vector3(-6.4, y, z + 0.46),
				Vector3(12.8, 0.45, 0.04),
				FRAME
			)
	# Cross-braces meet grounded columns and their full-width load beams.
	for end in range(2):
		var row: int = end * 3
		var z: float = ROW_Z[row] + 0.28
		for bay in range(3):
			for side: int in [-1, 1]:
				var a: float = SUPPORT_X[bay if side == 1 else bay + 1]
				var b: float = SUPPORT_X[bay + 1 if side == 1 else bay]
				_beam(
					root,
					"CrossBrace%d_%d_%d" % [row, bay, side],
					Vector3(a, 0.28, z),
					Vector3(b, ROW_FLOOR[row] - 0.46, z),
					0.12,
					FRAME
				)
	for side: int in [-1, 1]:
		var x: float = side * 6.15
		_beam(
			root,
			"DepthBrace%dA" % side,
			Vector3(x, 0.28, -2.72),
			Vector3(x, 6.69, 0.28),
			0.12,
			FRAME
		)
		_beam(
			root,
			"DepthBrace%dB" % side,
			Vector3(x, 0.28, 0.28),
			Vector3(x, 5.34, -2.72),
			0.12,
			FRAME
		)
	for column in range(4):
		_post(root, "RearWalkSupport%d" % column, Vector3(SUPPORT_X[column], 0, 0.80), 6.77)
	_box(root, "RearWalkBeam", Vector3(-6.4, 6.77, 0.65), Vector3(12.8, 0.20, 0.30), FRAME)
	_box(root, "RearWalkDeck", Vector3(-6.4, 6.97, 0.50), Vector3(12.8, 0.18, 0.50), DECK)
	for side: int in [-1, 1]:
		for column in range(2):
			var x: float = side * (6.58 + column * 1.04)
			for index in range(3):
				var z: float = [-3.22, -0.50, 0.80 if side == 1 else 2.05][index]
				_post(root, "AccessSupport%d_%d_%d" % [side, column, index], Vector3(x, 0, z), 5.42)
			_box(
				root,
				"AccessBeam%d_%d" % [side, column],
				Vector3(x - 0.09, 5.42, -3.50),
				Vector3(0.18, 0.20, 4.50 if side == 1 else 5.80),
				FRAME
			)


static func _seating(root: Node3D) -> void:
	for row in range(4):
		var y: float = ROW_FLOOR[row]
		var z: float = ROW_Z[row]
		_box(
			root,
			"BenchPan%d" % row,
			Vector3(-6.20, y + 0.38, z - 0.12),
			Vector3(12.40, 0.08, 0.44),
			BENCH
		)
		for leg in range(5):
			_box(
				root,
				"BenchLeg%d_%d" % [row, leg],
				Vector3(-6.05 + leg * 3.0, y, z + 0.01),
				Vector3(0.10, 0.38, 0.16),
				FRAME
			)
		_box(
			root,
			"BenchStretcher%d" % row,
			Vector3(-6.05, y + 0.14, z + 0.05),
			Vector3(12.10, 0.10, 0.08),
			FRAME
		)


static func _access(root: Node3D) -> void:
	_box(root, "LeftAccessWalk", Vector3(-7.80, 5.62, -3.50), Vector3(1.40, 0.18, 5.80), DECK)
	_box(root, "RightAisleBase", Vector3(6.40, 5.62, -3.50), Vector3(1.40, 0.18, 4.50), DECK)
	for row in range(3):
		for step in range(3):
			var top: float = ROW_FLOOR[row] + (step + 1) * 0.15
			_box(
				root,
				"AisleStep%d_%d" % [row, step],
				Vector3(6.40, 5.80, ROW_Z[row] + 0.15 + step * 0.20),
				Vector3(1.40, top - 5.80, 0.20),
				CONCRETE
			)
		var z: float = ROW_Z[row] + 0.75
		_box(
			root,
			"AisleLanding%d" % (row + 1),
			Vector3(6.40, 5.80, z),
			Vector3(1.40, ROW_FLOOR[row + 1] - 5.80, 1.25 if row == 2 else 0.40),
			DECK
		)
	# Two roomy parallel flights: 29 exact 0.20 m rises and 0.40 m treads.
	# Their actual concrete masses bear on ground; no floating tread proxy.
	_box(root, "GroundApproach", Vector3(-7.20, 0, 2.55), Vector3(1.20, 0.04, 1.25), CONCRETE)
	for index in range(15):
		_box(
			root,
			"GroundStair%d" % index,
			Vector3(-6.0 + index * 0.40, 0, 2.55),
			Vector3(0.40, (index + 1) * 0.20, 1.25),
			CONCRETE
		)
	_box(root, "StairTurningLanding", Vector3(0, 0, 1.05), Vector3(1.40, 3.0, 2.75), CONCRETE)
	for index in range(14):
		_box(
			root,
			"UpperStair%d" % index,
			Vector3(-0.40 - index * 0.40, 0, 1.05),
			Vector3(0.40, 3.20 + index * 0.20, 1.25),
			CONCRETE
		)
	_box(root, "StairTopLanding", Vector3(-6.40, 5.62, 1.05), Vector3(0.80, 0.18, 1.25), DECK)
	for index in range(2):
		_post(root, "TopLandingSupport%d" % index, Vector3(-5.78, 0, 1.25 + index * 0.85), 5.62)


static func _guards(root: Node3D) -> void:
	# The 1.00 m first-row guard ends at y=6.80. At z=-3.46 its actual
	# top is below all twelve plate/mound rays, including the nearest mound ray.
	_guard(root, "FrontGuard", Vector3(-6.40, 5.80, -3.46), Vector3(7.74, 5.80, -3.46), 1.00, 10)
	_guard(
		root,
		"LeftWalkFrontGuard",
		Vector3(-7.74, 5.80, -3.46),
		Vector3(-6.40, 5.80, -3.46),
		1.10,
		1
	)
	_guard(
		root, "LeftWalkOuterGuard", Vector3(-7.74, 5.80, -3.46), Vector3(-7.74, 5.80, 2.25), 1.10, 5
	)
	_guard(
		root, "TopLandingRearGuard", Vector3(-7.74, 5.80, 2.25), Vector3(-5.60, 5.80, 2.25), 1.10, 2
	)
	_guard(
		root,
		"TopLandingFrontGuard",
		Vector3(-6.40, 5.80, 1.10),
		Vector3(-5.60, 5.80, 1.10),
		1.10,
		1
	)
	_guard(root, "RearGuard", Vector3(-6.35, 7.15, 0.94), Vector3(7.74, 7.15, 0.94), 1.10, 10)
	for row in range(4):
		var start_z: float = ROW_Z[row] - (0.46 if row == 0 else 0.20)
		var end_z: float = ROW_Z[row] + (0.94 if row == 3 else 0.10)
		_guard(
			root,
			"RightLandingGuard%d" % row,
			Vector3(7.74, ROW_FLOOR[row], start_z),
			Vector3(7.74, ROW_FLOOR[row], end_z),
			1.10,
			1
		)
		if row < 3:
			_guard(
				root,
				"RightStepGuard%d" % row,
				Vector3(7.74, ROW_FLOOR[row], ROW_Z[row] + 0.10),
				Vector3(7.74, ROW_FLOOR[row + 1], ROW_Z[row] + 0.80),
				1.10,
				1
			)
		if row > 0:
			_guard(
				root,
				"LeftRowGuard%d" % row,
				Vector3(-6.35, ROW_FLOOR[row], ROW_Z[row] - 0.46),
				Vector3(-6.35, ROW_FLOOR[row], ROW_Z[row] + 0.50),
				1.10,
				1
			)
	for side in range(2):
		var z: float = 2.60 if side == 0 else 3.75
		_guard(
			root,
			"GroundStairGuard%d" % side,
			Vector3(-5.80, 0.20, z),
			Vector3(-0.20, 3.0, z),
			1.10,
			7
		)
		z = 1.10 if side == 0 else 2.25
		_guard(
			root,
			"UpperStairGuard%d" % side,
			Vector3(-0.20, 3.20, z),
			Vector3(-5.40, 5.80, z),
			1.10,
			13
		)
	_guard(root, "TurnOuterGuard", Vector3(1.34, 3.0, 1.10), Vector3(1.34, 3.0, 3.75), 1.10, 2)
	_guard(root, "TurnFrontGuard", Vector3(0, 3.0, 1.10), Vector3(1.34, 3.0, 1.10), 1.10, 1)
	_guard(root, "TurnRearGuard", Vector3(0, 3.0, 3.75), Vector3(1.34, 3.0, 3.75), 1.10, 1)


static func _post(root: Node3D, id: String, base: Vector3, top: float) -> void:
	_box(root, id + "Foot", base + Vector3(-0.17, 0, -0.17), Vector3(0.34, 0.16, 0.34), CONCRETE)
	_box(
		root,
		id + "Column",
		base + Vector3(-0.09, 0.16, -0.09),
		Vector3(0.18, top - 0.16, 0.18),
		FRAME
	)


static func _guard(
	root: Node3D, id: String, start: Vector3, end: Vector3, height: float, bays: int
) -> void:
	for index in range(bays + 1):
		var base: Vector3 = start.lerp(end, float(index) / bays)
		_box(
			root,
			id + "Post%d" % index,
			base + Vector3(-0.03, 0, -0.03),
			Vector3(0.06, height, 0.06),
			METAL
		)
	for level in range(2):
		var h: float = height - 0.05 if level == 1 else height * 0.5
		_beam(
			root,
			id + "Rail%d" % level,
			start + Vector3(0, h, 0),
			end + Vector3(0, h, 0),
			0.08,
			METAL
		)


static func _box(root: Node3D, id: String, low: Vector3, size: Vector3, color: Color) -> void:
	StadiumGroundBoxModels._box(root, id, AABB(low, size), color)
	_bind_piece(root, id)


static func _beam(
	root: Node3D, id: String, start: Vector3, end: Vector3, width: float, color: Color
) -> void:
	# Bake the complete oriented prism into native vertices; node frames stay unit.
	var direction: Vector3 = start.direction_to(end)
	var reference: Vector3 = Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var across: Vector3 = direction.cross(reference).normalized()
	var depth: Vector3 = across.cross(direction).normalized()
	var points: PackedVector3Array = []
	for center: Vector3 in [start, end]:
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			points.append(center + (across * corner.x + depth * corner.y) * width * 0.5)
	StadiumGroundBoxModels._solid(root, id, points, PRISM_FACES, color)
	_bind_piece(root, id)


static func _bind_piece(root: Node3D, id: String) -> void:
	var visual: MeshInstance3D = root.get_node("Visual/" + id)
	var body: StaticBody3D = root.get_node("Collision/" + id)
	for node: Node in [visual, body, body.get_child(0)]:
		node.set_meta("stadium_item", ITEM)
		node.set_meta("surface_role", ROLE)
	body.set_meta("ball_surface", &"stadium_scenery")
