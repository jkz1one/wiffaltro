class_name StadiumNpcMogulOneBowlV1
extends RefCounted
## Retained AM-01/r1 correspondence. Original: stadium_curved_lower_models.gd
## Working stylized ST-081 v1, complete standalone lower purchase assembly.

const VERSION: int = 1
const ROWS: int = 6
const CROWD_ANGLES: Array[float] = [-11.0, -8.0, -5.0, 5.0, 8.0, 11.0]
const SWAY: float = 0.04
const HALF: float = 14.7


static func create(occupied: bool = true) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ST081CurvedLowerWorking"
	root.set_meta("stadium_item", "ST-081")
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("represented_seats", ROWS * CROWD_ANGLES.size())
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	for row in range(ROWS):
		var inner: float = 18.35 + row * 1.05
		var deck: float = 1.30 + row * 0.45
		_band(root, "SolidTerrace%d" % row, inner, inner + 1.05, -HALF, HALF,
			0, deck, Color("818e84"))
		for side: int in [-1, 1]:
			var start: float = -13.4 if side == -1 else 2.8
			var end: float = -2.8 if side == -1 else 13.4
			_band(root, "SeatBand%d_%d" % [row, side], inner + 0.31, inner + 0.73,
				start, end, deck + 0.37, deck + 0.45, Color("507969"), false)
			_band(root, "SeatBack%d_%d" % [row, side], inner + 0.73, inner + 0.81,
				start, end, deck + 0.43, deck + 0.83, Color("507969"), false)
			_band(root, "SeatPlinth%d_%d" % [row, side], inner + 0.44, inner + 0.60,
				start, end, deck, deck + 0.37, Color("56645b"), false)
			var cap_start: float = -HALF if side == -1 else HALF - 0.75
			_band(root, "FinishedEnd%d_%d" % [row, side], inner, inner + 1.05,
				cap_start, cap_start + 0.75, deck, deck + 0.85, Color("bbc2ae"))
		# A contrasting aisle and short treads imply access without a playable interior.
		_band(root, "AccessAccent%d" % row, inner, inner + 1.05, -1.6, 1.6,
			deck, deck + 0.035, Color("c5b38d"), false)
		if occupied:
			for column in range(CROWD_ANGLES.size()):
				var index: int = row * CROWD_ANGLES.size() + column
				var point: Vector3 = polar(inner + 0.50, CROWD_ANGLES[column], deck + 0.46)
				StadiumNpcClubSeatingV1._person(root, index, point)
				var anchor: Node3D = root.get_node("Visual/CrowdAnchor%d" % index)
				anchor.rotation.y = deg_to_rad(CROWD_ANGLES[column]) + PI
				anchor.set_meta("rest_position", point)
	_band(root, "FrontRim", 18.10, 18.35, -HALF, HALF, 0, 1.95, Color("607a68"))
	_band(root, "RearRim", 24.65, 24.90, -HALF, HALF, 0, 4.40, Color("bbc2ae"))
	_band(root, "EntranceInlay", 24.90, 24.94, -1.5, 1.5, 0.08, 1.75,
		Color("344b43"), false)
	return root


static func animate_crowd(root: Node3D, phase: float) -> void:
	# No walking or arm extension: translated seated anchors have a strict 4cm envelope.
	for anchor: Node3D in root.get_node("Visual").get_children():
		if anchor.has_meta("rest_position"):
			anchor.position = anchor.get_meta("rest_position") + Vector3.UP * SWAY * sin(phase)


static func polar(radius: float, degrees: float, height: float) -> Vector3:
	return Vector3(radius * sin(deg_to_rad(degrees)), height, radius * cos(deg_to_rad(degrees)))


static func _band(root: Node3D, id: String, inner: float, outer: float, start: float,
	end: float, bottom: float, top: float, color: Color, solid: bool = true) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body: StaticBody3D = StaticBody3D.new() if solid else null
	if solid:
		body.name = id
		body.collision_layer = 1
		body.collision_mask = 2
		body.set_meta("stadium_item", "ST-081")
		body.set_meta("surface_id", id)
		body.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
		body.set_meta("ball_surface", &"stadium_scenery")
		root.get_node("Collision").add_child(body)
	var count: int = maxi(1, ceili((end - start) / 2.0))
	for segment in range(count):
		var a: float = lerpf(start, end, float(segment) / count)
		var b: float = lerpf(start, end, float(segment + 1) / count)
		var points: PackedVector3Array = []
		for height: float in [bottom, top]:
			for pair: Vector2 in [Vector2(inner, a), Vector2(outer, a),
				Vector2(outer, b), Vector2(inner, b)]:
				points.append(polar(pair.x, pair.y, height))
		for face: Array in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1],
			[1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
			for corner: int in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(points[face[corner]])
		if solid:
			var shape: CollisionShape3D = CollisionShape3D.new()
			shape.shape = ConvexPolygonShape3D.new()
			shape.shape.points = points
			shape.shape.margin = 0
			body.add_child(shape)
	surface.generate_normals()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = id
	mesh.mesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	root.get_node("Visual").add_child(mesh)
