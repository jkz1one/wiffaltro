class_name PitchExecutionModel
extends RefCounted

const MAX_DIRECTION_ERROR_RADIANS: float = 0.060
const MAX_RELEASE_ERROR_M: float = 0.10
const MAX_VELOCITY_LOSS: float = 0.28
const MAX_SPIN_LOSS: float = 0.68
const MAX_PERFORATION_LOSS: float = 0.50
const MAX_INSTABILITY_LOSS: float = 0.35
const MAX_ORIENTATION_ERROR_RADIANS: float = 0.55
const FATIGUE_CURVE_EXPONENT: float = 1.35
const REACH_COMPENSATION_ITERATIONS: int = 4
const REACH_TOLERANCE_M: float = 0.015
const MAX_REACH_ADJUSTMENT_RADIANS: float = 0.09

static func apply(
	base_parameters: PitchLaunchParameters,
	execution_quality: float,
	fatigue: float,
	difficulty: float,
	seed: int,
	plate_z: float = 0.0
) -> PitchLaunchParameters:
	var result: PitchLaunchParameters = base_parameters.copy()
	var quality: float = clampf(execution_quality, 0.0, 1.0)
	var fatigue_amount: float = clampf(fatigue, 0.0, 1.0)
	var fatigue_pressure: float = pow(
		fatigue_amount,
		FATIGUE_CURVE_EXPONENT
	)
	var difficulty_amount: float = clampf(difficulty, 0.0, 2.0)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed

	var error_strength: float = clampf(
		(1.0 - quality) * (0.85 + difficulty_amount * 0.20)
		+ fatigue_pressure * (0.75 + difficulty_amount * 0.20),
		0.0,
		1.5
	)

	var velocity_loss: float = clampf(
		fatigue_pressure * MAX_VELOCITY_LOSS
		+ (1.0 - quality) * 0.05,
		0.0,
		0.35
	)
	result.velocity *= 1.0 - velocity_loss

	# A real pitcher still changes release angle enough to get a tired pitch to
	# the plate. Correct only the extra vertical drop caused by lost speed; do
	# not correct lateral movement or later execution error. Reduced movement
	# can therefore leave a breaking Pitch over the plate instead of forcing it
	# into the dirt.
	_compensate_vertical_reach(base_parameters, result, plate_z)

	var spin_loss: float = clampf(
		fatigue_pressure * MAX_SPIN_LOSS
		+ (1.0 - quality) * 0.12,
		0.0,
		0.75
	)
	result.angular_velocity *= 1.0 - spin_loss
	result.perforation_force_scale *= 1.0 - (
		fatigue_pressure * MAX_PERFORATION_LOSS
	)
	result.instability_strength *= 1.0 - (
		fatigue_pressure * MAX_INSTABILITY_LOSS
	)

	var release_error: Vector3 = Vector3(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-0.25, 0.25)
	) * MAX_RELEASE_ERROR_M * error_strength
	result.position += release_error

	var yaw_error: float = (
		rng.randf_range(-1.0, 1.0)
		* MAX_DIRECTION_ERROR_RADIANS
		* error_strength
	)
	var pitch_error: float = (
		rng.randf_range(-1.0, 1.0)
		* MAX_DIRECTION_ERROR_RADIANS
		* error_strength
	)

	var direction: Vector3 = result.velocity.normalized()
	direction = direction.rotated(Vector3.UP, yaw_error)
	var right_axis: Vector3 = direction.cross(Vector3.UP).normalized()
	if right_axis.length_squared() > 0.000001:
		direction = direction.rotated(right_axis, pitch_error)

	result.velocity = direction * result.velocity.length()

	var orientation_axis: Vector3 = Vector3(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0)
	)
	if orientation_axis.length_squared() > 0.000001:
		orientation_axis = orientation_axis.normalized()
		var orientation_angle: float = (
			rng.randf_range(-1.0, 1.0)
			* MAX_ORIENTATION_ERROR_RADIANS
			* error_strength
		)
		result.orientation = (
			Quaternion(orientation_axis, orientation_angle)
			* result.orientation
		).normalized()

	result.seed = seed
	return result

static func _compensate_vertical_reach(
	base_parameters: PitchLaunchParameters,
	degraded_parameters: PitchLaunchParameters,
	plate_z: float
) -> void:
	var nominal_crossing: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(
			base_parameters,
			plate_z
		)
	)
	if not nominal_crossing.crossed:
		return

	var target_y: float = nominal_crossing.point.y
	for _iteration in range(REACH_COMPENSATION_ITERATIONS):
		var crossing: PitchCrossingResult = (
			PitchTrajectorySimulator.simulate_to_plane(
				degraded_parameters,
				plate_z
			)
		)
		if not crossing.crossed:
			return

		var vertical_error: float = target_y - crossing.point.y
		if absf(vertical_error) <= REACH_TOLERANCE_M:
			return

		var direction: Vector3 = degraded_parameters.velocity.normalized()
		var right_axis: Vector3 = direction.cross(Vector3.UP)
		if right_axis.length_squared() <= 0.000001:
			return

		var horizontal_distance: float = Vector2(
			degraded_parameters.position.x - crossing.point.x,
			degraded_parameters.position.z - crossing.point.z
		).length()
		if horizontal_distance <= 0.001:
			return

		var angle_adjustment: float = clampf(
			atan(vertical_error / horizontal_distance),
			-MAX_REACH_ADJUSTMENT_RADIANS,
			MAX_REACH_ADJUSTMENT_RADIANS
		)
		direction = direction.rotated(
			right_axis.normalized(),
			angle_adjustment
		)
		degraded_parameters.velocity = (
			direction * degraded_parameters.velocity.length()
		)
