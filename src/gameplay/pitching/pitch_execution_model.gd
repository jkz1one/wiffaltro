class_name PitchExecutionModel
extends RefCounted

const MAX_DIRECTION_ERROR_RADIANS: float = 0.055
const MAX_RELEASE_ERROR_M: float = 0.10
const MAX_VELOCITY_LOSS: float = 0.16
const MAX_SPIN_LOSS: float = 0.32
const MAX_ORIENTATION_ERROR_RADIANS: float = 0.55

static func apply(
	base_parameters: PitchLaunchParameters,
	execution_quality: float,
	fatigue: float,
	difficulty: float,
	seed: int
) -> PitchLaunchParameters:
	var result: PitchLaunchParameters = base_parameters.copy()
	var quality: float = clampf(execution_quality, 0.0, 1.0)
	var fatigue_amount: float = clampf(fatigue, 0.0, 1.0)
	var difficulty_amount: float = clampf(difficulty, 0.0, 2.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var error_strength: float = clampf(
		(1.0 - quality) * (0.85 + difficulty_amount * 0.20)
		+ fatigue_amount * (0.60 + difficulty_amount * 0.15),
		0.0,
		1.5
	)

	var release_error := Vector3(
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

	var velocity_loss: float = clampf(
		fatigue_amount * MAX_VELOCITY_LOSS
		+ (1.0 - quality) * 0.05,
		0.0,
		0.30
	)
	result.velocity = direction * result.velocity.length() * (1.0 - velocity_loss)

	var spin_loss: float = clampf(
		fatigue_amount * MAX_SPIN_LOSS
		+ (1.0 - quality) * 0.12,
		0.0,
		0.55
	)
	result.angular_velocity *= 1.0 - spin_loss

	var orientation_axis := Vector3(
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
