class_name BallPlayOutcome
extends RefCounted

enum Result {
	OUT,
	FOUL,
	SINGLE,
	DOUBLE,
	TRIPLE,
	HOME_RUN,
}

var result: Result = Result.OUT
var reason: StringName = &""
var caught: bool = false
var resolution_position: Vector3 = Vector3.ZERO


func display_name() -> String:
	var label: String = "UNKNOWN"
	match result:
		Result.OUT:
			label = "OUT"
		Result.FOUL:
			label = "FOUL"
		Result.SINGLE:
			label = "SINGLE"
		Result.DOUBLE:
			label = "DOUBLE"
		Result.TRIPLE:
			label = "TRIPLE"
		Result.HOME_RUN:
			label = "HOME RUN"
	return label
