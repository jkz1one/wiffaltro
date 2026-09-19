class_name PitchLaunchParameters
extends RefCounted

var pitch_id: StringName
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var orientation := Quaternion.IDENTITY
var angular_velocity := Vector3.ZERO

var mass_kg: float = 0.020
var radius_m: float = 0.0365
var drag_coefficient: float = 0.50
var magnus_scale: float = 1.0
var perforation_force_scale: float = 1.0
var orientation_stability: float = 1.0
var hole_axis_ball_local := Vector3.RIGHT
var seed: int = 0
