extends "res://tools/audits/ai_pitching_audit.gd"


func _run() -> void:
	var db: Node = get_tree().root.get_node("ContentDB")
	var ball: BallSetupDefinition = db.get_ball_setup(&"ball_setup.fresh")
	var rows: Array = []
	var pitch_ids: Array[StringName] = [
		&"pitch.overhand_four_seam", &"pitch.overhand_slider", &"pitch.eephus"
	]
	for pitcher_rating in [3, 8]:
		for condition in ["fresh", "poor_release", "exhausted"]:
			for sequence in ["repeat", "mixed"]:
				for count in [Vector2i(0, 0), Vector2i(0, 2), Vector2i(3, 0)]:
					var row: Dictionary = {
						"pitcher": pitcher_rating,
						"condition": condition,
						"sequence": sequence,
						"count": str(count),
						"trials": 0,
						"swings": 0,
						"contact": 0,
						"fair": 0,
						"quality_sum": 0.0,
						"timing_miss": 0,
						"aim_sigma_sum": 0.0,
						"zone": 0,
						"plate_error": 0.0,
						"plate_speed": 0.0
					}
					for hand in [
						PlayerDefinition.Handedness.RIGHT, PlayerDefinition.Handedness.LEFT
					]:
						var pitcher: PlayerDefinition = (
							db.get_player(PitchBatLab.DEBUG_PLAYER_ID).duplicate()
						)
						pitcher.velocity = pitcher_rating
						pitcher.break_rating = pitcher_rating
						pitcher.control = pitcher_rating
						var batter: PlayerDefinition = PlayerDefinition.new()
						batter.contact = 5
						batter.power = 5
						batter.bats = hand
						var model: BatterApproachModel = BatterApproachModel.new()
						for n in range(36):
							if n % 6 == 0:
								model.begin_plate_appearance(n / 6)
							# Every cell contains the same pitch mix. Repetition groups pitches;
							# mixing alternates them. Counts are controlled, not simulated PAs.
							var pitch_id: StringName = pitch_ids[
								(n / 12) if sequence == "repeat" else n % 3
							]
							var pitch: PitchDefinition = db.get_pitch(pitch_id)
							var target: Vector3 = Vector3(0.32 if n % 2 == 0 else -0.32, 1.05, 0)
							var key: String = (
								"%s/%s/%s/%s" % [pitcher_rating, condition, pitch_id, n % 2]
							)
							if not _parameters.has(key):
								var rated: PitchDefinition = MatchLabSupport.rated_pitch(
									pitch, pitcher, 1.0
								)
								var launch: PitchLaunchParameters = PitchAimSolver.solve(
									rated, ball, PitchBatLab.MOUND_ORIGIN, target, false, 41
								)
								_parameters[key] = launch
							var parameters: PitchLaunchParameters = PitchExecutionModel.apply(
								_parameters[key],
								minf(
									0.35 if condition == "poor_release" else 1.0,
									0.86 + pitcher_rating * 0.014
								),
								1.0 if condition == "exhausted" else 0.0,
								pitch.control_difficulty,
								pitch.execution_difficulty,
								pitch.category,
								4100 + n
							)
							var crossing: PitchCrossingResult = (
								PitchTrajectorySimulator.simulate_to_plane(parameters, 0)
							)
							var xy: Vector2 = Vector2(crossing.point.x, crossing.point.y)
							row.zone += int(absf(xy.x) <= 0.43 and absf(xy.y - 1.05) <= 0.5)
							row.plate_error += xy.distance_to(Vector2(target.x, target.y))
							row.plate_speed += crossing.velocity.length()
							var result: Dictionary = _delivery(
								model,
								pitch,
								parameters,
								batter,
								n * 3571 + 97,
								db,
								count.x,
								count.y
							)
							for metric in result:
								row[metric] += result[metric]
					rows.append(row)
	print("AI_MATCHUPS_JSON=" + JSON.stringify(rows))
	get_tree().quit()
