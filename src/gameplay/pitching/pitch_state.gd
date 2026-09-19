class_name PitchState
extends RefCounted

var position := Vector3.ZERO
var velocity := Vector3.ZERO
var orientation := Quaternion.IDENTITY
var angular_velocity := Vector3.ZERO
var elapsed_time: float = 0.0
var pitch_id: StringName
@warning_ignore("shadowed_global_identifier")
var seed: int = 0

func copy() -> PitchState:
	var result := PitchState.new()
	result.position = position
	result.velocity = velocity
	result.orientation = orientation
	result.angular_velocity = angular_velocity
	result.elapsed_time = elapsed_time
	result.pitch_id = pitch_id
	result.seed = seed
	return result
