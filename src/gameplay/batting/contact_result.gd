class_name ContactResult
extends RefCounted

enum Outcome {
	MISS,
	FOUL,
	CONTACT,
	PERFECT,
}

var outcome: Outcome = Outcome.MISS
var quality: float = 0.0
var contact_position: Vector3 = Vector3.ZERO
var exit_velocity: Vector3 = Vector3.ZERO
var launch_angle_degrees: float = 0.0
var spray_degrees: float = 0.0
var backspin_rad_s: float = 0.0
