class_name StadiumWallTopTerraceModels
extends RefCounted
## One ST-087 terrace: exact six-host bearings, complete roofless deck, viewing
## positions, rest benches, guards, rear supports and grounded compact access.
## Local +Z is outward; all solids are downstream of the existing scoring wall.

const VERSION: int = 1
const ITEM: String = "ST-087"
const ITEMS: Array[String] = [ITEM]
const HOST_ITEMS: Array[String] = ["ST-065", "ST-077"]
const SITE: String = "TERRACE-R-A"
const WORLD_CENTER: Vector3 = Vector3(15, 0, 23.4)
const ENVELOPE: AABB = AABB(Vector3(-6, 0, 0.02), Vector3(12, 4.73, 6.98))
const RESERVATION: AABB = AABB(Vector3(-6, 0, 0), Vector3(12, 4.8, 7))
const HOST_TOP: float = 3.25
const DECK_TOP: float = 3.65
const DECK_BOTTOM: float = 3.45
const STAIR_COUNT: int = 18
const STAIR_RISE: float = DECK_TOP / STAIR_COUNT
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const HOST_X: Array[float] = [-5, -3, -1, 1, 3, 5]
const SUPPORT_X: Array[float] = [-5, -3, -1, 1, 3]
const FRAME: Color = Color("435f63")
const METAL: Color = Color("b4c0b1")
const DECK: Color = Color("b9bba8")
const CONCRETE: Color = Color("8b9488")
const BENCH: Color = Color("c8a976")
const MARKER: Color = Color("d4c798")
const PRISM_FACES: Array = [
	[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]
]
# Structure 35, viewing/rest furniture 24, access 19, guards 74 = 152.
const MESH_COUNT: int = 152
const SOLID_COUNT: int = MESH_COUNT


static func create(item: String = ITEM, host_item: String = "ST-065") -> Node3D:
	if item != ITEM or host_item not in HOST_ITEMS:
		return null
	var root: Node3D = Node3D.new()
	root.name = "ST087WallTopTerrace"
	root.set_meta("stadium_item", ITEM)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("final_art_accepted", false)
	root.set_meta("envelope", ENVELOPE)
	root.set_meta("reservation", RESERVATION)
	root.set_meta("surface_role", ROLE)
	root.set_meta("physics_profile", ROLE)
	root.set_meta("host_item", host_item)
	root.set_meta("socket_profile", socket_profile(host_item))
	root.set_meta("static_geometry", true)
	root.set_meta("scenery_only", true)
	root.set_meta("bundled_supports", true)
	root.set_meta("bundled_access", true)
	root.set_meta("local_approach_only", true)
	root.set_meta("connected_pedestrian_route", false)
	root.set_meta("represented_view_positions", 12)
	root.set_meta("represented_audience_count", 0)
	root.set_meta("obstacle_units", 0)
	root.set_meta("facing", Vector3.FORWARD)
	root.set_meta("supported_wall_height", HOST_TOP)
	for id: String in ["Visual", "Collision"]:
		var branch: Node3D = Node3D.new()
		branch.name = id
		root.add_child(branch)
	_structure(root, host_item)
	_viewing(root)
	_access(root)
	_guards(root)
	return root


static func pose() -> Transform3D:
	return Transform3D(Basis.IDENTITY, WORLD_CENTER)


static func envelope(item: String = ITEM) -> AABB:
	return ENVELOPE if item == ITEM else AABB()


static func reservation(item: String = ITEM) -> AABB:
	return RESERVATION if item == ITEM else AABB()


static func bounds(item: String = ITEM) -> AABB:
	return envelope(item)


static func visible_bounds(item: String = ITEM) -> AABB:
	return envelope(item)


static func mesh_count(item: String = ITEM) -> int:
	return MESH_COUNT if item == ITEM else 0


static func solid_count(item: String = ITEM) -> int:
	return SOLID_COUNT if item == ITEM else 0


static func socket_profile(host_item: String) -> Dictionary:
	if host_item not in HOST_ITEMS:
		return {}
	# Plain scalars/arrays intentionally form stable saved-signature input.
	return {
		"version": 1,
		"host_item": host_item,
		"host_span": "full",
		"host_top": 3.25,
		"wall_field_z": 0.0,
		"wall_rear_z": 0.35,
		"host_centers_x": [-5, -3, -1, 1, 3, 5],
		"saddle_width": 1.6,
		"bearing_z": [0.21, 0.35] if host_item == "ST-065" else [0.02, 0.35],
		"bearing_y": [3.25, 3.45],
		"deck_y": [3.45, 3.65],
		"bearing_material":
		"padded_structural_backing" if host_item == "ST-065" else "brick_mortar_core"
	}


static func eye_points() -> PackedVector3Array:
	var result: PackedVector3Array = []
	for index in range(12):
		result.append(Vector3(-5.5 + index, 5.27, 0.8))
	return result


static func support_points() -> PackedVector3Array:
	var result: PackedVector3Array = []
	for x: float in SUPPORT_X:
		result.append(Vector3(x, 0, 6.65))
	for index in range(STAIR_COUNT):
		result.append(Vector3(5.2, 0, 5.875 - index * 0.25))
	result.append(Vector3(5.2, 0, 6.5))
	return result


static func _structure(root: Node3D, host_item: String) -> void:
	var bearing: float = 0.21 if host_item == "ST-065" else 0.02
	for index in range(6):
		_box(
			root,
			"HostSaddle%d" % index,
			Vector3(HOST_X[index] - 0.8, 3.25, bearing),
			Vector3(1.6, 0.2, 0.35 - bearing),
			FRAME
		)
	# This continuous transom abuts the six cap saddles, wholly behind the wall.
	_box(root, "HostTransom", Vector3(-6, 3.25, 0.35), Vector3(12, 0.20, 0.28), FRAME)
	for index in range(5):
		var x: float = SUPPORT_X[index]
		_box(
			root,
			"RearFoot%d" % index,
			Vector3(x - 0.24, 0, 6.41),
			Vector3(0.48, 0.18, 0.48),
			CONCRETE
		)
		_box(
			root,
			"RearColumn%d" % index,
			Vector3(x - 0.11, 0.18, 6.54),
			Vector3(0.22, 2.77, 0.22),
			FRAME
		)
		_box(
			root,
			"DeckJoist%d" % index,
			Vector3(x - 0.09, 3.07, 0.63),
			Vector3(0.18, 0.38, 6.24),
			FRAME
		)
	_box(root, "RearLoadBeam", Vector3(-5.85, 2.95, 6.49), Vector3(10.25, 0.30, 0.32), FRAME)
	_box(root, "LeftRimBeam", Vector3(-6, 3.07, 0.63), Vector3(0.18, 0.38, 6.37), FRAME)
	_box(root, "RightRimBeam", Vector3(4.22, 3.07, 1.5), Vector3(0.18, 0.38, 5.5), FRAME)
	_box(root, "LandingJoist", Vector3(4.91, 3.25, 0.63), Vector3(0.18, 0.20, 0.87), FRAME)
	for bay in range(4):
		_beam(
			root,
			"RearBrace%d" % bay,
			Vector3(SUPPORT_X[bay], 0.28, 6.65),
			Vector3(SUPPORT_X[bay + 1], 2.95, 6.65),
			0.10,
			FRAME
		)
	_box(root, "MainDeck", Vector3(-6, 3.45, 0.02), Vector3(10.4, 0.2, 6.98), DECK)
	_box(root, "TopLanding", Vector3(4.4, 3.45, 0.02), Vector3(1.6, 0.2, 1.48), DECK)
	# Closed perimeter fascia is integral to the assembly; no free end-cap copy.
	_box(root, "LeftFinishedEnd", Vector3(-6, 3.25, 0.02), Vector3(0.12, 0.20, 6.98), BENCH)
	_box(root, "RightFinishedEnd", Vector3(5.88, 3.25, 0.02), Vector3(0.12, 0.20, 1.48), BENCH)
	_box(root, "RearFinishedEnd", Vector3(-6, 3.25, 6.88), Vector3(10.4, 0.20, 0.12), BENCH)


static func _viewing(root: Node3D) -> void:
	for index in range(12):
		_box(
			root,
			"ViewPosition%d" % index,
			Vector3(-5.75 + index, 3.65, 0.50),
			Vector3(0.5, 0.02, 0.6),
			MARKER
		)
	# Backless rest benches leave the front standing-view line and both access aisles clear.
	for index in range(3):
		var x: float = -4.4 + index * 3.0
		_box(
			root,
			"RestBench%d" % index,
			Vector3(x - 1.1, 4.05, 4.25),
			Vector3(2.2, 0.10, 0.5),
			BENCH
		)
		for side: int in [-1, 1]:
			_box(
				root,
				"RestBenchLeg%d_%d" % [index, side],
				Vector3(x + side * 0.85 - 0.06, 3.65, 4.38),
				Vector3(0.12, 0.4, 0.24),
				FRAME
			)
		_box(
			root,
			"RestBenchStretcher%d" % index,
			Vector3(x - 0.91, 3.82, 4.44),
			Vector3(1.82, 0.08, 0.12),
			FRAME
		)


static func _access(root: Node3D) -> void:
	_box(root, "GroundApproach", Vector3(4.4, 0, 6), Vector3(1.6, 0.04, 1), CONCRETE)
	# All eighteen stair masses bear on the real y=0 property, no floating treads.
	for index in range(STAIR_COUNT):
		_box(
			root,
			"AccessStep%d" % index,
			Vector3(4.4, 0, 5.75 - index * 0.25),
			Vector3(1.6, (index + 1) * STAIR_RISE, 0.25),
			CONCRETE
		)


static func _guards(root: Node3D) -> void:
	_guard(root, "FrontGuard", Vector3(-5.94, 3.65, 0.08), Vector3(5.94, 3.65, 0.08), 1.08, 12)
	_guard(root, "LeftGuard", Vector3(-5.94, 3.65, 0.08), Vector3(-5.94, 3.65, 6.94), 1.08, 6)
	_guard(root, "RearGuard", Vector3(-5.94, 3.65, 6.94), Vector3(4.34, 3.65, 6.94), 1.08, 10)
	_guard(root, "DeckEdgeGuard", Vector3(4.34, 3.65, 1.5), Vector3(4.34, 3.65, 6.94), 1.08, 5)
	_guard(root, "LandingGuard", Vector3(5.94, 3.65, 0.08), Vector3(5.94, 3.65, 1.5), 1.08, 2)
	for side in range(2):
		var x: float = 4.46 if side == 0 else 5.94
		for index in range(10):
			var step: int = mini(index * 2, 17)
			var point: Vector3 = Vector3(x, (step + 1) * STAIR_RISE, 5.875 - step * 0.25)
			_box(
				root,
				"StairGuard%dPost%d" % [side, index],
				point + Vector3(-0.03, 0, -0.03),
				Vector3(0.06, 1.0, 0.06),
				METAL
			)
		for level in range(2):
			var h: float = 0.96 if level else 0.5
			_beam(
				root,
				"StairGuard%dRail%d" % [side, level],
				Vector3(x, STAIR_RISE + h, 5.875),
				Vector3(x, DECK_TOP + h, 1.625),
				0.08,
				METAL
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
		var h: float = height - 0.04 if level else 0.45
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
