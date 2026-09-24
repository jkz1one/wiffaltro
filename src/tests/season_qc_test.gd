extends Node

var _failures: int = 0


func _ready() -> void:
	_test_scouting()
	_test_unreachable_chase()
	_test_physical_batting()
	await _test_foul_feedback()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro season QC checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _test_scouting() -> void:
	var model: BatterApproachModel = BatterApproachModel.new()
	var pitch: PitchDefinition = ContentDB.get_pitch(&"pitch.overhand_four_seam")
	var target: Vector2 = Vector2(0.35, 1.05)
	for i in range(8):
		model.observe(pitch, target)
	model.begin_plate_appearance(2)
	_check(
		is_equal_approx(model.awareness_for(pitch, target), 0.12),
		"lineup notices repeated location across batters without retaining full individual familiarity"
	)
	for i in range(8):
		model.observe(pitch, Vector2(-0.35, 1.05))
	model.begin_plate_appearance(3)
	_check(is_zero_approx(model.awareness_for(pitch, target)), "old scouting must age out")
	model.reset(0)
	_check(model.recent_locations.is_empty(), "new match clears scouting")


func _test_unreachable_chase() -> void:
	# A bot requesting an aim far outside player reach must not move its bat there.
	for x in [-3.0, 3.0]:
		var intent: SwingIntent = SwingIntent.new()
		intent.aim_point = Vector2(x, 1.05)
		var tracker: SwingContactTracker = SwingContactTracker.new()
		tracker.begin(intent, ContentDB.get_swing(PitchBatLab.CONTACT_SWING_ID), 8, 5)
		var state: PitchState = PitchState.new()
		state.position = Vector3(x, 1.05, 0.18)
		state.velocity = Vector3(0, 0, -20)
		state.elapsed_time = 0.11
		var result: ContactResult = tracker.sample_segment(Vector3(x, 1.05, 0.38), 0.10, state)
		_check(
			result != null and result.outcome == ContactResult.Outcome.MISS,
			"a far chase cannot teleport the physical bat outside shared player reach"
		)


func _test_physical_batting() -> void:
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	var pitcher: PlayerDefinition = ContentDB.get_player(PitchBatLab.DEBUG_PLAYER_ID)
	var model: BatterApproachModel = BatterApproachModel.new()
	var skill_contacts: Array[int] = [0, 0]
	for skill_index in range(2):
		var batter: PlayerDefinition = PlayerDefinition.new()
		batter.contact = 3 if skill_index == 0 else 8
		batter.power = 5
		var side_contacts: Array[int] = [0, 0]
		var side_swings: Array[int] = [0, 0]
		var side_trials: Array[int] = [0, 0]
		for pitch_id in [&"pitch.overhand_four_seam", &"pitch.overhand_slider", &"pitch.eephus"]:
			var pitch: PitchDefinition = MatchLabSupport.rated_pitch(
				ContentDB.get_pitch(pitch_id), pitcher, 1.0
			)
			for pitcher_left in [false, true]:
				for batter_left in [false, true]:
					batter.bats = (
						PlayerDefinition.Handedness.LEFT
						if batter_left
						else PlayerDefinition.Handedness.RIGHT
					)
					for side in range(2):
						var x: float = (0.34 if side == 0 else -0.34) * (-1 if batter_left else 1)
						var launch: PitchLaunchParameters = PitchAimSolver.solve(
							pitch,
							ball,
							PitchBatLab.MOUND_ORIGIN,
							Vector3(x, 1.05, 0),
							pitcher_left,
							41
						)
						_check(launch != null, "inside/outside fixture must solve")
						if launch == null:
							continue
						for sample in range(60):
							model.reset(1)
							var parameters: PitchLaunchParameters = PitchExecutionModel.apply(
								launch,
								0.9,
								0.0,
								pitch.control_difficulty,
								pitch.execution_difficulty,
								pitch.category,
								4100 + sample
							)
							var state: PitchState = PitchState.new()
							state.position = parameters.position
							state.velocity = parameters.velocity
							state.orientation = parameters.orientation
							state.angular_velocity = parameters.angular_velocity
							state.seed = parameters.seed
							var tracker: SwingContactTracker = SwingContactTracker.new()
							var decided: bool = false
							var contacted: bool = false
							while state.elapsed_time < 3.0 and state.position.z > 0.0:
								var previous: Vector3 = state.position
								var previous_time: float = state.elapsed_time
								PitchFlightSolver.step(state, parameters)
								if tracker.active:
									var result: ContactResult = tracker.sample_segment(
										previous, previous_time, state
									)
									if result != null:
										contacted = result.outcome != ContactResult.Outcome.MISS
										break
								if not decided:
									var decision: Dictionary = model.track_pitch(
										pitch,
										state,
										batter,
										0,
										1,
										sample,
										batter.bats,
										ContentDB.get_swing(PitchBatLab.CONTACT_SWING_ID),
										ContentDB.get_swing(PitchBatLab.POWER_SWING_ID)
									)
									if decision.is_empty():
										continue
									decided = true
									if not decision.swing:
										break
									side_swings[side] += 1
									var intent: SwingIntent = SwingIntent.new()
									intent.aim_point = decision.aim
									intent.handedness_left = batter_left
									intent.start_time_seconds = state.elapsed_time
									intent.profile_id = (
										PitchBatLab.POWER_SWING_ID
										if decision.use_power
										else PitchBatLab.CONTACT_SWING_ID
									)
									tracker.begin(
										intent,
										ContentDB.get_swing(intent.profile_id),
										batter.contact,
										batter.power
									)
							side_trials[side] += 1
							side_contacts[side] += int(contacted)
							skill_contacts[skill_index] += int(contacted)
		print(
			"PHYSICAL BATTING contact=",
			batter.contact,
			" inside/outside contacts=",
			side_contacts,
			" swings=",
			side_swings,
			" trials=",
			side_trials
		)
		_check(
			absf(float(side_contacts[0] - side_contacts[1])) / side_trials[0] < 0.10,
			"mirrored strike locations must not create a large pooled side exploit"
		)
		_check(side_contacts[0] > 20 and side_contacts[1] > 20, "both sides must be hittable")
	_check(
		skill_contacts[1] > skill_contacts[0] * 1.20, "contact skill must improve physical outcomes"
	)


func _test_foul_feedback() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._throw_pitch()
	var profile: SwingProfileDefinition = ContentDB.get_swing(lab.CONTACT_SWING_ID)
	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = profile.id
	lab._swing_tracker.begin(intent, profile, 5, 5)
	var pitch_name: String = lab._selected_pitch().display_name
	var contact: ContactResult = ContactResult.new()
	contact.outcome = ContactResult.Outcome.FOUL
	contact.exit_velocity = Vector3(4, 2, 4)
	PitchBatLabSwingSupport._resolve_contact(lab, contact)
	lab._ball_play_resolver.record_ground_contact(Vector3(4, 0, 2))
	_check(
		pitch_name in lab._status_label.text and "MPH" in lab._status_label.text,
		"foul result retains thrown pitch identity and incoming speed after actor reset"
	)
	lab.queue_free()
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
