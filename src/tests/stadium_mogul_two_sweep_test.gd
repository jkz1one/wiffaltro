extends Node3D
## Complete aperture candidate: real radius, pole priority and preserved terminal floors.

const RADIUS: float = 0.0365
const SPEEDS: Array[float] = [15.0, 60.0, 120.0]

var _samples: int = 0
var _failures: int = 0
var _outcomes: Array[BallPlayOutcome] = []


func _ready() -> void:
	var original: String = StadiumRecipeBoundary.create("straight").signature()
	for shape: String in ["left_loft"]:
		var boundary: StadiumClubBoundaryStudy = StadiumMogulTwoBoundary.new()
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
		_prisms_and_steps(boundary)
		_poles(boundary)
		_receivers(boundary)
		_check(
			boundary.items.size() == 63 and boundary.graph.segments().size() == 18,
			"exact AM-02 left-loft infrastructure and graph"
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
			and StadiumDugoutBoundary.candidate("left_loft") == null
			and StadiumRecipeBoundary.create("left_loft") == null
		),
		"candidate authoring never mutates or extends the old saved factory"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro AM-02 sweep passed: dugouts, radius precedence and fair poles.")
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
	for left: bool in [false, true]:
		var outward: Vector3 = StadiumDugoutRecipe.placement(left).basis.z
		var prefix: String = "DUGOUT-L" if left else "DUGOUT-R"
		for height: float in [0.5, 2.38]:
			for speed: float in SPEEDS:
				var start: Vector3 = StadiumDugoutRecipe.rail_point(13, -0.8, left)
				start.y = height
				await _flight(
					boundary,
					start,
					outward * speed,
					{
						"result": BallPlayOutcome.Result.SINGLE,
						"segment": prefix + ("-OPEN" if height < 1 else "-Roof"),
						"role": "DUGOUT_OPENING_DEAD" if height < 1 else "DUGOUT_ROOF_TERMINAL"
					}
				)
	for row: Dictionary in boundary.graph.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		var normal: Vector2 = boundary.graph.inward(row)
		var inward: Vector3 = Vector3(normal.x, 0, normal.y)
		var center: Vector2 = (row.a + row.b) / 2
		for clear: bool in [false, true]:
			for speed: float in SPEEDS:
				await _flight(
					boundary,
					_point(center, row.height + 0.1 if clear else 0.6) + inward * 0.8,
					-inward * speed,
					{
						"result":
						BallPlayOutcome.Result.HOME_RUN if clear else BallPlayOutcome.Result.TRIPLE,
						"segment": row.id,
						"role": "BACK_CLEAR" if clear else "BACK_WALL_TERMINAL"
					}
				)
	for offset: float in [0.01, 0.06]:
		for speed: float in SPEEDS:
			await _flight(
				boundary,
				Vector3(-4 + offset, 3.55, 26.2),
				Vector3.BACK * speed,
				{
					"result":
					(
						BallPlayOutcome.Result.TRIPLE
						if offset < RADIUS
						else BallPlayOutcome.Result.HOME_RUN
					),
					"segment": "BACK-03" if offset < RADIUS else "BACK-02",
					"role": "BACK_WALL_TERMINAL" if offset < RADIUS else "BACK_CLEAR"
				}
			)
	for direction: float in [-1.0, 1.0]:
		for speed: float in SPEEDS:
			await _flight(
				boundary,
				Vector3(-4 - direction * 0.2, 3.55, 26.99),
				Vector3.RIGHT * direction * speed,
				{
					"result": BallPlayOutcome.Result.TRIPLE,
					"segment": "BACK-03",
					"role": "BACK_WALL_TERMINAL"
				}
			)
			await _flight(
				boundary,
				Vector3(-4, 3.55, 26.99),
				Vector3.RIGHT * direction * speed,
				{
					"result": BallPlayOutcome.Result.TRIPLE,
					"segment": "BACK-03",
					"role": "BACK_WALL_TERMINAL"
				}
			)
	for row: Dictionary in StadiumFoulPoleSites.rows(boundary.graph):
		var normal: Vector2 = boundary.graph.inward(boundary.graph.segment(row.segment))
		var inward: Vector3 = Vector3(normal.x, 0, normal.y)
		for upper: bool in [false, true]:
			for touched: bool in [false, true]:
				for grounded: bool in [false, true]:
					for speed: float in SPEEDS:
						await _flight(
							boundary,
							(
								row.position
								+ inward * 0.8
								+ Vector3.UP * (row.split + 0.1 if upper else row.split - 0.1)
							),
							-inward * speed,
							{
								"result":
								(
									BallPlayOutcome.Result.DOUBLE
									if touched or grounded
									else (
										BallPlayOutcome.Result.HOME_RUN
										if upper
										else BallPlayOutcome.Result.TRIPLE
									)
								),
								"segment": row.site,
								"role": "FOUL_POLE_UPPER" if upper else "FOUL_POLE_LOWER",
								"foul": true,
								"touched": touched,
								"grounded": grounded
							}
						)
	for x: float in [0.0, 1.5]:
		for speed: float in SPEEDS:
			await _flight(
				boundary,
				Vector3(x, 1.4, 0),
				Vector3.FORWARD * speed,
				{
					"result": BallPlayOutcome.Result.FOUL,
					"role": "RECEIVER_CONTAINMENT_FOUL",
					"segment": "ST026_PANEL" if x == 0 else "ST073_CENTER_NET"
				}
			)
	# Cross on the first moving integration, from a launch far from the ball's binding position.
	for speed: float in SPEEDS:
		await _flight(
			boundary,
			Vector3(-3.99, 3.55, 26.92),
			Vector3.BACK * speed,
			{
				"result": BallPlayOutcome.Result.TRIPLE,
				"segment": "BACK-03",
				"role": "BACK_WALL_TERMINAL",
				"first_motion": true
			}
		)


func _flight(
	boundary: StadiumClubBoundaryStudy, start: Vector3, velocity: Vector3, expected: Dictionary
) -> void:
	var ball: BattedBallBody = _ball()
	ball.global_position = Vector3(0, 1, 10)
	var resolver: BallPlayResolver = _resolver(expected.get("foul", false))
	resolver.state.has_grounded = expected.get("grounded", false)
	resolver.state.defender_touched = expected.get("touched", false)
	boundary.bind_ball(ball, resolver)
	_check(
		ball.continuous_cd and ball.radius_m == RADIUS and ball.collision_mask == 1,
		"physical CCD remains enabled with the actual 0.0365 m sphere"
	)
	var routed: Callable = ball.physics_contact_router
	var trace: Dictionary = {
		"previous": start, "motions": 0, "first_event_motion": -1, "events": []
	}
	ball.physics_contact_router = func(body: BattedBallBody, batch: Array[Dictionary]) -> void:
		if not body.global_position.is_equal_approx(trace.previous):
			trace.motions += 1
		trace.previous = body.global_position
		routed.call(body, batch)
	var applied: Callable = func(event: Dictionary, active: BallPlayResolver) -> void:
		if active == resolver:
			if trace.events.is_empty():
				trace.first_event_motion = trace.motions
			trace.events.append(event.duplicate(true))
	boundary.contact_applied.connect(applied)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = start
	launch.velocity = velocity
	ball.launch(launch)
	_check(
		boundary._previous.get(ball.get_instance_id()) == start,
		"launch seeds first-frame sweep from actual launch rather than stale bound position"
	)
	# Only engine integration drives the registered production candidate router here.
	for frame in range(120):
		await get_tree().physics_frame
		if resolver.state.dead:
			break
	_check(
		(
			_outcomes.size() == 1
			and _outcomes[0].result == expected.result
			and trace.events.size() == 1
			and trace.events[0].segment == expected.segment
			and trace.events[0].role == expected.role
			and resolver.state.stadium_contacts.size() == 1
		),
		(
			"real CCD has one exact outcome/surface at "
			+ str(velocity.length())
			+ " m/s: "
			+ str(expected)
		)
	)
	if expected.get("first_motion", false):
		_check(
			trace.first_event_motion == 1,
			"high contact beats low clear in the very first moving physics integration"
		)
	_check(
		(
			resolver.state.has_grounded == expected.get("grounded", false)
			and resolver.state.defender_touched == expected.get("touched", false)
		),
		"physics routing preserves grounded and defender-touched history"
	)
	var recorded: Array = resolver.state.stadium_contacts.duplicate(true)
	for frame in range(4):
		await get_tree().physics_frame
	_check(
		(
			_outcomes.size() == 1
			and resolver.state.stadium_contacts == recorded
			and trace.events.size() == 1
		),
		"later physics callbacks cannot duplicate or rewrite terminal evidence"
	)
	boundary.contact_applied.disconnect(applied)
	_samples += 1
	ball.queue_free()
	await get_tree().physics_frame


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
		var high: Vector3 = Vector3(point.x, row.height + 0.5, point.z)
		var crossing: Dictionary = boundary.graph.crossing(high + inward, high - inward)
		_check(
			crossing.get("segment") == row.id and crossing.get("role") == "BACK_CLEAR",
			"above-cap trajectory clears shaped graph without old straight wall"
		)
	var vertices: PackedVector2Array = boundary.graph.polygon()
	var segments: Array[Dictionary] = boundary.graph.segments()
	for vertex: Vector2 in StadiumHeightBoundary.candidate("left_loft").polygon().slice(4, 8):
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


func _prisms_and_steps(boundary: StadiumClubBoundaryStudy) -> void:
	var heights: Array[float] = []
	for row: Dictionary in boundary.graph.segments():
		if row.role.begins_with("DUGOUT"):
			continue
		var body: StaticBody3D = boundary.get_node(row.id)
		var shape: CollisionShape3D = body.get_child(0)
		_check(
			shape.shape is ConvexPolygonShape3D and shape.shape.margin == 0,
			"whole composite graph uses literal uninflated convex prisms"
		)
		_check(shape.shape.points.size() == 8, "exact eight-corner segment prism")
		for point: Vector3 in shape.shape.points:
			_check(
				is_zero_approx(point.y) or is_equal_approx(point.y, row.height),
				"actual prism matches its local segment height"
			)
		var center: Vector2 = (row.a + row.b) / 2
		var normal: Vector2 = boundary.graph.inward(row)
		var inward: Vector3 = Vector3(normal.x, 0, normal.y)
		var top: Vector3 = Vector3(center.x, row.height, center.y) - inward * 0.15
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			top + Vector3.UP, top - Vector3.UP * 0.5, StadiumClubBoundaryStudy.QUERY_MASK
		)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		_check(
			not hit.is_empty() and hit.collider == body and hit.position.distance_to(top) < 0.001,
			"actual cap ray hits the exact ordered slab top"
		)
		if row.role == "BACK_WALL_TERMINAL":
			heights.append(row.height)
	_check(
		heights == [3.25, 3.25, 4.875, 4.875, 4.875],
		"independent Left Loft five-span height sequence"
	)
	for pole: Dictionary in StadiumFoulPoleSites.rows(boundary.graph):
		_check(
			pole.split == (4.875 if pole.site == "FOUL-POLE-L" else 3.25),
			"left tall and right standard pole caps are recomputed from local graph"
		)
	var low: Dictionary = boundary.graph.segment("BACK-02")
	var high: Dictionary = boundary.graph.segment("BACK-03")
	var seam: Vector2 = Vector2(-4, 27)
	_check(low.b == seam and high.a == seam, "literal standard/tall (-4,27) step")
	var tangent: Vector2 = low.a.direction_to(low.b)
	var normal: Vector2 = boundary.graph.inward(low)
	for distance: float in [0.5, 20, 150]:
		for offset: float in [0, 0.01, 0.03, 0.06]:
			var center: Vector2 = seam - tangent * offset
			var start: Vector3 = Vector3(center.x + normal.x * 0.2, 3.55, center.y + normal.y * 0.2)
			var end: Vector3 = Vector3(
				center.x - normal.x * distance, 3.55, center.y - normal.y * distance
			)
			var event: Dictionary = StadiumClubBoundarySweep.event(boundary, start, end, 0.0365)
			_check(
				(
					event.get("segment") == (high.id if offset < 0.0365 else low.id)
					and (
						event.get("role")
						== ("BACK_WALL_TERMINAL" if offset < 0.0365 else "BACK_CLEAR")
					)
					and bool(event.get("swept_contact", false)) == (offset < 0.0365)
				),
				(
					"radius-aware first tall-step contact or earlier valid standard clear: "
					+ str(event)
				)
			)
	var near: Vector3 = Vector3(seam.x + normal.x * 0.01, 3.55, seam.y + normal.y * 0.01)
	for direction: float in [-1, 1]:
		var along: Vector3 = Vector3(tangent.x, 0, tangent.y) * direction
		var event: Dictionary = StadiumClubBoundarySweep.event(boundary, near, near + along)
		_check(
			(
				event.get("segment") == high.id
				and event.get("fraction", -1) == 0
				and event.get("swept_contact", false)
			),
			"both seam directions preserve initial overlap"
		)


func _ball() -> BattedBallBody:
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	return ball

func _point(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, height, point.y)

