class_name BallPlayOutcome
extends RefCounted

enum Result {
	OUT,
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
	match result:
		Result.OUT:
			return "OUT"
		Result.SINGLE:
			return "SINGLE"
		Result.DOUBLE:
			return "DOUBLE"
		Result.TRIPLE:
			return "TRIPLE"
		Result.HOME_RUN:
			return "HOME RUN"
		_:
			return "UNKNOWN"
