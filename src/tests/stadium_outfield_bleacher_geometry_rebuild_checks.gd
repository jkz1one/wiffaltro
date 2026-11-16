class_name StadiumOutfieldBleacherGeometryRebuildChecks
extends RefCounted
## Finite geometry support only. The shared fixture owns real property walls.
## Successful path: 1 contract + 6 foreign + 2*4 frozen + 1 create + 16 common
## + 18 anatomy + 10 native access/support + 24 native self-rays + 3 pose = 87.

const M = preload("res://src/presentation/stadium/stadium_outfield_bleacher_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const SOLIDS = preload("res://src/tests/stadium_ground_box_geometry_rebuild_checks.gd")
const EPS: float = 0.0002
const COMMON_CHECKS: int = 16
const ANATOMY_CHECKS: int = 18
const NATIVE_ACCESS_CHECKS: int = 10
const EXPECTED_CHECKS: int = 87
const FOREIGN: Array[String] = ["ST-027", "ST-029", "ST-052", "ST-057", "ST-080", ""]
const FROZEN: Dictionary = {
	"stadium_ground_box_models.gd":
	"cfee2e08209f30c8cb989b733981931d56aceecc8fedbbd231888036e2fd52eb",
	"stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4",
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
	"stadium_bleacher_models.gd": "040edd83c323dc009cfa68d9a8fccfea7ac775dcb05097992cf816187a15c07c"
}


static func expected_checks() -> int:
	return (
		1
		+ FOREIGN.size()
		+ 2 * FROZEN.size()
		+ 1
		+ COMMON_CHECKS
		+ ANATOMY_CHECKS
		+ NATIVE_ACCESS_CHECKS
		+ 12 * 2
		+ 3
	)


static func run(parent: Node3D, check: Callable) -> void:
	var probe: Node3D = Node3D.new()
	probe.name = "OutfieldBleacherGeometryProbe"
	probe.position = Vector3(2300, 0, 0)
	parent.add_child(probe)
	_emit(
		check,
		(
			M.VERSION == 1
			and M.ITEM == "ST-054"
			and M.ITEMS == ["ST-054"]
			and M.ENVELOPE == AABB(Vector3(-8, 0, -4), Vector3(16, 8.6, 8))
			and expected_checks() == EXPECTED_CHECKS
		),
		"one complete elevated parent has the exact fixed envelope and reachable check budget"
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
				and M.mesh_count(item) == 0
				and M.solid_count(item) == 0
				and M.support_points(item).is_empty()
			),
			"foreign seating and support items cannot substitute for the complete bleacher",
			{"item": item}
		)
		if foreign != null:
			foreign.free()
	_frozen(check)
	var model: Node3D = M.create()
	_emit(check, model != null, "one complete elevated outfield bleacher creates")
	if model != null:
		probe.add_child(model)
		await _common(probe, model, check)
		_anatomy(model, check)
		await _native_access(model, check)
		_self_sightlines(model, check)
		_pose(model, check)
		model.free()
	_frozen(check)
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"OUTFIELD_BLEACHER_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _frozen(check: Callable) -> void:
	for filename: String in FROZEN:
		_emit(
			check,
			FileAccess.get_sha256("res://src/presentation/stadium/" + filename) == FROZEN[filename],
			"every reused primitive and accepted seating factory remains byte exact",
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
		"complete ground-pivot assembly has exactly two identity branches"
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item") == "ST-054"
			and model.get_meta("model_version") == 1
			and model.get_meta("geometry_version") == 1
			and model.get_meta("static_geometry")
			and model.get_meta("scenery_only")
			and model.get_meta("obstacle_units") == 0
			and model.get_meta("physics_profile") == "DECORATIVE_AFTER_TERMINAL"
		),
		"complete static decorative parent grants zero obstacle units"
	)
	_emit(
		check,
		SOLIDS._static_unit_scale(model),
		"all actual members remain script-free finite visible unit-scale static geometry"
	)
	var scan: Dictionary = SCAN._scan(model)
	_emit(
		check,
		(
			str(scan.failure).is_empty()
			and scan.types == ["ArrayMesh"]
			and int(scan.meshes) == 327
			and M.mesh_count() == 327
			and int(scan.vertices) >= 7800
			and int(scan.vertices) < 12000
		),
		"all 327 real indexed convex-prism meshes pass full native array scanning",
		{"scan": scan}
	)
	_emit(
		check,
		SOLIDS._indexed(model),
		"all native surfaces store complete nonempty valid triangle index arrays"
	)
	_emit(
		check,
		SCAN._appearance_failure(model).is_empty() and int(scan.colors) >= 5,
		"opaque independent steel concrete decks and benches retain five readable material colors"
	)
	var actual: AABB = SCAN._bounds(POINTS._points(model))
	_emit(
		check,
		(
			_same_box(actual, AABB(Vector3(-7.8, 0, -3.5), Vector3(15.6, 8.25, 7.3)))
			and _same_box(actual, M.visible_bounds())
			and M.bounds() == M.ENVELOPE
			and model.get_meta("envelope") == M.ENVELOPE
			and model.get_meta("visible_bounds") == M.visible_bounds()
			and M.ENVELOPE.grow(EPS).encloses(actual)
		),
		"every actual vertex fits the independently measured complete reservation",
		{"actual": str(actual)}
	)
	_emit(
		check,
		_physical_match(model),
		"all 327 exact named zero-margin layer-one mask-two convex solids match their visible vertices"
	)
	_emit(
		check,
		SOLIDS._solid_faces(model),
		"every indexed triangle winds outward on its exact complete convex hull"
	)
	_emit(
		check,
		_roles(model),
		(
			"no live scoring receiver crowd capacity revenue or free support-copy state leaks into "
			+ "the assembly"
		)
	)
	var second: Node3D = M.create()
	probe.add_child(second)
	_emit(
		check,
		POINTS._independent(model, second),
		"all native meshes materials and physical resources are independent between copies"
	)
	var before: String = SOLIDS._signature(model)
	_emit(
		check,
		SOLIDS._signature(second) == before,
		"fresh complete copies reproduce identical native arrays materials and solid state"
	)
	SCAN._mutate(second)
	for shape: CollisionShape3D in second.find_children("*", "CollisionShape3D", true, false):
		shape.shape.points = PackedVector3Array(
			[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
	_emit(
		check,
		SOLIDS._signature(model) == before and SOLIDS._signature(second) != before,
		"destructive native mesh material pose and hull mutation cannot alter another copy"
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
		"an idle rendered frame cannot animate the deck benches access or solids"
	)
	_emit(
		check,
		(
			model.find_children("*", "Area3D", true, false).is_empty()
			and model.find_children("*", "NavigationRegion3D", true, false).is_empty()
			and model.find_children("*", "MultiMeshInstance3D", true, false).is_empty()
			and model.find_children("*", "AnimationPlayer", true, false).is_empty()
		),
		"the actual assembly contains no sensors crowd batching navigation or animation"
	)
	print(
		(
			"OUTFIELD_BLEACHER_GEOMETRY_MEASUREMENT "
			+ JSON.stringify(
				{
					"meshes": scan.meshes,
					"physical_hulls": 327,
					"vertices": scan.vertices,
					"visible_bounds": str(actual),
					"envelope": str(M.ENVELOPE),
					"ground_support_samples": M.support_points().size(),
					"rows": 4,
					"eye_samples": M.eye_points().size()
				},
				"",
				true,
				true
			)
		)
	)


static func _anatomy(model: Node3D, check: Callable) -> void:
	var eyes: PackedVector3Array = M.eye_points()
	var exact_eyes: bool = eyes.size() == 12
	for row in range(4):
		for column in range(3):
			exact_eyes = (
				exact_eyes
				and (
					eyes[row * 3 + column].distance_to(
						Vector3([-6.0, 0.0, 6.0][column], 7.0 + row * 0.45, -3.0 + row)
					)
					< EPS
				)
			)
	_emit(
		check,
		exact_eyes,
		"all twelve row end and center eyes have the approved 1.20 m floor offset"
	)
	_emit(
		check,
		(
			SCAN._members(model, "RowDeck").size() == 4
			and SCAN._members(model, "BenchPan").size() == 4
			and model.get_meta("row_count") == 4
		),
		"the actual compact assembly contains exactly four complete decks and backless benches"
	)
	var decks: bool = true
	var benches: bool = true
	var legs: bool = true
	for row in range(4):
		var y: float = 5.80 + row * 0.45
		var z: float = -3.0 + row
		decks = (
			decks
			and _same_box(
				_member(model, "RowDeck%d" % row),
				AABB(Vector3(-6.4, y - 0.18, z - 0.50), Vector3(12.8, 0.18, 1))
			)
		)
		var pan: AABB = _member(model, "BenchPan%d" % row)
		benches = (
			benches
			and _same_box(pan, AABB(Vector3(-6.2, y + 0.38, z - 0.12), Vector3(12.4, 0.08, 0.44)))
		)
		for column in range(3):
			benches = (
				benches and pan.grow(EPS).has_point(Vector3(eyes[row * 3 + column].x, y + 0.42, z))
			)
		for leg in range(5):
			var base: AABB = _member(model, "BenchLeg%d_%d" % [row, leg])
			legs = (
				legs
				and absf(base.position.y - y) < EPS
				and absf(base.end.y - pan.position.y) < EPS
				and base.grow(EPS).intersects(pan)
			)
	_emit(
		check, decks, "four full 12.8 m decks reach actual floor heights 5.80 6.25 6.70 and 7.15 m"
	)
	_emit(
		check,
		benches,
		"real 12.4 m backless bench pans physically contain every required seated eye sample"
	)
	_emit(
		check,
		(
			legs
			and SCAN._members(model, "BenchLeg").size() == 20
			and SCAN._members(model, "BenchStretcher").size() == 4
		),
		"all twenty bench legs meet their decks and pans with complete stretchers"
	)
	var feet: Array[Node] = model.get_node("Collision").find_children(
		"*Foot", "StaticBody3D", false, false
	)
	_emit(
		check,
		(
			feet.size() == 34
			and M.support_points().size() == 65
			and SCAN._members(model, "RowSupport").size() == 32
			and SCAN._members(model, "RearWalkSupport").size() == 8
		),
		"all thirty-four steel supports and thirty-one ground masses are included in the exact parent"
	)
	var columns: bool = true
	for foot: StaticBody3D in feet:
		var id: String = str(foot.name).trim_suffix("Foot")
		var base: AABB = _member(model, id + "Foot")
		var column: AABB = _member(model, id + "Column")
		columns = (
			columns
			and absf(base.position.y) < EPS
			and absf(base.end.y - column.position.y) < EPS
			and base.grow(EPS).intersects(column)
			and column.size.y > 5.0
		)
	_emit(
		check,
		columns,
		"each real column bears continuously on a ground-level foot rather than floating above terrain"
	)
	_emit(
		check,
		(
			SCAN._members(model, "CrossBrace").size() == 12
			and SCAN._members(model, "DepthBrace").size() == 4
			and _member(model, "DepthBrace1A").size.y > 6
			and _member(model, "CrossBrace3_0_1").size.x > 4
		),
		"sixteen real diagonal steel braces visibly tie transverse and longitudinal support frames"
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "LeftAccessWalk"),
				AABB(Vector3(-7.8, 5.62, -3.5), Vector3(1.4, 0.18, 5.8))
			)
			and _same_box(
				_member(model, "RightAisleBase"),
				AABB(Vector3(6.4, 5.62, -3.5), Vector3(1.4, 0.18, 4.5))
			)
			and _same_box(
				_member(model, "RearWalkDeck"),
				AABB(Vector3(-6.4, 6.97, 0.5), Vector3(12.8, 0.18, 0.5))
			)
		),
		"full-width supported left walk right aisle and rear walkway connect the complete deck system"
	)
	var risers: bool = SCAN._members(model, "RowRiser").size() == 3
	for row in range(3):
		risers = (
			risers
			and _same_box(
				_member(model, "RowRiser%d" % row),
				AABB(Vector3(-6.4, 5.8 + row * 0.45, -2.54 + row), Vector3(12.8, 0.45, 0.04))
			)
		)
	_emit(
		check,
		risers,
		"all three complete row riser faces close the actual elevated deck transitions"
	)
	var aisle: bool = (
		SCAN._members(model, "AisleStep").size() == 9
		and SCAN._members(model, "AisleLanding").size() == 3
	)
	for row in range(3):
		for step in range(3):
			var box: AABB = _member(model, "AisleStep%d_%d" % [row, step])
			aisle = (
				aisle
				and absf(box.end.y - (5.8 + row * 0.45 + (step + 1) * 0.15)) < EPS
				and absf(box.size.x - 1.4) < EPS
				and absf(box.size.z - 0.2) < EPS
				and absf(box.position.y - 5.8) < EPS
			)
	_emit(
		check,
		aisle,
		"a separate supported right aisle provides nine actual 0.15 m rises and three row landings"
	)
	var lower: bool = SCAN._members(model, "GroundStair").size() == 15 + 2 * 10
	for index in range(15):
		lower = (
			lower
			and _same_box(
				_member(model, "GroundStair%d" % index),
				AABB(Vector3(-6.0 + index * 0.4, 0, 2.55), Vector3(0.4, (index + 1) * 0.2, 1.25))
			)
		)
	_emit(
		check,
		lower,
		"first stair flight has fifteen exact ground-bearing 0.20 m rises with 0.40 m tread runs"
	)
	var upper: bool = true
	for index in range(14):
		upper = (
			upper
			and _same_box(
				_member(model, "UpperStair%d" % index),
				AABB(Vector3(-0.4 - index * 0.4, 0, 1.05), Vector3(0.4, 3.2 + index * 0.2, 1.25))
			)
		)
	_emit(
		check,
		(
			upper
			and _same_box(
				_member(model, "StairTurningLanding"),
				AABB(Vector3(0, 0, 1.05), Vector3(1.4, 3, 2.75))
			)
			and absf(_member(model, "GroundApproach").position.y) < EPS
		),
		(
			"second flight completes fourteen further rises with a full turning landing and actual "
			+ "ground approach"
		)
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "StairTopLanding"),
				AABB(Vector3(-6.4, 5.62, 1.05), Vector3(0.8, 0.18, 1.25))
			)
			and _member(model, "StairTopLanding").grow(EPS).intersects(
				_member(model, "LeftAccessWalk")
			)
			and _member(model, "StairTopLanding").grow(EPS).intersects(
				_member(model, "UpperStair13")
			)
		),
		"real top landing joins the final 5.80 m stair tread directly to the supported left walk"
	)
	var guard: bool = SCAN._members(model, "FrontGuard").size() == 13
	for member: MeshInstance3D in SCAN._members(model, "FrontGuard"):
		guard = guard and _member(model, str(member.name)).end.y <= 6.8 + EPS
	_emit(
		check,
		guard and absf(_member(model, "FrontGuardPost0").size.y - 1.0) < EPS,
		"actual first-row static guard is one metre high with every vertex below the required view rays"
	)
	_emit(
		check,
		(
			_guard_posts(model).size() == 106
			and SCAN._members(model, "RearGuard").size() == 13
			and SCAN._members(model, "RightLandingGuard").size() == 16
			and SCAN._members(model, "RightStepGuard").size() == 12
			and SCAN._members(model, "LeftRowGuard").size() == 12
		),
		(
			"actual perimeter stair and turning barriers include 106 posts and complete stepped "
			+ "access protection"
		)
	)
	_emit(
		check,
		(
			model.find_children("Crowd*", "", true, false).is_empty()
			and model.get_meta("represented_audience_count") == 0
			and model.get_meta("ambient_ball_count") == 0
			and model.get_meta("bundled_supports")
			and model.get_meta("bundled_seating")
		),
		(
			"the complete paid parent bundles every support and bench with no spectator mechanic "
			+ "or extra support item"
		)
	)
	_emit(
		check,
		(
			model.get_meta("facing") == Vector3.FORWARD
			and model.get_meta("local_approach_only")
			and not model.get_meta("connected_pedestrian_route")
			and model.get_meta("supported_wall_height") == 3.25
			and PitchBatLab.MOUND_ORIGIN == Vector3(0, 0, 13.716)
		),
		"field-facing local access uses the real mound and only the approved lower wall context"
	)


static func _native_access(model: Node3D, check: Callable) -> void:
	await model.get_tree().physics_frame
	await model.get_tree().physics_frame
	var supports: bool = true
	for point: Vector3 in M.support_points():
		supports = (
			supports
			and _hit_height(
				model, _ray(model, point + Vector3(0, -0.3, 0), point + Vector3(0, 0.03, 0)), 0.0
			)
		)
	_emit(
		check,
		supports,
		"native upward rays hit all sixty-five actual ground-bearing underside samples at y zero"
	)
	var steps: bool = true
	for index in range(15):
		steps = steps and _floor_hit(model, Vector3(-5.8 + index * 0.4, (index + 1) * 0.2, 3.175))
	for index in range(14):
		steps = steps and _floor_hit(model, Vector3(-0.2 - index * 0.4, 3.2 + index * 0.2, 1.675))
	_emit(
		check,
		steps,
		"native floor rays hit every one of the twenty-nine actual stair treads at its exact rise"
	)
	_emit(
		check,
		(
			_floor_hit(model, Vector3(0.7, 3, 2.425))
			and _floor_hit(model, Vector3(-6, 5.8, 1.675))
			and _floor_hit(model, Vector3(-6.6, 0.04, 3.175))
		),
		"native rays establish the real lower turning upper and ground landings"
	)
	var left: bool = true
	for z: float in [-3.20, -1.0, 1.70]:
		left = left and _floor_hit(model, Vector3(-7.1, 5.8, z))
	_emit(
		check,
		left,
		"native rays find continuous left-side access from the stair landing to the first row"
	)
	var aisle: bool = _floor_hit(model, Vector3(7.1, 5.8, -3.2))
	for row in range(3):
		for step in range(3):
			aisle = (
				aisle
				and _floor_hit(
					model,
					Vector3(7.1, 5.8 + row * 0.45 + (step + 1) * 0.15, -2.75 + row + step * 0.2)
				)
			)
		aisle = aisle and _floor_hit(model, Vector3(7.1, 6.25 + row * 0.45, -2.1 + row))
	_emit(
		check,
		aisle,
		"native rays hit all right-aisle intermediate steps and every row landing at their true heights"
	)
	var floor_samples: bool = true
	var seat_samples: bool = true
	for point: Vector3 in M.eye_points():
		floor_samples = floor_samples and _floor_hit(model, point + Vector3(0, -1.2, -0.30))
		seat_samples = (
			seat_samples
			and _hit_height(model, _ray(model, point, point + Vector3(0, -1.2, 0)), point.y - 0.74)
		)
	_emit(
		check,
		floor_samples,
		"all twelve end and center seating locations have actual clear foot decks below them"
	)
	_emit(
		check,
		seat_samples,
		"native rays from all twelve required seated eyes hit the actual backless pans"
	)
	var bearing: bool = true
	var first_failure: String = ""
	var patch_proof: Dictionary = {}
	var bearing_rays: int = 0
	var bearing_patches: int = 0
	for body: StaticBody3D in _guard_posts(model):
		var box: AABB = _member(model, str(body.name))
		if str(body.name) == "LeftRowGuard2Post1":
			# This one joined post has partial bearing on RowDeck2. Float32
			# bounds place its center 2.98e-8 m outside the deck's rear edge.
			# Prove an actual in-foot contact patch; never move the real post.
			bearing_patches += 1
			patch_proof = _joined_guard_bearing(model, body, box)
			if not bool(patch_proof.ok):
				bearing = false
				if first_failure.is_empty():
					first_failure = str(body.name) + ":partial-bearing-patch"
			continue
		bearing_rays += 1
		var point: Vector3 = Vector3(box.get_center().x, box.position.y, box.get_center().z)
		var exclude: Array[RID] = [body.get_rid()]
		var hit: Dictionary = _ray(
			model, point + Vector3(0, 0.08, 0), point + Vector3(0, -0.20, 0), exclude
		)
		if not _hit_height(model, hit, point.y):
			bearing = false
			if first_failure.is_empty():
				first_failure = str(body.name) + ":" + str(_hit_note(model, hit))
	_emit(
		check,
		bearing and bearing_rays == 105 and bearing_patches == 1,
		(
			"105 exact native rays and one contained native patch prove actual guard-post bearing "
			+ "including the partial deck-edge joint"
		),
		{
			"first_failure": first_failure,
			"ray_count": bearing_rays,
			"patch_count": bearing_patches,
			"partial_bearing_patch": patch_proof
		}
	)
	var clear_access: bool = true
	var route: Array[Vector3] = [
		Vector3(-6.6, 0.04, 3.175),
		Vector3(0.7, 3, 3.175),
		Vector3(0.7, 3, 1.675),
		Vector3(-6, 5.8, 1.675),
		Vector3(-7.1, 5.8, 1.675),
		Vector3(-7.1, 5.8, -3.25),
		Vector3(0, 5.8, -3.25),
		Vector3(7.1, 5.8, -3.25),
		Vector3(7.1, 7.15, 0.75),
		Vector3(0, 7.15, 0.75)
	]
	for index in range(15):
		route.append(Vector3(-5.8 + index * 0.4, (index + 1) * 0.2, 3.175))
	for index in range(14):
		route.append(Vector3(-0.2 - index * 0.4, 3.2 + index * 0.2, 1.675))
	for point: Vector3 in route:
		clear_access = (
			clear_access
			and _ray(model, point + Vector3(0, 0.02, 0), point + Vector3(0, 1.8, 0)).is_empty()
		)
	_emit(
		check,
		clear_access,
		(
			"actual full stair turns side walks row approach and rear walkway have clear 1.80 m "
			+ "standing samples"
		)
	)
	var barrier: Dictionary = _ray(model, Vector3(0, 6.3, -3.9), Vector3(0, 6.3, -3.2))
	_emit(
		check,
		(
			not barrier.is_empty()
			and str(barrier.collider.name) == "FrontGuardRail0"
			and _ray(model, Vector3(0, 6.9, -3.9), Vector3(0, 6.9, -3.2)).is_empty()
		),
		"native contact hits the actual front safety rail and clears the real opening above it",
		{"barrier": _hit_note(model, barrier)}
	)


static func _joined_guard_bearing(model: Node3D, body: StaticBody3D, foot: AABB) -> Dictionary:
	# Only the documented LeftRowGuard2Post1/RowDeck2 joint is eligible.
	# The cube's top is at the post base, and its full 1 cm square lies within
	# the real 6 cm foot. This proves partial contact, not full-foot coverage.
	var deck_body: StaticBody3D = model.get_node("Collision/RowDeck2")
	var deck: AABB = _member(model, "RowDeck2")
	var hull: PackedVector3Array = _hull(model, "RowDeck2")
	var size: Vector3 = Vector3(0.01, 0.01, 0.01)
	var center: Vector3 = Vector3(
		foot.get_center().x, foot.position.y - 0.005, foot.get_center().z - 0.015
	)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape.margin = 0.0
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.margin = 0.0
	query.transform = model.global_transform * Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclude: Array[RID] = [body.get_rid()]
	query.exclude = exclude
	# Measure the actual submitted query pose after native world-coordinate
	# storage, rather than assuming its requested center stayed bit-exact.
	var actual_center: Vector3 = model.to_local(query.transform.origin)
	var patch: AABB = AABB(actual_center - size * 0.5, size)
	var foot_contains_patch: bool = (
		patch.position.x > foot.position.x
		and patch.end.x < foot.end.x
		and patch.position.z > foot.position.z
		and patch.end.z < foot.end.z
	)
	var exact_deck_box: bool = hull.size() == 8
	for corner in range(8):
		exact_deck_box = exact_deck_box and POINTS._has_point(hull, deck.get_endpoint(corner))
	var top_error: float = absf(patch.end.y - foot.position.y)
	var deck_contains_patch: bool = deck.encloses(patch)
	var geometry_ok: bool = (
		str(body.name) == "LeftRowGuard2Post1"
		and _same_box(foot, AABB(Vector3(-6.38, 6.70, -0.53), Vector3(0.06, 1.1, 0.06)))
		and _same_box(deck, AABB(Vector3(-6.4, 6.52, -1.5), Vector3(12.8, 0.18, 1.0)))
		and exact_deck_box
		and foot_contains_patch
		and deck_contains_patch
		and patch.end.y == foot.position.y
	)
	var native_deck_hit: bool = false
	var native_hits: Array[Dictionary] = []
	for hit: Dictionary in model.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var collider: Node = hit.get("collider")
		native_hits.append(
			{
				"collider": "" if collider == null else str(collider.name),
				"exact_row_deck2": collider == deck_body and hit.get("rid") == deck_body.get_rid()
			}
		)
		if collider == deck_body and hit.get("rid") == deck_body.get_rid():
			native_deck_hit = true
	return {
		"ok": geometry_ok and native_deck_hit,
		"post": str(body.name),
		"required_collider": "RowDeck2",
		"partial_bearing_only": true,
		"shape_margin": shape.margin,
		"query_margin": query.margin,
		"patch_center": [actual_center.x, actual_center.y, actual_center.z],
		"patch_min": [patch.position.x, patch.position.y, patch.position.z],
		"patch_max": [patch.end.x, patch.end.y, patch.end.z],
		"patch_size": [size.x, size.y, size.z],
		"foot_min": [foot.position.x, foot.position.y, foot.position.z],
		"foot_max": [foot.end.x, foot.end.y, foot.end.z],
		"deck_min": [deck.position.x, deck.position.y, deck.position.z],
		"deck_max": [deck.end.x, deck.end.y, deck.end.z],
		"top_to_base_error": top_error,
		"foot_contains_patch_xz": foot_contains_patch,
		"exact_native_box_hull": exact_deck_box,
		"deck_contains_patch": deck_contains_patch,
		"native_deck_hit": native_deck_hit,
		"native_hits": native_hits
	}


static func _self_sightlines(model: Node3D, check: Callable) -> void:
	var eyes: PackedVector3Array = M.eye_points()
	for index in range(eyes.size()):
		for target: Vector3 in [Vector3.ZERO, PitchBatLab.MOUND_ORIGIN]:
			var local_target: Vector3 = target - Vector3(-17, 0, 36)
			var hit: Dictionary = _ray(model, eyes[index], local_target)
			_emit(
				check,
				hit.is_empty(),
				"native full-solid seated sightline clears every bench deck support stair and guard",
				{
					"sample": index,
					"eye": str(eyes[index]),
					"world_target": str(target),
					"hit": _hit_note(model, hit)
				}
			)


static func _pose(model: Node3D, check: Callable) -> void:
	model.position = Vector3(-17, 0, 36)
	var visible: AABB = model.transform * SCAN._bounds(POINTS._points(model))
	var reserve: AABB = model.transform * M.envelope()
	_emit(
		check,
		(
			reserve == AABB(Vector3(-25, 0, 32), Vector3(16, 8.6, 8))
			and _same_box(visible, AABB(Vector3(-24.8, 0, 32.5), Vector3(15.6, 8.25, 7.3)))
			and reserve.grow(EPS).encloses(visible)
		),
		"actual fixed world placement stays inside x minus25 to minus9 and z32 to40",
		{"actual": str(visible)}
	)
	var physical: PackedVector3Array = []
	for body: StaticBody3D in model.get_node("Collision").get_children():
		for point: Vector3 in _hull(model, str(body.name)):
			physical.append(model.transform * point)
	_emit(
		check,
		(
			_same_box(SCAN._bounds(physical), visible)
			and model.basis == Basis.IDENTITY
			and model.scale == Vector3.ONE
			and M.WORLD_CENTER == model.position
		),
		"all real collision vertices preserve the same exact zero-yaw unit-size fixed pose"
	)
	var actual_eyes: bool = true
	for row in range(4):
		for column in range(3):
			actual_eyes = (
				actual_eyes
				and (
					(model.transform * M.eye_points()[row * 3 + column]).distance_to(
						Vector3([-23, -17, -11][column], 7.0 + row * 0.45, 33.0 + row)
					)
					< EPS
				)
			)
	_emit(
		check,
		actual_eyes,
		"all transformed row end and center eyes reach the actual approved world coordinates"
	)


static func _same_box(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) < EPS and a.size.distance_to(b.size) < EPS


static func _hull(model: Node3D, id: String) -> PackedVector3Array:
	return model.get_node("Collision/" + id + "/Solid").shape.points


static func _member(model: Node3D, id: String) -> AABB:
	return SCAN._bounds(_hull(model, id))


static func _guard_posts(model: Node3D) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if str(body.name).contains("Guard") and str(body.name).contains("Post"):
			result.append(body)
	return result


static func _physical_match(model: Node3D) -> bool:
	var bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
	if (
		bodies.size() != 327
		or M.solid_count() != 327
		or model.find_children("*", "CollisionShape3D", true, false).size() != 327
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
			collider.name != "Solid"
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
		if hull.size() != 8:
			return false
		for point: Vector3 in hull:
			if (
				not point.is_finite()
				or not M.ENVELOPE.grow(EPS).has_point(point)
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
		for key: String in [
			"owned_copy",
			"capacity",
			"revenue",
			"target_points",
			"water_scoring",
			"player_card",
			"night_bonus",
			"crowd_mechanic"
		]:
			if node.has_meta(key):
				return false
		if node.has_meta("stadium_item") and node.get_meta("stadium_item") != "ST-054":
			return false
		if (
			node is StaticBody3D
			and (
				node.get_meta("stadium_item", "") != "ST-054"
				or node.get_meta("surface_id", "") != str(node.name)
				or node.get_meta("ball_surface", "") != &"stadium_scenery"
				or node.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL"
			)
		):
			return false
	return model.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL"


static func _ray(model: Node3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		model.to_global(from), model.to_global(to), 1
	)
	query.exclude = exclude
	return model.get_world_3d().direct_space_state.intersect_ray(query)


static func _hit_height(model: Node3D, hit: Dictionary, height: float) -> bool:
	return (
		not hit.is_empty()
		and model.is_ancestor_of(hit.collider)
		and absf(model.to_local(hit.position).y - height) < 0.003
	)


static func _floor_hit(model: Node3D, point: Vector3) -> bool:
	return _hit_height(
		model, _ray(model, point + Vector3(0, 0.10, 0), point + Vector3(0, -0.10, 0)), point.y
	)


static func _hit_note(model: Node3D, hit: Dictionary) -> Dictionary:
	return (
		{}
		if hit.is_empty()
		else {"body": str(hit.collider.name), "local": str(model.to_local(hit.position))}
	)
