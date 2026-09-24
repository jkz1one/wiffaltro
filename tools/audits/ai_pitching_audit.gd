extends Node

var _parameters: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var db: Node = get_tree().root.get_node("ContentDB")
	var ball: BallSetupDefinition = db.get_ball_setup(&"ball_setup.fresh")
	var pitcher: PlayerDefinition = db.get_player(PitchBatLab.DEBUG_PLAYER_ID)
	var rows: Array = []
	for pitch: PitchDefinition in db.pitch_by_id.values():
		var rated: PitchDefinition = MatchLabSupport.rated_pitch(pitch, pitcher, 1.0)
		for x in [-0.85, -0.35, 0.0, 0.35, 0.85]:
			for rating in [3, 5, 8]:
				for familiar in ["fresh", "repeat", "mixed"]:
					var row: Dictionary = {
						"pitch": String(pitch.id),
						"x": x,
						"rating": rating,
						"familiar": familiar,
						"trials": 0,
						"swings": 0,
						"contact": 0,
						"fair": 0,
						"quality_sum": 0.0,
						"timing_miss": 0,
						"aim_sigma_sum": 0.0
					}
					for left in [false, true]:
						var launch: PitchLaunchParameters = PitchAimSolver.solve(
							rated, ball, PitchBatLab.MOUND_ORIGIN, Vector3(x, 1.05, 0), left, 41
						)
						if launch == null:
							continue
						for sample in range(48):
							var key: String = "%s/%s/%s/%s" % [pitch.id, x, left, sample]
							if not _parameters.has(key):
								_parameters[key] = PitchExecutionModel.apply(
									launch,
									0.9,
									0.0,
									pitch.control_difficulty,
									pitch.execution_difficulty,
									pitch.category,
									4100 + sample
								)
							var parameters: PitchLaunchParameters = _parameters[key]
							var model: BatterApproachModel = BatterApproachModel.new()
							if familiar != "fresh":
								for n in range(6):
									model.observe(
										(
											pitch
											if familiar == "repeat"
											else db.pitch_by_id.values()[n % db.pitch_by_id.size()]
										),
										(
											Vector2(x, 1.05)
											if familiar == "repeat"
											else Vector2(
												-0.35 + (n % 3) * 0.35, 0.75 + (n % 2) * 0.6
											)
										)
									)
							var batter: PlayerDefinition = PlayerDefinition.new()
							batter.contact = rating
							batter.power = 5
							var result: Dictionary = _delivery(
								model, pitch, parameters, batter, sample * 3571 + 97, db
							)
							for metric in result:
								row[metric] += result[metric]
					rows.append(row)
	print("AI_AUDIT_JSON=" + JSON.stringify(rows))
	get_tree().quit()


func _delivery(
	model: BatterApproachModel,
	pitch: PitchDefinition,
	parameters: PitchLaunchParameters,
	batter: PlayerDefinition,
	sample: int,
	db: Node,
	balls: int = 0,
	strikes: int = 1
) -> Dictionary:
	var row: Dictionary = {
		"trials": 1,
		"swings": 0,
		"contact": 0,
		"fair": 0,
		"quality_sum": 0.0,
		"timing_miss": 0,
		"aim_sigma_sum": 0.0
	}
	var state: PitchState = PitchState.new()
	state.position = parameters.position
	state.velocity = parameters.velocity
	state.orientation = parameters.orientation
	state.angular_velocity = parameters.angular_velocity
	state.seed = parameters.seed
	var tracker: SwingContactTracker = SwingContactTracker.new()
	var decided: bool = false
	var planned: Dictionary = {}
	while state.elapsed_time < 3.0 and state.position.z > 0.0:
		var previous: Vector3 = state.position
		var previous_time: float = state.elapsed_time
		PitchFlightSolver.step(state, parameters)
		if tracker.active:
			var contact: ContactResult = tracker.sample_segment(previous, previous_time, state)
			if contact != null:
				row.contact = int(contact.outcome != ContactResult.Outcome.MISS)
				row.fair = int(
					(
						contact.outcome
						in [ContactResult.Outcome.CONTACT, ContactResult.Outcome.PERFECT]
					)
				)
				row.quality_sum = contact.quality
				row.timing_miss = int(
					(
						contact.outcome == ContactResult.Outcome.MISS
						and (
							contact.miss_reason
							in [ContactResult.MissReason.EARLY, ContactResult.MissReason.LATE]
						)
					)
				)
				break
		if decided:
			continue
		var read: Vector2 = BatterApproachModel.read_plate_location(state.position, state.velocity)
		if model.has_method("track_pitch"):
			planned = model.call(
				"track_pitch",
				pitch,
				state,
				batter,
				balls,
				strikes,
				sample,
				batter.bats,
				db.get_swing(PitchBatLab.CONTACT_SWING_ID),
				db.get_swing(PitchBatLab.POWER_SWING_ID)
			)
		else:
			if (
				state.position.z
				> model.trigger_z(pitch, state.velocity.length(), read, batter.contact, sample)
			):
				continue
			planned = model.decide(
				pitch, read, read, batter, balls, strikes, state.velocity.length(), sample
			)
		if planned.is_empty():
			continue
		decided = true
		row.aim_sigma_sum = planned.aim_sigma
		if not planned.swing:
			break
		row.swings = 1
		var intent: SwingIntent = SwingIntent.new()
		intent.profile_id = (
			PitchBatLab.POWER_SWING_ID if planned.use_power else PitchBatLab.CONTACT_SWING_ID
		)
		intent.handedness_left = batter.bats == PlayerDefinition.Handedness.LEFT
		intent.aim_point = planned.aim
		intent.start_time_seconds = state.elapsed_time
		tracker.begin(intent, db.get_swing(intent.profile_id), batter.contact, batter.power)
	if tracker.active:
		tracker.force_miss(state)
		row.timing_miss = 1
	return row
