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
var stadium_contacts: Array[Dictionary] = []
var defender_touched: bool = false
var bobbled: bool = false
var caught: bool = false
var dead: bool = false
var catch_position: Vector3 = Vector3.ZERO
var catch_time: float = 0.0
var elapsed_seconds: float = 0.0


func raise_result_floor(new_floor: ResultFloor) -> void:
	if int(new_floor) > int(result_floor):
		result_floor = new_floor


func record_stadium_contact(source: String, id: String, surface: String, role: String,
	position: Vector3, kind: String) -> void:
	stadium_contacts.append({"source": source, "id": id, "surface": surface, "role": role,
		"position": [snappedf(position.x, 0.0001), snappedf(position.y, 0.0001),
			snappedf(position.z, 0.0001)], "time": snappedf(elapsed_seconds, 0.0001), "kind": kind})
