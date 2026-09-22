extends Node

var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PitchBatLabSettings.path = "user://polish-settings-%d.cfg" % OS.get_process_id()
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab._record_export.path = "user://polish-records-%d.json" % OS.get_process_id()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	await _test_audio_and_settings(lab)
	await _test_feedback(lab)
	await _test_visibility_and_fielding(lab)
	await _test_result_holds(lab)
	_test_rolling_result(lab)
	var record_path: String = lab._record_export.path
	lab.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(record_path)
	DirAccess.remove_absolute(PitchBatLabSettings.path)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro presentation polish checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _test_audio_and_settings(lab: PitchBatLab) -> void:
	var hashes: Array[int] = []
	for cue in PlaySounds.CUES:
		var player: AudioStreamPlayer = lab._sounds._players[cue]
		var stream: AudioStreamWAV = player.stream as AudioStreamWAV
		_check(stream.get_length() > 0.08 and stream.get_length() < 1.0,
			"cues must be short and nonempty")
		var data: PackedByteArray = stream.data
		var peak: int = 0
		for offset in range(0, data.size(), 2):
			peak = maxi(peak, absi(data.decode_s16(offset)))
		_check(peak > 1000 and peak < 32767, "cue must have signal without clipping")
		_check(not hashes.has(hash(data)), "each cue must have a distinct waveform")
		hashes.append(hash(data))
		lab._sounds.play(cue)
		_check(player.playing, "unmuted cue must reach its audio player")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	lab._toggle_display_menu()
	lab._pause_menu._mute_button.pressed.emit()
	_check(lab._sounds_muted and lab._sounds.muted, "settings must mute all game sounds")
	for player: AudioStreamPlayer in lab._sounds._players.values():
		_check(not player.playing, "mute must stop existing sounds even during pause")
	lab._sounds_muted = false
	lab._sounds.set_muted(false)
	PitchBatLabSettings.restore(lab)
	_check(lab._sounds_muted and lab._sounds.muted, "mute must survive settings reload")
	await _frames(2)
	_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(lab._pause_menu.get_global_rect()),
		"expanded settings must fit the viewport")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	lab._sounds.play(&"contact")
	_check(lab._sounds.last_cue == &"", "muted events must not queue for later playback")
	lab._pause_menu._toggle_mute()
	_check(lab._sounds.last_cue == &"", "unmute must not replay discarded cues")


func _test_feedback(lab: PitchBatLab) -> void:
	# Different consecutive handedness catches feedback accidentally reading the next Batter.
	var team: TeamMatchState = lab._match_state.batting_team()
	var original: PlayerDefinition = team.current_batter().definition
	team.current_batter().definition = original.duplicate()
	team.current_batter().definition.bats = PlayerDefinition.Handedness.RIGHT
	_check(PitchFeedback.plate_message(lab, Vector3(0.6, 1.0, 0)) == "TOOK INSIDE",
		"inside/outside must match actual right-handed stance")
	team.current_batter().definition.bats = PlayerDefinition.Handedness.LEFT
	_check(PitchFeedback.plate_message(lab, Vector3(0.6, 1.0, 0)) == "TOOK OUTSIDE",
		"inside/outside must mirror for left-handed stance")
	team.current_batter().definition = original
	lab._swing_consumed = true
	lab._pending_swing_miss = ContactResult.new()
	lab._pending_swing_miss.miss_reason = ContactResult.MissReason.EARLY
	_check(PitchFeedback.plate_message(lab, Vector3(0, 0.3, 0)) == "CHASED LOW • EARLY",
		"chase feedback must include actual miss reason")
	lab._swing_consumed = false
	lab._pitch_feedback.show_note("TOOK OUTSIDE")
	for anchor in range(3):
		lab._hud_anchor_index = anchor
		PitchBatLabPresentation.apply_hud_anchor(lab)
		lab._pitch_feedback.advance(lab, 0.0)
		await _frames(2)
		var bounds: Rect2 = lab._pitch_feedback.get_global_rect()
		_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(bounds),
			"feedback must fit every scorebox anchor")
		_check(not bounds.intersects(lab._scorebug.get_global_rect()),
			"feedback must clear the scorebox")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	var remaining: float = lab._pitch_feedback.remaining
	await _frames(10)
	_check(lab._pitch_feedback.remaining == remaining, "pause must preserve feedback time")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	lab._pitch_feedback.advance(lab, 4.0)
	_check(not lab._pitch_feedback.visible, "feedback must expire")
	for id in lab.PITCH_IDS:
		_check(not ContentDB.get_pitch(id).tactical_description.is_empty(),
			"each authored pitch must have a tactical tooltip")
	# Largest authored repertoire with each scorebox anchor.
	lab._match_state.top_half = false
	lab._fatigue = 0.96
	var pitcher: PlayerMatchState = lab._match_state.pitcher()
	var original_pitcher: PlayerDefinition = pitcher.definition
	pitcher.definition = original_pitcher.duplicate()
	pitcher.definition.starting_pitches = []
	for id in lab.PITCH_IDS:
		pitcher.definition.starting_pitches.append(ContentDB.get_pitch(id))
	for anchor in range(3):
		lab._hud_anchor_index = anchor
		PitchBatLabPresentation.apply_hud_anchor(lab)
		lab._refresh_config()
		lab._pitch_feedback.show_note("CHASED LOW • MISSED HIGH")
		lab._pitch_feedback.advance(lab, 0.0)
		await _frames(2)
		var bounds: Rect2 = lab._pitch_picker.get_global_rect()
		_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(bounds),
			"nine pitches must fit every anchor")
		_check(not bounds.intersects(lab._pitch_feedback.get_global_rect()),
			"pitch panel must clear the feedback strip")
		_check(not lab._pitching_staff_toggle_button.get_global_rect().intersects(
			lab._pitch_feedback.get_global_rect()), "Bullpen must clear feedback")
		_check(not bounds.intersects(lab._controls_label.get_global_rect()),
			"expanded pitch panel must clear the footer")
	pitcher.definition = original_pitcher
	for fatigue in [0.0, 0.75, 0.82, 0.83, 0.92, 1.0]:
		lab._fatigue = fatigue
		lab._pitch_picker.refresh()
		var color: Color = lab._pitch_picker._stamina_fill.bg_color
		_check((color.r > color.g) == (fatigue >= 0.83),
			"stamina bar turns red only at 17% remaining or less")
	lab._fatigue = 0.0


func _test_visibility_and_fielding(lab: PitchBatLab) -> void:
	lab._match_mode = false
	lab._at_bat_cadence.stop()
	lab.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(3, 2, 6)
	launch.velocity = Vector3(0, 2, 18)
	lab._start_ball_in_play(launch)
	await _frames(3)
	var aids: BallVisibility = lab._ball_visibility
	_check(aids.visible and aids._shadow.visible, "airborne batted ball needs ground reference")
	_check(aids._mesh.get_surface_count() == 1, "fast batted ball needs a short historical trail")
	for point in aids._history:
		_check(point.distance_to(aids._history.back()) <= BallVisibility.TRAIL_LENGTH_M,
			"trail must remain spatially bounded")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	var shadow_position: Vector3 = aids._shadow.position
	var history: Array[Vector3] = aids._history.duplicate()
	await _frames(6)
	_check(aids._shadow.position == shadow_position and aids._history == history,
		"ball aids must freeze during camera inspection")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	# This cue check exercises a live bobble beyond Single; short bobbles are
	# dead fouls and are covered separately by the scoring/integration checks.
	lab._batted_ball.global_position.z = lab._field_definition.safe_hit_z_m + 0.5
	lab._apply_fielding_outcome(&"pitcher", lab.MOUND_ORIGIN, FieldingResolver.Outcome.BOBBLE)
	_check(lab._sounds.last_cue == &"bobble" and lab._pitch_feedback.text.contains("BOBBLE"),
		"bobble must pair sound with text without ending live play")
	_check(not lab._ball_play_resolver.state.dead, "bobble cue must not affect resolution")
	lab._apply_fielding_outcome(&"pitcher", lab.MOUND_ORIGIN, FieldingResolver.Outcome.CLEAN)
	_check(lab._sounds.last_cue == &"catch", "clean control must have its own cue")
	lab._cleanup_batted_ball()
	_check(not aids.visible and aids._history.is_empty(), "cleanup must discard all ball aids")
	lab._start_ball_in_play(launch)
	lab._on_batted_surface_contact(&"back_wall", Vector3(3, 2, 23.4))
	_check(lab._sounds.last_cue == &"wall", "wall result must trigger wall cue")
	lab._cleanup_batted_ball()


func _test_result_holds(lab: PitchBatLab) -> void:
	lab._match_mode = true
	lab._match_state = MatchLabSupport.create_match(
		lab.DEBUG_PLAYER_ID, lab.PLAYER_TEAM_NAME, lab.RIVAL_TEAM_NAME)
	lab._base_state = lab._match_state.bases
	lab._match_state.begin_pitch()
	lab._match_state.strikes = 2
	lab._swing_consumed = true
	lab._pending_swing_miss = ContactResult.new()
	lab._pending_swing_miss.miss_reason = ContactResult.MissReason.LATE
	lab._on_plate_crossed(Vector3(0, 1, 0), 20.0, 0.7)
	_check(lab._status_label.text.contains("STRIKEOUT")
		and lab._pitch_feedback.text == "LATE", "strikeout should retain actual swing feedback")
	_check(lab._at_bat_cadence.active_hold_seconds >= 2.25, "strikeouts need a readable hold")
	lab._match_state.phase = MatchState.Phase.GAME_END
	lab._match_state.winner_name = lab.PLAYER_TEAM_NAME
	PitchBatLabFeelSupport.notify_pitch_dead(lab)
	_check(not lab._match_presentation_director.blocks_gameplay(),
		"non-HR game-ending result must not jump straight to outro")
	await _frames(100)
	_check(not lab._match_presentation_director.blocks_gameplay(), "final result must marinate")
	await _frames(70)
	_check(lab._match_presentation_director.blocks_gameplay(), "outro must follow final result")


func _test_rolling_result(lab: PitchBatLab) -> void:
	var director: MatchPresentationDirector = lab._match_presentation_director
	director.begin_outro(220)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._camera_director.set_shot(director.current_shot())
	var score: String = lab._match_state.score_label()
	var clock: float = lab._match_state.elapsed_seconds
	var records: int = lab._play_records.size()
	var previous: Transform3D = lab._camera.global_transform
	var seen: Dictionary = {}
	var largest_step: float = 0.0
	# Two complete 40-second loops through the real presentation/camera update.
	for frame in range(4801):
		PitchBatLabFeelSupport.update(lab, 1.0 / 60.0)
		seen[director.current_shot()] = true
		largest_step = maxf(largest_step,
			previous.origin.distance_to(lab._camera.global_position))
		previous = lab._camera.global_transform
		_check(director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD,
			"rolling cameras must retain the continue-ready result state")
	_check(seen.size() == 4, "result loop must visit four scenic angles")
	_check(largest_step > 0.01 and largest_step < 0.8,
		"result camera must move gradually between views without positional cuts")
	_check(lab._match_state.score_label() == score and lab._match_state.elapsed_seconds == clock
		and lab._play_records.size() == records,
		"indefinite camera loops must not change final score, game time or records")
	lab._debug_paused = true
	var paused_time: float = director.elapsed_seconds
	PitchBatLabFeelSupport.update(lab, 2.0)
	_check(director.elapsed_seconds == paused_time, "pause must freeze the rolling shot clock")
	lab._debug_paused = false
	print("ROLLING RESULT scenic_angles=", seen.size(), " simulated_seconds=80 max_step_m=",
		snappedf(largest_step, 0.001))


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
