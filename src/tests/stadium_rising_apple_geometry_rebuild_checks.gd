class_name StadiumRisingAppleGeometryRebuildChecks
extends RefCounted
## Finite support for the shared native fixture, never a separate runner.
## 1 contract + 6 foreign + 2*4 frozen + 1 create + 16 common + 12 anatomy
## + 5*6 pose + 1 exact restoration + 5 invalid heights + 1 foreign pose = 81.

const M = preload("res://src/presentation/stadium/stadium_rising_apple_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const SOLIDS = preload("res://src/tests/stadium_ground_box_geometry_rebuild_checks.gd")
const EPS: float = 0.0002
const COMMON_CHECKS: int = 16
const ANATOMY_CHECKS: int = 12
const POSES: Array[float] = [0.0, 0.8, 1.6, 2.4, 3.2]
const INVALID_HEIGHTS: Array[float] = [-0.01, 3.21, INF, -INF, NAN]
const EXPECTED_CHECKS: int = 81
const FOREIGN: Array[String] = ["ST-046", "ST-048", "ST-049", "ST-050", "ST-054", ""]
const FROZEN: Dictionary = {
	"stadium_landmark_models.gd":
	"3e8e16c6a858fd89240faca6dbedd14e9b0ddcacdf503d445fbfa62b42e28f84",
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
	"stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4",
	"stadium_outfield_bleacher_models.gd":
	"b76c7798c102c499b00afab4b6ae91a9fd4964e30bb3ebca90cfcd4e8c696570"
}

# Only independently reviewed format-only successors; original FROZEN hashes remain valid.
const APPLE_FORMATTED_GEOMETRY: Dictionary = {
	"stadium_landmark_models.gd":
	"1e9f5c1ca94ac18dfed2e57d0d56502abe6c2b32e083a3db6cdeef4e6fd4b6a8",
	"stadium_ground_props_models.gd":
	"970c40bf95fce1e80161c96239f0823280d06ae96b96dd0516734b580a87dba1",
	"stadium_outfield_bleacher_models.gd":
	"aaf5b61d8c75cc7818a7ef5f5c6898f37e5accce0ea707bf14d41fd29047d548"
}


static func expected_checks() -> int:
	return (
		1
		+ FOREIGN.size()
		+ 2 * FROZEN.size()
		+ 1
		+ COMMON_CHECKS
		+ ANATOMY_CHECKS
		+ POSES.size() * 6
		+ 1
		+ INVALID_HEIGHTS.size()
		+ 1
	)


static func run(parent: Node3D, check: Callable) -> void:
	var probe: Node3D = Node3D.new()
	probe.name = "RisingAppleGeometryProbe"
	probe.position = Vector3(2500, 0, 0)
	parent.add_child(probe)
	_emit(
		check,
		(
			M.VERSION == 1
			and M.ITEM == "ST-047"
			and M.ITEMS == ["ST-047"]
			and M.MAX_RISE == 3.2
			and M.ENVELOPE == AABB(Vector3(-3, 0, -3), Vector3(6, 8, 6))
			and expected_checks() == EXPECTED_CHECKS
		),
		"one complete rising apple declares its finite geometry inventory and source-derived check budget"
	)
	for item: String in FOREIGN:
		var foreign: Node3D = M.create(item)
		_emit(
			check,
			(
				foreign == null
				and M.bounds(item) == AABB()
				and M.envelope(item) == AABB()
				and M.visible_bounds(item) == AABB()
				and M.swept_bounds(item) == AABB()
				and M.mesh_count(item) == 0
				and M.solid_count(item) == 0
				and M.support_points(item).is_empty()
			),
			"foreign inventory never borrows the rising apple model or physical reservation",
			{"item": item}
		)
		if foreign != null:
			foreign.free()
	_frozen(check)
	var model: Node3D = M.create()
	_emit(
		check,
		model != null,
		"the complete apple drum guide fruit stem leaf and every physical solid create"
	)
	if model != null:
		probe.add_child(model)
		await _common(probe, model, check)
		_anatomy(model, check)
		_poses(model, check)
		_rejected(model, check)
		model.free()
	_frozen(check)
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"RISING_APPLE_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _frozen(check: Callable) -> void:
	for filename: String in FROZEN:
		_emit(
			check,
			_apple_geometry_source_matches(filename),
			"reused factories are original or exact profiled format-only successors",
			{"file": filename}
		)


static func _common(probe: Node3D, model: Node3D, check: Callable) -> void:
	var moving: Node3D = model.get_node("RisingAssembly")
	_emit(
		check,
		(
			model.get_child_count() == 3
			and moving.get_child_count() == 2
			and model.transform == Transform3D.IDENTITY
			and moving.transform == Transform3D.IDENTITY
			and not moving.visible
			and model.get_node("Visual").transform == Transform3D.IDENTITY
			and model.get_node("Collision").transform == Transform3D.IDENTITY
			and moving.get_node("Visual").transform == Transform3D.IDENTITY
			and moving.get_node("Collision").transform == Transform3D.IDENTITY
		),
		"one complete apple has fixed visual and collision branches plus one shared movable assembly"
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item") == "ST-047"
			and model.get_meta("geometry_version") == 1
			and model.get_meta("model_version") == 1
			and model.get_meta("authoring_status") == "Working"
			and not model.get_meta("final_art_accepted")
			and model.get_meta("confirmed_result_only")
			and not model.get_meta("animated_during_pitch")
			and model.get_meta("obstacle_units") == 0
		),
		(
			"working presentation geometry reserves movement for a confirmed result without "
			+ "claiming final art acceptance"
		)
	)
	_emit(
		check,
		_static_unit_scale(model),
		(
			"every node is script-free finite unit-scale geometry; only the whole apple inherits "
			+ "owned reset concealment"
		)
	)
	var scan: Dictionary = SCAN._scan(model)
	_emit(
		check,
		(
			str(scan.failure).is_empty()
			and scan.types == ["ArrayMesh"]
			and int(scan.meshes) == 69
			and M.mesh_count() == 69
			and M.solid_count() == 69
			and int(scan.vertices) > 2500
			and int(scan.vertices) < 15000
		),
		(
			"all sixty-nine actual complete indexed meshes pass exhaustive native surface and "
			+ "array inspection"
		),
		{"scan": scan}
	)
	_emit(
		check,
		SOLIDS._indexed(model),
		"every actual surface has a complete explicit nonempty valid triangle-index array"
	)
	_emit(
		check,
		SCAN._appearance_failure(model).is_empty() and int(scan.colors) >= 10,
		(
			"opaque independently owned stone metal red fruit green leaf and wood materials form "
			+ "readable physical artwork"
		),
		{"colors": scan.colors}
	)
	var actual: AABB = SCAN._bounds(POINTS._points(model))
	_emit(
		check,
		(
			_same_box(actual, AABB(Vector3(-2.9, 0, -2.9), Vector3(5.8, 4.65, 5.8)))
			and M.visible_bounds() == M.DOWN_BOUNDS
			and M.bounds() == M.ENVELOPE
			and M.swept_bounds() == AABB(Vector3(-2.9, 0, -2.9), Vector3(5.8, 7.85, 5.8))
			and model.get_meta("visible_bounds") == M.DOWN_BOUNDS
			and model.get_meta("swept_bounds") == M.SWEPT_BOUNDS
			and model.get_meta("envelope") == M.ENVELOPE
			and M.ENVELOPE.encloses(M.SWEPT_BOUNDS)
		),
		(
			"all actual initial geometry and declared swept bounds fit the exact "
			+ "six-by-six-by-eight reservation"
		),
		{"actual": str(actual)}
	)
	_emit(
		check,
		_physical_match(model),
		(
			"all sixty-nine enabled zero-margin hulls match authored mesh solids exactly, "
			+ "including the ten intentionally retained concealed apple hulls"
		)
	)
	_emit(
		check,
		SOLIDS._solid_faces(model) and SOLIDS._solid_faces(moving),
		(
			"every fixed and moving triangle winds outward on its actual convex hull without "
			+ "reservation proxies"
		)
	)
	_emit(
		check,
		_roles(model),
		(
			"model anatomy introduces no scoring receiver sensor revenue training clock light "
			+ "audio or extra mechanics"
		)
	)
	var second: Node3D = M.create()
	probe.add_child(second)
	_emit(
		check,
		POINTS._independent(model, second),
		"purchased copies share no native mesh material or collision resource"
	)
	var before: String = SOLIDS._signature(model)
	_emit(
		check,
		SOLIDS._signature(second) == before,
		"fresh complete rising apples reproduce identical physical and visible state"
	)
	SCAN._mutate(second)
	M.set_rise(second, 3.2)
	for shape: CollisionShape3D in second.find_children("*", "CollisionShape3D", true, false):
		shape.shape.points = PackedVector3Array(
			[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
	_emit(
		check,
		SOLIDS._signature(model) == before and SOLIDS._signature(second) != before,
		"destructive native mesh material hull and pose mutation remains isolated to the altered copy"
	)
	second.free()
	var fresh: Node3D = M.create()
	_emit(
		check,
		SOLIDS._signature(fresh) == before,
		"regeneration stays deterministic after destructive mutation of a different copy"
	)
	fresh.free()
	await model.get_tree().process_frame
	_emit(
		check,
		SOLIDS._signature(model) == before and M.rise_height(model) == 0.0,
		"an idle rendered frame never anticipates an outcome or moves any apple part"
	)
	_emit(
		check,
		_ground_supports(model),
		"all five support points lie on the actual grounded convex plinth rather than its reservation"
	)
	print(
		(
			"RISING_APPLE_GEOMETRY_MEASUREMENT "
			+ JSON.stringify(
				{
					"item": "ST-047",
					"meshes": scan.meshes,
					"vertices": scan.vertices,
					"physical_hulls": model.find_children("*", "StaticBody3D", true, false).size(),
					"fixed_hulls": model.get_node("Collision").get_child_count(),
					"moving_hulls": moving.get_node("Collision").get_child_count(),
					"support_points": M.support_points().size(),
					"down_bounds": str(actual),
					"swept_bounds": str(M.swept_bounds()),
					"reservation": str(M.envelope()),
					"rise_metres": M.MAX_RISE,
					"final_art_accepted": false
				},
				"",
				true,
				true
			)
		)
	)


static func _anatomy(model: Node3D, check: Callable) -> void:
	_emit(
		check,
		_same_box(
			_member(model, "AppleGroundPlinth"),
			AABB(Vector3(-2.9, 0, -2.9), Vector3(5.8, 0.30, 5.8))
		),
		"the complete landmark bears on a real five-point-eight-metre grounded circular plinth"
	)
	var shell: bool = (
		(
			model
			. get_node("Visual")
			. find_children("AppleHatBody*", "MeshInstance3D", false, false)
			. size()
		)
		== 16
	)
	var band: bool = (
		(
			model
			. get_node("Visual")
			. find_children("AppleHatBand*", "MeshInstance3D", false, false)
			. size()
		)
		== 16
	)
	for index in range(16):
		var body: AABB = _member(model, "AppleHatBody%02d" % index)
		var stripe: AABB = _member(model, "AppleHatBand%02d" % index)
		shell = shell and absf(body.position.y - 0.46) < EPS and absf(body.end.y - 4.25) < EPS
		band = band and absf(stripe.position.y - 3.92) < EPS and absf(stripe.end.y - 4.25) < EPS
	_emit(
		check,
		(
			shell
			and band
			and absf(_member(model, "AppleDrumFoot").position.y - 0.30) < EPS
			and absf(_member(model, "AppleDrumFoot").end.y - 0.46) < EPS
		),
		(
			"sixteen true hollow body sectors rise from the grounded foot and carry a "
			+ "sixteen-sector brass hat band"
		)
	)
	var rim: bool = (
		(
			model
			. get_node("Visual")
			. find_children("AppleHatBrim*", "MeshInstance3D", false, false)
			. size()
		)
		== 16
	)
	for index in range(16):
		var box: AABB = _member(model, "AppleHatBrim%02d" % index)
		rim = rim and absf(box.position.y - 4.25) < EPS and absf(box.end.y - 4.50) < EPS
		for point: Vector3 in (
			model.get_node("Collision/AppleHatBrim%02d/Solid" % index).shape.points
		):
			rim = rim and Vector2(point.x, point.z).length() >= 1.90 - EPS
	_emit(
		check,
		rim and _member(model, "AppleLiftGuide").end.y < 4.50 and _hat_aperture_clear(model),
		(
			"sixteen wide hat-brim solids keep every actual moving vertex at least five "
			+ "centimetres inside the true aperture and cover the fixed guide from ordinary external "
			+ "views"
		)
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "AppleLiftGuide"),
				AABB(Vector3(-0.18, 0.30, -0.18), Vector3(0.36, 4.02, 0.36))
			)
			and _member(model, "AppleLiftGuide").grow(EPS).intersects(
				_member(model, "AppleGroundPlinth")
			)
		),
		(
			"an actual narrow grounded lift guide supports every authored pose without hidden "
			+ "below-ground geometry"
		)
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "AppleLiftCarriage", true),
				AABB(Vector3(-0.95, 1.10, -0.95), Vector3(1.9, 0.28, 1.9))
			)
			and _member(model, "AppleLiftCarriage", true).intersects(
				_member(model, "AppleLowerBody", true)
			)
		),
		"the real sliding carriage bears the complete lower apple body"
	)
	_emit(
		check,
		(
			_member(model, "AppleLowerBody", true).intersects(_member(model, "AppleMainBody", true))
			and _same_box(
				_member(model, "AppleMainBody", true),
				AABB(Vector3(-1.75, 1.50, -1.65), Vector3(3.5, 2.6, 3.3))
			)
		),
		"a full tapered lower fruit and broad red main body create a complete three-dimensional apple"
	)
	_emit(
		check,
		(
			_member(model, "AppleShoulderLeft", true).intersects(
				_member(model, "AppleMainBody", true)
			)
			and _member(model, "AppleShoulderRight", true).intersects(
				_member(model, "AppleMainBody", true)
			)
			and (
				absf(
					(
						_member(model, "AppleShoulderLeft", true).position.x
						+ _member(model, "AppleShoulderRight", true).end.x
					)
				)
				< EPS
			)
			and absf(_member(model, "AppleShoulderLeft", true).end.y - 4.20) < EPS
		),
		"two broad upper shoulders produce the lobed apple silhouette around a center crown"
	)
	_emit(
		check,
		(
			_member(model, "AppleCrownDimple", true).intersects(
				_member(model, "AppleShoulderLeft", true)
			)
			and _member(model, "AppleCrownDimple", true).intersects(
				_member(model, "AppleShoulderRight", true)
			)
			and _member(model, "AppleCrownDimple", true).intersects(
				_member(model, "AppleStem", true)
			)
		),
		"a real contrasting center dimple joins both upper lobes to the woody stem"
	)
	_emit(
		check,
		(
			absf(_member(model, "AppleStem", true).end.y - 4.65) < EPS
			and _member(model, "AppleStem", true).grow(EPS).encloses(
				AABB(Vector3(-0.18, 4.08, -0.18), Vector3(0.36, 0.24, 0.36))
			)
		),
		(
			"complete wood stem retains the original four-point-six-five-metre authored resting "
			+ "height inside the reset-hidden assembly"
		)
	)
	_emit(
		check,
		(
			_member(model, "AppleLeafStalk", true).intersects(_member(model, "AppleStem", true))
			and _member(model, "AppleLeafStalk", true).intersects(_member(model, "AppleLeaf", true))
			and _member(model, "AppleLeaf", true).size.z > 0.79
			and _member(model, "AppleLeaf", true).size.y > 0.18
			and _member(model, "AppleLeafVein", true).grow(0.03).intersects(
				_member(model, "AppleLeaf", true)
			)
		),
		"thick broad pointed leaf has an actual joining stalk and a raised visible vein"
	)
	_emit(
		check,
		(
			(
				(
					model
					. get_node("Visual")
					. find_children("ApplePlaqueRivet*", "MeshInstance3D", false, false)
					. size()
				)
				== 2
			)
			and (
				(
					model
					. get_node("Visual")
					. find_children("AppleBaseBolt*", "MeshInstance3D", false, false)
					. size()
				)
				== 4
			)
			and _member(model, "AppleFrontPlaque").intersects(_member(model, "ApplePlaqueInset"))
		),
		(
			"complete fixed presentation base includes front plaque inset two rivets and four "
			+ "grounded anchor bolts"
		)
	)
	_emit(
		check,
		(
			model.get_node("Visual").get_child_count() == 59
			and model.get_node("Collision").get_child_count() == 59
			and model.get_node("RisingAssembly/Visual").get_child_count() == 10
			and model.get_node("RisingAssembly/Collision").get_child_count() == 10
			and _same_box(
				SCAN._bounds(POINTS._points(model.get_node("RisingAssembly"))),
				AABB(Vector3(-1.78, 1.10, -1.65), Vector3(3.56, 3.55, 3.3))
			)
		),
		(
			"one supported moving assembly contains the entire fruit carriage shoulders dimple "
			+ "stem stalk leaf and vein"
		)
	)


static func _poses(model: Node3D, check: Callable) -> void:
	var moving: Node3D = model.get_node("RisingAssembly")
	var initial: String = SOLIDS._signature(model)
	var fixed: String = _fixed_signature(model)
	var payload: String = SOLIDS._signature(moving)
	var metadata: String = _metadata_signature(model)
	var resources: Array[Resource] = POINTS._resources(model)
	var original_points: PackedVector3Array = _moving_points(model)
	var swept: AABB = SCAN._bounds(POINTS._points(model))
	for rise: float in POSES:
		var expected_pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, rise, 0))
		var accepted: bool = M.set_rise(model, rise)
		var actual: AABB = SCAN._bounds(POINTS._points(model))
		swept = swept.merge(actual)
		_emit(
			check,
			(
				accepted
				and M.rise_height(model) == expected_pose.origin.y
				and moving.transform == expected_pose
				and moving.visible == (expected_pose.origin.y > 0.0)
				and _same_box(actual, AABB(Vector3(-2.9, 0, -2.9), Vector3(5.8, 4.65 + rise, 5.8)))
				and _same_box(actual, M.visible_bounds("ST-047", rise))
				and M.SWEPT_BOUNDS.grow(EPS).encloses(actual)
			),
			(
				"the owned pose API translates one complete assembly and reveals it only above reset "
				+ "within the unchanged sweep"
			),
			{"rise": rise, "actual": str(actual)}
		)
		_emit(
			check,
			_physical_match(model) and SOLIDS._solid_faces(model) and SOLIDS._solid_faces(moving),
			"every moved visible solid and enabled decorative hull still coincide exactly at this pose",
			{"rise": rise}
		)
		_emit(
			check,
			(
				_fixed_signature(model) == fixed
				and _metadata_signature(model) == metadata
				and SOLIDS._signature(moving) == payload
				and POINTS._resources(model) == resources
			),
			(
				"posing changes no fixed geometry resource hull material or metadata and preserves "
				+ "complete moving anatomy"
			),
			{"rise": rise}
		)
		var points: PackedVector3Array = _moving_points(model)
		var translated: bool = points.size() == original_points.size()
		for index in range(points.size()):
			translated = (
				translated
				and points[index].distance_to(original_points[index] + Vector3(0, rise, 0)) < EPS
			)
		_emit(
			check,
			translated and _static_unit_scale(model),
			(
				"all actual moving vertices translate by the same exact vertical displacement without "
				+ "scaling or missing parts"
			),
			{"rise": rise}
		)
		var guide: AABB = _member(model, "AppleLiftGuide")
		var carriage: AABB = _member(model, "AppleLiftCarriage", true)
		_emit(
			check,
			(
				_ground_supports(model)
				and guide.intersects(carriage)
				and carriage.position.y >= 1.10 - EPS
				and guide.end.y - carriage.position.y >= 0.02 - EPS
			),
			(
				"actual grounded lift guide and visible carriage retain positive support overlap "
				+ "throughout the entire rise"
			),
			{"rise": rise}
		)
		var site: Transform3D = Transform3D(Basis.IDENTITY, Vector3(36.5, 0, 44))
		var reservation: AABB = AABB(Vector3(30, 0, 39), Vector3(13, 8, 10))
		var fitted: bool = (
			reservation.grow(EPS).encloses(site * actual)
			and reservation.grow(EPS).encloses(site * M.ENVELOPE)
		)
		for point: Vector3 in M.support_points():
			fitted = (
				fitted
				and absf((site * point).y) < EPS
				and reservation.grow(EPS).has_point(site * point)
			)
		_emit(
			check,
			fitted and site.basis == Basis.IDENTITY,
			(
				"all actual posed geometry and grounded support fit the sole primary LANDMARK-A "
				+ "reservation unscaled"
			),
			{"rise": rise, "world": str(site * actual)}
		)
	_emit(
		check,
		(
			M.set_rise(model, 0.0)
			and SOLIDS._signature(model) == initial
			and _metadata_signature(model) == metadata
			and _same_box(swept, M.SWEPT_BOUNDS)
			and M.rise_height(model) == 0.0
			and not moving.visible
		),
		(
			"restoring the down pose exactly restores every visible and physical byte while the "
			+ "complete sweep reaches only seven-point-eight-five metres"
		)
	)


static func _rejected(model: Node3D, check: Callable) -> void:
	var before: String = SOLIDS._signature(model) + _metadata_signature(model)
	for rise: float in INVALID_HEIGHTS:
		_emit(
			check,
			(
				not M.set_rise(model, rise)
				and M.visible_bounds("ST-047", rise) == AABB()
				and SOLIDS._signature(model) + _metadata_signature(model) == before
				and M.rise_height(model) == 0.0
				and not model.get_node("RisingAssembly").visible
			),
			(
				"nonfinite or out-of-reservation pose input fails closed without changing any "
				+ "geometry or authority"
			),
			{"height": str(rise)}
		)
	var foreign: Node3D = Node3D.new()
	foreign.set_meta("stadium_item", "ST-048")
	_emit(
		check,
		(
			not M.set_rise(null, 1.0)
			and not M.set_rise(foreign, 1.0)
			and M.rise_height(null) == 0.0
			and M.rise_height(foreign) == 0.0
			and foreign.get_child_count() == 0
		),
		"missing and foreign models cannot receive or manufacture a rising apple pose"
	)
	foreign.free()


static func _same_box(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) < EPS and a.size.distance_to(b.size) < EPS


static func _member(model: Node3D, id: String, moving: bool = false) -> AABB:
	var mesh: MeshInstance3D = model.get_node(
		("RisingAssembly/" if moving else "") + "Visual/" + id
	)
	var points: PackedVector3Array = []
	for surface in range(mesh.mesh.get_surface_count()):
		for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			points.append(POINTS._local_pose(model, mesh) * point)
	return SCAN._bounds(points)


static func _moving_points(model: Node3D) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var moving: Node3D = model.get_node("RisingAssembly")
	for point: Vector3 in POINTS._points(moving):
		result.append(moving.transform * point)
	return result


static func _fixed_signature(model: Node3D) -> String:
	return (
		SOLIDS._signature(model.get_node("Visual")) + SOLIDS._signature(model.get_node("Collision"))
	)


static func _metadata_signature(model: Node3D) -> String:
	var state: Array = []
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "", true, false))
	for node: Node in nodes:
		for key: StringName in node.get_meta_list():
			state.append([str(model.get_path_to(node)), str(key), node.get_meta(key)])
	return var_to_bytes(state).hex_encode().sha256_text()


static func _ground_supports(model: Node3D) -> bool:
	var base: MeshInstance3D = model.get_node("Visual/AppleGroundPlinth")
	var arrays: Array = base.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var points: PackedVector3Array = M.support_points()
	if points.size() != 5:
		return false
	for point: Vector3 in points:
		if not point.is_finite() or absf(point.y) > EPS:
			return false
		for index in range(vertices.size()):
			if normals[index].dot(point - vertices[index]) > EPS:
				return false
	return true


static func _physical_match(model: Node3D) -> bool:
	var bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
	if (
		bodies.size() != 69
		or model.find_children("*", "CollisionShape3D", true, false).size() != 69
	):
		return false
	for body: StaticBody3D in bodies:
		var branch: Node3D = body.get_parent().get_parent()
		if (
			branch not in [model, model.get_node("RisingAssembly")]
			or body.get_parent() != branch.get_node("Collision")
			or body.get_child_count() != 1
			or body.transform != Transform3D.IDENTITY
			or body.collision_layer != 1
			or body.collision_mask != 2
			or body.constant_linear_velocity != Vector3.ZERO
			or body.constant_angular_velocity != Vector3.ZERO
		):
			return false
		var collider: CollisionShape3D = body.get_child(0)
		var mesh: MeshInstance3D = branch.get_node("Visual/" + str(body.name))
		if (
			str(collider.name) != "Solid"
			or not collider.shape is ConvexPolygonShape3D
			or collider.disabled
			or collider.shape.margin != 0.0
			or collider.transform != Transform3D.IDENTITY
			or POINTS._local_pose(model, collider) != POINTS._local_pose(model, mesh)
		):
			return false
		var visible: PackedVector3Array = []
		for surface in range(mesh.mesh.get_surface_count()):
			visible.append_array(mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
		var hull: PackedVector3Array = collider.shape.points
		for point: Vector3 in hull:
			if (
				not point.is_finite()
				or not POINTS._has_point(visible, point)
				or not M.ENVELOPE.grow(EPS).has_point(POINTS._local_pose(model, collider) * point)
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
			"night_profile",
			"water_entry"
		]:
			if node.has_meta(forbidden):
				return false
		if node.has_meta("stadium_item") and node.get_meta("stadium_item") != "ST-047":
			return false
		if (
			node.get_class() not in ["Node3D", "MeshInstance3D", "StaticBody3D", "CollisionShape3D"]
			or node.get_script() != null
			or node.is_processing()
			or node.is_physics_processing()
		):
			return false
		if (
			node is StaticBody3D
			and (
				node.get_meta("stadium_item", "") != "ST-047"
				or node.get_meta("surface_id", "") != str(node.name)
				or node.get_meta("ball_surface", "") != &"stadium_scenery"
				or node.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL"
			)
		):
			return false
	return (
		model.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL"
		and model.get_meta("physics_profile") == "DECORATIVE_AFTER_TERMINAL"
		and model.get_meta("scenery_only")
		and not model.get_meta("static_geometry")
		and not model.get_meta("ball_award_enabled")
		and not model.get_meta("water_entry_enabled")
		and model.get_meta("ambient_ball_count") == 0
	)


static func _static_unit_scale(model: Node3D) -> bool:
	# The sole permitted invisible node is the whole runtime-owned moving assembly at reset.
	# Its visible children retain their own flags; inherited concealment therefore holds even overhead.
	var moving: Node3D = model.get_node("RisingAssembly")
	var shown: bool = M.rise_height(model) > 0.0
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "", true, false))
	for node: Node in nodes:
		if (
			node.get_class() not in ["Node3D", "MeshInstance3D", "StaticBody3D", "CollisionShape3D"]
			or node.get_script() != null
			or node.is_processing()
			or node.is_physics_processing()
		):
			return false
		if (
			node is Node3D
			and (
				node.visible != (shown if node == moving else true)
				or node.top_level
				or not node.position.is_finite()
				or node.basis != Basis.IDENTITY
				or node.scale != Vector3.ONE
			)
		):
			return false
	for mesh: MeshInstance3D in moving.find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree() != shown:
			return false
	return true


static func _hat_aperture_clear(model: Node3D) -> bool:
	# A convex moving hull stays in the clear aperture whenever all its actual vertices do.
	# Pure vertical translation cannot change these sixteen horizontal supporting-plane tests.
	var inradius: float = 1.90 * cos(PI / 16.0)
	for point: Vector3 in POINTS._points(model.get_node("RisingAssembly")):
		for index in range(16):
			var angle: float = TAU * (index + 0.5) / 16.0
			if inradius - Vector2(point.x, point.z).dot(Vector2(cos(angle), sin(angle))) < 0.05:
				return false
	return true


static func _apple_geometry_source_matches(filename: String) -> bool:
	if not FROZEN.has(filename):
		return false
	var digest: String = FileAccess.get_sha256("res://src/presentation/stadium/" + filename)
	if digest == FROZEN[filename]:
		return true
	return (
		APPLE_FORMATTED_GEOMETRY.has(filename)
		and digest == APPLE_FORMATTED_GEOMETRY[filename]
		and StadiumPoolPartyAI22RetainedContract.inventory_matches()
		and StadiumNpcSourceQualification.matches_current(StadiumNpcPublicRuntime.SOURCE_PINS)
	)
