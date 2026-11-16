class_name StadiumMoldedSeatModels
extends RefCounted
## ST-051: one unoccupied molded stadium seat, ground pivot, facing local -Z.
## The fixed pad is map infrastructure. It creates no inventory or free seats.

const VERSION: int = 1
# Only the visible flush approach top is separated from the coplanar ground.
# The complete physical slab and both ramp endpoints remain exactly unchanged.
const APPROACH_VISUAL_RISE: float = 0.002
const ITEM: String = "ST-051"
const ENVELOPE: AABB = AABB(Vector3(-0.25, 0, -0.275), Vector3(0.50, 0.85, 0.55))
const PAD_BOUNDS: AABB = AABB(Vector3(-31, 0, 19), Vector3(6, 0.15, 3))
const APPROACH_BOUNDS: AABB = AABB(Vector3(-29, -0.04, 15), Vector3(2, 0.04, 2))
const RAMP_BOUNDS: AABB = AABB(Vector3(-29, 0, 17), Vector3(2, 0.15, 2))
const INFRASTRUCTURE_BOUNDS: AABB = AABB(Vector3(-31, -0.04, 15), Vector3(6, 0.19, 7))
const PIVOTS: Array[Vector3] = [
	Vector3(-29.5, 0.15, 20.8),
	Vector3(-28.5, 0.15, 20.8),
	Vector3(-27.5, 0.15, 20.8),
	Vector3(-26.5, 0.15, 20.8)
]
const PRISM_FACES: Array = [
	[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]
]
# Each section is [half width, outer y, outer z, inner y, inner z].
# The pan curves into a rear backrest; the lip and shoulders taper in width.
const SHELL: Array = [
	[0.22, 0.400, -0.275, 0.445, -0.275],
	[0.25, 0.380, -0.200, 0.425, -0.200],
	[0.25, 0.375, -0.020, 0.420, -0.020],
	[0.25, 0.400, 0.130, 0.445, 0.120],
	[0.25, 0.455, 0.230, 0.480, 0.180],
	[0.25, 0.550, 0.275, 0.550, 0.220],
	[0.25, 0.730, 0.275, 0.730, 0.220],
	[0.25, 0.820, 0.245, 0.820, 0.190],
	[0.20, 0.850, 0.215, 0.850, 0.160]
]


static func create(item: String = ITEM) -> Node3D:
	if item != ITEM:
		return null
	var root: Node3D = _root("ST051MoldedSeat")
	root.set_meta("stadium_item", ITEM)
	root.set_meta("envelope", ENVELOPE)
	root.set_meta("scenery_only", true)
	root.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
	root.set_meta("physics_profile", "DECORATIVE_AFTER_TERMINAL")
	root.set_meta("represented_seats", 1)
	root.set_meta("represented_audience", false)
	root.set_meta("facing", Vector3.FORWARD)
	for index in range(SHELL.size() - 1):
		var points: PackedVector3Array = _section(SHELL[index])
		points.append_array(_section(SHELL[index + 1]))
		_solid(
			root,
			"MoldedShell%02d" % index,
			points,
			PRISM_FACES,
			Color("426f86") if index < 4 else Color("4c7b92")
		)
	_box(
		root,
		"BasePlate",
		AABB(Vector3(-0.16, 0, -0.125), Vector3(0.32, 0.025, 0.28)),
		Color("687177")
	)
	_box(
		root,
		"Pedestal",
		AABB(Vector3(-0.05, 0.025, -0.035), Vector3(0.10, 0.33, 0.10)),
		Color("505b62")
	)
	_box(
		root,
		"PanBracket",
		AABB(Vector3(-0.155, 0.3475, -0.110), Vector3(0.31, 0.035, 0.25)),
		Color("626d74")
	)
	for side: int in [-1, 1]:
		for end: int in [-1, 1]:
			_bolt(
				root,
				"AnchorBolt%d_%d" % [side, end],
				Vector3(side * 0.12, 0.025, 0.015 + end * 0.09)
			)
	return root


static func create_pad() -> Node3D:
	var root: Node3D = _root("MoldedSeatFixedPad")
	root.set_meta("map_infrastructure", true)
	root.set_meta("infrastructure_id", "MOLDED_SEAT_PAD_FIXED")
	root.set_meta("paid_copy", false)
	root.set_meta("free_seats", false)
	root.set_meta("represented_seats", 0)
	root.set_meta("socket_pivots", PIVOTS.duplicate())
	root.set_meta("local_approach_only", true)
	root.set_meta("connected_pedestrian_route", false)
	root.set_meta("envelope", INFRASTRUCTURE_BOUNDS)
	_box(root, "FixedPad", PAD_BOUNDS, Color("aaa99d"))
	# The shallow approach slab ends exactly at ground level, never above it.
	_box(root, "LocalApproach", APPROACH_BOUNDS, Color("92968c"))
	var ramp: PackedVector3Array = [
		Vector3(-29, 0, 17),
		Vector3(-27, 0, 17),
		Vector3(-29, 0, 19),
		Vector3(-27, 0, 19),
		Vector3(-29, 0.15, 19),
		Vector3(-27, 0.15, 19)
	]
	_solid(
		root,
		"LocalRamp",
		ramp,
		[[0, 1, 3, 2], [0, 4, 5, 1], [2, 3, 5, 4], [0, 2, 4], [1, 5, 3]],
		Color("a0a397")
	)
	return root


static func _root(id: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = id
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("static_geometry", true)
	for id_value: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id_value
		root.add_child(child)
	return root


static func _section(row: Array) -> PackedVector3Array:
	return PackedVector3Array(
		[
			Vector3(-row[0], row[1], row[2]),
			Vector3(row[0], row[1], row[2]),
			Vector3(row[0], row[3], row[4]),
			Vector3(-row[0], row[3], row[4])
		]
	)


static func _box(root: Node3D, id: String, bounds: AABB, color: Color) -> void:
	var points: PackedVector3Array = []
	for y: float in [bounds.position.y, bounds.end.y]:
		points.append_array(
			PackedVector3Array(
				[
					Vector3(bounds.position.x, y, bounds.position.z),
					Vector3(bounds.end.x, y, bounds.position.z),
					Vector3(bounds.end.x, y, bounds.end.z),
					Vector3(bounds.position.x, y, bounds.end.z)
				]
			)
		)
	_solid(root, id, points, PRISM_FACES, color)


static func _bolt(root: Node3D, id: String, base: Vector3) -> void:
	var points: PackedVector3Array = []
	for y: float in [0.0, 0.02]:
		for index in range(12):
			var angle: float = TAU * float(index) / 12.0
			points.append(base + Vector3(cos(angle) * 0.012, y, sin(angle) * 0.012))
	var lower: Array = []
	var upper: Array = []
	var faces: Array = []
	for index in range(12):
		lower.append(index)
		upper.append(index + 12)
		faces.append([index, (index + 1) % 12, (index + 1) % 12 + 12, index + 12])
	faces.append(lower)
	faces.append(upper)
	_solid(root, id, points, faces, Color("b6bdba"))


static func _solid(
	root: Node3D, id: String, points: PackedVector3Array, faces: Array, color: Color
) -> void:
	var visible_points: PackedVector3Array = points.duplicate()
	if root.get_meta("map_infrastructure", false) and id == "LocalApproach":
		for index in range(visible_points.size()):
			if visible_points[index].y == APPROACH_BOUNDS.end.y:
				visible_points[index].y = APPROACH_VISUAL_RISE
	StadiumStarterModels._mesh(
		root, id, Vector3.ZERO, StadiumGroundPropsModels._poly_mesh(visible_points, faces), color
	)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("surface_id", id)
	if root.get_meta("map_infrastructure", false):
		body.set_meta("map_infrastructure", true)
		body.set_meta("infrastructure_id", "MOLDED_SEAT_PAD_FIXED")
		body.set_meta("surface_role", "GROUND")
		body.set_meta("ball_surface", &"ground")
	else:
		body.set_meta("stadium_item", ITEM)
		body.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
		body.set_meta("ball_surface", &"stadium_scenery")
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Solid"
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = points.duplicate()
	shape.margin = 0.0
	collider.shape = shape
	body.add_child(collider)
	root.get_node("Collision").add_child(body)
