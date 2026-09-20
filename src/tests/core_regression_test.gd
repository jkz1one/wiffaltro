# gdlint: disable=max-file-lines
extends Node

var _failures: int = 0
var _contact_cancel_actor: PitchFlightActor

func _ready() -> void:
	_test_pitch_release_quality()
	_test_bat_handedness_mapping()
	_test_swept_swing_timeline()
	BatSwingRegressionTest.run(self, Callable(self, "_check"))
	PlayabilityRegressionTest.run(Callable(self, "_check"))
	PitchClearanceRegressionTest.run(self, Callable(self, "_check"))
	FieldScoringRegressionTest.run(Callable(self, "_check"))
	_test_signed_contact_spin()
	_test_pitch_actor_contact_cancellation()
	_test_fatigue_curve_and_capacity()
	_test_fatigue_pitch_outcomes()
	_test_fresh_pitch_reachability()
	_test_low_effort_eephus_reachability()
	_test_at_bat_cadence()
	_test_match_flow_guards()
	_test_match_lab_suspension()
	_test_match_presentation_sequence()
	_test_pitch_identity_and_batter_awareness()
	_test_ai_pitch_determinism_and_counts()
	_test_match_count_rules()
	_test_match_scorebug()
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
		0.53,
		2,
		1.0
	)
	var fresh_high_control: float = PitchReleaseController.quality_at(
		0.53,
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
		PitchReleaseController.AUTO_RELEASE_SECONDS < 0.65,
		"the player delivery meter should complete quickly"
	)
	_check(
		PitchReleaseController.new().ideal_progress() >= 0.82
		and PitchReleaseController.new().ideal_progress() <= 0.88,
		"the release sweet spot should sit near 85% of the meter"
	)
	_check(
		PitchReleaseController.overdrive_at(
			PitchReleaseController.IDEAL_RELEASE_SECONDS
		) == 0.0
		and PitchReleaseController.overdrive_at(
			PitchReleaseController.AUTO_RELEASE_SECONDS
		) > 0.99,
		"only the short post-sweet-spot tail should add overdrive"
	)
	var pitcher: PlayerDefinition = ContentDB.get_player(&"player.debug_pitcher")
	var fastball: PitchDefinition = ContentDB.get_pitch(
		&"pitch.overhand_four_seam"
	)
	var slider: PitchDefinition = ContentDB.get_pitch(&"pitch.overhand_slider")
	var normal_fastball: PitchDefinition = MatchLabSupport.rated_pitch(
		fastball,
		pitcher,
		1.0,
		0.0
	)
	var overdriven_fastball: PitchDefinition = MatchLabSupport.rated_pitch(
		fastball,
		pitcher,
		1.0,
		1.0
	)
	var normal_slider: PitchDefinition = MatchLabSupport.rated_pitch(
		slider,
		pitcher,
		1.0,
		0.0
	)
	var overdriven_slider: PitchDefinition = MatchLabSupport.rated_pitch(
		slider,
		pitcher,
		1.0,
		1.0
	)
	_check(
		overdriven_fastball.nominal_velocity_mps
		> normal_fastball.nominal_velocity_mps,
		"overcooking a fastball should add bounded velocity"
	)
	_check(
		overdriven_slider.nominal_spin_rpm > normal_slider.nominal_spin_rpm
		and MatchLabSupport.release_overdrive_control_penalty(1.0) > 0.0,
		"overcooking a breaker should add finish at an explicit command cost"
	)

func _test_bat_handedness_mapping() -> void:
	_check(
		BatActor.stance_pivot_x(false) > 0.0
		and BatActor.stance_pivot_x(true) < 0.0,
		"right- and left-handed bats should load on mirrored back shoulders"
	)
	_check(
		BatActor.stance_yaw_degrees(false) > 0.0
		and is_zero_approx(BatActor.contact_yaw_degrees(false))
		and BatActor.stance_yaw_degrees(true) < 0.0
		and is_zero_approx(BatActor.contact_yaw_degrees(true))
		and BatActor.finish_yaw_degrees(false) < 0.0
		and BatActor.finish_yaw_degrees(true) > 0.0,
		"each handed bat should square at contact then finish toward the front"
	)
	_check(
		BatActor.stance_pivot_position(false).z
		< BatActor.contact_pivot_position(false).z,
		"the bat should load behind the contact position"
	)
	var bat: BatActor = BatActor.new()
	add_child(bat)
	bat.configure(false, Vector3.ZERO)
	_check(
		bat._pivot.position.x > 0.0 and bat._pivot.rotation.y > 0.0,
		"a visible right-handed bat should begin on its back/right shoulder"
	)
	var contact_profile: SwingProfileDefinition = ContentDB.get_swing(
		&"swing.contact"
	)
	bat.play_swing(contact_profile)
	bat._process(contact_profile.sweet_spot_seconds)
	_check(
		absf(bat._pivot.rotation.y) < 0.001
		and bat._pivot.position.is_equal_approx(
			BatActor.contact_pivot_position(false)
		),
		"the visible barrel should be square at the authored sweet spot"
	)
	bat._process(
		contact_profile.swing_duration_seconds
		- contact_profile.sweet_spot_seconds
	)
	_check(
		bat._pivot.rotation.y < 0.0
		and absf(bat._pivot.rotation.y) < PI,
		"the right-handed bat should finish forward without wrapping around"
	)
	bat.configure(true, Vector3.ZERO)
	_check(
		bat._pivot.position.x < 0.0 and bat._pivot.rotation.y < 0.0,
		"a visible left-handed stance should mirror the full bat rig"
	)
	bat.queue_free()

	var pitcher_avatar: PlayerAvatar = PlayerAvatar.new()
	add_child(pitcher_avatar)
	pitcher_avatar.configure(
		PlayerAvatar.Role.PITCHER,
		false,
		false,
		Color.WHITE
	)
	var ready_hand_position: Vector3 = pitcher_avatar._throw_hand.position
	pitcher_avatar.set_pitch_delivery_progress(0.68, false)
	_check(
		pitcher_avatar._throw_hand.position != ready_hand_position,
		"the player Pitcher release meter should drive a visible delivery pose"
	)
	pitcher_avatar.queue_free()

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
	var execution_seeds_preserved: bool = true
	var sample_count: int = 32
	for sample in range(sample_count):
		var sample_seed: int = 1000 + sample
		var fresh: PitchLaunchParameters = PitchExecutionModel.apply(
			base, 1.0, 0.50, 1.0, 1.05, pitch.category, sample_seed
		)
		var tired: PitchLaunchParameters = PitchExecutionModel.apply(
			base, 1.0, 1.0, 1.0, 1.05, pitch.category, sample_seed
		)
		execution_seeds_preserved = (
			execution_seeds_preserved
			and fresh.seed == sample_seed
			and tired.seed == sample_seed
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
	_check(
		execution_seeds_preserved,
		"Pitch execution should preserve its explicit deterministic seed"
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

func _test_match_flow_guards() -> void:
	var batting_lab: PitchBatLab = PitchBatLab.new()
	batting_lab._match_state = MatchLabSupport.create_match(
		batting_lab.DEBUG_PLAYER_ID,
		batting_lab.PLAYER_TEAM_NAME,
		batting_lab.RIVAL_TEAM_NAME
	)
	batting_lab._status_label = Label.new()
	batting_lab._at_bat_cadence = AtBatCadenceController.new()
	batting_lab._selected_pitch_index = 1
	batting_lab._pitch_target = Vector2(0.62, 0.42)
	_check(
		batting_lab._match_state.begin_pitch(),
		"AI failure regression should begin from a live Pitch"
	)
	PitchBatLabFeelSupport.recover_failed_pitch(
		batting_lab,
		ContentDB.get_pitch(&"pitch.eephus")
	)
	_check(
		batting_lab._match_state.phase == MatchState.Phase.PRE_PITCH
		and batting_lab._at_bat_cadence.state
		== AtBatCadenceController.State.DELIVERY
		and batting_lab._selected_pitch_index == 0
		and batting_lab._pitch_target == batting_lab.DEFAULT_TARGET
		and batting_lab._ai_pitch_preselected
		and not batting_lab._awaiting_batter_confirm,
		"a failed AI aim solve should recover into an automatic safe retry"
	)
	batting_lab._status_label.free()
	batting_lab.free()

	var pitching_lab: PitchBatLab = PitchBatLab.new()
	pitching_lab._match_state = MatchLabSupport.create_match(
		pitching_lab.DEBUG_PLAYER_ID,
		pitching_lab.PLAYER_TEAM_NAME,
		pitching_lab.RIVAL_TEAM_NAME
	)
	pitching_lab._match_state.top_half = false
	pitching_lab._release_controller = PitchReleaseController.new()
	pitching_lab._status_label = Label.new()
	_check(
		MatchLabSupport.can_edit_pitch_plan(pitching_lab),
		"Pitch setup should remain editable before the delivery begins"
	)
	pitching_lab._release_controller.begin()
	var original_pitcher_index: int = (
		pitching_lab._match_state.defensive_team().pitcher_index
	)
	var original_fielder_index: int = (
		pitching_lab._match_state.defensive_team().fielder_index
	)
	MatchLabSupport.cycle_pitcher(pitching_lab, 1)
	MatchLabSupport.cycle_primary_fielder(pitching_lab)
	_check(
		not MatchLabSupport.can_edit_pitch_plan(pitching_lab),
		"Pitch setup should lock while the release meter is active"
	)
	_check(
		pitching_lab._match_state.defensive_team().pitcher_index
		== original_pitcher_index
		and pitching_lab._match_state.defensive_team().fielder_index
		== original_fielder_index,
		"Pitcher and Primary Fielder roles should lock once delivery begins"
	)
	pitching_lab._release_controller.cancel()
	pitching_lab._match_state.begin_pitch()
	_check(
		not MatchLabSupport.can_edit_pitch_plan(pitching_lab),
		"Pitch setup should stay locked after the ball is committed"
	)
	pitching_lab._status_label.free()
	pitching_lab.free()

func _test_match_lab_suspension() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_state = MatchLabSupport.create_match(
		lab.DEBUG_PLAYER_ID,
		lab.PLAYER_TEAM_NAME,
		lab.RIVAL_TEAM_NAME
	)
	var original_match: MatchState = lab._match_state
	original_match.balls = 2
	original_match.strikes = 1
	lab._field_definition = ContentDB.get_field(lab.FIELD_ID)
	lab._at_bat_cadence = AtBatCadenceController.new()
	lab._release_controller = PitchReleaseController.new()
	lab._match_presentation_director = MatchPresentationDirector.new()
	lab._primary_fielder = FielderController.new()
	lab.add_child(lab._primary_fielder)
	lab._trajectory_draw = TrajectoryDebugDraw.new()
	lab.add_child(lab._trajectory_draw)
	lab._contact_vector_draw = TrajectoryDebugDraw.new()
	lab.add_child(lab._contact_vector_draw)
	lab._status_label = Label.new()
	lab.add_child(lab._status_label)
	lab._live_label = Label.new()
	lab.add_child(lab._live_label)
	lab._selected_pitch_index = 1
	lab._pitch_target = Vector2(0.31, 1.42)
	lab._pitch_effort = 1.07
	lab._fielder_anchor_index = 7
	lab._status_label.text = "Resume marker"

	PitchBatLabFeelSupport.toggle_match_mode(lab)
	_check(
		not lab._match_mode and lab._match_state == original_match,
		"entering Mechanics Lab should suspend rather than replace the match"
	)
	lab._selected_pitch_index = 0
	lab._pitch_target = Vector2.ZERO
	lab._pitch_effort = 0.82
	PitchBatLabFeelSupport.toggle_match_mode(lab)
	_check(
		lab._match_mode
		and lab._match_state == original_match
		and lab._match_state.balls == 2
		and lab._match_state.strikes == 1
		and lab._selected_pitch_index == 1
		and lab._pitch_target == Vector2(0.31, 1.42)
		and is_equal_approx(lab._pitch_effort, 1.07)
		and lab._fielder_anchor_index == 7
		and lab._status_label.text == "Resume marker",
		"leaving Mechanics Lab should restore the same match and pre-Pitch plan"
	)
	lab._fielder_anchor_index = 4
	lab._apply_defensive_assignment()
	_check(
		lab._fielder_anchor_index == PitchBatLab.DEFAULT_FIELDER_ANCHOR_INDEX,
		"restoring an obsolete center-lane assignment should fall back to a legal anchor"
	)
	original_match.begin_pitch()
	PitchBatLabFeelSupport.toggle_match_mode(lab)
	_check(
		lab._match_mode
		and lab._match_state == original_match
		and lab._match_state.phase == MatchState.Phase.PITCH_IN_FLIGHT,
		"a live Pitch should refuse Lab entry without discarding its match state"
	)
	lab.free()

func _test_match_scorebug() -> void:
	var match_state: MatchState = MatchState.create(
		_make_team("Away"),
		_make_team("Home")
	)
	match_state.away_team.runs = 3
	match_state.home_team.runs = 2
	match_state.balls = 2
	match_state.strikes = 1
	match_state.outs = 1
	match_state.bases.first = &"runner.first"
	var scorebug: MatchScorebug = MatchScorebug.new()
	add_child(scorebug)
	scorebug.refresh(match_state)
	_check(
		scorebug.visible
		and scorebug._away_score.text == "3"
		and scorebug._home_score.text == "2"
		and scorebug._count.text == "2–1"
		and scorebug._outs.text == "1 OUT",
		"scorebug should render score, count, and outs from MatchState"
	)
	_check(
		scorebug._base_markers.size() == 3,
		"scorebug should expose three persistent base indicators"
	)
	scorebug.queue_free()

func _test_match_presentation_sequence() -> void:
	var camera_director: MatchCameraDirector = MatchCameraDirector.new()
	camera_director.cycle_shot()
	_check(
		camera_director.shot == MatchCameraDirector.Shot.PITCHING,
		"camera shot cycling should preserve the typed Shot enum"
	)
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera_director.set_shot(MatchCameraDirector.Shot.FIELD_SETUP)
	camera_director.snap(camera)
	_check(
		camera.projection == Camera3D.PROJECTION_ORTHOGONAL
		and camera.global_basis.y.is_equal_approx(Vector3.BACK)
		and is_equal_approx(camera.global_basis.determinant(), 1.0),
		"Field Setup should use an undistorted orthographic view"
	)
	var live_ball_position: Vector3 = Vector3(1.0, 2.0, 10.0)
	camera_director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	camera_director.prepare_ball_in_play(true, live_ball_position)
	camera_director.snap(camera, live_ball_position)
	var defense_camera_z: float = camera.global_position.z
	camera_director.prepare_ball_in_play(false, live_ball_position)
	camera_director.snap(camera, live_ball_position)
	_check(
		defense_camera_z > live_ball_position.z
		and camera.global_position.z < live_ball_position.z
		and camera.projection == Camera3D.PROJECTION_PERSPECTIVE,
		"ball-in-play tracking should preserve defense or batting field orientation"
	)
	camera.queue_free()

	var first: MatchPresentationDirector = MatchPresentationDirector.new()
	var replay: MatchPresentationDirector = MatchPresentationDirector.new()
	first.begin_intro(219)
	replay.begin_intro(219)
	_check(
		first.shot_sequence == replay.shot_sequence,
		"broadcast intro shot selection should replay from its seed"
	)
	_check(
		first.motion_sequence == replay.motion_sequence,
		"broadcast intro camera motion should replay from its seed"
	)
	_check(
		first.shot_sequence.size() >= 1
		and first.shot_sequence.size() <= 3,
		"a basic game intro should automatically select one, two, or three shots"
	)
	var two_shot: MatchPresentationDirector = MatchPresentationDirector.new()
	two_shot.begin_intro(218)
	_check(
		two_shot.shot_sequence.size() == 2
		and first.shot_sequence.size() == 3,
		"ordinary match seeds should deliberately exercise two- and three-shot intros"
	)
	var long_take: MatchPresentationDirector = MatchPresentationDirector.new()
	long_take.begin_intro(216)
	_check(
		long_take.shot_sequence.size() == 1
		and long_take.shot_duration_seconds() == MatchPresentationDirector.LONG_SHOT_SECONDS,
		"one-shot intros should use the longer authored hold"
	)
	var unique_shots: Dictionary = {}
	for shot in first.shot_sequence:
		unique_shots[shot] = true
	_check(
		unique_shots.size() == first.shot_sequence.size(),
		"a short intro should not repeat the same camera"
	)
	_check(
		first.motion_sequence.size() == first.shot_sequence.size(),
		"each presentation shot should receive one slow camera motion"
	)
	var intro_event: MatchPresentationDirector.Event
	for index in range(first.shot_sequence.size()):
		intro_event = first.advance(first.shot_duration_seconds())
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
		outro_event = first.advance(first.shot_duration_seconds())
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
	var field: FieldDefinition = ContentDB.get_field(&"field.starter_backyard")
	var mound: Vector3 = Vector3(0.0, 0.0, 13.716)
	var fielder: FielderController = FielderController.new()
	add_child(fielder)
	fielder.set_pitcher_lane(mound.z)
	fielder.set_anchor(field.fielder_anchor(7))
	fielder.reaction_delay_seconds = 0.0
	fielder.target_position = Vector3(0.0, 0.0, 8.5)
	fielder._physics_process(1.0)
	_check(
		fielder.global_position.is_equal_approx(fielder.anchor_position),
		"the Primary Fielder must stay at its anchor before contact"
	)
	fielder.begin_play()
	fielder.target_position = Vector3(0.0, 0.0, 8.5)
	for _frame in range(300):
		fielder._physics_process(1.0 / 60.0)
	_check(
		fielder.global_position.distance_to(fielder.target_position) < 0.15,
		"a deep Fielder should charge into the near field after contact"
	)
	fielder.end_play()
	_check(
		not fielder.active and fielder.global_position.is_equal_approx(fielder.anchor_position),
		"dead play must restore the safe pre-Pitch anchor"
	)
	fielder.queue_free()
	_check(
		not field.is_fielder_anchor_available(1)
		and not field.is_fielder_anchor_available(4)
		and field.fielder_anchor(3).distance_to(mound) >= 5.0,
		"shallow/middle center must be unavailable and the default side anchor must clear the Pitcher"
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
	record.release_overdrive = 0.72
	record.exit_speed_mps = 21.4
	record.launch_angle_degrees = 12.5
	record.has_first_ground = true
	record.first_ground_position = Vector3(1.0, 0.04, 10.2)
	record.resolution_reason = &"ball_settled"
	record.result = &"single"
	var encoded: Dictionary = record.to_dict()
	_check(encoded["play_number"] == 7, "record should retain play number")
	_check(
		is_equal_approx(float(encoded["intended_target"][0]), 0.2)
		and is_equal_approx(float(encoded["intended_target"][1]), 1.1),
		"record vectors should be JSON-safe arrays"
	)
	_check(
		is_equal_approx(float(encoded["release_overdrive"]), 0.72),
		"record should retain release overdrive for deterministic tuning"
	)
	_check(
		is_equal_approx(float(encoded["exit_speed_mps"]), 21.4)
		and is_equal_approx(float(encoded["launch_angle_degrees"]), 12.5)
		and bool(encoded["has_first_ground"])
		and is_equal_approx(float(encoded["first_ground_position"][2]), 10.2)
		and encoded["resolution_reason"] == "ball_settled",
		"record should retain batted-ball geometry and resolution telemetry"
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
