class_name PitchAerodynamics
extends RefCounted

const AIR_DENSITY_KG_M3: float = 1.225
const GRAVITY_MPS2 := Vector3(0.0, -9.80665, 0.0)
const MAX_MAGNUS_COEFFICIENT: float = 0.45
const BASE_PERFORATION_COEFFICIENT: float = 0.10
const MIN_SPEED_MPS: float = 0.001

static func acceleration(
	velocity: Vector3,
	orientation: Quaternion,
	angular_velocity: Vector3,
	parameters: PitchLaunchParameters
) -> Vector3:
	var acceleration_total := GRAVITY_MPS2
	var speed := velocity.length()

	if speed <= MIN_SPEED_MPS:
		return acceleration_total

	var velocity_direction := velocity / speed
	var cross_section_area := PI * parameters.radius_m * parameters.radius_m
	var dynamic_acceleration_scale := (
		0.5
		* AIR_DENSITY_KG_M3
		* cross_section_area
		* speed
		* speed
		/ parameters.mass_kg
	)

	acceleration_total += (
		-velocity_direction
		* dynamic_acceleration_scale
		* parameters.drag_coefficient
	)

	var spin_speed := angular_velocity.length()
	if spin_speed > 0.001:
		var spin_axis := angular_velocity / spin_speed
		var lift_direction := spin_axis.cross(velocity_direction)
		if lift_direction.length_squared() > 0.000001:
			var spin_parameter := spin_speed * parameters.radius_m / speed
			var lift_coefficient := min(
				MAX_MAGNUS_COEFFICIENT,
				spin_parameter * parameters.magnus_scale
			)
			acceleration_total += (
				lift_direction.normalized()
				* dynamic_acceleration_scale
				* lift_coefficient
			)

	if parameters.perforation_force_scale > 0.0:
		var local_hole_axis := parameters.hole_axis_ball_local.normalized()
		var hole_axis_world := orientation * local_hole_axis
		var lateral_hole_axis := (
			hole_axis_world
			- velocity_direction * hole_axis_world.dot(velocity_direction)
		)

		if lateral_hole_axis.length_squared() > 0.000001:
			var orientation_strength := lateral_hole_axis.length()
			var perforation_coefficient := (
				BASE_PERFORATION_COEFFICIENT
				* parameters.perforation_force_scale
				* orientation_strength
			)
			acceleration_total += (
				lateral_hole_axis.normalized()
				* dynamic_acceleration_scale
				* perforation_coefficient
			)

	return acceleration_total

static func advance_orientation(
	orientation: Quaternion,
	angular_velocity: Vector3,
	delta_seconds: float
) -> Quaternion:
	var angular_speed := angular_velocity.length()
	if angular_speed <= 0.000001:
		return orientation

	var axis := angular_velocity / angular_speed
	var delta_rotation := Quaternion(axis, angular_speed * delta_seconds)
	return (delta_rotation * orientation).normalized()
