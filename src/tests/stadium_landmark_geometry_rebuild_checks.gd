class_name StadiumLandmarkGeometryRebuildChecks
extends RefCounted
## Bounded helper for the existing shared fixture; this is not a test runner.
## 1 contract + 6 foreign + 2*5 frozen + 3*(1 create + 16 common)
## + (8 sculpture + 8 robot + 9 fountain anatomy) + 3*2 site poses = 99.

const M = preload("res://src/presentation/stadium/stadium_landmark_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const SOLIDS = preload("res://src/tests/stadium_ground_box_geometry_rebuild_checks.gd")
const EPS: float = 0.0002
const COMMON_CHECKS: int = 16
const ANATOMY_CHECKS: Dictionary = {"ST-048": 8, "ST-049": 8, "ST-050": 9}
const EXPECTED_CHECKS: int = 99
const FOREIGN: Array[String] = ["ST-013", "ST-045", "ST-047", "ST-051", "ST-060", ""]
const COUNTS: Dictionary = {
	"ST-048": Vector2i(4, 3), "ST-049": Vector2i(52, 52), "ST-050": Vector2i(49, 46)
}
const ACTUAL: Dictionary = {
	"ST-048": AABB(Vector3(-2.3, 0, -2.3), Vector3(4.6, 5, 4.6)),
	"ST-049": AABB(Vector3(-1.9, 0, -1.9), Vector3(3.8, 7, 3.8)),
	"ST-050": AABB(Vector3(-3, 0, -3), Vector3(6, 5, 6))
}
const RESERVES: Dictionary = {
	"ST-048": AABB(Vector3(-2.5, 0, -2.5), Vector3(5, 5, 5)),
	"ST-049": AABB(Vector3(-2, 0, -2), Vector3(4, 7, 4)),
	"ST-050": AABB(Vector3(-3, 0, -3), Vector3(6, 5, 6))
}
const FROZEN: Dictionary = {
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
	"stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4",
	"stadium_landscape_models.gd":
	"235d15c52578afbc30aee7fda5dc7310bb47da5c8c2ab7ef329fa3a6b0fcc296",
	"stadium_practice_facility_models.gd":
	"8c0d8f2e73a92cc0e3111d0dea291844962d2093ee87318c54c8432ce3214b15",
	"stadium_treehouse_models.gd":
	"48cb5e251051eebc638ebf865fd16467c8adfd02a31577a224b9594cceb5beb9"
}


static func expected_checks() -> int:
	var count: int = 1 + FOREIGN.size() + 2 * FROZEN.size()
	for item: String in M.ITEMS:
		count += 1 + COMMON_CHECKS + int(ANATOMY_CHECKS[item]) + 2
	return count


static func run(parent: Node3D, check: Callable) -> void:
	var probe: Node3D = Node3D.new()
	probe.name = "LandmarkGeometryProbe"
	probe.position = Vector3(2400, 0, 0)
	parent.add_child(probe)
	_emit(
		check,
		(
			M.ITEMS == ["ST-048", "ST-049", "ST-050"]
			and M.VERSION == 1
			and expected_checks() == EXPECTED_CHECKS
		),
		"three complete landmark factories declare the exact finite geometry inventory"
	)
	for item: String in FOREIGN:
		var foreign: Node3D = M.create(item)
		_emit(
			check,
			(
				foreign == null
				and M.envelope(item) == AABB()
				and M.visible_bounds(item) == AABB()
				and M.bounds(item) == AABB()
				and M.support_points(item).is_empty()
				and M.mesh_count(item) == 0
				and M.solid_count(item) == 0
			),
			"foreign inventory never creates or borrows a landmark",
			{"item": item}
		)
		if foreign != null:
			foreign.free()
	_frozen(check)
	for item: String in M.ITEMS:
		var model: Node3D = M.create(item)
		_emit(check, model != null, "complete landmark parent creates", {"item": item})
		if model == null:
			continue
		probe.add_child(model)
		await _common(probe, model, item, check)
		match item:
			"ST-048":
				_sculpture(model, check)
			"ST-049":
				_robot(model, check)
			"ST-050":
				_tiki(model, check)
		_posed(model, item, check)
		model.free()
	_frozen(check)
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"LANDMARK_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _frozen(check: Callable) -> void:
	for filename: String in FROZEN:
		_emit(
			check,
			FileAccess.get_sha256("res://src/presentation/stadium/" + filename) == FROZEN[filename],
			"reused primitives and accepted older scenery factories remain byte exact",
			{"file": filename}
		)


static func _common(probe: Node3D, model: Node3D, item: String, check: Callable) -> void:
	_emit(
		check,
		(
			model.get_child_count() == 2
			and model.transform == Transform3D.IDENTITY
			and model.get_node("Visual").transform == Transform3D.IDENTITY
			and model.get_node("Collision").transform == Transform3D.IDENTITY
		),
		"one complete ground-pivot landmark has exactly two identity branches",
		{"item": item}
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item") == item
			and model.get_meta("geometry_version") == 1
			and model.get_meta("model_version") == 1
			and model.get_meta("static_geometry")
			and model.get_meta("scenery_only")
			and model.get_meta("ambient_ball_count") == 0
			and model.get_meta("obstacle_units") == 0
			and not model.get_meta("final_art_accepted")
			and model.get_meta("authoring_status") == "Working"
			and not model.get_meta("animated_during_pitch")
			and not model.get_meta("water_entry_enabled")
			and not model.get_meta("ball_award_enabled")
		),
		(
			"complete static artwork declares no award or live-play authority and retains pending "
			+ "final-art review"
		),
		{"item": item}
	)
	_emit(
		check,
		SOLIDS._static_unit_scale(model),
		"every actual landmark descendant is finite static script-free unit-scale geometry",
		{"item": item}
	)
	var scan: Dictionary = SCAN._scan(model)
	var expected: Vector2i = COUNTS[item]
	_emit(
		check,
		(
			str(scan.failure).is_empty()
			and scan.types == ["ArrayMesh"]
			and int(scan.meshes) == expected.x
			and M.mesh_count(item) == expected.x
			and int(scan.vertices) > 100
			and int(scan.vertices) < 18000
		),
		(
			"all real indexed native meshes have finite vertex and normal arrays within the "
			+ "bounded rendering budget"
		),
		{"item": item, "scan": scan, "expected_meshes": expected.x}
	)
	_emit(
		check,
		SOLIDS._indexed(model),
		"every actual landmark surface carries explicit valid triangle indices",
		{"item": item}
	)
	_emit(
		check,
		(
			SCAN._appearance_failure(model).is_empty()
			and int(scan.colors) >= (4 if item == "ST-048" else 7)
		),
		"plain independently owned opaque materials distinguish the actual complete landmark parts",
		{"item": item, "colors": scan.colors}
	)
	var actual: AABB = SCAN._bounds(POINTS._points(model))
	var reserve: AABB = RESERVES[item]
	_emit(
		check,
		(
			_same_box(actual, ACTUAL[item])
			and M.visible_bounds(item) == ACTUAL[item]
			and M.envelope(item) == reserve
			and M.bounds(item) == reserve
			and reserve.grow(EPS).encloses(actual)
			and model.get_meta("visible_bounds") == ACTUAL[item]
			and model.get_meta("envelope") == reserve
			and actual.position.y >= -EPS
		),
		(
			"all actual visible parts and supports fit the exact source-defined maximum dimensions "
			+ "above ground"
		),
		{"item": item, "actual": str(actual), "reserve": str(reserve)}
	)
	_emit(
		check,
		_physical_match(model, item),
		"each enabled decorative zero-margin hull matches its own visible convex solid exactly",
		{"item": item, "expected_solids": expected.y}
	)
	_emit(
		check,
		SOLIDS._solid_faces(model),
		"every rigid triangle winds outward on its actual convex hull without reserve collision proxies",
		{"item": item}
	)
	_emit(
		check,
		_roles(model, item),
		"no sensor water-entry scoring training revenue animation light or audio authority exists",
		{"item": item}
	)
	var second: Node3D = M.create(item)
	probe.add_child(second)
	_emit(
		check,
		POINTS._independent(model, second),
		"all actual mesh material and hull resources are independent between purchased copies",
		{"item": item}
	)
	var before: String = SOLIDS._signature(model)
	_emit(
		check,
		SOLIDS._signature(second) == before,
		"fresh complete landmarks reproduce identical native geometry and physical state",
		{"item": item}
	)
	SCAN._mutate(second)
	for shape: CollisionShape3D in second.find_children("*", "CollisionShape3D", true, false):
		shape.shape.points = PackedVector3Array(
			[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
	_emit(
		check,
		SOLIDS._signature(model) == before and SOLIDS._signature(second) != before,
		"destructive native mesh material pose and hull changes remain isolated to the altered copy",
		{"item": item}
	)
	second.free()
	var fresh: Node3D = M.create(item)
	_emit(
		check,
		SOLIDS._signature(fresh) == before,
		"regeneration remains deterministic after destructive mutation of another copy",
		{"item": item}
	)
	fresh.free()
	await model.get_tree().process_frame
	_emit(
		check,
		SOLIDS._signature(model) == before,
		"an idle rendered frame cannot animate robot shell water or any physical shape",
		{"item": item}
	)
	_emit(
		check,
		_ground_supports(model, item),
		"all five declared support points belong to the real grounded visible base",
		{"item": item, "supports": str(M.support_points(item))}
	)
	print(
		(
			"LANDMARK_GEOMETRY_MEASUREMENT "
			+ JSON.stringify(
				{
					"item": item,
					"meshes": scan.meshes,
					"vertices": scan.vertices,
					"physical_hulls": model.get_node("Collision").get_child_count(),
					"support_points": M.support_points(item).size(),
					"actual_bounds": str(actual),
					"reservation": str(reserve),
					"static": true,
					"final_art_accepted": false
				},
				"",
				true,
				true
			)
		)
	)


static func _sculpture(model: Node3D, check: Callable) -> void:
	_emit(
		check,
		(
			_same_box(
				_member(model, "SculptureGroundPlinth"),
				AABB(Vector3(-1.1, 0, -1.1), Vector3(2.2, 0.32, 2.2))
			)
			and absf(_member(model, "SculptureCradle").position.y - 0.32) < EPS
			and _member(model, "SculptureCradle").end.y > 0.60
		),
		"the complete giant ball has a real grounded plinth and intersecting cradle support"
	)
	var shell: MeshInstance3D = model.get_node("Visual/PerforatedWiffleShell")
	_emit(
		check,
		(
			_same_box(
				_member(model, "PerforatedWiffleShell"),
				AABB(Vector3(-2.3, 0.4, -2.3), Vector3(4.6, 4.6, 4.6))
			)
			and shell.get_meta("shell_thickness") == 0.10
		),
		"actual giant white sphere measures 4.6 metres across with ten-centimetre shell walls"
	)
	var holes: bool = true
	for index in range(8):
		var direction: Vector3 = (
			M._ball_point(Vector2(0.95, TAU * index / 8.0), 1.0) - M.BALL_CENTER
		)
		holes = holes and not _shell_hit(shell, direction)
	_emit(
		check,
		(
			holes
			and shell.get_meta("true_open_apertures") == 8
			and model.get_meta("true_open_apertures") == 8
		),
		(
			"eight actual sphere apertures have empty center-to-outside triangle rays rather than "
			+ "opaque decals"
		)
	)
	_emit(
		check,
		(
			_shell_hit(shell, M._ball_point(Vector2(0.15, 0.28), 1.0) - M.BALL_CENTER)
			and _shell_hit(shell, M._ball_point(Vector2(2.40, 0.28), 1.0) - M.BALL_CENTER)
		),
		"native triangles complete the front cap and rear sphere around the true apertures"
	)
	var arrays: Array = shell.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var outer: int = 0
	var inner: int = 0
	var walls: int = 0
	var radii_ok: bool = true
	for index in range(vertices.size()):
		var radial: Vector3 = vertices[index] - M.BALL_CENTER
		var radius: float = radial.length()
		var is_outer: bool = absf(radius - 2.3) < EPS
		var is_inner: bool = absf(radius - 2.2) < EPS
		radii_ok = radii_ok and (is_outer or is_inner)
		outer += int(is_outer)
		inner += int(is_inner)
		walls += int(absf(radial.normalized().dot(normals[index])) < 0.8)
	_emit(
		check,
		radii_ok and outer > 300 and inner > 300 and walls >= 128,
		"real outer inner and aperture-wall vertices form a thick open shell",
		{"outer_vertices": outer, "inner_vertices": inner, "wall_vertices": walls}
	)
	_emit(
		check,
		(
			shell.get_meta("visual_shell_only")
			and not model.has_node("Collision/PerforatedWiffleShell")
			and model.get_node("Collision").get_child_count() == 3
		),
		"open perforated shell never receives a falsely solid sphere or envelope collider"
	)
	var broad_openings: bool = true
	for index in range(8):
		for offset: Vector2 in [
			Vector2(-0.20, 0), Vector2(0.20, 0), Vector2(0, -0.08), Vector2(0, 0.08)
		]:
			var uv: Vector2 = Vector2(0.95, TAU * index / 8.0) + offset
			broad_openings = (
				broad_openings and not _shell_hit(shell, M._ball_point(uv, 1.0) - M.BALL_CENTER)
			)
	_emit(
		check,
		broad_openings,
		"each aperture has broad empty angular cross-sections readable at stadium scale"
	)
	_emit(
		check,
		(
			shell.material_override.albedo_color == Color("f5f3df")
			and shell.material_override.albedo_texture == null
			and shell.material_override.albedo_color.a == 1.0
			and vertices.size() > 1000
			and model.has_node("Visual/SculpturePlaque")
		),
		(
			"the readable sculpture is white solid-thickness perforated geometry on a complete "
			+ "labeled pedestal"
		)
	)


static func _robot(model: Node3D, check: Callable) -> void:
	_emit(
		check,
		(
			_same_box(
				_member(model, "RobotGroundPlinth"),
				AABB(Vector3(-1.9, 0, -1.9), Vector3(3.8, 0.32, 3.8))
			)
			and SCAN._members(model, "RobotBoot").size() == 2
			and absf(_member(model, "RobotBoot-1").position.y - 0.32) < EPS
		),
		"both broad scrap-metal boots visibly bear on the robot's own ground-supported base"
	)
	var legs: bool = true
	for side: int in [-1, 1]:
		legs = (
			legs
			and _member(model, "RobotShin%d" % side).grow(EPS).intersects(
				_member(model, "RobotBoot%d" % side)
			)
		)
		legs = (
			legs
			and _member(model, "RobotThigh%d" % side).grow(EPS).intersects(
				_member(model, "RobotShin%d" % side)
			)
		)
		legs = (
			legs
			and _member(model, "RobotThigh%d" % side).grow(EPS).intersects(
				_member(model, "RobotWaist")
			)
		)
	_emit(
		check,
		(
			legs
			and _member(model, "RobotWaist").grow(EPS).intersects(_member(model, "RobotChest"))
			and SCAN._members(model, "RobotKneeAxle").size() == 2
		),
		"two articulated metal legs knee axles waist and full torso form a continuous supported figure"
	)
	_emit(
		check,
		(
			SCAN._members(model, "RobotEyeSocket").size() == 2
			and SCAN._members(model, "RobotEye").size() == 4
			and model.has_node("Visual/RobotHead")
			and model.has_node("Visual/RobotBrow")
			and model.has_node("Visual/RobotJaw")
			and model.has_node("Visual/RobotAntenna")
			and model.has_node("Visual/RobotAntennaCap")
		),
		"complete robot head has two recessed eyes broad brow jaw and bounded antenna"
	)
	_emit(
		check,
		(
			_member(model, "RobotThrowUpperArm").grow(EPS).intersects(
				_member(model, "RobotShoulder1")
			)
			and _member(model, "RobotThrowForearm").grow(EPS).intersects(
				_member(model, "RobotThrowElbow")
			)
			and _member(model, "RobotThrowForearm").grow(EPS).intersects(
				_member(model, "RobotThrowHand")
			)
			and absf(_member(model, "RobotHeldDisplayBall").end.y - 7.0) < EPS
		),
		(
			"raised throwing arm elbow forearm hand and held ball make the static seven-metre "
			+ "pitching silhouette"
		)
	)
	_emit(
		check,
		(
			SCAN._members(model, "RobotGloveFinger").size() == 3
			and model.has_node("Visual/RobotGloveThumb")
			and _member(model, "RobotGlovePalm").end.x < 0
			and _member(model, "RobotGlovePalm").position.z < -1.5
			and _member(model, "RobotGloveForearm").grow(EPS).intersects(
				_member(model, "RobotGlovePalm")
			)
		),
		"opposite extended arm carries a complete three-finger-and-thumb catching glove"
	)
	_emit(
		check,
		(
			SCAN._members(model, "RobotVent").size() == 4
			and SCAN._members(model, "RobotMouthSlot").size() == 3
			and SCAN._members(model, "RobotShinPatch").size() == 2
			and SCAN._members(model, "RobotToePlate").size() == 2
			and model.has_node("Visual/RobotChestPatch")
			and model.has_node("Visual/RobotChestPlate")
		),
		"large rust brass and steel plates vents and metal patches establish a scrap-built statue"
	)
	_emit(
		check,
		(
			model.get_meta("held_display_ball_count") == 1
			and model.get_meta("ambient_ball_count") == 0
			and not model.get_meta("pitching_enabled")
			and SCAN._members(model, "RobotBallGrip").size() == 2
			and model.find_children("*", "RigidBody3D", true, false).is_empty()
		),
		(
			"held ball and two gripping fingers are inseparable static artwork with no simulated "
			+ "pitch or extra ball"
		)
	)
	_emit(
		check,
		(
			model.get_meta("fixed_pitching_pose")
			and _member(model, "RobotHead").position.y > 4.4
			and _member(model, "RobotGlovePalm").get_center().y < _member(model, "RobotChest").end.y
			and _member(model, "RobotThrowHand").position.y > _member(model, "RobotHead").end.y
		),
		(
			"large head chest low glove and raised throwing hand preserve the intended complete "
			+ "fixed pitching pose"
		)
	)


static func _tiki(model: Node3D, check: Callable) -> void:
	_emit(
		check,
		_same_box(
			_member(model, "FountainGroundBasin"), AABB(Vector3(-3, 0, -3), Vector3(6, 0.24, 6))
		),
		"complete six-metre basin has a real visible ground-supported floor"
	)
	var rim: bool = SCAN._members(model, "FountainBasinRim").size() == 16
	for member: MeshInstance3D in SCAN._members(model, "FountainBasinRim"):
		var box: AABB = _member(model, str(member.name))
		rim = rim and absf(box.position.y - 0.24) < EPS and absf(box.end.y - 0.72) < EPS
	_emit(
		check,
		rim,
		"sixteen actual convex visible stone rim sectors enclose the basin without a solid reserve proxy"
	)
	var water: AABB = _member(model, "FountainStillWater")
	_emit(
		check,
		(
			_same_box(water, AABB(Vector3(-2.68, 0.52, -2.68), Vector3(5.36, 0.05, 5.36)))
			and water.end.y < 0.72
			and not model.has_node("Collision/FountainStillWater")
		),
		(
			"actual static water plane is smaller and lower than the containing stone rim with no "
			+ "water collider"
		)
	)
	_emit(
		check,
		(
			model.has_node("Visual/TikiPedestal")
			and _member(model, "TikiHeadCore").grow(EPS).intersects(_member(model, "TikiPedestal"))
			and absf(_member(model, "TikiCrown").end.y - 5.0) < EPS
			and SCAN._members(model, "TikiEar").size() == 4
		),
		(
			"full tall faceted tiki head crown ears and supporting pedestal stay inside the "
			+ "five-metre ceiling"
		)
	)
	_emit(
		check,
		(
			SCAN._members(model, "TikiBrow").size() == 2
			and SCAN._members(model, "TikiEyeRecess").size() == 2
			and SCAN._members(model, "TikiEye").size() == 4
			and SCAN._members(model, "TikiCheek").size() == 6
			and _member(model, "TikiCarvedNose").position.z < -1.4
		),
		"deep physical brow cheek eye and projecting carved-nose geometry creates a readable giant face"
	)
	_emit(
		check,
		(
			SCAN._members(model, "TikiMouthSide").size() == 2
			and SCAN._members(model, "TikiTooth").size() == 3
			and model.has_node("Visual/TikiUpperLip")
			and model.has_node("Visual/TikiLowerLip")
			and model.has_node("Visual/TikiMouthRecess")
			and model.has_node("Visual/TikiWaterSpout")
			and (
				_member(model, "TikiMouthRecess").position.z
				> _member(model, "TikiUpperLip").position.z
			)
		),
		"recessed mouth cheeks lips three teeth and real spout give the fountain a complete face"
	)
	var stream: AABB = _member(model, "FountainStaticStream")
	_emit(
		check,
		(
			stream.grow(EPS).intersects(_member(model, "TikiWaterSpout"))
			and stream.grow(EPS).intersects(water)
			and _member(model, "FountainStaticSplash").grow(EPS).intersects(water)
			and stream.position.z > -2.0
			and stream.end.y < 1.94
		),
		(
			"one bounded static water stream joins the mouth spout to the visible basin with a "
			+ "contained splash"
		)
	)
	var water_points: PackedVector3Array = []
	var visual_only: bool = true
	for id: String in ["FountainStillWater", "FountainStaticStream", "FountainStaticSplash"]:
		water_points.append_array(
			model.get_node("Visual/" + id).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		)
		visual_only = visual_only and not model.has_node("Collision/" + id)
	var water_bounds: AABB = model.get_meta("water_visual_bounds")
	_emit(
		check,
		(
			visual_only
			and model.get_meta("bounded_static_water")
			and not model.get_meta("water_audio_enabled")
			and water_bounds.grow(EPS).encloses(SCAN._bounds(water_points))
			and M.envelope("ST-050").encloses(water_bounds)
		),
		(
			"all three water meshes stay in an explicit finite static volume without audio "
			+ "particles or water-entry authority"
		),
		{"actual_water": str(SCAN._bounds(water_points)), "allowed_water": str(water_bounds)}
	)
	_emit(
		check,
		(
			_same_box(
				SCAN._bounds(POINTS._points(model)), AABB(Vector3(-3, 0, -3), Vector3(6, 5, 6))
			)
			and model.get_node("Collision").get_child_count() == 46
			and _roles(model, "ST-050")
		),
		(
			"the entire basin water face crown and all forty-six visible-solid hulls fit the "
			+ "complete six-by-six-by-five landmark"
		)
	)


static func _posed(model: Node3D, item: String, check: Callable) -> void:
	for entry: Dictionary in [
		{
			"site": "PRIMARY",
			"center": Vector3(36.5, 0, 44),
			"reserve": AABB(Vector3(30, 0, 39), Vector3(13, 8, 10))
		},
		{
			"site": "PLAZA",
			"center": Vector3(40, 0, -14),
			"reserve": AABB(Vector3(36.5, 0, -17.5), Vector3(7, 8, 7))
		}
	]:
		var pose: Transform3D = Transform3D(Basis.IDENTITY, entry.center)
		var actual: AABB = pose * SCAN._bounds(POINTS._points(model))
		var reserve: AABB = entry.reserve
		var grounded: bool = (
			reserve.grow(EPS).encloses(actual)
			and reserve.grow(EPS).encloses(pose * M.envelope(item))
		)
		for point: Vector3 in M.support_points(item):
			grounded = (
				grounded
				and absf((pose * point).y) < EPS
				and reserve.grow(EPS).has_point(pose * point)
			)
		_emit(
			check,
			grounded and pose.basis == Basis.IDENTITY,
			(
				"complete unscaled fixed-pose landmark and every actual support fit the authored "
				+ "off-field site reserve"
			),
			{"item": item, "site": entry.site, "actual": str(actual), "reserve": str(reserve)}
		)


static func _same_box(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) < EPS and a.size.distance_to(b.size) < EPS


static func _member(model: Node3D, id: String) -> AABB:
	var member: MeshInstance3D = model.get_node("Visual/" + id)
	return SCAN._bounds(member.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])


static func _ground_supports(model: Node3D, item: String) -> bool:
	var base: String = {
		"ST-048": "SculptureGroundPlinth",
		"ST-049": "RobotGroundPlinth",
		"ST-050": "FountainGroundBasin"
	}[item]
	var box: AABB = _member(model, base)
	var points: PackedVector3Array = M.support_points(item)
	if points.size() != 5 or absf(box.position.y) > EPS:
		return false
	for point: Vector3 in points:
		if not point.is_finite() or absf(point.y) > EPS or not box.grow(EPS).has_point(point):
			return false
		if item == "ST-050" and Vector2(point.x, point.z).length() > 3.0 * cos(PI / 16.0):
			return false
	return true


static func _physical_match(model: Node3D, item: String) -> bool:
	var bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
	var expected: Vector2i = COUNTS[item]
	if (
		bodies.size() != expected.y
		or M.solid_count(item) != expected.y
		or model.find_children("*", "CollisionShape3D", true, false).size() != expected.y
	):
		return false
	for body: StaticBody3D in bodies:
		if (
			body.get_parent() != model.get_node("Collision")
			or body.get_child_count() != 1
			or body.transform != Transform3D.IDENTITY
			or body.collision_layer != 1
			or body.collision_mask != 2
			or body.constant_linear_velocity != Vector3.ZERO
			or body.constant_angular_velocity != Vector3.ZERO
		):
			return false
		var collider: CollisionShape3D = body.get_child(0)
		if (
			str(collider.name) != "Solid"
			or not collider.shape is ConvexPolygonShape3D
			or collider.disabled
			or collider.shape.margin != 0
			or collider.transform != Transform3D.IDENTITY
		):
			return false
		var hull: PackedVector3Array = collider.shape.points
		var visible: PackedVector3Array = (
			model.get_node("Visual/" + str(body.name)).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		)
		for point: Vector3 in hull:
			if (
				not point.is_finite()
				or not M.visible_bounds(item).grow(EPS).has_point(point)
				or not POINTS._has_point(visible, point)
			):
				return false
		for point: Vector3 in visible:
			if not POINTS._has_point(hull, point):
				return false
	return true


static func _roles(model: Node3D, item: String) -> bool:
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "", true, false))
	for node: Node in nodes:
		for forbidden: String in [
			"receiver",
			"receiver_id",
			"volume_id",
			"target_points",
			"water_scoring",
			"live_furnishing",
			"revenue",
			"income",
			"training",
			"stat_bonus",
			"capacity",
			"player_card",
			"night_profile",
			"water_entry"
		]:
			if node.has_meta(forbidden):
				return false
		if node.has_meta("stadium_item") and node.get_meta("stadium_item") != item:
			return false
		if (
			node is StaticBody3D
			and (
				node.get_meta("stadium_item", "") != item
				or node.get_meta("surface_id", "") != str(node.name)
				or node.get_meta("ball_surface", "") != &"stadium_scenery"
				or node.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL"
			)
		):
			return false
	return (
		model.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL"
		and model.get_meta("physics_profile") == "DECORATIVE_AFTER_TERMINAL"
		and model.find_children("*", "Area3D", true, false).is_empty()
		and model.find_children("*", "Light3D", true, false).is_empty()
		and model.find_children("*", "AnimationPlayer", true, false).is_empty()
		and model.find_children("*", "AudioStreamPlayer3D", true, false).is_empty()
	)


static func _shell_hit(shell: MeshInstance3D, direction: Vector3) -> bool:
	var arrays: Array = shell.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for offset in range(0, indices.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			M.BALL_CENTER,
			direction.normalized(),
			vertices[indices[offset]],
			vertices[indices[offset + 1]],
			vertices[indices[offset + 2]]
		)
		if hit != null:
			return true
	return false
