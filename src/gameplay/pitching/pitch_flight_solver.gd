class_name PitchFlightSolver
extends RefCounted

const SUBSTEP_HZ: float = 240.0
const SUBSTEP_SECONDS: float = 1.0 / SUBSTEP_HZ

static func step(
	state: PitchState,
	parameters: PitchLaunchParameters,
	delta_seconds: float = SUBSTEP_SECONDS
) -> void:
	var acceleration_start: Vector3 = PitchAerodynamics.acceleration(
		state.velocity,
		state.orientation,
		state.angular_velocity,
		parameters
	)

	var midpoint_velocity: Vector3 = (
		state.velocity
		+ acceleration_start * delta_seconds * 0.5
	)
	var midpoint_orientation: Quaternion = PitchAerodynamics.advance_orientation(
		state.orientation,
		state.angular_velocity,
		delta_seconds * 0.5
	)

	var acceleration_midpoint: Vector3 = PitchAerodynamics.acceleration(
		midpoint_velocity,
		midpoint_orientation,
		state.angular_velocity,
		parameters
	)

	state.position += midpoint_velocity * delta_seconds
	state.velocity += acceleration_midpoint * delta_seconds
	state.orientation = PitchAerodynamics.advance_orientation(
		state.orientation,
		state.angular_velocity,
		delta_seconds
	)
	state.elapsed_time += delta_seconds
