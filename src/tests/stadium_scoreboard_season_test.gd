extends "res://src/tests/physical_round_process_ui_test.gd"
## Actual report12 home settlement, production child failure/retry and complete14 save/restart.

const ScoreboardFixture = preload("res://src/tests/stadium_scoreboard_season_fixture.gd")

var _scoreboard: ScoreboardFixture = ScoreboardFixture.new()


func _permanent_players() -> bool:
	return true


func _home_stadium() -> bool:
	return true


func _prepare_season() -> void:
	_scoreboard.prepare(_app, _check, true)


func _human_report(season: SeasonState, fixture: Dictionary) -> Dictionary:
	var before: Dictionary = SeasonSave.snapshot(season)
	var report: Dictionary = await super._human_report(season, fixture)
	_scoreboard.observe(season, fixture, report, before, _check)
	return report


func _killed_child() -> void:
	# A failed admission must never signal PID0 or an unowned process.
	if not _app.round_ui.process_runner.running or _app.round_ui.process_runner._pid <= 0:
		_check(false, "kill probe requires this test's running positive child PID")
		get_tree().quit(1)
		return
	var before: Dictionary = SeasonSave.snapshot(_app.season)
	_scoreboard.checkpoint(_app.season, _check)
	await super._killed_child()
	_check(ClubCareer.same(before, SeasonSave.snapshot(_app.season)),
		"killed production child and slower restart publish no human result or ownership mutation")
	_scoreboard.checkpoint(_app.season, _check)


func _restart_partial() -> void:
	var before: Dictionary = _app.season.career.to_data()
	await super._restart_partial()
	_check(_app.season.physical.pending.reports.size() == 1
		and ClubCareer.same(before, _app.season.career.to_data()),
		"completed child survives process restart without paying the pending human home game")
	_scoreboard.checkpoint(_app.season, _check)


func _audit_season() -> void:
	super._audit_season()
	_scoreboard.audit(_app.season, _check)
	if _app.season.player_results.size() == 2:
		_check(_scoreboard.home_reports == 1 and _app.season.physical.reports.size() == 4,
			"two ordinary rounds settle one owned-home report12 and five actual park games")
		if _failures == 0:
			print("Wiffaltro scoreboard season passed: report12 settlement, child retry and saved restart.")
