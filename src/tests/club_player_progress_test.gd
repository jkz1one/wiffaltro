extends Node
## Synthetic evidence fixtures test extraction only, not physical feasibility or paid grants.

var _failures: int = 0


func _ready() -> void:
	_shapes()
	_capture()
	_development()
	_history()
	if _failures == 0:
		print("Wiffaltro player progress checks passed: human proof, unknown history and varied routes.")
	get_tree().quit(0 if _failures == 0 else 1)


func _details(scores: Array) -> Dictionary:
	var rows: Array = []
	for score: Array in scores:
		if 0 in [int(score[1]), int(score[2])]:
			rows.append({"game": score[0], "stats": null,
				"sponsors": 0, "end_half": -1, "deficit": 0})
	return {"version": 1, "games": rows,
		"development": {"mastery": 1, "known": 3, "lessons": []}}


func _shapes() -> void:
	var scores: Array = [[0, 1, 0, 3, 4]]
	var good: Dictionary = _details(scores)
	_check(ClubPlayerProgress.valid(good, scores), "unknown historical detail stays valid and unknown")
	good.games[0].stats = {"homers": 3, "hitters": 4, "strikeouts": 6, "three_k": 2}
	good.games[0].end_half = 9
	good.games[0].deficit = 3
	_check(ClubPlayerProgress.valid(good, scores), "bounded completed game evidence")
	for field: String in ["homers", "hitters", "strikeouts", "three_k"]:
		var bad: Dictionary = good.duplicate(true)
		bad.games[0].stats[field] = 100000
		_check(not ClubPlayerProgress.valid(bad, scores), "reject impossible " + field)
	for field: String in ["game", "sponsors", "end_half", "deficit"]:
		var bad: Dictionary = good.duplicate(true)
		bad.games[0][field] = "9"
		_check(not ClubPlayerProgress.valid(bad, scores), "reject malformed " + field)
	var bad: Dictionary = good.duplicate(true)
	bad.games[0].end_half = -1
	_check(not ClubPlayerProgress.valid(bad, scores), "unknown chronology cannot prove comeback")
	bad.games[0].end_half = 5
	_check(not ClubPlayerProgress.valid(bad, scores), "early ending needs mercy margin")
	bad = good.duplicate(true)
	bad.development.lessons = ["pitch.drop", "pitch.drop"]
	_check(not ClubPlayerProgress.valid(bad, scores), "duplicate lessons cannot inflate feat")
	for malformed: Array in [[[0, 1, 0, 4, 4]], [[0, 0, 0, 3, 4]], [[false, 1, 0, 3, 4]]]:
		_check(not ClubPlayerProgress.valid(good, malformed), "reject invalid bound score")
	bad = good.duplicate(true)
	bad.games.append(bad.games[0].duplicate(true))
	_check(not ClubPlayerProgress.valid(bad, scores), "one record per human game")


func _new() -> SeasonState:
	var season: SeasonState = SeasonState.create(51, false, true, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	return season


func _capture() -> void:
	var season: SeasonState = _new()
	var empty: Dictionary = ClubPlayerProgress.capture(season)
	_check(not empty.is_empty() and empty.games.is_empty(), "draft grants no completed-game feat")
	var fixture: Dictionary = season.pending_fixture()
	var roster: Array = season.teams[fixture.away].roster + season.teams[fixture.home].roster
	var stats: Dictionary = {}
	for id: String in roster:
		stats[id] = MatchPerformance.empty_line()
	var ours: String = season.teams[0].roster[0]
	var enemy: String = season.teams[fixture.away if fixture.home == 0 else fixture.home].roster[0]
	stats[ours].p_k = 3
	stats[ours].outs = 3
	stats[enemy].k = 3
	stats[enemy].pa = 3
	_check(SeasonPerformance.valid(stats, roster), "synthetic strikeout ledger balances")
	_check(season.record_player_result(fixture.id, 1, 0, stats), "committed synthetic scheduled game")
	var captured: Dictionary = ClubPlayerProgress.capture(season)
	_check(not captured.is_empty() and captured.games.size() == 1, "only human game captured")
	if captured.is_empty():
		return
	_check(captured.games[0].stats.strikeouts == 3, "human pitcher strikeouts only")
	_check(captured.games[0].stats.homers == 0 and captured.games[0].end_half == -1,
		"missing old chronology is not fabricated")
	season.player_results[0].erase("performance")
	_check(ClubPlayerProgress.capture(season).games[0].stats == null, "missing stats remain unknown")
	season.build._market = 1
	_check(ClubPlayerProgress.capture(season).is_empty(), "AI market cannot supply human proof")


func _development() -> void:
	var roster: Array[String] = ["player.ash_cole", "player.cal_mercer",
		"player.casey_rivers", "player.dakota_wells"]
	var build: SeasonBuild = SeasonBuild.new(8, roster)
	var first: Dictionary = ClubPlayerProgress._development(build)
	_check(first.known < 5 and first.mastery == 1 and first.lessons.is_empty(),
		"unowned 48-player baseline cannot grant mastery or five-pitch feat")
	var id: String = roster[0]
	var book: SeasonDevelopment = build._book
	var recipe: String = book.player(id).active[0]
	for step in range(4):
		_check(book.commit({"id": "synthetic:%d" % book.revision(), "rev": book.revision(),
			"op": "mastery", "player": id, "target": recipe}).ok, "synthetic legal development")
	var developed: Dictionary = ClubPlayerProgress._development(build)
	_check(developed.mastery == 5 and developed.lessons.is_empty(), "mastery separate from learning")
	for lesson: Array in [["pitch.riser", ""], ["pitch.drop", "pitch.riser"],
		["pitch.riser", "pitch.drop"]]:
		_check(book.commit({"id": "synthetic:%d" % book.revision(), "rev": book.revision(),
			"op": "learn", "player": id, "target": lesson[0], "replace": lesson[1]}).ok,
			"synthetic legal new and remembered lessons")
	developed = ClubPlayerProgress._development(build)
	_check(developed.lessons == ["pitch.drop", "pitch.riser"] and developed.known == 4
		and developed.mastery == 5, "relearning does not count as a third new recipe")
	var unrelated: String = "player.alex_finch"
	_check(book.commit({"id": "synthetic:%d" % book.revision(), "rev": book.revision(),
		"op": "learn", "player": unrelated, "target": "pitch.riser", "replace": ""}).ok,
		"synthetic unrelated player lesson")
	_check(ClubPlayerProgress._development(build).lessons == ["pitch.drop", "pitch.riser"],
		"uncontracted player lessons excluded")


func _history() -> void:
	var season: SeasonState = _new()
	for game in range(2):
		var fixture: Dictionary = season.pending_fixture()
		_check(season.record_player_result(fixture.id, 1 if fixture.away == 0 else 0,
			1 if fixture.home == 0 else 0), "synthetic wins for history metrics")
	var proof: Dictionary = ClubSeasonRecord.capture(season)
	var detail: Dictionary = _details(proof.scores)
	for row: Dictionary in detail.games:
		row.stats = {"homers": 0, "hitters": 4, "strikeouts": 3, "three_k": 1}
	var run: Dictionary = {"proof": proof, "status": "abandoned", "field_outs": 8,
		"collection": [], "sponsors": [{"hits": ["single", "double"]}], "player_progress": detail}
	var metrics: Dictionary = ClubPlayerProgress.metrics([run, run.duplicate(true)])
	_check(metrics.clean_total == 16 and metrics.strikeouts_total == 12,
		"career effort persists across abandoned seasons")
	_check(metrics.season_win_streak == 2 and metrics.season_hit_types == 2,
		"season streak and variety do not combine across seasons")
	_check(metrics.completed_seasons == 0 and metrics.get("no_bat_season", 0) == 0,
		"abandonment cannot claim completed-season restriction")
	_check(metrics.winning_hitters == 4 and metrics.shutout == 1,
		"actual recorded score plus human game proof derive feats")
	run.player_progress = null
	metrics = ClubPlayerProgress.metrics([run])
	_check(not metrics.has("strikeouts_total") and not metrics.has("contact_runs"),
		"legacy score alone cannot invent strikeouts or no-home-run proof")
	var result: Dictionary = {}
	var row: Dictionary = {"stats": null, "sponsors": 3, "end_half": 9, "deficit": 3}
	ClubPlayerProgress._game_metrics(result, row, [0, 1, 0, 3, 4], true)
	_check(result.walkoff == 1 and result.comeback_deficit == 3 and result.game_sponsors == 3,
		"home final-inning comeback and sponsor build")
	result = {}
	row.end_half = 8
	ClubPlayerProgress._game_metrics(result, row, [0, 1, 0, 3, 4], true)
	_check(result.walkoff == 0, "home win after top fifth is not walkoff")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
