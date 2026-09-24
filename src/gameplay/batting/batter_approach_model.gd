class_name BatterApproachModel
extends RefCounted

const ZONE_HALF_WIDTH_M: float = 0.43
const ZONE_CENTER_Y_M: float = 1.05
const ZONE_HALF_HEIGHT_M: float = 0.50
const MAX_AWARENESS: float = 0.50

var plate_appearance_number: int = -1
var previous_pitch_id: StringName = &""
var previous_target: Vector2 = Vector2.ZERO
var previous_location_bucket: int = -1
var same_pitch_streak: int = 0
var same_location_streak: int = 0
var pitch_seen_counts: Dictionary = {}
var recent_locations: Array[int] = []
var previous_speed: float = 0.0
var _plan: Dictionary = {}
var _read_history: Array[Dictionary] = []
var _delivery_seed: int = -1
var _delivered: bool = false
var _last_velocity: Vector3 = Vector3.ZERO
var _last_sample_time: float = -1.0
var _read_acceleration: Vector3 = Vector3(0, -9.81, 0)


func reset(next_plate_appearance_number: int) -> void:
	plate_appearance_number = next_plate_appearance_number
	previous_pitch_id = &""
	previous_target = Vector2.ZERO
	previous_location_bucket = -1
	same_pitch_streak = 0
	same_location_streak = 0
	pitch_seen_counts.clear()
	recent_locations.clear()
	previous_speed = 0.0
	reset_pitch()


func begin_plate_appearance(next_number: int) -> void:
	# The lineup can notice a repeated location; individual timing familiarity
	# still resets. Only the last eight visible deliveries inform this read.
	var scouting: Array[int] = recent_locations.duplicate()
	var speed: float = previous_speed
	reset(next_number)
	recent_locations = scouting
	previous_speed = speed


func awareness_for(pitch: PitchDefinition, target: Vector2) -> float:
	if pitch == null:
		return 0.0
	var awareness: float = 0.0
	var seen_count: int = int(pitch_seen_counts.get(pitch.id, 0))
	awareness += minf(0.12, float(seen_count) * 0.025)
	if pitch.id == previous_pitch_id:
		awareness += 0.05 + minf(0.08, float(same_pitch_streak) * 0.02)
	var bucket: int = _location_bucket(target)
	if bucket == previous_location_bucket:
		awareness += 0.04 + minf(0.06, float(same_location_streak) * 0.015)
	if previous_location_bucket >= 0 and target.distance_to(previous_target) <= 0.20:
		awareness += 0.05
	awareness += minf(0.12, float(recent_locations.count(bucket)) * 0.015)
	return clampf(awareness, 0.0, MAX_AWARENESS)


func reset_pitch() -> void:
	_plan.clear()
	_read_history.clear()
	_delivery_seed = -1
	_delivered = false
	_last_sample_time = -1.0
	_read_acceleration = Vector3(0, -9.81, 0)


func trigger_z(
	_pitch: PitchDefinition,
	plate_speed_mps: float,
	_target: Vector2,
	contact_rating: int = 5,
	_decision_seed: int = 0
) -> float:
	# Begin a timing plan before starting the bat. Better hitters can read longer.
	var lead: float = lerpf(0.27, 0.22, clampf(contact_rating / 10.0, 0.0, 1.0))
	return ContactResolver.CONTACT_PLANE_Z + plate_speed_mps * lead


func track_pitch(
	pitch: PitchDefinition,
	state: PitchState,
	batter: PlayerDefinition,
	balls: int,
	strikes: int,
	decision_seed: int,
	batting_hand: int,
	contact_profile: SwingProfileDefinition,
	power_profile: SwingProfileDefinition
) -> Dictionary:
	if _delivery_seed != decision_seed:
		reset_pitch()
		_delivery_seed = decision_seed
	if _delivered:
		return {}
	if _last_sample_time >= 0.0 and state.elapsed_time > _last_sample_time:
		var dt: float = state.elapsed_time - _last_sample_time
		var observed: Vector3 = ((state.velocity - _last_velocity) / dt).limit_length(60.0)
		_read_acceleration = _read_acceleration.lerp(observed, 1.0 - exp(-18.0 * dt))
	_last_velocity = state.velocity
	_last_sample_time = state.elapsed_time
	var read: Vector2 = read_plate_location(state.position, state.velocity, _read_acceleration)
	_read_history.append({"time": state.elapsed_time, "read": read})
	# Corrections use a delayed visual estimate; no hidden target/solver forecast.
	while _read_history.size() > 1 and _read_history[1].time <= state.elapsed_time - 0.065:
		_read_history.pop_front()
	if _plan.is_empty():
		if state.position.z > trigger_z(pitch, -state.velocity.z, read, batter.contact):
			return {}
		_plan = plan_swing(
			pitch,
			state.position,
			state.velocity,
			batter,
			balls,
			strikes,
			decision_seed,
			batting_hand,
			state.elapsed_time
		)
		var profile: SwingProfileDefinition = power_profile if _plan.use_power else contact_profile
		_plan.start_time = _plan.contact_time - profile.sweet_spot_seconds
	if _plan.swing and state.elapsed_time < _plan.start_time:
		var correction: Vector2 = (_read_history[0].read - _plan.plate_read).limit_length(0.09)
		_plan.aim = _plan.initial_aim + correction * lerpf(0.35, 0.75, batter.contact / 10.0)
		return {}
	_delivered = true
	observe(pitch, read)
	previous_speed = float(_plan.read_speed)
	return _plan.duplicate()


func plan_swing(
	pitch: PitchDefinition,
	position: Vector3,
	velocity: Vector3,
	batter: PlayerDefinition,
	balls: int,
	strikes: int,
	decision_seed: int,
	batting_hand: int,
	elapsed: float
) -> Dictionary:
	var read: Vector2 = read_plate_location(position, velocity, _read_acceleration)
	var decision: Dictionary = decide(
		pitch, read, read, batter, balls, strikes, velocity.length(), decision_seed, batting_hand
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = decision_seed ^ 0x5A17
	var skill: float = clampf(batter.contact / 10.0, 0.0, 1.0)
	var speed: float = maxf(1.0, -velocity.z)
	var remaining: float = _time_to_plate(position, velocity, _read_acceleration)
	var sigma: float = lerpf(0.024, 0.012, skill)
	sigma += maxf(0.0, pitch.timing_difficulty - 1.0) * 0.008
	sigma += smoothstep(18.0, 32.0, speed) * 0.008
	sigma *= 1.0 - float(decision.awareness) * 0.25
	# A speed change disrupts the previous delivery's rhythm without dictating an outcome.
	var rhythm_error: float = 0.0
	if previous_speed > 0.0:
		rhythm_error = clampf((speed - previous_speed) / previous_speed, -0.5, 0.5) * 0.045
	decision.contact_time = elapsed + remaining + rng.randfn(0.0, sigma) + rhythm_error
	decision.read_speed = speed
	decision.plate_read = read
	decision.initial_aim = decision.aim
	decision.timing_sigma = sigma
	return decision


func decide(
	pitch: PitchDefinition,
	ball_xy: Vector2,
	target: Vector2,
	batter: PlayerDefinition,
	balls: int,
	strikes: int,
	plate_speed_mps: float,
	decision_seed: int,
	batting_hand: int = -1
) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = decision_seed ^ 0x29B3
	var awareness: float = awareness_for(pitch, target)
	var hand: int = batter.bats if batting_hand < 0 else batting_hand
	var body_side: float = -1.0 if hand == PlayerDefinition.Handedness.LEFT else 1.0
	var inside_amount: float = ball_xy.x * body_side
	var outside_distance: float = maxf(0.0, absf(ball_xy.x) - ZONE_HALF_WIDTH_M)
	var vertical_distance: float = maxf(0.0, absf(ball_xy.y - ZONE_CENTER_Y_M) - ZONE_HALF_HEIGHT_M)
	var chase_distance: float = Vector2(outside_distance, vertical_distance).length()
	var in_zone: bool = chase_distance <= 0.0001
	var center_score: float = clampf(
		1.0 - Vector2(ball_xy.x / 0.52, (ball_xy.y - ZONE_CENTER_Y_M) / 0.58).length(), 0.0, 1.0
	)
	var recognition_load: float = maxf(0.0, pitch.recognition_difficulty - awareness * 0.40)
	var speed_load: float = clampf(inverse_lerp(14.0, 31.0, plate_speed_mps), 0.0, 1.0)
	var speed_challenge: float = pow(speed_load, 1.45)

	var swing_chance: float
	if in_zone:
		swing_chance = 0.70 + center_score * 0.16
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
	aim_sigma *= 1.0 - awareness * 0.10
	aim_sigma -= center_score * pitch.mistake_punish * 0.035
	aim_sigma = clampf(aim_sigma, 0.11, 0.36)

	var swing: bool = rng.randf() <= swing_chance
	var aim_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	aim_rng.seed = decision_seed ^ 0x731D
	var aim: Vector2 = (
		ball_xy + Vector2(aim_rng.randfn(0.0, aim_sigma), aim_rng.randfn(0.0, aim_sigma))
	)
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
	recent_locations.append(bucket)
	if recent_locations.size() > 8:
		recent_locations.pop_front()
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


static func read_plate_location(
	position: Vector3, velocity: Vector3, acceleration: Vector3 = Vector3(0, -9.81, 0)
) -> Vector2:
	# Estimate from visible motion. Acceleration is measured from past samples,
	# never read from the pitch's authored movement or future solver state.
	var remaining: float = _time_to_plate(position, velocity, acceleration)
	var estimate: Vector3 = (
		position + velocity * remaining + 0.5 * acceleration * remaining * remaining
	)
	return Vector2(estimate.x, estimate.y)


static func _time_to_plate(position: Vector3, velocity: Vector3, acceleration: Vector3) -> float:
	var speed: float = maxf(1.0, -velocity.z)
	var remaining: float = maxf(0.0, (position.z - ContactResolver.CONTACT_PLANE_Z) / speed)
	return clampf(remaining + 0.5 * acceleration.z * remaining * remaining / speed, 0.0, 0.32)


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
