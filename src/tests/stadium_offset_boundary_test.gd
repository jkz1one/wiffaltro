extends "res://src/tests/stadium_recipe_boundary_test.gd"
## Asymmetric candidate stays outside all accepted shop and saved geometry factories.


func _ready() -> void:
	_check(StadiumRecipeBoundary.create("offset_gables") == null,
		"prototype cannot be silently accepted by existing saved factories")
	var graph: StadiumRecipeBoundary = StadiumOffsetBoundary.new()
	_check(graph.identity() == "PROTOTYPE-OFFSET-GABLES-v1" and graph.segments().size() == 11,
		"candidate has its own identity and all eleven perimeter sections")
	_check(graph.contains(Vector2(0, 27.5)) and not graph.contains(Vector2(-8, 23.5)),
		"deep center and re-entrant left-center shoulder are distinct playable space")
	_check(absf(StadiumSurfaceMask.area(graph.polygon()) - 1012.742) < 0.001,
		"candidate matches independent polygon area")
	for row: Dictionary in graph.segments():
		_check(row.height == (3.25 if row.role == "BACK_WALL_TERMINAL" else 1.2),
			"candidate does not introduce an unapproved height conversion")
	_analytic_sweeps()
	_rules(graph)
	_movement(graph)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro offset boundary checks passed: isolated asymmetry, movement and scoring.")
	get_tree().quit(0 if _failures == 0 else 1)


func _rules(graph: StadiumRecipeBoundary) -> void:
	var back_z: float = 28.0
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
	var max_z: float = 28.0
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
		var from: Vector3 = Vector3(random.randf_range(-23, 23), 0, random.randf_range(-5, 27.5))
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
