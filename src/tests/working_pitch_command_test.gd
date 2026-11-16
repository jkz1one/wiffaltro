extends Node
## Bounded all-catalog command coverage, not balance or noisy target accuracy.

const SEEDS: Array[int] = [17, 53, 137]
const TARGET: Vector3 = Vector3(0, 1.05, 0)
var _failures: Array[String] = []
var _evidence: Dictionary = {}
var _context: String = "inventory"


func _ready() -> void:
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	var recipes: Array[PitchDefinition] = WorkingPitchCatalog.recipes()
	_check(recipes.size() == 41, "all 41 actual recipes")
	for authored: PitchDefinition in recipes:
		for level: int in [1, 5]:
			var recipe: PitchDefinition = WorkingPitchCatalog.mastered(String(authored.id), level)
			for left: bool in [false, true]:
				_test_command(recipe, ball, level, left)
			_test_ai(recipe, level)
	_context = "evidence"
	var file: FileAccess = FileAccess.open(
		"user://working_pitch_command_native.json", FileAccess.WRITE)
	_check(file != null, "isolated evidence writable")
	if file != null:
		file.store_string(JSON.stringify({"catalog": WorkingPitchCatalog.signature(),
			"failures": _failures, "cases": _evidence, "seeds": SEEDS,
			"scope": "41 recipes, both hands, levels 1/5, center nominal target; "
				+ "quality 0.85/fatigue 0.3. No noisy target accuracy or visual claim."}, "\t"))
		file.close()
	if _failures.is_empty():
		print("Working pitch command checks passed: 164 command cases, 492 noisy flights.")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_command(
	recipe: PitchDefinition, ball: BallSetupDefinition, level: int, left: bool
) -> void:
	var key: String = "%s level=%d left=%s" % [recipe.id, level, left]
	_context = key
	var nominal: PitchLaunchParameters = PitchAimSolver.solve(
		recipe, ball, PitchBatLab.MOUND_ORIGIN, TARGET, left, 41)
	_check(nominal != null, "nominal control target solves")
	if nominal == null:
		_evidence[key] = {"nominal_solved": false}
		return
	var samples: Array = []
	for seed_value: int in SEEDS:
		_context = key + " seed=%d" % seed_value
		var executed: PitchLaunchParameters = PitchExecutionModel.apply(nominal, 0.85, 0.3,
			recipe.control_difficulty, recipe.execution_difficulty, recipe.category, seed_value)
		_check(executed.pitch_id == recipe.id, "execution retains recipe identity")
		_test_finite_forward(executed)
		var crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(executed, 0)
		_check(crossing.crossed, "bounded noisy flight crosses plate plane")
		_check(crossing.point.is_finite() and crossing.velocity.is_finite(), "finite crossing")
		samples.append({"seed": seed_value, "crossed": crossing.crossed,
			"point": [crossing.point.x, crossing.point.y, crossing.point.z],
			"arrival": crossing.elapsed_seconds})
	_context = key
	_check(samples[0].point != samples[1].point or samples[1].point != samples[2].point,
		"seeded execution spread is nonzero")
	_evidence[key] = {"nominal_solved": true, "samples": samples}


func _test_finite_forward(parameters: PitchLaunchParameters) -> void:
	var state: PitchState = PitchState.new()
	state.position = parameters.position
	state.velocity = parameters.velocity
	state.orientation = parameters.orientation
	state.angular_velocity = parameters.angular_velocity
	state.pitch_id = parameters.pitch_id
	state.seed = parameters.seed
	for step: int in range(720):
		PitchFlightSolver.step(state, parameters)
		if not state.position.is_finite() or not state.velocity.is_finite():
			_check(false, "nonfinite trajectory at substep %d" % step)
			return
		if state.velocity.z >= 0:
			_check(false, "nonforward trajectory at substep %d" % step)
			return
		if state.position.z <= 0:
			return
		if state.position.y < -5:
			break
	_check(false, "no plane crossing within 720 bounded substeps")


func _test_ai(recipe: PitchDefinition, level: int) -> void:
	_context = "%s level=%d AI singleton arsenal" % [recipe.id, level]
	var options: Array[PitchDefinition] = [recipe]
	var pitcher: PlayerDefinition = ContentDB.get_player(&"player.casey_rivers")
	for seed_value: int in SEEDS:
		var choice: Dictionary = PitchingStrategy.choose(
			options, pitcher, 1, 2, 0, seed_value, 0.7, false)
		_check(choice.pitch_index == 0, "AI can select exact recipe seed=%d" % seed_value)


func _check(condition: bool, message: String) -> void:
	if not condition:
		message = _context + ": " + message
		_failures.append(message)
		if _failures.size() <= 24:
			push_error(message)
