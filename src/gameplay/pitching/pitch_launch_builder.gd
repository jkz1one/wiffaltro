class_name PitchLaunchBuilder
extends RefCounted

static func build_nominal(
	pitch: PitchDefinition,
	ball_setup: BallSetupDefinition,
	mound_origin: Vector3,
	target_position: Vector3,
	is_left_handed: bool,
	seed: int
) -> PitchLaunchParameters:
	if pitch == null:
		push_error("PitchLaunchBuilder: pitch is null.")
		return null

	if pitch.delivery_profile == null:
		push_error("PitchLaunchBuilder: pitch has no delivery profile.")
		return null

	if ball_setup == null or ball_setup.aero_profile == null:
		push_error("PitchLaunchBuilder: ball setup/aero profile is missing.")
		return null

	var parameters := PitchLaunchParameters.new()
	parameters.pitch_id = pitch.id
	parameters.seed = seed

	var release_offset := pitch.delivery_profile.release_offset_pitcher_frame_m
	parameters.position = mound_origin + CoordinateFrame.pitcher_frame_vector(
		release_offset.x,
		release_offset.y,
		release_offset.z,
		is_left_handed
	)

	var launch_direction := (target_position - parameters.position).normalized()
	parameters.velocity = launch_direction * pitch.nominal_velocity_mps

	var spin_axis_source := pitch.nominal_spin_axis_pitcher_frame
	var spin_axis_world := CoordinateFrame.pitcher_frame_vector(
		spin_axis_source.x,
		spin_axis_source.y,
		spin_axis_source.z,
		is_left_handed
	).normalized()
	var spin_radians_per_second := pitch.nominal_spin_rpm * TAU / 60.0
	parameters.angular_velocity = spin_axis_world * spin_radians_per_second

	parameters.orientation = Quaternion.IDENTITY
	parameters.hole_axis_ball_local = pitch.nominal_hole_axis_ball_local.normalized()

	var aero := ball_setup.aero_profile
	parameters.mass_kg = aero.mass_kg
	parameters.radius_m = aero.radius_m
	parameters.drag_coefficient = aero.drag_coefficient * ball_setup.drag_multiplier
	parameters.magnus_scale = aero.magnus_scale * ball_setup.magnus_multiplier
	parameters.perforation_force_scale = (
		aero.perforation_force_scale
		* ball_setup.perforation_multiplier
		* pitch.perforation_influence
	)
	parameters.orientation_stability = (
		aero.orientation_stability
		* ball_setup.stability_multiplier
	)

	return parameters
