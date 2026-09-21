extends Node

var _failures: int = 0


func _ready() -> void:
	SeasonSave.path = "user://season-flow-stats-%d.json" % OS.get_process_id()
	_test_scoring_events()
	_test_saved_season()
	await _test_pages()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	if _failures == 0:
		print("Wiffaltro season flow checks passed: stats, migration, recaps and navigation.")
	get_tree().quit(0 if _failures == 0 else 1)


func _draft() -> SeasonState:
	var season: SeasonState = SeasonState.create(936)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	return season


func _test_scoring_events() -> void:
	var state: MatchState = _draft().make_match()
	var hitters: Array[PlayerMatchState] = state.away_team.roster
	var starter: PlayerMatchState = state.pitcher()
	starter.spend_stamina(1.0)
	state.record_hit(BallPlayOutcome.Result.SINGLE)
	state.bases.first = hitters[0].definition.id
	state.bases.second = hitters[2].definition.id
	state.bases.third = hitters[3].definition.id
	state.balls = 3
	state.record_ball()
	state.strikes = 2
	state.record_foul()
	_check(
		state.performance.players[String(hitters[1].definition.id)]["pa"] == 1,
		"two-strike foul must not end or duplicate an appearance"
	)
	state.record_called_pitch(true)
	state.home_team.select_pitcher(2)
	var reliever: PlayerMatchState = state.pitcher()
	reliever.spend_stamina(1.0)
	state.record_hit(BallPlayOutcome.Result.DOUBLE)
	state.record_hit(BallPlayOutcome.Result.TRIPLE)
	state.record_hit(BallPlayOutcome.Result.HOME_RUN)
	state.record_ball_in_play_out(1, "Sacrifice fly")
	var stats_data: Dictionary = state.performance.snapshot(state)
	var first: Dictionary = stats_data[String(hitters[0].definition.id)]
	var second: Dictionary = stats_data[String(hitters[1].definition.id)]
	var third: Dictionary = stats_data[String(hitters[2].definition.id)]
	var old_arm: Dictionary = stats_data[String(starter.definition.id)]
	var new_arm: Dictionary = stats_data[String(reliever.definition.id)]
	_check(
		first["pa"] == 2 and first["h"] == 2 and first["triple"] == 1,
		"hit types must stay with the hitter before the batting cursor advances"
	)
	_check(
		second["pa"] == 2 and second["bb"] == 1 and second["hr"] == 1 and second["rbi"] == 3,
		"loaded walk and homer must credit their actual hitter and driven runs"
	)
	_check(
		third["pa"] == 2 and third["k"] == 1 and third["rbi"] == 1,
		"strikeout and sacrifice must count appearances without becoming hits"
	)
	_check(
		old_arm["p_h"] == 1 and old_arm["p_bb"] == 1 and old_arm["p_k"] == 1,
		"starter must retain events after substitution"
	)
	_check(
		new_arm["p_h"] == 3 and new_arm["outs"] == 1 and new_arm["pitches"] == 1,
		"reliever must receive only their own events and actual pitch count"
	)
	stats_data[String(starter.definition.id)]["p_h"] = 99
	_check(
		state.performance.players[String(starter.definition.id)]["p_h"] == 1,
		"snapshot must not alias live stats"
	)
	var walkoff: MatchState = _draft().make_match()
	walkoff.inning = 5
	walkoff.top_half = false
	var winner: String = String(walkoff.batter().definition.id)
	walkoff.record_hit(BallPlayOutcome.Result.HOME_RUN)
	_check(
		(
			walkoff.phase == MatchState.Phase.GAME_END
			and walkoff.performance.players[winner]["hr"] == 1
		),
		"walk-off must record before game-end and batting cursor transitions"
	)


func _complete_game(season: SeasonState) -> MatchState:
	var state: MatchState = season.make_match()
	var player_home: bool = season.pending_fixture()["home"] == 0
	var scored: bool = false
	for step in range(100):
		if state.phase == MatchState.Phase.GAME_END:
			return state
		if state.phase != MatchState.Phase.PRE_PITCH:
			state.continue_after_dead_ball()
			continue
		state.pitcher().spend_stamina(1.0)
		if not scored and state.top_half != player_home:
			state.record_hit(BallPlayOutcome.Result.HOME_RUN)
			scored = true
		else:
			state.strikes = 2
			state.record_strike()
	_check(false, "scripted scored game must terminate")
	return state


func _test_saved_season() -> void:
	var season: SeasonState = _draft()
	for game in range(12):
		var fixture: Dictionary = season.pending_fixture()
		var state: MatchState = _complete_game(season)
		var snapshot: Dictionary = state.performance.snapshot(state)
		_check(
			season.record_player_result(
				fixture["id"], state.away_team.runs, state.home_team.runs, snapshot
			),
			"completed match must commit score and statistics"
		)
		var totals: Dictionary = SeasonPerformance.totals(season)
		_check(
			not season.record_player_result(
				fixture["id"], state.away_team.runs, state.home_team.runs, snapshot
			),
			"duplicate final handoff must not commit stats twice"
		)
		_check(totals == SeasonPerformance.totals(season), "duplicate handoff leaves totals intact")
		season.swap_batters(0, 2)
		_check(SeasonSave.save(season), "stats checkpoint must save")
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored != null and SeasonPerformance.totals(restored) == totals,
			"statistics must survive save and lineup changes by stable player ID"
		)
		if restored != null:
			season = restored
	_check(
		season.champion == 0 and season.player_results.size() == 12,
		"full season stats include both playoff games"
	)
	var home_runs: int = 0
	for line: Dictionary in SeasonPerformance.totals(season).values():
		home_runs += int(line["hr"])
	_check(home_runs == 12, "twelve one-run wins must produce exactly twelve player homers")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var valid_data: Dictionary = data.duplicate(true)
	var id: String = data["picks"][0]
	data["results"][0]["performance"][id]["h"] = -1
	_check(SeasonSave._decode(data) == null, "negative stats rejected")
	data = valid_data.duplicate(true)
	data["results"][0]["performance"][id]["pa"] = 0.5
	_check(SeasonSave._decode(data) == null, "fractional stats rejected")
	data = valid_data.duplicate(true)
	data["results"][0]["performance"][id]["p_h"] += 1
	_check(SeasonSave._decode(data) == null, "unbalanced batting/pitching stats rejected")
	data = valid_data.duplicate(true)
	data["results"][0]["performance"]["player.foreign"] = data["results"][0]["performance"][id]
	_check(SeasonSave._decode(data) == null, "foreign roster statistics rejected")
	data = valid_data.duplicate(true)
	data["version"] = 2
	for result: Dictionary in data["results"]:
		result.erase("performance")
	var migrated: SeasonState = SeasonSave._decode(data)
	_check(
		migrated != null and migrated.champion == season.champion,
		"v2 migration retains completed season and scores"
	)
	_check(
		(
			migrated != null
			and SeasonPerformance.coverage(migrated).begins_with("Recorded games: 0 / 12")
		),
		"legacy games must have missing coverage, not invented box scores"
	)
	data["results"] = data["results"].slice(0, 1)
	migrated = SeasonSave._decode(data)
	if migrated != null:
		var state: MatchState = _complete_game(migrated)
		migrated.record_player_result(
			migrated.pending_fixture()["id"],
			state.away_team.runs,
			state.home_team.runs,
			state.performance.snapshot(state)
		)
		_check(
			SeasonPerformance.coverage(migrated).begins_with("Recorded games: 1 / 2"),
			"resumed older season must add only newly observed player stats"
		)
		_check(
			SeasonSave.save(migrated) and SeasonSave.restore() != null,
			"mixed legacy/current history must checkpoint and restore"
		)


func _test_pages() -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.begin_season(936)
	app.choose_player(app.season.offers()[0])
	await _bounds(app)
	_check(
		_texts(app).contains("+ / − = rating difference"), "draft comparison must explain deltas"
	)
	for pick in range(3):
		app.choose_player(app.season.offers()[0])
	await _bounds(app)
	_check(
		(app.menu._footer.get_child(0) as Button).text == "PREPARE NEXT GAME",
		"hub primary action must lead to pregame"
	)
	(app.menu._footer.get_child(0) as Button).pressed.emit()
	await _bounds(app)
	_check(
		app.menu.page == "lineup" and _texts(app).contains("Opposing starter:"),
		"pregame shows actual opposing starter and editable lineup"
	)
	var scroll: ScrollContainer = app.menu._body.get_parent() as ScrollContainer
	scroll.scroll_vertical = 150
	await _frames()
	var offset: int = scroll.scroll_vertical
	app.select_starter(2)
	await _frames()
	await _frames()
	_check(
		(app.menu._body.get_parent() as ScrollContainer).scroll_vertical == offset,
		"lineup changes should preserve scroll position"
	)
	var state: MatchState = _complete_game(app.season)
	var game: Dictionary = app.season.pending_fixture()
	app.season.record_player_result(
		game["id"], state.away_team.runs, state.home_team.runs, state.performance.snapshot(state)
	)
	app.menu.show_last_game()
	await _bounds(app)
	_check(
		_texts(app).contains("BATTING") and _texts(app).contains("PITCHING"),
		"postgame includes actual team performance"
	)
	(app.menu._footer.get_child(0) as Button).pressed.emit()
	_check(app.menu.page == "lineup", "postgame can prepare next game directly")
	app.menu.show_stats()
	await _bounds(app)
	for index in range(11):
		game = app.season.pending_fixture()
		state = _complete_game(app.season)
		app.season.record_player_result(
			game["id"],
			state.away_team.runs,
			state.home_team.runs,
			state.performance.snapshot(state)
		)
	app.menu.show_hub()
	await _bounds(app)
	_check(
		app.menu.page == "summary" and _texts(app).contains("BACKYARD LEAGUE CHAMPIONS"),
		"completed season must open distinct season recap"
	)
	app.menu.show_last_game()
	await _bounds(app)
	app.menu.show_home()
	await _bounds(app)
	app.ask_new_season()
	_check(app._dialog.visible, "completed season replacement still requires confirmation")
	app._dialog.hide()
	app.queue_free()
	await _frames()


func _texts(app: SeasonApp) -> String:
	var lines: PackedStringArray = []
	for node in app.menu.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	return "\n".join(lines)


func _bounds(app: SeasonApp) -> void:
	await _frames()
	_check(
		Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(app.menu.get_global_rect()),
		"menu must remain within viewport: " + app.menu.page
	)
	_check(
		app.menu.get_global_rect().encloses(app.menu._footer.get_global_rect()),
		"footer must stay visible: " + app.menu.page
	)
	for node in app.menu.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control.get_viewport() != app.menu.get_viewport():
			continue
		var rect: Rect2 = control.get_global_rect()
		_check(
			rect.position.x >= -1 and rect.end.x <= 1281,
			"content must fit horizontally: %s / %s" % [app.menu.page, control.name]
		)


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
