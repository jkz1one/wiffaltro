class_name StadiumGroundPropsModels
extends RefCounted
## Fixed owned yard props. BL/BN reservations and BS live surfaces share the same art.
## Plant assemblies are scenery with no collision. Closed rigid props contain no trap volumes.

const VERSION: int = 1
const IDS: Array[String] = [
	"ST-004", "ST-008", "ST-009", "ST-010", "ST-011", "ST-012", "ST-015", "ST-016", "ST-017"
]
const LIVE: String = "LIVE_RICOCHET"


static func create(id: String) -> Node3D:
	if id not in IDS:
		return null
	var root: Node3D = Node3D.new()
	root.name = id.replace("-", "")
	root.set_meta("stadium_item", id)
	root.set_meta("geometry_version", VERSION)
	for name: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = name
		root.add_child(child)
	match id:
		"ST-004":
			_mower(root)
		"ST-008":
			_bbq(root)
		"ST-009":
			_cooler(root)
		"ST-010":
			_table(root)
		"ST-011":
			_umbrella(root)
		"ST-012":
			_shed(root)
		"ST-015":
			_fern(root)
		"ST-016":
			_flowers(root)
		"ST-017":
			_bed(root)
	return root


static func envelope(id: String) -> AABB:
	match id:
		"ST-004":
			return AABB(Vector3(-0.42, 0, -0.44), Vector3(0.84, 1.10, 1.28))
		"ST-008", "ST-009":
			return AABB(Vector3(-0.48, 0, -0.48), Vector3(0.96, 1.25, 0.96))
		"ST-010":
			return AABB(Vector3(-1.10, 0, -0.90), Vector3(2.20, 1.0, 1.80))
		"ST-011":
			return AABB(Vector3(-1.75, 0, -1.75), Vector3(3.50, 2.85, 3.50))
		"ST-012":
			return AABB(Vector3(-2.0, 0, -1.75), Vector3(4.0, 3.50, 3.50))
		"ST-015", "ST-016":
			return AABB(Vector3(-0.75, 0, -0.75), Vector3(1.50, 1.25, 1.50))
		"ST-017":
			return AABB(Vector3(-0.80, 0, -2.25), Vector3(1.60, 1.0, 4.50))
	return AABB()


static func surfaces(id: String) -> Array[String]:
	var result: Array[String] = []
	match id:
		"ST-004":
			result.assign(["MOWER_DECK", "MOWER_ENGINE", "MOWER_HANDLE_GRIP"])
			for side: String in ["L", "R"]:
				result.append("MOWER_HANDLE_" + side)
				for axle: String in ["FRONT", "REAR"]:
					result.append("MOWER_WHEEL_%s_%s" % [side, axle])
		"ST-008":
			result.assign(["BBQ_KETTLE", "BBQ_LID_HANDLE", "BBQ_LID_POST_L", "BBQ_LID_POST_R"])
			for index in range(3):
				result.append("BBQ_LEG%d" % index)
				result.append("BBQ_FOOT%d" % index)
		"ST-009":
			result.assign(["COOLER_BODY", "COOLER_LID", "COOLER_HANDLE_L", "COOLER_HANDLE_R"])
		"ST-010":
			result.assign(["TABLE_TOP", "TABLE_BENCH_L", "TABLE_BENCH_R", "TABLE_LONG_BRACE"])
			for end in range(2):
				result.append("TABLE_BENCH_RAIL%d" % end)
				for side: String in ["L", "R"]:
					result.append("TABLE_LEG_%d_%s" % [end, side])
					result.append("TABLE_FOOT_%d_%s" % [end, side])
		"ST-011":
			result.assign(["UMBRELLA_BASE", "UMBRELLA_POLE", "UMBRELLA_TOP_CAP"])
			for index in range(8):
				result.append("UMBRELLA_CANOPY%d" % index)
		"ST-012":
			result.assign(["SHED_BODY", "SHED_ROOF"])
	return result


static func _mower(root: Node3D) -> void:
	_box(root, "MOWER_DECK", Vector3(0, 0.235, 0), Vector3(0.62, 0.13, 0.72), Color("567965"))
	_box(root, "MOWER_ENGINE", Vector3(0, 0.39, -0.07), Vector3(0.34, 0.22, 0.34), Color("424b47"))
	_cylinder(
		root, "EngineStarterCap", Vector3(0, 0.51, -0.07), 0.12, 0.025, Color("273633"), false
	)
	for stripe in range(4):
		_art_box(
			root,
			"EngineVent%d" % stripe,
			Vector3(-0.105 + stripe * 0.07, 0.405, -0.244),
			Vector3(0.025, 0.12, 0.009),
			Color("182b28")
		)
	for side in range(2):
		var sign_side: float = -1.0 if side == 0 else 1.0
		var suffix: String = "L" if side == 0 else "R"
		for axle in range(2):
			var z: float = -0.27 if axle == 0 else 0.27
			var name: String = "MOWER_WHEEL_%s_%s" % [suffix, "FRONT" if axle == 0 else "REAR"]
			_cylinder(root, name, Vector3(sign_side * 0.34, 0.14, z), 0.14, 0.10, Color("28312e"))
			_rotate_part(root, name, Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK))
			_cylinder(
				root,
				"Hub_%s_%d" % [suffix, axle],
				Vector3(sign_side * 0.394, 0.14, z),
				0.055,
				0.012,
				Color("a9b0a1"),
				false
			)
			root.get_node("Visual/Hub_%s_%d" % [suffix, axle]).basis = Basis(
				Vector3.DOWN, Vector3.RIGHT, Vector3.BACK
			)
		_beam(
			root,
			"MOWER_HANDLE_" + suffix,
			Vector3(sign_side * 0.23, 0.31, 0.23),
			Vector3(sign_side * 0.27, 1.01, 0.77),
			0.04,
			Color("a8aca0")
		)
	_beam(
		root,
		"MOWER_HANDLE_GRIP",
		Vector3(-0.30, 1.01, 0.77),
		Vector3(0.30, 1.01, 0.77),
		0.06,
		Color("2e3832")
	)
	_art_box(
		root, "DeckWear", Vector3(-0.21, 0.303, -0.18), Vector3(0.11, 0.007, 0.10), Color("936b48")
	)


static func _bbq(root: Node3D) -> void:
	_ellipsoid(
		root, "BBQ_KETTLE", Vector3(0, 0.72, 0), Vector3(0.34, 0.30, 0.34), Color("343b39"), true
	)
	_cylinder(root, "LidSeam", Vector3(0, 0.78, 0), 0.334, 0.012, Color("90988d"), false)
	for side in range(2):
		var x: float = -0.08 if side == 0 else 0.08
		_box(
			root,
			"BBQ_LID_POST_" + ("L" if side == 0 else "R"),
			Vector3(x, 1.055, 0),
			Vector3(0.025, 0.10, 0.025),
			Color("a1a89a")
		)
	_box(root, "BBQ_LID_HANDLE", Vector3(0, 1.115, 0), Vector3(0.22, 0.045, 0.055), Color("704b32"))
	for index in range(3):
		var angle: float = TAU * index / 3.0 + PI / 2.0
		var radial: Vector3 = Vector3(cos(angle), 0, sin(angle))
		_beam(
			root,
			"BBQ_LEG%d" % index,
			radial * 0.28 + Vector3(0, 0.035, 0),
			radial * 0.17 + Vector3(0, 0.52, 0),
			0.035,
			Color("a1a99c")
		)
		_cylinder(
			root,
			"BBQ_FOOT%d" % index,
			radial * 0.28 + Vector3(0, 0.02, 0),
			0.055,
			0.04,
			Color("333b34")
		)
		var phi: float = -0.35 + index * 0.35
		var point: Vector3 = Vector3(
			0.34 * sin(0.52) * cos(phi), 0.72 + 0.30 * cos(0.52), 0.34 * sin(0.52) * sin(phi)
		)
		var normal: Vector3 = (
			Vector3(
				point.x / (0.34 * 0.34), (point.y - 0.72) / (0.30 * 0.30), point.z / (0.34 * 0.34)
			)
			. normalized()
		)
		_cylinder(
			root, "LidVent%d" % index, point + normal * 0.002, 0.015, 0.003, Color("131d1b"), false
		)
		root.get_node("Visual/LidVent%d" % index).quaternion = Quaternion(Vector3.UP, normal)


static func _cooler(root: Node3D) -> void:
	_box(root, "COOLER_BODY", Vector3(0, 0.24, 0), Vector3(0.76, 0.48, 0.46), Color("b74842"))
	_box(root, "COOLER_LID", Vector3(0, 0.515, 0), Vector3(0.79, 0.07, 0.49), Color("e3dfcc"))
	for side in range(2):
		var x: float = -0.42 if side == 0 else 0.42
		_box(
			root,
			"COOLER_HANDLE_" + ("L" if side == 0 else "R"),
			Vector3(x, 0.35, 0),
			Vector3(0.06, 0.10, 0.26),
			Color("dedcc7")
		)
	_art_box(
		root,
		"CoolerFrontRidge",
		Vector3(0, 0.405, 0.234),
		Vector3(0.67, 0.018, 0.009),
		Color("d97866")
	)
	_art_box(
		root, "CoolerLatch", Vector3(0, 0.47, 0.251), Vector3(0.075, 0.095, 0.018), Color("e2dfc9")
	)
	_art_box(
		root, "CoolerInset", Vector3(0, 0.25, 0.233), Vector3(0.32, 0.13, 0.008), Color("a63e3b")
	)


static func _table(root: Node3D) -> void:
	var wood: Color = Color("9f7850")
	_box(root, "TABLE_TOP", Vector3(0, 0.82, 0), Vector3(2.10, 0.10, 0.80), wood)
	for side in range(2):
		var z: float = -0.68 if side == 0 else 0.68
		_box(
			root,
			"TABLE_BENCH_" + ("L" if side == 0 else "R"),
			Vector3(0, 0.46, z),
			Vector3(2.10, 0.08, 0.30),
			Color("b28a5b")
		)
	for end in range(2):
		var x: float = -0.72 if end == 0 else 0.72
		_box(
			root,
			"TABLE_BENCH_RAIL%d" % end,
			Vector3(x, 0.39, 0),
			Vector3(0.10, 0.10, 1.60),
			Color("78583b")
		)
		for side in range(2):
			var sign_side: float = -1.0 if side == 0 else 1.0
			var suffix: String = "%d_%s" % [end, "L" if side == 0 else "R"]
			_beam(
				root,
				"TABLE_LEG_" + suffix,
				Vector3(x, 0.05, sign_side * 0.62),
				Vector3(x, 0.78, sign_side * 0.22),
				0.10,
				Color("82613f")
			)
			_box(
				root,
				"TABLE_FOOT_" + suffix,
				Vector3(x, 0.025, sign_side * 0.64),
				Vector3(0.18, 0.05, 0.22),
				Color("664e37")
			)
	_box(root, "TABLE_LONG_BRACE", Vector3(0, 0.33, 0), Vector3(1.50, 0.10, 0.10), Color("725236"))
	for seam in range(3):
		_art_box(
			root,
			"TopPlankJoint%d" % seam,
			Vector3(0, 0.871, -0.20 + seam * 0.20),
			Vector3(2.06, 0.002, 0.008),
			Color("5f4936")
		)
	for x: float in [-0.72, 0.72]:
		for z: float in [-0.30, 0.30]:
			_cylinder(
				root,
				"TopBolt_%s_%s" % [x, z],
				Vector3(x, 0.874, z),
				0.017,
				0.006,
				Color("756c5b"),
				false
			)


static func _umbrella(root: Node3D) -> void:
	_cylinder(root, "UMBRELLA_BASE", Vector3(0, 0.05, 0), 0.28, 0.10, Color("646f65"))
	_cylinder(root, "UMBRELLA_POLE", Vector3(0, 1.395, 0), 0.035, 2.69, Color("d4c7a4"))
	for index in range(8):
		var a: float = TAU * index / 8.0
		var b: float = TAU * (index + 1) / 8.0
		var first: Vector3 = Vector3(cos(a) * 1.65, 2.35, sin(a) * 1.65)
		var second: Vector3 = Vector3(cos(b) * 1.65, 2.35, sin(b) * 1.65)
		var points: PackedVector3Array = [
			Vector3(0, 2.78, 0),
			first,
			second,
			Vector3(0, 2.73, 0),
			first - Vector3(0, 0.05, 0),
			second - Vector3(0, 0.05, 0)
		]
		_convex(
			root,
			"UMBRELLA_CANOPY%d" % index,
			points,
			[[0, 1, 2], [3, 5, 4], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]],
			Color("c35e4d") if index % 2 == 0 else Color("e7ddbd")
		)
	_cylinder(root, "UMBRELLA_TOP_CAP", Vector3(0, 2.78, 0), 0.06, 0.08, Color("c0b18b"))


static func _shed(root: Node3D) -> void:
	_box(root, "SHED_BODY", Vector3(0, 1.10, 0), Vector3(3.0, 2.20, 2.40), Color("78664e"))
	var points: PackedVector3Array = [
		Vector3(-1.60, 2.15, -1.30),
		Vector3(0, 2.80, -1.30),
		Vector3(1.60, 2.15, -1.30),
		Vector3(-1.60, 2.15, 1.30),
		Vector3(0, 2.80, 1.30),
		Vector3(1.60, 2.15, 1.30)
	]
	_convex(
		root,
		"SHED_ROOF",
		points,
		[[0, 1, 2], [3, 5, 4], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]],
		Color("505d55")
	)
	for plank in range(15):
		var x: float = -1.40 + plank * 0.20
		var color: Color = Color("948064") if plank % 3 == 0 else Color("85715a")
		for face in [-1, 1]:
			_art_box(
				root,
				"EndPlank_%d_%d" % [face, plank],
				Vector3(x, 1.08, face * 1.205),
				Vector3(0.184, 2.14, 0.016),
				color
			)
	for plank in range(12):
		var z: float = -1.10 + plank * 0.20
		for side in [-1, 1]:
			_art_box(
				root,
				"SidePlank_%d_%d" % [side, plank],
				Vector3(side * 1.505, 1.08, z),
				Vector3(0.016, 2.14, 0.184),
				Color("89775e") if plank % 3 else Color("75664f")
			)
	_art_box(
		root, "ClosedDoor", Vector3(-0.55, 0.94, 1.225), Vector3(0.88, 1.86, 0.026), Color("665a43")
	)
	for y: float in [0.22, 1.65]:
		_art_box(
			root,
			"DoorBrace%s" % y,
			Vector3(-0.55, y, 1.246),
			Vector3(0.82, 0.075, 0.016),
			Color("a38b68")
		)
	_art_box(
		root,
		"DoorHandle",
		Vector3(-0.22, 0.96, 1.265),
		Vector3(0.035, 0.15, 0.024),
		Color("343e36")
	)
	_art_box(
		root,
		"ClosedWindowFrame",
		Vector3(0.70, 1.48, 1.225),
		Vector3(0.72, 0.60, 0.032),
		Color("c4b594")
	)
	_art_box(
		root,
		"ClosedWindow",
		Vector3(0.70, 1.48, 1.245),
		Vector3(0.60, 0.48, 0.012),
		Color("617a77")
	)
	_art_box(
		root,
		"WindowMullion",
		Vector3(0.70, 1.48, 1.257),
		Vector3(0.035, 0.51, 0.014),
		Color("c4b594")
	)


static func _fern(root: Node3D) -> void:
	var pot: CylinderMesh = CylinderMesh.new()
	pot.bottom_radius = 0.17
	pot.top_radius = 0.25
	pot.height = 0.34
	pot.radial_segments = 20
	StadiumStarterModels._mesh(root, "FernPot", Vector3(0, 0.17, 0), pot, Color("a86540"))
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 0.225
	rim.outer_radius = 0.26
	rim.rings = 20
	rim.ring_segments = 8
	StadiumStarterModels._mesh(root, "FernPotRim", Vector3(0, 0.34, 0), rim, Color("bd7951"))
	_cylinder(root, "FernSoil", Vector3(0, 0.334, 0), 0.224, 0.012, Color("4b3c2e"), false)
	for frond in range(8):
		var angle: float = TAU * frond / 8.0
		var radial: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var tangent: Vector3 = Vector3(-sin(angle), 0, cos(angle))
		var previous: Vector3 = Vector3(0, 0.34, 0)
		for step in range(1, 6):
			var t: float = step / 5.0
			var point: Vector3 = radial * (0.55 * t) + Vector3(0, 0.34 + 0.90 * t - 0.34 * t * t, 0)
			_art_beam(root, "Frond_%d_%d" % [frond, step], previous, point, 0.012, Color("406337"))
			if step < 5:
				for side in [-1, 1]:
					var tip: Vector3 = (
						point
						+ tangent * side * (0.17 * (1.0 - t * 0.55))
						+ radial * 0.05
						+ Vector3(0, 0.045, 0)
					)
					_leaf(
						root,
						"FernLeaf_%d_%d_%d" % [frond, step, side],
						point,
						tip,
						0.032,
						Color("658445") if frond % 2 == 0 else Color("3f713d")
					)
			previous = point


static func _flowers(root: Node3D) -> void:
	for index in range(9):
		var angle: float = TAU * index / 9.0
		var radius: float = 0.10 if index == 0 else 0.36 + 0.04 * (index % 2)
		var base: Vector3 = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		_ellipsoid(
			root,
			"FlowerSoil%d" % index,
			base + Vector3(0, 0.025, 0),
			Vector3(0.14, 0.025, 0.14),
			Color("5e6040"),
			false
		)
		_bloom(
			root,
			"Wildflower%d" % index,
			base + Vector3(0, 0.025, 0),
			0.48 + 0.10 * (index % 4),
			(
				Color("e5cb56")
				if index % 3 == 0
				else (Color("d494ad") if index % 3 == 1 else Color("eee5c9"))
			)
		)


static func _bed(root: Node3D) -> void:
	var timber: Color = Color("9b7550")
	_art_box(root, "BedBase", Vector3(0, 0.025, 0), Vector3(1.20, 0.05, 3.80), Color("66503a"))
	for side in [-1, 1]:
		_art_box(
			root,
			"BedSide%d" % side,
			Vector3(side * 0.55, 0.18, 0),
			Vector3(0.10, 0.30, 3.80),
			timber
		)
		_art_box(
			root, "BedEnd%d" % side, Vector3(0, 0.18, side * 1.85), Vector3(1.0, 0.30, 0.10), timber
		)
		for end in [-1, 1]:
			_art_box(
				root,
				"BedPost%d_%d" % [side, end],
				Vector3(side * 0.56, 0.18, end * 1.86),
				Vector3(0.08, 0.36, 0.08),
				Color("795c40")
			)
	_art_box(root, "BedSoil", Vector3(0, 0.18, 0), Vector3(1.0, 0.12, 3.60), Color("514331"))
	for index in range(12):
		var x: float = -0.30 if index % 2 == 0 else 0.30
		var z: float = -1.48 + floori(index / 2.0) * 0.59
		_bloom(
			root,
			"BedFlower%d" % index,
			Vector3(x, 0.24, z),
			0.31 + 0.035 * (index % 4),
			Color("d29bba") if index % 2 == 0 else Color("e4c762")
		)


static func _bloom(root: Node3D, id: String, base: Vector3, height: float, color: Color) -> void:
	var top: Vector3 = base + Vector3(0, height, 0)
	_art_beam(root, id + "Stem", base, top, 0.012, Color("53763d"))
	for side in [-1, 1]:
		var point: Vector3 = base + Vector3(0, height * 0.48, 0)
		_leaf(
			root,
			id + "Leaf%d" % side,
			point,
			point + Vector3(side * 0.12, 0.07, 0.035),
			0.035,
			Color("6b8746")
		)
	for petal in range(5):
		var angle: float = TAU * petal / 5.0
		_ellipsoid(
			root,
			id + "Petal%d" % petal,
			top + Vector3(cos(angle) * 0.045, 0, sin(angle) * 0.045),
			Vector3(0.037, 0.016, 0.037),
			color,
			false
		)
	_ellipsoid(
		root,
		id + "Center",
		top + Vector3(0, 0.012, 0),
		Vector3(0.026, 0.020, 0.026),
		Color("a98337"),
		false
	)


static func _leaf(
	root: Node3D, id: String, start: Vector3, end: Vector3, width: float, color: Color
) -> void:
	var along: Vector3 = (end - start).normalized()
	var across: Vector3 = along.cross(Vector3.UP).normalized() * width
	var middle: Vector3 = start.lerp(end, 0.48)
	var points: PackedVector3Array = [
		start,
		middle + across,
		end,
		middle - across,
		middle + Vector3(0, 0.012, 0),
		middle - Vector3(0, 0.004, 0)
	]
	var mesh: ArrayMesh = _poly_mesh(
		points,
		[[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4], [1, 0, 5], [2, 1, 5], [3, 2, 5], [0, 3, 5]]
	)
	StadiumStarterModels._mesh(root, id, Vector3.ZERO, mesh, color)


static func _box(root: Node3D, id: String, center: Vector3, size: Vector3, color: Color) -> void:
	StadiumStarterModels._box(root, id, center, size, color, LIVE)


static func _art_box(
	root: Node3D, id: String, center: Vector3, size: Vector3, color: Color
) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	StadiumStarterModels._mesh(root, id, center, mesh, color)


static func _beam(
	root: Node3D, id: String, start: Vector3, end: Vector3, width: float, color: Color
) -> void:
	StadiumStarterModels._segment(root, id, start, end, width, color)


static func _art_beam(
	root: Node3D, id: String, start: Vector3, end: Vector3, width: float, color: Color
) -> void:
	_art_box(root, id, (start + end) * 0.5, Vector3(width, start.distance_to(end), width), color)
	root.get_node("Visual/" + id).quaternion = Quaternion(Vector3.UP, (end - start).normalized())


static func _cylinder(
	root: Node3D,
	id: String,
	center: Vector3,
	radius: float,
	height: float,
	color: Color,
	physical: bool = true
) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	if physical:
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		StadiumStarterModels._part(root, id, center, mesh, shape, color, LIVE)
	else:
		StadiumStarterModels._mesh(root, id, center, mesh, color)


static func _rotate_part(root: Node3D, id: String, rotation: Basis) -> void:
	root.get_node("Visual/" + id).basis = rotation
	root.get_node("Collision/" + id).basis = rotation


static func _ellipsoid(
	root: Node3D, id: String, center: Vector3, radii: Vector3, color: Color, physical: bool
) -> void:
	if not physical:
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 12
		mesh.rings = 6
		StadiumStarterModels._mesh(root, id, center, mesh, color)
		root.get_node("Visual/" + id).scale = radii
		return
	var points: PackedVector3Array = []
	var faces: Array = []
	for ring in range(13):
		var theta: float = PI * ring / 12.0
		for slice in range(24):
			var phi: float = TAU * slice / 24.0
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
	for ring in range(12):
		for slice in range(24):
			var next: int = (slice + 1) % 24
			faces.append(
				[
					ring * 24 + slice,
					ring * 24 + next,
					(ring + 1) * 24 + next,
					(ring + 1) * 24 + slice
				]
			)
	_convex(root, id, points, faces, color)


static func _convex(
	root: Node3D, id: String, points: PackedVector3Array, faces: Array, color: Color
) -> void:
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = points
	StadiumStarterModels._part(
		root, id, Vector3.ZERO, _poly_mesh(points, faces), shape, color, LIVE
	)


static func _poly_mesh(points: PackedVector3Array, faces: Array) -> ArrayMesh:
	var center: Vector3 = Vector3.ZERO
	for point: Vector3 in points:
		center += point
	center /= points.size()
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in faces:
		for index in range(1, face.size() - 1):
			var a: Vector3 = points[face[0]]
			var b: Vector3 = points[face[index]]
			var c: Vector3 = points[face[index + 1]]
			var normal: Vector3 = -(b - a).cross(c - a)
			if normal.length_squared() <= 1e-16:
				continue
			if normal.dot((a + b + c) / 3.0 - center) < 0.0:
				var swap: Vector3 = b
				b = c
				c = swap
				normal = -normal
			normal = normal.normalized()
			for point: Vector3 in [a, b, c]:
				surface.set_normal(normal)
				surface.add_vertex(point)
	surface.index()
	return surface.commit()
