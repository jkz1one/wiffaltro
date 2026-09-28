extends Node

var _failures: int = 0


func _ready() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._player_home = true
	lab._match_state = MatchLabSupport.create_match(lab.DEBUG_PLAYER_ID, "Away", "Home")
	lab._base_state = lab._match_state.bases
	lab._awaiting_batter_confirm = false
	lab._at_bat_cadence.stop()
	lab._apply_defensive_assignment()
	var batter: PlayerDefinition = lab._match_state.batter().definition.duplicate()
	lab._match_state.batter().definition = batter
	var pitcher: PlayerDefinition = lab._match_state.pitcher().definition.duplicate()
	lab._match_state.pitcher().definition = pitcher
	var rows: Array = []
	for rating in [3, 5, 8]:
		batter.contact = rating
		batter.power = 5
		var totals: Dictionary = {"swings": 0, "contact": 0, "timing_miss": 0}
		for pitch_id in [&"pitch.overhand_four_seam", &"pitch.overhand_slider", &"pitch.drop"]:
			pitcher.starting_pitches = [ContentDB.get_pitch(pitch_id)]
			lab._selected_pitch_index = 0
			for x in [-0.34, 0.0, 0.34]:
				for y in [0.67, 1.05, 1.43]:
					var row: Dictionary = {
						"rating": rating,
						"pitch": pitch_id,
						"x": x,
						"y": y,
						"strikes": 0,
						"swings": 0,
						"contact": 0,
						"fair": 0,
						"timing_miss": 0
					}
					for hand in [0, 1]:
						batter.bats = hand
						pitcher.throws = hand
						for sample in range(12):
							_delivery(lab, Vector2(x, y), sample, row)
					for key in totals:
						totals[key] += row[key]
					rows.append(row)
		_check(totals.swings > 200, "in-zone fixture must exercise real swings")
		_check(
			totals.timing_miss > totals.swings * 0.04,
			"in-zone timing errors must survive the production swing window"
		)
		_check(
			totals.contact < totals.swings * 0.88,
			"even strong hitters must leave room for swinging strikes"
		)
	print("AI_ZONE_JSON=", JSON.stringify(rows))
	lab.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro in-zone AI checks passed: 1944 production deliveries.")
	get_tree().quit(0 if _failures == 0 else 1)


func _delivery(lab: PitchBatLab, target: Vector2, sample: int, row: Dictionary) -> void:
	lab._pitch_actor.reset_pitch()
	lab._match_state.top_half = true
	lab._match_state.inning = 1
	lab._match_state.outs = 0
	lab._match_state.away_team.batting_index = 0
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	lab._match_state.between_batters = true
	lab._match_state.balls = 0
	lab._match_state.strikes = 2 if sample % 3 == 0 else 0
	lab._match_state.plate_appearance_number = 1
	var pitcher: PlayerMatchState = lab._match_state.pitcher()
	pitcher.stamina_remaining = pitcher.stamina_max
	lab._throw_number = sample * 23 + 111
	lab._batter_approach.reset(1)
	lab._pitch_target = target
	lab._pitch_effort = 1.0
	lab._pending_release_quality = 1.0
	lab._throw_pitch()
	_check(lab._pitch_actor.running, "zone delivery must launch")
	if not lab._pitch_actor.running:
		return
	# Audit-only ground truth; the AI itself never receives this forecast.
	var crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
		lab._pitch_actor.parameters, 0.0
	)
	var in_zone: bool = (
		crossing.crossed
		and absf(crossing.point.x) <= 0.43
		and crossing.point.y >= 0.55
		and crossing.point.y <= 1.55
	)
	var record: PlayRecord = lab._active_play_record
	for frame in range(360):
		lab._pitch_actor._physics_process(1.0 / 120.0)
		if not lab._pitch_actor.running:
			break
	_check(record != null and record.ai_decision_recorded, "production AI must decide")
	if not in_zone or record == null:
		return
	row.strikes += 1
	row.swings += int(record.ai_swung)
	var result: ContactResult = lab._swing_tracker.result
	if result == null:
		return
	row.contact += int(result.outcome != ContactResult.Outcome.MISS)
	row.fair += int(
		result.outcome in [ContactResult.Outcome.CONTACT, ContactResult.Outcome.PERFECT]
	)
	row.timing_miss += int(
		(
			result.outcome == ContactResult.Outcome.MISS
			and (
				result.miss_reason
				in [ContactResult.MissReason.EARLY, ContactResult.MissReason.LATE]
			)
		)
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
