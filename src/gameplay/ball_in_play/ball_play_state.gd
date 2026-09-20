class_name BallPlayState
extends RefCounted

enum ResultFloor {
	NONE,
	SINGLE,
	DOUBLE,
	TRIPLE,
	HOME_RUN,
}

var is_fair: bool = true
var is_foul_play: bool = false
var has_grounded: bool = false
var first_ground_position: Vector3 = Vector3.ZERO
var result_floor: ResultFloor = ResultFloor.NONE
var last_defender_touch: StringName = &""
var last_obstacle_contact: StringName = &""
var defender_touched: bool = false
var caught: bool = false
var dead: bool = false
var catch_position: Vector3 = Vector3.ZERO
var catch_time: float = 0.0
var elapsed_seconds: float = 0.0


func raise_result_floor(new_floor: ResultFloor) -> void:
	if int(new_floor) > int(result_floor):
		result_floor = new_floor
