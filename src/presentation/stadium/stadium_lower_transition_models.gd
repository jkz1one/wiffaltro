class_name StadiumLowerTransitionModels
extends RefCounted
## Separately identified, independently wound Working lower transition assemblies.

const VERSION: int = 1
const ROWS: int = 6
const SEAT_T: Array[float] = [0.24, 0.45, 0.66]
const S = preload("res://src/gameplay/stadium/stadium_lower_transition_sites.gd")


static func create_right(occupied: bool = true) -> Node3D:
	return _create("JOIN-R", occupied)


static func create_left(occupied: bool = true) -> Node3D:
	return _create("JOIN-L", occupied)


static func deck(site: String, row: int, t: float, u: float) -> float:
	# An affine world-space ramp makes each tessellated terrace top exactly planar.
	var along: Vector2 = Vector2(16, 29.4).normalized()
	var vertex: Vector3 = S.point(site, t, u)
	var start: Vector3 = S.point("JOIN-R", 0, 0.35 + row * 1.05 + 0.525)
	var station: float = (Vector2(absf(vertex.x), vertex.z) - Vector2(8, -6)).dot(along)
	var first: float = (Vector2(start.x, start.z) - Vector2(8, -6)).dot(along)
	return lerpf(1.30 + row * 0.45, 3.0 + row * 0.60, (station - first) / (12 - first))


static func _create(site: String, occupied: bool) -> Node3D:
	var root: Node3D = StadiumBaselineStandModels._root(S.item(site))
	root.name = "ST085RightLowerWorking" if site == "JOIN-R" else "ST088LeftLowerWorking"
	root.set_meta("site", site)
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("represented_seats", ROWS * SEAT_T.size())
	root.set_meta("baseline_end", "stair" if site == "JOIN-R" else "solid")
	for row in range(ROWS):
		var u: float = 0.35 + row * 1.05
		_patch(root, "SolidTerrace%d" % row, S.MIN_T, S.MAX_T, u, u + 1.05,
			row, -100, 0, Color("818e84"))
		_patch(root, "SeatBand%d" % row, 0.16, 0.73, u + 0.31, u + 0.73,
			row, 0.37, 0.45, Color("507969"), false)
		_patch(root, "SeatBack%d" % row, 0.16, 0.73, u + 0.73, u + 0.81,
			row, 0.43, 0.83, Color("507969"), false)
		_patch(root, "SeatPlinth%d" % row, 0.16, 0.73, u + 0.44, u + 0.60,
			row, 0, 0.37, Color("56645b"), false)
		_patch(root, "FinishedBowlEnd%d" % row, S.MIN_T, 0.075, u, u + 1.05,
			row, 0, 0.65, Color("bbc2ae"))
		var end_height: float = 0.40 if site == "JOIN-R" else 0.75
		_patch(root, "FinishedBaselineEnd%d" % row, 0.925, S.MAX_T, u, u + 1.05,
			row, 0, end_height, Color("bbc2ae"))
		_patch(root, "AccessAccent%d" % row, 0.79, 0.89, u, u + 1.05,
			row, 0, 0.035, Color("c5b38d"), false)
		if occupied:
			for column in range(SEAT_T.size()):
				var index: int = row * SEAT_T.size() + column
				var t: float = SEAT_T[column]
				var center: Vector3 = S.point(site, t, u + 0.50,
					deck(site, row, t, u + 0.50) + 0.46)
				StadiumSeatingModels._person(root, index, center)
				var anchor: Node3D = root.get_node("Visual/CrowdAnchor%d" % index)
				anchor.rotation.y = atan2(-center.x, 8 - center.z)
				anchor.set_meta("rest_position", center)
	_patch(root, "FrontRim", S.MIN_T, S.MAX_T, S.MIN_U, 0.35,
		0, -100, 0.45, Color("607a68"))
	_patch(root, "RearRim", S.MIN_T, S.MAX_T, 6.65, S.MAX_U,
		5, -100, 0.75, Color("bbc2ae"))
	_patch(root, "ClosedEntranceInlay", 0.79, 0.89, 6.88, 6.895,
		0, -100, -0.1, Color("344b43"), false)
	return root


static func _patch(root: Node3D, id: String, t0: float, t1: float,
	u0: float, u1: float, row: int, bottom: float, top: float,
	color: Color, solid: bool = true) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var site: String = root.get_meta("site")
	var body: StaticBody3D = null
	if solid:
		body = StaticBody3D.new()
		body.name = id
		body.collision_layer = 1
		body.collision_mask = 2
		body.set_meta("stadium_item", S.item(site))
		body.set_meta("surface_id", id)
		body.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
		body.set_meta("ball_surface", &"stadium_scenery")
		root.get_node("Collision").add_child(body)
	var points: PackedVector3Array = []
	for offset: float in [bottom, top]:
		for pair: Vector2 in [Vector2(t0, u0), Vector2(t1, u0),
			Vector2(t1, u1), Vector2(t0, u1)]:
			var height: float = 0 if offset == -100 else deck(site, row, pair.x, pair.y) + offset
			points.append(S.point(site, pair.x, pair.y, height))
	var center: Vector3 = Vector3.ZERO
	for point: Vector3 in points:
		center += point / 8
	for face: Array in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 4, 5, 1],
		[1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		# Godot uses clockwise front faces. Winding is authored separately for each hand.
		var cross: Vector3 = (points[face[1]] - points[face[0]]).cross(
			points[face[2]] - points[face[0]])
		if cross.dot(points[face[0]] - center) > 0:
			face.reverse()
		for corner: int in [0, 1, 2, 0, 2, 3]:
			surface.add_vertex(points[face[corner]])
	if solid:
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = ConvexPolygonShape3D.new()
		collision.shape.points = points
		collision.shape.margin = 0
		body.add_child(collision)
	surface.generate_normals()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = id
	mesh.mesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	root.get_node("Visual").add_child(mesh)
