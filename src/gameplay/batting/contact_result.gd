class_name ContactResult
extends RefCounted

enum Outcome {
	MISS,
	FOUL,
	CONTACT,
	PERFECT,
}

enum MissReason {
	NONE,
	EARLY,
	LATE,
	LEFT,
	RIGHT,
	ABOVE,
	BELOW,
}

var outcome: Outcome = Outcome.MISS
var quality: float = 0.0
var contact_position: Vector3 = Vector3.ZERO
var exit_velocity: Vector3 = Vector3.ZERO
var launch_angle_degrees: float = 0.0
var spray_degrees: float = 0.0
var backspin_rad_s: float = 0.0
var horizontal_error_m: float = 0.0
var vertical_error_m: float = 0.0
var timing_error_m: float = 0.0
var spatial_quality: float = 0.0
var timing_quality: float = 0.0
var miss_reason: MissReason = MissReason.NONE

func timing_name() -> String:
	if timing_error_m > 0.025:
		return "EARLY"
	if timing_error_m < -0.025:
		return "LATE"
	return "ON TIME"

func aim_name() -> String:
	if absf(horizontal_error_m) <= 0.025 and absf(vertical_error_m) <= 0.025:
		return "CENTERED"
	var horizontal_name: String = (
		"RIGHT" if horizontal_error_m > 0.025
		else "LEFT" if horizontal_error_m < -0.025
		else ""
	)
	var vertical_name: String = (
		"HIGH" if vertical_error_m > 0.025
		else "LOW" if vertical_error_m < -0.025
		else ""
	)
	return (vertical_name + " " + horizontal_name).strip_edges()

func miss_reason_name() -> String:
	var description: String
	match miss_reason:
		MissReason.EARLY:
			description = "EARLY"
		MissReason.LATE:
			description = "LATE"
		MissReason.LEFT:
			description = "MISSED LEFT"
		MissReason.RIGHT:
			description = "MISSED RIGHT"
		MissReason.ABOVE:
			description = "MISSED HIGH"
		MissReason.BELOW:
			description = "MISSED LOW"
		_:
			description = "MISS"
	return description
