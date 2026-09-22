extends Node

var _failures: int = 0


func _ready() -> void:
	PitchBatLabSettings.path = "user://chase-settings-%d.cfg" % OS.get_process_id()
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
	# Controlled counts and fresh arms isolate the production trajectory/read/
	# decision/swing path. These are not complete plate appearances or human data.
	for hand in [PlayerDefinition.Handedness.RIGHT, PlayerDefinition.Handedness.LEFT]:
		batter.bats = hand
		var direction: float = -1.0 if hand == PlayerDefinition.Handedness.RIGHT else 1.0
		var totals: Array[int] = []
		for count in [Vector2i(0, 0), Vector2i(0, 2), Vector2i(3, 0)]:
			for distance in [0.50, 0.65, 0.95]:
				var swings: int = 0
				var chance: float = 0.0
				var read_x: float = 0.0
				for sample in range(40):
					lab._pitch_actor.reset_pitch()
					lab._match_state.phase = MatchState.Phase.PRE_PITCH
					lab._match_state.between_batters = true
					lab._match_state.balls = count.x
					lab._match_state.strikes = count.y
					lab._match_state.plate_appearance_number = 1 + floori(float(sample) / 4.0)
					var pitcher: PlayerMatchState = lab._match_state.pitcher()
					pitcher.stamina_remaining = pitcher.stamina_max
					lab._throw_number = sample
					if sample % 4 == 0:
						lab._batter_approach.reset(lab._match_state.plate_appearance_number)
					lab._pitch_target = Vector2(direction * distance, 1.05)
					lab._pending_release_quality = 1.0
					lab._throw_pitch()
					_check(lab._pitch_actor.running, "outside pitch must actually launch")
					for frame in range(240):
						lab._pitch_actor._physics_process(1.0 / 120.0)
						MatchLabSupport.try_ai_swing(lab)
						if lab._ai_swing_decided or not lab._pitch_actor.running:
							break
					var record: PlayRecord = lab._active_play_record
					_check(record != null and record.ai_decision_recorded,
						"every outside delivery must reach a live AI decision")
					if record == null or not record.ai_decision_recorded:
						continue
					_check(lab._swing_consumed == record.ai_swung,
						"a recorded chase must start an actual swing; a take must not")
					swings += int(record.ai_swung)
					chance += record.ai_swing_chance
					read_x += absf(record.ai_plate_read.x)
				totals.append(swings)
				print("LIVE CHASE hand=", hand, " count=", count, " aim_x=", distance,
					" swung=", swings, "/40 mean_chance=", snappedf(chance / 40, 0.001),
					" mean_abs_read_x=", snappedf(read_x / 40, 0.001))
		_check(totals[0] > 0 and totals[0] > totals[2],
			"borderline outside deliveries must provoke more real swings than waste pitches")
		_check(totals[3] > totals[0] and totals[6] < totals[0],
			"two-strike protection and three-ball patience must reach live swing selection")
	lab.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(PitchBatLabSettings.path)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro live chase checks passed: 720 production launches and decisions.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
