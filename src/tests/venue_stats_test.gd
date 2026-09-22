extends Node

var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SeasonSave.path = "user://venue-stats-season-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://venue-stats-settings-%d.cfg" % OS.get_process_id()
	_test_schedule_and_save()
	await _test_venues()
	await _test_bullpen()
	await _test_stats()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	DirAccess.remove_absolute(PitchBatLabSettings.path)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro venue and pause stats checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _draft() -> SeasonState:
	var season: SeasonState = SeasonState.create(733)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	return season


func _test_schedule_and_save() -> void:
	var season: SeasonState = _draft()
	var homes: int = 0
	var aways: int = 0
	for game in range(12):
		var fixture: Dictionary = season.pending_fixture()
		_check(not fixture.is_empty(), "winning season must reach championship")
		if fixture.is_empty():
			break
		var field: FieldDefinition = SeasonState.field_for_fixture(fixture)
		var is_home: bool = fixture["home"] == 0 and not fixture.get("neutral", false)
		_check(field.id == (PitchBatLab.FIELD_ID if is_home else SeasonState.AWAY_FIELD_ID),
			"fixture must select the correct venue including playoffs")
		_check(field.display_name in SeasonPages.venue(fixture), "pregame must name actual venue")
		if game < 10:
			homes += int(is_home)
			aways += int(not is_home)
		_check(SeasonSave.save(season), "venue fixture must save")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null and restored.pending_fixture() == fixture,
			"Continue must keep the same fixture")
		if restored != null:
			_check(SeasonState.field_for_fixture(restored.pending_fixture()) == field,
				"Continue must load the same venue")
		season.record_player_result(fixture["id"], 1 if fixture["home"] == 0 else 3,
			3 if fixture["home"] == 0 else 1)
	_check(homes == 5 and aways == 5, "regular season must use each venue five times")
	_check(SeasonState.field_for_fixture({"home": 1, "away": 0, "id": 30}).id
		== SeasonState.AWAY_FIELD_ID, "away semifinal uses host park")
	_check(SeasonState.field_for_fixture({"home": 0, "away": 1, "neutral": true}).id
		== SeasonState.AWAY_FIELD_ID, "nominal home in final must still use neutral park")
	_check("You bat first" in SeasonPages.venue({"home": 1, "away": 0, "neutral": true})
		and "You pitch first" in SeasonPages.venue({"home": 0, "away": 1, "neutral": true}),
		"neutral final opening role must follow seeding, not assume the player hosts")


func _test_venues() -> void:
	var home: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var away: FieldDefinition = ContentDB.get_field(SeasonState.AWAY_FIELD_ID)
	var home_data: Dictionary = PlayRecordExport.field_metadata(home)
	var away_data: Dictionary = PlayRecordExport.field_metadata(away)
	home_data.erase("field_id")
	away_data.erase("field_id")
	_check(home_data == away_data, "venue scenery must preserve scoring geometry")
	for index in range(9):
		_check(home.fielder_anchor(index) == away.fielder_anchor(index)
			and home.is_fielder_anchor_available(index) == away.is_fielder_anchor_available(index),
			"both fields must preserve legal defender anchors")
	var collisions: Array = []
	for field in [home, away]:
		var lab: PitchBatLab = PitchBatLab.new()
		lab._field_id = field.id
		add_child(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		_check(lab._field_definition == field, "configured venue must reach resolver geometry")
		_check(field.display_name in lab._presentation_subtitle.text, "intro must name venue")
		var geometry: Node = lab.get_node("StarterFieldGeometry")
		var signature: Array = []
		for child in geometry.get_children():
			if child is StaticBody3D:
				var shape: CollisionShape3D = child.get_child(0)
				signature.append([String(child.name), child.position, shape.shape.size,
					child.collision_layer, child.collision_mask])
		collisions.append(signature)
		var scenery: Node = geometry.get_node_or_null("CommonsParkScenery")
		_check((scenery != null) == (field == away), "away scenery only belongs to away park")
		if scenery != null:
			_check(scenery.get_child_count() > 20, "away venue must have distinct authored scenery")
			_check(_collision_count(scenery) == 0, "decorations must not add gameplay collisions")
		lab.queue_free()
		await get_tree().process_frame
	_check(collisions[0] == collisions[1], "home and away physical collision shapes must match")


func _test_bullpen() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._player_home = true
	lab._pitching_staff_active = true
	for anchor in range(3):
		lab._hud_anchor_index = anchor
		PitchBatLabPresentation.apply_hud_anchor(lab)
		lab._refresh_config()
		await _frames(2)
		_check(lab._pitching_staff_panel.visible, "bullpen fixture must be visible")
		_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(
			lab._pitching_staff_panel.get_global_rect()), "expanded bullpen must fit each HUD anchor")
		var team: TeamMatchState = lab._match_state.defensive_team()
		for index in range(4):
			var button: Button = lab._pitcher_buttons[index]
			var hand: String = "LEFT" if team.roster[index].definition.throws == (
				PlayerDefinition.Handedness.LEFT) else "RIGHT"
			_check(button.text.contains("Throws " + hand), "bullpen hand must match actual pitcher")
			for line in button.text.split("\n"):
				var width: float = button.get_theme_font("font").get_string_size(line,
					HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
				_check(width + button.get_theme_stylebox("normal").get_minimum_size().x
					<= button.size.x, "bullpen name, hand, status and stamina must fit")
	lab.queue_free()
	await get_tree().process_frame


func _test_stats() -> void:
	var season: SeasonState = _draft()
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = season.make_match()
	lab._player_home = season.pending_fixture()["home"] == 0
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._record_export.path = "user://venue-stats-record-%d.json" % OS.get_process_id()
	var state: MatchState = lab._match_state
	var batter: PlayerMatchState = state.batter()
	state.record_hit(BallPlayOutcome.Result.DOUBLE)
	state.continue_after_dead_ball()
	lab._awaiting_batter_confirm = false
	lab._at_bat_cadence.stop()
	# Inspect during a physical pitch, on either batting or pitching side.
	lab._throw_pitch()
	_check(lab._pitch_actor.running, "pause fixture must have a live pitch")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	_check(lab._pause_menu._main.get_child(0).has_focus(),
		"pause must put keyboard focus on Resume")
	for button in lab._pause_menu._main.get_children():
		_check(button.focus_mode == Control.FOCUS_ALL, "pause actions must support keyboard focus")
	_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(
		lab._pause_menu.get_global_rect()), "restyled pause menu must stay within the viewport")
	lab._pause_menu._stats_button.grab_focus()
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	get_viewport().push_input(enter, true)
	enter = enter.duplicate()
	enter.pressed = false
	get_viewport().push_input(enter, true)
	await _frames(2)
	var panel: MatchStatsPanel = lab._pause_menu.stats
	_check(panel.visible and not lab._pause_menu.visible and get_tree().paused,
		"stats open inside pause with play frozen")
	var before: Dictionary = state.performance.snapshot(state)
	var before_position: Vector3 = lab._pitch_actor.state.position
	var before_time: float = state.elapsed_seconds
	for team in range(2):
		panel._team.select(team)
		panel._team.item_selected.emit(team)
		for tab in range(2):
			panel._tabs.current_tab = tab
			panel.refresh()
			await _frames(3)
			var labels: PackedStringArray = _labels(panel._body)
			for player in panel.selected_team().roster:
				_check("\n".join(labels).contains(player.definition.display_name),
					"stats must show each member of selected team")
			if tab == 0:
				for rating in SeasonPlayerCard.RATING_NAMES:
					_check(rating in labels, "ratings page must include " + rating)
				for player in panel.selected_team().roster:
					for pitch in player.definition.starting_pitches:
						_check("\n".join(labels).contains(pitch.display_name),
							"ratings page must show full repertoire names")
			else:
				var grid: GridContainer = panel._body.get_child(2)
				for row in range(4):
					if panel.selected_team().roster[row] == batter:
						_check(grid.get_child((row + 1) * 9 + 2).text == "1"
							and grid.get_child((row + 1) * 9 + 3).text == "1",
							"live double must appear as one hit and one double for its hitter")
			_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(panel.get_global_rect()),
				"stats panel must fit viewport")
			_check(panel.get_global_rect().encloses(panel._back.get_global_rect()),
				"back button must stay visible independent of scrolling")
			_check(panel._body.size.x <= panel._scroll.size.x, "stats content must not overflow width")
	_check(state.performance.snapshot(state) == before and state.elapsed_seconds == before_time
		and lab._pitch_actor.state.position == before_position,
		"inspecting both teams must not advance pitch, match clock or performance")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	PitchBatLabInput.handle(lab, escape)
	_check(not panel.visible and lab._pause_menu.visible and get_tree().paused,
		"first Escape must return to pause without resuming")
	PitchBatLabInput.handle(lab, escape)
	_check(not get_tree().paused and not panel.visible, "second Escape resumes normally")
	var path: String = lab._record_export.path
	lab.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(path)


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().process_frame


func _labels(node: Node) -> PackedStringArray:
	var result: PackedStringArray = []
	if node is Label:
		result.append(node.text)
	for child in node.get_children():
		result.append_array(_labels(child))
	return result


func _collision_count(node: Node) -> int:
	var result: int = int(node is CollisionObject3D)
	for child in node.get_children():
		result += _collision_count(child)
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
