class_name BattedBallAerodynamics
extends RefCounted

const AIR_DENSITY_KG_M3: float = 1.225
const MAX_LIFT_COEFFICIENT: float = 0.32
const BASE_PERFORATION_COEFFICIENT: float = 0.07
const MIN_SPEED_MPS: float = 0.05

static func acceleration(
	velocity: Vector3,
	orientation: Quaternion,
	angular_velocity: Vector3,
	mass_kg: float,
	radius_m: float,
	drag_coefficient: float,
	magnus_scale: float,
	perforation_force_scale: float,
	hole_axis_ball_local: Vector3
) -> Vector3:
	var speed: float = velocity.length()
	if speed <= MIN_SPEED_MPS or mass_kg <= 0.0:
		return Vector3.ZERO

	var velocity_direction: Vector3 = velocity / speed
	var cross_section_area: float = PI * radius_m * radius_m
	var dynamic_acceleration_scale: float = (
		0.5
		* AIR_DENSITY_KG_M3
		* cross_section_area
		* speed
		* speed
		/ mass_kg
	)
	var result: Vector3 = (
		-velocity_direction
		* dynamic_acceleration_scale
		* drag_coefficient
	)

	var spin_speed: float = angular_velocity.length()
	if spin_speed > 0.001:
		var spin_axis: Vector3 = angular_velocity / spin_speed
		var lift_direction: Vector3 = spin_axis.cross(velocity_direction)
		if lift_direction.length_squared() > 0.000001:
			var spin_parameter: float = spin_speed * radius_m / speed
			var lift_coefficient: float = minf(
				MAX_LIFT_COEFFICIENT,
				spin_parameter * magnus_scale
			)
			result += (
				lift_direction.normalized()
				* dynamic_acceleration_scale
				* lift_coefficient
			)

	if perforation_force_scale > 0.0:
		var hole_axis_world: Vector3 = (
			orientation * hole_axis_ball_local.normalized()
		)
		var lateral_hole_axis: Vector3 = (
			hole_axis_world
			- velocity_direction * hole_axis_world.dot(velocity_direction)
		)
		if lateral_hole_axis.length_squared() > 0.000001:
			result += (
				lateral_hole_axis.normalized()
				* dynamic_acceleration_scale
				* BASE_PERFORATION_COEFFICIENT
				* perforation_force_scale
				* lateral_hole_axis.length()
			)
	return result
