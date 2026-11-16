extends Node
## Finite shape acceptance. Public eligibility and human readability are separate.

var _failures: Array[String] = []
var _evidence: Dictionary = {}
var _context: String = "inventory"


func _ready() -> void:
	_check(WorkingPitchCatalog.exotic_recipes().size() == 3, "three unique named Exotic recipes")
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	for recipe: PitchDefinition in WorkingPitchCatalog.exotic_recipes():
		_context = String(recipe.id)
		_check(recipe.rarity == PitchDefinition.Rarity.EXOTIC, "explicit fictional rarity")
		_check(WorkingPitchCatalog.lesson_price(String(recipe.id)) < 0,
			"unqualified achievement route must not become a free public lesson")
		for level: int in [1, 5]:
			_context = "%s level=%d both hands" % [recipe.id, level]
			var pitch: PitchDefinition = WorkingPitchCatalog.mastered(String(recipe.id), level)
			var target: Vector3 = Vector3(0, 1.05, 0)
			var right: PitchLaunchParameters = PitchAimSolver.solve(
				pitch, ball, PitchBatLab.MOUND_ORIGIN, target, false, 41)
			var left: PitchLaunchParameters = PitchAimSolver.solve(
				pitch, ball, PitchBatLab.MOUND_ORIGIN, target, true, 41)
			_check(right != null and left != null, "both hands and mastery reach center")
			if right == null or left == null:
				continue
			_context = "%s level=%d right" % [recipe.id, level]
			var trace: Array[Vector3] = _trace(right)
			_context = "%s level=%d left" % [recipe.id, level]
			var mirror: Array[Vector3] = _trace(left)
			_check(trace.size() == mirror.size(), "mirrored timing")
			for index: int in range(mini(trace.size(), mirror.size())):
				var expected: Vector3 = Vector3(-trace[index].x, trace[index].y, trace[index].z)
				_check(expected.distance_to(mirror[index]) < 0.002, "mirrored full Exotic flight")
			_context = "%s level=%d right shape" % [recipe.id, level]
			_test_shape(recipe, right, trace, level)
	var file: FileAccess = FileAccess.open("user://working_pitch_exotic_native.json", FileAccess.WRITE)
	_check(file != null, "isolated native evidence is writable")
	if file != null:
		file.store_string(JSON.stringify({"catalog": WorkingPitchCatalog.signature(),
			"failures": _failures, "recipes": _evidence,
			"scope": "Finite native shapes; not public purchase or human readability acceptance."}, "\t"))
		file.close()
	if _failures.is_empty():
		print("Working Exotic shape checks passed: three unique recipes, two hands, levels1/5.")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _trace(parameters: PitchLaunchParameters) -> Array[Vector3]:
	var state: PitchState = PitchState.new()
	state.position = parameters.position
	state.velocity = parameters.velocity
	state.orientation = parameters.orientation
	state.angular_velocity = parameters.angular_velocity
	var points: Array[Vector3] = [state.position]
	for _index: int in range(720):
		PitchFlightSolver.step(state, parameters)
		_check(state.velocity.z < 0, "Exotic always travels forward")
		points.append(state.position)
		if state.position.z <= 0:
			break
	_check(points[-1].z <= 0, "Exotic crosses the plate")
	return points


func _test_shape(
	recipe: PitchDefinition, parameters: PitchLaunchParameters,
	trace: Array[Vector3], level: int
) -> void:
	var turn_depths: Array[float] = []
	var minimum: Vector2 = Vector2.INF
	var maximum: Vector2 = -Vector2.INF
	var lateral_min: float = 0.0
	var lateral_max: float = 0.0
	var previous_dx: float = 0.0
	var samples: Array = []
	for index: int in range(trace.size()):
		var point: Vector3 = trace[index]
		var progress: float = (parameters.release_z - point.z) / parameters.release_z
		var chord_x: float = lerpf(trace[0].x, trace[-1].x, progress)
		lateral_min = minf(lateral_min, point.x - chord_x)
		lateral_max = maxf(lateral_max, point.x - chord_x)
		var xy: Vector2 = Vector2(point.x, point.y)
		minimum = minimum.min(xy)
		maximum = maximum.max(xy)
		if index > 0:
			var dx: float = point.x - trace[index - 1].x
			if previous_dx * dx < 0:
				turn_depths.append((parameters.release_z - point.z) / parameters.release_z)
			previous_dx = dx
		if index % 8 == 0 or index == trace.size() - 1:
			samples.append([point.x, point.y, point.z])
	var center: Vector2 = (minimum + maximum) * 0.5
	var last_angle: float = atan2(trace[0].y - center.y, trace[0].x - center.x)
	var angle_sum: float = 0.0
	for point: Vector3 in trace.slice(1):
		var angle: float = atan2(point.y - center.y, point.x - center.x)
		angle_sum += wrapf(angle - last_angle, -PI, PI)
		last_angle = angle
	var winding: float = absf(angle_sum / TAU)
	match recipe.exotic_shape:
		&"switchback":
			_check(turn_depths.size() == 1, "Switchback has exactly one lateral reversal")
			if turn_depths.size() == 1:
				_check(turn_depths[0] > 0.45 and turn_depths[0] < 0.66,
					"Switchback reversal stays in its readable middle window")
		&"corkscrew":
			_check(winding > 0.8 and winding < 1.2, "Corkscrew has one bounded loop")
			_check(lateral_min < -0.25 and lateral_max > 0.25,
				"Corkscrew centerline traverses both sides, unlike an ordinary arc")
			_check(maximum.y < 4.5 and maximum.x - minimum.x < 2.5, "Corkscrew spatial envelope")
			var settled: Vector3 = PitchExoticShape.acceleration(
				parameters.release_z * 0.10, parameters.velocity, parameters)
			_check(settled.length() < 0.00001, "Corkscrew force settles before final approach")
		&"trapdoor":
			var early: Vector3 = PitchExoticShape.acceleration(
				parameters.release_z * 0.45, parameters.velocity, parameters)
			var late: Vector3 = PitchExoticShape.acceleration(
				parameters.release_z * 0.12, parameters.velocity, parameters)
			_check(early == Vector3.ZERO and late.y < -20, "Trapdoor adds a genuinely delayed dive")
			var neutral: PitchLaunchParameters = parameters.copy()
			neutral.exotic_shape = &""
			neutral.exotic_strength = 0.0
			var baseline: Array[Vector3] = _trace(neutral)
			var early_depth: float = parameters.release_z * 0.40
			var early_delta: float = _at_depth(trace, early_depth).y - _at_depth(baseline, early_depth).y
			var final_delta: float = _at_depth(trace, 0).y - _at_depth(baseline, 0).y
			_check(absf(early_delta) < 0.001 and final_delta < -0.5,
				"actual Trapdoor displacement develops late, not only its force schedule")
	_evidence["%s:level%d" % [recipe.id, level]] = {
		"turn_depths": turn_depths, "winding": winding, "apex": maximum.y, "trace": samples
	}


static func _at_depth(trace: Array[Vector3], depth: float) -> Vector3:
	for index: int in range(1, trace.size()):
		if trace[index].z <= depth:
			var before: Vector3 = trace[index - 1]
			var after: Vector3 = trace[index]
			return before.lerp(after, (before.z - depth) / (before.z - after.z))
	return trace[-1]


func _check(condition: bool, message: String) -> void:
	message = _context + ": " + message
	if not condition:
		_failures.append(message)
		if _failures.size() <= 16:
			push_error(message)
