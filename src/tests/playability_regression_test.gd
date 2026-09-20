class_name PlayabilityRegressionTest
extends RefCounted

static func run(check: Callable) -> void:
	_test_live_foul_resolution(check)
	_test_moving_ground_out_rule(check)
	_test_field_layout(check)
	_test_pitcher_swept_reaction(check)
	_test_defender_territory(check)
	_test_roster_handedness_mix(check)
	_test_batted_ball_variety_bridge(check)
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
	resolver.observe_segment(
		Vector3(0.0, 0.4, field.safe_hit_z_m - 0.2),
		Vector3(0.0, 0.4, field.safe_hit_z_m + 0.2)
	)
	resolver.record_pitcher_clean_control(Vector3(0.0, 0.4, 13.25), false, true)
	check.call(
		field.safe_hit_z_m
		< PitchBatLab.MOUND_ORIGIN.z - PitcherDefense.REACTION_RADIUS_M
		and is_equal_approx(field.safe_hit_z_m, 10.5)
		and is_equal_approx(field.deep_air_z_m, 17.0)
		and field.deep_air_z_m - field.safe_hit_z_m >= 6.0
		and field.back_wall_z_m - field.deep_air_z_m >= 6.0
		and PitcherDefense.can_attempt(
			PitchBatLab.MOUND_ORIGIN + Vector3(0.0, 0.7, 0.55),
			PitchBatLab.MOUND_ORIGIN
		)
		and outcomes.size() == 1
		and outcomes[0].result == BallPlayOutcome.Result.OUT,
		"the scoring planes should leave distinct zones and preserve the mound comebacker Out"
	)

	var primary_after_safe: BallPlayResolver = BallPlayResolver.new()
	var primary_outcomes: Array[BallPlayOutcome] = []
	primary_after_safe.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: primary_outcomes.append(outcome)
	)
	primary_after_safe.start_play(field)
	primary_after_safe.record_ground_contact(Vector3(0.0, 0.0, 6.0))
	primary_after_safe.observe_segment(
		Vector3(0.0, 0.4, field.safe_hit_z_m - 0.2),
		Vector3(0.0, 0.4, field.safe_hit_z_m + 0.2)
	)
	primary_after_safe.record_clean_control(
		&"primary_fielder", Vector3(0.0, 0.4, 11.0), false, true
	)
	check.call(
		primary_outcomes.size() == 1
		and primary_outcomes[0].result == BallPlayOutcome.Result.SINGLE,
		"ordinary defense must not erase a Single after the safe plane"
	)

	var stopped: BallPlayResolver = BallPlayResolver.new()
	var stopped_outcomes: Array[BallPlayOutcome] = []
	stopped.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: stopped_outcomes.append(outcome)
	)
	stopped.start_play(field)
	stopped.record_ground_contact(Vector3(0.0, 0.0, 6.0))
	stopped.record_pitcher_clean_control(Vector3(0.0, 0.4, 13.25), false, false)
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
	var starter_field: FieldDefinition = ContentDB.get_field(&"field.starter_backyard")
	check.call(
		not starter_field.is_fielder_anchor_available(1)
		and not starter_field.is_fielder_anchor_available(4)
		and starter_field.is_fielder_anchor_available(7),
		"the starter field should reserve the shallow/middle center Pitcher sightline"
	)
	check.call(
		PitcherDefense.REACTION_RADIUS_M <= 0.65,
		"Pitcher defense should remain a deliberately small reaction envelope"
	)

static func _test_pitcher_swept_reaction(check: Callable) -> void:
	var mound: Vector3 = PitchBatLab.MOUND_ORIGIN
	var crossing: Vector3 = PitcherDefense.attempt_position(
		mound + Vector3(0.0, 0.7, -1.1),
		mound + Vector3(0.0, 0.7, 1.1),
		mound
	)
	var miss: Vector3 = PitcherDefense.attempt_position(
		mound + Vector3(0.8, 0.7, -1.1),
		mound + Vector3(0.8, 0.7, 1.1),
		mound
	)
	check.call(
		crossing != Vector3.INF and miss == Vector3.INF,
		"Pitcher defense should catch swept comebackers without expanding its radius"
	)
	var field: FieldDefinition = ContentDB.get_field(&"field.starter_backyard")
	var resolver: BallPlayResolver = BallPlayResolver.new()
	var outcomes: Array[BallPlayOutcome] = []
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome)
	)
	resolver.start_play(field)
	resolver.record_ground_contact(mound + Vector3(0.0, 0.0, -1.0))
	var fielding_outcome: FieldingResolver.Outcome = PitcherDefense.resolve(
		crossing,
		Vector3(0.0, 0.0, 12.0),
		mound,
		true,
		8
	)
	if fielding_outcome == FieldingResolver.Outcome.CLEAN:
		resolver.observe_segment(
			Vector3(0.0, 0.4, field.safe_hit_z_m - 0.2),
			Vector3(0.0, 0.4, field.safe_hit_z_m + 0.2)
		)
		resolver.record_pitcher_clean_control(crossing, false, true)
	check.call(
		fielding_outcome == FieldingResolver.Outcome.CLEAN
		and outcomes.size() == 1
		and outcomes[0].result == BallPlayOutcome.Result.OUT,
		"a fieldable moving comebacker should resolve through Pitcher defense as an Out"
	)

static func _test_defender_territory(check: Callable) -> void:
	var fielder: FielderController = FielderController.new()
	fielder.set_pitcher_lane(PitchBatLab.MOUND_ORIGIN.z)
	fielder.set_anchor(Vector3(0.0, 0.0, 14.0))
	check.call(
		fielder.territory_min_z > PitchBatLab.MOUND_ORIGIN.z,
		"a behind-mound Fielder should stay out of the Pitcher's comebacker lane"
	)
	fielder.set_anchor(Vector3(0.0, 0.0, 8.5))
	check.call(
		fielder.territory_min_z == -INF,
		"a deliberately shallow Fielder should retain the authored shallow territory"
	)
	fielder.free()

static func _test_roster_handedness_mix(check: Callable) -> void:
	var match_state: MatchState = MatchLabSupport.create_match(
		&"player.debug_pitcher", "PLAYER", "RIVAL"
	)
	var left_handed_count: int = 0
	var teams: Array[TeamMatchState] = [match_state.away_team, match_state.home_team]
	for team in teams:
		for player in team.roster:
			if player.definition.bats == PlayerDefinition.Handedness.LEFT:
				left_handed_count += 1
	check.call(
		left_handed_count == 2,
		"prototype rosters should make left-handed batters uncommon rather than even"
	)

static func _test_batted_ball_variety_bridge(check: Callable) -> void:
	var contact: ContactResult = ContactResult.new()
	contact.exit_velocity = Vector3(3.0, 2.0, 12.0)
	contact.backspin_rad_s = 42.0
	contact.spray_degrees = 18.0
	contact.horizontal_error_m = 0.14
	var pitch_state: PitchState = PitchState.new()
	pitch_state.orientation = Quaternion(Vector3.UP, 0.41)
	var launch: BattedBallLaunch = BattedBallLaunch.from_contact(contact, pitch_state)
	check.call(
		launch.orientation == pitch_state.orientation
		and not is_zero_approx(launch.angular_velocity.y)
		and not is_zero_approx(launch.angular_velocity.z),
		"contact should carry Pitch orientation and signed side/gyro spin into Jolt"
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
