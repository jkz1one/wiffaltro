extends Node
## Numerical trajectory checks only, not measured-real-world tuning or human balance acceptance.
var failures: int = 0
var evidence: Dictionary = {}

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	for id: String in ["pitch.submarine_two_seam", "pitch.submarine_curveball"]:
		for level: int in [1, 5]:
			var recipe: PitchDefinition = ExpandedSeasonCatalog.mastered(id, level)
			check(recipe != null and recipe.delivery_profile.id == &"delivery.submarine", "exact low Submarine delivery")
			if recipe == null:
				continue
			var right: PitchLaunchParameters = PitchAimSolver.solve(recipe, ball, PitchBatLab.MOUND_ORIGIN, Vector3(0, 1.05, 0), false, 41)
			var left: PitchLaunchParameters = PitchAimSolver.solve(recipe, ball, PitchBatLab.MOUND_ORIGIN, Vector3(0, 1.05, 0), true, 41)
			check(right != null and left != null, "both hands solve center " + id)
			if right == null or left == null:
				continue
			var trace: Array[Vector3] = _trace(right)
			var mirror: Array[Vector3] = _trace(left)
			check(trace.size() == mirror.size(), "hand mirroring preserves flight time")
			for index in range(mini(trace.size(), mirror.size())):
				check(Vector3(-trace[index].x, trace[index].y, trace[index].z).distance_to(mirror[index]) < 0.002, "full-flight mirrored trajectory")
			var arrival: Vector3 = _at_depth(trace, 0.0)
			check(Vector2(arrival.x, arrival.y).distance_to(Vector2(0, 1.05)) < 0.12, "center plate arrival " + id)
			var adjacent_id: String = "pitch.sidearm_sinker" if id.ends_with("two_seam") else "pitch.submarine_slide_drop"
			var adjacent: PitchDefinition = ExpandedSeasonCatalog.mastered(adjacent_id, level)
			# Control for release geometry when comparing family movement. This is a
			# detached test resource, never a new recipe or a production offering.
			adjacent.delivery_profile = recipe.delivery_profile.duplicate(true) as DeliveryProfileDefinition
			var control: PitchLaunchParameters = PitchAimSolver.solve(adjacent, ball, PitchBatLab.MOUND_ORIGIN, Vector3(0, 1.05, 0), false, 41)
			check(control != null, "adjacent family solves center")
			if control == null:
				continue
			var control_trace: Array[Vector3] = _trace(control)
			var separation: float = 0.0
			for depth: float in [3.0, 6.0, 9.0, 12.0]:
				separation = maxf(separation, _at_depth(trace, depth).distance_to(_at_depth(control_trace, depth)))
			check(separation > 0.01, "family has a distinct actual flight, not only an ID " + id)
			var samples: Array = []
			for point: Vector3 in trace:
				samples.append([point.x, point.y, point.z])
			evidence["%s:%d" % [id, level]] = {"trace": samples, "arrival": [arrival.x, arrival.y, arrival.z], "adjacent": adjacent_id, "max_sample_separation": separation, "ticks": trace.size()}
	var file: FileAccess = FileAccess.open("user://expanded-pitch-trajectories.json", FileAccess.WRITE)
	check(file != null, "trajectory evidence writable in isolated user root")
	if file != null:
		file.store_string(JSON.stringify({"catalog": ExpandedSeasonCatalog.signature(), "failures": failures, "scope": "Numerical sanity and distinctness only; visual tuning and balance remain provisional.", "recipes": evidence}, "\t"))
		file.close()
	print("Expanded trajectory failures: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _trace(parameters: PitchLaunchParameters) -> Array[Vector3]:
	var state: PitchState = PitchState.new()
	state.position = parameters.position
	state.velocity = parameters.velocity
	state.orientation = parameters.orientation
	state.angular_velocity = parameters.angular_velocity
	var points: Array[Vector3] = [state.position]
	for _tick in range(720):
		PitchFlightSolver.step(state, parameters)
		check(state.position.is_finite() and state.velocity.is_finite() and state.velocity.z < 0, "finite forward flight")
		points.append(state.position)
		if state.position.z <= 0:
			break
	check(points[-1].z <= 0, "trajectory crosses plate")
	return points

static func _at_depth(trace: Array[Vector3], depth: float) -> Vector3:
	for index in range(1, trace.size()):
		if trace[index].z <= depth:
			var before: Vector3 = trace[index - 1]
			var after: Vector3 = trace[index]
			return before.lerp(after, (before.z - depth) / (before.z - after.z))
	return trace[-1]
