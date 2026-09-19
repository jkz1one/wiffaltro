class_name PitchReleaseController
extends RefCounted

const IDEAL_RELEASE_SECONDS: float = 0.72
const AUTO_RELEASE_SECONDS: float = 1.24
const MIN_GOOD_WINDOW_SECONDS: float = 0.105
const MAX_GOOD_WINDOW_SECONDS: float = 0.205

var active: bool = false
var elapsed_seconds: float = 0.0
var last_quality: float = 1.0
var last_offset_seconds: float = 0.0

func begin() -> void:
	active = true
	elapsed_seconds = 0.0

func cancel() -> void:
	active = false
	elapsed_seconds = 0.0

func advance(delta_seconds: float) -> bool:
	if not active:
		return false
	elapsed_seconds += maxf(0.0, delta_seconds)
	return elapsed_seconds >= AUTO_RELEASE_SECONDS

func release(control_rating: int, fatigue: float) -> float:
	last_offset_seconds = elapsed_seconds - IDEAL_RELEASE_SECONDS
	last_quality = quality_at(
		elapsed_seconds,
		control_rating,
		fatigue
	)
	active = false
	return last_quality

func preview_quality(control_rating: int, fatigue: float) -> float:
	return quality_at(elapsed_seconds, control_rating, fatigue)

func meter_progress() -> float:
	return clampf(elapsed_seconds / AUTO_RELEASE_SECONDS, 0.0, 1.0)

func ideal_progress() -> float:
	return IDEAL_RELEASE_SECONDS / AUTO_RELEASE_SECONDS

static func quality_at(
	release_seconds: float,
	control_rating: int,
	fatigue: float
) -> float:
	var control: float = clampf(float(control_rating) / 10.0, 0.0, 1.0)
	var fatigue_pressure: float = PitchExecutionModel.fatigue_pressure(fatigue)
	var good_window: float = lerpf(
		MIN_GOOD_WINDOW_SECONDS,
		MAX_GOOD_WINDOW_SECONDS,
		control
	) * lerpf(1.0, 0.80, fatigue_pressure)
	var offset: float = absf(release_seconds - IDEAL_RELEASE_SECONDS)
	var normalized_offset: float = offset / maxf(0.001, good_window)
	return clampf(exp(-0.5 * normalized_offset * normalized_offset), 0.0, 1.0)

static func grade_name(quality: float) -> String:
	if quality >= 0.92:
		return "PERFECT"
	if quality >= 0.72:
		return "GOOD"
	if quality >= 0.45:
		return "OK"
	return "MISSED"

func release_description() -> String:
	var grade: String = grade_name(last_quality)
	if grade == "PERFECT" or grade == "GOOD":
		return grade
	if last_offset_seconds < -0.015:
		return "EARLY"
	if last_offset_seconds > 0.015:
		return "LATE"
	return grade
