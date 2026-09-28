class_name PitchLaunchParameters
extends RefCounted

var pitch_id: StringName
var is_left_handed: bool = false
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var orientation: Quaternion = Quaternion.IDENTITY
var angular_velocity: Vector3 = Vector3.ZERO

var mass_kg: float = 0.020
var radius_m: float = 0.0365
var drag_coefficient: float = 0.50
var magnus_scale: float = 1.0
var perforation_force_scale: float = 1.0
var orientation_stability: float = 1.0
var instability_strength: float = 0.0
var instability_frequency_hz: float = 3.0

var mastery_movement_scale: float = 1.0
var mastery_late_bias: float = 0.0
var mastery_noise_scale: float = 1.0
var command_only_quality: bool = false
var gear_command_scale: float = 1.0
var release_z: float = 0.0
var target_z: float = 0.0

var hole_axis_ball_local: Vector3 = Vector3.RIGHT
@warning_ignore("shadowed_global_identifier")
var seed: int = 0

func copy() -> PitchLaunchParameters:
	var result := PitchLaunchParameters.new()
	result.pitch_id = pitch_id
	result.is_left_handed = is_left_handed
	result.position = position
	result.velocity = velocity
	result.orientation = orientation
	result.angular_velocity = angular_velocity
	result.mass_kg = mass_kg
	result.radius_m = radius_m
	result.drag_coefficient = drag_coefficient
	result.magnus_scale = magnus_scale
	result.perforation_force_scale = perforation_force_scale
	result.orientation_stability = orientation_stability
	result.instability_strength = instability_strength
	result.instability_frequency_hz = instability_frequency_hz
	result.mastery_movement_scale = mastery_movement_scale
	result.mastery_late_bias = mastery_late_bias
	result.mastery_noise_scale = mastery_noise_scale
	result.command_only_quality = command_only_quality
	result.gear_command_scale = gear_command_scale
	result.release_z = release_z
	result.target_z = target_z
	result.hole_axis_ball_local = hole_axis_ball_local
	result.seed = seed
	return result
