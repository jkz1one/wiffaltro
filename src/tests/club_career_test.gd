extends "res://src/tests/paid_shop_ui_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_contracts()
	await _career_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro club career checks passed: rewards, history, abandonment, atomic saves and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _new(seed_value: int = 51, club: ClubCareer = null) -> SeasonState:
	var season: SeasonState = SeasonState.create(seed_value, false, true, true)
	season.career = ClubCareer.new() if club == null else club
	_check(season.career.start(season), "new tracked run starts only before draft")
	for pick in range(4):
		season.choose_player(season.offers()[0])
	return season


func _record(season: SeasonState, win: bool = true) -> void:
	var fixture: Dictionary = season.pending_fixture()
	var home_wins: bool = (fixture.home == 0) == win
	_check(
		season.record_player_result(fixture.id, 0 if home_wins else 1, 1 if home_wins else 0),
		"actual scheduled result"
	)


func _finish(season: SeasonState, outcome: String) -> void:
	while season.phase != SeasonState.Phase.COMPLETE:
		var win: bool = outcome != "missed"
		if season.phase == SeasonState.Phase.SEMIFINAL and outcome == "semifinal":
			win = false
		if season.phase == SeasonState.Phase.FINAL and outcome == "runner_up":
			win = false
		_record(season, win)


func _contracts() -> void:
	SeasonSave.path = "user://career-contract-%d.json" % OS.get_process_id()
	for finish: String in ["missed", "semifinal", "runner_up", "champion"]:
		var season: SeasonState = _new()
		_check(season.career.balance() == 0, "zero starting Club Bucks")
		_finish(season, finish)
		_check(season.career.balance() == 0, "unsaved completion never publishes reward")
		_check(SeasonSave.save(season), "atomic completion checkpoint")
		var expected: int = {"missed": 35, "semifinal": 80, "runner_up": 110, "champion": 220}[finish]
		_check(season.career.balance() == expected, "correct finish, regular bonus and first clear")
		_check(
			season.career.runs[-1].receipt.finish == finish, "finish derived from complete bracket"
		)
		var saved: Dictionary = season.career.to_data()
		_check(
			(
				SeasonSave.save(season)
				and ClubCareer.same(SeasonSave.restore().career.to_data(), saved)
			),
			"duplicate save/reload cannot repay"
		)
		for field: String in [
			"receipt", "score", "draw", "seed", "current", "tier", "status", "extra"
		]:
			var bad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
			match field:
				"receipt":
					bad.career.runs[-1].receipt.total += 1
				"score":
					bad.career.runs[-1].proof.scores[0][0] = 7
				"draw":
					bad.career.runs[-1].proof.draws[0] += 0.000000000001
				"seed":
					bad.career.runs[-1].seed += 1
				"current":
					bad.career.current = 0
				"tier":
					bad.career.runs[-1].tier = 1
				"status":
					bad.career.runs[-1].status = "abandoned"
				"extra":
					bad.career.wallet = 999
			_check(SeasonSave._decode(bad) == null, "reject inconsistent club " + field)
	_repeat_and_retry()
	var legacy: SeasonState = SeasonState.create(5, false, true, true)
	_check(
		SeasonSave.save(legacy) and SeasonSave.restore().career == null,
		"old Working saves gain no invented career or rewards"
	)
	_cleanup()


func _repeat_and_retry() -> void:
	var season: SeasonState = _new()
	_finish(season, "champion")
	_check(SeasonSave.save(season), "first title saved")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "close completed history without abandonment")
	var repeat: SeasonState = _new(51, club)
	_check(
		repeat.career.current == 2 and repeat.career.balance() == 220,
		"same seed is a distinct season, keeps earned balance"
	)
	for game in range(11):
		_record(repeat)
	_check(SeasonSave.save(repeat), "pregame final checkpoint")
	var before: Dictionary = repeat.career.to_data()
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	_record(repeat)
	SeasonSave.path = path + "/missing/save.json"
	_check(
		not SeasonSave.save(repeat) and ClubCareer.same(before, repeat.career.to_data()),
		"failed completion publishes no career mutation"
	)
	SeasonSave.path = path
	_check(
		(
			FileAccess.get_file_as_string(path) == bytes
			and SeasonSave.restore().career.balance() == 220
		),
		"previous entire season and balance survive"
	)
	_check(
		SeasonSave.save(repeat) and repeat.career.balance() == 415,
		"repeat title pays 195 once, without first-clear bonus"
	)
	_check(
		SeasonSave.save(repeat) and SeasonSave.restore().career.balance() == 415, "retry idempotent"
	)
	club = repeat.career.fork()
	_check(club.close(repeat), "retain both titles")
	var unfinished: SeasonState = _new(51, club)
	_record(unfinished)
	_check(SeasonSave.save(unfinished), "ordinary progress saves without abandonment")
	_check(unfinished.career.runs[-1].status == "active", "save/quit is not abandonment")
	club = unfinished.career.fork()
	_check(club.close(unfinished), "explicit replacement abandons active season")
	var fresh: SeasonState = _new(51, club)
	_check(
		(
			fresh.career.runs[2].status == "abandoned"
			and fresh.career.balance() == 415
			and fresh.career.cleared()
		),
		"abandonment pays zero and preserves clear/history"
	)
	_check(fresh.cash() == 0 and fresh.build.revision() == 0, "seasonal power and cash reset")
	_check(SeasonSave.save(fresh), "new season and prior abandonment persist together")
	var backup: String = FileAccess.get_file_as_string(SeasonSave.path + ".bak")
	var file: FileAccess = FileAccess.open(SeasonSave.path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	_check(
		SeasonSave.restore() != null and not SeasonSave.last_error.is_empty(),
		"valid career backup recovers"
	)
	_check(
		FileAccess.get_file_as_string(SeasonSave.path + ".bak") == backup,
		"recovery never rewrites backup"
	)


func _career_ui() -> void:
	SeasonSave.path = "user://career-ui-%d.json" % OS.get_process_id()
	_cleanup()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(51, true)
	# Historical score-only fixture; physical rounds have separate integration coverage.
	app.season.physical = null
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
	_finish(app.season, "champion")
	_check(app._checkpoint(), "UI completed season settles")
	app.show_season()
	await _menu_bounds(app, "career-completion")
	await _click(_button(app.menu, "CLUB RECORD"))
	await _menu_bounds(app, "career-history")
	var before: String = FileAccess.get_file_as_string(SeasonSave.path)
	await _click(_button(app.menu, "VIEW SEASON #1"))
	await _menu_bounds(app, "career-detail")
	await _click(_button(app.menu, "BACK TO CLUB RECORD"))
	await _click(_button(app.menu, "MAIN MENU"))
	await _click(_button(app.menu, "NEW WORKING SEASON"))
	await _click(app._dialog.get_cancel_button())
	_check(
		(
			FileAccess.get_file_as_string(SeasonSave.path) == before
			and app.season.career.balance() == 220
		),
		"review/cancel does not write, abandon or pay"
	)
	var previous: SeasonState = app.season
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	app.begin_season(51, true)
	# Historical score-only fixture; physical rounds have separate integration coverage.
	app.season.physical = null
	_check(
		app.season == previous and app.season.career.current == 1,
		"failed replacement preserves exact prior season"
	)
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == before, "failed replacement preserves bytes")
	await _click(_button(app.menu, "NEW WORKING SEASON"))
	await _click(app._dialog.get_ok_button())
	_check(
		app.season.career.current == 2 and app.season.career.balance() == 220,
		"confirmed replacement retains history and money"
	)
	app.begin_season(99, false)
	_check(
		app.season.career.current == 0 and app.season.career.balance() == 220,
		"switch to legacy season retains club"
	)
	_check(
		app.season.career.runs[-1].status == "abandoned",
		"unfinished Working run recorded abandoned"
	)
	app.menu.show_home()
	await _click(_button(app.menu, "CLUB RECORD"))
	await _menu_bounds(app, "career-retained-in-legacy")
	_check(SeasonSave.restore().career.balance() == 220, "legacy save reload keeps career")
	app.queue_free()
	await _frames()
	_cleanup()
	var file: FileAccess = FileAccess.open(SeasonSave.path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var blocked: SeasonApp = SeasonApp.new()
	add_child(blocked)
	await _frames()
	blocked.begin_season(51, true)
	_check(
		blocked.season == null and FileAccess.get_file_as_string(SeasonSave.path) == "{broken",
		"unreadable career cannot be silently replaced"
	)
	blocked.queue_free()
	await _frames()
	_cleanup()


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
