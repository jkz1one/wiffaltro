extends Node

var _failures: int = 0

func _ready() -> void:
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	var player: PlayerDefinition = ContentDB.get_player(&"player.debug_pitcher")
	for pitch: PitchDefinition in ContentDB.pitch_by_id.values():
		var rated: PitchDefinition = MatchLabSupport.rated_pitch(pitch, player, 1.0)
		var base: PitchLaunchParameters = PitchAimSolver.solve(
			rated, ball, PitchBatLab.MOUND_ORIGIN, Vector3(0.32, 1.05, 0), false, 41)
		if base == null:
			push_error("Quality fixture must solve: " + pitch.display_name)
			get_tree().quit(1)
			return
		var fresh_speed: float = 0.0
		var fresh_error: float = 0.0
		for fatigue in [0.0, 0.8, 1.0]:
			var reachable: int = 0
			var hittable: int = 0
			var speed: float = 0.0
			var error: float = 0.0
			for sample in range(12):
				var parameters: PitchLaunchParameters = PitchExecutionModel.apply(
					base, 0.9, fatigue, pitch.control_difficulty,
					pitch.execution_difficulty, pitch.category, 4100 + sample)
				var crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(parameters, 0)
				speed += parameters.velocity.length()
				if crossing.crossed:
					var xy: Vector2 = Vector2(crossing.point.x, crossing.point.y)
					error += xy.distance_to(Vector2(0.32, 1.05))
					if crossing.point.y >= 0.05:
						reachable += 1
					if absf(xy.x) <= 0.65 and xy.y >= 0.35 and xy.y <= 1.8:
						hittable += 1
			print("PITCH_QUALITY ", pitch.id, " fatigue=", fatigue, " reaches=", reachable,
				" hittable=", hittable, " mean_speed=", speed / 12.0, " mean_error=", error / 12.0)
			_check(reachable == 12, "sampled pitches must reach the plate above ground")
			_check(hittable >= 8, "fatigue must not turn ordinary targets into routine unhittable misses")
			if fatigue == 0.0:
				fresh_speed = speed
				fresh_error = error
			elif fatigue == 0.8:
				_check(speed >= fresh_speed * 0.85, "20% stamina must remain usable")
			else:
				_check(speed < fresh_speed * 0.93, "empty stamina must meaningfully weaken stuff")
				_check(error > fresh_error * 1.1, "fatigue must still reduce command")
	if _failures == 0:
		print("Wiffaltro pitch quality checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
