extends Node3D
## Private proposed anchor placement/reset only. No live fielding, ball or motion qualification.

const FIELD: FieldDefinition = preload("res://src/content/fields/npc_venue_field.tres")
const SUPPORT_Z: Array[float] = [16.0, 17.0, 23.4, 26.0]
const SETTLE_FRAMES: int = 20
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_records()
	for profile: String in StadiumHillsideTerrain.PROFILES:
		await _exercise_profile(profile)
	print("HILLSIDE_ANCHOR_CONTRACT checks=%d failures=%d" % [_checks, _failures])
	if _failures == 0:
		print("Private Hillside anchor lifecycle passed; terrain geometry remains Working.")
	get_tree().quit(0 if _failures == 0 else 1)


func _records() -> void:
	_check(not FIELD.shallow_center_available and not FIELD.middle_center_available,
		"canonical NPC resource retains its two unavailable center slots")
	for profile: String in StadiumHillsideTerrain.PROFILES:
		var rows: Array[Dictionary] = StadiumHillsideAnchorContract.anchors(FIELD, profile)
		_check(rows.size() == 9, "all nine existing slots retained: " + profile)
		for index in range(9):
			var row: Dictionary = StadiumHillsideAnchorContract.anchor(FIELD, index, profile)
			_check(rows.size() == 9 and not row.is_empty() and rows[index] == row and row.index == index
				and row.available == FIELD.is_fielder_anchor_available(index)
				and row.source_anchor == FIELD.fielder_anchor(index),
				"original slot identity, XZ and availability retained: " + str(index))
			_record(row, Vector2(FIELD.fielder_anchor(index).x,
				FIELD.fielder_anchor(index).z), profile, true)
		for shallow: bool in [false, true]:
			for middle: bool in [false, true]:
				var field: FieldDefinition = FIELD.duplicate(true) as FieldDefinition
				field.shallow_center_available = shallow
				field.middle_center_available = middle
				var flags: Array[Dictionary] = StadiumHillsideAnchorContract.anchors(field, profile)
				for index in range(9):
					_check(flags.size() == 9
						and flags[index].available == field.is_fielder_anchor_available(index)
						and flags[index].source_anchor == FIELD.fielder_anchor(index),
						"each availability combination preserves all authored anchors")
		for z: float in SUPPORT_Z:
			_record(StadiumHillsideAnchorContract.support(Vector2(0, z), profile),
				Vector2(0, z), profile, false)
		var off_knot: Dictionary = StadiumHillsideAnchorContract.support(Vector2(0, 18.375), profile)
		_check(off_knot.design_minus_support == off_knot.design_height - off_knot.support_height
			and (off_knot.design_minus_support != 0.0 if profile == "hill"
			else off_knot.design_minus_support == 0.0),
			"off-knot record distinguishes analytic design from physical sampled support")
	_check(StadiumHillsideAnchorContract.anchor(null, 0).is_empty()
		and StadiumHillsideAnchorContract.anchor(FIELD, -1).is_empty()
		and StadiumHillsideAnchorContract.anchor(FIELD, 9).is_empty()
		and StadiumHillsideAnchorContract.anchor(FIELD, 0, "unsupported").is_empty()
		and StadiumHillsideAnchorContract.support(Vector2(NAN, 17)).is_empty()
		and StadiumHillsideAnchorContract.support(Vector2(0, 17), "unsupported").is_empty()
		and StadiumHillsideAnchorContract.support(Vector2(32.1, 17)).is_empty()
		and StadiumHillsideAnchorContract.support(Vector2(0, 38.1)).is_empty(),
		"invalid index, field, profile, nonfinite and out-of-property support refused")


func _record(row: Dictionary, xz: Vector2, profile: String, is_anchor: bool) -> void:
	var types: Dictionary = {"position": TYPE_VECTOR3, "design_height": TYPE_FLOAT,
		"support_height": TYPE_FLOAT, "design_minus_support": TYPE_FLOAT,
		"support_normal": TYPE_VECTOR3, "terrain_signature": TYPE_STRING,
		"profile": TYPE_STRING, "production_ready": TYPE_BOOL, "status": TYPE_STRING}
	if is_anchor:
		types.merge({"index": TYPE_INT, "available": TYPE_BOOL, "source_anchor": TYPE_VECTOR3})
	var valid: bool = true
	for key: String in types:
		valid = valid and row.has(key) and typeof(row.get(key)) == types[key]
	_check(valid, "anchor/support records have concrete contract types")
	if not valid:
		return
	var point: Vector3 = row.position
	_check(point == Vector3(xz.x, row.support_height, xz.y)
		and row.support_height == StadiumHillsideTerrain.support_height(xz, profile)
		and row.design_height == StadiumHillsideTerrain.design_height(xz.y, profile)
		and row.design_minus_support == row.design_height - row.support_height
		and row.support_normal == StadiumHillsideTerrain.support_normal(xz, profile),
		"sampled support, design and normal have their separate exact authorities")
	_check(row.profile == profile
		and row.terrain_signature == StadiumHillsideTerrain.signature(profile)
		and row.status == "Working" and not row.production_ready,
		"proposed profile identity never grants production admission")
	_check(profile != "flat-control" or (point == Vector3(xz.x, 0.0, xz.y)
		and row.support_height == 0.0 and row.design_height == 0.0
		and row.design_minus_support == 0.0 and row.support_normal == Vector3.UP),
		"flat control preserves exact existing XZ, zero Y and up normal")


func _exercise_profile(profile: String) -> void:
	var terrain: Node3D = StadiumHillsideTerrainModels.create(profile)
	add_child(terrain)
	var body: StaticBody3D = terrain.get_node("TerrainCollision") as StaticBody3D
	var shape: CollisionShape3D = body.get_node("ClosedTerrainShape") as CollisionShape3D
	await _wait_frames(2)
	_check(shape.shape is ConcavePolygonShape3D and not shape.disabled
		and body.collision_layer == (1 | StadiumHillsideTerrainModels.QUERY_LAYER),
		"retained closed terrain collider supplies the actual physical support")
	var probe: StadiumHillsideAnchorProbe = StadiumHillsideAnchorProbe.new()
	add_child(probe)
	_check(probe.configure(FIELD, terrain, profile), "canonical field binds exact terrain")
	_check(probe.start(0), "initial canonical placement accepted")
	_reset(probe, FIELD, 0, profile, "idle")
	await _settled(probe, body, profile)
	for unavailable: int in [1, 4]:
		var before: Vector3 = probe.probe_actor.global_position
		_check(not probe.set_anchor(unavailable) and probe.selected_index == 0
			and probe.state == "idle" and probe.probe_actor.active
			and probe.probe_actor.global_position == before,
			"unavailable existing slot refuses placement without changing the valid actor")
	var before_invalid: Vector3 = probe.probe_actor.global_position
	_check(not probe.set_anchor(9) and probe.selected_index == 0
		and probe.probe_actor.global_position == before_invalid,
		"unknown slot is not clamped into an available existing slot")
	probe.stop()
	_stopped(probe)
	var enabled: FieldDefinition = FIELD.duplicate(true) as FieldDefinition
	enabled.shallow_center_available = true
	enabled.middle_center_available = true
	_check(probe.configure(enabled, terrain, profile), "explicit enabled-centers field binds")
	for index in range(9):
		var accepted: bool = probe.start(index) if index == 0 else probe.set_anchor(index)
		_check(accepted, "all nine exact existing positions physically place or switch while idle")
		_reset(probe, enabled, index, profile, "idle")
		await _settled(probe, body, profile)
	_check(probe.begin_play(), "private begin-play reset accepted")
	_reset(probe, enabled, 8, profile, "playing")
	await _settled(probe, body, profile)
	var before_playing: Vector3 = probe.probe_actor.global_position
	_check(not probe.set_anchor(0) and probe.state == "playing" and probe.selected_index == 8
		and probe.probe_actor.global_position == before_playing and probe.probe_actor.active,
		"playing state refuses an idle-only anchor switch")
	_check(probe.end_play(), "private end-play reset accepted")
	_reset(probe, enabled, 8, profile, "idle")
	await _settled(probe, body, profile)
	probe.stop()
	_stopped(probe)
	_check(probe.restart(), "stopped private probe restarts at retained selected slot")
	_reset(probe, enabled, 8, profile, "idle")
	await _settled(probe, body, profile)
	for z: float in SUPPORT_Z:
		probe.stop()
		var landmark: FieldDefinition = enabled.duplicate(true) as FieldDefinition
		landmark.middle_center_anchor_z_m = z
		_check(probe.configure(landmark, terrain, profile), "existing center slot binds support landmark")
		_check(probe.start(4), "physical placement at support landmark z=" + str(z))
		_reset(probe, landmark, 4, profile, "idle")
		await _settled(probe, body, profile)
	await _refusals(probe, enabled, terrain, body, profile)
	probe.queue_free()
	await _wait_frames(2)


func _reset(probe: StadiumHillsideAnchorProbe, field: FieldDefinition, index: int,
	profile: String, expected_state: String) -> void:
	var row: Dictionary = StadiumHillsideAnchorContract.anchor(field, index, profile)
	_check(probe.state == expected_state and probe.selected_index == index
		and probe.anchor_record == row and is_instance_valid(probe.probe_actor)
		and probe.probe_actor is CharacterBody3D and probe.probe_actor.active,
		"lifecycle reset preserves selected anchor and actual retained actor")
	var actor: StadiumHillsideProbeActor = probe.probe_actor
	_check(actor.global_position == row.position + Vector3.UP * 0.05
		and actor.command == Vector2.ZERO and actor.velocity == Vector3.ZERO
		and actor.elapsed == 0.0 and actor.profile == profile,
		"reset is exact retained physical spawn with zero command, velocity and elapsed time")


func _settled(probe: StadiumHillsideAnchorProbe, body: StaticBody3D, profile: String) -> void:
	await _wait_frames(SETTLE_FRAMES)
	var actor: StadiumHillsideProbeActor = probe.probe_actor
	_check(actor.active and actor.is_on_floor() and actor.body_clear()
		and actor.command == Vector2.ZERO and actor.elapsed > 0.0,
		"zero-command retained actor has real settled floor contact and capsule clearance")
	var point: Vector3 = StadiumHillsideTerrain.point(actor.global_position.x,
		actor.global_position.z, profile)
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 3.0, point - Vector3.UP * 3.0,
		StadiumHillsideTerrainModels.QUERY_LAYER)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	_check(not hit.is_empty() and hit.collider == body
		and hit.position.distance_to(point) <= 0.0002,
		"actual bound collider and physical sampled top agree within inherited ray-match allowance")


func _stopped(probe: StadiumHillsideAnchorProbe) -> void:
	_check(probe.state == "stopped" and not probe.probe_actor.active
		and probe.probe_actor.command == Vector2.ZERO and probe.probe_actor.velocity == Vector3.ZERO,
		"stop deactivates retained actor and clears its zero-motion lifecycle state")


func _refusals(probe: StadiumHillsideAnchorProbe, field: FieldDefinition,
	terrain: Node3D, body: StaticBody3D, profile: String) -> void:
	probe.stop()
	var unsupported: Node3D = Node3D.new()
	add_child(unsupported)
	_check(not probe.configure(field, unsupported, profile),
		"unsupported root without physical terrain refused")
	_check(not probe.configure(field, terrain, "unsupported"), "unknown terrain profile refused")
	_check(not probe.configure(field, terrain, "flat-control" if profile == "hill" else "hill"),
		"physical profile mismatch refused even where both profiles have a flat region")
	unsupported.queue_free()
	var outside: FieldDefinition = field.duplicate(true) as FieldDefinition
	outside.side_anchor_x_m = 32.1
	_check(StadiumHillsideAnchorContract.anchor(outside, 2, profile).is_empty(),
		"out-of-property existing slot has no invented support record")
	var configured_outside: bool = probe.configure(outside, terrain, profile)
	_check(configured_outside,
		"terrain binding alone does not silently rewrite out-of-property slot data")
	_check(not probe.start(2), "out-of-property actor placement refused")
	_check(probe.state == "stopped" and probe.selected_index == -1
		and not probe.probe_actor.active,
		"refused unsupported or outside placement creates no active actor or selected slot")
	_check(probe.configure(field, terrain, profile),
		"valid terrain can be configured after rejected request")
	_check(probe.start(4), "support-loss control starts on valid existing slot")
	_reset(probe, field, 4, profile, "idle")
	await _settled(probe, body, profile)
	body.collision_layer = 0
	await _wait_frames(2)
	_check(probe.state == "blocked" and not probe.probe_actor.active
		and probe.probe_actor.command == Vector2.ZERO and probe.probe_actor.velocity == Vector3.ZERO,
		"removed physical collision support blocks even stationary private probe")
	_check(not probe.restart() and probe.state == "blocked" and not probe.probe_actor.active,
		"restart refuses removed physical collision support")
	body.collision_layer = 1 | StadiumHillsideTerrainModels.QUERY_LAYER
	await _wait_frames(2)
	_check(probe.restart(), "restored physical support permits explicit restart")
	_reset(probe, field, 4, profile, "idle")
	await _settled(probe, body, profile)
	terrain.queue_free()
	await _wait_frames(2)
	_check(not is_instance_valid(terrain) and probe.state == "blocked"
		and not probe.probe_actor.active,
		"freed bound terrain cannot be silently replaced by formula-only support")
	_check(not probe.restart() and probe.state == "blocked", "freed terrain refuses restart")


func _wait_frames(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
