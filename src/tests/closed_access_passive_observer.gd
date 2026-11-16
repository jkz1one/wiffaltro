extends RefCounted
## Test-only read-only diagnostics. Never changes lab/controller/actor state.
## Not outcome authority, a physical report, or evidence of earned eligibility.
const LIMIT: int = 512
var rows: Array[Dictionary] = []
var roles: Dictionary = {}
var motion: Dictionary = {}
var next_record: int = 0
var truncated: bool = false


func sample(lab: PitchBatLab) -> void:
	if not is_instance_valid(lab):
		return
	var active: PlayRecord = lab._active_play_record
	if active != null:
		var key: String = str(active.play_number)
		if not roles.has(key) and lab._match_state != null and roles.size() < LIMIT:
			roles[key] = {
				"primary": String(lab._match_state.fielder().definition.id),
				"anchor": lab._fielder_anchor_index
			}
		if roles.size() >= LIMIT:
			truncated = true
		if (
			roles.has(key)
			and lab._ball_play_resolver != null
			and lab._ball_play_resolver.state != null
			and is_instance_valid(lab._batted_ball)
			and is_instance_valid(lab._primary_fielder)
			and lab._ball_in_play_is_live()
		):
			if not motion.has(key):
				motion[key] = {
					"air_samples": 0,
					"ground_samples": 0,
					"min_air_distance": 1000000.0,
					"max_air_height": 0.0,
					"bobble_seen": false,
					"primary_attempts_max": 0
				}
			var row: Dictionary = motion[key]
			var play: BallPlayState = lab._ball_play_resolver.state
			var position: Vector3 = lab._batted_ball.global_position
			if play.has_grounded:
				row.ground_samples += 1
			else:
				row.air_samples += 1
				row.min_air_distance = minf(
					row.min_air_distance, lab._primary_fielder.horizontal_distance_to(position)
				)
				row.max_air_height = maxf(row.max_air_height, position.y)
			row.bobble_seen = row.bobble_seen or play.bobbled
			row.primary_attempts_max = maxi(row.primary_attempts_max, lab._primary_attempts)
	while next_record < lab._play_records.size():
		var record: PlayRecord = lab._play_records[next_record]
		next_record += 1
		if rows.size() >= LIMIT:
			truncated = true
			continue
		var key: String = str(record.play_number)
		rows.append(
			{
				"play": record.play_number,
				"inning": record.inning,
				"top_half": record.top_half,
				"batter": String(record.batter_id),
				"pitcher": String(record.pitcher_id),
				"role_observation": roles.get(key, {}).duplicate(true),
				"contact": record.contact_outcome,
				"launch_degrees": record.launch_angle_degrees,
				"exit_speed": record.exit_speed_mps,
				"spray_degrees": record.spray_degrees,
				"grounded": record.has_first_ground,
				"last_touch": String(record.last_defender_touch),
				"result": String(record.result),
				"reason": String(record.resolution_reason),
				"motion_samples": motion.get(key, {}).duplicate(true)
			}
		)
		if rows.size() >= LIMIT:
			truncated = true


func snapshot() -> Dictionary:
	return {
		"version": 1,
		"authority": "passive-test-diagnostics-not-earnings",
		"limit": LIMIT,
		"truncated": truncated,
		"completed_records_seen": next_record,
		"records": rows.duplicate(true)
	}
