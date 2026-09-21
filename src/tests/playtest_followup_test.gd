extends Node

var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_test_chase_choices()
	await _test_bullpen_and_timeout()
	await _test_home_run(false)
	await _test_home_run(true)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro playtest followup checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _lab(suffix: String) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._record_export.path = "user://followup-test-%d-%s.json" % [OS.get_process_id(), suffix]
	return lab


func _free(lab: PitchBatLab) -> void:
	var path: String = lab._record_export.path
	lab.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(path)


func _test_bullpen_and_timeout() -> void:
	var lab: PitchBatLab = _lab("bullpen")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	PitchBatLabInput.handle(lab, escape)
	_check(lab._debug_paused, "Escape is the pause shortcut")
	var old_pause: InputEventKey = InputEventKey.new()
	old_pause.keycode = KEY_P
	old_pause.pressed = true
	PitchBatLabInput.handle(lab, old_pause)
	_check(lab._debug_paused, "P must no longer toggle pause")
	PitchBatLabInput.handle(lab, escape)
	_check(not lab._debug_paused, "Escape resumes the paused game")
	_check(not lab._controls_label.get_global_rect().intersects(
		lab._display_menu_button.get_global_rect()), "footer text must clear Pause")
	var team: TeamMatchState = lab._match_state.defensive_team()
	team.current_pitcher().spend_stamina(1.0)
	MatchLabSupport.consider_ai_pitching_change(lab)
	_check(team.pitcher_index == 0, "AI must retain a fresh pitcher")
	team.current_pitcher().stamina_remaining = team.current_pitcher().stamina_max * 0.16
	lab._match_state.between_batters = false
	MatchLabSupport.consider_ai_pitching_change(lab)
	_check(team.pitcher_index == 0, "AI cannot change pitchers during an at-bat")
	lab._match_state.between_batters = true
	MatchLabSupport.consider_ai_pitching_change(lab)
	_check(team.pitcher_index != 0 and team.roster[0].pitching_finished,
		"AI must replace a tired pitcher at a legal boundary")
	_check(not team.select_pitcher(0), "removed pitcher cannot re-enter on the mound")
	team.batting_index = 0
	team.fielder_index = 0
	_check(team.current_batter() == team.roster[0] and team.current_fielder() == team.roster[0],
		"pitching removal must retain batting and fielding eligibility")
	PitchBatLabFeelSupport.confirm_batter_ready(lab)
	var pitch_index: int = lab._selected_pitch_index
	var target: Vector2 = lab._pitch_target
	_check(PitchBatLabFeelSupport.request_batter_timeout(lab), "quiet set permits one timeout")
	_check(lab._awaiting_batter_confirm and lab._match_state.batter_timeout_used,
		"timeout returns to a deliberate ready state")
	for frame in range(90):
		await get_tree().physics_frame
	_check(lab._throw_number == 0, "stepping out cannot release a pitch")
	PitchBatLabFeelSupport.confirm_batter_ready(lab)
	_check(lab._selected_pitch_index == pitch_index and lab._pitch_target == target,
		"timeout must preserve the opponent's selected pitch and target")
	_check(not PitchBatLabFeelSupport.request_batter_timeout(lab), "one timeout per at-bat")
	lab._match_state.batter_timeout_used = false
	lab._at_bat_cadence.elapsed_seconds = lab._at_bat_cadence.active_set_seconds + 0.1
	_check(not PitchBatLabFeelSupport.request_batter_timeout(lab), "windup closes the timeout window")
	await _free(lab)


func _test_home_run(walkoff: bool) -> void:
	var lab: PitchBatLab = _lab("walkoff" if walkoff else "home-run")
	lab._match_state.top_half = false
	lab._match_state.inning = 5 if walkoff else 1
	lab._awaiting_batter_confirm = false
	lab._active_play_record = PlayRecord.new()
	lab._primary_fielder.set_physics_process(false)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(3, 4.5, 21)
	launch.velocity = Vector3(0, 0, 15)
	lab._start_ball_in_play(launch)
	lab._pitcher_attempted = true
	lab._primary_attempts = 2
	for frame in range(180):
		await get_tree().physics_frame
		if lab._home_run.active:
			break
	_check(lab._sounds.last_cue == &"home_run", "actual HR must play celebration cue")
	_check(lab._home_run.active, "physical wall clearance must begin HR presentation")
	_check(lab._play_records.size() == 1, "HR must score and record exactly once")
	var score: int = lab._match_state.home_team.runs
	for frame in range(36):
		await get_tree().physics_frame
	_check(lab._batted_ball.global_position.z > lab._field_definition.back_wall_z_m + 1.0,
		"HR ball must visibly travel beyond the wall")
	_check(not lab._batted_ball.freeze, "carry must remain physical before the wide shot")
	lab._display_menu_button.pressed.emit()
	var elapsed: float = lab._home_run.elapsed
	var position: Vector3 = lab._batted_ball.position
	for frame in range(12):
		await get_tree().physics_frame
	_check(lab._home_run.elapsed == elapsed and lab._batted_ball.position == position,
		"pause must freeze both HR carry and presentation time")
	lab._display_menu_button.pressed.emit()
	for frame in range(60):
		await get_tree().physics_frame
	_check(lab._home_run.wide_shot
		and lab._camera_director.shot == MatchCameraDirector.Shot.ESTABLISHING,
		"HR must transition smoothly to the wide celebration view")
	_check("HOME RUN" in lab._status_label.text and lab._home_run.active,
		"home run call must remain visible during the extended hold")
	_check(not lab._pitch_picker.visible, "HR celebration should clear the pitch selector")
	_check(not lab._match_presentation_director.blocks_gameplay(),
		"walkoff outro must wait for the HR celebration")
	for frame in range(240):
		await get_tree().physics_frame
	_check(lab._match_state.home_team.runs == score and lab._play_records.size() == 1,
		"carry or later collisions cannot score the HR twice")
	if walkoff:
		_check(lab._match_presentation_director.blocks_gameplay(), "walkoff must eventually reach outro")
	await _free(lab)


func _test_chase_choices() -> void:
	var model: BatterApproachModel = BatterApproachModel.new()
	var pitch: PitchDefinition = ContentDB.get_pitch(&"pitch.overhand_slider")
	var batter: PlayerDefinition = ContentDB.get_player(PitchBatLab.DEBUG_PLAYER_ID)
	var borderline: int = 0
	var protecting: int = 0
	var waste: int = 0
	for sample in range(600):
		for location in [Vector2(0.50, 1.05), Vector2(1.2, 1.05)]:
			var decision: Dictionary = model.decide(pitch, location, location, batter, 0, 0, 23, sample)
			if decision.swing:
				if location.x < 1.0:
					borderline += 1
				else:
					waste += 1
		var protect: Dictionary = model.decide(
			pitch, Vector2(0.50, 1.05), Vector2(0.50, 1.05), batter, 0, 2, 23, sample)
		if protect.swing:
			protecting += 1
	_check(borderline > 120 and borderline < 300, "borderline pitches need meaningful, bounded chase")
	_check(protecting > borderline, "two strikes must encourage protection")
	_check(waste < 40, "obvious waste pitches must still be mostly taken")
	print("CHASE_CHOICES borderline=", borderline, " protect=", protecting, " waste=", waste, "/600")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
