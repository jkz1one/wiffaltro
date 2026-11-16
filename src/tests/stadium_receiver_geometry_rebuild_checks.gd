class_name StadiumReceiverGeometryRebuildChecks
extends RefCounted
## Bounded geometry helper for the shared receiver qualification. No independent runner.

const EPS: float = 0.0002
const EXPECTED_CHECKS: int = 145
const RESERVATION: AABB = AABB(Vector3(-5.25, 0, -5.25), Vector3(10.5, 7.0, 4.75))
const FROZEN: Dictionary = {
	"stadium_receiver_net_models.gd":
	"cec34955f5d8d52b9a7df68034667cb2ba10fab29aaf612f257f0fe20a2ad7ef",
	"stadium_target_models.gd": "0334e3bc2588f17a2a7ec1f6d64209dedea8336c67461930415248f228d7ba0a",
	"stadium_seating_models.gd": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb",
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"
}


class GeometryProbe:
	extends "res://src/tests/stadium_grand_three_stack_geometry_test_support.gd"

	func _ready() -> void:
		pass


static func run(parent: Node3D, check: Callable) -> void:
	var probe: GeometryProbe = GeometryProbe.new()
	parent.add_child(probe)
	probe.position = Vector3(500, 0, 0)
	_emit(
		check,
		(
			StadiumReceiverOwnedModels.VERSION == 1
			and StadiumReceiverOwnedModels.ITEMS == ["ST-072", "ST-073"]
		),
		"one owned factory covers exactly the two requested catching assemblies"
	)
	_emit(
		check,
		(
			StadiumReceiverOwnedModels.position("ST-072") == Vector3(0, 0, -2.65)
			and StadiumReceiverOwnedModels.position("ST-073") == Vector3.ZERO
		),
		"placement API preserves cage offset and frozen net pose zero"
	)
	_frozen(check)
	var originals: Dictionary = {
		"ST-073": StadiumReceiverNetModels.create(),
		"ST-026": StadiumTargetModels.create(),
		"ST-079": StadiumStarterModels.create("ST-079")
	}
	var before: Dictionary = {}
	var regenerated: Dictionary = {}
	for item: String in originals:
		before[item] = _branches(probe, originals[item])
		regenerated[item] = _canonical_branches(probe, originals[item])
	for item: String in StadiumReceiverOwnedModels.ITEMS:
		var model: Node3D = await _model(probe, item, check)
		if model == null:
			continue
		if item == "ST-072":
			_cage(probe, model, check)
		else:
			_net(model, originals["ST-073"], check)
		_flex(probe, model, check)
		_primary_fit(probe, model, originals, check)
		model.free()
	_rejections(check)
	for item: String in originals:
		var fresh: Node3D = (
			StadiumReceiverNetModels.create()
			if item == "ST-073"
			else (
				StadiumTargetModels.create()
				if item == "ST-026"
				else StadiumStarterModels.create("ST-079")
			)
		)
		_emit(
			check,
			(
				_branches(probe, originals[item]) == before[item]
				and _canonical_branches(probe, fresh) == regenerated[item]
			),
			"owned creation and flex preserve existing and freshly regenerated frozen geometry",
			{"item": item}
		)
		fresh.free()
		originals[item].free()
	_frozen(check)
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"RECEIVER_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _frozen(check: Callable) -> void:
	for file: String in FROZEN:
		var actual: String = FileAccess.get_sha256("res://src/presentation/stadium/" + file)
		_emit(
			check,
			actual == FROZEN[file],
			"reused receiver and primitive factories remain byte-for-byte frozen",
			{"file": file, "expected": FROZEN[file], "actual": actual}
		)
	_emit(
		check,
		(
			FileAccess.get_sha256("res://src/gameplay/stadium/stadium_wall_recipes.gd")
			== "2225255afd3ded7bddb8a94ac1ee639e91a4c2c77806e17f70db21f13fd822e5"
		),
		"reused panel placement helper remains byte-for-byte frozen"
	)


static func _branches(probe: GeometryProbe, model: Node3D) -> String:
	return (
		probe._grand_snapshot(model.get_node("Visual"))
		+ probe._grand_snapshot(model.get_node("Collision"))
	)


static func _canonical_branches(probe: GeometryProbe, model: Node3D) -> String:
	var result: String = ""
	for branch: String in ["Visual", "Collision"]:
		var state: Array = []
		probe._grand_node_state(model.get_node(branch), state)
		# Preserve the established generated-mesh counter fix, never discard geometry.
		for index in range(state.size()):
			var entry: Array = state[index]
			if entry[1] == "MeshInstance3D" and str(entry[0]).begins_with("@MeshInstance3D@"):
				entry[0] = "@generated:%s:%d" % [entry[1], index]
		result += var_to_bytes(state).hex_encode().sha256_text()
	return result


static func _row(item: String) -> Dictionary:
	return {
		"copy": "GEOMETRY:" + item,
		"item": item,
		"site": "RECEIVER-CATCH",
		"position": StadiumReceiverOwnedModels.position(item),
		"yaw": 0.0
	}


static func _model(probe: GeometryProbe, item: String, check: Callable) -> Node3D:
	var row: Dictionary = _row(item)
	var model: Node3D = StadiumReceiverOwnedModels.create(item, row)
	_emit(check, model != null, "exact-copy receiver assembly is created", {"item": item})
	if model == null:
		return null
	probe.add_child(model)
	await probe.get_tree().process_frame
	await probe.get_tree().physics_frame
	await probe.get_tree().physics_frame
	_emit(
		check,
		_ownership(model, row),
		"every root branch mesh body and shape owns the exact copy item and site",
		{"item": item}
	)
	var identity: bool = model.transform == Transform3D.IDENTITY
	for branch: String in ["Visual", "Collision"]:
		identity = identity and model.get_node(branch).transform == Transform3D.IDENTITY
	for node: Node3D in model.find_children("*", "Node3D", true, false):
		identity = (
			identity
			and node.position.is_finite()
			and node.basis.is_finite()
			and node.basis.determinant() > 0
			and not node.top_level
		)
	_emit(
		check,
		identity,
		"placement stays external and all authored transforms are finite positive-handed",
		{"item": item}
	)
	var actual: AABB = _bounds(probe, model)
	var reserve: AABB = StadiumReceiverOwnedModels.envelope(item)
	_emit(
		check,
		reserve.grow(EPS).encloses(actual) and model.get_meta("envelope") == reserve,
		"complete measured visible and physical assembly fits its conservative bound",
		{"item": item, "actual": str(actual), "reserve": str(reserve)}
	)
	var world: AABB = AABB(actual.position + StadiumReceiverOwnedModels.position(item), actual.size)
	_emit(
		check,
		RESERVATION.grow(EPS).encloses(world),
		"actual full assembly fits the unchanged v4 receiver reservation",
		{"item": item, "actual": str(world)}
	)
	_emit(
		check,
		_physical(model, item, row),
		"unique named bodies and shapes carry fixed rest collision and exact owned surface IDs",
		{"item": item}
	)
	return model


static func _ownership(model: Node3D, row: Dictionary) -> bool:
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "", true, false))
	for node: Node in nodes:
		if (
			node.get_meta("owned_copy", "") != row.copy
			or node.get_meta("paid_copy", "") != row.copy
			or node.get_meta("stadium_item", "") != row.item
			or node.get_meta("site", "") != row.site
			or node.get_meta("receiver_owned", false) != true
			or node.get_meta("surface_role", "") != "RECEIVER_CONTAINMENT_FOUL"
			or node.get_meta("ball_surface", "") != &"stadium_receiver"
		):
			return false
	return true


static func _physical(model: Node3D, item: String, row: Dictionary) -> bool:
	var bodies: Node = model.get_node("Collision")
	if bodies.get_child_count() != (19 if item == "ST-072" else 13):
		return false
	var names: Array[String] = []
	var shapes: Array[String] = []
	var seen: Array[String] = []
	for body: StaticBody3D in bodies.get_children():
		var id: String = str(body.get_meta("surface_id", ""))
		if (
			names.has(str(body.name))
			or str(body.name).begins_with("@")
			or body.get_meta("owned_body_id", "") != str(row.copy) + ":" + str(body.name)
			or body.get_meta("owned_surface_id", "") != str(row.copy) + ":" + id
			or not StadiumReceiverOwnedModels.surfaces(item).has(id)
			or body.collision_layer != 1
			or body.collision_mask != 2
			or body.get_child_count() != 1
		):
			return false
		names.append(str(body.name))
		if not seen.has(id):
			seen.append(id)
		var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
		if (
			shape == null
			or shape.shape == null
			or shape.disabled
			or shape.shape.margin != 0
			or shape.transform != Transform3D.IDENTITY
			or str(shape.name) != str(body.name) + "Shape"
			or shapes.has(str(shape.name))
			or shape.get_meta("surface_id", "") != id
		):
			return false
		shapes.append(str(shape.name))
	seen.sort()
	var expected: Array[String] = StadiumReceiverOwnedModels.surfaces(item)
	expected.sort()
	return seen == expected


static func _bounds(probe: GeometryProbe, model: Node3D) -> AABB:
	var points: PackedVector3Array = probe._all_points(model)
	var inverse: Transform3D = model.global_transform.affine_inverse()
	var result: AABB = AABB(inverse * points[0], Vector3.ZERO)
	for point: Vector3 in points:
		result = result.expand(inverse * point)
	return result


static func _member_bounds(model: Node3D, id: String) -> AABB:
	var mesh: MeshInstance3D = model.get_node("Visual/" + id)
	return mesh.transform * mesh.get_aabb()


static func _cage(probe: GeometryProbe, model: Node3D, check: Callable) -> void:
	var front_x: float = 2.20 + 1.20 * tan(deg_to_rad(42.0))
	_emit(
		check,
		absf(front_x - StadiumReceiverOwnedModels.CAGE_FRONT_X) < EPS,
		"front-post centers independently derive from the corrected 42-degree foul-line direction"
	)
	for side: int in [-1, 1]:
		var rear: Node3D = model.get_node("Collision/ST072_PostRear%d" % side)
		var front: Node3D = model.get_node("Collision/ST072_PostFront%d" % side)
		_emit(
			check,
			(
				rear.position.is_equal_approx(Vector3(side * 2.20, 1.56, 0))
				and front.position.is_equal_approx(Vector3(side * front_x, 1.56, 1.20))
			),
			"actual front and rear posts form an outward opening cup",
			{"side": side}
		)
		var direction: Vector2 = (
			Vector2(front.position.x - rear.position.x, front.position.z - rear.position.z)
			. normalized()
		)
		_emit(
			check,
			(
				direction.distance_to(Vector2(side * sin(deg_to_rad(42.0)), cos(deg_to_rad(42.0))))
				< EPS
			),
			"each actual wing is parallel to its outward foul-line direction",
			{"side": side}
		)
		var post_shape: CapsuleShape3D = front.get_child(0).shape as CapsuleShape3D
		_emit(
			check,
			(
				post_shape != null
				and absf(post_shape.radius - 0.05) < EPS
				and absf(absf(front.position.x) + post_shape.radius - 3.330484853157408) < EPS
			),
			"front posts have exact 50mm radius and corrected 3.330485m outer front edge",
			{"side": side}
		)
	for id: String in StadiumReceiverOwnedModels.CAGE_PANELS:
		var body: StaticBody3D = model.get_node("Collision/" + id)
		var shape: BoxShape3D = body.get_child(0).shape as BoxShape3D
		var mesh: MeshInstance3D = model.get_node("Visual/" + id)
		var ends: Array = StadiumReceiverOwnedModels.CAGE_PANELS[id]
		var pose: Transform3D = StadiumWallRecipes.placement({"a": ends[0], "b": ends[1]})
		_emit(
			check,
			(
				shape != null
				and shape.size.is_equal_approx(Vector3(ends[0].distance_to(ends[1]), 2.80, 0.006))
				and body.position.is_equal_approx(pose.origin + Vector3(0, 1.55, 0))
				and body.basis.is_equal_approx(pose.basis)
				and mesh.transform.is_equal_approx(pose)
			),
			"each continuous thin mesh collider exactly matches its authored chain plane",
			{"surface": id}
		)
		var bounds: AABB = mesh.get_aabb()
		_emit(
			check,
			(
				absf(bounds.position.y - 0.15) < EPS
				and absf(bounds.end.y - 2.95) < EPS
				and absf(bounds.size.z) < EPS
				and mesh.material_override.metallic > 0.6
				and mesh.get_meta("diamond_pitch") == 0.05
				and mesh.get_meta("wire_width") == 0.003
			),
			"chain diamonds remain metallic, thin and fully inside the authored mesh height",
			{"surface": id}
		)
	_emit(
		check,
		(
			StadiumReceiverOwnedModels.CAGE_GRID < 0.073
			and model.get_node("Collision").get_child_count() == 19
		),
		(
			"diamonds are smaller than the unchanged ball without per-wire collision or a solid "
			+ "cage footprint"
		)
	)
	var no_front: bool = true
	var no_top: bool = true
	for x: float in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		for y: float in [0.2, 1.55, 2.9]:
			no_front = no_front and not _occupied(model, Vector3(x, y, 1.20))
		for z: float in [0.2, 0.6, 1.0]:
			no_top = no_top and not _occupied(model, Vector3(x, 3.11, z))
	_emit(
		check,
		no_front and model.get_meta("open_front", false),
		"actual central front aperture stays open with no center barrier"
	)
	_emit(
		check,
		no_top and model.get_meta("open_top", false),
		"actual overhead opening stays open above the bounded cage"
	)
	var physical_solids: bool = true
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if StadiumReceiverOwnedModels.CAGE_PANELS.has(str(body.name)):
			continue
		var mesh: MeshInstance3D = model.get_node("Visual/" + str(body.name))
		var shape: Shape3D = body.get_child(0).shape
		physical_solids = physical_solids and body.transform == mesh.transform
		if shape is CapsuleShape3D:
			physical_solids = (
				physical_solids
				and mesh.mesh is CapsuleMesh
				and shape.radius == mesh.mesh.radius
				and shape.height == mesh.mesh.height
			)
		elif shape is BoxShape3D:
			physical_solids = (
				physical_solids and mesh.mesh is BoxMesh and shape.size == mesh.mesh.size
			)
		else:
			physical_solids = false
	_emit(
		check,
		physical_solids,
		"every non-panel frame and support collider exactly matches its visible solid"
	)
	for side: int in [-1, 1]:
		for suffix: String in ["Rear", "Front"]:
			var foot: Node3D = model.get_node("Collision/ST072_Foot%s%d" % [suffix, side])
			var post: Node3D = model.get_node("Collision/ST072_Post%s%d" % [suffix, side])
			var bound: AABB = _member_bounds(model, "ST072_Foot%s%d" % [suffix, side])
			_emit(
				check,
				absf(bound.position.y) < EPS and probe._contact(foot, post),
				"each real post bears on a grounded physical foot",
				{"side": side, "position": suffix}
			)
		var brace: Node3D = model.get_node("Collision/ST072_RearBrace%d" % side)
		_emit(
			check,
			(
				probe._contact(brace, model.get_node("Collision/ST072_FootRear%d" % side))
				and probe._contact(brace, model.get_node("Collision/ST072_PostRear%d" % side))
			),
			"each rear brace joins its actual foot and rear post",
			{"side": side}
		)
	var camera_clear: bool = true
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if body.get_meta("surface_id") == "ST072_SUPPORTS":
			var bound: AABB = _member_bounds(model, str(body.name))
			camera_clear = (
				camera_clear
				and (bound.end.x < -0.18 or bound.position.x > 0.18)
				and bound.position.z >= -0.40001
			)
	_emit(
		check,
		camera_clear,
		"rear supports stay behind the cup within 0.40m and never occupy the central camera line"
	)
	_emit(
		check,
		(
			absf(_member_bounds(model, "ST072_RearRailBottom").get_center().y - 0.12) < EPS
			and absf(_member_bounds(model, "ST072_RearRailTop").get_center().y - 3.0) < EPS
			and _bounds(probe, model).end.y <= 3.10 + EPS
		),
		"actual rails retain archived bottom/top centers and the complete cage remains at most 3.10m high"
	)


static func _occupied(model: Node3D, point: Vector3) -> bool:
	for body: StaticBody3D in model.get_node("Collision").get_children():
		var shape: Shape3D = body.get_child(0).shape
		var local: Vector3 = body.transform.affine_inverse() * point
		if shape is BoxShape3D:
			if AABB(-shape.size / 2, shape.size).grow(EPS).has_point(local):
				return true
		elif shape is CapsuleShape3D:
			var half: float = maxf(0, shape.height / 2 - shape.radius)
			var axis: Vector3 = Vector3(0, clampf(local.y, -half, half), 0)
			if local.distance_to(axis) <= shape.radius + EPS:
				return true
		elif shape is CylinderShape3D:
			if (
				absf(local.y) <= shape.height / 2 + EPS
				and Vector2(local.x, local.z).length() <= shape.radius + EPS
			):
				return true
	return false


static func _net(model: Node3D, original: Node3D, check: Callable) -> void:
	_emit(
		check,
		StadiumReceiverNetModels.VERSION == 2 and _geometry_same(model, original),
		"owned stadium net preserves every v2 mesh vertex material transform and collision shape"
	)
	_emit(
		check,
		(
			StadiumReceiverOwnedModels.envelope("ST-073")
			== AABB(Vector3(-5.1, 0, -5.15), Vector3(10.2, 6.9, 2.75))
		),
		"stadium net keeps the frozen full bound and zero external offset"
	)
	var counts: Dictionary = {"panels": 0, "lines": 0, "poles": 0, "anchors": 0}
	for body: StaticBody3D in model.get_node("Collision").get_children():
		var id: String = str(body.name)
		if StadiumReceiverNetModels.PANELS.has(id):
			counts.panels += 1
		elif id.contains("_LINE_"):
			counts.lines += 1
		elif id.begins_with("ST073_POLE"):
			counts.poles += 1
		elif id.begins_with("ST073_ANCHOR"):
			counts.anchors += 1
	_emit(
		check,
		counts == {"panels": 3, "lines": 6, "poles": 2, "anchors": 2},
		"complete net retains three panels six boundary lines two poles and two anchors",
		counts
	)
	for id: String in StadiumReceiverNetModels.PANELS:
		var endpoints: Array = StadiumReceiverNetModels.PANELS[id]
		var body: StaticBody3D = model.get_node("Collision/" + id)
		var pose: Transform3D = StadiumWallRecipes.placement({"a": endpoints[0], "b": endpoints[1]})
		_emit(
			check,
			(
				body.position.is_equal_approx(pose.origin + Vector3(0, 3.375, 0))
				and body.basis.is_equal_approx(pose.basis)
			),
			"corrected net panel keeps its field-facing cup pose",
			{"surface": id}
		)
	var center: Node3D = model.get_node("Collision/ST073_CENTER_NET")
	var right: Node3D = model.get_node("Collision/ST073_POLE1")
	var left: Node3D = model.get_node("Collision/ST073_POLE-1")
	_emit(
		check,
		(
			center.position.z < right.position.z
			and center.position.z < left.position.z
			and absf(right.position.x) > 2
			and absf(left.position.x) > 2
		),
		"actual net opens outward toward the field rather than back toward the camera"
	)
	_emit(
		check,
		not _occupied(model, Vector3(0, 3, -2.7)) and not _occupied(model, Vector3(0, 7.0, -3.5)),
		"net front and overhead remain real openings with no extra invisible closure"
	)


static func _geometry_same(actual: Node3D, original: Node3D) -> bool:
	for branch: String in ["Visual", "Collision"]:
		var a: Node = actual.get_node(branch)
		var b: Node = original.get_node(branch)
		if a.get_child_count() != b.get_child_count():
			return false
		for index in range(a.get_child_count()):
			var one: Node3D = a.get_child(index)
			var two: Node3D = b.get_child(index)
			if (
				one.name != two.name
				or one.transform != two.transform
				or one.get_class() != two.get_class()
			):
				return false
			if one is MeshInstance3D:
				if (
					(
						StadiumCurvedCanopySites._resource(one.mesh)
						!= StadiumCurvedCanopySites._resource(two.mesh)
					)
					or (
						StadiumCurvedCanopySites._resource(one.material_override)
						!= StadiumCurvedCanopySites._resource(two.material_override)
					)
				):
					return false
			elif (
				one.get_child_count() != 1
				or two.get_child_count() != 1
				or one.get_child(0).transform != two.get_child(0).transform
				or (
					StadiumCurvedCanopySites._resource(one.get_child(0).shape)
					!= StadiumCurvedCanopySites._resource(two.get_child(0).shape)
				)
			):
				return false
	return true


static func _flex(probe: GeometryProbe, model: Node3D, check: Callable) -> void:
	var cage: bool = model.get_meta("stadium_item") == "ST-072"
	var panels: Dictionary = (
		StadiumReceiverOwnedModels.CAGE_PANELS if cage else StadiumReceiverNetModels.PANELS
	)
	var settle: float = 0.35 if cage else 0.55
	var maximum: float = 0.08 if cage else 0.25
	var collision_before: String = probe._grand_snapshot(model.get_node("Collision"))
	for id: String in panels:
		var mesh: MeshInstance3D = model.get_node("Visual/" + id)
		var rest: PackedVector3Array = mesh.get_meta("rest_vertices")
		var impact: Vector3 = mesh.transform * Vector3(0, 1.55 if cage else 3.375, 0)
		for elapsed: float in [0.0, settle / 2, settle, settle + 1.0]:
			_emit(
				check,
				StadiumReceiverOwnedModels.flex(model, id, elapsed, impact),
				"known owned panel accepts its deterministic visual flex",
				{"surface": id, "elapsed": elapsed}
			)
			var changed: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var valid: bool = changed.size() == rest.size()
			var peak: float = 0
			for index in range(changed.size()):
				var delta: Vector3 = changed[index] - rest[index]
				peak = maxf(peak, delta.length())
				valid = (
					valid
					and delta.length() <= maximum + EPS
					and absf(delta.x) < EPS
					and absf(delta.y) < EPS
					and changed[index].is_finite()
					and (
						StadiumReceiverOwnedModels
						. envelope(str(model.get_meta("stadium_item")))
						. grow(EPS)
						. has_point(mesh.transform * changed[index])
					)
				)
			if elapsed == settle / 2:
				valid = valid and peak > maximum * 0.90
			if elapsed >= settle or elapsed == 0:
				valid = valid and peak < EPS
			_emit(
				check,
				valid,
				"actual visual vertices stay bounded, visibly flex at peak, and settle on schedule",
				{"surface": id, "elapsed": elapsed, "peak": peak, "limit": maximum}
			)
			_emit(
				check,
				probe._grand_snapshot(model.get_node("Collision")) == collision_before,
				"visual response never moves replaces duplicates or changes any rest collider",
				{"surface": id, "elapsed": elapsed}
			)
	_emit(
		check,
		(
			not StadiumReceiverOwnedModels.flex(model, "UNKNOWN", 0.1, Vector3.ZERO)
			and not StadiumReceiverOwnedModels.flex(model, str(panels.keys()[0]), NAN, Vector3.ZERO)
			and not StadiumReceiverOwnedModels.flex(
				model, str(panels.keys()[0]), 0.1, Vector3(INF, 0, 0)
			)
		),
		"unknown surfaces and non-finite feedback inputs fail closed"
	)


static func _primary_fit(
	probe: GeometryProbe, model: Node3D, originals: Dictionary, check: Callable
) -> void:
	var placed: Vector3 = StadiumReceiverOwnedModels.position(str(model.get_meta("stadium_item")))
	for item: String in ["ST-026", "ST-079"]:
		var primary: Node3D = originals[item]
		probe.add_child(primary)
		var bounds: AABB = _bounds(probe, primary)
		bounds.position += StadiumTargetModels.POSITION
		var separate: bool = true
		for body: StaticBody3D in model.get_node("Collision").get_children():
			var solid: AABB = _member_bounds(model, str(body.name))
			solid.position += placed
			separate = separate and not solid.grow(0.001).intersects(bounds)
		_emit(
			check,
			separate,
			"actual complete primary bounds clear every receiver panel frame and support solid",
			{"primary": item, "receiver": str(model.get_meta("stadium_item"))}
		)
		probe.remove_child(primary)


static func _rejections(check: Callable) -> void:
	for row: Dictionary in [
		{},
		{"copy": "", "site": "RECEIVER-CATCH"},
		{"copy": "COPY", "site": ""},
		{"copy": 1, "site": "RECEIVER-CATCH"},
		{"copy": "COPY", "site": 1},
		{"copy": "COPY", "site": "RECEIVER-CATCH", "item": "ST-079"}
	]:
		var candidate: Node3D = StadiumReceiverOwnedModels.create("ST-072", row)
		_emit(
			check,
			candidate == null,
			"incomplete or conflicting ownership cannot create a catching assembly",
			row
		)
		if candidate != null:
			candidate.free()
	var unknown: Node3D = StadiumReceiverOwnedModels.create("ST-025", _row("ST-025"))
	_emit(
		check,
		(
			unknown == null
			and StadiumReceiverOwnedModels.surfaces("ST-025").is_empty()
			and StadiumReceiverOwnedModels.envelope("ST-025") == AABB()
		),
		"unapproved receiver models cannot enter through the owned catching factory"
	)
	if unknown != null:
		unknown.free()
