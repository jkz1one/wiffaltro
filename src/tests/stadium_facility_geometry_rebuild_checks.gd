class_name StadiumFacilityGeometryRebuildChecks
extends RefCounted
## Bounded geometry support for the single shared facility rebuild fixture.
## This is not a per-item scene or a second runner; it does not certify final art.

const ITEMS: Array[String] = ["ST-033", "ST-034", "ST-055", "ST-056", "ST-057", "ST-059"]
const ROOMS: Array[String] = ["ST-055", "ST-057"]
const EPSILON: float = 0.0002
const ROOM_BOUNDS: AABB = AABB(Vector3(-2.95, 0, 7.55), Vector3(5.9, 10.2, 8.6))
const ROOM_SHELL: AABB = AABB(Vector3(-2.75, 7.2, 12), Vector3(5.5, 3, 4))
const PENNANT_BOUNDS: AABB = AABB(Vector3(-2.02, 5.06, 9.86), Vector3(1.54, 1.8, 0.2))
# Static successful-path assertion count; see the adjacent source audit for breakdown.
const EXPECTED_CHECKS: int = 197


# Existing complete-point, frozen-snapshot and contracted-solid helpers are reused.
# Suppress the old test scene's _ready so this adapter cannot start another runner.
class SolidProbe:
	extends "res://src/tests/stadium_grand_three_stack_geometry_test_support.gd"
	var solid_ok: bool = true
	var solid_failure: String = ""

	func _ready() -> void:
		pass

	func _check(ok: bool, message: String) -> void:
		solid_ok = solid_ok and ok
		if not ok and solid_failure.is_empty():
			solid_failure = message


static func run(parent: Node3D, check: Callable) -> void:
	var probe: SolidProbe = SolidProbe.new()
	parent.add_child(probe)
	# Isolation from the photographed assembly, without altering any canonical site pose.
	probe.position = Vector3(1000, 0, 0)
	_emit(
		check,
		StadiumFacilityOwnedModels.ITEMS == ITEMS and StadiumFacilityOwnedModels.VERSION == 1,
		"one facility family owns exactly six requested models",
		{"items": StadiumFacilityOwnedModels.ITEMS}
	)
	var originals: Dictionary = {}
	var signatures: Dictionary = {}
	for item: String in ["ST-029", "ST-031"]:
		originals[item] = StadiumStraightOwnedModels.create(item)
		signatures[item] = _branches(probe, originals[item])
	for item: String in ITEMS:
		var model: Node3D = StadiumFacilityOwnedModels.create(item)
		_emit(check, model != null, "complete facility exists", {"item": item})
		if model == null:
			continue
		probe.add_child(model)
		# Label3D bounds are not trusted before its first render update.
		await probe.get_tree().process_frame
		_model_contract(probe, model, item, check)
		model.free()
	await _room_neighborhood(probe, check)
	await _fixed_sites(probe, check)
	for item: String in ["ST-029", "ST-031"]:
		var fresh: Node3D = StadiumStraightOwnedModels.create(item)
		_emit(
			check,
			(
				_branches(probe, originals[item]) == signatures[item]
				and _branches(probe, fresh) == signatures[item]
			),
			"facility creation leaves existing and freshly regenerated frozen host unchanged",
			{"item": item}
		)
		fresh.free()
		originals[item].free()
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"FACILITY_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _branches(probe: SolidProbe, model: Node3D) -> String:
	return (
		probe._grand_snapshot(model.get_node("Visual"))
		+ probe._grand_snapshot(model.get_node("Collision"))
	)


static func _points(probe: SolidProbe, model: Node3D) -> PackedVector3Array:
	var result: PackedVector3Array = probe._all_points(model)
	for label: Label3D in model.find_children("*", "Label3D", true, false):
		var bounds: AABB = label.get_aabb()
		for index in range(8):
			result.append(label.global_transform * bounds.get_endpoint(index))
	return result


static func _bounds(points: PackedVector3Array, pose: Transform3D = Transform3D.IDENTITY) -> AABB:
	if points.is_empty():
		return AABB()
	var result: AABB = AABB(pose * points[0], Vector3.ZERO)
	for point: Vector3 in points:
		result = result.expand(pose * point)
	return result


static func _member(model: Node3D, member: String) -> AABB:
	var mesh: MeshInstance3D = model.get_node_or_null("Visual/" + member) as MeshInstance3D
	if mesh == null:
		return AABB()
	return model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()


static func _same_box(actual: AABB, expected: AABB) -> bool:
	return (
		actual.position.distance_to(expected.position) < EPSILON
		and actual.size.distance_to(expected.size) < EPSILON
	)


static func _model_contract(
	probe: SolidProbe, model: Node3D, item: String, check: Callable
) -> void:
	var points: PackedVector3Array = _points(probe, model)
	var envelope: AABB = StadiumFacilityOwnedModels.envelope(item)
	var local: AABB = _bounds(points, model.global_transform.affine_inverse())
	var finite: bool = not points.is_empty()
	for point: Vector3 in points:
		finite = finite and point.is_finite()
	_emit(
		check,
		finite and envelope.grow(EPSILON).encloses(local),
		"all actual mesh, collision and ready label bounds fit full facility envelope",
		{"item": item, "actual": str(local), "envelope": str(envelope)}
	)
	var identity: bool = model.transform == Transform3D.IDENTITY
	for branch: String in ["Visual", "Collision"]:
		identity = (
			identity
			and model.has_node(branch)
			and model.get_node(branch).transform == Transform3D.IDENTITY
		)
	var positive: bool = true
	for node: Node3D in model.find_children("*", "Node3D", true, false):
		positive = (
			positive
			and node.transform.origin.is_finite()
			and node.basis.is_finite()
			and node.basis.determinant() > 0
			and not node.top_level
		)
	_emit(
		check,
		identity and positive,
		"owned root and containers are identity with finite positive-handed descendants",
		{"item": item}
	)
	var failure: String = _pair_failure(model)
	_emit(
		check,
		failure.is_empty(),
		"every visible solid has one exact enabled matching scenery collider",
		{"item": item, "member": failure}
	)
	var disconnected: Array[String] = _ungrounded(model)
	_emit(
		check,
		disconnected.is_empty(),
		"all complete physical members have a touching solid chain to ground",
		{"item": item, "disconnected": disconnected}
	)
	var labels: Array[Node] = model.find_children("*", "Label3D", true, false)
	var ready: bool = not labels.is_empty()
	for label: Label3D in labels:
		var box: AABB = label.get_aabb()
		ready = (
			ready
			and not label.text.is_empty()
			and box.size.x > 0
			and box.size.y > 0
			and label.visible
			and label.pixel_size > 0
		)
	_emit(
		check,
		ready,
		"all authored labels have nonempty actual bounds after one frame",
		{"item": item, "labels": labels.size()}
	)
	var label_failure: String = _label_failure(model)
	_emit(
		check,
		label_failure.is_empty(),
		"every actual label fits its backing and clears all complete solid volumes",
		{"item": item, "label_or_obstruction": label_failure}
	)
	_sign_contract(model, item, check)
	if item in ROOMS:
		_room_contract(model, item, check)


static func _pair_failure(model: Node3D) -> String:
	var visual: Node3D = model.get_node("Visual")
	var collision: Node3D = model.get_node("Collision")
	var meshes: Array[Node] = visual.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty() or collision.get_child_count() != meshes.size():
		return "pair-count:%d/%d" % [meshes.size(), collision.get_child_count()]
	for mesh: MeshInstance3D in meshes:
		var body: StaticBody3D = collision.get_node_or_null(str(mesh.name)) as StaticBody3D
		if (
			body == null
			or body.get_child_count() != 1
			or body.transform != mesh.transform
			or mesh.basis != Basis.IDENTITY
			or body.collision_layer != 1
			or body.collision_mask != 2
			or body.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL"
		):
			return str(mesh.name) + ":body"
		var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
		if (
			shape == null
			or shape.disabled
			or shape.transform != Transform3D.IDENTITY
			or not shape.shape is BoxShape3D
			or not mesh.mesh is BoxMesh
		):
			return str(mesh.name) + ":shape"
		if shape.shape.size != mesh.mesh.size or shape.shape.margin != 0:
			return str(mesh.name) + ":volume"
	return ""


static func _ungrounded(model: Node3D) -> Array[String]:
	# These facilities deliberately use exact axis-aligned paired BoxMesh/BoxShape3D.
	# Aggregate the full contact graph; a floating fascia cannot pass via a grounded post alone.
	var boxes: Dictionary = {}
	var connected: Dictionary = {}
	for body: StaticBody3D in model.get_node("Collision").get_children():
		var box: AABB = _member(model, str(body.name))
		boxes[str(body.name)] = box
		if absf(box.position.y) < EPSILON:
			connected[str(body.name)] = true
	var progress: bool = true
	while progress:
		progress = false
		for member: String in boxes:
			if connected.has(member):
				continue
			for support: String in connected.keys():
				if boxes[member].grow(EPSILON).intersects(boxes[support]):
					connected[member] = true
					progress = true
					break
	var result: Array[String] = []
	for member: String in boxes:
		if not connected.has(member):
			result.append(member)
	return result


static func _no_penetration(
	probe: SolidProbe, model: Node3D, neighbors: Array[Node3D], check: Callable, context: String
) -> void:
	probe.solid_ok = true
	probe.solid_failure = ""
	probe._grand_no_penetration(model, neighbors)
	_emit(
		check,
		probe.solid_ok,
		"whole contracted solids avoid independently purchased neighbors",
		{"context": context, "model": str(model.name), "failure": probe.solid_failure}
	)


static func _put(probe: SolidProbe, item: String, site: String) -> Node3D:
	var model: Node3D = (
		StadiumFacilityOwnedModels.create(item)
		if item in ITEMS
		else StadiumStraightOwnedModels.create(item)
	)
	probe.add_child(model)
	model.transform = (
		StadiumBaselineSites.pose(site)
		if site.begins_with("BASE-")
		else StadiumFacilityItems.pose(site)
	)
	return model


static func _room_contract(model: Node3D, item: String, check: Callable) -> void:
	_emit(
		check,
		(
			_same_box(StadiumFacilityOwnedModels.envelope(item), ROOM_BOUNDS)
			and _same_box(model.get_meta("room_shell_bounds", AABB()), ROOM_SHELL)
		),
		"room keeps complete 5.5 by 4 by 3 shell and full rear access reserve",
		{"item": item}
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "RoomFloor"), AABB(Vector3(-2.75, 7.2, 12), Vector3(5.5, 0.15, 4))
			)
			and _same_box(
				_member(model, "RoomRoof"), AABB(Vector3(-2.75, 10.05, 12), Vector3(5.5, 0.15, 4))
			)
		),
		"actual room floor and roof retain the complete full-size shell",
		{
			"item": item,
			"floor": str(_member(model, "RoomFloor")),
			"roof": str(_member(model, "RoomRoof"))
		}
	)
	var landing: AABB = _member(model, "RearLanding")
	_emit(
		check,
		(
			_same_box(landing, AABB(Vector3(-2.75, 7.15, 9.31), Vector3(5.5, 0.2, 2.69)))
			and landing.position.y - 6.95 >= 0.1999
		),
		"complete rear landing clears intact host parapet by 0.20m",
		{"item": item, "landing": str(landing)}
	)
	var steps: bool = true
	var failed_step: int = -1
	for index in range(8):
		var expected: AABB = AABB(
			Vector3(1.2, 6.15, 7.55 + index * 0.22), Vector3(1.1, 0.15 * (index + 1), 0.22)
		)
		if not _same_box(_member(model, "AccessStep%d" % index), expected):
			steps = false
			failed_step = index
	_emit(
		check,
		steps and absf(2.4 - (1.2 + 1.1) - 0.1) < EPSILON,
		"eight actual short access steps keep the approved 1.10m lane and 0.10m transition gap",
		{"item": item, "step": failed_step}
	)
	var supports: bool = true
	for row in range(3):
		var z: float = [10.4, 12.4, 15.6][row]
		var beam_bottom: float = 6.95 if row == 0 else 7.0
		for side: int in [-1, 1]:
			supports = (
				supports
				and _same_box(
					_member(model, "SupportFoot%d_%d" % [row, side]),
					AABB(Vector3(side * 2.4 - 0.3, 0, z - 0.3), Vector3(0.6, 0.3, 0.6))
				)
			)
			supports = (
				supports
				and _same_box(
					_member(model, "GroundSupport%d_%d" % [row, side]),
					AABB(
						Vector3(side * 2.4 - 0.13, 0.3, z - 0.13),
						Vector3(0.26, beam_bottom - 0.3, 0.26)
					)
				)
			)
		supports = (
			supports
			and _same_box(
				_member(model, "SupportBeam%d" % row),
				AABB(Vector3(-2.75, beam_bottom, z - 0.15), Vector3(5.5, 0.2, 0.3))
			)
		)
	_emit(
		check,
		supports and absf((10.4 - 0.3) - 9.9 - 0.2) < EPSILON,
		(
			"all six grounded supports and three actual beams start at z10.10 beyond the complete "
			+ "frozen host"
		),
		{"item": item, "front_support_z": _member(model, "SupportFoot0_-1").position.z}
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "RoomLeftWall"),
				AABB(Vector3(-2.75, 7.35, 12), Vector3(0.15, 2.7, 4))
			)
			and _same_box(
				_member(model, "RoomRightWall"), AABB(Vector3(2.6, 7.35, 12), Vector3(0.15, 2.7, 4))
			)
			and _same_box(
				_member(model, "RoomRearWall"),
				AABB(Vector3(-2.6, 7.35, 15.85), Vector3(5.2, 2.7, 0.15))
			)
		),
		"actual side and rear walls enclose the complete room depth and height",
		{"item": item}
	)
	var pennant_clear: bool = true
	var conflict: String = ""
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if _member(model, str(mesh.name)).intersects(PENNANT_BOUNDS.grow(-EPSILON)):
			pennant_clear = false
			conflict = str(mesh.name)
	_emit(
		check,
		pennant_clear,
		"every new room and support solid clears the complete current pennant envelope",
		{"item": item, "conflict": conflict, "pennant": str(PENNANT_BOUNDS)}
	)


static func _room_neighborhood(probe: SolidProbe, check: Callable) -> void:
	for hand: String in ["L", "R"]:
		for swap in range(2):
			var lowers: Array[Node3D] = []
			var concourses: Array[Node3D] = []
			var rooms: Array[Node3D] = []
			var snapshots: Array[String] = []
			var transition_lower: Node3D = StadiumRoofOwnedModels.create(
				"ST-088" if hand == "L" else "ST-085"
			)
			var transition_deck: Node3D = StadiumRoofOwnedModels.create(
				"ST-089" if hand == "L" else "ST-086"
			)
			probe.add_child(transition_lower)
			probe.add_child(transition_deck)
			for bay in range(2):
				var site: String = "BASE-" + hand + str(bay + 1)
				lowers.append(_put(probe, "ST-029", site))
				concourses.append(_put(probe, "ST-031", site))
				rooms.append(_put(probe, ROOMS[(bay + swap) % 2], site))
				snapshots.append(_branches(probe, lowers[bay]) + _branches(probe, concourses[bay]))
			await probe.get_tree().process_frame
			await probe.get_tree().physics_frame
			await probe.get_tree().physics_frame
			for bay in range(2):
				var site: String = "BASE-" + hand + str(bay + 1)
				var item: String = ROOMS[(bay + swap) % 2]
				var room: Node3D = rooms[bay]
				var context: String = item + "/" + site
				var pose: Transform3D = StadiumBaselineSites.pose(site)
				_emit(
					check,
					(
						room.transform == pose
						and pose.basis.determinant() > 0.9999
						and StadiumFacilityItems.pose(site) == pose
						and _same_box(StadiumFacilityItems.reserved(site), ROOM_BOUNDS)
					),
					"both handed BASE poses preserve exact full-size room transforms",
					{"context": context, "determinant": pose.basis.determinant()}
				)
				var actual: AABB = _bounds(
					_points(probe, room), probe.global_transform.affine_inverse()
				)
				for tier: String in ["club", "mogul"]:
					_emit(
						check,
						(
							StadiumProperty.contains(tier, actual)
							and StadiumProperty.contains(tier, pose * ROOM_BOUNDS)
						),
						"all actual room bounds and complete reserve fit legal property",
						{"context": context, "tier": tier, "actual": str(actual)}
					)
				var deck: Node3D = concourses[bay].get_node("Collision/ConcourseDeck")
				var joined: bool = true
				var failed: String = ""
				for index in range(8):
					var step: Node3D = room.get_node("Collision/AccessStep%d" % index)
					if not probe._contact(deck, step):
						joined = false
						failed = "deck/AccessStep%d" % index
					if (
						index > 0
						and not probe._contact(
							room.get_node("Collision/AccessStep%d" % (index - 1)), step
						)
					):
						joined = false
						failed = "AccessStep%d/%d" % [index - 1, index]
				_emit(
					check,
					joined,
					"all eight actual steps physically touch the unchanged deck and form a continuous ascent",
					{"context": context, "pair": failed}
				)
				_emit(
					check,
					(
						probe._contact(
							room.get_node("Collision/AccessStep7"),
							room.get_node("Collision/RearLanding")
						)
						and probe._contact(
							room.get_node("Collision/RearLanding"),
							room.get_node("Collision/RoomFloor")
						)
					),
					"actual top step joins rear landing and full room floor",
					{"context": context}
				)
				var load_path: bool = true
				var load_failure: String = ""
				for row in range(3):
					var beam: Node3D = room.get_node("Collision/SupportBeam%d" % row)
					var supported: Node3D = room.get_node(
						"Collision/RearLanding" if row == 0 else "Collision/RoomFloor"
					)
					if not probe._contact(beam, supported):
						load_path = false
						load_failure = "SupportBeam%d/platform" % row
					for side: int in [-1, 1]:
						var foot: Node3D = room.get_node("Collision/SupportFoot%d_%d" % [row, side])
						var column: Node3D = room.get_node(
							"Collision/GroundSupport%d_%d" % [row, side]
						)
						if not probe._contact(foot, column) or not probe._contact(column, beam):
							load_path = false
							load_failure = "foot/column/beam%d_%d" % [row, side]
				_emit(
					check,
					load_path,
					"six actual ground feet, columns and beams physically support the full room and landing",
					{"context": context, "pair": load_failure}
				)
				var deck_box: AABB = _member(concourses[bay], "ConcourseDeck")
				var parapet: AABB = _member(concourses[bay], "RearParapet")
				_emit(
					check,
					(
						_same_box(deck_box, AABB(Vector3(-2.95, 6, 7), Vector3(5.9, 0.15, 2.85)))
						and _same_box(
							parapet, AABB(Vector3(-2.95, 6.15, 9.725), Vector3(5.9, 0.8, 0.15))
						)
					),
					"real frozen host deck and rear parapet retain every authored extent",
					{"context": context, "deck": str(deck_box), "parapet": str(parapet)}
				)
				_no_penetration(
					probe,
					room,
					[lowers[bay], concourses[bay]],
					check,
					context + "/own frozen hosts; deck tangency only"
				)
				_no_penetration(
					probe,
					room,
					[
						lowers[1 - bay],
						concourses[1 - bay],
						rooms[1 - bay],
						transition_lower,
						transition_deck
					],
					check,
					context + "/adjacent full room, hosts and handed transitions"
				)
				_emit(
					check,
					(
						_branches(probe, lowers[bay]) + _branches(probe, concourses[bay])
						== snapshots[bay]
					),
					"all original host mesh, collision, material and transform state remains frozen",
					{"context": context}
				)
			var axis: Vector3 = rooms[0].global_basis.x.normalized()
			var first: Vector2 = _projection(_points(probe, rooms[0]), axis)
			var second: Vector2 = _projection(_points(probe, rooms[1]), axis)
			var actual_gap: float = maxf(first.x - second.y, second.x - first.y)
			var reserve_gap: float = _separation(
				_box_points(ROOM_BOUNDS, rooms[0].global_transform),
				_box_points(ROOM_BOUNDS, rooms[1].global_transform),
				axis
			)
			_emit(
				check,
				actual_gap >= 0.0998 and absf(reserve_gap - 0.1) < EPSILON,
				"adjacent full rooms retain the complete 0.10m reserved seam on both BASE hands",
				{"hand": hand, "swap": swap, "actual_gap": actual_gap, "reserve_gap": reserve_gap}
			)
			for model: Node3D in lowers + concourses + rooms + [transition_lower, transition_deck]:
				model.free()


static func _projection(points: PackedVector3Array, axis: Vector3) -> Vector2:
	var result: Vector2 = Vector2(INF, -INF)
	for point: Vector3 in points:
		var value: float = axis.dot(point)
		result.x = minf(result.x, value)
		result.y = maxf(result.y, value)
	return result


static func _separation(
	first: PackedVector3Array, second: PackedVector3Array, axis: Vector3
) -> float:
	var a: Vector2 = _projection(first, axis)
	var b: Vector2 = _projection(second, axis)
	return maxf(a.x - b.y, b.x - a.y)


static func _box_points(box: AABB, pose: Transform3D) -> PackedVector3Array:
	var result: PackedVector3Array = []
	for index in range(8):
		result.append(pose * box.get_endpoint(index))
	return result


static func _fixed_sites(probe: SolidProbe, check: Callable) -> void:
	var rows: Array[Array] = [
		["ST-033", "SERVICE-A"],
		["ST-033", "SERVICE-B"],
		["ST-034", "SERVICE-A"],
		["ST-034", "SERVICE-B"],
		["ST-056", "ANNOUNCER-A"],
		["ST-059", "TICKET-APPROACH"]
	]
	for row: Array in rows:
		var item: String = row[0]
		var site: String = row[1]
		var model: Node3D = _put(probe, item, site)
		await probe.get_tree().process_frame
		var expected: Transform3D = _fixed_pose(site)
		var reserve: AABB = _fixed_reserve(site)
		var local: AABB = _bounds(_points(probe, model), model.global_transform.affine_inverse())
		var actual: AABB = _bounds(_points(probe, model), probe.global_transform.affine_inverse())
		_emit(
			check,
			(
				model.transform.is_equal_approx(expected)
				and _same_box(StadiumFacilityItems.reserved(site), reserve)
			),
			"fixed facility uses the exact independent approved site pose and reserve",
			{
				"item": item,
				"site": site,
				"pose": str(model.transform),
				"reserve": str(StadiumFacilityItems.reserved(site))
			}
		)
		_emit(
			check,
			reserve.grow(EPSILON).encloses(local),
			(
				"complete sign, awning, text and physical geometry stay inside fixed reservation "
				+ "after label update"
			),
			{"item": item, "site": site, "actual_local": str(local), "reserve": str(reserve)}
		)
		for tier: String in ["club", "mogul"]:
			_emit(
				check,
				(
					StadiumProperty.contains(tier, actual)
					and StadiumProperty.contains(tier, expected * reserve)
				),
				"complete actual fixed facility and reservation fit property",
				{"item": item, "site": site, "tier": tier, "actual": str(actual)}
			)
		if item == "ST-059":
			await _ticket_bowls(probe, model, check)
		model.free()


static func _fixed_pose(site: String) -> Transform3D:
	match site:
		"SERVICE-A":
			return Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-36, 0, -7))
		"SERVICE-B":
			return Transform3D(Basis(Vector3.UP, PI / 2), Vector3(36, 0, -7))
		"ANNOUNCER-A":
			return Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-35, 0, 12))
		"TICKET-APPROACH":
			return Transform3D(Basis(Vector3.UP, PI), Vector3(24, 0, -20.5))
	return Transform3D.IDENTITY


static func _fixed_reserve(site: String) -> AABB:
	if site in ["SERVICE-A", "SERVICE-B"]:
		return AABB(Vector3(-3, 0, -3), Vector3(6, 4.5, 6))
	if site == "ANNOUNCER-A":
		# This rotated local 4x5 rectangle is the approved world-axis 5x4 reservation.
		return AABB(Vector3(-2, 0, -2.5), Vector3(4, 4.5, 5))
	return AABB(Vector3(-1.5, 0, -1.5), Vector3(3, 4, 3))


static func _ticket_bowls(probe: SolidProbe, ticket: Node3D, check: Callable) -> void:
	var reserve: AABB = _fixed_pose("TICKET-APPROACH") * _fixed_reserve("TICKET-APPROACH")
	_emit(
		check,
		absf(reserve.position.z + 22) < EPSILON and reserve.size.is_equal_approx(Vector3(3, 4, 3)),
		"ticket approach keeps the full 3m reserve tangent to the Club boundary",
		{"reserve": str(reserve)}
	)
	var ticket_points: PackedVector3Array = _box_points(
		_fixed_reserve("TICKET-APPROACH"), _fixed_pose("TICKET-APPROACH")
	)
	var nearest_pose: Transform3D = StadiumCurvedLowerSites.pose("BOWL-01")
	var nearest_points: PackedVector3Array = _box_points(
		StadiumRoofOwnedModels.envelope("ST-083"), nearest_pose
	)
	var nearest_gap: float = _separation(
		ticket_points, nearest_points, nearest_pose.basis.z.normalized()
	)
	_emit(
		check,
		absf(nearest_gap - 1.125571585) < EPSILON,
		"oriented complete BOWL-01 concourse reserve leaves the measured 1.125571585m ticket gap",
		{"gap": nearest_gap}
	)
	for site: String in ["BOWL-01", "BOWL-02", "BOWL-03", "BOWL-04", "BOWL-05"]:
		var chain: Array[Node3D] = []
		var envelopes_clear: bool = true
		var smallest_gap: float = INF
		var pose: Transform3D = StadiumCurvedLowerSites.pose(site)
		for item: String in ["ST-081", "ST-083", "ST-082", "ST-084"]:
			var state: String = "upper" if item == "ST-084" else "lower"
			var model: Node3D = StadiumRoofOwnedModels.create(item, state)
			probe.add_child(model)
			model.transform = pose
			chain.append(model)
			var points: PackedVector3Array = _box_points(
				StadiumRoofOwnedModels.envelope(item, state), pose
			)
			var gap: float = -INF
			for axis: Vector3 in [
				Vector3.RIGHT, Vector3.BACK, pose.basis.x.normalized(), pose.basis.z.normalized()
			]:
				gap = maxf(gap, _separation(ticket_points, points, axis))
			envelopes_clear = envelopes_clear and gap > 0
			smallest_gap = minf(smallest_gap, gap)
		_emit(
			check,
			envelopes_clear,
			"ticket reservation clears each complete oriented bowl chain envelope",
			{"site": site, "minimum_separating_gap": smallest_gap}
		)
		await probe.get_tree().physics_frame
		await probe.get_tree().physics_frame
		_no_penetration(
			probe,
			ticket,
			chain,
			check,
			"ST-059/TICKET-APPROACH/" + site + "/all four purchased bowl pieces"
		)
		for model: Node3D in chain:
			model.free()


static func _sign_contract(model: Node3D, item: String, check: Callable) -> void:
	var board: AABB = _member(model, "SignBoard")
	var label: Label3D = model.get_node("Visual/SignText")
	var text_bounds: AABB = (
		model.global_transform.affine_inverse() * label.global_transform * label.get_aabb()
	)
	var board_z: float = (
		11.94
		if item in ROOMS
		else -1.0 if item == "ST-033" else -1.30 if item == "ST-056" else -1.05
	)
	var text_z: float = board_z - 0.08
	_emit(
		check,
		(
			absf(board.get_center().z - board_z) < EPSILON
			and absf(board.position.z - (board_z - 0.06)) < EPSILON
			and absf(label.position.z - text_z) < EPSILON
			and absf(label.rotation.y - PI) < EPSILON
			and not label.no_depth_test
			and not label.double_sided
		),
		"sign keeps approved board/front/text planes with real outward-facing depth-tested text",
		{
			"item": item,
			"board_z": board.get_center().z,
			"front_z": board.position.z,
			"text_z": label.position.z
		}
	)
	var size_ok: bool = (
		absf(label.pixel_size - 0.005) < 0.0000001 if item in ["ST-034", "ST-059"] else true
	)
	_emit(
		check,
		(
			size_ok
			and text_bounds.position.x >= board.position.x + 0.06 - EPSILON
			and text_bounds.end.x <= board.end.x - 0.06 + EPSILON
			and text_bounds.position.y >= board.position.y + 0.02 - EPSILON
			and text_bounds.end.y <= board.end.y - 0.02 + EPSILON
			and text_bounds.end.z < board.position.z - 0.019
		),
		"actual ready sign glyph bounds fit the complete board with clear face separation",
		{
			"item": item,
			"board": str(board),
			"text": str(text_bounds),
			"pixel_size": label.pixel_size
		}
	)
	var clipped: String = ""
	for other: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if _member(model, str(other.name)).grow(-EPSILON).intersects(text_bounds.grow(0.001)):
			clipped = str(other.name)
	_emit(
		check,
		clipped.is_empty(),
		"no actual building, awning or sign volume clips the visible sign text",
		{"item": item, "obstruction": clipped, "text": str(text_bounds)}
	)


static func _label_failure(model: Node3D) -> String:
	for label: Label3D in model.find_children("*", "Label3D", true, false):
		var board_name: String = "MenuBoard" if str(label.name) == "MenuText" else "SignBoard"
		var board: AABB = _member(model, board_name)
		var text_bounds: AABB = (
			model.global_transform.affine_inverse() * label.global_transform * label.get_aabb()
		)
		if (
			text_bounds.position.x < board.position.x + 0.02 - EPSILON
			or text_bounds.end.x > board.end.x - 0.02 + EPSILON
			or text_bounds.position.y < board.position.y + 0.01 - EPSILON
			or text_bounds.end.y > board.end.y - 0.01 + EPSILON
			or text_bounds.end.z >= board.position.z - 0.004
		):
			return str(label.name) + ":backing:" + str(text_bounds)
		for other: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if _member(model, str(other.name)).grow(-EPSILON).intersects(text_bounds.grow(0.001)):
				return str(label.name) + ":clips:" + str(other.name)
	return ""
