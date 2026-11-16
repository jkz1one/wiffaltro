class_name StadiumTreehouseGeometryRebuildChecks
extends RefCounted
## Finite geometry support for the shared owned fixture, never another runner.
## Successful path: 1 contract + 6 foreign + 2*4 frozen + 1 create
## + 16 common + 15 anatomy + 3 fixed-pose checks = exactly 50 assertions.

const M = preload("res://src/presentation/stadium/stadium_treehouse_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const SOLIDS = preload("res://src/tests/stadium_ground_box_geometry_rebuild_checks.gd")
const EPS: float = 0.0002
const COMMON_CHECKS: int = 16
const ANATOMY_CHECKS: int = 15
const EXPECTED_CHECKS: int = 50
const FOREIGN: Array[String] = ["ST-013", "ST-014", "ST-044", "ST-046", "ST-060", ""]
const FROZEN: Dictionary = {
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
	"stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4",
	"stadium_landscape_models.gd":
	"235d15c52578afbc30aee7fda5dc7310bb47da5c8c2ab7ef329fa3a6b0fcc296",
	"stadium_practice_facility_models.gd":
	"8c0d8f2e73a92cc0e3111d0dea291844962d2093ee87318c54c8432ce3214b15"
}


static func expected_checks() -> int:
	return 1 + FOREIGN.size() + 2 * FROZEN.size() + 1 + COMMON_CHECKS + ANATOMY_CHECKS + 3


static func run(parent: Node3D, check: Callable) -> void:
	var probe: Node3D = Node3D.new()
	probe.name = "TreehouseGeometryProbe"
	probe.position = Vector3(2200, 0, 0)
	parent.add_child(probe)
	_emit(
		check,
		(
			M.ITEM == "ST-045"
			and M.ITEMS == ["ST-045"]
			and M.VERSION == 1
			and expected_checks() == EXPECTED_CHECKS
		),
		"one complete treehouse factory and exact finite assertion inventory"
	)
	for item: String in FOREIGN:
		var foreign: Node3D = M.create(item)
		_emit(
			check,
			(
				foreign == null
				and M.envelope(item) == AABB()
				and M.visible_bounds(item) == AABB()
				and M.local_approach_bounds(item) == AABB()
			),
			"foreign inventory cannot substitute for the complete treehouse",
			{"item": item}
		)
		if foreign != null:
			foreign.free()
	_frozen(check)
	var model: Node3D = M.create()
	_emit(check, model != null, "one full bundled treehouse creates")
	if model != null:
		probe.add_child(model)
		await _common(probe, model, check)
		_anatomy(model, check)
		_posed(model, check)
		model.free()
	_frozen(check)
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"TREEHOUSE_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _frozen(check: Callable) -> void:
	for filename: String in FROZEN:
		_emit(
			check,
			FileAccess.get_sha256("res://src/presentation/stadium/" + filename) == FROZEN[filename],
			"reused primitives and accepted landscape and practice factories remain byte exact",
			{"file": filename}
		)


static func _common(probe: Node3D, model: Node3D, check: Callable) -> void:
	_emit(
		check,
		(
			model.get_child_count() == 2
			and model.transform == Transform3D.IDENTITY
			and model.get_node("Visual").transform == Transform3D.IDENTITY
			and model.get_node("Collision").transform == Transform3D.IDENTITY
		),
		"one ground-pivot complete assembly has exactly two identity branches"
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item") == "ST-045"
			and model.get_meta("geometry_version") == 1
			and model.get_meta("model_version") == 1
			and model.get_meta("static_geometry")
			and model.get_meta("scenery_only")
			and model.get_meta("bundled_support_tree")
			and not model.get_meta("climbing_enabled")
			and model.get_meta("ambient_ball_count") == 0
			and model.get_meta("obstacle_units") == 0
			and not model.get_meta("final_art_accepted")
			and model.get_meta("authoring_status") == "Working"
		),
		(
			"complete static scenery declares bundled artwork and honestly retains pending "
			+ "final-art acceptance"
		)
	)
	_emit(
		check,
		SOLIDS._static_unit_scale(model),
		"all actual descendants are finite static visible unit-scale nodes without scripts"
	)
	var scan: Dictionary = SCAN._scan(model)
	_emit(
		check,
		(
			str(scan.failure).is_empty()
			and scan.types == ["ArrayMesh"]
			and scan.meshes == 101
			and M.MESH_COUNT == 101
			and int(scan.vertices) > 2400
			and int(scan.vertices) < 4000
		),
		"all 101 real meshes have bounded finite native vertices normals and valid array types",
		{"scan": scan}
	)
	_emit(
		check,
		SOLIDS._indexed(model),
		"every actual surface stores explicit nonempty valid triangle indices"
	)
	_emit(
		check,
		SCAN._appearance_failure(model).is_empty() and int(scan.colors) >= 8,
		"independent opaque timber bark roof and foliage materials retain the accepted plain model style"
	)
	var actual: AABB = SCAN._bounds(POINTS._points(model))
	var visible: AABB = AABB(Vector3(-2.5, 0, -2.5), Vector3(5, 6, 5))
	var reserve: AABB = AABB(Vector3(-3, 0, -3), Vector3(6, 7, 6))
	_emit(
		check,
		(
			_same_box(actual, visible)
			and M.visible_bounds() == visible
			and M.envelope() == reserve
			and M.bounds() == reserve
			and model.get_meta("envelope") == reserve
			and model.get_meta("visible_bounds") == visible
			and reserve.grow(EPS).encloses(actual)
		),
		(
			"actual full bundled model reaches five by five by six metres inside the six by six by "
			+ "seven reserve"
		),
		{"actual": str(actual), "reservation": str(reserve)}
	)
	_emit(
		check,
		_physical_match(model),
		"all 97 enabled zero-margin decorative hulls exactly match their own visible solid vertices"
	)
	_emit(
		check,
		SOLIDS._solid_faces(model),
		"every rigid actual triangle winds outward on its complete convex hull"
	)
	_emit(
		check,
		_roles(model),
		(
			"no live surface sensor scoring revenue training climbing animation or Night authority "
			+ "is installed"
		)
	)
	var second: Node3D = M.create()
	probe.add_child(second)
	_emit(
		check,
		POINTS._independent(model, second),
		"all real meshes materials and hulls are independent between purchased parents"
	)
	var before: String = SOLIDS._signature(model)
	_emit(
		check,
		SOLIDS._signature(second) == before,
		"fresh complete parents reproduce identical native arrays and physical state"
	)
	SCAN._mutate(second)
	for shape: CollisionShape3D in second.find_children("*", "CollisionShape3D", true, false):
		shape.shape.points = PackedVector3Array(
			[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
	_emit(
		check,
		SOLIDS._signature(model) == before and SOLIDS._signature(second) != before,
		"destructive native mesh material hull and transform changes stay within the changed copy"
	)
	second.free()
	var fresh: Node3D = M.create()
	_emit(
		check,
		SOLIDS._signature(fresh) == before,
		"regeneration remains deterministic after destructive mutation of another copy"
	)
	fresh.free()
	await model.get_tree().process_frame
	_emit(
		check,
		SOLIDS._signature(model) == before,
		"an idle rendered frame cannot animate tree ladder rails or physical shapes"
	)
	_emit(
		check,
		(
			not model.has_meta("owned_copy")
			and not model.has_meta("tree_copy")
			and model.find_children("*ST013*", "", true, false).is_empty()
			and model.find_children("*Landscape*", "", true, false).is_empty()
		),
		"bundled tree is part of the one parent and never a separately owned or mounted ST-013 purchase"
	)
	print(
		(
			"TREEHOUSE_GEOMETRY_MEASUREMENT "
			+ JSON.stringify(
				{
					"meshes": scan.meshes,
					"vertices": scan.vertices,
					"bodies": model.get_node("Collision").get_child_count(),
					"visual_canopies": 4,
					"actual_bounds": str(actual),
					"reservation": str(reserve),
					"local_approach": str(M.local_approach_bounds()),
					"support_points": M.support_points().size(),
					"static": true,
					"final_art_accepted": false
				},
				"",
				true,
				true
			)
		)
	)


static func _anatomy(model: Node3D, check: Callable) -> void:
	var posts: bool = SCAN._members(model, "SupportPost").size() == 4
	for side: int in [-1, 1]:
		for end: int in [-1, 1]:
			var z: float = -1.4 if end == -1 else 1.7
			posts = (
				posts
				and _same_box(
					_member(model, "SupportPost%d_%d" % [side, end]),
					AABB(Vector3(side * 1.65 - 0.1, 0, z - 0.1), Vector3(0.2, 2.0, 0.2))
				)
			)
	_emit(
		check,
		posts,
		"four actual full-height timber posts bear on y zero and reach the deck underside"
	)
	var supports: PackedVector3Array = M.support_points()
	var grounded: bool = supports.size() == 7
	var bases: Array[String] = [
		"BundledTrunk",
		"SupportPost-1_-1",
		"SupportPost1_-1",
		"SupportPost-1_1",
		"SupportPost1_1",
		"LadderFoot-1",
		"LadderFoot1"
	]
	for index in range(supports.size()):
		var box: AABB = _member(model, bases[index])
		grounded = grounded and absf(supports[index].y) < EPS and absf(box.position.y) < EPS
		grounded = grounded and box.grow(EPS).has_point(supports[index])
	_emit(
		check,
		grounded,
		"seven declared support points lie on actual grounded trunk post or ladder-foot bases"
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "BundledTrunk"),
				AABB(Vector3(-0.32, 0, 1.08), Vector3(0.64, 4.85, 0.64))
			)
			and SCAN._members(model, "BundledRoot").size() == 4
			and SCAN._members(model, "BundledBranch").size() == 2
			and model.has_node("Collision/BundledForwardBranch")
		),
		(
			"one grounded tapered trunk four flared roots and three real crown branches form a "
			+ "recognizable bundled tree"
		)
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "DeckFront"), AABB(Vector3(-1.9, 2.0, -1.65), Vector3(3.8, 0.2, 2.6))
			)
			and SCAN._members(model, "DeckRearWing").size() == 2
			and model.has_node("Collision/DeckRearLip")
			and SCAN._members(model, "DeckSideFascia").size() == 2
			and SCAN._members(model, "DeckEndFascia").size() == 2
		),
		(
			"four solid deck sections and all four fascia edges create a complete 3.8 by 3.6 metre "
			+ "raised platform"
		)
	)
	_emit(
		check,
		(
			absf(_member(model, "DeckRearWing-1").end.x + 0.45) < EPS
			and absf(_member(model, "DeckRearWing1").position.x - 0.45) < EPS
			and absf(_member(model, "DeckFront").end.z - 0.95) < EPS
			and absf(_member(model, "DeckRearLip").position.z - 1.85) < EPS
			and not _inside_solid_aabb(model, Vector3(0.40, 2.1, 1.4))
		),
		(
			"real rectangular deck opening leaves air beside the trunk rather than a solid reserve "
			+ "or room proxy"
		)
	)
	_emit(
		check,
		(
			SCAN._members(model, "KneeBrace").size() == 4
			and SCAN._members(model, "SupportBeam").size() == 2
			and _member(model, "SupportBeam-1").end.y >= 2.0 - EPS
			and _member(model, "SupportBeam1").end.y >= 2.0 - EPS
		),
		"four diagonal knee braces and two full crossbeams visibly support the deck at its real underside"
	)
	_emit(
		check,
		(
			absf(_member(model, "CabinDoorWing-1").end.x + 0.48) < EPS
			and absf(_member(model, "CabinDoorWing1").position.x - 0.48) < EPS
			and absf(_member(model, "DoorHeader").position.y - 3.92) < EPS
			and not _inside_solid_aabb(model, Vector3(0, 3.0, -0.71))
		),
		"front cabin has a real 0.96 metre wide 1.72 metre high open doorway from the deck"
	)
	_emit(
		check,
		(
			not _inside_solid_aabb(model, Vector3(-1.11, 3.2, 0.05))
			and not _inside_solid_aabb(model, Vector3(1.11, 3.2, 0.05))
			and SCAN._members(model, "WindowSill").size() == 2
		),
		"both complete side walls surround actual open windows with supported timber sills"
	)
	_emit(
		check,
		(
			SCAN._members(model, "CabinGable").size() == 2
			and SCAN._members(model, "RoofSlope").size() == 2
			and model.has_node("Collision/CabinRearWall")
			and model.has_node("Collision/RoofRidge")
			and not _inside_solid_aabb(model, Vector3(0, 3.0, 0.0))
		),
		"complete back wall two gables and overlapping roof slopes surround a genuinely hollow cabin"
	)
	_emit(
		check,
		(
			absf(_member(model, "FrontGuardRail-1_0").end.x + 0.5) < EPS
			and absf(_member(model, "FrontGuardRail1_0").position.x - 0.5) < EPS
			and not _inside_solid_aabb(model, Vector3(0, 2.65, -1.55))
		),
		"front platform rails leave an actual one-metre access gap aligned with the ladder"
	)
	_emit(
		check,
		(
			SCAN._members(model, "SideGuardPost").size() == 10
			and SCAN._members(model, "RearGuardPost").size() == 3
			and SCAN._members(model, "EntryGuardPost").size() == 2
			and SCAN._members(model, "SideGuardRail").size() == 4
			and SCAN._members(model, "FrontGuardRail").size() == 4
			and SCAN._members(model, "RearGuardRail").size() == 2
			and absf(_member(model, "RearGuardPost1").position.y - 2.18) < EPS
		),
		(
			"fifteen platform-supported guard posts and ten rails enclose all sides except the "
			+ "local ladder entry"
		)
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "LadderFoot-1"),
				AABB(Vector3(-0.56, 0, -2.5), Vector3(0.18, 0.12, 0.16))
			)
			and _same_box(
				_member(model, "LadderFoot1"),
				AABB(Vector3(0.38, 0, -2.5), Vector3(0.18, 0.12, 0.16))
			)
			and SCAN._members(model, "LadderStile").size() == 2
		),
		"two real grounded ladder shoes support continuous inclined stiles extending above the platform"
	)
	var rungs: bool = SCAN._members(model, "LadderRung").size() == 9
	for index in range(9):
		var y: float = 0.25 + index * 0.24
		var z: float = -2.42 + (y - 0.06) / 3.0
		rungs = (
			rungs
			and _same_box(
				_member(model, "LadderRung%d" % index),
				AABB(Vector3(-0.47, y - 0.05, z - 0.08), Vector3(0.94, 0.1, 0.16))
			)
		)
	_emit(
		check,
		(
			rungs
			and absf(_member(model, "LadderRung8").end.y - 2.22) < EPS
			and _member(model, "LadderRung8").end.z > -1.65
		),
		"nine evenly spaced full-width rungs follow the same ladder slope and meet the real deck top"
	)
	var canopies: bool = SCAN._members(model, "Crown").size() == 4
	for member: MeshInstance3D in SCAN._members(model, "Crown"):
		canopies = (
			canopies
			and member.get_meta("visual_canopy_only", false)
			and not model.has_node("Collision/" + str(member.name))
		)
	_emit(
		check,
		(
			canopies
			and _member(model, "CrownCore").grow(EPS).has_point(Vector3(0, 4.85, 1.4))
			and _member(model, "CrownFront").grow(EPS).has_point(Vector3(0, 5.30, -0.9))
		),
		(
			"four bounded faceted foliage lobes meet actual branch ends and never become broad "
			+ "canopy colliders"
		)
	)
	var approach: AABB = SCAN._bounds(SCAN._points(model, "Ladder"))
	_emit(
		check,
		(
			M.local_approach_bounds().grow(EPS).encloses(approach)
			and M.envelope().encloses(M.local_approach_bounds())
			and model.get_meta("local_approach_only")
			and not model.get_meta("connected_pedestrian_route")
			and model.get_meta("local_approach_bounds") == M.local_approach_bounds()
		),
		"complete real ladder approach stays inside the reserve and claims no external connected route",
		{"actual_ladder": str(approach)}
	)


static func _posed(model: Node3D, check: Callable) -> void:
	var pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(-29, 0, 20))
	var actual: AABB = pose * SCAN._bounds(POINTS._points(model))
	var reserve: AABB = pose * M.envelope()
	_emit(
		check,
		(
			_same_box(actual, AABB(Vector3(-31.5, 0, 17.5), Vector3(5, 6, 5)))
			and _same_box(reserve, AABB(Vector3(-32, 0, 17), Vector3(6, 7, 6)))
			and reserve.grow(EPS).encloses(actual)
		),
		"exact fixed TREEHOUSE-A pose preserves complete unscaled geometry and full reservation",
		{"actual": str(actual), "reserve": str(reserve)}
	)
	var grounded: bool = true
	for support: Vector3 in M.support_points():
		grounded = (
			grounded
			and absf((pose * support).y) < EPS
			and reserve.grow(EPS).has_point(pose * support)
		)
	_emit(
		check,
		grounded,
		"all seven actual fixed-pose support bases remain on world ground inside TREEHOUSE-A"
	)
	_emit(
		check,
		(
			reserve.encloses(pose * M.local_approach_bounds())
			and pose.basis * Vector3.FORWARD == Vector3.FORWARD
		),
		"fixed minus-Z ladder approach remains wholly inside TREEHOUSE-A without a connecting-path claim"
	)


static func _same_box(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) < EPS and a.size.distance_to(b.size) < EPS


static func _member(model: Node3D, id: String) -> AABB:
	var member: MeshInstance3D = model.get_node("Visual/" + id)
	return SCAN._bounds(member.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])


static func _inside_solid_aabb(model: Node3D, point: Vector3) -> bool:
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if _member(model, str(body.name)).has_point(point):
			return true
	return false


static func _physical_match(model: Node3D) -> bool:
	var bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
	if (
		bodies.size() != 97
		or M.SOLID_COUNT != 97
		or model.find_children("*", "CollisionShape3D", true, false).size() != 97
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
				or not M.VISIBLE.grow(EPS).has_point(point)
				or not POINTS._has_point(visible, point)
			):
				return false
		for point: Vector3 in visible:
			if not POINTS._has_point(hull, point):
				return false
	return true


static func _roles(model: Node3D) -> bool:
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
			"tree_copy",
			"night_profile"
		]:
			if node.has_meta(forbidden):
				return false
		if node.has_meta("stadium_item") and node.get_meta("stadium_item") != "ST-045":
			return false
		if (
			node is StaticBody3D
			and (
				node.get_meta("stadium_item", "") != "ST-045"
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
	)
