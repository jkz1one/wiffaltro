class_name StadiumGroundBoxGeometryRebuildChecks
extends RefCounted
## Finite native support for the shared fixture, never another runner.
## Successful path: 1 + 6 foreign IDs + 2*5 frozen + 1 create + 17 common
## + 16 anatomy + 2*4 posed checks = 59. Six seats/figures are art, not capacity.

const M = preload("res://src/presentation/stadium/stadium_ground_box_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const EPS: float = 0.0002
const COMMON_CHECKS: int = 17
const ANATOMY_CHECKS: int = 16
const EXPECTED_CHECKS: int = 59
const FOREIGN: Array[String] = ["ST-051", "ST-057", "ST-080", "ST-027", "ST-029", ""]
const FROZEN: Dictionary = {
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
	"stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4",
	"stadium_seating_models.gd": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb",
	"stadium_bleacher_models.gd":
	"040edd83c323dc009cfa68d9a8fccfea7ac775dcb05097992cf816187a15c07c",
	"stadium_molded_seat_models.gd":
	"3ea9641a5607152e791cc61944bd52024bb7011c8cb116a913773fe065a90db6"
}


static func expected_checks() -> int:
	return 1 + FOREIGN.size() + 2 * FROZEN.size() + 1 + COMMON_CHECKS + ANATOMY_CHECKS + 2 * 4


static func run(parent: Node3D, check: Callable) -> void:
	var probe: Node3D = Node3D.new()
	probe.name = "GroundBoxGeometryProbe"
	probe.position = Vector3(1800, 0, 0)
	parent.add_child(probe)
	_emit(
		check,
		(
			M.VERSION == 1
			and M.ITEM == "ST-052"
			and expected_checks() == EXPECTED_CHECKS
			and M.ENVELOPE == AABB(Vector3(-2.75, 0, -2), Vector3(5.5, 2.2, 4))
		),
		"one bounded ground box factory and exact reachable geometry check budget"
	)
	for item: String in FOREIGN:
		var foreign: Node3D = M.create(item)
		_emit(
			check,
			foreign == null,
			"standalone seats, luxury suites and foreign items cannot substitute",
			{"item": item}
		)
		if foreign != null:
			foreign.free()
	_frozen(check)
	var model: Node3D = M.create()
	_emit(check, model != null, "one complete premium ground box section creates")
	if model != null:
		probe.add_child(model)
		await _common(probe, model, check)
		await _anatomy(model, check)
		await _posed(model, check)
		model.free()
	_frozen(check)
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"GROUND_BOX_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _frozen(check: Callable) -> void:
	for filename: String in FROZEN:
		_emit(
			check,
			FileAccess.get_sha256("res://src/presentation/stadium/" + filename) == FROZEN[filename],
			"all reused generic helpers and existing saleable seating factories remain byte exact",
			{"file": filename}
		)


static func _common(probe: Node3D, model: Node3D, check: Callable) -> void:
	var visual: Node3D = model.get_node("Visual")
	var collision: Node3D = model.get_node("Collision")
	_emit(
		check,
		(
			model.get_child_count() == 2
			and model.transform == Transform3D.IDENTITY
			and visual.transform == Transform3D.IDENTITY
			and collision.transform == Transform3D.IDENTITY
		),
		"complete ground-pivot assembly has exactly two identity branches"
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item") == "ST-052"
			and model.get_meta("geometry_version") == 1
			and model.get_meta("model_version") == 1
			and model.get_meta("envelope") == M.ENVELOPE
			and model.get_meta("static_geometry")
			and model.get_meta("scenery_only")
			and model.get_meta("obstacle_units") == 0
			and model.get_meta("physics_profile") == "DECORATIVE_AFTER_TERMINAL"
		),
		"one bounded section retains exact static decorative identity and zero obstacle units"
	)
	_emit(
		check,
		_static_unit_scale(model),
		"every actual descendant is static, finite, visible and unit scale without scripts"
	)
	var scan: Dictionary = SCAN._scan(model)
	_emit(
		check,
		(
			str(scan.failure).is_empty()
			and scan.types == ["ArrayMesh"]
			and scan.meshes == 111
			and M.MESH_COUNT == 111
			and int(scan.vertices) > 2000
		),
		"every native vertex normal and member validates across exactly 111 actual meshes",
		{"scan": scan}
	)
	_emit(
		check,
		_indexed(model),
		"all stored mesh surfaces have explicit nonempty valid triangle index streams"
	)
	_emit(
		check,
		SCAN._appearance_failure(model).is_empty() and int(scan.colors) >= 10,
		(
			"opaque readable stone, warm metal, cushioned seats and represented audience use plain "
			+ "independent materials"
		)
	)
	var actual: AABB = SCAN._bounds(POINTS._points(model))
	_emit(
		check,
		(
			_same_box(actual, AABB(Vector3(-2.75, 0, -2), Vector3(5.5, 1.54, 4)))
			and _same_box(actual, M.ACTUAL_BOUNDS)
			and M.ENVELOPE.grow(EPS).encloses(actual)
		),
		(
			"all actual geometry reaches the full ground footprint and measured 1.54-metre top "
			+ "inside 2.2-metre reserve"
		),
		{"actual": str(actual)}
	)
	_emit(
		check,
		_physical_match(model),
		"all 87 named zero-margin physical hulls match their exact visible solid vertices"
	)
	_emit(
		check,
		_solid_faces(model),
		"every rigid indexed triangle winds outward on its actual physical convex hull"
	)
	_emit(
		check,
		_roles(model),
		"all rigid bodies are decorative after terminal without scoring, live-play or revenue metadata"
	)
	var second: Node3D = M.create()
	probe.add_child(second)
	_emit(
		check,
		POINTS._independent(model, second),
		"all native meshes, materials and collision shapes are independent between sections"
	)
	var before: String = _signature(model)
	_emit(
		check,
		_signature(second) == before,
		"fresh complete sections reproduce identical real arrays and exact named physical state"
	)
	SCAN._mutate(second)
	for shape: CollisionShape3D in second.find_children("*", "CollisionShape3D", true, false):
		shape.shape.points = PackedVector3Array(
			[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
	_emit(
		check,
		_signature(model) == before and _signature(second) != before,
		"destructive native resource, material, physical and pose mutation cannot alter another section"
	)
	second.free()
	var fresh: Node3D = M.create()
	_emit(
		check,
		_signature(fresh) == before,
		"regeneration stays deterministic after mutation of another complete section"
	)
	fresh.free()
	await model.get_tree().process_frame
	_emit(
		check,
		_signature(model) == before,
		"an idle rendered frame cannot animate any figure, rail or physical shape"
	)
	_emit(
		check,
		_audience(model),
		(
			"six bounded static generic audience anchors are bundled art without collision or "
			+ "independent inventory"
		)
	)
	_emit(
		check,
		(
			model.get_meta("represented_seats") == 6
			and model.get_meta("represented_audience_count") == 6
			and model.get_meta("represented_audience")
			and model.get_meta("bundled_seating")
			and model.find_children("*Molded*", "", true, false).is_empty()
			and model.find_children("*ST051*", "", true, false).is_empty()
			and not model.has_meta("owned_copy")
		),
		"six broad seats are explicit represented artwork and never six saleable ST-051 copies"
	)
	print(
		(
			"GROUND_BOX_GEOMETRY_MEASUREMENT "
			+ JSON.stringify(
				{
					"meshes": scan.meshes,
					"vertices": scan.vertices,
					"visible_bounds": str(actual),
					"reservation": str(M.ENVELOPE),
					"physical_hulls": 87,
					"represented_seats": 6,
					"represented_figures": 6,
					"unit_scale": true
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
		(
			_same_box(
				_member(model, "GroundBase"), AABB(Vector3(-2.75, 0, -2), Vector3(4.4, 0.12, 4))
			)
			and _same_box(
				_member(model, "EntryLanding"),
				AABB(Vector3(1.65, 0, -0.9), Vector3(1.1, 0.12, 2.9))
			)
		),
		"real ground-supported split base fills the reservation without a coplanar approach overlay"
	)
	var ramp: PackedVector3Array = _hull(model, "LocalAccessRamp")
	_emit(
		check,
		(
			ramp.size() == 6
			and _same_box(
				_member(model, "LocalAccessRamp"),
				AABB(Vector3(1.65, 0, -2), Vector3(1.1, 0.12, 1.1))
			)
		),
		"small real access wedge remains entirely inside the right-rear reservation"
	)
	var arrays: Array = model.get_node("Visual/LocalAccessRamp").mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var normal: Vector3 = _stored_normal(Vector3(0, 1, -0.12 / 1.1).normalized())
	var slope_ok: bool = true
	var top_count: int = 0
	for index in range(vertices.size()):
		if normals[index].y > 0.5:
			top_count += 1
			slope_ok = (
				slope_ok
				and absf(vertices[index].y - (0.12 / 1.1) * (vertices[index].z + 2)) < EPS
				and normals[index] == normal
			)
	_emit(
		check,
		slope_ok and top_count >= 4,
		"actual ramp top follows its analytic slope with independently stored native normals"
	)
	var seams: bool = true
	for x: float in [1.65, 2.75]:
		seams = (
			seams
			and POINTS._has_point(ramp, Vector3(x, 0, -2))
			and POINTS._has_point(ramp, Vector3(x, 0.12, -0.9))
		)
	_emit(
		check,
		(
			seams
			and absf(_member(model, "EntryLanding").end.y - 0.12) < EPS
			and model.get_meta("local_approach_only")
			and not model.get_meta("connected_pedestrian_route")
		),
		"both true ramp endpoints join ground and landing without claiming a connected pedestrian route"
	)
	_emit(
		check,
		(
			SCAN._members(model, "FrontPost").size() == 5
			and SCAN._members(model, "RearPost").size() == 4
			and SCAN._members(model, "SidePost").size() == 4
			and model.has_node("Visual/EntryCornerPost")
			and SCAN._members(model, "FrontRail").size() == 2
			and SCAN._members(model, "RearRail").size() == 2
			and SCAN._members(model, "SideRail").size() == 4
		),
		"complete enclosure has fourteen supported posts and eight real rail members"
	)
	_emit(
		check,
		(
			absf(_member(model, "RearRail1").end.x - 1.465) < EPS
			and absf(_member(model, "EntryCornerPost").position.x - 2.575) < EPS
			and _member(model, "EntryCornerPost").position.y == 0
			and _member(model, "FrontRail1").end.y <= 1.24 + EPS
		),
		(
			"rear rail leaves a real 1.11-metre entrance and front rail remains below the "
			+ "represented eye level"
		)
	)
	var seat_parts: bool = true
	for index in range(6):
		seat_parts = seat_parts and SCAN._members(model, "BoxSeat%02d" % index).size() == 10
	_emit(
		check,
		seat_parts,
		"each of six broad bundled seats has ten real base, support, cushion, back and armrest parts"
	)
	var supported: bool = true
	var inward: bool = true
	var separated: bool = true
	for row in range(2):
		for place in range(3):
			var index: int = row * 3 + place
			var id: String = "BoxSeat%02d" % index
			var base: AABB = _member(model, id + "Base")
			var pedestal: AABB = _member(model, id + "Pedestal")
			var pan: AABB = _member(model, id + "PanFrame")
			var cushion: AABB = _member(model, id + "Cushion")
			var back: AABB = _member(model, id + "BackFrame")
			supported = (
				supported
				and absf(base.position.y - (0.12 if row == 0 else 0.30)) < EPS
				and absf(base.end.y - pedestal.position.y) < EPS
				and pedestal.grow(EPS).intersects(pan)
				and absf(pan.end.y - cushion.position.y) < EPS
				and pan.grow(EPS).intersects(back)
				and absf(cushion.size.x - 0.62) < EPS
			)
			inward = (
				inward and cushion.get_center().z > back.end.z and cushion.end.z > back.end.z + 0.5
			)
			separated = (
				separated
				and _member(model, id + "Arm1").end.x < 1.4
				and absf(base.get_center().x - [-1.65, -0.4, 0.85][place]) < EPS
				and absf(base.get_center().z - (0.55 if row == 0 else -0.9)) < EPS
			)
	_emit(
		check,
		supported,
		"every actual broad seat is supported continuously by its base, pedestal, frame and cushion"
	)
	_emit(
		check,
		inward and model.get_meta("facing") == Vector3.BACK,
		"actual seat fronts extend toward local plus Z with the tall backs behind them"
	)
	_emit(
		check,
		(
			separated
			and _member(model, "RearRowRiser").end.z < -0.149
			and _member(model, "BoxSeat00PanFrame").position.z > 0.229
		),
		"actual two-row seat spacing keeps the right aisle and between-row foot space clear"
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "RearRowRiser"),
				AABB(Vector3(-2.5, 0.12, -1.75), Vector3(3.9, 0.18, 1.6))
			)
			and _same_box(
				_member(model, "RearRowAccessStep"),
				AABB(Vector3(1.4, 0.12, -0.85), Vector3(0.4, 0.09, 0.7))
			)
		),
		"rear tier has one contained nine-centimetre intermediate access step on the actual base"
	)
	_emit(
		check,
		(
			_audience(model)
			and _same_box(SCAN._bounds(POINTS._points(model)), M.ACTUAL_BOUNDS)
			and model.find_children("*", "Area3D", true, false).is_empty()
			and model.find_children("*", "NavigationRegion3D", true, false).is_empty()
		),
		"bounded represented figures add neither sensors, navigation, simulation nor moving geometry"
	)
	await model.get_tree().physics_frame
	await model.get_tree().physics_frame
	var midpoint: Dictionary = _ray(model, Vector3(2.1, 1, -1.45), Vector3(2.1, -0.5, -1.45))
	_emit(
		check,
		(
			_hit_height(model, midpoint, 0.06)
			and _hit_height(
				model,
				_ray(model, Vector3(2.1, 1, -1.999), Vector3(2.1, -0.5, -1.999)),
				0.12 / 1100.0
			)
			and _hit_height(
				model,
				_ray(model, Vector3(2.1, 1, -0.901), Vector3(2.1, -0.5, -0.901)),
				0.12 - 0.12 / 1100.0
			)
		),
		"native rays hit the actual local ramp at midpoint and both near-endpoint heights",
		{"midpoint": _hit_note(model, midpoint)}
	)
	_emit(
		check,
		(
			_hit_height(model, _ray(model, Vector3(2.1, 1, 0.1), Vector3(2.1, -0.5, 0.1)), 0.12)
			and _hit_height(
				model, _ray(model, Vector3(-2.25, 1, -0.5), Vector3(-2.25, -0.5, -0.5)), 0.30
			)
		),
		"native rays hit the real landing and rear tier at their different supported heights"
	)
	_emit(
		check,
		(
			_ray(model, Vector3(2.1, 0.5, -2.1), Vector3(2.1, 0.5, 1.4)).is_empty()
			and _ray(model, Vector3(2.77, 1, -1.45), Vector3(2.77, -0.5, -1.45)).is_empty()
			and _ray(model, Vector3(-2.77, 1, 0), Vector3(-2.77, -0.5, 0)).is_empty()
		),
		"native rays prove the rear entrance and aisle are open with no invisible widened box solid"
	)
	var pan_hit: Dictionary = _ray(model, Vector3(-1.38, 1.1, 0.75), Vector3(-1.38, 0.2, 0.75))
	var back_hit: Dictionary = _ray(model, Vector3(-1.38, 1.02, 1.3), Vector3(-1.38, 1.02, -0.3))
	_emit(
		check,
		(
			_hit_height(model, pan_hit, 0.66)
			and str(pan_hit.collider.name) == "BoxSeat00Cushion"
			and not back_hit.is_empty()
			and str(back_hit.collider.name) == "BoxSeat00BackPad"
			and absf(model.to_local(back_hit.position).z - 0.30) < 0.003
		),
		"native rays hit the actual field-facing cushion and back pad without an imaginary seat volume",
		{"pan": _hit_note(model, pan_hit), "back": _hit_note(model, back_hit)}
	)


static func _posed(model: Node3D, check: Callable) -> void:
	for side: int in [-1, 1]:
		model.position = Vector3(side * 18.2, 0, 3)
		model.rotation.y = PI / 2.0 if side == -1 else -PI / 2.0
		var reserve: AABB = AABB(Vector3(side * 18.2 - 2, 0, 0.25), Vector3(4, 2.2, 5.5))
		var art: AABB = model.transform * SCAN._bounds(POINTS._points(model))
		_emit(
			check,
			(
				reserve.grow(EPS).encloses(art)
				and _same_box(art, AABB(Vector3(side * 18.2 - 2, 0, 0.25), Vector3(4, 1.54, 5.5)))
			),
			"all posed actual art preserves the exact four-by-five-and-a-half world footprint",
			{"side": side, "actual": str(art)}
		)
		var physical: PackedVector3Array = []
		for body: StaticBody3D in model.get_node("Collision").get_children():
			for point: Vector3 in _hull(model, str(body.name)):
				physical.append(model.transform * point)
		var box: AABB = SCAN._bounds(physical)
		_emit(
			check,
			(
				reserve.grow(EPS).encloses(box)
				and absf(box.position.y) < EPS
				and absf(box.size.x - 4) < EPS
				and absf(box.size.z - 5.5) < EPS
			),
			"every actual posed collision vertex remains inside the fixed world reservation",
			{"side": side, "physical": str(box)}
		)
		var field: Vector3 = Vector3(-side, 0, 0)
		var direction: Vector3 = model.basis * Vector3.BACK
		var front: Vector3 = model.transform * _member(model, "BoxSeat00Cushion").get_center()
		var rear: Vector3 = model.transform * _member(model, "BoxSeat00BackFrame").get_center()
		_emit(
			check,
			(
				direction.dot(field) > 0.99999
				and (front - rear).dot(field) > 0.2
				and model.scale.is_equal_approx(Vector3.ONE)
			),
			"both exact quarter-turn orientations face the real seats inward without scaling",
			{"side": side, "facing": str(direction)}
		)
		await model.get_tree().physics_frame
		await model.get_tree().physics_frame
		_emit(
			check,
			(
				_hit_height(
					model, _ray(model, Vector3(2.1, 1, -1.45), Vector3(2.1, -0.5, -1.45)), 0.06
				)
				and _ray(model, Vector3(2.1, 0.5, -2.1), Vector3(2.1, 0.5, 1.4)).is_empty()
			),
			"native transformed ramp and entrance contacts preserve the approved left and right placement",
			{"side": side}
		)


static func _same_box(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) < EPS and a.size.distance_to(b.size) < EPS


static func _hull(model: Node3D, id: String) -> PackedVector3Array:
	return model.get_node("Collision/" + id + "/Solid").shape.points


static func _member(model: Node3D, id: String) -> AABB:
	return SCAN._bounds(_hull(model, id))


static func _signature(model: Node3D) -> String:
	return (
		POINTS._visual_signature(model)
		+ var_to_bytes(POINTS._physical_state(model)).hex_encode().sha256_text()
	)


static func _static_unit_scale(root: Node3D) -> bool:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
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
				not node.visible
				or node.top_level
				or not node.position.is_finite()
				or node.basis != Basis.IDENTITY
				or node.scale != Vector3.ONE
			)
		):
			return false
	return true


static func _indexed(model: Node3D) -> bool:
	for member: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(member.mesh.get_surface_count()):
			var arrays: Array = member.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_INDEX] == null:
				return false
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if indices.is_empty() or indices.size() % 3 != 0:
				return false
			for index: int in indices:
				if index < 0 or index >= vertices.size():
					return false
	return true


static func _physical_match(model: Node3D) -> bool:
	var bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
	if (
		bodies.size() != 87
		or M.SOLID_COUNT != 87
		or model.find_children("*", "CollisionShape3D", true, false).size() != 87
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
				or not M.ENVELOPE.grow(EPS).has_point(point)
				or not POINTS._has_point(visible, point)
			):
				return false
		for point: Vector3 in visible:
			if not POINTS._has_point(hull, point):
				return false
	return true


static func _solid_faces(model: Node3D) -> bool:
	for body: StaticBody3D in model.get_node("Collision").get_children():
		var hull: PackedVector3Array = _hull(model, str(body.name))
		var arrays: Array = model.get_node("Visual/" + str(body.name)).mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[index]]
			var b: Vector3 = vertices[indices[index + 1]]
			var c: Vector3 = vertices[indices[index + 2]]
			var cross_value: Vector3 = -(b - a).cross(c - a)
			var normal: Vector3 = normals[indices[index]]
			if cross_value.length_squared() < 1e-12 or cross_value.normalized().dot(normal) < 0.999:
				return false
			for point: Vector3 in hull:
				if normal.dot(point - a) > EPS:
					return false
	return true


static func _roles(model: Node3D) -> bool:
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "", true, false))
	for node: Node in nodes:
		for forbidden: String in [
			"owned_copy",
			"volume_id",
			"target_points",
			"water_scoring",
			"live_furnishing",
			"revenue",
			"capacity",
			"player_card"
		]:
			if node.has_meta(forbidden):
				return false
		if node.has_meta("stadium_item") and node.get_meta("stadium_item") != "ST-052":
			return false
		if (
			node is StaticBody3D
			and (
				node.get_meta("stadium_item", "") != "ST-052"
				or node.get_meta("surface_id", "") != str(node.name)
				or node.get_meta("ball_surface", "") != &"stadium_scenery"
				or node.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL"
			)
		):
			return false
	return model.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL"


static func _audience(model: Node3D) -> bool:
	var anchors: Array[Node] = model.find_children("CrowdAnchor*", "Node3D", true, false)
	if anchors.size() != 6:
		return false
	for index in range(6):
		var anchor: Node3D = model.get_node("Visual/CrowdAnchor%d" % index)
		var row: int = 0 if index < 3 else 1
		var expected: Vector3 = Vector3(
			[-1.65, -0.4, 0.85][index % 3],
			0.66 if row == 0 else 0.84,
			0.585 if row == 0 else -0.865
		)
		if (
			not anchor.position.is_equal_approx(expected)
			or not anchor.get_meta("represented_audience", false)
			or anchor.get_child_count() != 4
			or anchor.has_meta("owned_copy")
			or anchor.has_meta("stadium_item")
		):
			return false
		for member: Node in anchor.get_children():
			if not member is MeshInstance3D or not member.mesh is ArrayMesh:
				return false
	return true


static func _stored_normal(analytic: Vector3) -> Vector3:
	# Independent analytic direction, compared after the same native storage format.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.BACK]:
		surface.set_normal(analytic)
		surface.add_vertex(vertex)
	surface.index()
	var mesh: ArrayMesh = surface.commit()
	var stored: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	return stored[0]


static func _ray(model: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		model.to_global(from), model.to_global(to), 1
	)
	return model.get_world_3d().direct_space_state.intersect_ray(query)


static func _hit_height(model: Node3D, hit: Dictionary, height: float) -> bool:
	return (
		not hit.is_empty()
		and model.is_ancestor_of(hit.collider)
		and absf(model.to_local(hit.position).y - height) < 0.003
	)


static func _hit_note(model: Node3D, hit: Dictionary) -> Dictionary:
	return (
		{}
		if hit.is_empty()
		else {"body": str(hit.collider.name), "local": str(model.to_local(hit.position))}
	)
