extends Node

var _failures: int = 0
var _launches: int = 0


func _ready() -> void:
	SeasonSave.path = "user://pitch-routing-season-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://pitch-routing-settings-%d.cfg" % OS.get_process_id()
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._record_export.path = "user://pitch-routing-records-%d.json" % OS.get_process_id()
	_test_definitions()
	for player: PlayerDefinition in ContentDB.player_by_id.values():
		if player.id == PitchBatLab.DEBUG_PLAYER_ID:
			continue
		_prepare(lab, player)
		for index in range(player.starting_pitches.size()):
			var expected: PitchDefinition = player.starting_pitches[index]
			for mouse in [false, true]:
				_reset_pitch(lab)
				_select(lab, index, mouse)
				_check_selection(lab, index, expected)
				_launch(lab, expected)
	_test_transitions(lab)
	await _test_full_name_bounds(lab)
	_test_season_identity()
	var record_path: String = lab._record_export.path
	lab.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	DirAccess.remove_absolute(PitchBatLabSettings.path)
	DirAccess.remove_absolute(record_path)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro pitch routing checks passed: ", _launches, " actual launches.")
	get_tree().quit(0 if _failures == 0 else 1)


func _prepare(lab: PitchBatLab, player: PlayerDefinition) -> void:
	lab._match_mode = true
	lab._player_home = true
	lab._match_state = MatchLabSupport.create_match(lab.DEBUG_PLAYER_ID, "Away", "Home")
	lab._match_state.home_team.roster[0] = PlayerMatchState.create(player)
	lab._base_state = lab._match_state.bases
	lab._awaiting_batter_confirm = false
	lab._at_bat_cadence.stop()
	_reset_pitch(lab)
	lab._apply_defensive_assignment()
	lab._refresh_config()


func _reset_pitch(lab: PitchBatLab) -> void:
	lab._pitch_actor.reset_pitch()
	PitchBatLabFeelSupport.cancel_release(lab)
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	lab._match_state.between_batters = true
	lab._pitch_target = Vector2(0.0, 1.05)
	lab._pitch_effort = 1.0
	lab._fatigue = 0.0
	lab._pending_release_quality = 1.0


func _select(lab: PitchBatLab, index: int, mouse: bool) -> void:
	if mouse:
		lab._pitch_picker._buttons[index].pressed.emit()
	else:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = (KEY_1 + index) as Key
		event.pressed = true
		PitchBatLabInput.handle(lab, event)


func _check_selection(lab: PitchBatLab, index: int, expected: PitchDefinition) -> void:
	var button: Button = lab._pitch_picker._buttons[index]
	_check(lab._selected_pitch() == expected, "input must select authored resource: " + expected.id)
	_check(button.visible and button.button_pressed, "selected row must agree: " + expected.id)
	_check(button.text.begins_with(str(index + 1) + "  "), "shortcut must match visible row")
	_check(button.tooltip_text.begins_with(expected.display_name + "\n"),
		"tooltip must name selected pitch")
	_check(button.text == "%d  %s" % [index + 1, expected.display_name],
		"visible label must preserve the full authored pitch name, including delivery")


func _launch(lab: PitchBatLab, expected: PitchDefinition) -> void:
	var original_spin: Vector3 = expected.nominal_spin_axis_pitcher_frame
	lab._throw_pitch()
	_check(lab._pitch_actor.running, "authored center pitch must launch: " + expected.id)
	if not lab._pitch_actor.running:
		return
	_launches += 1
	var parameters: PitchLaunchParameters = lab._pitch_actor.parameters
	_check(parameters.pitch_id == expected.id and lab._pitch_actor.state.pitch_id == expected.id,
		"physical flight must use selected identity")
	_check(lab._active_play_record.pitch_id == expected.id,
		"QC record must use launched identity")
	_check(parameters.hole_axis_ball_local.is_equal_approx(
		expected.nominal_hole_axis_ball_local.normalized()), "flight must use selected aero recipe")
	_check(lab._pitch_picker._selected.text == expected.display_name,
		"collapsed delivery label must agree with launch")
	var other: int = (lab._selected_pitch_index + 1) % lab._current_pitch_options().size()
	_select(lab, other, false)
	_select(lab, other, true)
	_check(lab._selected_pitch() == expected, "live delivery must reject both selection paths")
	_check(expected.nominal_spin_axis_pitcher_frame == original_spin,
		"rating and launch must not mutate shared pitch content")


func _test_definitions() -> void:
	for id: StringName in PitchBatLab.PITCH_IDS:
		var pitch: PitchDefinition = ContentDB.get_pitch(id)
		_check(pitch != null and pitch.id == id, "manifest ID must resolve to its own resource")
		_check(pitch.resource_path == "res://src/content/pitches/" + String(id).trim_prefix("pitch.")
			+ ".tres", "pitch ID must agree with authored resource path")
	var drop: PitchDefinition = ContentDB.get_pitch(&"pitch.drop")
	var fast: PitchDefinition = ContentDB.get_pitch(&"pitch.overhand_four_seam")
	_check(drop.display_name == "Drop" and fast.display_name == "Overhand Four-Seam",
		"Drop and Four-Seam labels must not be exchanged")
	_check(drop.nominal_spin_axis_pitcher_frame.x < -0.9
		and fast.nominal_spin_axis_pitcher_frame.x > 0.9,
		"Drop and Four-Seam must retain distinct authored topspin/backspin recipes")


func _test_transitions(lab: PitchBatLab) -> void:
	# Deliberately invert slots to catch global-key assumptions and stale indices.
	var drop: PitchDefinition = ContentDB.get_pitch(&"pitch.drop")
	var fast: PitchDefinition = ContentDB.get_pitch(&"pitch.overhand_four_seam")
	var player: PlayerDefinition = ContentDB.get_player(&"player.ash_cole").duplicate()
	player.starting_pitches = [drop, fast]
	_prepare(lab, player)
	lab._match_state.away_team.roster[0].definition = player
	_select(lab, 0, false)
	_check_selection(lab, 0, drop)
	lab._toggle_match_mode()
	_check(not lab._match_mode, "safe F2 must enter lab")
	_select(lab, 0, false)
	_check(lab._selected_pitch() == fast, "lab uses its global catalog order")
	lab._toggle_match_mode()
	_check_selection(lab, 0, drop)
	_launch(lab, drop)
	_reset_pitch(lab)
	var replacement: PlayerDefinition = player.duplicate()
	replacement.starting_pitches = [fast, drop]
	lab._match_state.home_team.roster[1] = PlayerMatchState.create(replacement)
	MatchLabSupport.select_pitcher(lab, 1)
	_check(lab._match_state.pitcher().definition == replacement, "bullpen changes actual pitcher")
	_check_selection(lab, 0, fast)
	_select(lab, 1, true)
	_check_selection(lab, 1, drop)
	_launch(lab, drop)
	_reset_pitch(lab)
	# Let the AI overwrite its selection, then return through real inning handoff.
	lab._match_state.top_half = false
	MatchLabSupport.apply_ai_pitch_choice(lab)
	var ai_pitch: PitchDefinition = lab._current_pitch_options()[lab._selected_pitch_index]
	lab._ai_pitch_preselected = true
	lab._throw_pitch()
	_check(lab._pitch_actor.parameters.pitch_id == ai_pitch.id, "AI launch uses its own repertoire")
	_reset_pitch(lab)
	lab._match_state.phase = MatchState.Phase.INNING_TRANSITION
	PitchBatLabFeelSupport.handle_match_advance(lab)
	_check(lab._player_is_pitching(), "inning handoff must return player defense")
	_check_selection(lab, 0, fast)
	_select(lab, 1, false)
	_launch(lab, drop)


func _test_season_identity() -> void:
	for seed_value in range(20):
		var season: SeasonState = SeasonState.create(seed_value)
		for pick in range(4):
			season.choose_player(season.offers()[0])
		season.select_starter(2)
		var starter: String = season.teams[0]["roster"][season.starter_index]
		var fielder: String = season.teams[0]["roster"][season.fielder_index]
		season.swap_batters(0, 2)
		season.swap_batters(1, 3)
		_check(SeasonSave.save(season), "reordered lineup must save")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null, "reordered lineup must restore")
		if restored == null:
			continue
		var state: MatchState = restored.make_match()
		var team: TeamMatchState = state.home_team if restored.pending_fixture()["home"] == 0 else (
			state.away_team)
		_check(team.current_pitcher().definition.id == StringName(starter),
			"reorder/reload must preserve starter identity")
		_check(team.current_fielder().definition.id == StringName(fielder),
			"reorder/reload must preserve fielder identity")
		for index in range(4):
			var expected: PlayerDefinition = ContentDB.get_player(
				StringName(season.teams[0]["roster"][index]))
			_check(team.roster[index].definition == expected,
				"reorder/reload must preserve each player's ratings, hands and repertoire")


func _test_full_name_bounds(lab: PitchBatLab) -> void:
	var player: PlayerDefinition = ContentDB.get_player(&"player.ash_cole").duplicate()
	player.starting_pitches = []
	for id: StringName in PitchBatLab.PITCH_IDS:
		player.starting_pitches.append(ContentDB.get_pitch(id))
	_prepare(lab, player)
	for anchor in range(3):
		lab._hud_anchor_index = anchor
		PitchBatLabPresentation.apply_hud_anchor(lab)
		lab._refresh_config()
		await get_tree().process_frame
		await get_tree().process_frame
		var picker: PitchPicker = lab._pitch_picker
		_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(picker.get_global_rect()),
			"full-name pitch panel must fit the viewport")
		_check(not picker.get_global_rect().intersects(lab._scorebug.get_global_rect()),
			"full-name pitch panel must clear scorebox at each anchor")
		for button in picker._buttons:
			var font: Font = button.get_theme_font("font")
			var width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, button.get_theme_font_size("font_size")).x
			var padding: float = button.get_theme_stylebox("normal").get_minimum_size().x
			_check(width + padding <= button.size.x,
				"full pitch name must fit without clipping: " + button.text)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
