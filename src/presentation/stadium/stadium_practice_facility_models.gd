class_name StadiumPracticeFacilityModels
extends RefCounted
## Complete BQ practice scenery. Each purchased parent includes its full lane,
## supports, frame, bounded strands, rubber and plate; no live practice simulation.

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-060", "ST-061"]
const BULLPEN_VISIBLE: AABB = AABB(Vector3(-2, 0, -5), Vector3(4, 3, 10))
const CAGE_VISIBLE: AABB = AABB(Vector3(-2, 0, -5), Vector3(4, 3.5, 10))
const BULLPEN_RESERVATION: AABB = AABB(Vector3(-2.25, 0, -5.25), Vector3(4.5, 3.5, 10.5))
const CAGE_RESERVATION: AABB = AABB(Vector3(-2.25, 0, -5.25), Vector3(4.5, 4, 10.5))
const POST_Z: Array[float] = [-4.94, -2.47, 0.0, 2.47, 4.94]
const GRID: float = 0.25
const DIAMOND_GRID: float = 0.28
const STRAND_WIDTH: float = 0.009
const MAX_STRANDS: int = 400
const METAL: Color = Color("768885")
const FRAME: Color = Color("425a53")
const NET: Color = Color("bcc4a9")
const MARK: Color = Color("eee7cd")
const PRISM_FACES: Array = [
	[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]
]


static func create(item: String) -> Node3D:
	if item not in ITEMS:
		return null
	var root: Node3D = Node3D.new()
	root.name = item.replace("-", "") + "PracticeFacility"
	root.set_meta("stadium_item", item)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("envelope", envelope(item))
	root.set_meta("visible_bounds", visible_bounds(item))
	root.set_meta("static_geometry", true)
	root.set_meta("scenery_only", true)
	root.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
	root.set_meta("physics_profile", "DECORATIVE_AFTER_TERMINAL")
	root.set_meta("obstacle_units", 0)
	root.set_meta("lane_direction", Vector3.BACK)
	root.set_meta("ambient_ball_count", 0)
	root.set_meta("practice_figure_count", 0)
	root.set_meta("connected_pedestrian_route", false)
	root.set_meta("strand_count", 0)
	for id: String in ["Visual", "Collision"]:
		var branch: Node3D = Node3D.new()
		branch.name = id
		root.add_child(branch)
	var cage: bool = item == "ST-061"
	var height: float = 3.5 if cage else 3.0
	_lane(root, cage)
	_frame(root, height, cage)
	_enclosure(root, height, cage)
	return root


static func visible_bounds(item: String) -> AABB:
	return BULLPEN_VISIBLE if item == "ST-060" else CAGE_VISIBLE if item == "ST-061" else AABB()


static func envelope(item: String) -> AABB:
	return (
		BULLPEN_RESERVATION
		if item == "ST-060"
		else CAGE_RESERVATION if item == "ST-061" else AABB()
	)


static func bounds(item: String) -> AABB:
	return envelope(item)


static func _lane(root: Node3D, cage: bool) -> void:
	# The actual full-footprint slab rises above ground; no coplanar top overlay.
	_box(
		root,
		"LaneBase",
		Vector3(0, 0.04, 0),
		Vector3(4, 0.08, 10),
		Color("60764f") if cage else Color("b18a61")
	)
	_box(root, "PitchingPad", Vector3(0, 0.10, -3.5), Vector3(1.5, 0.04, 1.8), Color("526c49"))
	_box(root, "BattingPad", Vector3(0, 0.10, 3.5), Vector3(2.5, 0.04, 2.1), Color("526c49"))
	_box(root, "PitchingRubber", Vector3(0, 0.13, -3.5), Vector3(0.61, 0.02, 0.152), MARK)
	var outline: PackedVector2Array = [
		Vector2(-0.215, 3.63),
		Vector2(0.215, 3.63),
		Vector2(0.215, 3.42),
		Vector2(0, 3.20),
		Vector2(-0.215, 3.42)
	]
	var points: PackedVector3Array = []
	for y: float in [0.12, 0.132]:
		for point: Vector2 in outline:
			points.append(Vector3(point.x, y, point.y))
	_solid(
		root,
		"HomePlate",
		points,
		[
			[0, 1, 2, 3, 4],
			[5, 6, 7, 8, 9],
			[0, 1, 6, 5],
			[1, 2, 7, 6],
			[2, 3, 8, 7],
			[3, 4, 9, 8],
			[4, 0, 5, 9]
		],
		MARK
	)
	for side: int in [-1, 1]:
		for edge: int in [-1, 1]:
			_box(
				root,
				"BatterMarkLong%d_%d" % [side, edge],
				Vector3(side * 0.72 + edge * 0.25, 0.123, 3.4),
				Vector3(0.025, 0.006, 1.4),
				MARK
			)
			_box(
				root,
				"BatterMarkEnd%d_%d" % [side, edge],
				Vector3(side * 0.72, 0.123, 3.4 + edge * 0.6875),
				Vector3(0.475, 0.006, 0.025),
				MARK
			)


static func _frame(root: Node3D, height: float, cage: bool) -> void:
	var color: Color = FRAME if cage else METAL
	for side: int in [-1, 1]:
		for index in range(POST_Z.size()):
			var z: float = POST_Z[index]
			_box(
				root,
				"Foot%d_%d" % [side, index],
				Vector3(side * 1.86, 0.10, clampf(z, -4.86, 4.86)),
				Vector3(0.28, 0.04, 0.28),
				color
			)
			_box(
				root,
				"Post%d_%d" % [side, index],
				Vector3(side * 1.94, height / 2.0, z),
				Vector3(0.12, height - 0.24, 0.12),
				color
			)
		for level in range(2):
			_box(
				root,
				"SideRail%d_%d" % [side, level],
				Vector3(side * 1.94, 0.14 if level == 0 else height - 0.06, 0),
				Vector3(0.12, 0.12, 10),
				color
			)
	for end: int in [-1, 1]:
		_box(
			root,
			"EndTopRail%d" % end,
			Vector3(0, height - 0.06, end * 4.94),
			Vector3(3.76, 0.12, 0.12),
			color
		)
	_box(root, "BackBottomRail", Vector3(0, 0.14, 4.94), Vector3(3.76, 0.12, 0.12), color)
	for side: int in [-1, 1]:
		_box(
			root,
			"EntryWingRail%d" % side,
			Vector3(side * 1.245, 0.14, -4.94),
			Vector3(1.27, 0.12, 0.12),
			color
		)
		_box(
			root,
			"EntryJamb%d" % side,
			Vector3(side * 0.55, 1.195, -4.94),
			Vector3(0.12, 2.15, 0.12),
			color
		)
	_box(root, "EntryHeader", Vector3(0, 2.27, -4.94), Vector3(1.22, 0.12, 0.12), color)
	if cage:
		# Three complete cross-members provide a freestanding roof-net support frame.
		for index in range(1, 4):
			_box(
				root,
				"RoofCross%d" % index,
				Vector3(0, height - 0.06, POST_Z[index]),
				Vector3(3.76, 0.12, 0.12),
				color
			)
	else:
		# A closed, inset gate remains part of the full purchased chain-link enclosure.
		for side: int in [-1, 1]:
			_box(
				root,
				"GateStile%d" % side,
				Vector3(side * 0.46, 1.17, -4.94),
				Vector3(0.05, 2.06, 0.05),
				color
			)
		for level in range(2):
			_box(
				root,
				"GateRail%d" % level,
				Vector3(0, 0.165 if level == 0 else 2.175, -4.94),
				Vector3(0.92, 0.05, 0.05),
				color
			)
		for level in range(2):
			_box(
				root,
				"GateHinge%d" % level,
				Vector3(-0.49, 0.45 + level * 1.35, -4.94),
				Vector3(0.12, 0.10, 0.08),
				FRAME
			)
		_box(root, "GateLatch", Vector3(0.49, 1.16, -4.965), Vector3(0.14, 0.055, 0.06), FRAME)


static func _enclosure(root: Node3D, height: float, cage: bool) -> void:
	var panel_height: float = height - 0.20
	for side: int in [-1, 1]:
		_panel(
			root,
			"SideStrands%d" % side,
			Vector3(side * 1.94, 0.14, -4.94),
			Vector3.BACK,
			Vector3.UP,
			Vector2(9.88, panel_height),
			not cage
		)
	_panel(
		root,
		"BackStrands",
		Vector3(-1.94, 0.14, 4.94),
		Vector3.RIGHT,
		Vector3.UP,
		Vector2(3.88, panel_height),
		not cage
	)
	for side: int in [-1, 1]:
		_panel(
			root,
			"EntryWingStrands%d" % side,
			Vector3(-1.94 if side == -1 else 0.55, 0.14, -4.94),
			Vector3.RIGHT,
			Vector3.UP,
			Vector2(1.39, panel_height),
			not cage
		)
	_panel(
		root,
		"EntryUpperStrands",
		Vector3(-0.55, 2.27, -4.94),
		Vector3.RIGHT,
		Vector3.UP,
		Vector2(1.10, height - 2.33),
		not cage
	)
	if cage:
		_panel(
			root,
			"RoofStrands",
			Vector3(-1.94, height - 0.06, -4.94),
			Vector3.RIGHT,
			Vector3.BACK,
			Vector2(3.88, 9.88),
			false
		)
	else:
		_panel(
			root,
			"GateStrands",
			Vector3(-0.46, 0.165, -4.94),
			Vector3.RIGHT,
			Vector3.UP,
			Vector2(0.92, 2.01),
			true
		)


static func _panel(
	root: Node3D, id: String, origin: Vector3, u: Vector3, v: Vector3, size: Vector2, diamond: bool
) -> void:
	var segments: Array = []
	if diamond:
		# Clip both diagonal families to the real panel; coarse spacing bounds cost.
		for slope: float in [-1.0, 1.0]:
			for index in range(
				-ceili(size.x / DIAMOND_GRID) - 1, ceili((size.y + size.x) / DIAMOND_GRID) + 2
			):
				var intercept: float = index * DIAMOND_GRID
				var low: float = maxf(0, minf(-intercept / slope, (size.y - intercept) / slope))
				var high: float = minf(
					size.x, maxf(-intercept / slope, (size.y - intercept) / slope)
				)
				if high - low > 0.02:
					segments.append(
						[
							Vector2(low, slope * low + intercept),
							Vector2(high, slope * high + intercept)
						]
					)
	else:
		for column in range(ceili(size.x / GRID) + 1):
			var x: float = minf(size.x, column * GRID)
			segments.append([Vector2(x, 0), Vector2(x, size.y)])
		for row in range(ceili(size.y / GRID) + 1):
			var y: float = minf(size.y, row * GRID)
			segments.append([Vector2(0, y), Vector2(size.x, y)])
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var indices: PackedInt32Array = []
	# Bake one indexed generic unit quad per panel, then copy its actual triangles.
	# This bounds resource construction as well as the visible strand count.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	StadiumNetModels._quad(surface, Vector2(0, -0.5), Vector2(1, 0.5))
	surface.index()
	var primitive: ArrayMesh = surface.commit()
	var source_arrays: Array = primitive.surface_get_arrays(0)
	var local: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
	var local_indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
	for segment: Array in segments:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var axis: Vector2 = a.direction_to(b)
		var across: Vector2 = Vector2(-axis.y, axis.x)
		for source_index: int in local_indices:
			var point: Vector3 = local[source_index]
			var p: Vector2 = a + axis * point.x * a.distance_to(b) + across * point.y * STRAND_WIDTH
			vertices.append(origin + u * p.x + v * p.y)
			normals.append(-u.cross(v).normalized())
			indices.append(indices.size())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	StadiumStarterModels._mesh(root, id, Vector3.ZERO, mesh, METAL if diamond else NET)
	var visual: MeshInstance3D = root.get_node("Visual/" + id)
	visual.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.set_meta("visual_strands", true)
	visual.set_meta("strand_count", segments.size())
	visual.set_meta("strand_pattern", "diamond" if diamond else "square")
	visual.set_meta(
		"supported_panel", AABB(origin, Vector3.ZERO).expand(origin + u * size.x + v * size.y)
	)
	root.set_meta("strand_count", int(root.get_meta("strand_count")) + segments.size())


static func _box(root: Node3D, id: String, center: Vector3, size: Vector3, color: Color) -> void:
	var low: Vector3 = center - size / 2.0
	var high: Vector3 = center + size / 2.0
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


static func _solid(
	root: Node3D, id: String, points: PackedVector3Array, faces: Array, color: Color
) -> void:
	var mesh: ArrayMesh = StadiumGroundPropsModels._poly_mesh(points, faces)
	# Explicitly supply identity indices if a reused primitive ever omits its stream.
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_INDEX] == null or arrays[Mesh.ARRAY_INDEX].is_empty():
		var indices: PackedInt32Array = []
		for index in range(arrays[Mesh.ARRAY_VERTEX].size()):
			indices.append(index)
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	StadiumStarterModels._mesh(root, id, Vector3.ZERO, mesh, color)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("stadium_item", root.get_meta("stadium_item"))
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
