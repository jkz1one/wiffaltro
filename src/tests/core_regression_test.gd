extends Node

var _failures: int = 0
var _contact_cancel_actor: PitchFlightActor

func _ready() -> void:
	_test_pitch_release_quality()
	_test_swept_swing_timeline()
	_test_signed_contact_spin()
	_test_pitch_actor_contact_cancellation()
	_test_fatigue_curve_and_capacity()
	_test_fatigue_pitch_outcomes()
	_test_fresh_pitch_reachability()
	_test_low_effort_eephus_reachability()
	_test_at_bat_cadence()
	_test_match_presentation_sequence()
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
	var perfect: float = PitchReleaseController.quality_at(
		PitchReleaseController.IDEAL_RELEASE_SECONDS,
		5,
		0.0
	)
	var early: float = PitchReleaseController.quality_at(0.28, 5, 0.0)
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
	_check(
		PitchReleaseController.AUTO_RELEASE_SECONDS < 1.0,
		"the player delivery meter should complete in under one second"
	)

func _test_swept_swing_timeline() -> void:
	var profile: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = profile.id
	intent.aim_point = Vector2(0.0, 1.05)
	intent.start_time_seconds = 0.0
	var tracker: SwingContactTracker = SwingContactTracker.new()
	tracker.begin(intent, profile, 5, 5)
	var state: PitchState = PitchState.new()
	state.position = Vector3(0.0, 1.05, 2.38)
	state.velocity = Vector3(0.0, 0.0, -20.0)
	var result: ContactResult
	for _step in range(80):
		var previous_position: Vector3 = state.position
		var previous_time: float = state.elapsed_time
		state.position += state.velocity * PitchFlightSolver.SUBSTEP_SECONDS
		state.elapsed_time += PitchFlightSolver.SUBSTEP_SECONDS
		result = tracker.sample_segment(previous_position, previous_time, state)
		if result != null:
			break
	_check(result != null, "a centered timed swing should produce an encounter")
	_check(
		result != null and result.outcome != ContactResult.Outcome.MISS,
		"a centered timed swing should make contact"
	)

	var outside_intent: SwingIntent = SwingIntent.new()
	outside_intent.profile_id = profile.id
	outside_intent.aim_point = Vector2(0.75, 1.05)
	outside_intent.start_time_seconds = 0.0
	var outside_tracker: SwingContactTracker = SwingContactTracker.new()
	outside_tracker.begin(outside_intent, profile, 5, 5)
	var outside_state: PitchState = PitchState.new()
	outside_state.position = Vector3(0.0, 1.05, 2.38)
	outside_state.velocity = Vector3(0.0, 0.0, -20.0)
	var outside_result: ContactResult
	for _step in range(80):
		var previous_position: Vector3 = outside_state.position
		var previous_time: float = outside_state.elapsed_time
		outside_state.position += (
			outside_state.velocity * PitchFlightSolver.SUBSTEP_SECONDS
		)
		outside_state.elapsed_time += PitchFlightSolver.SUBSTEP_SECONDS
		outside_result = outside_tracker.sample_segment(
			previous_position,
			previous_time,
			outside_state
		)
		if outside_result != null:
			break
	_check(
		outside_result != null
		and outside_result.outcome == ContactResult.Outcome.MISS
		and outside_result.miss_reason == ContactResult.MissReason.LEFT,
		"depth encounter should report a spatial miss for bad X aim"
	)

	var early_tracker: SwingContactTracker = SwingContactTracker.new()
	early_tracker.begin(intent, profile, 5, 5)
	var early_state: PitchState = PitchState.new()
	early_state.position = Vector3(0.0, 1.05, 6.0)
	early_state.velocity = Vector3(0.0, 0.0, -12.0)
	var early_result: ContactResult
	for _step in range(80):
		var previous_position: Vector3 = early_state.position
		var previous_time: float = early_state.elapsed_time
		early_state.position += (
			early_state.velocity * PitchFlightSolver.SUBSTEP_SECONDS
		)
		early_state.elapsed_time += PitchFlightSolver.SUBSTEP_SECONDS
		early_result = early_tracker.sample_segment(
			previous_position,
			previous_time,
			early_state
		)
		if early_result != null:
			break
	_check(
		early_result != null
		and early_result.outcome == ContactResult.Outcome.MISS
		and early_result.miss_reason == ContactResult.MissReason.EARLY,
		"an early swing should finish while the Pitch keeps advancing"
	)

func _test_pitch_actor_contact_cancellation() -> void:
	var actor: PitchFlightActor = PitchFlightActor.new()
	_contact_cancel_actor = actor
	actor.segment_advanced.connect(_cancel_pitch_during_segment)
	add_child(actor)
	var parameters: PitchLaunchParameters = PitchLaunchParameters.new()
	parameters.position = Vector3(0.0, 1.05, 2.0)
	parameters.velocity = Vector3(0.0, 0.0, -18.0)
	actor.start_pitch(parameters)
	actor._physics_process(PitchFlightSolver.SUBSTEP_SECONDS * 2.0)
	_check(
		not actor.running and actor.state == null,
		"contact-time Pitch cancellation should survive the rest of its physics frame"
	)
	remove_child(actor)
	actor.queue_free()
	_contact_cancel_actor = null

func _test_signed_contact_spin() -> void:
	var profile: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	var pitch_state: PitchState = PitchState.new()
	pitch_state.position = Vector3(0.0, 1.05, 0.18)
	pitch_state.velocity = Vector3(0.0, 0.0, -18.0)
	pitch_state.elapsed_time = 0.11
	var undercut: SwingIntent = SwingIntent.new()
	undercut.aim_point = Vector2(0.0, 0.90)
	undercut.start_time_seconds = 0.0
	var rollover: SwingIntent = SwingIntent.new()
	rollover.aim_point = Vector2(0.0, 1.20)
	rollover.start_time_seconds = 0.0
	var undercut_result: ContactResult = ContactResolver.resolve_swept_segment(
		Vector3(0.0, 1.05, 0.38),
		0.10,
		pitch_state,
		undercut,
		profile
	)
	var rollover_result: ContactResult = ContactResolver.resolve_swept_segment(
		Vector3(0.0, 1.05, 0.38),
		0.10,
		pitch_state,
		rollover,
		profile
	)
	_check(
		undercut_result != null
		and rollover_result != null
		and undercut_result.backspin_rad_s > 0.0
		and rollover_result.backspin_rad_s < 0.0,
		"vertical contact offset should produce signed backspin and topspin"
	)

func _cancel_pitch_during_segment(
	_previous_position: Vector3,
	_previous_elapsed_seconds: float
) -> void:
	if _contact_cancel_actor != null:
		_contact_cancel_actor.reset_pitch()

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
		var sample_seed: int = 1000 + sample
		var fresh: PitchLaunchParameters = PitchExecutionModel.apply(
			base, 1.0, 0.50, 1.0, 1.05, pitch.category, sample_seed
		)
		var tired: PitchLaunchParameters = PitchExecutionModel.apply(
			base, 1.0, 1.0, 1.0, 1.05, pitch.category, sample_seed
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

func _test_fresh_pitch_reachability() -> void:
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	var mound: Vector3 = Vector3(0.0, 0.0, 13.716)
	var target: Vector3 = Vector3(0.0, 1.05, 0.0)
	var pitch_ids: Array[StringName] = [
		&"pitch.overhand_four_seam",
		&"pitch.overhand_sinker",
		&"pitch.sidearm_sinker",
		&"pitch.overhand_slider",
		&"pitch.sidearm_slider",
		&"pitch.eephus",
		&"pitch.knuckleball",
		&"pitch.riser",
		&"pitch.drop",
	]
	for index in range(pitch_ids.size()):
		var pitch: PitchDefinition = ContentDB.get_pitch(pitch_ids[index])
		var base: PitchLaunchParameters = PitchAimSolver.solve(
			pitch,
			ball,
			mound,
			target,
			false,
			700 + index
		)
		_check(base != null, "%s should produce an aimed launch" % pitch.display_name)
		if base == null:
			continue
		for sample in range(8):
			var executed: PitchLaunchParameters = PitchExecutionModel.apply(
				base,
				0.90,
				0.35,
				pitch.control_difficulty,
				pitch.execution_difficulty,
				pitch.category,
				9000 + index * 31 + sample
			)
			var crossing: PitchCrossingResult = (
				PitchTrajectorySimulator.simulate_to_plane(executed, 0.0)
			)
			_check(
				crossing.crossed,
				"%s should reach the plate when fresh" % pitch.display_name
			)

func _test_low_effort_eephus_reachability() -> void:
	var eephus: PitchDefinition = ContentDB.get_pitch(&"pitch.eephus")
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	var pitcher: PlayerDefinition = PlayerDefinition.new()
	pitcher.velocity = 5
	pitcher.break_rating = 4
	var rated: PitchDefinition = MatchLabSupport.rated_pitch(
		eephus,
		pitcher,
		MatchLabSupport.MIN_EFFORT
	)
	var targets: Array[Vector3] = [
		Vector3(-0.65, 0.35, 0.0),
		Vector3(0.0, 1.05, 0.0),
		Vector3(0.65, 1.75, 0.0),
	]
	for index in range(targets.size()):
		var solved: PitchLaunchParameters = PitchAimSolver.solve(
			rated,
			ball,
			Vector3(0.0, 0.0, 13.716),
			targets[index],
			false,
			1200 + index
		)
		_check(
			solved != null,
			"low-effort Eephus should solve across the authored aim area"
		)
		if solved == null:
			continue
		var crossing: PitchCrossingResult = (
			PitchTrajectorySimulator.simulate_to_plane(solved, 0.0)
		)
		_check(
			crossing.crossed,
			"low-effort Eephus should reach the plate plane"
		)
		if crossing.crossed:
			_check(
				Vector2(crossing.point.x, crossing.point.y).distance_to(
					Vector2(targets[index].x, targets[index].y)
				) <= 0.08,
				"low-effort Eephus should retain intended-location aiming"
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
		cadence.active_hold_seconds
		>= AtBatCadenceController.MIN_DEAD_BALL_HOLD_SECONDS
		and cadence.active_hold_seconds
		<= AtBatCadenceController.MAX_DEAD_BALL_HOLD_SECONDS,
		"dead-ball rhythm should leave time to read the previous result"
	)
	_check(
		cadence.advance(cadence.active_hold_seconds + 0.01)
		== AtBatCadenceController.Event.CONTINUE_PLAY,
		"an unfinished at-bat should continue without another acceptance"
	)
	cadence.hold_dead_ball(85, true)
	_check(
		cadence.active_hold_seconds
		>= AtBatCadenceController.MIN_BETWEEN_BATTERS_SECONDS,
		"a completed plate appearance should also advance automatically"
	)
	_check(
		cadence.advance(cadence.active_hold_seconds + 0.01)
		== AtBatCadenceController.Event.CONTINUE_PLAY,
		"terminal dead-ball holds should not wait for acceptance input"
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

func _test_match_presentation_sequence() -> void:
	var first: MatchPresentationDirector = MatchPresentationDirector.new()
	var replay: MatchPresentationDirector = MatchPresentationDirector.new()
	first.begin_intro(219)
	replay.begin_intro(219)
	_check(
		first.shot_sequence == replay.shot_sequence,
		"broadcast intro shot selection should replay from its seed"
	)
	_check(
		first.shot_sequence.size() >= 2
		and first.shot_sequence.size() <= 3,
		"a basic game intro should automatically select two or three shots"
	)
	var two_shot: MatchPresentationDirector = MatchPresentationDirector.new()
	two_shot.begin_intro(218)
	_check(
		two_shot.shot_sequence.size() == 2
		and first.shot_sequence.size() == 3,
		"ordinary match seeds should deliberately exercise two- and three-shot intros"
	)
	var unique_shots: Dictionary = {}
	for shot in first.shot_sequence:
		unique_shots[shot] = true
	_check(
		unique_shots.size() == first.shot_sequence.size(),
		"a short intro should not repeat the same camera"
	)
	var intro_event: MatchPresentationDirector.Event
	for index in range(first.shot_sequence.size()):
		intro_event = first.advance(MatchPresentationDirector.SHOT_SECONDS)
		var expected_event: MatchPresentationDirector.Event = (
			MatchPresentationDirector.Event.SHOT_CHANGED
			if index + 1 < first.shot_sequence.size()
			else MatchPresentationDirector.Event.RETURN_TO_GAMEPLAY
		)
		_check(
			intro_event == expected_event,
			"intro shots should advance and return through the role camera"
		)
	_check(
		first.advance(MatchPresentationDirector.SETTLE_SECONDS)
		== MatchPresentationDirector.Event.INTRO_COMPLETE
		and not first.blocks_gameplay(),
		"intro settlement should release gameplay"
	)

	first.begin_outro(220)
	var outro_event: MatchPresentationDirector.Event
	for _index in range(first.shot_sequence.size()):
		outro_event = first.advance(MatchPresentationDirector.SHOT_SECONDS)
	_check(
		outro_event == MatchPresentationDirector.Event.OUTRO_COMPLETE
		and first.mode == MatchPresentationDirector.Mode.OUTRO_HOLD
		and first.blocks_gameplay(),
		"outro completion should hold the final result until restart"
	)

	replay.begin_intro(221)
	_check(
		replay.skip() == MatchPresentationDirector.Event.INTRO_COMPLETE
		and not replay.blocks_gameplay(),
		"skipping the intro should release gameplay immediately"
	)

func _test_pitch_identity_and_batter_awareness() -> void:
	var fastball: PitchDefinition = ContentDB.get_pitch(
		&"pitch.overhand_four_seam"
	)
	var eephus: PitchDefinition = ContentDB.get_pitch(&"pitch.eephus")
	_check(
		fastball.nominal_velocity_mps >= eephus.nominal_velocity_mps * 1.75,
		"Four-Seam and Eephus must occupy clearly different speed bands"
	)
	_check(
		eephus.category == PitchDefinition.Category.UNCONVENTIONAL,
		"Eephus should remain an unconventional Pitch"
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
	_check(match_state.begin_pitch(), "a ready match should begin a Pitch")
	match_state.cancel_pitch()
	_check(
		match_state.phase == MatchState.Phase.PRE_PITCH
		and match_state.between_batters,
		"a failed launch should restore the pre-Pitch match state"
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
	_check(
		FieldingResolver.resolve(0.82, 8.0, 1.1, false, 6)
		== FieldingResolver.Outcome.MISS,
		"the Primary Fielder must not control balls outside visible reach"
	)
	_check(
		FieldingResolver.resolve(
			0.45,
			8.0,
			FieldingResolver.MAX_AIR_CONTROL_HEIGHT_M + 0.05,
			false,
			10
		) == FieldingResolver.Outcome.MISS,
		"the Primary Fielder must not catch balls above authored hand reach"
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
