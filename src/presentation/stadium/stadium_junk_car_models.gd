class_name StadiumJunkCarModels
extends RefCounted
## Original closed, immobile ST005 hatchback. Exact solid pieces share their visual
## vertices with convex collision; the underbody is deliberately not a box collider.
## Trap entry is geometric admission ONLY. The runtime must prove that an admitted
## ball becomes stationary/unreachable before applying the retained trapped rule.

const VERSION: int = 1
const ITEM: String = "ST-005"
const ITEMS: Array[String] = [ITEM]
const LIVE_UNITS: int = 4
const LIVE: String = "LIVE_RICOCHET"
const SURFACE: String = "JUNK_CAR_BODY"
const TRAP_ID: String = "ST005_UNDERBODY_TRAP_v1"
const TRAP_FLOOR: float = 0.0
const TRAP_HEIGHT: float = 0.28
const TRAP_HALF_WIDTH: float = 0.65
const TRAP_HALF_LENGTH: float = 0.72
const EPS: float = 0.00001
const WHEEL_SEGMENTS: int = 20
const PAINT: Color = Color("637362")
const RUST: Color = Color("925c39")
const DARK_RUST: Color = Color("643d2b")
const GLASS: Color = Color("344c4d")


static func create(item: String = ITEM, live: bool = true) -> Node3D:
	if item != ITEM:
		return null
	var root: Node3D = Node3D.new()
	root.name = "ST005RustyCompactCar"
	root.set_meta("stadium_item", ITEM)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("live_furnishing", live)
	root.set_meta("scenery_only", not live)
	root.set_meta("envelope", envelope(item))
	root.set_meta("reservation", reservation(item))
	for branch: String in ["Visual", "Collision"]:
		var node: Node3D = Node3D.new()
		node.name = branch
		root.add_child(node)
	if live:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = SURFACE
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("stadium_item", ITEM)
		body.set_meta("surface_id", SURFACE)
		body.set_meta("surface_role", LIVE)
		root.get_node("Collision").add_child(body)
	_bodywork(root, live)
	_wheels(root, live)
	_details(root)
	if live:
		var carrier: Node3D = Node3D.new()
		carrier.name = "UnderbodyTrap"
		carrier.set_meta("volume_id", TRAP_ID)
		carrier.set_meta("floor", TRAP_FLOOR)
		carrier.set_meta("height", TRAP_HEIGHT)
		carrier.set_meta("polygon", trap_polygon())
		carrier.set_meta("apertures", trap_apertures())
		root.add_child(carrier)
	return root


static func envelope(item: String = ITEM) -> AABB:
	return AABB(Vector3(-0.85, 0, -1.90), Vector3(1.70, 1.40, 3.80)) if item == ITEM else AABB()


static func reservation(item: String = ITEM) -> AABB:
	return AABB(Vector3(-1.15, 0, -2.20), Vector3(2.30, 1.80, 4.40)) if item == ITEM else AABB()


static func surfaces(item: String = ITEM) -> Array[String]:
	if item == ITEM:
		return [SURFACE]
	return []


static func trap_polygon() -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(-TRAP_HALF_WIDTH, -TRAP_HALF_LENGTH),
			Vector2(TRAP_HALF_WIDTH, -TRAP_HALF_LENGTH),
			Vector2(TRAP_HALF_WIDTH, TRAP_HALF_LENGTH),
			Vector2(-TRAP_HALF_WIDTH, TRAP_HALF_LENGTH)
		]
	)


static func trap_apertures() -> Array[Dictionary]:
	return [
		{
			"id": "UNDERBODY_LEFT",
			"origin": Vector3(-TRAP_HALF_WIDTH, 0, 0),
			"inward": Vector3.RIGHT,
			"half_length": TRAP_HALF_LENGTH,
			"floor": TRAP_FLOOR,
			"height": TRAP_HEIGHT
		},
		{
			"id": "UNDERBODY_RIGHT",
			"origin": Vector3(TRAP_HALF_WIDTH, 0, 0),
			"inward": Vector3.LEFT,
			"half_length": TRAP_HALF_LENGTH,
			"floor": TRAP_FLOOR,
			"height": TRAP_HEIGHT
		}
	]


static func trap_contains_local(point: Vector3, radius: float) -> bool:
	if not point.is_finite() or not is_finite(radius) or radius <= EPS:
		return false
	# Ground tangency is legal. Ceiling and side/axle edges require clear space.
	return (
		point.y >= TRAP_FLOOR + radius - EPS
		and point.y < TRAP_HEIGHT - radius - EPS
		and absf(point.x) < TRAP_HALF_WIDTH - radius - EPS
		and absf(point.z) < TRAP_HALF_LENGTH - radius - EPS
	)


static func trap_entry_local(previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	if (
		not previous.is_finite()
		or not current.is_finite()
		or not is_finite(radius)
		or radius <= EPS
		or radius * 2.0 >= TRAP_HEIGHT - TRAP_FLOOR
	):
		return {}
	var selected: Dictionary = {}
	for aperture: Dictionary in trap_apertures():
		var inward: Vector3 = aperture.inward
		var start: float = (previous - aperture.origin).dot(inward)
		var finish: float = (current - aperture.origin).dot(inward)
		# Crossing is witnessed when the WHOLE sphere has entered, not when its
		# outside edge touches a broad box. An already-inside ball is not admitted.
		if start >= radius or finish <= radius + EPS or finish <= start:
			continue
		var fraction: float = (radius + EPS - start) / (finish - start)
		var position: Vector3 = previous.lerp(current, fraction)
		if (
			not is_finite(fraction)
			or not position.is_finite()
			or position.y < TRAP_FLOOR + radius - EPS
			or position.y >= TRAP_HEIGHT - radius - EPS
			or absf(position.z) >= TRAP_HALF_LENGTH - radius - EPS
		):
			continue
		# The segment must actually reach interior clearance. Tangency cannot arm
		# an unreachable-ball claim, and top/bottom/longitudinal entries do not count.
		if selected.is_empty() or fraction < float(selected.fraction):
			selected = {
				"fraction": fraction,
				"position": position,
				"aperture": aperture.id,
				"volume_id": TRAP_ID
			}
	return selected


static func _bodywork(root: Node3D, live: bool) -> void:
	var footprint: PackedVector2Array = [
		Vector2(-0.68, -1.82),
		Vector2(0.68, -1.82),
		Vector2(0.79, -1.60),
		Vector2(0.79, 1.55),
		Vector2(0.67, 1.82),
		Vector2(-0.67, 1.82),
		Vector2(-0.79, 1.55),
		Vector2(-0.79, -1.60)
	]
	_prism(root, "ClosedLowerBody", footprint, TRAP_HEIGHT, 0.70, PAINT, live)
	# The cabin is a closed tapered hatchback, not an open target or a giant box.
	var cabin: PackedVector3Array = [
		Vector3(-0.73, 0.70, -0.78),
		Vector3(0.73, 0.70, -0.78),
		Vector3(0.73, 0.70, 1.48),
		Vector3(-0.73, 0.70, 1.48),
		Vector3(-0.59, 1.399, -0.27),
		Vector3(0.59, 1.399, -0.27),
		Vector3(0.59, 1.399, 0.83),
		Vector3(-0.59, 1.399, 0.83)
	]
	_poly(root, "ClosedCabin", cabin, _box_faces(), Color("707c68"), live)
	# Four independent solid wedges make a real depressed hood centre. The
	# visible dent and collision have the same inward crease, never a flat proxy.
	var corners: PackedVector3Array = [
		Vector3(-0.68, 0.755, -1.73),
		Vector3(0.68, 0.775, -1.73),
		Vector3(0.72, 0.79, -0.79),
		Vector3(-0.72, 0.79, -0.79)
	]
	var dent: Vector3 = Vector3(-0.18, 0.714, -1.26)
	for index in range(4):
		var a: Vector3 = corners[index]
		var b: Vector3 = corners[(index + 1) % 4]
		var points: PackedVector3Array = [
			a,
			b,
			dent,
			Vector3(a.x, 0.70, a.z),
			Vector3(b.x, 0.70, b.z),
			Vector3(dent.x, 0.70, dent.z)
		]
		_poly(
			root,
			"DentedHood%d" % index,
			points,
			[[0, 1, 2], [3, 5, 4], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]],
			[Color("717b60"), PAINT, Color("586756"), RUST][index],
			live
		)
	_box(
		root, "RearDeck", Vector3(0, 0.735, 1.65), Vector3(1.30, 0.07, 0.28), Color("68715a"), live
	)
	# Both crossmembers touch ground: visibly collapsed suspension, and a real
	# physical stop closes fore/aft paths beneath the car. Side mouths stay open.
	for axle in range(2):
		var z: float = -1.18 if axle == 0 else 1.18
		_box(
			root,
			"GroundedAxle%d" % axle,
			Vector3(0, 0.14, z),
			Vector3(1.48, 0.28, 0.30),
			Color("3b3b31"),
			live
		)
	_box(
		root,
		"FrontBumper",
		Vector3(0, 0.365, -1.86),
		Vector3(1.45, 0.11, 0.08),
		Color("83887a"),
		live
	)
	_box(
		root, "RearBumper", Vector3(0, 0.35, 1.86), Vector3(1.40, 0.10, 0.08), Color("756f5b"), live
	)


static func _wheels(root: Node3D, live: bool) -> void:
	for side in range(2):
		var sign_side: float = -1.0 if side == 0 else 1.0
		for axle in range(2):
			var z: float = -1.18 if axle == 0 else 1.18
			var suffix: String = (
				"%s_%s" % ["L" if side == 0 else "R", "Front" if axle == 0 else "Rear"]
			)
			var points: PackedVector3Array = []
			for x: float in [sign_side * 0.70, sign_side * 0.847]:
				for index in range(WHEEL_SEGMENTS):
					var angle: float = TAU * index / WHEEL_SEGMENTS
					points.append(
						Vector3(x, maxf(0, 0.225 + cos(angle) * 0.275), z + sin(angle) * 0.32)
					)
			_poly(
				root,
				"FlatTire_" + suffix,
				points,
				_ring_faces(WHEEL_SEGMENTS),
				Color("30342e"),
				live
			)
			# Missing hubcaps, dull rust hubs, five dark holes and flattened sidewalls.
			_disc(
				root,
				"BareHub_" + suffix,
				Vector3(sign_side * 0.851 - sign_side * 0.003, 0.235, z),
				Vector3(sign_side, 0, 0),
				0.14,
				RUST,
				12
			)
			for hole in range(5):
				var angle: float = TAU * hole / 5.0 + axle * 0.19
				_disc(
					root,
					"HubHole_%s_%d" % [suffix, hole],
					Vector3(sign_side * 0.849, 0.235 + cos(angle) * 0.087, z + sin(angle) * 0.087),
					Vector3(sign_side, 0, 0),
					0.026,
					Color("35372e"),
					7
				)
			_disc(
				root,
				"HubNut_" + suffix,
				Vector3(sign_side * 0.85, 0.235, z),
				Vector3(sign_side, 0, 0),
				0.030,
				Color("b09b73"),
				6
			)


static func _details(root: Node3D) -> void:
	# All glass is opaque and closed. Windshield and rear hatch match cabin slopes.
	_patch(
		root,
		"ClosedWindshield",
		[
			Vector3(-0.650, 0.81, -0.702),
			Vector3(0.650, 0.81, -0.702),
			Vector3(0.548, 1.32, -0.330),
			Vector3(-0.548, 1.32, -0.330)
		],
		GLASS,
		Vector3(0, 0.6, -1)
	)
	_patch(
		root,
		"ClosedRearGlass",
		[
			Vector3(-0.550, 1.32, 0.907),
			Vector3(0.550, 1.32, 0.907),
			Vector3(0.665, 0.81, 1.382),
			Vector3(-0.665, 0.81, 1.382)
		],
		Color("42534b"),
		Vector3(0, 0.6, 1)
	)
	for side in range(2):
		var s: float = -1.0 if side == 0 else 1.0
		var suffix: String = "L" if side == 0 else "R"
		_patch(
			root,
			"ClosedDoorGlass_" + suffix,
			[
				Vector3(s * 0.710, 0.81, -0.65),
				Vector3(s * 0.710, 0.81, 0.30),
				Vector3(s * 0.612, 1.30, 0.30),
				Vector3(s * 0.612, 1.30, -0.27)
			],
			GLASS,
			Vector3(s, 0.2, 0)
		)
		_patch(
			root,
			"ClosedQuarterGlass_" + suffix,
			[
				Vector3(s * 0.710, 0.81, 0.40),
				Vector3(s * 0.710, 0.81, 1.30),
				Vector3(s * 0.612, 1.30, 0.82),
				Vector3(s * 0.612, 1.30, 0.40)
			],
			Color("3c514b"),
			Vector3(s, 0.2, 0)
		)
		_box(
			root,
			"ClosedDoorSeam_" + suffix,
			Vector3(s * 0.792, 0.49, 0.35),
			Vector3(0.003, 0.35, 0.012),
			DARK_RUST,
			false
		)
		_box(
			root,
			"DoorHandle_" + suffix,
			Vector3(s * 0.799, 0.64, 0.18),
			Vector3(0.015, 0.035, 0.16),
			Color("aaa28a"),
			false
		)
		for patch in range(5):
			var z: float = -0.72 + patch * 0.33
			var y: float = 0.36 + (patch % 3) * 0.09
			_patch(
				root,
				"RustFlake_%s_%d" % [suffix, patch],
				[
					Vector3(s * 0.794, y, z - 0.11),
					Vector3(s * 0.794, y - 0.025, z + 0.08),
					Vector3(s * 0.794, y + 0.05, z + 0.14),
					Vector3(s * 0.794, y + 0.095, z + 0.03),
					Vector3(s * 0.794, y + 0.07, z - 0.13)
				],
				RUST if patch % 2 == 0 else DARK_RUST,
				Vector3(s, 0, 0)
			)
		_box(
			root,
			"RustedSill_" + suffix,
			Vector3(s * 0.793, 0.297, 0),
			Vector3(0.007, 0.030, 1.58),
			Color("805138"),
			false
		)
		# Sealed cloudy headlight on one side, dark missing lens on the other.
		_box(
			root,
			"Headlight_" + suffix,
			Vector3(s * 0.48, 0.575, -1.824),
			Vector3(0.27, 0.13, 0.006),
			Color("c2baa0") if side == 0 else Color("292f2b"),
			false
		)
		_box(
			root,
			"TailLight_" + suffix,
			Vector3(s * 0.47, 0.565, 1.824),
			Vector3(0.23, 0.12, 0.006),
			Color("80473b"),
			false
		)
	_box(
		root,
		"SunkenGrille",
		Vector3(0, 0.515, -1.826),
		Vector3(0.54, 0.14, 0.006),
		Color("333b32"),
		false
	)
	for index in range(5):
		_box(
			root,
			"GrilleSlat%d" % index,
			Vector3(-0.22 + index * 0.11, 0.515, -1.831),
			Vector3(0.014, 0.13, 0.006),
			Color("8a8369"),
			false
		)
	_box(
		root,
		"BlankRearPlate",
		Vector3(0, 0.525, 1.828),
		Vector3(0.38, 0.11, 0.004),
		Color("b1a482"),
		false
	)
	_patch(
		root,
		"RoofRustIsland",
		[
			Vector3(-0.42, 1.40, 0.12),
			Vector3(-0.17, 1.40, 0.08),
			Vector3(0.07, 1.40, 0.25),
			Vector3(-0.04, 1.40, 0.44),
			Vector3(-0.36, 1.40, 0.40)
		],
		RUST,
		Vector3.UP
	)


static func _box(
	root: Node3D, id: String, center: Vector3, size: Vector3, color: Color, physical: bool
) -> void:
	var points: PackedVector3Array = []
	for vertex: Vector3 in [
		Vector3(-1, -1, -1),
		Vector3(1, -1, -1),
		Vector3(1, -1, 1),
		Vector3(-1, -1, 1),
		Vector3(-1, 1, -1),
		Vector3(1, 1, -1),
		Vector3(1, 1, 1),
		Vector3(-1, 1, 1)
	]:
		points.append(center + vertex * size / 2.0)
	_poly(root, id, points, _box_faces(), color, physical)


static func _box_faces() -> Array:
	return [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]


static func _ring_faces(count: int) -> Array:
	var faces: Array = [range(count), range(count, count * 2)]
	for index in range(count):
		var next: int = (index + 1) % count
		faces.append([index, next, next + count, index + count])
	return faces


static func _prism(
	root: Node3D,
	id: String,
	footprint: PackedVector2Array,
	low: float,
	high: float,
	color: Color,
	physical: bool
) -> void:
	var points: PackedVector3Array = []
	for y: float in [low, high]:
		for point: Vector2 in footprint:
			points.append(Vector3(point.x, y, point.y))
	_poly(root, id, points, _ring_faces(footprint.size()), color, physical)


static func _poly(
	root: Node3D, id: String, points: PackedVector3Array, faces: Array, color: Color, physical: bool
) -> void:
	var center: Vector3 = Vector3.ZERO
	for point: Vector3 in points:
		center += point
	center /= points.size()
	var triangles: PackedVector3Array = []
	for face: Array in faces:
		for index in range(1, face.size() - 1):
			var a: Vector3 = points[face[0]]
			var b: Vector3 = points[face[index]]
			var c: Vector3 = points[face[index + 1]]
			_triangle(triangles, a, b, c, (a + b + c) / 3.0 - center)
	_mesh(root, id, triangles, color)
	if physical:
		var collider: CollisionShape3D = CollisionShape3D.new()
		collider.name = id
		var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		shape.points = points
		shape.margin = 0.0
		collider.shape = shape
		root.get_node("Collision/" + SURFACE).add_child(collider)


static func _disc(
	root: Node3D,
	id: String,
	center: Vector3,
	normal: Vector3,
	radius: float,
	color: Color,
	segments: int
) -> void:
	var points: PackedVector3Array = []
	for index in range(segments):
		var angle: float = TAU * index / segments
		points.append(center + Vector3(0, cos(angle), sin(angle)) * radius)
	_patch(root, id, points, color, normal)


static func _patch(
	root: Node3D, id: String, points: PackedVector3Array, color: Color, normal: Vector3
) -> void:
	var triangles: PackedVector3Array = []
	for index in range(1, points.size() - 1):
		_triangle(triangles, points[0], points[index], points[index + 1], normal)
	_mesh(root, id, triangles, color)


static func _triangle(
	faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, outward: Vector3
) -> void:
	var normal: Vector3 = -(b - a).cross(c - a)
	if normal.length_squared() < 0.000000000001:
		return
	faces.append_array(
		PackedVector3Array([a, c, b]) if normal.dot(outward) < 0 else PackedVector3Array([a, b, c])
	)


static func _mesh(root: Node3D, id: String, points: PackedVector3Array, color: Color) -> void:
	var normals: PackedVector3Array = []
	for index in range(0, points.size(), 3):
		var normal: Vector3 = -(
			(points[index + 1] - points[index])
			. cross(points[index + 2] - points[index])
			. normalized()
		)
		for vertex in range(3):
			normals.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(range(points.size()))
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.91
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = id
	instance.mesh = mesh
	instance.material_override = material
	root.get_node("Visual").add_child(instance)
