class_name FieldScoringRegressionTest
extends RefCounted


static func run(check: Callable) -> void:
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	_test_short_bobbles(check)
	var expected: Dictionary = {
		"settled_short": BallPlayOutcome.Result.SINGLE,
		"primary_before_single": BallPlayOutcome.Result.OUT,
		"roller_past_deep": BallPlayOutcome.Result.SINGLE,
		"air_past_single": BallPlayOutcome.Result.SINGLE,
		"air_past_deep": BallPlayOutcome.Result.DOUBLE,
		"caught_past_deep": BallPlayOutcome.Result.OUT,
		"touched_past_deep": BallPlayOutcome.Result.SINGLE,
		"pitcher_double_floor": BallPlayOutcome.Result.DOUBLE,
		"pitcher_bobble": BallPlayOutcome.Result.SINGLE,
		"bounce_wall": BallPlayOutcome.Result.DOUBLE,
		"fly_wall": BallPlayOutcome.Result.TRIPLE,
		"wall_top": BallPlayOutcome.Result.TRIPLE,
		"clear_wall": BallPlayOutcome.Result.HOME_RUN,
	}
	for scenario in expected:
		var resolver: BallPlayResolver = BallPlayResolver.new()
		var outcomes: Array[BallPlayOutcome] = []
		resolver.play_resolved.connect(
			func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome)
		)
		resolver.start_play(field)
		_exercise(resolver, scenario)
		check.call(
			outcomes.size() == 1 and outcomes[0].result == expected[scenario],
			"starter field scoring rule: %s" % scenario
		)


static func _exercise(resolver: BallPlayResolver, scenario: String) -> void:
	var field: FieldDefinition = resolver.field
	if scenario in ["primary_before_single", "roller_past_deep", "bounce_wall"]:
		resolver.record_ground_contact(Vector3(0.0, 0.04, 5.0))
	if scenario in ["touched_past_deep", "pitcher_bobble"]:
		resolver.record_bobble(&"pitcher", Vector3(0.0, 0.4, field.safe_hit_z_m + 0.5))
	match scenario:
		"settled_short", "pitcher_bobble":
			resolver.resolve_settled(Vector3(0.0, 0.04, 7.0))
		"primary_before_single":
			resolver.record_clean_control(&"primary_fielder", Vector3(0.0, 0.2, 8.0), false)
		"air_past_single":
			resolver.observe_segment(Vector3(0.0, 1.0, resolver.field.safe_hit_z_m - 0.1),
				Vector3(0.0, 1.0, resolver.field.safe_hit_z_m + 0.1))
			resolver.record_ground_contact(Vector3(0.0, 0.04, 12.0))
			resolver.resolve_settled(Vector3(0.0, 0.04, 12.5))
		"roller_past_deep", "air_past_deep", "touched_past_deep", "caught_past_deep":
			_cross_deep(resolver)
			if scenario == "caught_past_deep":
				resolver.record_clean_control(&"primary_fielder", Vector3(0.0, 1.0, 18.0), true)
			else:
				resolver.resolve_settled(Vector3(0.0, 0.04, 19.0))
		"pitcher_double_floor":
			_cross_deep(resolver)
			resolver.record_ground_contact(Vector3(0.0, 0.04, 18.0))
			resolver.record_pitcher_clean_control(Vector3(0.0, 0.3, 13.716), false, true)
		"bounce_wall", "fly_wall", "wall_top", "clear_wall":
			var height: float = 1.0
			if scenario == "wall_top":
				height = field.home_run_height_m
			elif scenario == "clear_wall":
				height = field.home_run_height_m + 0.01
			resolver.observe_segment(
				Vector3(0.0, height, field.back_wall_z_m - 0.1),
				Vector3(0.0, height, field.back_wall_z_m + 0.1)
			)


static func _cross_deep(resolver: BallPlayResolver) -> void:
	resolver.observe_segment(
		Vector3(0.0, 1.0, resolver.field.safe_hit_z_m - 0.1),
		Vector3(0.0, 1.0, resolver.field.deep_air_z_m + 0.1)
	)


static func _test_short_bobbles(check: Callable) -> void:
	for field_id in [PitchBatLab.FIELD_ID, SeasonState.AWAY_FIELD_ID]:
		var field: FieldDefinition = ContentDB.get_field(field_id)
		for defender in [&"pitcher", &"primary_fielder"]:
			for grounded in [false, true]:
				for offset in [-0.01, 0.0, 0.01]:
					var resolver: BallPlayResolver = BallPlayResolver.new()
					var outcomes: Array[BallPlayOutcome] = []
					resolver.play_resolved.connect(
						func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome))
					resolver.start_play(field)
					var point: Vector3 = Vector3(0, 0.4, field.safe_hit_z_m + offset)
					if grounded:
						resolver.record_ground_contact(Vector3(0, 0.04, 3))
					resolver.record_bobble(defender, point)
					if offset < 0.0:
						check.call(resolver.state.dead and outcomes.size() == 1
							and outcomes[0].result == BallPlayOutcome.Result.FOUL
							and not outcomes[0].caught, "short bobble is immediately a dead foul")
						resolver.record_clean_control(defender, point, not grounded)
						resolver.record_back_wall_contact(Vector3(0, 1, field.back_wall_z_m))
						check.call(outcomes.size() == 1, "dead bobble cannot become an Out or extra bases")
					else:
						check.call(not resolver.state.dead and outcomes.is_empty(),
							"bobble at or beyond Single remains live")
						resolver.resolve_settled(point)
						check.call(outcomes.size() == 1
							and outcomes[0].result == BallPlayOutcome.Result.SINGLE,
							"bobble grants no automatic extra base beyond Single")
