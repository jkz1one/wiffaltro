class_name SwingContactTracker
extends RefCounted

var active: bool = false
var intent: SwingIntent
var profile: SwingProfileDefinition
var contact_rating: int = 5
var power_rating: int = 5
var result: ContactResult

func begin(
	new_intent: SwingIntent,
	new_profile: SwingProfileDefinition,
	new_contact_rating: int,
	new_power_rating: int
) -> void:
	intent = new_intent
	if intent != null:
		intent.aim_point = SwingIntent.reachable_aim(intent.aim_point)
	profile = new_profile
	contact_rating = new_contact_rating
	power_rating = new_power_rating
	result = null
	active = intent != null and profile != null

func reset() -> void:
	active = false
	intent = null
	profile = null
	result = null

func sample_segment(
	previous_position: Vector3,
	previous_pitch_time: float,
	pitch_state: PitchState
) -> ContactResult:
	if not active or pitch_state == null:
		return null
	var sampled: ContactResult = ContactResolver.resolve_swept_segment(
		previous_position,
		previous_pitch_time,
		pitch_state,
		intent,
		profile,
		contact_rating,
		power_rating
	)
	if sampled != null:
		result = sampled
		active = false
		return result

	var swing_elapsed: float = (
		pitch_state.elapsed_time - intent.start_time_seconds
	)
	if swing_elapsed >= profile.contact_window_end_seconds:
		result = ContactResolver.timing_miss(
			pitch_state,
			intent,
			profile,
			contact_rating
		)
		active = false
		return result
	return null

func force_miss(pitch_state: PitchState) -> ContactResult:
	if result != null:
		return result
	if pitch_state == null or intent == null or profile == null:
		return null
	result = ContactResolver.timing_miss(
		pitch_state,
		intent,
		profile,
		contact_rating
	)
	active = false
	return result
