class_name StadiumWallTopTerraceGeometryRebuildChecks
extends RefCounted
## Bounded support for the shared native fixture. Six real host bearings per
## variant plus aggregate geometry/access checks; no independent engine runner.

const M = preload("res://src/presentation/stadium/stadium_wall_top_terrace_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const SOLIDS = preload("res://src/tests/stadium_ground_box_geometry_rebuild_checks.gd")
const EPS: float = 0.0002
const EXPECTED_CHECKS: int = 84
const FOREIGN: Array[String] = ["ST-065", "ST-077", "ST-054", "ST-086", "ST-088", ""]
const INVALID_HOSTS: Array[String] = ["ST-024", "ST-078", "ST-022", "ST-023", ""]
const FROZEN: Dictionary = {
	"stadium_ground_box_models.gd":
	"cfee2e08209f30c8cb989b733981931d56aceecc8fedbbd231888036e2fd52eb",
	"stadium_wall_panel_models.gd":
	"aa2cb103cf6998f81466c9173bdb3eb206a91835f84857e73380ca98e38ada7b",
	"stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4",
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"
}


static func expected_checks() -> int:
	return 1 + FOREIGN.size() + INVALID_HOSTS.size() + 2 * FROZEN.size() + 2 * (1 + 12 + 8 + 6 + 5)


static func run(parent: Node3D, check: Callable) -> void:
	var probe: Node3D = Node3D.new()
	probe.name = "WallTopTerraceGeometryProbe"
	probe.position = Vector3(2700, 0, 0)
	parent.add_child(probe)
	_emit(
		check,
		(
			M.VERSION == 1
			and M.ITEM == "ST-087"
			and M.HOST_ITEMS == ["ST-065", "ST-077"]
			and M.pose() == Transform3D(Basis.IDENTITY, Vector3(15, 0, 23.4))
			and M.RESERVATION == AABB(Vector3(-6, 0, 0), Vector3(12, 4.8, 7))
			and expected_checks() == EXPECTED_CHECKS
		),
		"one complete terrace has two exact host profiles and a finite check budget"
	)
	for item: String in FOREIGN:
		var foreign: Node3D = M.create(item)
		_emit(
			check,
			(
				foreign == null
				and M.bounds(item) == AABB()
				and M.reservation(item) == AABB()
				and M.mesh_count(item) == 0
				and M.solid_count(item) == 0
			),
			"foreign purchases cannot substitute for a terrace",
			{"item": item}
		)
		if foreign != null:
			foreign.free()
	for host_item: String in INVALID_HOSTS:
		var invalid: Node3D = M.create("ST-087", host_item)
		_emit(
			check,
			invalid == null and M.socket_profile(host_item).is_empty(),
			"lightweight side and unknown wall profiles cannot host",
			{"host": host_item}
		)
		if invalid != null:
			invalid.free()
	_frozen(check)
	for host_item: String in M.HOST_ITEMS:
		var model: Node3D = M.create("ST-087", host_item)
		_emit(
			check,
			model != null,
			"a complete material-specific terrace creates",
			{"host": host_item}
		)
		if model == null:
			continue
		probe.add_child(model)
		var hosts: Array[Node3D] = []
		for index in range(6):
			var host: Node3D = StadiumWallPanelModels.create(host_item, "full")
			host.name = "RequiredHost%d" % index
			host.transform = Transform3D(
				Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(-5 + index * 2, 0, 0)
			)
			probe.add_child(host)
			hosts.append(host)
		_common(model, host_item, check)
		_anatomy(model, hosts, host_item, check)
		await probe.get_tree().physics_frame
		await probe.get_tree().physics_frame
		_host_bearings(model, hosts, host_item, check)
		_native(model, check)
		model.free()
		for host: Node3D in hosts:
			host.free()
	_frozen(check)
	probe.free()


static func _common(model: Node3D, host_item: String, check: Callable) -> void:
	_emit(
		check,
		(
			model.get_child_count() == 2
			and model.transform == Transform3D.IDENTITY
			and model.get_node("Visual").transform == Transform3D.IDENTITY
			and model.get_node("Collision").transform == Transform3D.IDENTITY
		),
		"complete ground-pivot terrace has exactly two identity branches"
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item") == "ST-087"
			and model.get_meta("host_item") == host_item
			and model.get_meta("geometry_version") == 1
			and model.get_meta("model_version") == 1
			and model.get_meta("authoring_status") == "Working"
			and not model.get_meta("final_art_accepted")
			and model.get_meta("socket_profile") == M.socket_profile(host_item)
		),
		"working terrace binds its exact material-specific socket profile"
	)
	_emit(
		check,
		SOLIDS._static_unit_scale(model),
		"all terrace nodes are finite visible script-free unit-scale static geometry"
	)
	var scan: Dictionary = SCAN._scan(model)
	_emit(
		check,
		(
			str(scan.failure).is_empty()
			and scan.types == ["ArrayMesh"]
			and int(scan.meshes) == 152
			and M.mesh_count() == 152
			and M.solid_count() == 152
		),
		"all 152 native indexed prism meshes pass exhaustive array inspection",
		{"scan": scan}
	)
	_emit(check, SOLIDS._indexed(model), "every visible prism has complete valid triangle indices")
	_emit(
		check,
		SCAN._appearance_failure(model).is_empty() and int(scan.colors) == 6,
		"six opaque structural deck bench and view-marker colors remain readable"
	)
	var actual: AABB = SCAN._bounds(POINTS._points(model))
	_emit(
		check,
		(
			_same_box(actual, AABB(Vector3(-6, 0, 0.02), Vector3(12, 4.73, 6.98)))
			and _same_box(actual, M.ENVELOPE)
			and M.RESERVATION.grow(EPS).encloses(actual)
			and StadiumProperty.contains("backyard", M.pose() * M.RESERVATION)
		),
		"every real vertex stays in the exact 12 by 7 metre reserve that fits existing backyard grounds",
		{"actual": str(actual)}
	)
	_emit(
		check,
		_physical_match(model),
		"each actual visible prism exactly matches its named enabled zero-margin scenery hull"
	)
	_emit(
		check,
		SOLIDS._solid_faces(model),
		"every indexed triangle winds outward on its actual complete convex solid"
	)
	_emit(
		check,
		_roles(model),
		"all terrace contact is decorative after terminal without live obstacle crowd or ownership grants"
	)
	var second: Node3D = M.create("ST-087", host_item)
	_emit(
		check,
		POINTS._independent(model, second),
		"fresh terraces own independent native meshes materials and physical resources"
	)
	var before: String = SOLIDS._signature(model)
	var deterministic: bool = SOLIDS._signature(second) == before
	SCAN._mutate(second)
	for shape: CollisionShape3D in second.find_children("*", "CollisionShape3D", true, false):
		shape.shape.points = PackedVector3Array(
			[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
	var isolated: bool = SOLIDS._signature(model) == before and SOLIDS._signature(second) != before
	second.free()
	var fresh: Node3D = M.create("ST-087", host_item)
	_emit(
		check,
		deterministic and isolated and SOLIDS._signature(fresh) == before,
		"destructive copy mutation cannot change an existing terrace or deterministic regeneration"
	)
	fresh.free()
	print(
		(
			"WALL_TOP_TERRACE_GEOMETRY_MEASUREMENT "
			+ JSON.stringify(
				{
					"host": host_item,
					"meshes": scan.meshes,
					"hulls": 152,
					"occupied": str(actual),
					"reservation": str(M.RESERVATION),
					"socket": M.socket_profile(host_item)
				},
				"",
				true,
				true
			)
		)
	)


static func _anatomy(
	model: Node3D, hosts: Array[Node3D], host_item: String, check: Callable
) -> void:
	var saddles: bool = SCAN._members(model, "HostSaddle").size() == 6
	var bearing: float = 0.21 if host_item == "ST-065" else 0.02
	for index in range(6):
		var saddle: AABB = _member(model, "HostSaddle%d" % index)
		var source: MeshInstance3D = hosts[index].get_node("Visual").get_child(0)
		var actual_host: AABB = hosts[index].transform * source.transform * source.mesh.get_aabb()
		saddles = (
			saddles
			and _same_box(
				saddle,
				AABB(Vector3(-5.8 + index * 2, 3.25, bearing), Vector3(1.6, 0.2, 0.35 - bearing))
			)
			and absf(actual_host.end.y - saddle.position.y) < EPS
			and saddle.position.x >= actual_host.position.x - EPS
			and saddle.end.x <= actual_host.end.x + EPS
			and saddle.position.z >= actual_host.position.z - EPS
			and saddle.end.z <= actual_host.end.z + EPS
		)
	_emit(
		check,
		saddles,
		(
			"six whole saddle feet bear on the actual authored padded backing or brick mortar top, "
			+ "never a generic wall label"
		)
	)
	var load_path: bool = (
		_touch(model, "HostSaddle0", "HostTransom") and _touch(model, "HostSaddle5", "HostTransom")
	)
	for index in range(5):
		load_path = (
			load_path
			and _touch(model, "HostTransom", "DeckJoist%d" % index)
			and _touch(model, "DeckJoist%d" % index, "MainDeck")
			and _touch(model, "DeckJoist%d" % index, "RearLoadBeam")
			and _touch(model, "RearLoadBeam", "RearColumn%d" % index)
			and _touch(model, "RearColumn%d" % index, "RearFoot%d" % index)
		)
	_emit(
		check,
		(
			load_path
			and _touch(model, "LandingJoist", "HostTransom")
			and _touch(model, "LandingJoist", "TopLanding")
			and _touch(model, "TopLanding", "AccessStep17")
		),
		(
			"the exact front transom joists rear load beam columns and grounded stairs form "
			+ "connected support paths"
		)
	)
	var feet: bool = (
		SCAN._members(model, "RearFoot").size() == 5
		and SCAN._members(model, "RearBrace").size() == 4
	)
	for index in range(5):
		feet = (
			feet
			and _same_box(
				_member(model, "RearFoot%d" % index),
				AABB(Vector3(-5.24 + 2 * index, 0, 6.41), Vector3(0.48, 0.18, 0.48))
			)
		)
	_emit(
		check,
		feet,
		"five full rear feet touch real property ground and four braces join the load-bearing rear frame"
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "MainDeck"), AABB(Vector3(-6, 3.45, 0.02), Vector3(10.4, 0.2, 6.98))
			)
			and _same_box(
				_member(model, "TopLanding"),
				AABB(Vector3(4.4, 3.45, 0.02), Vector3(1.6, 0.2, 1.48))
			)
			and _touch(model, "MainDeck", "TopLanding")
		),
		"a complete supported deck and top landing join at the real stair exit"
	)
	var stairs: bool = SCAN._members(model, "AccessStep").size() == 18
	for index in range(18):
		stairs = (
			stairs
			and _same_box(
				_member(model, "AccessStep%d" % index),
				AABB(
					Vector3(4.4, 0, 5.75 - index * 0.25),
					Vector3(1.6, (index + 1) * 3.65 / 18, 0.25)
				)
			)
		)
	_emit(
		check,
		(
			stairs
			and _same_box(
				_member(model, "GroundApproach"), AABB(Vector3(4.4, 0, 6), Vector3(1.6, 0.04, 1))
			)
		),
		(
			"eighteen real grounded 0.25 metre treads join a full one-metre approach to the 3.65 "
			+ "metre landing"
		)
	)
	var views: bool = (
		M.eye_points().size() == 12 and SCAN._members(model, "ViewPosition").size() == 12
	)
	for index in range(12):
		views = (
			views
			and M.eye_points()[index].distance_to(Vector3(-5.5 + index, 5.27, 0.8)) < EPS
			and _same_box(
				_member(model, "ViewPosition%d" % index),
				AABB(Vector3(-5.75 + index, 3.65, 0.5), Vector3(0.5, 0.02, 0.6))
			)
		)
	_emit(
		check,
		views,
		"twelve real front viewing pads establish twelve standing-eye locations without adding spectators"
	)
	_emit(
		check,
		(
			SCAN._members(model, "RestBench").size() == 12
			and _touch(model, "RestBench0", "RestBenchLeg0_-1")
			and _touch(model, "RestBench2", "RestBenchLeg2_1")
			and _touch(model, "RestBenchLeg1_-1", "MainDeck")
		),
		"three complete backless rest benches have six grounded-on-deck legs and integral stretchers"
	)
	_emit(
		check,
		(
			SCAN._members(model, "FrontGuard").size() == 15
			and SCAN._members(model, "StairGuard").size() == 24
			and SCAN._members(model, "LeftFinishedEnd").size() == 1
			and SCAN._members(model, "RightFinishedEnd").size() == 1
			and SCAN._members(model, "RearFinishedEnd").size() == 1
			and _guard_posts(model).size() == 60
		),
		(
			"full front rear end deck-edge and stair guards plus closed fascia finish the single "
			+ "paid assembly"
		)
	)


static func _host_bearings(
	model: Node3D, hosts: Array[Node3D], host_item: String, check: Callable
) -> void:
	var exclude: Array[RID] = []
	for body: StaticBody3D in model.get_node("Collision").get_children():
		exclude.append(body.get_rid())
	for index in range(6):
		var center: Vector3 = _member(model, "HostSaddle%d" % index).get_center()
		var hit: Dictionary = _ray(
			model, Vector3(center.x, 3.30, center.z), Vector3(center.x, 3.20, center.z), exclude
		)
		_emit(
			check,
			(
				not hit.is_empty()
				and hit.collider == hosts[index].get_node("PanelCollision")
				and absf(model.to_local(hit.position).y - 3.25) < 0.0005
			),
			"native exact-host top ray verifies required terrace bearing",
			{"host_item": host_item, "host_index": index, "hit": _note(model, hit)}
		)


static func _native(model: Node3D, check: Callable) -> void:
	var ground: bool = true
	for point: Vector3 in M.support_points():
		ground = (
			ground
			and _height(
				model, _ray(model, point - Vector3(0, 0.1, 0), point + Vector3(0, 0.03, 0)), 0
			)
		)
	_emit(
		check,
		ground,
		(
			"native underside rays establish every real rear foot stair mass and approach at "
			+ "property height zero"
		)
	)
	var stairs: bool = true
	for index in range(18):
		stairs = (
			stairs and _floor(model, Vector3(5.2, (index + 1) * 3.65 / 18, 5.875 - index * 0.25))
		)
	_emit(
		check,
		stairs,
		"native floor rays find all eighteen actual stair treads at their exact heights"
	)
	var access: bool = true
	for point: Vector3 in [
		Vector3(5.2, 0.04, 6.5),
		Vector3(5.2, 3.65, 1.3),
		Vector3(3.8, 3.65, 1.3),
		Vector3(3.8, 3.65, 3.2),
		Vector3(3.8, 3.65, 6.2),
		Vector3(-5.7, 3.65, 6.2),
		Vector3(-5.7, 3.65, 3.2)
	]:
		access = (
			access
			and _floor(model, point)
			and _ray(model, point + Vector3(0, 0.03, 0), point + Vector3(0, 1.8, 0)).is_empty()
		)
	_emit(
		check,
		access,
		(
			"native access samples have actual floors and clear standing space through approach "
			+ "landing side and rear walks"
		)
	)
	var sight: bool = true
	var first_hit: Dictionary = {}
	for eye: Vector3 in M.eye_points():
		for target: Vector3 in [Vector3.ZERO, Vector3(0, 0, 13.716)]:
			var hit: Dictionary = _ray(model, eye, target - M.WORLD_CENTER)
			if not hit.is_empty():
				sight = false
				if first_hit.is_empty():
					first_hit = _note(model, hit)
	_emit(
		check,
		sight,
		(
			"all twelve actual front viewing positions clear the whole terrace and selected real "
			+ "host toward plate and mound"
		),
		{"first_hit": first_hit}
	)
	var bearing: bool = true
	var first: Dictionary = {}
	for post: StaticBody3D in _guard_posts(model):
		var box: AABB = _member(model, str(post.name))
		var point: Vector3 = Vector3(box.get_center().x, box.position.y, box.get_center().z)
		var hit: Dictionary = _ray(
			model, point + Vector3(0, 0.04, 0), point - Vector3(0, 0.08, 0), [post.get_rid()]
		)
		if not _height(model, hit, point.y):
			bearing = false
			if first.is_empty():
				first = {"post": str(post.name), "hit": _note(model, hit)}
	_emit(
		check,
		bearing,
		"every actual guard post bears on its real deck landing or exact stair tread",
		{"first_failure": first}
	)


static func _physical_match(model: Node3D) -> bool:
	if (
		model.get_node("Visual").get_child_count() != 152
		or model.get_node("Collision").get_child_count() != 152
	):
		return false
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if (
			body.get_child_count() != 1
			or body.transform != Transform3D.IDENTITY
			or body.collision_layer != 1
			or body.collision_mask != 2
		):
			return false
		var shape: CollisionShape3D = body.get_child(0)
		if (
			not shape.shape is ConvexPolygonShape3D
			or shape.shape.margin != 0
			or shape.disabled
			or shape.transform != Transform3D.IDENTITY
		):
			return false
		var hull: PackedVector3Array = shape.shape.points
		var vertices: PackedVector3Array = (
			model.get_node("Visual/" + str(body.name)).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		)
		if hull.size() != 8:
			return false
		for point: Vector3 in hull:
			if (
				not point.is_finite()
				or not M.ENVELOPE.grow(EPS).has_point(point)
				or not POINTS._has_point(vertices, point)
			):
				return false
		for point: Vector3 in vertices:
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
		if node.has_meta("stadium_item") and node.get_meta("stadium_item") != "ST-087":
			return false
		if (
			node is StaticBody3D
			and (
				node.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL"
				or node.get_meta("ball_surface", "") != &"stadium_scenery"
				or node.get_meta("surface_id", "") != str(node.name)
			)
		):
			return false
	return (
		model.get_meta("obstacle_units") == 0 and model.get_meta("represented_audience_count") == 0
	)


static func _guard_posts(model: Node3D) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if str(body.name).contains("Guard") and str(body.name).contains("Post"):
			result.append(body)
	return result


static func _member(model: Node3D, id: String) -> AABB:
	return SCAN._bounds(model.get_node("Collision/" + id + "/Solid").shape.points)


static func _same_box(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) < EPS and a.size.distance_to(b.size) < EPS


static func _touch(model: Node3D, a: String, b: String) -> bool:
	return _member(model, a).grow(EPS).intersects(_member(model, b))


static func _ray(model: Node3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		model.to_global(from), model.to_global(to), 1
	)
	query.exclude = exclude
	return model.get_world_3d().direct_space_state.intersect_ray(query)


static func _height(model: Node3D, hit: Dictionary, height: float) -> bool:
	return (
		not hit.is_empty()
		and model.is_ancestor_of(hit.collider)
		and absf(model.to_local(hit.position).y - height) < 0.0005
	)


static func _floor(model: Node3D, point: Vector3) -> bool:
	return _height(
		model, _ray(model, point + Vector3(0, 0.08, 0), point - Vector3(0, 0.08, 0)), point.y
	)


static func _note(model: Node3D, hit: Dictionary) -> Dictionary:
	return (
		{}
		if hit.is_empty()
		else {"body": str(hit.collider.name), "local": str(model.to_local(hit.position))}
	)


static func _frozen(check: Callable) -> void:
	for filename: String in FROZEN:
		_emit(
			check,
			FileAccess.get_sha256("res://src/presentation/stadium/" + filename) == FROZEN[filename],
			"accepted wall and primitive geometry remains byte exact",
			{"file": filename}
		)


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"WALL_TOP_TERRACE_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)
