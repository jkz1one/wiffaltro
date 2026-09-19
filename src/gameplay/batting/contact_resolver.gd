class_name ContactResolver
extends RefCounted

const CONTACT_PLANE_Z: float = 0.28
const MAX_SPRAY_DEGREES: float = 38.0
const BASE_TRANSFER_FACTOR: float = 0.32

static func resolve(
	pitch_state: PitchState,
	intent: SwingIntent,
	profile: SwingProfileDefinition,
	contact_rating: int = 5,
	power_rating: int = 5
) -> ContactResult:
	var result: ContactResult = ContactResult.new()
	result.contact_position = pitch_state.position
	var contact_factor: float = lerpf(
		0.82,
		1.18,
		clampf(float(contact_rating) / 10.0, 0.0, 1.0)
	)
	var power_factor: float = lerpf(
		0.85,
		1.15,
		clampf(float(power_rating) / 10.0, 0.0, 1.0)
	)

	var horizontal_error: float = (
		pitch_state.position.x - intent.aim_point.x
	)
	var vertical_error: float = (
		pitch_state.position.y - intent.aim_point.y
	)
	var depth_error: float = pitch_state.position.z - CONTACT_PLANE_Z

	var nx: float = (
		horizontal_error / (profile.contact_radius_x_m * contact_factor)
	)
	var ny: float = (
		vertical_error / (profile.contact_radius_y_m * contact_factor)
	)
	var nz: float = depth_error / (profile.contact_depth_m * contact_factor)
	var normalized_error_squared: float = nx * nx + ny * ny + nz * nz

	if normalized_error_squared > 1.0:
		result.outcome = ContactResult.Outcome.MISS
		return result

	var quality: float = clampf(
		1.0 - sqrt(normalized_error_squared),
		0.0,
		1.0
	)
	result.quality = quality

	if quality < profile.minimum_contact_quality:
		result.outcome = ContactResult.Outcome.FOUL
	elif quality >= 0.90:
		result.outcome = ContactResult.Outcome.PERFECT
	else:
		result.outcome = ContactResult.Outcome.CONTACT

	var timing_ratio: float = clampf(
		depth_error / profile.contact_depth_m,
		-1.0,
		1.0
	)
	var handedness_sign: float = -1.0 if not intent.handedness_left else 1.0
	result.spray_degrees = (
		timing_ratio
		* MAX_SPRAY_DEGREES
		* handedness_sign
	)

	var vertical_ratio: float = clampf(
		vertical_error / (profile.contact_radius_y_m * contact_factor),
		-1.0,
		1.0
	)
	result.launch_angle_degrees = clampf(
		profile.attack_angle_degrees
		+ vertical_ratio * 32.0,
		-22.0,
		55.0
	)

	var incoming_speed: float = pitch_state.velocity.length()
	var ideal_exit_speed: float = (
		profile.bat_speed_mps
		+ incoming_speed * BASE_TRANSFER_FACTOR
	) * profile.exit_velocity_multiplier * power_factor
	var exit_speed: float = ideal_exit_speed * lerpf(0.35, 1.0, quality)

	var launch_angle_radians: float = deg_to_rad(result.launch_angle_degrees)
	var spray_radians: float = deg_to_rad(result.spray_degrees)
	var horizontal_speed: float = cos(launch_angle_radians) * exit_speed

	var toward_field: Vector3 = Vector3(
		sin(spray_radians) * horizontal_speed,
		sin(launch_angle_radians) * exit_speed,
		cos(spray_radians) * horizontal_speed
	)

	result.exit_velocity = toward_field
	result.backspin_rad_s = maxf(0.0, vertical_ratio) * 110.0 * quality
	return result
