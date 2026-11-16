extends Node3D
## Complete aperture candidate: real radius, pole priority and preserved terminal floors.

var _failures: int = 0
var _outcomes: Array[BallPlayOutcome] = []


func _ready() -> void:
	var original: String = StadiumRecipeBoundary.create("straight").signature()
	for shape: String in ["deeper_center"]:
		var boundary: StadiumClubBoundaryStudy = StadiumClubBoundaryStudy.new()
		add_child(boundary)
		_check(boundary.build(shape), "complete candidate builds: " + shape)
		_check(not boundary.build(shape), "repeated build is rejected before duplicating colliders")
		_check(
			boundary.graph.segments().size() == boundary.graph.polygon().size(),
			"every candidate polygon edge has one classified segment"
		)
		await get_tree().physics_frame
		await get_tree().physics_frame
		for left in [false, true]:
			_aperture(boundary, left)
			_dead_rules(boundary, left)
		_backs(boundary)
		_poles(boundary)
		_receivers(boundary)
		_check(
			boundary.items.size() == 60 and boundary.graph.segments().size() == 16,
			"exact AM-01 deeper-center infrastructure and graph"
		)
		await _flights(boundary)
		await _live_reuse(boundary)
		_check(
			not boundary.graph.contains(Vector2(50, 10)), "dead dugout space is not a field route"
		)
		boundary.queue_free()
		await get_tree().physics_frame
	_check(
		(
			StadiumRecipeBoundary.create("straight").signature() == original
			and StadiumDugoutBoundary.candidate("invented") == null
		),
		"candidate authoring never mutates or extends the old saved factory"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro AM-01 sweep passed: dugouts, radius precedence and fair poles.")
	get_tree().quit(0 if _failures == 0 else 1)


func _aperture(boundary: StadiumClubBoundaryStudy, left: bool) -> void:
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
			var from: Vector3 = StadiumDugoutRecipe.rail_point(row[0], -0.5, left)
			var to: Vector3 = StadiumDugoutRecipe.rail_point(row[0], distance, left)
			from.y = row[1]
			to.y = row[1]
			var event: Dictionary = StadiumClubBoundarySweep.event(boundary, from, to)
			_check(
				event.get("role") == row[2],
				"swept aperture/jamb/roof role: " + str(row) + " actual=" + str(event)
			)


func _dead_rules(boundary: StadiumClubBoundaryStudy, left: bool) -> void:
	for foul in [false, true]:
		for floor_value: int in [BallPlayState.ResultFloor.NONE, BallPlayState.ResultFloor.DOUBLE]:
			var resolver: BallPlayResolver = _resolver(foul)
			resolver.state.raise_result_floor(floor_value)
			var from: Vector3 = StadiumDugoutRecipe.rail_point(13, -0.5, left) + Vector3.UP * 0.5
			var to: Vector3 = StadiumDugoutRecipe.rail_point(13, 2.5, left) + Vector3.UP * 0.5
			StadiumClubBoundarySweep.observe(boundary, resolver, from, to)
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
					StadiumClubBoundarySweep.observe(boundary, resolver, to, from).is_empty()
					and _outcomes.size() == 1
				),
				"interior rebound or later exit cannot reactivate play"
			)
	var live: BallPlayResolver = _resolver(true)
	StadiumClubBoundarySweep.observe(
		boundary,
		live,
		StadiumDugoutRecipe.rail_point(11, -0.5, left) + Vector3.UP * 0.5,
		StadiumDugoutRecipe.rail_point(11, 1, left) + Vector3.UP * 0.5
	)
	_check(
		not live.state.dead and live.state.is_foul_play and _outcomes.is_empty(),
		"front barrier stays live and cannot rewrite initial fair/foul"
	)


func _poles(boundary: StadiumClubBoundaryStudy) -> void:
	for row: Dictionary in StadiumFoulPoleSites.rows(boundary.graph):
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
					var event: Dictionary = StadiumClubBoundarySweep.observe(
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


func _receivers(boundary: StadiumClubBoundaryStudy) -> void:
	var resolver: BallPlayResolver = _resolver(false)
	var event: Dictionary = StadiumClubBoundarySweep.observe(
		boundary, resolver, Vector3(1.5, 1.4, 0), Vector3(1.5, 1.4, -5.5)
	)
	_check(
		(
			event.get("segment") == "ST073_CENTER_NET"
			and _outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.FOUL
		),
		"actual target-width miss reaches corrected stadium net and becomes terminal Foul"
	)


func _flights(boundary: StadiumClubBoundaryStudy) -> void:
	for left in [false, true]:
		var outward: Vector3 = StadiumDugoutRecipe.placement(left).basis.z
		for height: float in [0.5, 2.38]:
			for speed: float in [15, 60, 120]:
				var start: Vector3 = StadiumDugoutRecipe.rail_point(13, -0.8, left)
				start.y = height
				await _flight(boundary, start, outward * speed, BallPlayOutcome.Result.SINGLE)
	for row: Dictionary in StadiumFoulPoleSites.rows(boundary.graph):
		var normal: Vector2 = boundary.graph.inward(boundary.graph.segment(row.segment))
		var inward: Vector3 = Vector3(normal.x, 0, normal.y)
		for speed: float in [15, 60, 120]:
			await _flight(
				boundary,
				row.position + inward * 0.8 + Vector3.UP * (row.split + 0.1),
				-inward * speed,
				BallPlayOutcome.Result.HOME_RUN
			)


func _flight(
	boundary: StadiumClubBoundaryStudy, start: Vector3, velocity: Vector3, expected: int
) -> void:
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	var resolver: BallPlayResolver = _resolver(false)
	boundary.bind_ball(ball, resolver)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = start
	launch.velocity = velocity
	ball.launch(launch)
	var previous: Vector3 = start
	for frame in range(90):
		await get_tree().physics_frame
		StadiumClubBoundarySweep.observe(boundary, resolver, previous, ball.global_position)
		previous = ball.global_position
		if resolver.state.dead:
			break
	_check(
		_outcomes.size() == 1 and _outcomes[0].result == expected,
		"CCD opening/roof/pole result at speed " + str(velocity.length())
	)
	var recorded: Array = resolver.state.stadium_contacts.duplicate(true)
	for frame in range(3):
		await get_tree().physics_frame
	_check(
		_outcomes.size() == 1 and resolver.state.stadium_contacts == recorded,
		"later physics contacts cannot rewrite the completed candidate play"
	)
	ball.queue_free()
	await get_tree().process_frame


func _live_reuse(boundary: StadiumClubBoundaryStudy) -> void:
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	var resolver: BallPlayResolver = _resolver(true)
	boundary.bind_ball(ball, resolver)
	for play in range(2):
		resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), true)
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = StadiumDugoutRecipe.rail_point(11, -0.3, false) + Vector3.UP * 0.5
		launch.velocity = StadiumDugoutRecipe.placement(false).basis.z * 15
		ball.launch(launch)
		for frame in range(20):
			await get_tree().physics_frame
		_check(
			(
				not resolver.state.dead
				and resolver.state.is_foul_play
				and resolver.state.stadium_contacts.size() == 1
			),
			"resting live contact records once, and a reused ball gets a fresh play record"
		)
	ball.queue_free()
	await get_tree().process_frame


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
		_failures += 1
		push_error(message)


func _backs(boundary: StadiumClubBoundaryStudy) -> void:
	for row: Dictionary in boundary.graph.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		var normal: Vector2 = boundary.graph.inward(row)
		var center: Vector2 = (row.a + row.b) / 2
		var inward: Vector3 = Vector3(normal.x, 0, normal.y)
		var point: Vector3 = Vector3(center.x, 1, center.y)
		var event: Dictionary = StadiumClubBoundarySweep.event(
			boundary, point + inward * 0.5, point - inward * 2
		)
		_check(
			event.get("segment") == row.id and event.get("role") == "BACK_WALL_TERMINAL",
			"actual composed shaped slab owns its terminal front face: " + row.id
		)
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			point + inward * 0.5, point - inward, StadiumClubBoundaryStudy.QUERY_MASK
		)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		_check(
			(
				not hit.is_empty()
				and hit.collider.get_meta("club_surface", "") == row.id
				and hit.position.distance_to(point) < 0.0001
			),
			"real collider front plane corresponds to graph: " + row.id
		)
		var high: Vector3 = point + Vector3.UP * 3
		var crossing: Dictionary = boundary.graph.crossing(high + inward, high - inward)
		_check(
			crossing.get("segment") == row.id and crossing.get("role") == "BACK_CLEAR",
			"above-cap trajectory clears shaped graph without old straight wall"
		)
	var vertices: PackedVector2Array = boundary.graph.polygon()
	var segments: Array[Dictionary] = boundary.graph.segments()
	for vertex: Vector2 in StadiumRecipeBoundary.create("deeper_center").polygon().slice(3, 7):
		var adjacent: Array[String] = []
		for index in range(vertices.size()):
			if vertices[index].is_equal_approx(vertex):
				adjacent = [segments[posmod(index - 1, segments.size())].id, segments[index].id]
		_check(adjacent.size() == 2, "each checked corner has exactly two named adjacent slabs")
		var interior: Vector2 = vertex.lerp(Vector2(0, 10), 0.1)
		var exterior: Vector2 = vertex + (vertex - interior).normalized()
		var expected: Vector3 = Vector3(vertex.x, 0.7, vertex.y)
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(interior.x, 0.7, interior.y),
			Vector3(exterior.x, 0.7, exterior.y),
			StadiumClubBoundaryStudy.QUERY_MASK
		)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		_check(
			(
				not hit.is_empty()
				and hit.collider.get_meta("club_surface", "") in adjacent
				and hit.collider.get_meta("surface_kind", "") == "boundary"
				and hit.position.distance_to(expected) <= 0.002
			),
			(
				"corner ray hits its adjacent slab within2mm of the actual local join: "
				+ str(vertex)
				+ " adjacent="
				+ str(adjacent)
				+ " hit="
				+ str(hit)
			)
		)
