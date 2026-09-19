class_name PitchExecutionModel
extends RefCounted

const MAX_DIRECTION_ERROR_RADIANS: float = 0.130
const MAX_RELEASE_ERROR_M: float = 0.18
const MAX_VELOCITY_LOSS: float = 0.28
const MAX_SPIN_LOSS: float = 0.68
const MAX_PERFORATION_LOSS: float = 0.50
const MAX_INSTABILITY_LOSS: float = 0.35
const MAX_ORIENTATION_ERROR_RADIANS: float = 0.55
const FATIGUE_CURVE_EXPONENT: float = 1.10
const EXECUTION_DIRECTION_SIGMA_RADIANS: float = 0.018
const FATIGUE_DIRECTION_SIGMA_RADIANS: float = 0.042
const LAPSE_DIRECTION_SIGMA_RADIANS: float = 0.022
const EXECUTION_RELEASE_SIGMA_M: float = 0.035
const FATIGUE_RELEASE_SIGMA_M: float = 0.055
const LAPSE_RELEASE_SIGMA_M: float = 0.035
const BASE_LAPSE_CHANCE: float = 0.12
const DIFFICULTY_LAPSE_CHANCE: float = 0.12
const BREAKING_LAPSE_BONUS: float = 0.14
const REACH_COMPENSATION_ITERATIONS: int = 4
const REACH_TOLERANCE_M: float = 0.015
const MAX_REACH_ADJUSTMENT_RADIANS: float = 0.09

static func apply(
	base_parameters: PitchLaunchParameters,
	execution_quality: float,
	fatigue: float,
	control_difficulty: float,
	execution_difficulty: float,
	is_breaking_pitch: bool,
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
	var control_amount: float = clampf(control_difficulty, 0.0, 2.0)
	var execution_amount: float = clampf(execution_difficulty, 0.0, 2.0)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed

	# Fatigue changes the distribution of outcomes, not one fixed degradation
	# amount. Independent rolls prevent every part of a Pitch from worsening in
	# lockstep. A lapse is an occasional heavier tail, especially for breaking
	# Pitches, but it never changes the intended target.
	var lapse_chance: float = fatigue_pressure * (
		BASE_LAPSE_CHANCE
		+ DIFFICULTY_LAPSE_CHANCE * execution_amount
		+ (BREAKING_LAPSE_BONUS if is_breaking_pitch else 0.0)
	)
	var lapse_strength: float = 0.0
	if rng.randf() < lapse_chance:
		lapse_strength = (
			rng.randf_range(0.25, 0.65) * fatigue_amount
		)

	var velocity_pressure: float = clampf(
		fatigue_pressure * rng.randf_range(0.70, 1.30)
		+ lapse_strength * 0.35,
		0.0,
		1.30
	)
	var spin_pressure: float = clampf(
		fatigue_pressure * rng.randf_range(0.45, 1.45)
		+ lapse_strength * 0.80,
		0.0,
		1.35
	)
	var perforation_pressure: float = clampf(
		fatigue_pressure * rng.randf_range(0.40, 1.60)
		+ lapse_strength * 0.85,
		0.0,
		1.50
	)
	var instability_pressure: float = clampf(
		fatigue_pressure * rng.randf_range(0.60, 1.40)
		+ lapse_strength * 0.50,
		0.0,
		1.35
	)

	var velocity_loss: float = clampf(
		velocity_pressure * MAX_VELOCITY_LOSS
		+ (1.0 - quality) * 0.05,
		0.0,
		0.38
	)
	result.velocity *= 1.0 - velocity_loss

	# A real pitcher still changes release angle enough to get a tired pitch to
	# the plate. Correct only the extra vertical drop caused by lost speed; do
	# not correct lateral movement or later execution error. Reduced movement
	# can therefore leave a breaking Pitch over the plate instead of forcing it
	# into the dirt.
	_compensate_vertical_reach(base_parameters, result, plate_z)

	var spin_loss: float = clampf(
		spin_pressure * MAX_SPIN_LOSS
		+ (1.0 - quality) * 0.12,
		0.0,
		0.88
	)
	result.angular_velocity *= 1.0 - spin_loss
	var perforation_loss: float = clampf(
		perforation_pressure * MAX_PERFORATION_LOSS,
		0.0,
		0.85
	)
	result.perforation_force_scale *= 1.0 - perforation_loss
	var instability_loss: float = clampf(
		instability_pressure * MAX_INSTABILITY_LOSS,
		0.0,
		0.65
	)
	result.instability_strength *= 1.0 - instability_loss

	var control_scale: float = 0.75 + control_amount * 0.35
	var release_sigma_m: float = (
		(1.0 - quality) * EXECUTION_RELEASE_SIGMA_M
		+ fatigue_amount * FATIGUE_RELEASE_SIGMA_M * control_scale
		+ lapse_strength * LAPSE_RELEASE_SIGMA_M
	)
	var release_error: Vector3 = Vector3(
		rng.randfn(0.0, release_sigma_m),
		rng.randfn(0.0, release_sigma_m),
		rng.randfn(0.0, release_sigma_m * 0.25)
	)
	if release_error.length() > MAX_RELEASE_ERROR_M:
		release_error = release_error.normalized() * MAX_RELEASE_ERROR_M
	result.position += release_error

	var direction_sigma: float = (
		(1.0 - quality) * EXECUTION_DIRECTION_SIGMA_RADIANS
		+ fatigue_amount * FATIGUE_DIRECTION_SIGMA_RADIANS * control_scale
		+ lapse_strength * LAPSE_DIRECTION_SIGMA_RADIANS
	)
	var yaw_error: float = clampf(
		rng.randfn(0.0, direction_sigma),
		-MAX_DIRECTION_ERROR_RADIANS,
		MAX_DIRECTION_ERROR_RADIANS
	)
	var pitch_error: float = clampf(
		rng.randfn(0.0, direction_sigma),
		-MAX_DIRECTION_ERROR_RADIANS,
		MAX_DIRECTION_ERROR_RADIANS
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
		var orientation_strength: float = clampf(
			(1.0 - quality) + fatigue_pressure + lapse_strength,
			0.0,
			1.5
		)
		var orientation_angle: float = (
			rng.randf_range(-1.0, 1.0)
			* MAX_ORIENTATION_ERROR_RADIANS
			* orientation_strength
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
