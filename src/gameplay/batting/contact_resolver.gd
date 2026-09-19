class_name ContactResolver
extends RefCounted

const CONTACT_PLANE_Z: float = 0.28
const MAX_SPRAY_DEGREES: float = 38.0
const BASE_TRANSFER_FACTOR: float = 0.32
const BARREL_DEPTH_RADIUS_M: float = 0.13

static func resolve_swept_segment(
	previous_position: Vector3,
	previous_pitch_time: float,
	pitch_state: PitchState,
	intent: SwingIntent,
	profile: SwingProfileDefinition,
	contact_rating: int = 5,
	power_rating: int = 5
) -> ContactResult:
	var current_pitch_time: float = pitch_state.elapsed_time
	var window_start: float = (
		intent.start_time_seconds + profile.contact_window_start_seconds
	)
	var window_end: float = (
		intent.start_time_seconds + profile.contact_window_end_seconds
	)
	var overlap_start: float = maxf(previous_pitch_time, window_start)
	var overlap_end: float = minf(current_pitch_time, window_end)
	if overlap_end < overlap_start:
		return null

	var segment_seconds: float = maxf(
		0.000001,
		current_pitch_time - previous_pitch_time
	)
	var start_alpha: float = clampf(
		(overlap_start - previous_pitch_time) / segment_seconds,
		0.0,
		1.0
	)
	var end_alpha: float = clampf(
		(overlap_end - previous_pitch_time) / segment_seconds,
		0.0,
		1.0
	)
	var ball_start: Vector3 = previous_position.lerp(
		pitch_state.position,
		start_alpha
	)
	var ball_end: Vector3 = previous_position.lerp(
		pitch_state.position,
		end_alpha
	)
	var swing_start: float = overlap_start - intent.start_time_seconds
	var swing_end: float = overlap_end - intent.start_time_seconds
	var center_start: Vector3 = Vector3(
		intent.aim_point.x,
		intent.aim_point.y,
		_swing_center_z(swing_start, profile)
	)
	var center_end: Vector3 = Vector3(
		intent.aim_point.x,
		intent.aim_point.y,
		_swing_center_z(swing_end, profile)
	)
	# Depth establishes when the ball and moving barrel meet. X/Y error is
	# evaluated at that encounter, so a badly aimed Swing becomes a spatial
	# miss instead of changing the encounter time.
	var relative_start_z: float = (
		ball_start.z - center_start.z
	) / BARREL_DEPTH_RADIUS_M
	var relative_end_z: float = (
		ball_end.z - center_end.z
	) / BARREL_DEPTH_RADIUS_M
	var relative_delta_z: float = relative_end_z - relative_start_z
	var closest_alpha: float = 0.0
	if absf(relative_delta_z) > 0.000001:
		closest_alpha = clampf(
			-relative_start_z / relative_delta_z,
			0.0,
			1.0
		)
	var closest_relative_z: float = lerpf(
		relative_start_z,
		relative_end_z,
		closest_alpha
	)
	if absf(closest_relative_z) > 1.0:
		return null

	var contact_position: Vector3 = ball_start.lerp(
		ball_end,
		closest_alpha
	)
	return _resolve_at_contact(
		pitch_state,
		contact_position,
		intent,
		profile,
		contact_rating,
		power_rating
	)

static func timing_miss(
	pitch_state: PitchState,
	intent: SwingIntent,
	profile: SwingProfileDefinition,
	contact_rating: int = 5
) -> ContactResult:
	var result: ContactResult = ContactResult.new()
	result.contact_position = pitch_state.position
	var contact_factor: float = _contact_factor(contact_rating)
	result.horizontal_error_m = pitch_state.position.x - intent.aim_point.x
	result.vertical_error_m = pitch_state.position.y - intent.aim_point.y
	result.timing_error_m = pitch_state.position.z - CONTACT_PLANE_Z
	var nx: float = result.horizontal_error_m / (
		profile.contact_radius_x_m * contact_factor
	)
	var ny: float = result.vertical_error_m / (
		profile.contact_radius_y_m * contact_factor
	)
	result.spatial_quality = clampf(
		1.0 - sqrt(nx * nx + ny * ny),
		0.0,
		1.0
	)
	result.miss_reason = (
		ContactResult.MissReason.EARLY
		if pitch_state.position.z > CONTACT_PLANE_Z
		else ContactResult.MissReason.LATE
	)
	return result

static func _resolve_at_contact(
	pitch_state: PitchState,
	contact_position: Vector3,
	intent: SwingIntent,
	profile: SwingProfileDefinition,
	contact_rating: int,
	power_rating: int
) -> ContactResult:
	var result: ContactResult = ContactResult.new()
	result.contact_position = contact_position
	var contact_factor: float = _contact_factor(contact_rating)
	var power_factor: float = lerpf(
		0.85,
		1.15,
		clampf(float(power_rating) / 10.0, 0.0, 1.0)
	)

	var horizontal_error: float = (
		contact_position.x - intent.aim_point.x
	)
	var vertical_error: float = (
		contact_position.y - intent.aim_point.y
	)
	var depth_error: float = contact_position.z - CONTACT_PLANE_Z
	result.horizontal_error_m = horizontal_error
	result.vertical_error_m = vertical_error
	result.timing_error_m = depth_error

	var nx: float = (
		horizontal_error / (profile.contact_radius_x_m * contact_factor)
	)
	var ny: float = (
		vertical_error / (profile.contact_radius_y_m * contact_factor)
	)
	var nz: float = depth_error / (profile.contact_depth_m * contact_factor)
	var normalized_error_squared: float = nx * nx + ny * ny + nz * nz
	result.spatial_quality = clampf(
		1.0 - sqrt(nx * nx + ny * ny),
		0.0,
		1.0
	)
	result.timing_quality = clampf(1.0 - absf(nz), 0.0, 1.0)

	if normalized_error_squared > 1.0:
		result.outcome = ContactResult.Outcome.MISS
		result.miss_reason = _primary_miss_reason(nx, ny, nz)
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

static func _swing_center_z(
	swing_elapsed_seconds: float,
	profile: SwingProfileDefinition
) -> float:
	if swing_elapsed_seconds <= profile.sweet_spot_seconds:
		var load_progress: float = clampf(
			inverse_lerp(
				profile.contact_window_start_seconds,
				profile.sweet_spot_seconds,
				swing_elapsed_seconds
			),
			0.0,
			1.0
		)
		return CONTACT_PLANE_Z + lerpf(
			-profile.contact_depth_m * 0.5,
			0.0,
			load_progress
		)
	var finish_progress: float = clampf(
		inverse_lerp(
			profile.sweet_spot_seconds,
			profile.contact_window_end_seconds,
			swing_elapsed_seconds
		),
		0.0,
		1.0
	)
	return CONTACT_PLANE_Z + lerpf(
		0.0,
		profile.contact_depth_m * 0.5,
		finish_progress
	)

static func _contact_factor(contact_rating: int) -> float:
	return lerpf(
		0.82,
		1.18,
		clampf(float(contact_rating) / 10.0, 0.0, 1.0)
	)

static func _primary_miss_reason(
	normalized_x: float,
	normalized_y: float,
	normalized_timing: float
) -> ContactResult.MissReason:
	var timing_amount: float = absf(normalized_timing)
	var horizontal_amount: float = absf(normalized_x)
	var vertical_amount: float = absf(normalized_y)
	if timing_amount >= horizontal_amount and timing_amount >= vertical_amount:
		return (
			ContactResult.MissReason.EARLY
			if normalized_timing > 0.0
			else ContactResult.MissReason.LATE
		)
	if horizontal_amount >= vertical_amount:
		return (
			ContactResult.MissReason.RIGHT
			if normalized_x > 0.0
			else ContactResult.MissReason.LEFT
		)
	return (
		ContactResult.MissReason.ABOVE
		if normalized_y > 0.0
		else ContactResult.MissReason.BELOW
	)
