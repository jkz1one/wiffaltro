extends "res://src/tests/season_opponent_base_playoffs_test.gd"
## All33 real fixtures, five complete14 home games, exact inventory and once-only career reward.

const ScoreboardFixture = preload("res://src/tests/stadium_scoreboard_season_fixture.gd")

var _scoreboard: ScoreboardFixture = ScoreboardFixture.new()


func _permanent_players() -> bool:
	return true


func _home_stadium() -> bool:
	return true


func _prepare_season() -> void:
	_scoreboard.prepare(_app, _check)


func _human_report(season: SeasonState, fixture: Dictionary) -> Dictionary:
	var before: Dictionary = SeasonSave.snapshot(season)
	var report: Dictionary = await super._human_report(season, fixture)
	_scoreboard.observe(season, fixture, report, before, _check)
	return report


func _wait_sponsor_round() -> void:
	# The fixed-step parent has no active match during a child job. Its frame count
	# can outrun the independent physics; use the existing process-UI wall-time bound.
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 300000:
		await get_tree().process_frame
		if _app.season.physical.pending.is_empty():
			return
		if not _app.round_ui._working:
			_check(false, "scoreboard process round paused: " + _app.round_ui.detail.text)
			return
	_check(false, "scoreboard process round exceeded bounded wall-time budget")


func _audit_season() -> void:
	super._audit_season()
	_scoreboard.audit(_app.season, _check)
	if _app.season.phase == SeasonState.Phase.COMPLETE and _failures == 0:
		print("Wiffaltro scoreboard playoffs passed: 33 real games, exact paid ownership and archive.")
