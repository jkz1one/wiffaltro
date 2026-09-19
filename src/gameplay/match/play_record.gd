class_name PlayRecord
extends RefCounted

var play_number: int = 0
var inning: int = 0
var top_half: bool = true
var balls_before: int = 0
var strikes_before: int = 0
var outs_before: int = 0
var batter_id: StringName = &""
var pitcher_id: StringName = &""
var pitch_id: StringName = &""
var intended_target: Vector2 = Vector2.ZERO
var effort: float = 1.0
var fatigue: float = 0.0
var execution_quality: float = 1.0
var release_offset_seconds: float = 0.0
var seed: int = 0
var crossed_plate: bool = false
var crossing_point: Vector2 = Vector2.ZERO
var plate_speed_mps: float = 0.0
var swing_profile_id: StringName = &""
var swing_aim: Vector2 = Vector2.ZERO
var contact_outcome: int = -1
var contact_quality: float = 0.0
var timing_error_m: float = 0.0
var horizontal_error_m: float = 0.0
var vertical_error_m: float = 0.0
var result: StringName = &"pending"
var runs_scored: int = 0

func to_dict() -> Dictionary:
	return {
		"play_number": play_number,
		"inning": inning,
		"top_half": top_half,
		"count_before": [balls_before, strikes_before, outs_before],
		"batter_id": String(batter_id),
		"pitcher_id": String(pitcher_id),
		"pitch_id": String(pitch_id),
		"intended_target": [intended_target.x, intended_target.y],
		"effort": effort,
		"fatigue": fatigue,
		"execution_quality": execution_quality,
		"release_offset_seconds": release_offset_seconds,
		"seed": seed,
		"crossed_plate": crossed_plate,
		"crossing_point": [crossing_point.x, crossing_point.y],
		"plate_speed_mps": plate_speed_mps,
		"swing_profile_id": String(swing_profile_id),
		"swing_aim": [swing_aim.x, swing_aim.y],
		"contact_outcome": contact_outcome,
		"contact_quality": contact_quality,
		"timing_error_m": timing_error_m,
		"horizontal_error_m": horizontal_error_m,
		"vertical_error_m": vertical_error_m,
		"result": String(result),
		"runs_scored": runs_scored,
	}
