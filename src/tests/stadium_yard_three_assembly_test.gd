extends "res://src/tests/stadium_yard_assembly_test.gd"
## Independent physical oracle: qualified Yard construction plus literal archived light sites.

const SITES: Array[String] = ["YLIGHT-FL", "YLIGHT-FR", "YLIGHT-RL", "YLIGHT-RR"]
const POINTS: Array[Vector3] = [Vector3(-25, 0, 0), Vector3(25, 0, 0),
	Vector3(-25, 0, 25), Vector3(25, 0, 25)]
const PREFIX: String = "npc-candidate:AY-03:"


func _ready() -> void:
	var record: Dictionary = StadiumYardThreeStudy.canonical()
	var actual: StadiumPropertyGeometry = StadiumYardThreeStudy.build()
	var expected: StadiumPropertyGeometry = _reference()
	_check(actual != null and expected != null, "both independent complete constructions exist")
	if actual == null or expected == null:
		if actual != null:
			actual.free()
		if expected != null:
			expected.free()
		get_tree().quit(1)
		return
	# The inherited bounds inspector uses real global transforms. Attach the complete assembly
	# before measuring any model; keep it attached through the installed physics controls below.
	add_child(actual)
	_check(_same(actual, expected), "exact field/host/model/pose/light/collision correspondence")
	_check(record.id == "AY-03" and record.items.size() == 8 and record.live_units == 0
		and record.blueprint_entitlements == ["ST-037", "ST-080"], "exact eight-copy composition")
	_check(record.endowment.blueprint_value == 450 and record.endowment.copy_value == 420
		and record.endowment.land_value == 0 and record.endowment.total_value == 870
		and not record.endowment.spendable, "870 descriptive endowment, never human funds")
	_check(record.environment.certificates.is_empty() and not record.environment.night_eligible
		and record.environment.target_slots == ["13:10", "16:10"]
		and record.lighting.presentation == "dormant-daylight", "four poles grant no night authority")
	_check(actual.field.id == &"field.npc_venue" and actual.field != StadiumYardThreeStudy.FIELD
		and actual.field.display_name == "NPC Venue", "private field resource is copied exactly")
	_prisms(actual)
	for row: Dictionary in record.items:
		var model: Node3D = actual.objects.get(row.instance)
		_check(model != null and row.host == "field"
			and row.item == model.get_meta("stadium_item")
			and row.transform == StadiumYardVenueStudy.components(model.transform),
			"expanded persisted row exactly matches actual field host/item/pose")
		if model != null and row.item == "ST-037":
			_check(row.model == "yard-light-v2" and row.beam_transform
				== StadiumYardVenueStudy.components(model.get_node("FieldLight").transform),
				"persisted light model and beam pose match actual independent physical construction")
	_finite_clearance_controls(actual)
	for index in range(4):
		var model: Node3D = actual.objects[PREFIX + SITES[index]]
		_check(model.position == POINTS[index], "fixed archived light site " + SITES[index])
		var local_bounds: AABB = _bounds(model, model)
		var world_bounds: AABB = model.global_transform * local_bounds
		var envelope_ok: bool = StadiumYardLightModels.ENVELOPE.grow(0.0001).encloses(local_bounds)
		var property_ok: bool = StadiumProperty.contains("backyard", world_bounds)
		var clearance: Dictionary = _finite_clearance(world_bounds, actual)
		print("AY03_LIGHT_BOUNDS ", JSON.stringify({"site": SITES[index],
			"local": _bounds_record(local_bounds), "world": _bounds_record(world_bounds),
			"envelope_ok": envelope_ok, "property_ok": property_ok,
			"finite_play_ok": clearance.outside_play, "wall_slabs_clear": clearance.clear_walls,
			"legacy_seating_buffer_ok": StadiumSeatingLayout._outside_play(world_bounds)},
			"", true, true))
		_check(envelope_ok, "actual light fits unchanged local envelope " + SITES[index])
		_check(property_ok, "actual light fits unchanged Backyard property " + SITES[index])
		_check(clearance.outside_play, "actual light clears finite Yard play polygon " + SITES[index])
		_check(clearance.clear_walls, "actual light clears all physical wall slabs " + SITES[index])
		var beam: SpotLight3D = model.get_node("FieldLight")
		var target: Vector3 = Vector3(0, 0.7, 8 if index < 2 else 18)
		var toward: Vector3 = (target - model.transform * beam.position).normalized()
		_check((-(model.basis * beam.basis).z).normalized().dot(toward) > 0.999999,
			"actual fixed beam aim points at retained front/rear target")
		_check(not beam.visible and beam.light_energy == float(PackedFloat32Array([0.40])[0])
			and beam.spot_range == 54
			and beam.spot_angle == 68 and beam.shadow_enabled, "qualified optics are dormant")
		var material: StandardMaterial3D = model.get_node("Visual/LampLens").material_override
		_check(not material.emission_enabled, "daylight lenses do not emit")
		for body: StaticBody3D in model.get_node("Collision").get_children():
			_check(body.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL"
				and body.get_meta("candidate_instance") == PREFIX + SITES[index]
				and not body.has_meta("owned_copy"), "decorative pole has no human receipt")
	for edit in range(23):
		var changed: StadiumPropertyGeometry = StadiumYardThreeStudy.build()
		if changed == null:
			_check(false, "mutation control constructor failed")
			continue
		var light: Node3D = changed.objects[PREFIX + "YLIGHT-FL"]
		var beam: SpotLight3D = light.get_node("FieldLight")
		match edit:
			0: light.position.x += 0.0001
			1: light.scale.x = 1.0001
			2: light.set_meta("candidate_host", "SC-L1")
			3: light.set_meta("candidate_instance", PREFIX + "SC-L1")
			4: light.set_meta("stadium_item", "ST-038")
			5: light.get_node("Visual/Footing").mesh.size.x += 0.001
			6: light.get_node("Collision/Pole").get_child(0).shape.radius += 0.001
			7: light.get_node("Collision/Pole").get_child(0).disabled = true
			8: light.get_node("Collision/Pole").collision_layer = 0
			9: light.get_node("Collision/Pole").set_meta("surface_role", "LIVE_OBJECT")
			10: beam.visible = true
			11: beam.light_energy += 0.001
			12: beam.spot_angle += 0.01
			13: beam.rotation.x += 0.001
			14: light.get_node("Visual/LampLens").material_override.emission_enabled = true
			15: changed.field.safe_hit_z_m += 0.001
			16: changed.field.id = &"field.starter_backyard"
			17:
				var foreign: Node3D = Node3D.new()
				changed.add_child(foreign)
				changed.remove_child(light)
				foreign.add_child(light)
			18:
				var shape: ConvexPolygonShape3D = changed.get_node(
					"BoundaryGraph").get_child(0).get_child(0).shape
				var points: PackedVector3Array = shape.points
				points[0].x += 0.01
				shape.points = points
			19: light.process_mode = Node.PROCESS_MODE_DISABLED
			20:
				light.get_node("Collision/Pole").disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			21: light.get_node("Collision/Pole").process_mode = Node.PROCESS_MODE_DISABLED
			22:
				var forged: GDScript = GDScript.new()
				forged.source_code = "extends Node3D\n"
				_check(forged.reload() == OK, "anonymous-script negative control compiles")
				light.set_script(forged)
		_check(not _same(changed, expected),
			"unchanged record cannot hide physical mutation " + str(edit))
		_check(ClubCareer.same(changed.get_meta("candidate_venue"), record),
			"negative control left candidate metadata unchanged")
		changed.free()
	_check(_supplement_current_public_membership("AY-03")
		and StadiumNpcVenues.definition("AY-03", 2).is_empty()
		and not StadiumNpcVenues.valid_manifest(record), "authoring never admits NPC production data")
	await _installed_collision_modes(actual, expected)
	actual.free()
	expected.free()
	await get_tree().process_frame
	if _failures == 0:
		print("Wiffaltro yard-three assembly passed: "
			+ "exact AY-03 and independent physical mutation controls.")
	get_tree().quit(0 if _failures == 0 else 1)


func _reference() -> StadiumPropertyGeometry:
	# Never call AY-03 construction/canonical here: independently expand the archived composition.
	var result: StadiumPropertyGeometry = StadiumYardVenueStudy.build()
	if result == null:
		return null
	result.name = "AY03Candidate"
	result.field = preload("res://src/content/fields/npc_venue_field.tres").duplicate(true)
	var objects: Dictionary = {}
	for site: String in ["SC-L1", "SC-L2", "SC-R1", "SC-R2"]:
		objects[PREFIX + site] = result.objects["npc-candidate:AY-01:" + site]
	for index in range(4):
		var model: Node3D = StadiumYardLightModels.create()
		model.name = SITES[index]
		StadiumYardLightModels.place(model, SITES[index])
		result.add_child(model)
		objects[PREFIX + SITES[index]] = model
	result.objects = objects
	return result


func _same(actual: StadiumPropertyGeometry, expected: StadiumPropertyGeometry) -> bool:
	if not _node_policies(actual, expected) or actual.objects.keys() != expected.objects.keys() \
		or actual.tier != "backyard" \
		or actual.field.get_script() != expected.field.get_script() \
		or var_to_bytes(StadiumNpcRetainedGeometry._geometry(actual)) != var_to_bytes(
			StadiumNpcRetainedGeometry._geometry(expected)):
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		if actual.field.get(key) != expected.field.get(key):
			return false
	for identity: String in actual.objects:
		var model: Node3D = actual.objects[identity]
		if model.get_parent() != actual or model.has_meta("owned_copy") \
			or model.get_meta("candidate_instance", "") != identity \
			or model.get_meta("candidate_site", "") != identity.trim_prefix(PREFIX) \
			or model.get_meta("candidate_host", "") != "field":
			return false
		if model.has_node("FieldLight"):
			# The shared mesh inspector predates lights. Inspect all stored light properties too.
			if var_to_bytes(StadiumNpcRetainedGeometry._stored(model.get_node("FieldLight"))) != \
				var_to_bytes(StadiumNpcRetainedGeometry._stored(
					expected.objects[identity].get_node("FieldLight"))):
				return false
	return actual.route_obstacles().is_empty()


func _node_policies(actual: Node, expected: Node) -> bool:
	# An in-memory script has no resource_path; actual identity and execution modes still matter.
	if actual.get_script() != expected.get_script() or actual.process_mode != expected.process_mode \
		or actual.get_child_count() != expected.get_child_count():
		return false
	if actual is CollisionObject3D and (not expected is CollisionObject3D \
		or actual.disable_mode != expected.disable_mode):
		return false
	for index in range(actual.get_child_count()):
		if not _node_policies(actual.get_child(index), expected.get_child(index)):
			return false
	return true


func _installed_collision_modes(actual: StadiumPropertyGeometry,
	expected: StadiumPropertyGeometry) -> void:
	if not actual.is_inside_tree() or actual.get_parent() != self:
		_check(false, "installed collision controls require the same attached complete assembly")
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(-25, 2, -1), Vector3(-25, 2, 1), 1)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var pole: StaticBody3D = actual.objects[PREFIX + "YLIGHT-FL"].get_node("Collision/Pole")
	var hit: Dictionary = space.intersect_ray(ray)
	_check(not hit.is_empty() and hit.collider == pole and _same(actual, expected),
		"installed exact pole is physically present before execution-mode controls")
	for target: Node in [actual, pole]:
		var before: Node.ProcessMode = target.process_mode
		target.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(not _same(actual, expected) and space.intersect_ray(ray).is_empty(),
			"disabled installed root/body genuinely removes the pole and fails exact correspondence")
		target.process_mode = before
		await get_tree().physics_frame
		await get_tree().physics_frame
		hit = space.intersect_ray(ray)
		_check(_same(actual, expected) and not hit.is_empty() and hit.collider == pole,
			"restoring installed execution mode restores both physical pole and exact correspondence")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	remove_child(actual)


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
	var corners: PackedVector2Array = [Vector2(bounds.position.x, bounds.position.z),
		Vector2(bounds.end.x, bounds.position.z), Vector2(bounds.end.x, bounds.end.z),
		Vector2(bounds.position.x, bounds.end.z)]
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
	var inside: Dictionary = _finite_clearance(AABB(Vector3(-0.1, 0, 13.9),
		Vector3(0.2, 7, 0.2)), property)
	_check(not inside.outside_play, "finite-footprint oracle rejects an in-field pole volume")
	var straddle: Dictionary = _finite_clearance(AABB(Vector3(-0.1, 0, 23.3),
		Vector3(0.2, 7, 0.2)), property)
	_check(not straddle.outside_play and not straddle.clear_walls,
		"finite-footprint oracle rejects actual back-line and wall overlap")
	var wall_only: Dictionary = _finite_clearance(AABB(Vector3(-0.1, 0, 23.45),
		Vector3(0.2, 7, 0.1)), property)
	_check(wall_only.outside_play and not wall_only.clear_walls,
		"being outside play cannot hide a real physical wall-slab overlap")
	var beyond: Dictionary = _finite_clearance(AABB(Vector3(-0.1, 0, 24),
		Vector3(0.2, 7, 0.2)), property)
	_check(beyond.outside_play and beyond.clear_walls,
		"finite footprint accepts truly separated space behind the actual wall")
	var unit_square: PackedVector2Array = [Vector2.ZERO, Vector2.RIGHT,
		Vector2.ONE, Vector2.DOWN]
	_check(not _strictly_separated(AABB(Vector3(1, 0, 0), Vector3.ONE), unit_square),
		"strict footprint oracle rejects exact edge-touch without widening tolerance")


func _bounds_record(bounds: AABB) -> Dictionary:
	return {"position": [bounds.position.x, bounds.position.y, bounds.position.z],
		"size": [bounds.size.x, bounds.size.y, bounds.size.z],
		"end": [bounds.end.x, bounds.end.y, bounds.end.z]}


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
