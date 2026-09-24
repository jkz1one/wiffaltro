class_name SwingIntent
extends RefCounted

const AIM_MIN_X: float = -0.75
const AIM_MAX_X: float = 0.75
const AIM_MIN_Y: float = 0.30
const AIM_MAX_Y: float = 1.85

var profile_id: StringName
var aim_point: Vector2 = Vector2.ZERO
var handedness_left: bool = false
var start_time_seconds: float = 0.0


static func reachable_aim(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, AIM_MIN_X, AIM_MAX_X), clampf(point.y, AIM_MIN_Y, AIM_MAX_Y))
