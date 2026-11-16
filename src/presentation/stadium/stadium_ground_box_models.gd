class_name StadiumGroundBoxModels
extends RefCounted
## ST-052 is one complete ground section, facing local +Z. Its six broad seats
## and six static figures are bundled art representation, never ST-051 inventory.
## The right-rear local access stays inside the fixed reservation; no route claim.

const VERSION: int = 1
const ITEM: String = "ST-052"
const ENVELOPE: AABB = AABB(Vector3(-2.75, 0, -2), Vector3(5.5, 2.2, 4))
const ACTUAL_BOUNDS: AABB = AABB(Vector3(-2.75, 0, -2), Vector3(5.5, 1.54, 4))
const REPRESENTED_SEATS: int = 6
const SOLID_COUNT: int = 87
const MESH_COUNT: int = 111
const PRISM_FACES: Array = [
	[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]
]
const SEAT_X: Array[float] = [-1.65, -0.4, 0.85]
const ROW_Z: Array[float] = [0.55, -0.9]
const ROW_FLOOR: Array[float] = [0.12, 0.30]


static func create(item: String = ITEM) -> Node3D:
	if item != ITEM:
		return null
	var root: Node3D = Node3D.new()
	root.name = "ST052GroundBoxSection"
	root.set_meta("stadium_item", ITEM)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("envelope", ENVELOPE)
	root.set_meta("static_geometry", true)
	root.set_meta("scenery_only", true)
	root.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
	root.set_meta("physics_profile", "DECORATIVE_AFTER_TERMINAL")
	root.set_meta("obstacle_units", 0)
	root.set_meta("represented_seats", REPRESENTED_SEATS)
	root.set_meta("represented_audience", true)
	root.set_meta("represented_audience_count", REPRESENTED_SEATS)
	root.set_meta("bundled_seating", true)
	root.set_meta("local_approach_only", true)
	root.set_meta("connected_pedestrian_route", false)
	root.set_meta("facing", Vector3.BACK)
	for id: String in ["Visual", "Collision"]:
		var branch: Node3D = Node3D.new()
		branch.name = id
		root.add_child(branch)
	_base(root)
	_rails(root)
	for row in range(2):
		for place in range(3):
			var index: int = row * 3 + place
			var pivot: Vector3 = Vector3(SEAT_X[place], ROW_FLOOR[row], ROW_Z[row])
			_seat(root, index, pivot)
			StadiumSeatingModels._person(root, index, pivot + Vector3(0, 0.54, 0.035))
			_index_person(root.get_node("Visual/CrowdAnchor%d" % index))
	return root


static func _base(root: Node3D) -> void:
	# The slab is split around the local ramp; nothing overlays a coplanar ground top.
	_box(root, "GroundBase", AABB(Vector3(-2.75, 0, -2), Vector3(4.4, 0.12, 4)), Color("9c9c90"))
	_box(
		root, "EntryLanding", AABB(Vector3(1.65, 0, -0.9), Vector3(1.1, 0.12, 2.9)), Color("aaa99b")
	)
	var ramp: PackedVector3Array = [
		Vector3(1.65, 0, -2),
		Vector3(2.75, 0, -2),
		Vector3(1.65, 0, -0.9),
		Vector3(2.75, 0, -0.9),
		Vector3(1.65, 0.12, -0.9),
		Vector3(2.75, 0.12, -0.9)
	]
	_solid(
		root,
		"LocalAccessRamp",
		ramp,
		[[0, 1, 3, 2], [0, 4, 5, 1], [2, 3, 5, 4], [0, 2, 4], [1, 5, 3]],
		Color("b7b6a6")
	)
	_box(
		root,
		"RearRowRiser",
		AABB(Vector3(-2.5, 0.12, -1.75), Vector3(3.9, 0.18, 1.6)),
		Color("8e9288")
	)
	_box(
		root,
		"RearRowAccessStep",
		AABB(Vector3(1.4, 0.12, -0.85), Vector3(0.40, 0.09, 0.70)),
		Color("b3b5a5")
	)


static func _rails(root: Node3D) -> void:
	var metal: Color = Color("c1a56b")
	for index in range(5):
		var x: float = [-2.62, -1.31, 0.0, 1.31, 2.62][index]
		_box(
			root,
			"FrontPost%d" % index,
			AABB(Vector3(x - 0.045, 0.12, 1.835), Vector3(0.09, 1.12, 0.09)),
			metal
		)
	for index in range(4):
		var x: float = [-2.62, -1.31, 0.0, 1.42][index]
		_box(
			root,
			"RearPost%d" % index,
			AABB(Vector3(x - 0.045, 0.12, -1.925), Vector3(0.09, 1.12, 0.09)),
			metal
		)
	for side: int in [-1, 1]:
		for index in range(2):
			var z: float = -0.63 if index == 0 else 0.63
			_box(
				root,
				"SidePost%d_%d" % [side, index],
				AABB(Vector3(side * 2.62 - 0.045, 0.12, z - 0.045), Vector3(0.09, 1.12, 0.09)),
				metal
			)
	# This corner post bears on ground through the ramp, leaving a clear rear entrance.
	_box(root, "EntryCornerPost", AABB(Vector3(2.575, 0, -1.925), Vector3(0.09, 1.24, 0.09)), metal)
	for tier in range(2):
		var y: float = 0.64 if tier == 0 else 1.16
		_box(
			root,
			"FrontRail%d" % tier,
			AABB(Vector3(-2.665, y, 1.835), Vector3(5.33, 0.08, 0.09)),
			metal
		)
		_box(
			root,
			"RearRail%d" % tier,
			AABB(Vector3(-2.665, y, -1.925), Vector3(4.13, 0.08, 0.09)),
			metal
		)
		for side: int in [-1, 1]:
			_box(
				root,
				"SideRail%d_%d" % [side, tier],
				AABB(Vector3(side * 2.62 - 0.045, y, -1.88), Vector3(0.09, 0.08, 3.76)),
				metal
			)


static func _seat(root: Node3D, index: int, pivot: Vector3) -> void:
	var id: String = "BoxSeat%02d" % index
	var metal: Color = Color("465960")
	var cushion: Color = Color("34647b") if index < 3 else Color("3d7082")
	_box(
		root, id + "Base", AABB(pivot + Vector3(-0.18, 0, -0.17), Vector3(0.36, 0.025, 0.34)), metal
	)
	_box(
		root,
		id + "Pedestal",
		AABB(pivot + Vector3(-0.07, 0.025, -0.07), Vector3(0.14, 0.405, 0.14)),
		metal
	)
	_box(
		root,
		id + "PanFrame",
		AABB(pivot + Vector3(-0.33, 0.42, -0.32), Vector3(0.66, 0.06, 0.65)),
		metal
	)
	_box(
		root,
		id + "Cushion",
		AABB(pivot + Vector3(-0.31, 0.48, -0.30), Vector3(0.62, 0.06, 0.61)),
		cushion
	)
	_box(
		root,
		id + "BackFrame",
		AABB(pivot + Vector3(-0.33, 0.48, -0.37), Vector3(0.66, 0.59, 0.07)),
		metal
	)
	_box(
		root,
		id + "BackPad",
		AABB(pivot + Vector3(-0.31, 0.54, -0.30), Vector3(0.62, 0.50, 0.05)),
		cushion
	)
	for side: int in [-1, 1]:
		_box(
			root,
			id + "ArmPost%d" % side,
			AABB(pivot + Vector3(side * 0.38 - 0.03, 0.025, -0.12), Vector3(0.06, 0.665, 0.06)),
			metal
		)
		_box(
			root,
			id + "Arm%d" % side,
			AABB(pivot + Vector3(side * 0.38 - 0.045, 0.69, -0.30), Vector3(0.09, 0.07, 0.65)),
			Color("b89d70")
		)


static func _index_person(anchor: Node3D) -> void:
	# Reuse the existing generic static person shape; retain no primitive or shared
	# resource references and require explicit index streams on every stored mesh.
	for member: MeshInstance3D in anchor.get_children():
		var arrays: Array = member.mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_INDEX] == null or arrays[Mesh.ARRAY_INDEX].is_empty():
			var indices: PackedInt32Array = []
			for index in range(arrays[Mesh.ARRAY_VERTEX].size()):
				indices.append(index)
			arrays[Mesh.ARRAY_INDEX] = indices
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		member.mesh = mesh


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


static func _solid(
	root: Node3D, id: String, points: PackedVector3Array, faces: Array, color: Color
) -> void:
	StadiumStarterModels._mesh(
		root, id, Vector3.ZERO, StadiumGroundPropsModels._poly_mesh(points, faces), color
	)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("stadium_item", ITEM)
	body.set_meta("surface_id", id)
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
