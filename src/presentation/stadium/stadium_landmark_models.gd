class_name StadiumLandmarkModels
extends RefCounted
## Three complete static off-field landmarks. All geometry is authored in metres.
## The perforated shell is genuinely open; water is bounded static artwork only.

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-048", "ST-049", "ST-050"]
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const ENVELOPES: Dictionary = {
	"ST-048": AABB(Vector3(-2.5, 0, -2.5), Vector3(5, 5, 5)),
	"ST-049": AABB(Vector3(-2, 0, -2), Vector3(4, 7, 4)),
	"ST-050": AABB(Vector3(-3, 0, -3), Vector3(6, 5, 6))
}
const VISIBLE: Dictionary = {
	"ST-048": AABB(Vector3(-2.3, 0, -2.3), Vector3(4.6, 5, 4.6)),
	"ST-049": AABB(Vector3(-1.9, 0, -1.9), Vector3(3.8, 7, 3.8)),
	"ST-050": AABB(Vector3(-3, 0, -3), Vector3(6, 5, 6))
}
const MESH_COUNTS: Dictionary = {"ST-048": 4, "ST-049": 52, "ST-050": 49}
const SOLID_COUNTS: Dictionary = {"ST-048": 3, "ST-049": 52, "ST-050": 46}
const PRISM_FACES: Array = [
	[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]
]
const BALL_CENTER: Vector3 = Vector3(0, 2.7, 0)
const BALL_RADIUS: float = 2.3
const SHELL_THICKNESS: float = 0.10
const HOLE_COUNT: int = 8
const HOLE_THETA: float = 0.95
const HOLE_THETA_RADIUS: float = 0.37
const HOLE_PHI_RADIUS: float = 0.18
const STONE: Color = Color("777c79")
const STONE_EDGE: Color = Color("b0b0a0")
const WHITE: Color = Color("f5f3df")
const STEEL: Color = Color("7d898f")
const DARK_STEEL: Color = Color("424e55")
const RUST: Color = Color("a66642")
const BRASS: Color = Color("be9650")
const TIKI_WOOD: Color = Color("90613f")
const TIKI_EDGE: Color = Color("c0945e")
const TIKI_DARK: Color = Color("47362d")
const WATER: Color = Color("429ca8")


static func create(item: String) -> Node3D:
	if item not in ITEMS:
		return null
	var root: Node3D = Node3D.new()
	root.name = {
		"ST-048": "ST048WiffleBallSculpture",
		"ST-049": "ST049PitchingRobotStatue",
		"ST-050": "ST050TikiFountain"
	}[item]
	root.set_meta("stadium_item", item)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("final_art_accepted", false)
	root.set_meta("envelope", envelope(item))
	root.set_meta("visible_bounds", visible_bounds(item))
	root.set_meta("static_geometry", true)
	root.set_meta("scenery_only", true)
	root.set_meta("surface_role", ROLE)
	root.set_meta("physics_profile", ROLE)
	root.set_meta("obstacle_units", 0)
	root.set_meta("ambient_ball_count", 0)
	root.set_meta("animated_during_pitch", false)
	root.set_meta("water_entry_enabled", false)
	root.set_meta("ball_award_enabled", false)
	for id: String in ["Visual", "Collision"]:
		var branch: Node3D = Node3D.new()
		branch.name = id
		root.add_child(branch)
	match item:
		"ST-048":
			_sculpture(root)
		"ST-049":
			_robot(root)
		"ST-050":
			_tiki(root)
	return root


static func envelope(item: String) -> AABB:
	return ENVELOPES.get(item, AABB())


static func visible_bounds(item: String) -> AABB:
	return VISIBLE.get(item, AABB())


static func bounds(item: String) -> AABB:
	return envelope(item)


static func mesh_count(item: String) -> int:
	return int(MESH_COUNTS.get(item, 0))


static func solid_count(item: String) -> int:
	return int(SOLID_COUNTS.get(item, 0))


static func support_points(item: String) -> PackedVector3Array:
	match item:
		"ST-048":
			return PackedVector3Array(
				[
					Vector3.ZERO,
					Vector3(-0.9, 0, -0.9),
					Vector3(0.9, 0, -0.9),
					Vector3(-0.9, 0, 0.9),
					Vector3(0.9, 0, 0.9)
				]
			)
		"ST-049":
			return PackedVector3Array(
				[
					Vector3.ZERO,
					Vector3(-1.7, 0, -1.7),
					Vector3(1.7, 0, -1.7),
					Vector3(-1.7, 0, 1.7),
					Vector3(1.7, 0, 1.7)
				]
			)
		"ST-050":
			return PackedVector3Array(
				[
					Vector3.ZERO,
					Vector3(-2.8, 0, 0),
					Vector3(2.8, 0, 0),
					Vector3(0, 0, -2.8),
					Vector3(0, 0, 2.8)
				]
			)
	return PackedVector3Array()


static func _sculpture(root: Node3D) -> void:
	_box(root, "SculptureGroundPlinth", Vector3(0, 0.16, 0), Vector3(2.2, 0.32, 2.2), STONE)
	_stem(root, "SculptureCradle", Vector3(0, 0.32, 0), Vector3(0, 0.68, 0), 0.82, 0.65, STONE_EDGE)
	_box(root, "SculpturePlaque", Vector3(0, 0.19, -1.112), Vector3(0.95, 0.18, 0.024), BRASS)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Eight parameter-space annuli surround true oval voids, including thickness walls.
	for hole in range(HOLE_COUNT):
		var phi: float = TAU * hole / float(HOLE_COUNT)
		var perimeter: Array[Vector2] = []
		for side in range(4):
			for step in range(4):
				var t: float = step / 4.0
				match side:
					0:
						perimeter.append(Vector2(-1 + 2 * t, -1))
					1:
						perimeter.append(Vector2(1, -1 + 2 * t))
					2:
						perimeter.append(Vector2(1 - 2 * t, 1))
					3:
						perimeter.append(Vector2(-1, 1 - 2 * t))
		for segment in range(perimeter.size()):
			var next: int = (segment + 1) % perimeter.size()
			var a: Vector2 = perimeter[segment]
			var b: Vector2 = perimeter[next]
			var inner_a: Vector2 = (
				Vector2(HOLE_THETA, phi)
				+ a.normalized() * Vector2(HOLE_THETA_RADIUS, HOLE_PHI_RADIUS)
			)
			var inner_b: Vector2 = (
				Vector2(HOLE_THETA, phi)
				+ b.normalized() * Vector2(HOLE_THETA_RADIUS, HOLE_PHI_RADIUS)
			)
			var outer_a: Vector2 = (
				Vector2((0.35 + PI / 2.0) / 2.0, phi)
				+ a * Vector2((PI / 2.0 - 0.35) / 2.0, PI / 8.0)
			)
			var outer_b: Vector2 = (
				Vector2((0.35 + PI / 2.0) / 2.0, phi)
				+ b * Vector2((PI / 2.0 - 0.35) / 2.0, PI / 8.0)
			)
			for ring in range(3):
				var t0: float = ring / 3.0
				var t1: float = (ring + 1) / 3.0
				_shell_patch(
					surface,
					inner_a.lerp(outer_a, t0),
					inner_b.lerp(outer_b, t0),
					inner_b.lerp(outer_b, t1),
					inner_a.lerp(outer_a, t1)
				)
			var rim: Array[Vector3] = [
				_ball_point(inner_a, BALL_RADIUS),
				_ball_point(inner_b, BALL_RADIUS),
				_ball_point(inner_b, BALL_RADIUS - SHELL_THICKNESS),
				_ball_point(inner_a, BALL_RADIUS - SHELL_THICKNESS)
			]
			var toward_hole: Vector3 = (
				_ball_point(Vector2(HOLE_THETA, phi), BALL_RADIUS) - (rim[0] + rim[1]) * 0.5
			)
			_quad(surface, rim, toward_hole)
	# The front cap and complete rear hemisphere meet the same 32 sector-edge samples.
	for region in range(2):
		var start: float = 0.0 if region == 0 else PI / 2.0
		var finish: float = 0.35 if region == 0 else PI
		var rings: int = 2 if region == 0 else 12
		for row in range(rings):
			for segment in range(32):
				var a: float = lerpf(start, finish, row / float(rings))
				var b: float = lerpf(start, finish, (row + 1) / float(rings))
				var p: float = -PI / 8.0 + TAU * segment / 32.0
				var q: float = p + TAU / 32.0
				_shell_patch(surface, Vector2(a, p), Vector2(a, q), Vector2(b, q), Vector2(b, p))
	surface.index()
	var mesh: ArrayMesh = surface.commit()
	_indexed_mesh(root, "PerforatedWiffleShell", mesh, WHITE)
	root.get_node("Visual/PerforatedWiffleShell").set_meta("true_open_apertures", HOLE_COUNT)
	root.get_node("Visual/PerforatedWiffleShell").set_meta("shell_thickness", SHELL_THICKNESS)
	root.get_node("Visual/PerforatedWiffleShell").set_meta("visual_shell_only", true)
	root.set_meta("true_open_apertures", HOLE_COUNT)


static func _ball_point(uv: Vector2, radius: float) -> Vector3:
	return BALL_CENTER + radius * Vector3(sin(uv.x) * cos(uv.y), sin(uv.x) * sin(uv.y), -cos(uv.x))


static func _shell_patch(
	surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2
) -> void:
	for inner in range(2):
		var radius: float = BALL_RADIUS - SHELL_THICKNESS * inner
		var points: Array[Vector3] = [
			_ball_point(a, radius),
			_ball_point(b, radius),
			_ball_point(c, radius),
			_ball_point(d, radius)
		]
		var normal: Vector3 = (points[0] + points[1] + points[2] + points[3]) * 0.25 - BALL_CENTER
		_quad(surface, points, normal * (1.0 if inner == 0 else -1.0), true, inner == 1)


static func _quad(
	surface: SurfaceTool,
	points: Array[Vector3],
	expected: Vector3,
	smooth: bool = false,
	inward: bool = false
) -> void:
	for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = points[triangle[0]]
		var b: Vector3 = points[triangle[1]]
		var c: Vector3 = points[triangle[2]]
		var normal: Vector3 = -(b - a).cross(c - a)
		if normal.length_squared() < 1e-12:
			continue
		if normal.dot(expected) < 0:
			var swap: Vector3 = b
			b = c
			c = swap
			normal = -normal
		for point: Vector3 in [a, b, c]:
			surface.set_normal(
				(
					(point - BALL_CENTER).normalized() * (-1.0 if inward else 1.0)
					if smooth
					else normal.normalized()
				)
			)
			surface.add_vertex(point)


static func _robot(root: Node3D) -> void:
	_box(root, "RobotGroundPlinth", Vector3(0, 0.16, 0), Vector3(3.8, 0.32, 3.8), STONE)
	_box(root, "RobotPlaque", Vector3(0, 0.18, -1.912 + 0.024), Vector3(1.15, 0.19, 0.024), BRASS)
	for side: int in [-1, 1]:
		_box(
			root,
			"RobotBoot%d" % side,
			Vector3(side * 0.70, 0.55, 0.30),
			Vector3(0.90, 0.46, 1.45),
			DARK_STEEL
		)
		_box(
			root,
			"RobotToePlate%d" % side,
			Vector3(side * 0.70, 0.65, -0.39),
			Vector3(0.96, 0.25, 0.16),
			RUST
		)
		var knee: Vector3 = Vector3(side * 0.72, 1.65, 0.10 if side == -1 else 0.32)
		_stem(root, "RobotShin%d" % side, Vector3(side * 0.70, 0.72, 0.30), knee, 0.20, 0.23, STEEL)
		_stem(root, "RobotThigh%d" % side, knee, Vector3(side * 0.52, 2.68, 0), 0.26, 0.30, RUST)
		_stem(
			root,
			"RobotKneeAxle%d" % side,
			knee + Vector3(-0.30, 0, 0),
			knee + Vector3(0.30, 0, 0),
			0.28,
			0.28,
			BRASS
		)
		_box(
			root,
			"RobotShinPatch%d" % side,
			Vector3(side * 0.70, 1.12, 0.035),
			Vector3(0.25, 0.48, 0.10),
			BRASS
		)
	_stem(root, "RobotWaist", Vector3(0, 2.55, 0), Vector3(0, 2.96, 0), 0.55, 0.55, DARK_STEEL)
	_box(root, "RobotChest", Vector3(0, 3.55, 0), Vector3(1.65, 1.40, 1.0), STEEL)
	_box(root, "RobotChestPatch", Vector3(-0.45, 3.65, -0.53), Vector3(0.55, 0.80, 0.08), RUST)
	_box(root, "RobotChestPlate", Vector3(0.40, 3.70, -0.55), Vector3(0.70, 0.62, 0.12), BRASS)
	for index in range(4):
		_box(
			root,
			"RobotVent%d" % index,
			Vector3(0.42, 3.48 + index * 0.14, -0.62),
			Vector3(0.51, 0.055, 0.03),
			DARK_STEEL
		)
	for side: int in [-1, 1]:
		_stem(
			root,
			"RobotShoulder%d" % side,
			Vector3(side * 0.72, 4.0, 0),
			Vector3(side * 1.10, 4.0, 0),
			0.34,
			0.34,
			BRASS
		)
	_stem(root, "RobotNeck", Vector3(0, 4.20, 0), Vector3(0, 4.52, 0), 0.24, 0.24, DARK_STEEL)
	_box(root, "RobotHead", Vector3(0, 4.94, -0.04), Vector3(1.10, 0.92, 0.90), STEEL)
	_box(root, "RobotBrow", Vector3(0, 5.15, -0.54), Vector3(1.22, 0.20, 0.16), RUST)
	for side: int in [-1, 1]:
		_box(
			root,
			"RobotEyeSocket%d" % side,
			Vector3(side * 0.27, 4.96, -0.51),
			Vector3(0.34, 0.25, 0.08),
			DARK_STEEL
		)
		_box(
			root,
			"RobotEye%d" % side,
			Vector3(side * 0.27, 4.96, -0.56),
			Vector3(0.18, 0.12, 0.05),
			Color("d8b95a")
		)
	_box(root, "RobotJaw", Vector3(0, 4.60, -0.44), Vector3(0.83, 0.20, 0.24), BRASS)
	for index in range(3):
		_box(
			root,
			"RobotMouthSlot%d" % index,
			Vector3(-0.23 + index * 0.23, 4.62, -0.568),
			Vector3(0.08, 0.12, 0.025),
			DARK_STEEL
		)
	_stem(
		root,
		"RobotAntenna",
		Vector3(-0.30, 5.38, 0.02),
		Vector3(-0.30, 5.78, 0.02),
		0.065,
		0.065,
		BRASS
	)
	_sphere(root, "RobotAntennaCap", Vector3(-0.30, 5.80, 0.02), Vector3.ONE * 0.12, RUST)
	var elbow: Vector3 = Vector3(1.45, 5.08, 0.30)
	_stem(root, "RobotThrowUpperArm", Vector3(1.05, 4.0, 0), elbow, 0.20, 0.18, STEEL)
	_sphere(root, "RobotThrowElbow", elbow, Vector3.ONE * 0.25, BRASS)
	_stem(root, "RobotThrowForearm", elbow, Vector3(1.20, 6.27, -0.25), 0.18, 0.16, RUST)
	_sphere(
		root, "RobotThrowHand", Vector3(1.20, 6.38, -0.25), Vector3(0.24, 0.26, 0.24), DARK_STEEL
	)
	_sphere(root, "RobotHeldDisplayBall", Vector3(1.20, 6.72, -0.25), Vector3.ONE * 0.28, WHITE)
	for side: int in [-1, 1]:
		_stem(
			root,
			"RobotBallGrip%d" % side,
			Vector3(1.20 + side * 0.16, 6.35, -0.25),
			Vector3(1.20 + side * 0.22, 6.67, -0.25),
			0.065,
			0.065,
			STEEL
		)
	var glove_elbow: Vector3 = Vector3(-1.50, 3.20, -0.45)
	_stem(root, "RobotGloveUpperArm", Vector3(-1.05, 4.0, 0), glove_elbow, 0.21, 0.18, STEEL)
	_sphere(root, "RobotGloveElbow", glove_elbow, Vector3.ONE * 0.24, BRASS)
	_stem(root, "RobotGloveForearm", glove_elbow, Vector3(-1.10, 3.43, -1.18), 0.18, 0.16, RUST)
	_box(root, "RobotGlovePalm", Vector3(-1.10, 3.43, -1.40), Vector3(0.66, 0.70, 0.36), RUST)
	for finger in range(3):
		_box(
			root,
			"RobotGloveFinger%d" % finger,
			Vector3(-1.34 + finger * 0.24, 3.91, -1.40),
			Vector3(0.18, 0.40, 0.30),
			BRASS
		)
	_box(root, "RobotGloveThumb", Vector3(-0.65, 3.52, -1.40), Vector3(0.30, 0.32, 0.30), BRASS)
	root.set_meta("fixed_pitching_pose", true)
	root.set_meta("held_display_ball_count", 1)
	root.set_meta("pitching_enabled", false)


static func _tiki(root: Node3D) -> void:
	_stem(root, "FountainGroundBasin", Vector3.ZERO, Vector3(0, 0.24, 0), 3.0, 3.0, STONE, 16)
	for segment in range(16):
		var a: float = TAU * segment / 16.0
		var b: float = TAU * (segment + 1) / 16.0
		var points: PackedVector3Array = []
		for y: float in [0.24, 0.72]:
			for polar: Vector2 in [
				Vector2(2.72, a), Vector2(3.0, a), Vector2(3.0, b), Vector2(2.72, b)
			]:
				points.append(Vector3(cos(polar.y) * polar.x, y, sin(polar.y) * polar.x))
		_solid(
			root,
			"FountainBasinRim%02d" % segment,
			points,
			PRISM_FACES,
			STONE_EDGE if segment % 2 == 0 else STONE
		)
	_stem(
		root,
		"FountainStillWater",
		Vector3(0, 0.52, 0),
		Vector3(0, 0.57, 0),
		2.68,
		2.68,
		WATER,
		32,
		false
	)
	_stem(
		root,
		"TikiPedestal",
		Vector3(0, 0.24, 0.65),
		Vector3(0, 0.92, 0.65),
		1.48,
		1.36,
		TIKI_DARK,
		12
	)
	_stem(
		root,
		"TikiHeadCore",
		Vector3(0, 0.82, 0.65),
		Vector3(0, 4.82, 0.65),
		1.36,
		1.30,
		TIKI_WOOD,
		12
	)
	_stem(
		root, "TikiCrown", Vector3(0, 4.64, 0.65), Vector3(0, 5.0, 0.65), 1.46, 1.38, TIKI_EDGE, 12
	)
	for side: int in [-1, 1]:
		_box(
			root,
			"TikiEar%d" % side,
			Vector3(side * 1.37, 2.91, 0.55),
			Vector3(0.38, 1.65, 0.65),
			TIKI_EDGE
		)
		_box(
			root,
			"TikiEarInset%d" % side,
			Vector3(side * 1.42, 2.91, 0.20),
			Vector3(0.22, 1.18, 0.12),
			TIKI_DARK
		)
		_box(
			root,
			"TikiEyeRecess%d" % side,
			Vector3(side * 0.63, 3.61, -0.72),
			Vector3(0.81, 0.55, 0.22),
			TIKI_DARK
		)
		_beam(
			root,
			"TikiBrow%d" % side,
			Vector3(side * 0.18, 3.95, -1.01),
			Vector3(side * 1.10, 4.13, -0.88),
			0.25,
			TIKI_EDGE
		)
		_box(
			root,
			"TikiEye%d" % side,
			Vector3(side * 0.63, 3.64, -0.85),
			Vector3(0.32, 0.17, 0.09),
			TIKI_EDGE
		)
		_box(
			root,
			"TikiCheek%d" % side,
			Vector3(side * 0.93, 2.84, -0.65),
			Vector3(0.48, 0.73, 0.54),
			TIKI_EDGE
		)
		_box(
			root,
			"TikiMouthSide%d" % side,
			Vector3(side * 0.62, 1.98, -0.82),
			Vector3(0.28, 0.84, 0.46),
			TIKI_EDGE
		)
		for stripe in range(2):
			_box(
				root,
				"TikiCheekCarving%d_%d" % [side, stripe],
				Vector3(side * 0.93, 2.65 + stripe * 0.26, -0.93),
				Vector3(0.32, 0.08, 0.06),
				TIKI_DARK
			)
	var nose: PackedVector3Array = [
		Vector3(-0.30, 2.64, -0.79),
		Vector3(-0.30, 2.64, -1.47),
		Vector3(-0.30, 3.96, -0.79),
		Vector3(0.30, 2.64, -0.79),
		Vector3(0.30, 2.64, -1.47),
		Vector3(0.30, 3.96, -0.79)
	]
	_solid(
		root,
		"TikiCarvedNose",
		nose,
		[[0, 1, 2], [3, 5, 4], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]],
		TIKI_EDGE
	)
	_box(root, "TikiMouthRecess", Vector3(0, 1.98, -0.74), Vector3(1.05, 0.69, 0.18), TIKI_DARK)
	_box(root, "TikiUpperLip", Vector3(0, 2.42, -0.94), Vector3(1.40, 0.25, 0.48), TIKI_EDGE)
	_box(root, "TikiLowerLip", Vector3(0, 1.56, -0.94), Vector3(1.40, 0.25, 0.48), TIKI_EDGE)
	for tooth in range(3):
		_box(
			root,
			"TikiTooth%d" % tooth,
			Vector3(-0.36 + tooth * 0.36, 2.21, -1.04),
			Vector3(0.25, 0.24, 0.18),
			WHITE
		)
	_box(root, "TikiWaterSpout", Vector3(0, 1.83, -1.14), Vector3(0.44, 0.18, 0.66), TIKI_DARK)
	# One solid-looking static stream ends inside the basin; it is neither sensor nor collider.
	_stem(
		root,
		"FountainStaticStream",
		Vector3(0, 0.57, -1.52),
		Vector3(0, 1.83, -1.47),
		0.13,
		0.10,
		WATER,
		12,
		false
	)
	_stem(
		root,
		"FountainStaticSplash",
		Vector3(0, 0.57, -1.52),
		Vector3(0, 0.61, -1.52),
		0.38,
		0.32,
		Color("91c5c6"),
		16,
		false
	)
	root.set_meta("bounded_static_water", true)
	root.set_meta(
		"water_visual_bounds", AABB(Vector3(-2.68, 0.52, -2.68), Vector3(5.36, 1.41, 5.36))
	)
	root.set_meta("water_audio_enabled", false)


static func _box(root: Node3D, id: String, center: Vector3, size: Vector3, color: Color) -> void:
	var low: Vector3 = center - size * 0.5
	var high: Vector3 = center + size * 0.5
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


static func _beam(
	root: Node3D, id: String, start: Vector3, end: Vector3, width: float, color: Color
) -> void:
	var direction: Vector3 = start.direction_to(end)
	var across: Vector3 = direction.cross(Vector3.FORWARD).normalized()
	var depth: Vector3 = across.cross(direction).normalized()
	var points: PackedVector3Array = []
	for center: Vector3 in [start, end]:
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			points.append(center + (across * corner.x + depth * corner.y) * width * 0.5)
	_solid(root, id, points, PRISM_FACES, color)


static func _stem(
	root: Node3D,
	id: String,
	start: Vector3,
	end: Vector3,
	bottom: float,
	top: float,
	color: Color,
	segments: int = 12,
	physical: bool = true
) -> void:
	var pose: Basis = Basis(Quaternion(Vector3.UP, start.direction_to(end)))
	var points: PackedVector3Array = []
	for level in range(2):
		for index in range(segments):
			var angle: float = TAU * index / float(segments)
			var radius: float = bottom if level == 0 else top
			points.append(
				(
					(start if level == 0 else end)
					+ pose * Vector3(cos(angle) * radius, 0, sin(angle) * radius)
				)
			)
	var faces: Array = []
	var lower: Array = []
	var upper: Array = []
	for index in range(segments):
		lower.append(index)
		upper.append(index + segments)
		var next: int = (index + 1) % segments
		faces.append([index, next, next + segments, index + segments])
	faces.append(lower)
	faces.append(upper)
	if physical:
		_solid(root, id, points, faces, color)
	else:
		_visual(root, id, points, faces, color)


static func _sphere(
	root: Node3D, id: String, center: Vector3, radii: Vector3, color: Color
) -> void:
	var points: PackedVector3Array = [
		center + Vector3(0, radii.y, 0), center - Vector3(0, radii.y, 0)
	]
	for row in range(1, 6):
		var theta: float = PI * row / 6.0
		for index in range(12):
			var phi: float = TAU * index / 12.0
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
	var faces: Array = []
	for index in range(12):
		var next: int = (index + 1) % 12
		faces.append([0, 2 + index, 2 + next])
		faces.append([1, 50 + next, 50 + index])
		for row in range(4):
			faces.append(
				[
					2 + row * 12 + index,
					2 + row * 12 + next,
					14 + row * 12 + next,
					14 + row * 12 + index
				]
			)
	_solid(root, id, points, faces, color)


static func _indexed_mesh(root: Node3D, id: String, mesh: ArrayMesh, color: Color) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_INDEX] == null or arrays[Mesh.ARRAY_INDEX].is_empty():
		var indices: PackedInt32Array = []
		for index in range(arrays[Mesh.ARRAY_VERTEX].size()):
			indices.append(index)
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	StadiumStarterModels._mesh(root, id, Vector3.ZERO, mesh, color)


static func _visual(
	root: Node3D, id: String, points: PackedVector3Array, faces: Array, color: Color
) -> void:
	_indexed_mesh(root, id, StadiumGroundPropsModels._poly_mesh(points, faces), color)


static func _solid(
	root: Node3D, id: String, points: PackedVector3Array, faces: Array, color: Color
) -> void:
	_visual(root, id, points, faces, color)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("stadium_item", root.get_meta("stadium_item"))
	body.set_meta("surface_id", id)
	body.set_meta("surface_role", ROLE)
	body.set_meta("ball_surface", &"stadium_scenery")
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Solid"
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = points.duplicate()
	shape.margin = 0.0
	collider.shape = shape
	body.add_child(collider)
	root.get_node("Collision").add_child(body)
