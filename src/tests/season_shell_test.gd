extends Node

var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SeasonSave.path = "user://season-test-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://season-display-test-%d.cfg" % OS.get_process_id()
	_test_schedules_and_playoffs()
	_test_saves()
	await _test_menus_and_match_handoff()
	DirAccess.remove_absolute(SeasonSave.path)
	DirAccess.remove_absolute(SeasonSave.path + ".bak")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro season shell checks passed: 60 seasons, saves and menu handoffs.")
	get_tree().quit(0 if _failures == 0 else 1)


func _draft(seed_value: int) -> SeasonState:
	var season: SeasonState = SeasonState.create(seed_value)
	for pick in range(4):
		_check(season.offers().size() == 3, "each draft round must offer three players")
		_check(season.choose_player(season.offers()[pick % 3]), "draft choice must succeed")
	var ids: Array = []
	for team in season.teams:
		_check(team["roster"].size() == 4, "each club needs four two-way players")
		for id: String in team["roster"]:
			_check(not ids.has(id), "players must not appear on two clubs")
			ids.append(id)
	return season


func _test_schedules_and_playoffs() -> void:
	var paths: Dictionary = {}
	for seed_value in range(60):
		var season: SeasonState = _draft(seed_value)
		var pairs: Dictionary = {}
		for round_number in range(10):
			var clubs: Array = []
			for game in season.schedule:
				if game["round"] == round_number:
					for team in [game["home"], game["away"]]:
						_check(not clubs.has(team), "one game per club per round")
						clubs.append(team)
					var pair: String = "%d:%d" % [game["away"], game["home"]]
					_check(not pairs.has(pair), "each directed matchup occurs once")
					pairs[pair] = true
			_check(clubs.size() == 6, "every club must play every round")
		_check(pairs.size() == 30, "double round robin needs 30 total games")
		var count: int = 0
		while season.phase != SeasonState.Phase.COMPLETE and count < 13:
			var fixture: Dictionary = season.pending_fixture()
			_check(not fixture.is_empty(), "active season must have a player fixture")
			if fixture.is_empty():
				break
			if season.phase == SeasonState.Phase.SEMIFINAL:
				_check(
					(
						season.playoff_seeds.find(fixture["home"])
						< season.playoff_seeds.find(fixture["away"])
					),
					"higher seed must host semifinal"
				)
			if season.phase == SeasonState.Phase.FINAL:
				_check(fixture.get("neutral", false), "final must be neutral")
			var win: bool = seed_value % 3 == 0 or (seed_value % 3 == 1 and count < 10)
			var home_wins: bool = win == (fixture["home"] == 0)
			_check(not season.record_player_result(fixture["id"], 3, 3), "ties cannot be committed")
			_check(
				season.record_player_result(
					fixture["id"], 1 if home_wins else 6, 6 if home_wins else 1
				),
				"completed fixture must advance exactly once"
			)
			_check(
				not season.record_player_result(fixture["id"], 1, 6), "duplicate result rejected"
			)
			count += 1
		_check(
			season.phase == SeasonState.Phase.COMPLETE and season.champion >= 0,
			"every season must resolve a champion"
		)
		_check(
			season.results.size() == 33, "regular season and all three playoff games must resolve"
		)
		for row in season.standings():
			_check(row["wins"] + row["losses"] == 10, "standings must exclude playoffs")
		paths[count] = true
		if seed_value % 3 == 0:
			_check(season.champion == 0, "winning every game must make player champion")
		_check(SeasonSave.save(season), "completed season must checkpoint")
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored != null and restored.results == season.results,
			"all completed seasons must restore identical league and playoff results"
		)
	_check(
		paths.has(10) and paths.has(11) and paths.has(12),
		"cover missing playoffs, semifinal elimination and championship paths"
	)


func _test_saves() -> void:
	var draft: SeasonState = SeasonState.create(41)
	draft.choose_player(draft.offers()[1])
	_check(SeasonSave.save(draft), "draft must save")
	var resumed: SeasonState = SeasonSave.restore()
	_check(resumed != null and resumed.offers() == draft.offers(), "resume same draft offers")
	var season: SeasonState = _draft(71)
	season.swap_batters(0, 3)
	season.select_starter(2)
	for game in range(5):
		season.record_player_result(season.pending_fixture()["id"], game + 1, game + 2)
	_check(SeasonSave.save(season), "between-game state must replace earlier save")
	resumed = SeasonSave.restore()
	_check(resumed != null, "season save must decode")
	if resumed != null:
		_check(
			(
				resumed.results == season.results
				and resumed.pending_fixture() == season.pending_fixture()
			),
			"restore must reproduce all AI scores and pending fixture"
		)
		_check(
			resumed.teams[0]["roster"] == season.teams[0]["roster"] and resumed.starter_index == 2,
			"lineup and starter must survive reload"
		)
		var first: Dictionary = season.pending_fixture()
		season.record_player_result(first["id"], 7, 2)
		resumed.record_player_result(first["id"], 7, 2)
		_check(resumed.results == season.results, "resumed AI simulation remains reproducible")
	var file: FileAccess = FileAccess.open(SeasonSave.path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	_check(
		SeasonSave.restore() != null and SeasonSave.last_error.begins_with("Recovered"),
		"corrupt save must recover the prior valid checkpoint"
	)
	_check(
		FileAccess.get_file_as_string(SeasonSave.path) == "{broken", "invalid save stays untouched"
	)
	DirAccess.remove_absolute(SeasonSave.path + ".bak")
	_check(SeasonSave.restore() == null, "invalid save without backup must not start a fake season")
	DirAccess.remove_absolute(SeasonSave.path)


func _test_menus_and_match_handoff() -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames(2)
	_check(app.menu.page == "home" and app.lab == null, "boot must show menu without starting play")
	await _menu_bounds(app)
	app.menu.show_preseason()
	await _menu_bounds(app)
	app.difficulty_choice = 2
	app.begin_season(91)
	_check(app.season.difficulty == 2, "preseason difficulty must reach saved season")
	for pick in range(4):
		await _menu_bounds(app)
		var chosen: String = app.season.offers()[0]
		app.menu._select_draft(chosen)
		await _frames(2)
		_check(app.season.picks.size() == pick, "selecting a card must not draft it yet")
		(app.menu._footer.get_child(0) as Button).pressed.emit()
	_check(app.menu.page == "hub", "four picks must lead to season hub")
	app.menu.show_lineup()
	app.swap_lineup(0, 2)
	app.select_starter(1)
	await _menu_bounds(app)
	var displayed_stats: int = 0
	for node in app.menu._body.find_children("*", "Label", true, false):
		if (node as Label).text in SeasonPlayerCard.RATING_NAMES:
			displayed_stats += 1
	_check(displayed_stats == 7, "all seven stats must be visible on lineup without hovering")
	app.menu.show_schedule()
	await _menu_bounds(app)
	for game in range(2):
		var fixture: Dictionary = app.season.pending_fixture().duplicate()
		app.play_season_game()
		var lab: PitchBatLab = app.lab
		_check(lab._field_definition == SeasonState.field_for_fixture(fixture),
			"season app must load the fixture's actual home or away venue")
		var export_path: String = "user://season-flow-%d-%d.json" % [OS.get_process_id(), game]
		lab._record_export.path = export_path
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		_check(
			lab._player_is_pitching() == (fixture["home"] == 0),
			"home side must pitch first and away side must bat first"
		)
		var roster: TeamMatchState = (
			lab._match_state.home_team if fixture["home"] == 0 else lab._match_state.away_team
		)
		_check(
			roster.current_pitcher().definition.id == StringName(app.season.teams[0]["roster"][1]),
			"configured starter must reach actual match"
		)
		var original: MatchState = lab._match_state
		var saved_order: Array = app.season.teams[0]["roster"].duplicate()
		app.swap_lineup(0, 3)
		_check(
			app.season.teams[0]["roster"] == saved_order, "lineup must lock during an active game"
		)
		lab._start_new_match()
		_check(lab._match_state == original, "R must not replace a managed season game")
		app.finish_game()
		_check(
			app.lab == lab and app.season.round_index == game, "unfinished result must not commit"
		)
		PitchBatLabFeelSupport.toggle_debug_pause(lab)
		app.ask_leave_game()
		_check(app._dialog.visible and get_tree().paused, "leaving must confirm while frozen")
		app._dialog.hide()
		PitchBatLabFeelSupport.toggle_debug_pause(lab)
		# Exercise the real presentation handoff with an injected final score.
		lab._match_state.away_team.runs = 2
		lab._match_state.home_team.runs = 3
		lab._match_state.phase = MatchState.Phase.GAME_END
		lab._match_state.winner_name = lab._match_state.home_team.display_name
		PitchBatLabFeelSupport.begin_match_outro(lab)
		app.finish_game()
		_check(app.lab == lab, "outro must complete before result handoff")
		await _frames(2)
		var final_save: SeasonState = SeasonSave.restore()
		_check(
			final_save != null and final_save.round_index == game + 1,
			"final score must save before the player dismisses the outro"
		)
		PitchBatLabFeelSupport.toggle_debug_pause(lab)
		_check(
			lab._pause_menu._leave_button.disabled, "completed games must use the result handoff"
		)
		PitchBatLabFeelSupport.toggle_debug_pause(lab)
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab.match_return_requested.emit()
		app.finish_game()
		_check(
			app.lab == null and app.menu.page == "postgame" and app.season.round_index == game + 1,
			"postgame must commit once and return to menu"
		)
		await _menu_bounds(app)
		var resumed: SeasonState = SeasonSave.restore()
		_check(resumed != null and resumed.round_index == game + 1, "completed game must persist")
		app.show_season()
		await _frames(2)
		DirAccess.remove_absolute(export_path)
	app.play_season_game()
	var saved_totals: Dictionary = SeasonPerformance.totals(app.season)
	app.lab._match_state.record_hit(BallPlayOutcome.Result.HOME_RUN)
	app.leave_game()
	_check(
		app.season.round_index == 2 and not get_tree().paused,
		"abandoning a game must preserve season and unpause menus"
	)
	_check(SeasonPerformance.totals(app.season) == saved_totals,
		"abandoned game performance must not enter season totals")
	app.queue_free()
	await _frames(2)


func _menu_bounds(app: SeasonApp) -> void:
	await _frames(2)
	_check(
		Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(app.menu.get_global_rect()),
		"menu must stay within viewport"
	)
	_check(
		app.menu.get_global_rect().encloses(app.menu._footer.get_global_rect()),
		"navigation must stay visible without scrolling"
	)
	for node in app.menu._body.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control.get_viewport() != app.menu.get_viewport():
			continue
		var bounds: Rect2 = control.get_global_rect()
		_check(
			bounds.position.x >= 43 and bounds.end.x <= 1237,
			"menu content must not clip horizontally: " + str(control.name)
		)


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
