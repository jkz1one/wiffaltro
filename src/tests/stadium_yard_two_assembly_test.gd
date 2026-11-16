extends "res://src/tests/stadium_yard_assembly_test.gd"
## Independent archived four-copy physical reference, actual installed bounds and identity controls.

const PREFIX: String = "npc-candidate:AY-02:"
const SITES: Array[String] = ["RECEIVER-PRIMARY", "SIDE-SEAT-L", "SIDE-SEAT-R", "O-R1"]
const ITEMS: Array[String] = ["ST-079", "ST-027", "ST-027", "ST-001"]


func _ready() -> void:
	var actual: StadiumYardTwoProperty = StadiumYardTwoStudy.build()
	var expected: StadiumYardTwoProperty = _reference()
	if actual == null or expected == null:
		_check(false, "complete actual and independent reference constructors")
		get_tree().quit(1)
		return
	add_child(actual)
	_check(
		_same(actual, expected), "exact independent four-copy field/model/pose/collider assembly"
	)
	var record: Dictionary = StadiumYardTwoStudy.canonical()
	_check(
		(
			record.id == "AY-02"
			and record.items.size() == 4
			and record.live_units == 1
			and record.blueprint_entitlements == ["ST-001", "ST-027", "ST-079"]
		),
		"exact archived four-copy one-live-unit content"
	)
	_check(
		(
			record.endowment.blueprint_value == 300
			and record.endowment.copy_value == 275
			and record.endowment.land_value == 0
			and record.endowment.total_value == 575
			and not record.endowment.spendable
		),
		"575 descriptive endowment is not spendable human funds"
	)
	_check(
		(
			record.environment.certificates.is_empty()
			and not record.environment.night_eligible
			and record.environment.target_slots == ["13:10", "16:10"]
		),
		"no inferred environment authority"
	)
	_check(
		(
			actual.field.id == &"field.npc_venue"
			and actual.field != StadiumYardTwoStudy.FIELD
			and actual.field.display_name == "NPC Venue"
		),
		"private field copied without registration"
	)
	_prisms(actual)
	_finite_clearance_controls(actual)
	for index in range(4):
		var model: Node3D = actual.objects[PREFIX + SITES[index]]
		var row: Dictionary = record.items[index]
		_check(
			(
				row.item == ITEMS[index]
				and row.host == "field"
				and row.transform == StadiumYardVenueStudy.components(model.transform)
			),
			"record item/host/pose matches actual independently checked model"
		)
		var local_bounds: AABB = _bounds(model, model)
		var world_bounds: AABB = model.global_transform * local_bounds
		var envelope: AABB = _envelope(ITEMS[index])
		_check(
			(
				envelope.grow(0.0001).encloses(local_bounds)
				and StadiumProperty.contains("backyard", world_bounds)
			),
			"actual model fits fixed envelope/property"
		)
		var clearance: Dictionary = _finite_clearance(world_bounds, actual)
		_check(clearance.clear_walls, "every actual copy clears all six finite physical wall slabs")
		if ITEMS[index] == "ST-027":
			_check(
				clearance.outside_play and model.get_meta("represented_seats") == 10,
				"each occupied small bleacher is outside finite play with ten bundled audience"
			)
		else:
			_check(
				not clearance.outside_play,
				"receiver/cone remain their exact in-field gameplay roles"
			)
		print(
			"AY02_MODEL_BOUNDS ",
			JSON.stringify(
				{
					"site": SITES[index],
					"local": _bounds_record(local_bounds),
					"world": _bounds_record(world_bounds),
					"outside_play": clearance.outside_play,
					"clear_walls": clearance.clear_walls
				},
				"",
				true,
				true
			)
		)
	var routes: Array[Dictionary] = actual.route_obstacles()
	_check(
		(
			routes.size() == 2
			and routes[0].copy == PREFIX + "RECEIVER-PRIMARY"
			and routes[1].copy == PREFIX + "O-R1"
			and routes[1].center == Vector3(8, 0, 14)
		),
		"routing distinguishes receiver/cone from two decorative audience structures"
	)
	for edit in range(22):
		var changed: StadiumYardTwoProperty = StadiumYardTwoStudy.build()
		if changed == null:
			_check(false, "negative-control constructor")
			continue
		var cone: Node3D = changed.objects[PREFIX + "O-R1"]
		var body: StaticBody3D = cone.get_node("Collision/CONE_BODY")
		match edit:
			0:
				cone.position.x += 0.001
			1:
				cone.scale.x = 1.001
			2:
				cone.set_meta("candidate_host", "RECEIVER-PRIMARY")
			3:
				cone.set_meta("candidate_instance", PREFIX + "SIDE-SEAT-L")
			4:
				cone.set_meta("stadium_item", "ST-003")
			5:
				cone.get_node("Visual/CONE_BASE").mesh.size.x += 0.01
			6:
				body.get_child(0).disabled = true
			7:
				body.collision_layer = 0
			8:
				body.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
			9:
				body.set_meta("owned_copy", "starter-v1:ST-001")
			10:
				body.remove_meta("candidate_instance")
			11:
				changed.field.safe_hit_z_m += 0.001
			12:
				changed.field.id = &"field.starter_backyard"
			13:
				var foreign: Node3D = Node3D.new()
				changed.add_child(foreign)
				changed.remove_child(cone)
				foreign.add_child(cone)
			14:
				var shape: ConvexPolygonShape3D = (
					changed.get_node("BoundaryGraph").get_child(0).get_child(0).shape
				)
				var points: PackedVector3Array = shape.points
				points[0].x += 0.01
				shape.points = points
			15:
				cone.process_mode = Node.PROCESS_MODE_DISABLED
			16:
				body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			17:
				body.process_mode = Node.PROCESS_MODE_DISABLED
			18:
				var forged: GDScript = GDScript.new()
				forged.source_code = "extends Node3D\n"
				_check(forged.reload() == OK, "anonymous forged script compiles")
				cone.set_script(forged)
			19:
				changed.objects[PREFIX + "O-R1"] = changed.objects[PREFIX + "RECEIVER-PRIMARY"]
			20:
				changed.objects[PREFIX + "SIDE-SEAT-L"].get_node("Visual/CrowdAnchor0").position.x += 0.01
			21:
				changed.objects[PREFIX + "RECEIVER-PRIMARY"].get_node("Collision/ST079_BACK").position.z += 0.01
		_check(
			not _same(changed, expected),
			"unchanged metadata cannot conceal physical edit " + str(edit)
		)
		_check(
			ClubCareer.same(changed.get_meta("candidate_venue"), record),
			"control retained canonical metadata"
		)
		changed.free()
	_check(
		(
			_supplement_current_public_membership("AY-02")
			and StadiumNpcVenues.definition("AY-02", 2).is_empty()
			and not StadiumNpcVenues.valid_manifest(record)
		),
		"authoring cannot become public NPC availability"
	)
	await _installed_modes(actual, expected)
	actual.free()
	expected.free()
	await get_tree().process_frame
	if _failures == 0:
		print(
			"Wiffaltro yard-two assembly passed: exact AY-02 and independent physical mutation controls."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _reference() -> StadiumYardTwoProperty:
	# Literal DE/BT/CA expansion, never the candidate's study or pose generator.
	var property: StadiumYardTwoProperty = StadiumYardTwoProperty.new()
	property.name = "AY02Candidate"
	if not property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new()):
		property.free()
		return null
	property.field = preload("res://src/content/fields/npc_venue_field.tres").duplicate(true)
	if StadiumBoundaryRuntime.assemble(property) == null:
		property.free()
		return null
	var poses: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.05)),
		Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT), Vector3(-24, 0, 12.5)),
		Transform3D(Basis(Vector3(0, 0, 1), Vector3.UP, Vector3.LEFT), Vector3(24, 0, 12.5)),
		Transform3D(Basis.IDENTITY, Vector3(8, 0, 14))
	]
	for index in range(4):
		var model: Node3D = (
			StadiumSeatingModels.create(ITEMS[index])
			if ITEMS[index] == "ST-027"
			else StadiumStarterModels.create(ITEMS[index])
		)
		model.name = SITES[index]
		model.transform = poses[index]
		var identity: String = PREFIX + SITES[index]
		model.set_meta("candidate_instance", identity)
		model.set_meta("candidate_site", SITES[index])
		model.set_meta("candidate_host", "field")
		property.add_child(model)
		property.objects[identity] = model
		property.bind_model(identity, model)
	return property


func _same(actual: StadiumYardTwoProperty, expected: StadiumYardTwoProperty) -> bool:
	if (
		not _node_policies(actual, expected)
		or actual.objects.keys() != expected.objects.keys()
		or actual.tier != "backyard"
		or actual.field.get_script() != expected.field.get_script()
		or (
			var_to_bytes(StadiumNpcRetainedGeometry._geometry(actual))
			!= var_to_bytes(StadiumNpcRetainedGeometry._geometry(expected))
		)
	):
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		if actual.field.get(key) != expected.field.get(key):
			return false
	for identity: String in actual.objects:
		var model: Node3D = actual.objects[identity]
		if (
			model.get_parent() != actual
			or model.get_meta("owned_copy", "") != identity
			or model.get_meta("candidate_instance", "") != identity
			or model.get_meta("candidate_site", "") != identity.trim_prefix(PREFIX)
			or model.get_meta("candidate_host", "") != "field"
		):
			return false
		for body: StaticBody3D in model.get_node("Collision").get_children():
			if actual.contact_identity(body).is_empty():
				return false
	return true


func _envelope(item: String) -> AABB:
	if item == "ST-027":
		return AABB(Vector3(-3, 0, -1.5), Vector3(6, 2.2, 3))
	if item == "ST-079":
		return AABB(Vector3(-0.30, 0, -0.18), Vector3(0.60, 0.88, 0.61))
	return AABB(Vector3(-0.175, 0, -0.175), Vector3(0.35, 0.50, 0.35))


func _installed_modes(actual: StadiumYardTwoProperty, expected: StadiumYardTwoProperty) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(8, 0.27, 13), Vector3(8, 0.27, 15), 1
	)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var body: StaticBody3D = actual.objects[PREFIX + "O-R1"].get_node("Collision/CONE_BODY")
	var hit: Dictionary = space.intersect_ray(ray)
	_check(not hit.is_empty() and hit.collider == body, "positive ray meets actual cone collider")
	for target: Node in [actual, body]:
		var before: Node.ProcessMode = target.process_mode
		target.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(
			not _same(actual, expected) and space.intersect_ray(ray).is_empty(),
			"disabled root/body actually removes collision and fails correspondence"
		)
		target.process_mode = before
		await get_tree().physics_frame
		await get_tree().physics_frame
		hit = space.intersect_ray(ray)
		_check(
			_same(actual, expected) and not hit.is_empty() and hit.collider == body,
			"restoration returns exact physical contact and independent comparison"
		)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	remove_child(actual)


func _node_policies(actual: Node, expected: Node) -> bool:
	# An in-memory script has no resource_path; actual identity and execution modes still matter.
	if (
		actual.get_script() != expected.get_script()
		or actual.process_mode != expected.process_mode
		or actual.get_child_count() != expected.get_child_count()
	):
		return false
	if (
		actual is CollisionObject3D
		and (not expected is CollisionObject3D or actual.disable_mode != expected.disable_mode)
	):
		return false
	for index in range(actual.get_child_count()):
		if not _node_policies(actual.get_child(index), expected.get_child(index)):
			return false
	return true


func _finite_clearance(bounds: AABB, property: StadiumPropertyGeometry) -> Dictionary:
	# The six actual slabs give the finite play-facing graph and full joined wall footprints.
	# Chair-only _outside_play instead imposes a 1.5m buffer beyond an infinite side extension.
	var play: PackedVector2Array = []
	var slabs: Array[PackedVector2Array] = []
	for body: StaticBody3D in property.get_node("BoundaryGraph").get_children():
		var shape: CollisionShape3D = body.get_child(0)
		var polygon: PackedVector2Array = []
		for corner in range(4):
			var point: Vector3 = shape.global_transform * shape.shape.points[corner]
			polygon.append(Vector2(point.x, point.z))
		play.append(polygon[0])
		slabs.append(polygon)
	var walls_clear: bool = true
	for polygon: PackedVector2Array in slabs:
		walls_clear = _strictly_separated(bounds, polygon) and walls_clear
	return {"outside_play": _strictly_separated(bounds, play), "clear_walls": walls_clear}


func _strictly_separated(bounds: AABB, polygon: PackedVector2Array) -> bool:
	# SAT over this convex Yard footprint and the actual world AABB. Strict gaps only:
	# touching is rejected, no EPS, rounded distance, enlarged threshold or extrapolated side rule.
	var corners: PackedVector2Array = [
		Vector2(bounds.position.x, bounds.position.z),
		Vector2(bounds.end.x, bounds.position.z),
		Vector2(bounds.end.x, bounds.end.z),
		Vector2(bounds.position.x, bounds.end.z)
	]
	var axes: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN]
	for index in range(polygon.size()):
		var edge: Vector2 = polygon[(index + 1) % polygon.size()] - polygon[index]
		axes.append(Vector2(-edge.y, edge.x))
	for axis: Vector2 in axes:
		var box_min: float = INF
		var box_max: float = -INF
		var poly_min: float = INF
		var poly_max: float = -INF
		for point: Vector2 in corners:
			box_min = minf(box_min, point.dot(axis))
			box_max = maxf(box_max, point.dot(axis))
		for point: Vector2 in polygon:
			poly_min = minf(poly_min, point.dot(axis))
			poly_max = maxf(poly_max, point.dot(axis))
		if box_max < poly_min or poly_max < box_min:
			return true
	return false


func _finite_clearance_controls(property: StadiumPropertyGeometry) -> void:
	var inside: Dictionary = _finite_clearance(
		AABB(Vector3(-0.1, 0, 13.9), Vector3(0.2, 7, 0.2)), property
	)
	_check(not inside.outside_play, "finite-footprint oracle rejects an in-field object volume")
	var straddle: Dictionary = _finite_clearance(
		AABB(Vector3(-0.1, 0, 23.3), Vector3(0.2, 7, 0.2)), property
	)
	_check(
		not straddle.outside_play and not straddle.clear_walls,
		"finite-footprint oracle rejects actual back-line and wall overlap"
	)
	var wall_only: Dictionary = _finite_clearance(
		AABB(Vector3(-0.1, 0, 23.45), Vector3(0.2, 7, 0.1)), property
	)
	_check(
		wall_only.outside_play and not wall_only.clear_walls,
		"being outside play cannot hide a real physical wall-slab overlap"
	)
	var beyond: Dictionary = _finite_clearance(
		AABB(Vector3(-0.1, 0, 24), Vector3(0.2, 7, 0.2)), property
	)
	_check(
		beyond.outside_play and beyond.clear_walls,
		"finite footprint accepts truly separated space behind the actual wall"
	)
	var unit_square: PackedVector2Array = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	_check(
		not _strictly_separated(AABB(Vector3(1, 0, 0), Vector3.ONE), unit_square),
		"strict footprint oracle rejects exact edge-touch without widening tolerance"
	)


func _bounds_record(bounds: AABB) -> Dictionary:
	return {
		"position": [bounds.position.x, bounds.position.y, bounds.position.z],
		"size": [bounds.size.x, bounds.size.y, bounds.size.z],
		"end": [bounds.end.x, bounds.end.y, bounds.end.z]
	}


func _supplement_current_public_membership(id: String) -> bool:
	var helper: Variant = load("res://src/tests/yard_current_membership_checks.gd")
	var rows: Array[Dictionary] = helper.check(id)
	var ok: bool = not rows.is_empty()
	for row: Dictionary in rows:
		_check(row.ok, "YARD_CURRENT_MEMBERSHIP_SUPPLEMENT " + id + ": " + row.label)
		ok = ok and bool(row.ok)
	print("YARD_CURRENT_MEMBERSHIP_SUPPLEMENT " + JSON.stringify({
		"id": id, "checks": rows.size(), "ok": ok, "original_default_credit": false}))
	return ok
