class_name StadiumLiveFurnishingModels
extends RefCounted
## BS same-copy live/scenery furnishings. Exact hollow geometry, no scoring authority.
## Reversible blockout sizes approved for this rebuild; legacy factories stay frozen.

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-002", "ST-007"]
const LIVE: String = "LIVE_RICOCHET"
const BEACH_RADIUS: float = 0.40
const BEACH_CENTER: Vector3 = Vector3(0, 0.40, 0)
const BEACH_SLICES: int = 48
const BEACH_RINGS: int = 24
const TUB_OUTER: float = 1.30
const TUB_INNER: float = 1.05
const TUB_TOP: float = 1.00
const TUB_WATER: float = 0.78
const TUB_FLOOR: float = 0.08
const TUB_SEGMENTS: int = 64
const TUB_WATER_ID: String = "ST007_WATER_VOLUME_v1"
const TUB_RIM_BOTTOM: float = 0.90


static func create(item: String, live: bool = true) -> Node3D:
	if item not in ITEMS:
		return null
	var root: Node3D = Node3D.new()
	root.name = item.replace("-", "") + "Furnishing"
	root.set_meta("stadium_item", item)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("live_furnishing", live)
	root.set_meta("scenery_only", not live)
	root.set_meta("envelope", envelope(item))
	root.set_meta("reservation", reservation(item))
	for branch: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = branch
		root.add_child(child)
	if item == "ST-002":
		_beach(root, live)
	else:
		_tub(root, live)
	return root


static func envelope(item: String) -> AABB:
	match item:
		"ST-002":
			return AABB(Vector3(-BEACH_RADIUS, 0, -BEACH_RADIUS), Vector3.ONE * BEACH_RADIUS * 2.0)
		"ST-007":
			return AABB(
				Vector3(-TUB_OUTER, 0, -TUB_OUTER), Vector3(TUB_OUTER * 2, TUB_TOP, TUB_OUTER * 2)
			)
	return AABB()


static func reservation(item: String) -> AABB:
	match item:
		"ST-002":
			return AABB(Vector3(-1, 0, -1), Vector3(2, 1.5, 2))
		"ST-007":
			return AABB(Vector3(-1.75, 0, -1.75), Vector3(3.5, 1.5, 3.5))
	return AABB()


static func surfaces(item: String) -> Array[String]:
	match item:
		"ST-002":
			return ["BEACH_BALL"]
		"ST-007":
			return ["HOT_TUB_SHELL"]
	return []


static func contact_wobble(model: Node3D, local_hit: Vector3) -> void:
	if (
		not is_instance_valid(model)
		or model.get_meta("stadium_item", "") != "ST-002"
		or not model.get_meta("live_furnishing", false)
	):
		return
	var pivot: StadiumLiveFurnishingWobble = (
		model.get_node_or_null("Visual/BallPivot") as StadiumLiveFurnishingWobble
	)
	if pivot != null:
		pivot.react(local_hit - BEACH_CENTER)


static func wobble(model: Node3D) -> void:
	contact_wobble(model, BEACH_CENTER + Vector3.RIGHT)


static func beach_point(ring: int, slice: int) -> Vector3:
	if ring <= 0:
		return Vector3.UP * BEACH_RADIUS
	if ring >= BEACH_RINGS:
		return Vector3.DOWN * BEACH_RADIUS
	var theta: float = PI * ring / float(BEACH_RINGS)
	var phi: float = TAU * posmod(slice, BEACH_SLICES) / float(BEACH_SLICES)
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi)) * BEACH_RADIUS


static func beach_points() -> PackedVector3Array:
	var result: PackedVector3Array = [beach_point(0, 0), beach_point(BEACH_RINGS, 0)]
	for ring in range(1, BEACH_RINGS):
		for slice in range(BEACH_SLICES):
			result.append(beach_point(ring, slice))
	return result


static func tub_point(radius: float, height: float, index: int) -> Vector3:
	var angle: float = TAU * posmod(index, TUB_SEGMENTS) / float(TUB_SEGMENTS)
	return Vector3(radius * cos(angle), height, radius * sin(angle))


static func tub_polygon(radius: float) -> PackedVector2Array:
	var result: PackedVector2Array = []
	for index in range(TUB_SEGMENTS):
		var point: Vector3 = tub_point(radius, 0, index)
		result.append(Vector2(point.x, point.z))
	return result


static func water_polygon() -> PackedVector2Array:
	return tub_polygon(TUB_INNER)


static func tub_segment_points(index: int) -> PackedVector3Array:
	var result: PackedVector3Array = []
	for height: float in [0.0, TUB_TOP]:
		for radius: float in [TUB_INNER, TUB_OUTER]:
			result.append(tub_point(radius, height, index))
			result.append(tub_point(radius, height, index + 1))
	return result


static func tub_floor_points() -> PackedVector3Array:
	var result: PackedVector3Array = []
	for height: float in [0.0, TUB_FLOOR]:
		for index in range(TUB_SEGMENTS):
			result.append(tub_point(TUB_INNER, height, index))
	return result


static func _body(root: Node3D, id: String, center: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("stadium_item", root.get_meta("stadium_item"))
	body.set_meta("surface_id", id)
	body.set_meta("surface_role", LIVE)
	root.get_node("Collision").add_child(body)
	return body


static func _shape(body: StaticBody3D, id: String, points: PackedVector3Array) -> void:
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = id
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = points
	shape.margin = 0.0
	collider.shape = shape
	body.add_child(collider)


static func _beach(root: Node3D, live: bool) -> void:
	var pivot: Node3D = StadiumLiveFurnishingWobble.new() if live else Node3D.new()
	pivot.name = "BallPivot"
	pivot.position = BEACH_CENTER
	root.get_node("Visual").add_child(pivot)
	var colors: Array[Color] = [
		Color("db6654"),
		Color("f0e7ce"),
		Color("568fac"),
		Color("f0e7ce"),
		Color("e3b947"),
		Color("f0e7ce")
	]
	for panel in range(6):
		_beach_patch(
			pivot,
			"BeachPanel%d" % panel,
			2,
			BEACH_RINGS - 1,
			panel * 8,
			(panel + 1) * 8,
			colors[panel]
		)
	_beach_patch(pivot, "BeachNorthPatch", 1, 2, 0, BEACH_SLICES, Color("eee6d5"))
	_beach_patch(
		pivot, "BeachSouthPatch", BEACH_RINGS - 1, BEACH_RINGS, 0, BEACH_SLICES, Color("eee6d5")
	)
	_beach_patch(pivot, "BeachValve", 0, 1, 0, BEACH_SLICES, Color("829e9e"))
	if live:
		_shape(_body(root, "BEACH_BALL", BEACH_CENTER), "RestSphere", beach_points())


static func _beach_patch(
	parent: Node3D,
	id: String,
	first_ring: int,
	last_ring: int,
	first_slice: int,
	last_slice: int,
	color: Color
) -> void:
	var faces: PackedVector3Array = []
	for ring in range(first_ring, last_ring):
		for slice in range(first_slice, last_slice):
			var a: Vector3 = beach_point(ring, slice)
			var b: Vector3 = beach_point(ring, slice + 1)
			var c: Vector3 = beach_point(ring + 1, slice + 1)
			var d: Vector3 = beach_point(ring + 1, slice)
			_triangle(faces, a, b, c, (a + b + c).normalized())
			_triangle(faces, a, c, d, (a + c + d).normalized())
	_add_mesh(parent, id, faces, color, true)


static func _tub(root: Node3D, live: bool) -> void:
	var visual: Node3D = root.get_node("Visual")
	for index in range(TUB_SEGMENTS):
		var faces: PackedVector3Array = []
		_vertical_quad(faces, TUB_OUTER, 0.0, 0.14, index, false)
		_vertical_quad(faces, TUB_OUTER, 0.18, 0.72, index, false)
		_vertical_quad(faces, TUB_OUTER, 0.76, TUB_RIM_BOTTOM, index, false)
		var color: Color = [Color("9b6f48"), Color("ad8052"), Color("88603f"), Color("a4774e")][
			index % 4
		]
		_add_mesh(visual, "TubWoodStave%02d" % index, faces, color)
	for band in range(2):
		var faces: PackedVector3Array = []
		var low: float = 0.14 if band == 0 else 0.72
		for index in range(TUB_SEGMENTS):
			_vertical_quad(faces, TUB_OUTER, low, low + 0.04, index, false)
		_add_mesh(visual, "TubRetainingBand%d" % band, faces, Color("5e645d"))
	var liner: PackedVector3Array = []
	var rim: PackedVector3Array = []
	var base: PackedVector3Array = []
	for index in range(TUB_SEGMENTS):
		_vertical_quad(liner, TUB_INNER, TUB_FLOOR, TUB_RIM_BOTTOM, index, true)
		_vertical_quad(rim, TUB_INNER, TUB_RIM_BOTTOM, TUB_TOP, index, true)
		_vertical_quad(rim, TUB_OUTER, TUB_RIM_BOTTOM, TUB_TOP, index, false)
		_ring_quad(rim, TUB_INNER, TUB_OUTER, TUB_TOP, index, Vector3.UP)
		_ring_quad(base, TUB_INNER, TUB_OUTER, 0.0, index, Vector3.DOWN)
	_add_mesh(visual, "TubInnerLiner", liner, Color("c4d0bc"))
	_add_mesh(visual, "TubContinuousRim", rim, Color("d8c5a0"))
	_add_mesh(visual, "TubUnderside", base, Color("735337"))
	_add_mesh(visual, "TubBasinFloor", _disk(TUB_INNER, TUB_FLOOR, true), Color("b7c8b5"))
	_add_mesh(visual, "TubFloorUnderside", _disk(TUB_INNER, 0.0, false), Color("735337"))
	var water: MeshInstance3D = _add_mesh(
		visual, "TubWater", _disk(TUB_INNER, TUB_WATER, true), Color("4c9698")
	)
	(water.material_override as StandardMaterial3D).roughness = 0.24
	water.set_meta("aperture_id", TUB_WATER_ID)
	if live:
		var body: StaticBody3D = _body(root, "HOT_TUB_SHELL", Vector3.ZERO)
		for index in range(TUB_SEGMENTS):
			_shape(body, "AnnularSegment%02d" % index, tub_segment_points(index))
		_shape(body, "BasinFloor", tub_floor_points())
		var volume: Node3D = Node3D.new()
		volume.name = "WaterVolume"
		volume.set_meta("volume_id", TUB_WATER_ID)
		volume.set_meta("floor", TUB_FLOOR)
		volume.set_meta("height", TUB_WATER)
		volume.set_meta("polygon", water_polygon())
		root.add_child(volume)


static func _vertical_quad(
	faces: PackedVector3Array, radius: float, low: float, high: float, index: int, inward: bool
) -> void:
	var a: Vector3 = tub_point(radius, low, index)
	var b: Vector3 = tub_point(radius, low, index + 1)
	var normal: Vector3 = Vector3(a.x + b.x, 0, a.z + b.z).normalized() * (-1.0 if inward else 1.0)
	_quad(faces, a, b, Vector3(b.x, high, b.z), Vector3(a.x, high, a.z), normal)


static func _ring_quad(
	faces: PackedVector3Array,
	inner: float,
	outer: float,
	height: float,
	index: int,
	normal: Vector3
) -> void:
	_quad(
		faces,
		tub_point(inner, height, index),
		tub_point(inner, height, index + 1),
		tub_point(outer, height, index + 1),
		tub_point(outer, height, index),
		normal
	)


static func _disk(radius: float, height: float, upward: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	for index in range(TUB_SEGMENTS):
		_triangle(
			result,
			Vector3(0, height, 0),
			tub_point(radius, height, index),
			tub_point(radius, height, index + 1),
			Vector3.UP if upward else Vector3.DOWN
		)
	return result


static func _quad(
	faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3
) -> void:
	_triangle(faces, a, b, c, normal)
	_triangle(faces, a, c, d, normal)


static func _triangle(
	faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, outward: Vector3
) -> void:
	var cross_value: Vector3 = -(b - a).cross(c - a)
	if cross_value.length_squared() < 0.000000000001:
		return
	if cross_value.dot(outward) < 0.0:
		faces.append_array(PackedVector3Array([a, c, b]))
	else:
		faces.append_array(PackedVector3Array([a, b, c]))


static func _add_mesh(
	parent: Node3D,
	id: String,
	faces: PackedVector3Array,
	color: Color,
	sphere_normals: bool = false
) -> MeshInstance3D:
	var normals: PackedVector3Array = []
	for index in range(0, faces.size(), 3):
		var normal: Vector3 = -(
			(faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index]).normalized()
		)
		for offset in range(3):
			normals.append(faces[index + offset].normalized() if sphere_normals else normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(range(faces.size()))
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.74
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = id
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
