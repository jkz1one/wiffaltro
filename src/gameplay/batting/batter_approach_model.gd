class_name BatterApproachModel
extends RefCounted

const ZONE_HALF_WIDTH_M: float = 0.43
const ZONE_CENTER_Y_M: float = 1.05
const ZONE_HALF_HEIGHT_M: float = 0.50
const MAX_AWARENESS: float = 0.82

var plate_appearance_number: int = -1
var previous_pitch_id: StringName = &""
var previous_target: Vector2 = Vector2.ZERO
var previous_location_bucket: int = -1
var same_pitch_streak: int = 0
var same_location_streak: int = 0
var pitch_seen_counts: Dictionary = {}


func reset(next_plate_appearance_number: int) -> void:
	plate_appearance_number = next_plate_appearance_number
	previous_pitch_id = &""
	previous_target = Vector2.ZERO
	previous_location_bucket = -1
	same_pitch_streak = 0
	same_location_streak = 0
	pitch_seen_counts.clear()


func awareness_for(pitch: PitchDefinition, target: Vector2) -> float:
	if pitch == null:
		return 0.0
	var awareness: float = 0.0
	var seen_count: int = int(pitch_seen_counts.get(pitch.id, 0))
	awareness += minf(0.30, float(seen_count) * 0.10)
	if pitch.id == previous_pitch_id:
		awareness += 0.14 + minf(0.18, float(same_pitch_streak) * 0.06)
	var bucket: int = _location_bucket(target)
	if bucket == previous_location_bucket:
		awareness += 0.10 + minf(0.12, float(same_location_streak) * 0.04)
	if previous_location_bucket >= 0 and target.distance_to(previous_target) <= 0.20:
		awareness += 0.16
	return clampf(awareness, 0.0, MAX_AWARENESS)


func trigger_z(
	pitch: PitchDefinition,
	plate_speed_mps: float,
	target: Vector2,
	contact_rating: int = 5,
	decision_seed: int = 0
) -> float:
	var awareness: float = awareness_for(pitch, target)
	var speed_pressure: float = clampf(inverse_lerp(12.0, 32.0, plate_speed_mps), 0.0, 1.0)
	var contact_skill: float = clampf(float(contact_rating) / 10.0, 0.0, 1.0)
	var timing_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	timing_rng.seed = decision_seed
	var timing_sigma_seconds: float = lerpf(0.024, 0.010, contact_skill)
	timing_sigma_seconds += pow(speed_pressure, 1.55) * 0.018
	timing_sigma_seconds += maxf(0.0, pitch.timing_difficulty - 1.0) * 0.006
	timing_sigma_seconds *= lerpf(1.0, 0.72, awareness)
	var timing_read_error: float = clampf(
		timing_rng.randfn(0.0, timing_sigma_seconds), -0.052, 0.052
	)
	var swing_lead_seconds: float = lerpf(0.125, 0.115, speed_pressure)
	swing_lead_seconds += awareness * 0.018
	swing_lead_seconds -= (pitch.recognition_difficulty - 1.0) * 0.012
	swing_lead_seconds -= (pitch.timing_difficulty - 1.0) * 0.008
	swing_lead_seconds += timing_read_error
	swing_lead_seconds = clampf(swing_lead_seconds, 0.085, 0.15)
	var depth: float = plate_speed_mps * swing_lead_seconds
	return ContactResolver.CONTACT_PLANE_Z + clampf(depth, 0.85, 4.8)


func decide(
	pitch: PitchDefinition,
	ball_xy: Vector2,
	target: Vector2,
	batter: PlayerDefinition,
	balls: int,
	strikes: int,
	plate_speed_mps: float,
	decision_seed: int
) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = decision_seed
	var awareness: float = awareness_for(pitch, target)
	var body_side: float = 1.0 if batter.bats == PlayerDefinition.Handedness.LEFT else -1.0
	var inside_amount: float = ball_xy.x * body_side
	var outside_distance: float = maxf(0.0, absf(ball_xy.x) - ZONE_HALF_WIDTH_M)
	var vertical_distance: float = maxf(0.0, absf(ball_xy.y - ZONE_CENTER_Y_M) - ZONE_HALF_HEIGHT_M)
	var chase_distance: float = Vector2(outside_distance, vertical_distance).length()
	var in_zone: bool = chase_distance <= 0.0001
	var center_score: float = clampf(
		1.0 - Vector2(ball_xy.x / 0.52, (ball_xy.y - ZONE_CENTER_Y_M) / 0.58).length(), 0.0, 1.0
	)
	var outside_sweet_spot: float = clampf(1.0 - absf(inside_amount + 0.14) / 0.38, 0.0, 1.0)
	var inside_penalty: float = (
		clampf(inverse_lerp(0.05, ZONE_HALF_WIDTH_M, inside_amount), 0.0, 1.0) * 0.14
	)
	var recognition_load: float = maxf(0.0, pitch.recognition_difficulty - awareness * 0.90)
	var speed_load: float = clampf(inverse_lerp(14.0, 31.0, plate_speed_mps), 0.0, 1.0)
	var speed_challenge: float = pow(speed_load, 1.45)

	var swing_chance: float
	if in_zone:
		swing_chance = 0.66 + center_score * 0.16 + outside_sweet_spot * 0.07
		swing_chance -= inside_penalty
		swing_chance += awareness * 0.15
	else:
		# Borderline balls invite a real chase; obvious waste pitches remain
		# easy takes. Recognition and two-strike protection increase temptation.
		swing_chance = (0.34 + recognition_load * 0.045) * exp(-chase_distance * 5.5)
		if strikes >= 2:
			swing_chance += 0.18 * exp(-chase_distance * 4.0)
	if balls >= 3 and strikes < 2:
		swing_chance *= 0.58
	if strikes >= 2 and in_zone:
		swing_chance += 0.12
	swing_chance = clampf(swing_chance, 0.015, 0.96)

	var contact_skill: float = clampf(float(batter.contact) / 10.0, 0.0, 1.0)
	var aim_sigma: float = lerpf(0.245, 0.105, contact_skill)
	aim_sigma += 0.012
	aim_sigma += recognition_load * 0.050
	aim_sigma += speed_challenge * pitch.timing_difficulty * 0.075
	aim_sigma += chase_distance * 0.22
	aim_sigma += inside_penalty * 0.22
	aim_sigma -= awareness * 0.070
	aim_sigma -= center_score * pitch.mistake_punish * 0.035
	aim_sigma = clampf(aim_sigma, 0.055, 0.32)

	var swing: bool = rng.randf() <= swing_chance
	var aim: Vector2 = ball_xy + Vector2(rng.randfn(0.0, aim_sigma), rng.randfn(0.0, aim_sigma))
	var punish_score: float = clampf(
		center_score * pitch.mistake_punish + awareness * 0.75, 0.0, 1.5
	)
	var power_chance: float = clampf(
		0.12 + float(batter.power - batter.contact) * 0.045 + punish_score * 0.34, 0.05, 0.78
	)
	return {
		"swing": swing,
		"aim": aim,
		"use_power": rng.randf() < power_chance,
		"awareness": awareness,
		"swing_chance": swing_chance,
		"aim_sigma": aim_sigma,
		"location_read": _location_read(inside_amount, chase_distance),
	}


func observe(pitch: PitchDefinition, target: Vector2) -> void:
	if pitch == null:
		return
	var bucket: int = _location_bucket(target)
	if pitch.id == previous_pitch_id:
		same_pitch_streak += 1
	else:
		same_pitch_streak = 0
	if bucket == previous_location_bucket:
		same_location_streak += 1
	else:
		same_location_streak = 0
	pitch_seen_counts[pitch.id] = int(pitch_seen_counts.get(pitch.id, 0)) + 1
	previous_pitch_id = pitch.id
	previous_target = target
	previous_location_bucket = bucket


static func _location_bucket(target: Vector2) -> int:
	var column: int = 0 if target.x < -0.18 else (2 if target.x > 0.18 else 1)
	var row: int = 0 if target.y < 0.83 else (2 if target.y > 1.27 else 1)
	return row * 3 + column


static func _location_read(inside_amount: float, chase_distance: float) -> String:
	if chase_distance > 0.22:
		return "CHASE"
	if inside_amount > 0.16:
		return "INSIDE"
	if inside_amount < -0.16:
		return "OUTSIDE"
	return "MIDDLE"
