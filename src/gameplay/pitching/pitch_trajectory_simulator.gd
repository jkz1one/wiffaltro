class_name PitchTrajectorySimulator
extends RefCounted

static func simulate_to_plane(
	parameters: PitchLaunchParameters,
	plane_z: float,
	max_seconds: float = 3.0
) -> PitchCrossingResult:
	var result := PitchCrossingResult.new()
	var state := PitchState.new()
	state.position = parameters.position
	state.velocity = parameters.velocity
	state.orientation = parameters.orientation
	state.angular_velocity = parameters.angular_velocity
	state.pitch_id = parameters.pitch_id
	state.seed = parameters.seed

	while state.elapsed_time < max_seconds:
		var previous_position: Vector3 = state.position
		var previous_velocity: Vector3 = state.velocity
		var previous_time: float = state.elapsed_time

		PitchFlightSolver.step(state, parameters)

		if previous_position.z > plane_z and state.position.z <= plane_z:
			var denominator: float = previous_position.z - state.position.z
			var fraction: float = 1.0
			if absf(denominator) > 0.000001:
				fraction = clampf(
					(previous_position.z - plane_z) / denominator,
					0.0,
					1.0
				)

			result.crossed = true
			result.point = previous_position.lerp(state.position, fraction)
			result.velocity = previous_velocity.lerp(state.velocity, fraction)
			result.elapsed_seconds = lerpf(previous_time, state.elapsed_time, fraction)
			return result

		if state.position.y < -5.0:
			return result

	return result
