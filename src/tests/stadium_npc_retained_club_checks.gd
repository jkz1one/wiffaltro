extends Node3D
## Installed AC-only mechanics, real contact provenance and dense both-handed camera paths.

var failures: int = 0
var candidate_v2: bool = false
var _runtime: Script = StadiumNpcRetainedRuntime
var _prefix: String = "npc:AC-01:r1:"
var _outcomes: Array[BallPlayOutcome] = []
var _sample_fps: int = 60


func run(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	if candidate_v2:
		_runtime = StadiumNpcCandidateRuntimeV2
		_prefix = "npc:AC-01:r2:"
	_integrity(lab, property)
	for left in [false, true]:
		_aperture(property.boundary, left)
		_dead_rules(property.boundary, left)
	_poles(property.boundary)
	_receiver(lab, property)
	await _physical_provenance(property)
	get_window().size = Vector2i(1280, 720)
	for fps: int in [30, 60, 120]:
		_sample_fps = fps
		await _camera(lab, property)


func _aperture(boundary: StadiumNpcRetainedClubBoundary, left: bool) -> void:
	var cases: Array = [
		[13.0, 0.5, "DUGOUT_OPENING_DEAD"],
		[12.02, 0.5, "DUGOUT_FACE_LIVE"],
		[13.98, 0.5, "DUGOUT_FACE_LIVE"],
		[12.05, 0.5, "DUGOUT_OPENING_DEAD"],
		[11.0, 0.5, "DUGOUT_FACE_LIVE"],
		[13.0, 2.38, "DUGOUT_ROOF_TERMINAL"],
		[13.0, 2.35, "DUGOUT_OPENING_DEAD"],
		[13.0, 2.75, "DUGOUT_EXTERIOR_DEAD"],
		[9.0, 0.5, "SIDE_RETURN_LIVE"],
		[17.0, 0.5, "SIDE_RETURN_LIVE"]
	]
	for row: Array in cases:
		for distance: float in [0.5, 5, 100]:
			var from: Vector3 = StadiumNpcClubDugoutRecipeV1.rail_point(row[0], -0.5, left)
			var to: Vector3 = StadiumNpcClubDugoutRecipeV1.rail_point(row[0], distance, left)
			from.y = row[1]
			to.y = row[1]
			var event: Dictionary = StadiumNpcRetainedClubSweep.event(boundary, from, to)
			_check(
				event.get("role") == row[2],
				"swept aperture/jamb/roof role: " + str(row) + " actual=" + str(event)
			)


func _dead_rules(boundary: StadiumNpcRetainedClubBoundary, left: bool) -> void:
	for foul in [false, true]:
		for floor_value: int in [BallPlayState.ResultFloor.NONE, BallPlayState.ResultFloor.DOUBLE]:
			var resolver: BallPlayResolver = _resolver(foul)
			resolver.state.raise_result_floor(floor_value)
			var from: Vector3 = (
				StadiumNpcClubDugoutRecipeV1.rail_point(13, -0.5, left) + Vector3.UP * 0.5
			)
			var to: Vector3 = (
				StadiumNpcClubDugoutRecipeV1.rail_point(13, 2.5, left) + Vector3.UP * 0.5
			)
			StadiumNpcRetainedClubSweep.observe(boundary, resolver, from, to)
			var expected: int = (
				BallPlayOutcome.Result.FOUL
				if foul
				else (
					BallPlayOutcome.Result.DOUBLE
					if floor_value == BallPlayState.ResultFloor.DOUBLE
					else BallPlayOutcome.Result.SINGLE
				)
			)
			_check(
				_outcomes.size() == 1 and _outcomes[0].result == expected,
				"entry ends play once with earned floor/minimum Single or Foul"
			)
			_check(
				(
					StadiumNpcRetainedClubSweep.observe(boundary, resolver, to, from).is_empty()
					and _outcomes.size() == 1
				),
				"interior rebound or later exit cannot reactivate play"
			)
	var live: BallPlayResolver = _resolver(true)
	StadiumNpcRetainedClubSweep.observe(
		boundary,
		live,
		StadiumNpcClubDugoutRecipeV1.rail_point(11, -0.5, left) + Vector3.UP * 0.5,
		StadiumNpcClubDugoutRecipeV1.rail_point(11, 1, left) + Vector3.UP * 0.5
	)
	_check(
		not live.state.dead and live.state.is_foul_play and _outcomes.is_empty(),
		"front barrier stays live and cannot rewrite initial fair/foul"
	)


func _poles(boundary: StadiumNpcRetainedClubBoundary) -> void:
	for row: Dictionary in StadiumNpcClubFoulSitesV1.rows(boundary.graph):
		var wall: Dictionary = boundary.graph.segment(row.segment)
		var normal: Vector2 = boundary.graph.inward(wall)
		for y: float in [0.8, row.split, row.split + 0.01, row.split + 0.10]:
			for touched in [false, true]:
				for grounded in [false, true]:
					var resolver: BallPlayResolver = _resolver(true)
					resolver.state.defender_touched = touched
					resolver.state.has_grounded = grounded
					var from: Vector3 = row.position + Vector3(normal.x * 0.5, y, normal.y * 0.5)
					var to: Vector3 = row.position + Vector3(-normal.x * 3, y, -normal.y * 3)
					var event: Dictionary = StadiumNpcRetainedClubSweep.observe(
						boundary, resolver, from, to
					)
					var upper: bool = y > row.split
					var expected: int = (
						BallPlayOutcome.Result.DOUBLE
						if touched or grounded
						else (
							BallPlayOutcome.Result.HOME_RUN
							if upper
							else BallPlayOutcome.Result.TRIPLE
						)
					)
					_check(
						(
							event.get("kind") == "pole"
							and _outcomes.size() == 1
							and _outcomes[0].result == expected
							and not resolver.state.is_foul_play
							and resolver.state.has_grounded == grounded
							and resolver.state.defender_touched == touched
						),
						(
							"physical pole precedes wall/clear and applies its explicit fair result: "
							+ str(event)
							+ " grounded="
							+ str(grounded)
							+ " touched="
							+ str(touched)
						)
					)


func _resolver(foul: bool) -> BallPlayResolver:
	_outcomes.clear()
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	)
	return resolver


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _endpoints(_depth: float) -> Array[Vector3]:
	var result: Array[Vector3] = [
		Vector3(0, 0.15, 27.9),
		Vector3(-8, 0.15, 22.4),
		Vector3(13, 0.15, 22.9),
		Vector3(7, 0.15, 11.75),
		Vector3(-25, 1.8, 18),
		Vector3(25, 1.8, 18),
		Vector3(0, 7, 30),
		Vector3(0, 35, 25),
		Vector3(-1.5, 1, -4.45),
		Vector3(1.5, 1, -4.45)
	]
	for left in [false, true]:
		for distance: float in [11, 13, 15]:
			result.append(
				StadiumNpcClubDugoutRecipeV1.rail_point(distance, -0.15, left) + Vector3.UP * 0.7
			)
	return result


func _camera(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	# Static-body transforms must reach physics before testing the swept camera's real queries.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var director: MatchCameraDirector = lab._camera_director
	var camera: Camera3D = lab._camera
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = camera.near * 2
	query.collision_mask = 64
	var samples: int = 0
	var outside: int = 0
	var blocked: int = 0
	var overlaps: int = 0
	var max_step: float = 0
	var max_turn: float = 0
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		for defense in [false, true]:
			for requested: Vector3 in _endpoints(0):
				var start: Vector3 = Vector3(requested.x if requested.z < 0 else 0, 1, 0)
				var contact: Dictionary = StadiumNpcRetainedClubSweep.event(
					property.boundary, start, requested
				)
				var endpoint: Vector3 = contact.get("position", requested)
				# Do not continue a camera probe through a dead wall into solid stands outside play.
				var prior: Vector3i = Vector3i(outside, blocked, overlaps)
				director.set_shot(
					(
						MatchCameraDirector.Shot.PITCHING
						if defense
						else MatchCameraDirector.Shot.BATTING
					)
				)
				director.snap(camera)
				director.prepare_ball_in_play(defense, start, endpoint - start)
				director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
				for frame in range(_sample_fps * 4):
					ball.position = start.lerp(endpoint, minf(1, frame / (_sample_fps * 2.5)))
					var before: Transform3D = camera.global_transform
					director.update(camera, 1.0 / _sample_fps, true, ball.position)
					StadiumPropertyRuntime.refresh_receiver_visibility(lab)
					max_step = maxf(max_step, before.origin.distance_to(camera.global_position))
					max_turn = maxf(
						max_turn,
						before.basis.get_rotation_quaternion().angle_to(
							camera.global_basis.get_rotation_quaternion()
						)
					)
					outside += int(
						(
							camera.is_position_behind(ball.position)
							or not (Rect2(24, 24, 1232, 672).has_point(
								camera.unproject_position(ball.position)
							))
						)
					)
					blocked += int(
						director.tracking_visibility.call(
							"actual_blocked", camera.global_position, ball.position
						)
					)
					query.transform.origin = camera.global_position
					overlaps += int(
						not (
							camera
							. get_world_3d()
							. direct_space_state
							. intersect_shape(query, 1)
							. is_empty()
						)
					)
					samples += 1
				if Vector3i(outside, blocked, overlaps) != prior:
					print(
						"CLUB_TRACKING_FAILURE left=",
						left,
						" defense=",
						defense,
						" endpoint=",
						endpoint,
						" counts=",
						Vector3i(outside, blocked, overlaps) - prior
					)
	print(
		"CLUB_TRACKING fps=",
		_sample_fps,
		" samples=",
		samples,
		" outside=",
		outside,
		" blocked=",
		blocked,
		" overlaps=",
		overlaps,
		" max_step=",
		max_step,
		" max_turn=",
		max_turn
	)
	_check(
		outside == 0 and blocked == 0 and overlaps == 0,
		"real complete-field camera volume stays clear and the ball remains framed"
	)
	_check(
		max_step < 32.1 / _sample_fps and max_turn < 1.7 / _sample_fps,
		"complete-field camera retains bounded movement and turning"
	)
	lab._cleanup_batted_ball()
	await get_tree().process_frame


func _receiver(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	var receiver: StadiumClubPitchReceiver = property.receiver
	for speed: float in [15, 40, 120]:
		for row: Array in [
			[Vector3(0, 1.3, 0), "ST026_PANEL"],
			[Vector3(1.5, 1.3, 0), "ST073_CENTER_NET"],
			[Vector3(3, 1.3, 0), "ST073_NET_R"],
			[Vector3(-3, 1.3, 0), "ST073_NET_L"]
		]:
			var path: Dictionary = receiver.trace(row[0], Vector3(0, 0, -speed), 0.0365)
			_check(
				path.hit.get("surface") == row[1] and path.times[-1] <= 0.38,
				"retained AC receiver reaches actual named surface at speed " + str(speed)
			)
			_check(
				String(path.hit.get("copy", "")).begins_with(_prefix),
				"all AC swept receiver contacts preserve real NPC identity"
			)
			if row[1] == "ST073_CENTER_NET":
				_check(
					path.hide_at > 0 and path.hide_at < path.times[-1],
					"AC camera cutoff precedes genuine physical containment"
				)
	var miss: Dictionary = receiver.trace(Vector3(0, 8, 0), Vector3(0, 0, -40), 0.0365)
	_check(
		(
			miss.hit.is_empty()
			and miss.reason == "receiver_cleanup"
			and is_equal_approx(miss.points[-1].z, -5.2)
		),
		"AC above-net miss keeps real cleanup"
	)
	var old_match: MatchState = lab._match_state
	property.process_mode = Node.PROCESS_MODE_DISABLED
	property.display.process_mode = Node.PROCESS_MODE_DISABLED
	lab._start_new_match()
	_check(
		old_match != lab._match_state and property.display._match == lab._match_state,
		"AC display synchronously rebinds even while property/display processing is disabled"
	)
	property.process_mode = Node.PROCESS_MODE_INHERIT
	property.display.process_mode = Node.PROCESS_MODE_INHERIT
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var panel: Node3D = receiver.chair.get_node("Visual/ST026_PANEL")
	var original: Transform3D = panel.transform
	receiver._flex(0.09)
	_check(
		panel.transform != original and _runtime.installed(lab, "AC-01"),
		"retained AC target flex is actual geometry and stays inside its exact presentation contract"
	)
	receiver._flex(0.18)
	for id: String in StadiumNpcClubNetV1.PANELS:
		var mesh: MeshInstance3D = receiver.net.get_node("Visual/" + id)
		var rest: PackedVector3Array = mesh.get_meta("rest_vertices")
		receiver._flex_surface = id
		receiver._flex_net(0.275, id, Vector3(0, 1.3, -4.5))
		_check(
			(
				mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] != rest
				and _runtime.installed(lab, "AC-01")
			),
			"every retained AC net panel permits its actual impact-weighted pocket"
		)
		var active_mesh: Mesh = mesh.mesh
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		vertices[0].x += 0.001
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var changed_mesh: ArrayMesh = ArrayMesh.new()
		changed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.mesh = changed_mesh
		_check(
			not _runtime.installed(lab, "AC-01"),
			"active net flex never excuses an independently changed vertex"
		)
		mesh.mesh = active_mesh
		_check(
			_runtime.installed(lab, "AC-01"),
			"exact active net mesh restores its positive integrity control"
		)
		var changed_rest: PackedVector3Array = rest.duplicate()
		changed_rest[0].z += 0.001
		mesh.set_meta("rest_vertices", changed_rest)
		_check(
			not _runtime.installed(lab, "AC-01"),
			"forged net rest metadata cannot legitimize geometry while flex is active"
		)
		mesh.set_meta("rest_vertices", rest)
		_check(
			_runtime.installed(lab, "AC-01"),
			"restoring retained rest metadata returns valid active flex"
		)
		receiver._flex_net(0.55, id, Vector3(0, 1.3, -4.5))


func _physical_provenance(property: StadiumNpcRetainedProperty) -> void:
	for left in [false, true]:
		var outward: Vector3 = StadiumNpcClubDugoutRecipeV1.placement(left).basis.z
		for height: float in [0.5, 2.38]:
			var point: Vector3 = StadiumNpcClubDugoutRecipeV1.rail_point(13, -0.8, left)
			point.y = height
			await _physical(property, point, outward * 60, BallPlayOutcome.Result.SINGLE)
	for row: Dictionary in StadiumNpcClubFoulSitesV1.rows(property.boundary.graph):
		var normal: Vector2 = property.boundary.graph.inward(
			property.boundary.graph.segment(row.segment)
		)
		var inward: Vector3 = Vector3(normal.x, 0, normal.y)
		await _physical(
			property,
			row.position + inward * 0.8 + Vector3.UP * (row.split + 0.1),
			-inward * 60,
			BallPlayOutcome.Result.HOME_RUN
		)
	await _physical(property, Vector3(0, 1.3, 0), Vector3(0, 0, -40), BallPlayOutcome.Result.FOUL)
	await _physical(property, Vector3(1.5, 1.3, 0), Vector3(0, 0, -40), BallPlayOutcome.Result.FOUL)


func _physical(
	property: StadiumNpcRetainedProperty, start: Vector3, velocity: Vector3, expected: int
) -> void:
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	var resolver: BallPlayResolver = _resolver(false)
	property.bind_ball(ball, resolver)
	property.provenance.clear()
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = start
	launch.velocity = velocity
	ball.launch(launch)
	var previous: Vector3 = start
	for frame in range(90):
		await get_tree().physics_frame
		property.observe(resolver, previous, ball.global_position)
		previous = ball.global_position
		if resolver.state.dead:
			break
	_check(
		_outcomes.size() == 1 and _outcomes[0].result == expected,
		"installed retained AC ball reaches one actual pole/dugout/receiver result"
	)
	# An opening may end at the graph plane without physical item contact. Actual solid
	# pole, roof and receiver probes must preserve preterminal NPC provenance.
	if not (start.y == 0.5 and start.z > 0):
		var found: bool = false
		for row: Dictionary in property.provenance:
			_check(
				String(row.instance).begins_with(_prefix),
				"preterminal contact belongs to an actual retained AC instance"
			)
			found = found or row.preterminal
		_check(found, "real solid contact captures NPC provenance before terminal resolution")
	var recorded: Array = resolver.state.stadium_contacts.duplicate(true)
	for frame in range(3):
		await get_tree().physics_frame
	_check(
		_outcomes.size() == 1 and resolver.state.stadium_contacts == recorded,
		"later AC contacts cannot overwrite terminal outcome or contact records"
	)
	ball.queue_free()
	await get_tree().process_frame


func _integrity(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	var boundary: StadiumNpcRetainedClubBoundary = property.boundary
	var source: StadiumNpcClubBoundaryV1 = boundary.source
	var foreign: StadiumNpcClubV1 = StadiumNpcClubV1.build()
	boundary.source = foreign.get_node("ClubBoundary")
	_check(
		not _runtime.installed(lab, "AC-01"),
		"fresh authentic but foreign construction cannot replace installed boundary source"
	)
	boundary.source = source
	foreign.free()
	_check(_runtime.installed(lab, "AC-01"), "exact wrapper source restores")
	var bodies: Array[StaticBody3D] = source.bodies.duplicate()
	source.bodies.pop_back()
	_check(
		not _runtime.installed(lab, "AC-01"),
		"lost retained collision membership rejects even when wrapper aliases the same array"
	)
	source.bodies.assign(bodies)
	_check(_runtime.installed(lab, "AC-01"), "full retained body list restores")
	source.bodies.reverse()
	_check(
		not _runtime.installed(lab, "AC-01"),
		"reordered actual body membership cannot substitute for retained construction order"
	)
	source.bodies.assign(bodies)
	_check(_runtime.installed(lab, "AC-01"), "retained body order restores")
	boundary.contact_applied.disconnect(property._club_contact)
	_check(
		not _runtime.installed(lab, "AC-01"),
		"lost real preterminal provenance/receiver contact callback rejects installation"
	)
	boundary.contact_applied.connect(property._club_contact)
	_check(_runtime.installed(lab, "AC-01"), "real contact callback restores")
	var protection: Callable = property.receiver.camera_protection
	property.receiver.camera_protection = func() -> bool: return true
	_check(
		not _runtime.installed(lab, "AC-01"),
		"plausible foreign camera protection callback cannot replace live role policy"
	)
	property.receiver.camera_protection = protection
	_check(_runtime.installed(lab, "AC-01"), "exact role callback restores")
	var cache: Dictionary = property.receiver._rest_meshes
	var cached_mesh: Mesh = cache["ST073_NET_R"]
	var altered: Array = cached_mesh.surface_get_arrays(0)
	var changed: PackedVector3Array = altered[Mesh.ARRAY_VERTEX].duplicate()
	changed[0].x += 0.001
	altered[Mesh.ARRAY_VERTEX] = changed
	var corrupt: ArrayMesh = ArrayMesh.new()
	corrupt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, altered)
	cache["ST073_NET_R"] = corrupt
	_check(
		not _runtime.installed(lab, "AC-01"),
		"corrupted inactive rest-mesh cache cannot become future retained net geometry"
	)
	cache["ST073_NET_R"] = cached_mesh
	_check(_runtime.installed(lab, "AC-01"), "exact inactive mesh cache restores")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	property.bind_ball(ball, lab._ball_play_resolver)
	_check(
		_runtime.installed(lab, "AC-01"),
		"actual bound ball starts with authentic retained callbacks"
	)
	var launch: Callable = boundary._seed.bind(ball.get_instance_id())
	ball.launch_started.disconnect(launch)
	_check(
		not _runtime.installed(lab, "AC-01"),
		"missing launch-seed callback cannot leave a stale previous-segment origin"
	)
	boundary.bind_ball(ball, lab._ball_play_resolver)
	_check(_runtime.installed(lab, "AC-01"), "rebind repairs lost launch callback")
	var exit_callback: Callable = boundary._forget.bind(
		ball.get_instance_id(), lab._ball_play_resolver.get_instance_id()
	)
	ball.tree_exited.disconnect(exit_callback)
	_check(
		not _runtime.installed(lab, "AC-01"),
		"missing ball-exit cleanup cannot retain stale live callback state"
	)
	boundary.bind_ball(ball, lab._ball_play_resolver)
	_check(_runtime.installed(lab, "AC-01"), "rebind repairs lost exit callback")
	boundary._resolver_ids.erase(ball.get_instance_id())
	_check(not _runtime.installed(lab, "AC-01"), "missing actual ball-to-resolver mapping rejects")
	boundary.bind_ball(ball, lab._ball_play_resolver)
	_check(_runtime.installed(lab, "AC-01"), "rebind repairs resolver map")
	boundary._bound_balls.erase(ball.get_instance_id())
	_check(
		not _runtime.installed(lab, "AC-01"),
		"missing actual ball weak-reference membership rejects"
	)
	boundary.bind_ball(ball, lab._ball_play_resolver)
	_check(_runtime.installed(lab, "AC-01"), "rebind repairs actual ball map")
	var ball_id: int = ball.get_instance_id()
	var previous: Vector3 = boundary._previous[ball_id]
	boundary._previous.erase(ball_id)
	_check(
		not _runtime.installed(lab, "AC-01"),
		"missing previous position cannot silently collapse the swept segment"
	)
	boundary._previous[ball_id] = previous
	_check(_runtime.installed(lab, "AC-01"), "exact previous position restores")
	for invalid: Variant in [Vector3(INF, 0, 0), Vector3(0, NAN, 0), Vector2.ZERO]:
		boundary._previous[ball_id] = invalid
		_check(
			not _runtime.installed(lab, "AC-01"),
			"previous position requires an existing finite Vector3: " + str(invalid)
		)
		boundary._previous[ball_id] = previous
		_check(
			_runtime.installed(lab, "AC-01"),
			"finite exact previous position restores after rejected value"
		)
	ball.free()
	_check(
		_runtime.installed(lab, "AC-01"),
		"freed callback probe leaves no stale live-ball integrity requirement"
	)
