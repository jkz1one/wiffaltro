class_name PlayabilityRegressionTest
extends RefCounted

static func run(check: Callable) -> void:
	_test_live_foul_resolution(check)
	_test_moving_ground_out_rule(check)
	_test_field_layout(check)
	_test_fastball_speed_challenge(check)
	_test_player_repertoire_exception(check)
	_test_batting_aim_pose(check)

static func _test_live_foul_resolution(check: Callable) -> void:
	var field: FieldDefinition = FieldDefinition.new()
	var foul_catch: BallPlayResolver = BallPlayResolver.new()
	var caught_outcomes: Array[BallPlayOutcome] = []
	foul_catch.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: caught_outcomes.append(outcome)
	)
	foul_catch.start_play(field, true)
	foul_catch.record_clean_control(&"primary_fielder", Vector3(2.0, 1.2, 5.0), true)
	check.call(
		caught_outcomes.size() == 1
		and caught_outcomes[0].result == BallPlayOutcome.Result.OUT
		and caught_outcomes[0].caught,
		"an airborne foul should remain live for a defensive catch"
	)

	var foul_ground: BallPlayResolver = BallPlayResolver.new()
	var grounded_outcomes: Array[BallPlayOutcome] = []
	foul_ground.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: grounded_outcomes.append(outcome)
	)
	foul_ground.start_play(field, true)
	foul_ground.record_ground_contact(Vector3(4.0, 0.0, 4.0))
	check.call(
		grounded_outcomes.size() == 1
		and grounded_outcomes[0].result == BallPlayOutcome.Result.FOUL,
		"an uncaught foul should resolve only after grounding or leaving play"
	)

static func _test_moving_ground_out_rule(check: Callable) -> void:
	var field: FieldDefinition = ContentDB.get_field(&"field.starter_backyard")
	var resolver: BallPlayResolver = BallPlayResolver.new()
	var outcomes: Array[BallPlayOutcome] = []
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome)
	)
	resolver.start_play(field)
	resolver.record_ground_contact(Vector3(0.0, 0.0, 6.0))
	resolver.record_clean_control(&"pitcher", Vector3(0.0, 0.4, 13.7), false, true)
	check.call(
		field.safe_hit_z_m > PitchBatLab.MOUND_ORIGIN.z
		and outcomes.size() == 1
		and outcomes[0].result == BallPlayOutcome.Result.OUT,
		"a moving fair grounder controlled before the singles line should be an Out"
	)

	var stopped: BallPlayResolver = BallPlayResolver.new()
	var stopped_outcomes: Array[BallPlayOutcome] = []
	stopped.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: stopped_outcomes.append(outcome)
	)
	stopped.start_play(field)
	stopped.record_ground_contact(Vector3(0.0, 0.0, 6.0))
	stopped.record_clean_control(&"pitcher", Vector3(0.0, 0.4, 13.7), false, false)
	check.call(
		stopped_outcomes.size() == 1
		and stopped_outcomes[0].result == BallPlayOutcome.Result.SINGLE,
		"a stopped ball before the line should not become a delayed ground Out"
	)

static func _test_field_layout(check: Callable) -> void:
	var field: FieldDefinition = FieldDefinition.new()
	check.call(
		field.fielder_anchor_name(8) == "Deep Left"
		and field.fielder_anchor_name(6) == "Deep Right"
		and field.fielder_anchor(8).x > field.fielder_anchor(6).x,
		"field labels should match the player-facing left/right view"
	)
	check.call(
		PitcherDefense.REACTION_RADIUS_M <= 0.65,
		"Pitcher defense should remain a deliberately small reaction envelope"
	)

static func _test_fastball_speed_challenge(check: Callable) -> void:
	var model: BatterApproachModel = BatterApproachModel.new()
	model.reset(1)
	var fastball: PitchDefinition = ContentDB.get_pitch(&"pitch.overhand_four_seam")
	var batter: PlayerDefinition = PlayerDefinition.new()
	batter.contact = 6
	batter.power = 6
	var target: Vector2 = Vector2(0.0, 1.05)
	var slower: Dictionary = model.decide(
		fastball, target, target, batter, 0, 0, 18.0, 812
	)
	var faster: Dictionary = model.decide(
		fastball, target, target, batter, 0, 0, 30.0, 812
	)
	check.call(
		float(faster["aim_sigma"]) > float(slower["aim_sigma"]) + 0.035,
		"higher plate speed should create an intrinsic AI timing/aim challenge"
	)

static func _test_player_repertoire_exception(check: Callable) -> void:
	var match_state: MatchState = MatchLabSupport.create_match(
		&"player.debug_pitcher", "PLAYER", "RIVAL"
	)
	var player_six_pitch_count: int = 0
	var rival_six_pitch_count: int = 0
	for player in match_state.away_team.roster:
		if player.definition.starting_pitches.size() == 6:
			player_six_pitch_count += 1
	for player in match_state.home_team.roster:
		if player.definition.starting_pitches.size() == 6:
			rival_six_pitch_count += 1
	check.call(
		player_six_pitch_count == 1 and rival_six_pitch_count == 0,
		"exactly one player-team prototype should carry the six-Pitch repertoire"
	)

static func _test_batting_aim_pose(check: Callable) -> void:
	var low_offset: Vector3 = BatActor.aim_pose_position_offset(Vector2(0.0, -1.0))
	var high_offset: Vector3 = BatActor.aim_pose_position_offset(Vector2(0.0, 1.0))
	check.call(
		high_offset.y > low_offset.y
		and absf(BatActor.aim_pose_axis_tilt_degrees(Vector2(1.0, 1.0))) <= 6.1,
		"bat load should follow aim height with only a subtle bounded tilt"
	)
