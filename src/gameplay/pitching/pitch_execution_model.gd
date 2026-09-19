class_name PitchExecutionModel
extends RefCounted

const MAX_DIRECTION_ERROR_RADIANS: float = 0.115
const MAX_RELEASE_ERROR_M: float = 0.16
const MAX_ORIENTATION_ERROR_RADIANS: float = 0.55
const EXECUTION_DIRECTION_SIGMA_RADIANS: float = 0.018
const FATIGUE_DIRECTION_SIGMA_RADIANS: float = 0.034
const LAPSE_DIRECTION_SIGMA_RADIANS: float = 0.020
const EXECUTION_RELEASE_SIGMA_M: float = 0.035
const FATIGUE_RELEASE_SIGMA_M: float = 0.045
const LAPSE_RELEASE_SIGMA_M: float = 0.030
const BASE_LAPSE_CHANCE: float = 0.08
const DIFFICULTY_LAPSE_CHANCE: float = 0.10
const BREAKING_LAPSE_BONUS: float = 0.18
const REACH_COMPENSATION_ITERATIONS: int = 5
const REACH_TOLERANCE_M: float = 0.015
const MAX_REACH_ADJUSTMENT_RADIANS: float = 0.075
const MAX_CENTER_PULL: float = 0.88
const MIN_PLATE_REACH_Y_M: float = -0.20
const COMMAND_CENTER: Vector2 = Vector2(0.0, 1.05)

static func fatigue_pressure(fatigue: float) -> float:
	var amount: float = clampf(fatigue, 0.0, 1.0)
	if amount <= 0.35:
		return 0.0
	if amount <= 0.50:
		var early: float = inverse_lerp(0.35, 0.50, amount)
		return 0.025 * early * early
	if amount <= 0.92:
		var working: float = inverse_lerp(0.50, 0.92, amount)
		return lerpf(0.025, 0.60, pow(working, 1.75))
	var danger: float = inverse_lerp(0.92, 1.0, amount)
	return lerpf(0.60, 1.0, pow(danger, 0.85))

static func crisis_pressure(fatigue: float) -> float:
	var amount: float = clampf(fatigue, 0.0, 1.0)
	if amount <= 0.75:
		return 0.0
	return pow(inverse_lerp(0.75, 1.0, amount), 1.70)

static func fatigue_stage_name(fatigue: float) -> String:
	var amount: float = clampf(fatigue, 0.0, 1.0)
	if amount < 0.50:
		return "FRESH"
	if amount < 0.75:
		return "WORKING"
	if amount < 0.92:
		return "TIRED"
	if amount < 1.0:
		return "DANGER"
	return "BATTING PRACTICE"

static func apply(
	base_parameters: PitchLaunchParameters,
	execution_quality: float,
	fatigue: float,
	control_difficulty: float,
	execution_difficulty: float,
	pitch_category: int,
	seed: int,
	plate_z: float = 0.0
) -> PitchLaunchParameters:
	var result: PitchLaunchParameters = base_parameters.copy()
	var quality: float = clampf(execution_quality, 0.0, 1.0)
	var fatigue_amount: float = clampf(fatigue, 0.0, 1.0)
	var pressure: float = fatigue_pressure(fatigue_amount)
	var crisis: float = crisis_pressure(fatigue_amount)
	var control_amount: float = clampf(control_difficulty, 0.0, 2.0)
	var execution_amount: float = clampf(execution_difficulty, 0.0, 2.0)
	var is_breaking: bool = pitch_category == PitchDefinition.Category.BREAKING

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed

	# Heavy tails belong to the danger band. Below 50% fatigue, the small
	# pressure value is deliberately too weak to dominate normal execution.
	var lapse_chance: float = crisis * (
		BASE_LAPSE_CHANCE
		+ DIFFICULTY_LAPSE_CHANCE * execution_amount
		+ (BREAKING_LAPSE_BONUS if is_breaking else 0.0)
	)
	var lapse_strength: float = 0.0
	if rng.randf() < lapse_chance:
		lapse_strength = rng.randf_range(0.25, 0.70) * crisis

	var velocity_pressure: float = clampf(
		pressure * rng.randf_range(0.82, 1.18) + lapse_strength * 0.22,
		0.0,
		1.15
	)
	var spin_pressure: float = clampf(
		pressure * rng.randf_range(0.72, 1.28) + lapse_strength * 0.70,
		0.0,
		1.20
	)
	var perforation_pressure: float = clampf(
		pressure * rng.randf_range(0.68, 1.32) + lapse_strength * 0.72,
		0.0,
		1.25
	)
	var instability_pressure: float = clampf(
		pressure * rng.randf_range(0.78, 1.22) + lapse_strength * 0.45,
		0.0,
		1.20
	)

	# Faster Pitches shed substantially more velocity. Slower Pitches remain
	# recognizable but lose their movement authority and location instead.
	var speed_factor: float = clampf(
		inverse_lerp(15.0, 29.0, base_parameters.velocity.length()),
		0.0,
		1.0
	)
	var velocity_loss_ceiling: float = lerpf(0.10, 0.28, speed_factor)
	var velocity_loss: float = clampf(
		velocity_pressure * velocity_loss_ceiling
		+ (1.0 - quality) * 0.025,
		0.0,
		0.34
	)
	result.velocity *= 1.0 - velocity_loss

	# Preserve vertical reach after the velocity loss, without correcting the
	# movement loss or command error that makes a tired Pitch hittable.
	_compensate_vertical_reach(base_parameters, result, plate_z)

	var spin_loss_ceiling: float = 0.82 if is_breaking else 0.58
	var spin_loss: float = clampf(
		spin_pressure * spin_loss_ceiling + (1.0 - quality) * 0.08,
		0.0,
		0.90
	)
	result.angular_velocity *= 1.0 - spin_loss
	var perforation_loss: float = clampf(
		perforation_pressure * 0.68,
		0.0,
		0.88
	)
	result.perforation_force_scale *= 1.0 - perforation_loss
	var instability_loss: float = clampf(
		instability_pressure * 0.55,
		0.0,
		0.72
	)
	result.instability_strength *= 1.0 - instability_loss

	var control_scale: float = 0.75 + control_amount * 0.35
	var release_sigma_m: float = (
		(1.0 - quality) * EXECUTION_RELEASE_SIGMA_M
		+ pressure * FATIGUE_RELEASE_SIGMA_M * control_scale
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
		+ pressure * FATIGUE_DIRECTION_SIGMA_RADIANS * control_scale
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
			(1.0 - quality) + pressure + lapse_strength,
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

	# At high fatigue, command increasingly regresses toward a hittable center.
	# The pull is continuous, seeded, and strongest for edge targets; it is not
	# an on/off replacement of the player's chosen target.
	var center_tendency: float = clampf(
		pressure * 0.14 + crisis * 0.72 + lapse_strength * 0.24,
		0.0,
		MAX_CENTER_PULL
	)
	if center_tendency > 0.01:
		_pull_crossing_toward_center(
			base_parameters,
			result,
			plate_z,
			center_tendency * rng.randf_range(0.82, 1.12)
		)

	# Even an exhausted Pitcher remains capable of delivering a ball to the
	# plate. Preserve ugly dirt misses, but prevent fatigue from burying the ball
	# below the world before it reaches the hitting plane.
	_guarantee_plate_reach(result, plate_z)
	result.seed = seed
	return result

static func _compensate_vertical_reach(
	base_parameters: PitchLaunchParameters,
	degraded_parameters: PitchLaunchParameters,
	plate_z: float
) -> void:
	var nominal_crossing: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(base_parameters, plate_z)
	)
	if not nominal_crossing.crossed:
		return
	_adjust_crossing_toward(
		degraded_parameters,
		Vector2(nominal_crossing.point.x, nominal_crossing.point.y),
		plate_z,
		false
	)

static func _pull_crossing_toward_center(
	base_parameters: PitchLaunchParameters,
	degraded_parameters: PitchLaunchParameters,
	plate_z: float,
	strength: float
) -> void:
	var current: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(degraded_parameters, plate_z)
	)
	var nominal: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(base_parameters, plate_z)
	)
	if not current.crossed or not nominal.crossed:
		return
	var horizontal_edge: float = absf(nominal.point.x - COMMAND_CENTER.x) / 0.43
	var vertical_edge: float = absf(nominal.point.y - COMMAND_CENTER.y) / 0.50
	var edge_factor: float = clampf(maxf(horizontal_edge, vertical_edge), 0.0, 1.0)
	var weighted_strength: float = clampf(
		strength * lerpf(0.45, 1.0, edge_factor),
		0.0,
		MAX_CENTER_PULL
	)
	var desired: Vector2 = Vector2(current.point.x, current.point.y).lerp(
		COMMAND_CENTER,
		weighted_strength
	)
	_adjust_crossing_toward(degraded_parameters, desired, plate_z, true)

static func _guarantee_plate_reach(
	parameters: PitchLaunchParameters,
	plate_z: float
) -> void:
	for _iteration in range(REACH_COMPENSATION_ITERATIONS):
		var crossing: PitchCrossingResult = (
			PitchTrajectorySimulator.simulate_to_plane(parameters, plate_z)
		)
		if crossing.crossed and crossing.point.y >= MIN_PLATE_REACH_Y_M:
			return
		var direction: Vector3 = parameters.velocity.normalized()
		var right_axis: Vector3 = direction.cross(Vector3.UP)
		if right_axis.length_squared() <= 0.000001:
			return
		direction = direction.rotated(
			right_axis.normalized(),
			MAX_REACH_ADJUSTMENT_RADIANS * 0.55
		)
		parameters.velocity = direction * parameters.velocity.length()

static func _adjust_crossing_toward(
	parameters: PitchLaunchParameters,
	target: Vector2,
	plate_z: float,
	adjust_horizontal: bool
) -> void:
	for _iteration in range(REACH_COMPENSATION_ITERATIONS):
		var crossing: PitchCrossingResult = (
			PitchTrajectorySimulator.simulate_to_plane(parameters, plate_z)
		)
		if not crossing.crossed:
			return
		var error: Vector2 = target - Vector2(crossing.point.x, crossing.point.y)
		if (
			absf(error.y) <= REACH_TOLERANCE_M
			and (not adjust_horizontal or absf(error.x) <= REACH_TOLERANCE_M)
		):
			return
		var horizontal_distance: float = Vector2(
			parameters.position.x - crossing.point.x,
			parameters.position.z - crossing.point.z
		).length()
		if horizontal_distance <= 0.001:
			return
		var direction: Vector3 = parameters.velocity.normalized()
		if adjust_horizontal:
			var yaw_adjustment: float = clampf(
				-atan(error.x / horizontal_distance),
				-MAX_REACH_ADJUSTMENT_RADIANS,
				MAX_REACH_ADJUSTMENT_RADIANS
			)
			direction = direction.rotated(Vector3.UP, yaw_adjustment)
		var right_axis: Vector3 = direction.cross(Vector3.UP)
		if right_axis.length_squared() <= 0.000001:
			return
		var pitch_adjustment: float = clampf(
			atan(error.y / horizontal_distance),
			-MAX_REACH_ADJUSTMENT_RADIANS,
			MAX_REACH_ADJUSTMENT_RADIANS
		)
		direction = direction.rotated(right_axis.normalized(), pitch_adjustment)
		parameters.velocity = direction * parameters.velocity.length()
