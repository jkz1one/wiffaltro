extends Node

var _failures: int = 0
var _cases: int = 0


func _ready() -> void:
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	var player: PlayerDefinition = ContentDB.get_player(&"player.casey_rivers")
	for pitch: PitchDefinition in ContentDB.pitch_by_id.values():
		for effort in [0.82, 1.0, 1.12]:
			var rated: PitchDefinition = MatchLabSupport.rated_pitch(pitch, player, effort)
			for target in [Vector3(0, 1.05, 0), Vector3(0.3, 0.75, 0), Vector3(-0.3, 1.35, 0)]:
				var right: PitchLaunchParameters = PitchAimSolver.solve(
					rated, ball, PitchBatLab.MOUND_ORIGIN, target, false, 41)
				var left: PitchLaunchParameters = PitchAimSolver.solve(
					rated, ball, PitchBatLab.MOUND_ORIGIN, _mirror(target), true, 41)
				_check((right == null) == (left == null), "both hands need equal nominal reach")
				if right == null or left == null:
					continue
				_compare_flight(right, left, String(pitch.id))
				for fatigue in [0.0, 0.8, 1.0]:
					var executed_right: PitchLaunchParameters = PitchExecutionModel.apply(
						right, 0.85, fatigue, pitch.control_difficulty, pitch.execution_difficulty,
						pitch.category, 713)
					var executed_left: PitchLaunchParameters = PitchExecutionModel.apply(
						left, 0.85, fatigue, pitch.control_difficulty, pitch.execution_difficulty,
						pitch.category, 713)
					_compare_flight(executed_right, executed_left, String(pitch.id))
	_test_vertical_identity(ball)
	if _failures == 0:
		print("Wiffaltro pitch handedness checks passed: ", _cases, " paired trajectories.")
	get_tree().quit(0 if _failures == 0 else 1)


func _compare_flight(
	right: PitchLaunchParameters, left: PitchLaunchParameters, name_text: String
) -> void:
	_cases += 1
	_check(left.pitch_id == right.pitch_id, "handedness must retain pitch identity")
	for depth in [8.0, 4.0, 0.0]:
		var r: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(right, depth)
		var l: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(left, depth)
		_check(r.crossed == l.crossed, "both hands must have the same executed reach")
		if not r.crossed and not l.crossed:
			print("BOTH_HANDS_NO_CROSSING ", name_text, " depth=", depth,
				" speed=", right.velocity.length())
		if r.crossed and l.crossed:
			_check(l.point.distance_to(_mirror(r.point)) < 0.002,
				"lateral mirror must preserve vertical flight: " + name_text)
			_check(l.velocity.distance_to(_mirror(r.velocity)) < 0.002,
				"lateral mirror must preserve vertical velocity: " + name_text)


func _test_vertical_identity(ball: BallSetupDefinition) -> void:
	for id in [&"pitch.overhand_four_seam", &"pitch.drop", &"pitch.riser"]:
		var pitch: PitchDefinition = ContentDB.get_pitch(id)
		for left in [false, true]:
			var launch: PitchLaunchParameters = PitchAimSolver.solve(
				pitch, ball, PitchBatLab.MOUND_ORIGIN, Vector3(0, 1.05, 0), left, 41)
			_check(launch != null, "vertical pitch identity fixture must solve")
			if launch == null:
				continue
			var neutral: PitchLaunchParameters = launch.copy()
			neutral.magnus_scale = 0.0
			neutral.perforation_force_scale = 0.0
			neutral.instability_strength = 0.0
			var actual: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(launch, 0)
			var baseline: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(neutral, 0)
			var movement: float = actual.point.y - baseline.point.y
			print("VERTICAL_IDENTITY ", id, " left=", left, " induced_y_m=", movement)
			_check(movement < -0.5 if id == &"pitch.drop" else movement > 0.5,
				"Drop must dive; Four-Seam/Riser retain upward lift for either throwing hand")


static func _mirror(value: Vector3) -> Vector3:
	return Vector3(-value.x, value.y, value.z)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		if _failures <= 12:
			push_error(message)
