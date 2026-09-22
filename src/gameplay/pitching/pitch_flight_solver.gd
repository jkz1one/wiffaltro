class_name PitchFlightSolver
extends RefCounted

const SUBSTEP_HZ: float = 240.0
const SUBSTEP_SECONDS: float = 1.0 / SUBSTEP_HZ

static func step(
	state: PitchState,
	parameters: PitchLaunchParameters,
	delta_seconds: float = SUBSTEP_SECONDS
) -> void:
	var orientation_spin: Vector3 = (
		state.angular_velocity + _instability_angular_velocity(state, parameters)
	)

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
		orientation_spin,
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
		orientation_spin,
		delta_seconds
	)
	state.elapsed_time += delta_seconds

static func _instability_angular_velocity(
	state: PitchState,
	parameters: PitchLaunchParameters
) -> Vector3:
	if parameters.instability_strength <= 0.0:
		return Vector3.ZERO

	var phase: float = float(abs(parameters.seed) % 997) * 0.01337
	var omega: float = TAU * parameters.instability_frequency_hz
	var t: float = state.elapsed_time

	var wobble: Vector3 = Vector3(
		sin(omega * t + phase),
		cos(omega * 0.73 * t + phase * 1.71),
		sin(omega * 1.19 * t + phase * 0.61)
	) * parameters.instability_strength
	return CoordinateFrame.mirror_spin(wobble) if parameters.is_left_handed else wobble
