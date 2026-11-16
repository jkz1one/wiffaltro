extends Node
## Concave reference geometry, continuous defender clearance and terminal baseball rules.

var _failures: int = 0
var _outcomes: Array[BallPlayOutcome] = []


func _ready() -> void:
	_check(StadiumRecipeBoundary.create("freeform") == null, "only authored shapes")
	_analytic_sweeps()
	for shape: String in StadiumWallRecipes.SHAPES:
		var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create(shape)
		_graph(graph, shape)
		_rules(graph)
		_movement(graph)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro recipe boundary checks passed: concave containment, swept clearance and rules.")
	get_tree().quit(0 if _failures == 0 else 1)


func _graph(graph: StadiumRecipeBoundary, shape: String) -> void:
	var deeper: bool = shape == "deeper_center"
	_check(graph.segments().size() == (8 if deeper else 6), "complete authored graph")
	_check(graph.contains(Vector2(-0.000357, -5.999988)),
		"near-horizontal-edge interior is not misclassified by a polygon ray degeneracy")
	_check(graph.contains(Vector2(0, 25)) == deeper, "deeper pocket is real playable interior")
	_check(not graph.contains(Vector2(22, 24)), "return notch remains outside")
	_check(graph.crossing(Vector3(0, 1, 22), Vector3(0, 1, 25)).is_empty() == deeper,
		"old infinite back plane cannot terminate deeper-center travel")
	for row: Dictionary in graph.segments():
		var middle: Vector2 = (row.a + row.b) / 2
		var normal: Vector2 = graph.inward(row)
		for height: float in [0.05, row.height, row.height + 0.001, row.height + 20]:
			var from: Vector3 = Vector3(middle.x + normal.x * 0.2, height,
				middle.y + normal.y * 0.2)
			var to: Vector3 = from - Vector3(normal.x, 0, normal.y) * 100
			var event: Dictionary = graph.crossing(from, to)
			_check(event.get("segment") == row.id, "finite high-speed face crossing")
			var role: String = row.role
			if height > row.height and row.role == "BACK_WALL_TERMINAL":
				role = "BACK_CLEAR"
			elif height > row.height and row.role == "SIDE_RETURN_LIVE":
				role = "SIDE_EXIT_DEAD"
			_check(event.get("role") == role, "per-section exact top clearance")
	for sign_x: float in [-1.0, 1.0]:
		var x: float = sign_x * StadiumWallRecipes.BACK_X
		var event: Dictionary = graph.crossing(Vector3(x, 0.6, 22), Vector3(x, 0.6, 25))
		_check(event.get("role") == "BACK_WALL_TERMINAL", "terminal owns shared return joint")
	if deeper:
		for joint: Array in [[10.0, "BACK-01"], [-10.0, "BACK-02"]]:
			var event: Dictionary = graph.crossing(Vector3(joint[0], 1, 25), Vector3(joint[0], 1, 27))
			_check(event.get("segment") == joint[1], "same-role joint has canonical event provenance")
	_check(graph.crossing(Vector3.INF, Vector3.ZERO).is_empty(), "nonfinite path rejected")
	_check(graph.signature() != StadiumBoundaryGraph.signature(), "versioned geometry identity")


func _rules(graph: StadiumRecipeBoundary) -> void:
	var back_z: float = 26 if graph.polygon().size() == 8 else 23.4
	for foul: bool in [false, true]:
		for grounded: bool in [false, true]:
			for touched: bool in [false, true]:
				for height: float in [0.6, 4.0]:
					_outcomes.clear()
					var resolver: BallPlayResolver = BallPlayResolver.new()
					resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
					resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
						_outcomes.append(outcome))
					resolver.state.has_grounded = grounded
					resolver.state.defender_touched = touched
					var event: Dictionary = graph.observe(resolver,
						Vector3(0, height, back_z - 0.2), Vector3(0, height, back_z + 10))
					var expected: int = BallPlayOutcome.Result.FOUL if foul else (
						BallPlayOutcome.Result.DOUBLE if grounded or touched else (
							BallPlayOutcome.Result.HOME_RUN if height > 3.25 else BallPlayOutcome.Result.TRIPLE))
					# Existing back-clear semantics depend on grounding, not an invented touch rule.
					if not foul and not grounded and height > 3.25:
						expected = BallPlayOutcome.Result.HOME_RUN
					_check(_outcomes.size() == 1 and _outcomes[0].result == expected,
						"terminal classification preserves foul/ground/touch history")
					_check(not graph.apply(resolver, event) and _outcomes.size() == 1,
						"terminal contact cannot resolve twice")
					_check(resolver.state.stadium_contacts[-1].id == graph.identity(),
						"event provenance binds exact graph")


func _movement(graph: StadiumRecipeBoundary) -> void:
	var max_z: float = 26 if graph.polygon().size() == 8 else 23.4
	var center: Vector3 = graph.clip(Vector3(0, 0, 10), Vector3(0, 0, 100))
	_check(absf(center.z - (max_z - graph.DEFENDER_RADIUS)) < 0.0001,
		"continuous movement reaches correct center-depth clearance")
	if max_z == 26:
		_check(graph.clip(Vector3(0, 0, 23), Vector3(0, 0, 25)) == Vector3(0, 0, 25),
			"safe defender motion enters deeper pocket")
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 408251
	var samples: int = 0
	for index in range(1200):
		var from: Vector3 = Vector3(random.randf_range(-23, 23), 0, random.randf_range(-5, 25.5))
		if not _clear(graph, from):
			continue
		var to: Vector3 = Vector3(random.randf_range(-60, 60), 0, random.randf_range(-40, 70))
		var clipped: Vector3 = graph.clip(from, to)
		_check(_clear(graph, clipped), "swept-circle endpoint stays inside with full clearance")
		_check(from.distance_to(clipped) <= from.distance_to(to) + 0.0001,
			"clipping never adds movement distance")
		for step in range(21):
			_check(_clear(graph, from.lerp(clipped, float(step) / 20)),
				"entire move avoids return-notch tunneling")
		samples += 1
	print("RECIPE_SWEEP ", graph.identity(), " moves=", samples, " path_samples=", samples * 21)
	_check(samples > 600, "substantial deterministic swept-path coverage")
	for point: Vector3 in [Vector3(40, 0, 40), Vector3(0, 0, max_z - 0.1)]:
		_check(graph.clip(point, Vector3.ZERO) == point, "invalid spawn is not silently repaired")


func _clear(graph: StadiumRecipeBoundary, point: Vector3) -> bool:
	var flat: Vector2 = Vector2(point.x, point.z)
	if not graph.contains(flat):
		return false
	for row: Dictionary in graph.segments():
		if flat.distance_to(Geometry2D.get_closest_point_to_segment(flat, row.a, row.b)) \
			< graph.DEFENDER_RADIUS - 0.0001:
			return false
	return true


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _analytic_sweeps() -> void:
	var a: Vector2 = Vector2(-1, 0)
	var b: Vector2 = Vector2(1, 0)
	_check(absf(StadiumRecipeBoundary._capsule_fraction(Vector2(0, 2), Vector2(0, -2),
		a, b) - 0.365) < 0.00001, "analytic finite-face time of impact")
	_check(absf(StadiumRecipeBoundary._capsule_fraction(Vector2(2, 0), Vector2.ZERO,
		a, b) - 0.23) < 0.00001, "analytic endpoint-circle time of impact")
	_check(StadiumRecipeBoundary._capsule_fraction(Vector2(-2, 0.54), Vector2(2, 0.54),
		a, b) == 1.0, "exact tangential grazing does not freeze safe movement")
	_check(StadiumRecipeBoundary._capsule_fraction(Vector2(2, 0.55), Vector2(-2, 0.55),
		a, b) == 1.0, "near-tangent safe movement remains unrestricted")
	_check(StadiumRecipeBoundary._circle_fraction(Vector2(0.539999, 0), Vector2.ZERO,
		Vector2.ZERO) == 0.0, "epsilon-close spawn cannot penetrate farther")
