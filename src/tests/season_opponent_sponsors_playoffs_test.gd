extends "res://src/tests/season_opponent_sponsors_visible_test.gd"
## Explicit long benchmark: every fixture, including the human slot, plays real physics.


func _ready() -> void:
	SeasonSave.path = "user://sponsor-playoffs-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://sponsor-playoffs-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_app.begin_season(443, true)
	for pick in range(4):
		_app.choose_player(_app.season.offers()[0])
	var started: int = Time.get_ticks_msec()
	var human_games: int = 0
	var releases: int = 0
	for round_number in range(12):
		var fixture: Dictionary = _app.season.pending_fixture()
		if fixture.is_empty():
			break
		var report: Dictionary = await _human_report(_app.season, fixture)
		if report.is_empty():
			break
		human_games += 1
		releases += report.releases.size()
		_app.round_ui.begin([fixture.id, report.away_runs, report.home_runs,
			report.performance, [], [], {}, [], [], {}, {}, []])
		await _wait_sponsor_round()
		_audit_season()
		print("NPC_SPONSOR_BRACKET round=", round_number + 1, " ", _probe.summary())
	_check(_app.season.phase == SeasonState.Phase.COMPLETE and _app.season.results.size() == 33,
		"complete actual six-club bracket includes both semifinals and final")
	_check(_app.season.physical.reports.size() + human_games == 33,
		"every scheduled fixture used actual physical events, including human-slot games")
	var purchases: int = 0
	var income: int = 0
	for club: Dictionary in _app.season.opponents.clubs.values():
		for decision: Dictionary in club.decisions:
			purchases += 1 if decision.stat == "sponsor" else 0
		for event: Dictionary in club.build.to_data().events:
			if event.op == "reward":
				income += int(club.build.income_for_game(int(event.game)).get("D01", 0))
	_check(purchases > 0 and income > 0, "actual season buys sponsors and earns walk income")
	_check(_app.season.career.runs[-1].has("receipt"), "derived career finish is paid")
	var saved: Dictionary = SeasonSave.snapshot(_app.season)
	var balance: int = _app.season.career.balance()
	_check(SeasonSave.save(_app.season) and ClubCareer.same(saved, SeasonSave.snapshot(_app.season))
		and _app.season.career.balance() == balance, "career and sponsor save do not pay twice")
	for row: Dictionary in _app.season.physical.reports:
		releases += row.report.releases.size()
	print("NPC_SPONSOR_FULL_SEASON games=33 human_slot=", human_games,
		" archived_ai=", _app.season.physical.reports.size(), " releases=", releases,
		" sponsors=", purchases, " income=", income, " career=", balance,
		" wall_ms=", Time.get_ticks_msec() - started,
		" saved_bytes=", FileAccess.get_file_as_bytes(SeasonSave.path).size())
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent sponsor playoff checks passed: 33 real games and exact career replay.")
	get_tree().quit(0 if _failures == 0 else 1)
