extends Node

var _failures: int = 0

func _ready() -> void:
	_test_pitch_release_quality()
	_test_fatigue_curve_and_capacity()
	_test_fatigue_pitch_outcomes()
	_test_at_bat_cadence()
	_test_pitch_identity_and_batter_awareness()
	_test_ai_pitch_determinism_and_counts()
	_test_match_count_rules()
	_test_defensive_separation()
	_test_back_wall_segment_resolution()
	_test_play_record_serialization()
	if _failures == 0:
		print("Wiffaltro core regression checks passed.")
		get_tree().quit(0)
	else:
		push_error("Wiffaltro core regression failures: %d" % _failures)
		get_tree().quit(1)

func _test_pitch_release_quality() -> void:
	var perfect: float = PitchReleaseController.quality_at(0.72, 5, 0.0)
	var early: float = PitchReleaseController.quality_at(0.42, 5, 0.0)
	var tired_low_control: float = PitchReleaseController.quality_at(
		0.84,
		2,
		1.0
	)
	var fresh_high_control: float = PitchReleaseController.quality_at(
		0.84,
		9,
		0.0
	)
	_check(perfect > 0.99, "ideal release should grade perfect")
	_check(early < perfect, "early release should lose quality")
	_check(
		fresh_high_control > tired_low_control,
		"Control and freshness should widen the release window"
	)

func _test_fatigue_curve_and_capacity() -> void:
	var previous_pressure: float = 0.0
	for step in range(21):
		var fatigue: float = float(step) / 20.0
		var pressure: float = PitchExecutionModel.fatigue_pressure(fatigue)
		_check(
			pressure + 0.000001 >= previous_pressure,
			"fatigue pressure should be monotonic"
		)
		previous_pressure = pressure
	_check(
		PitchExecutionModel.fatigue_pressure(0.50) <= 0.03,
		"fatigue should remain virtually dormant through 50 percent"
	)
	_check(
		PitchExecutionModel.fatigue_pressure(0.92) >= 0.59,
		"92 percent fatigue should enter the danger band"
	)
	_check(
		PitchExecutionModel.fatigue_pressure(1.0) >= 0.99,
		"zero Stamina should apply full fatigue pressure"
	)
	var definition: PlayerDefinition = PlayerDefinition.new()
	definition.stamina = 8
	var pitcher: PlayerMatchState = PlayerMatchState.create(definition)
	pitcher.spend_stamina(75.0)
	_check(
		pitcher.fatigue_ratio() < 0.50,
		"a high-Stamina Pitcher should remain fresh after 15 standard Pitches"
	)

func _test_fatigue_pitch_outcomes() -> void:
	var pitch: PitchDefinition = ContentDB.get_pitch(&"pitch.overhand_slider")
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	var target: Vector3 = Vector3(0.42, 1.05, 0.0)
	var base: PitchLaunchParameters = PitchAimSolver.solve(
		pitch,
		ball,
		Vector3(0.0, 0.0, 13.716),
		target,
		false,
		77
	)
	_check(base != null, "fatigue regression Pitch should solve")
	if base == null:
		return
	var fresh_speed_total: float = 0.0
	var tired_speed_total: float = 0.0
	var fresh_spin_total: float = 0.0
	var tired_spin_total: float = 0.0
	var fresh_center_distance: float = 0.0
	var tired_center_distance: float = 0.0
	var tired_crossings: int = 0
	var sample_count: int = 32
	for sample in range(sample_count):
		var seed: int = 1000 + sample
		var fresh: PitchLaunchParameters = PitchExecutionModel.apply(
			base, 1.0, 0.50, 1.0, 1.05, pitch.category, seed
		)
		var tired: PitchLaunchParameters = PitchExecutionModel.apply(
			base, 1.0, 1.0, 1.0, 1.05, pitch.category, seed
		)
		var fresh_crossing: PitchCrossingResult = (
			PitchTrajectorySimulator.simulate_to_plane(fresh, 0.0)
		)
		var tired_crossing: PitchCrossingResult = (
			PitchTrajectorySimulator.simulate_to_plane(tired, 0.0)
		)
		fresh_speed_total += fresh.velocity.length()
		tired_speed_total += tired.velocity.length()
		fresh_spin_total += fresh.angular_velocity.length()
		tired_spin_total += tired.angular_velocity.length()
		if fresh_crossing.crossed:
			fresh_center_distance += absf(fresh_crossing.point.x)
		if tired_crossing.crossed:
			tired_crossings += 1
			tired_center_distance += absf(tired_crossing.point.x)
			_check(
				tired_crossing.point.y >= PitchExecutionModel.MIN_PLATE_REACH_Y_M - 0.02,
				"an exhausted Pitch should still reach the plate plane"
			)
	_check(
		tired_crossings == sample_count,
		"all sampled exhausted Pitches should cross the plate plane"
	)
	_check(
		tired_speed_total < fresh_speed_total * 0.90,
		"an exhausted Slider should lose meaningful velocity"
	)
	_check(
		tired_spin_total < fresh_spin_total * 0.45,
		"an exhausted Slider should lose most of its finish"
	)
	_check(
		tired_center_distance < fresh_center_distance * 0.75,
		"an exhausted edge-targeted Slider should leak toward center"
	)

func _test_at_bat_cadence() -> void:
	var cadence: AtBatCadenceController = AtBatCadenceController.new()
	cadence.begin_delivery(42)
	_check(
		cadence.advance(cadence.active_delivery_seconds - 0.01)
		== AtBatCadenceController.Event.NONE,
		"AI delivery should visibly telegraph before release"
	)
	_check(
		cadence.advance(0.02) == AtBatCadenceController.Event.THROW_PITCH,
		"AI delivery should release after its windup"
	)
	cadence.hold_dead_ball(84)
	_check(
		cadence.advance(cadence.active_hold_seconds + 0.01)
		== AtBatCadenceController.Event.CONTINUE_PLAY,
		"an unfinished at-bat should continue without another acceptance"
	)
	var replay: AtBatCadenceController = AtBatCadenceController.new()
	replay.begin_delivery(42)
	_check(
		is_equal_approx(
			cadence.active_delivery_seconds,
			replay.active_delivery_seconds
		),
		"Pitch rhythm variation should replay from its seed"
	)

func _test_pitch_identity_and_batter_awareness() -> void:
	var fastball: PitchDefinition = ContentDB.get_pitch(
		&"pitch.overhand_four_seam"
	)
	var eephus: PitchDefinition = ContentDB.get_pitch(&"pitch.eephus")
	_check(
		fastball.nominal_velocity_mps >= eephus.nominal_velocity_mps * 2.4,
		"Four-Seam and Eephus must occupy clearly different speed bands"
	)
	_check(
		eephus.category == PitchDefinition.Category.OFF_SPEED,
		"Eephus should be authored as an off-speed Pitch"
	)
	var model: BatterApproachModel = BatterApproachModel.new()
	model.reset(1)
	var target: Vector2 = Vector2(0.31, 1.08)
	var initial_awareness: float = model.awareness_for(fastball, target)
	model.observe(fastball, target)
	model.observe(fastball, target)
	_check(
		model.awareness_for(fastball, target) > initial_awareness + 0.25,
		"repeating a Pitch and location should raise batter awareness"
	)
	var batter: PlayerDefinition = PlayerDefinition.new()
	batter.contact = 6
	batter.power = 6
	var center: Dictionary = model.decide(
		fastball, Vector2(0.0, 1.05), target, batter, 0, 0, 24.0, 51
	)
	var chase: Dictionary = model.decide(
		fastball, Vector2(0.88, 1.05), target, batter, 0, 0, 24.0, 51
	)
	var outside: Dictionary = model.decide(
		fastball, Vector2(-0.18, 1.05), target, batter, 0, 0, 24.0, 51
	)
	var inside: Dictionary = model.decide(
		fastball, Vector2(0.36, 1.05), target, batter, 0, 0, 24.0, 51
	)
	_check(
		float(center["swing_chance"]) > float(chase["swing_chance"]) * 3.0,
		"far chase Pitches should be much harder to offer at than center mistakes"
	)
	_check(
		float(outside["aim_sigma"]) < float(inside["aim_sigma"]),
		"the reachable outer half should be easier than the inner edge"
	)

func _test_ai_pitch_determinism_and_counts() -> void:
	var first: Dictionary = MatchLabSupport.ai_pitch_choice(4, 12, 3, 2, 1, 0)
	var replay: Dictionary = MatchLabSupport.ai_pitch_choice(4, 12, 3, 2, 1, 0)
	_check(first == replay, "AI choice should replay from the same state")
	var three_ball_strikes: int = 0
	var two_strike_strikes: int = 0
	for index in range(200):
		var protect: Dictionary = MatchLabSupport.ai_pitch_choice(
			4, index, 2, 3, 1, -1
		)
		var chase: Dictionary = MatchLabSupport.ai_pitch_choice(
			4, index, 2, 0, 2, -1
		)
		if _target_in_zone(protect["target"]):
			three_ball_strikes += 1
		if _target_in_zone(chase["target"]):
			two_strike_strikes += 1
	_check(
		three_ball_strikes > two_strike_strikes,
		"AI should attack the zone more often in three-ball counts"
	)

func _test_match_count_rules() -> void:
	var match_state: MatchState = MatchState.create(
		_make_team("Away"),
		_make_team("Home")
	)
	match_state.strikes = 2
	match_state.record_foul()
	_check(match_state.strikes == 2, "two-strike foul should preserve the count")
	match_state.continue_after_dead_ball()
	match_state.balls = 3
	match_state.record_ball()
	_check(
		match_state.away_team.batting_index == 1,
		"walk should complete the plate appearance"
	)
	_check(match_state.bases.first != &"", "walk should place the batter on first")

func _test_defensive_separation() -> void:
	var field: FieldDefinition = FieldDefinition.new()
	var mound: Vector3 = Vector3(0.0, 0.0, 13.716)
	_check(
		field.fielder_anchor(4).distance_to(mound) >= 2.5,
		"Middle Center must not overlap the Pitcher at the mound"
	)
	var team: TeamMatchState = _make_team("Defense")
	team.fielder_index = 2
	_check(team.select_pitcher(2), "valid Pitcher selection should succeed")
	_check(
		team.pitcher_index != team.fielder_index,
		"Pitcher and Primary Fielder must remain different players"
	)
	_check(
		PitcherDefense.REACTION_RADIUS_M <= 1.0,
		"Pitcher defense must remain a small comebacker radius"
	)

func _test_back_wall_segment_resolution() -> void:
	var resolver: BallPlayResolver = BallPlayResolver.new()
	var field: FieldDefinition = FieldDefinition.new()
	resolver.start_play(field)
	resolver.observe_segment(
		Vector3(0.0, 2.0, field.back_wall_z_m - 0.3),
		Vector3(0.0, 2.0, field.back_wall_z_m + 0.3)
	)
	_check(
		resolver.state.dead,
		"back-wall rulings should survive a missed thin collision callback"
	)

func _test_play_record_serialization() -> void:
	var record: PlayRecord = PlayRecord.new()
	record.play_number = 7
	record.pitch_id = &"pitch.test"
	record.intended_target = Vector2(0.2, 1.1)
	record.result = &"single"
	var encoded: Dictionary = record.to_dict()
	_check(encoded["play_number"] == 7, "record should retain play number")
	_check(
		is_equal_approx(float(encoded["intended_target"][0]), 0.2)
		and is_equal_approx(float(encoded["intended_target"][1]), 1.1),
		"record vectors should be JSON-safe arrays"
	)

func _make_team(team_name: String) -> TeamMatchState:
	var definitions: Array[PlayerDefinition] = []
	for index in range(TeamMatchState.ROSTER_SIZE):
		var definition: PlayerDefinition = PlayerDefinition.new()
		definition.id = StringName("player.test_%s_%d" % [team_name, index])
		definition.display_name = "%s %d" % [team_name, index]
		definitions.append(definition)
	return TeamMatchState.create(team_name, definitions)

func _target_in_zone(target: Vector2) -> bool:
	return (
		target.x >= -0.43
		and target.x <= 0.43
		and target.y >= 0.55
		and target.y <= 1.55
	)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
