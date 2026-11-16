extends Node3D
## Native-ready ST032 geometry tests. Never presented as an executed qualification.
## Direct sweeps exercise actual BoxShape3D surfaces. Physics probes use legal swing
## inputs through ContactResolver and untouched launch outputs; gravity/aero are off
## solely to isolate jamb/entry geometry, not to claim an ordinary match trajectory.

var _failures: int = 0
var _host: Node3D
var _graph: StadiumTimberDugoutBoundary
var _bodies: Array[StaticBody3D] = []
var _previous: Vector3
var _resolver: BallPlayResolver
var _outcomes: Array[BallPlayOutcome] = []
var _physical_contacts: int = 0
var _live_segment: String = ""
var _query_diagnostic_count: int = 0


func _ready() -> void:
	var old_signature: String = StadiumDugoutBoundary.candidate("straight").signature()
	_graph = StadiumTimberDugoutBoundary.candidate("straight")
	_check(_graph != null and StadiumTimberDugoutBoundary.candidate("deeper_center") == null,
		"the timber runtime is restricted to this exact straight recipe")
	_host = Node3D.new()
	add_child(_host)
	for left: bool in [false, true]:
		_cold_binding(left)
		_build(left)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for left: bool in [false, true]:
		_spheres(left)
		_terminal_rules(left)
		await _physical_probe(left, 68.5, "DUGOUT_OPENING_DEAD")
		await _physical_probe(left, 65.0, "DUGOUT_FACE_LIVE")
	_radius_integrity()
	_check(StadiumDugoutBoundary.candidate("straight").signature() == old_signature,
		"ST074 and its saved graph stay unchanged")
	_check(_graph.segment("DUGOUT-R-OPEN").height == 1.30,
		"timber entry is 1.30m instead of concrete roof height")
	_check(not _graph.contains(Vector2(50, 10)), "dugout interior never becomes a field route")
	print("TIMBER_QUERY_DIAGNOSTIC_TOTAL=", _query_diagnostic_count)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("ST032 timber real-sphere geometry and genuine-contact probes passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _cold_binding(left: bool) -> void:
	var model: Node3D = StadiumTimberDugoutModels.create()
	model.transform = StadiumTimberDugoutContract.placement(left)
	var record: Dictionary = StadiumTimberDugoutContract.interface(left)
	_check(StadiumTimberDugoutContract.valid_binding(model, left, record),
		"untouched authentic handed timber cold-binds")
	model.scale.x = 1.01
	_check(not StadiumTimberDugoutContract.valid_binding(model, left, record),
		"scaled timber fails cold binding")
	model.transform = StadiumTimberDugoutContract.placement(left)
	var shape: CollisionShape3D = model.get_node("Collision/FrontBarrier-1/Shape")
	shape.shape.size.x += 0.01
	_check(not StadiumTimberDugoutContract.valid_binding(model, left, record),
		"invisible widened jamb fails exact model-tree binding")
	model.free()


func _build(left: bool) -> void:
	var root: Node3D = StadiumTimberDugoutModels.create()
	root.transform = StadiumTimberDugoutContract.placement(left)
	_host.add_child(root)
	for body: StaticBody3D in root.get_node("Collision").get_children():
		if body.get_meta("surface_role") != "DUGOUT_FACE_LIVE":
			body.collision_layer = 0
			body.collision_mask = 0
			continue
		var inner: bool = String(body.name).ends_with("-1") == left
		var prefix: String = "DUGOUT-L" if left else "DUGOUT-R"
		body.collision_layer = 1 | StadiumTimberDugoutBoundary.QUERY_MASK
		body.collision_mask = 2
		body.set_meta("club_surface", prefix + ("-FACE-IN" if inner else "-FACE-OUT"))
		body.set_meta("surface_priority", 350)
		body.set_meta("surface_kind", "dugout")
		_bodies.append(body)
	_check(_bodies.size() == (4 if left else 2), "only two real low fronts per hand are live")


func _spheres(left: bool) -> void:
	var cases: Array = [
		[13.0, 0.5, 0.0365, "DUGOUT_OPENING_DEAD"],
		[12.02, 0.5, 0.0365, "DUGOUT_FACE_LIVE"],
		[13.98, 0.5, 0.0365, "DUGOUT_FACE_LIVE"],
		[12.05, 0.5, 0.0365, "DUGOUT_OPENING_DEAD"],
		[13.95, 0.5, 0.0365, "DUGOUT_OPENING_DEAD"],
		[12.05, 0.5, 0.08, "DUGOUT_FACE_LIVE"],
		[13.95, 0.5, 0.08, "DUGOUT_FACE_LIVE"],
		[10.0, 0.5, 0.0365, "DUGOUT_FACE_LIVE"],
		[16.0, 0.5, 0.0365, "DUGOUT_FACE_LIVE"],
		[12.0, 0.5, 0.0365, "DUGOUT_FACE_LIVE"],
		[14.0, 0.5, 0.0365, "DUGOUT_FACE_LIVE"],
		[11.0, 1.22, 0.0365, "DUGOUT_FACE_LIVE"],
		[11.0, 1.25, 0.0365, "SIDE_EXIT_DEAD"],
		[11.0, 1.25, 0.08, "DUGOUT_FACE_LIVE"],
		[13.0, 1.29, 0.0365, "DUGOUT_OPENING_DEAD"],
		[13.0, 1.31, 0.0365, "DUGOUT_EXTERIOR_DEAD"],
		[13.0, 2.5, 0.0365, "DUGOUT_EXTERIOR_DEAD"]
	]
	for row: Array in cases:
		for distance: float in [0.5, 5.0, 100.0]:
			var from: Vector3 = _point(row[0], -0.5, row[1], left)
			var to: Vector3 = _point(row[0], distance, row[1], left)
			var hit: Dictionary = StadiumTimberDugoutBoundary.event(
				_host, _graph, _bodies, from, to, row[2])
			if hit.get("role") != row[3] or (hit.get("role") == "DUGOUT_FACE_LIVE"
				and not hit.get("swept_contact", false)):
				_query_diagnostic(left, row, distance, from, to, hit)
			_check(hit.get("role") == row[3], "real-radius role " + str(row) + ": " + str(hit))
			if hit.get("role") == "DUGOUT_FACE_LIVE":
				_check(hit.get("swept_contact", false), "jamb/front requires a real sphere contact"
					+ " left=" + str(left) + " row=" + str(row) + " distance=" + str(distance)
					+ " selected=" + str(hit))
			else:
				_check(not hit.has("npc_instance") and not hit.get("swept_contact", false),
					"open space has no invented solid or NPC contact provenance")
	var from: Vector3 = _point(13, -0.5, 0.5, left)
	var to: Vector3 = _point(13, 0.5, 0.5, left)
	_check(StadiumTimberDugoutBoundary.event(_host, _graph, _bodies, from, to, 0).is_empty(),
		"missing physical radius fails closed")
	_check(StadiumTimberDugoutBoundary.event(_host, _graph, _bodies, to, from, 0.0365).is_empty(),
		"interior-to-field open passage cannot manufacture an outward crossing")
	var touch: Dictionary = {"fraction": 0.5, "swept_contact": true,
		"priority": 350, "segment": "closed-jamb"}
	var opening: Dictionary = {"fraction": 0.5, "priority": 250, "segment": "entry"}
	_check(StadiumTimberDugoutBoundary.precedes(touch, opening, 1)
		and not StadiumTimberDugoutBoundary.precedes(opening, touch, 1),
		"solid precedes same-time aperture crossing")


func _terminal_rules(left: bool) -> void:
	for foul: bool in [false, true]:
		for earned: int in [BallPlayState.ResultFloor.NONE, BallPlayState.ResultFloor.DOUBLE]:
			_outcomes.clear()
			var resolver: BallPlayResolver = BallPlayResolver.new()
			resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
			resolver.state.raise_result_floor(earned)
			resolver.play_resolved.connect(func(value: BallPlayOutcome) -> void: _outcomes.append(value))
			var selected: Dictionary = StadiumTimberDugoutBoundary.event(_host, _graph, _bodies,
				_point(13, -0.5, 0.5, left), _point(13, 0.5, 0.5, left), 0.0365)
			_check(_graph.apply(resolver, selected), "measured entry uses shared graph resolver")
			var expected: int = BallPlayOutcome.Result.FOUL if foul else (
				BallPlayOutcome.Result.DOUBLE if earned == BallPlayState.ResultFloor.DOUBLE
				else BallPlayOutcome.Result.SINGLE)
			_check(_outcomes.size() == 1 and _outcomes[0].result == expected,
				"entry preserves earned Double, minimum Single, or initial Foul")
			var history: Array = resolver.state.stadium_contacts.duplicate(true)
			_check(not _graph.apply(resolver, selected) and _outcomes.size() == 1
				and resolver.state.stadium_contacts == history,
				"terminal furniture/rebound cannot reopen or rewrite result")


func _physical_probe(left: bool, spray: float, expected_role: String) -> void:
	var launch: BattedBallLaunch = _genuine_launch(left, spray)
	_check(launch != null, "legal resolver-produced probe launch")
	if launch == null:
		return
	_outcomes.clear()
	_physical_contacts = 0
	_live_segment = ""
	_resolver = BallPlayResolver.new()
	_resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), launch.is_foul)
	_resolver.play_resolved.connect(func(value: BallPlayOutcome) -> void: _outcomes.append(value))
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	_previous = launch.position
	ball.physics_contact_router = _contact_batch
	ball.launch(launch)
	for frame: int in range(400):
		await get_tree().physics_frame
		if _resolver.state.dead or (_physical_contacts > 0 and not _live_segment.is_empty()):
			break
	var contacts: Array = _resolver.state.stadium_contacts
	_check(not contacts.is_empty() and contacts.back().role == expected_role,
		"genuine bat launch reaches expected real timber role: " + expected_role)
	if expected_role == "DUGOUT_FACE_LIVE":
		_check(_physical_contacts > 0 and not _resolver.state.dead and _outcomes.is_empty(),
			"actual ball-body jamb/barrier contact remains live")
	else:
		_check(_resolver.state.dead and _outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.FOUL,
			"actual open flight keeps genuine contact's foul assignment")
	var before: Array = contacts.duplicate(true)
	for frame: int in range(3):
		await get_tree().physics_frame
	if expected_role != "DUGOUT_FACE_LIVE":
		_check(_resolver.state.stadium_contacts == before and _outcomes.size() == 1,
			"later actual physics cannot replace terminal result")
	ball.queue_free()
	await get_tree().process_frame


func _genuine_launch(left: bool, spray: float) -> BattedBallLaunch:
	var profile: SwingProfileDefinition = load("res://src/content/swings/power_swing.tres")
	var pitch: PitchState = PitchState.new()
	pitch.position = Vector3(0, 0.7, 0.25)
	pitch.velocity = Vector3(0, 0, -12)
	pitch.elapsed_time = 1.0166666666666666
	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = profile.id
	intent.handedness_left = not left
	intent.start_time_seconds = 0.8763333333333333
	intent.aim_point = Vector2(0, 0.7)
	var previous: Vector3 = Vector3(0, 0.7, 0.45)
	var first: ContactResult = ContactResolver.resolve_swept_segment(
		previous, 1.0, pitch, intent, profile, 10, 10)
	if first == null:
		return null
	# Choose reachable swing inputs; never edit contact or launch outputs.
	var factor: float = ContactResolver._contact_factor(10)
	var vertical_ratio: float = -profile.attack_angle_degrees / 32.0
	var quality: float = profile.minimum_contact_quality * (1.0 - (spray - 48.0) / 22.0)
	var depth: float = first.contact_position.z - ContactResolver.CONTACT_PLANE_Z
	var nz: float = depth / (profile.contact_depth_m * factor)
	var nx2: float = pow(1.0 - quality, 2) - vertical_ratio * vertical_ratio - nz * nz
	if nx2 < 0:
		return null
	intent.aim_point = Vector2(sqrt(nx2) * profile.contact_radius_x_m * factor,
		pitch.position.y - depth * tan(deg_to_rad(profile.attack_angle_degrees))
		- vertical_ratio * profile.contact_radius_y_m * factor)
	if SwingIntent.reachable_aim(intent.aim_point) != intent.aim_point:
		return null
	var contact: ContactResult = ContactResolver.resolve_swept_segment(
		previous, 1.0, pitch, intent, profile, 10, 10)
	if contact == null or contact.outcome != ContactResult.Outcome.FOUL:
		return null
	return BattedBallLaunch.from_contact(contact, pitch)


func _contact_batch(ball: BattedBallBody, batch: Array[Dictionary]) -> void:
	if _resolver.state.dead:
		return
	var current: Vector3 = ball.global_position
	var previous: Vector3 = _previous
	var selected: Dictionary = StadiumTimberDugoutBoundary.event(_host, _graph, _bodies,
		_previous, current, StadiumTimberDugoutBoundary.ball_radius(ball))
	_previous = current
	for contact: Dictionary in batch:
		if contact.body is StaticBody3D and _bodies.has(contact.body):
			_physical_contacts += 1
			if selected.is_empty():
				selected = StadiumTimberDugoutBoundary.contact_event(contact.body, contact.position, 1)
	if selected.is_empty() or selected.get("segment", "") == _live_segment:
		return
	if not _resolver.state.is_foul_play:
		StadiumBoundaryObserver._bands(_resolver, previous, selected.position)
	_graph.apply(_resolver, selected)
	if selected.role == "DUGOUT_FACE_LIVE":
		_live_segment = selected.segment


func _radius_integrity() -> void:
	var ball: BattedBallBody = BattedBallBody.new()
	add_child(ball)
	_check(is_equal_approx(StadiumTimberDugoutBoundary.ball_radius(ball), ball.radius_m),
		"physical collider supplies radius instead of visual/debug ball")
	ball.radius_m *= 2
	_check(StadiumTimberDugoutBoundary.ball_radius(ball) == 0,
		"stale radius metadata fails closed")
	ball.queue_free()


func _point(s: float, d: float, y: float, left: bool) -> Vector3:
	return StadiumDugoutRecipe.rail_point(s, d, left) + Vector3.UP * y


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _query_diagnostic(left: bool, row: Array, distance: float, from: Vector3,
	to: Vector3, selected: Dictionary) -> void:
	_query_diagnostic_count += 1
	if _query_diagnostic_count > 16:
		return
	var data: Dictionary = {"left": left, "s": row[0], "height": row[1], "radius": row[2],
		"expected_role": row[3], "distance": distance, "from": _vector_data(from),
		"to": _vector_data(to), "selected": selected, "graph": _graph.crossing(from, to),
		"physics_frame": Engine.get_physics_frames(), "diagnostic_index": _query_diagnostic_count}
	print("TIMBER_QUERY_DIAGNOSTIC=", JSON.stringify(data, "", true, true))
	var space: PhysicsDirectSpaceState3D = _host.get_world_3d().direct_space_state
	for body: StaticBody3D in _bodies:
		var collider: CollisionShape3D = body.get_node("Shape")
		var shape: BoxShape3D = collider.shape as BoxShape3D
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = SphereShape3D.new()
		query.shape.radius = row[2]
		query.shape.margin = 0
		query.margin = 0
		query.collision_mask = StadiumTimberDugoutBoundary.QUERY_MASK
		query.transform.origin = from
		var excluded: Array[RID] = []
		for other: StaticBody3D in _bodies:
			if other != body:
				excluded.append(other.get_rid())
		query.exclude = excluded
		var overlaps: Array = []
		for overlap: Dictionary in space.intersect_shape(query, 4):
			overlaps.append({"shape": overlap.get("shape"),
				"collider_path": String(overlap.collider.get_path()),
				"expected_body": overlap.collider == body})
		query.motion = to - from
		var motion: PackedFloat32Array = space.cast_motion(query)
		var pose: Transform3D = collider.global_transform
		var inverse: Transform3D = pose.affine_inverse()
		var at_graph: Vector3 = selected.get("position", from)
		var local_graph: Vector3 = inverse * at_graph
		var nearest: Vector3 = local_graph.clamp(-shape.size / 2, shape.size / 2)
		var body_data: Dictionary = {"diagnostic_index": _query_diagnostic_count,
			"path": String(body.get_path()),
			"segment": body.get_meta("club_surface"), "layer": body.collision_layer,
			"mask": body.collision_mask, "shape_disabled": collider.disabled,
			"shape_size": _vector_data(shape.size), "shape_margin": shape.margin,
			"shape_origin": _vector_data(pose.origin),
			"basis_x": _vector_data(pose.basis.x), "basis_y": _vector_data(pose.basis.y),
			"basis_z": _vector_data(pose.basis.z), "local_from": _vector_data(inverse * from),
			"local_to": _vector_data(inverse * to), "local_at_graph": _vector_data(local_graph),
			"distance_to_box_at_graph": local_graph.distance_to(nearest),
			"query_radius": query.shape.radius, "query_margin": query.margin,
			"exclude_count": excluded.size(), "initial_overlaps": overlaps, "cast_motion": Array(motion),
			"adapter_contact": StadiumTimberDugoutBoundary._contact(
				_host, body, _bodies, from, to, row[2])}
		print("TIMBER_QUERY_BODY=", JSON.stringify(body_data, "", true, true))


func _vector_data(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
