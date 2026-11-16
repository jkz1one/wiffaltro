extends "res://src/tests/season_physical_round_test.gd"
## Twenty-three actual offscreen games; human losses are explicit scheduling fixtures.


func _ready() -> void:
	SeasonSave.path = "user://physical-playoffs-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://physical-playoffs-%d.cfg" % OS.get_process_id()
	var season: SeasonState = _new(true)
	_check(SeasonSave.save(season), "physical career begins")
	var app: SeasonApp = await _app()
	var started: int = Time.get_ticks_msec()
	for round_number in range(10):
		var fixture: Dictionary = app.season.pending_fixture()
		var home: bool = fixture.home == 0
		app.round_ui.begin([fixture.id, 1 if home else 0, 0 if home else 1,
			{}, [], [], {}, [], [], {}, {}, []])
		await _wait_round(app)
		_check(app.season.player_results.size() == round_number + 1,
			"each human scheduling fixture commits once")
		_check(SeasonSave.restore() != null and ClubCareer.same(
			SeasonSave.snapshot(SeasonSave.restore()), SeasonSave.snapshot(app.season)),
			"round reload uses exact saved evidence and ledgers")
	_check(app.season.phase == SeasonState.Phase.COMPLETE and app.season.results.size() == 33,
		"automatic semifinal and neutral final finish after human elimination")
	_check(app.season.physical.reports.size() == 23 and app.season.physical.pending.is_empty(),
		"twenty regular AI fixtures, both semifinals and final have physical evidence")
	_check(app.season.career.runs[-1].receipt.finish == "missed"
		and app.season.career.balance() == 35, "complete bracket pays the derived career finish once")
	for index in range(1, 6):
		var count: int = app.season.results.filter(
			func(row: Dictionary) -> bool: return row.home == index or row.away == index).size()
		_check(app.season.opponents.clubs[str(index)].build._bank.view().rewards.size() == count,
			"AI receives precisely its played fixtures, including elimination games")
	var pitches: int = 0
	var simulation: float = 0.0
	for row: Dictionary in app.season.physical.reports:
		pitches += row.report.releases.size()
		simulation += row.report.elapsed
	print("PHYSICAL_SEASON games=23 pitches=", pitches, " simulated_seconds=", simulation,
		" wall_ms=", Time.get_ticks_msec() - started,
		" saved_bytes=", FileAccess.get_file_as_bytes(SeasonSave.path).size())
	var saved: Dictionary = SeasonSave.snapshot(app.season)
	_check(SeasonSave.save(app.season) and ClubCareer.same(SeasonSave.snapshot(app.season), saved),
		"completed career save cannot pay twice")
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro physical playoff checks passed: full saved season and 23 real AI games.")
	get_tree().quit(0 if _failures == 0 else 1)


func _wait_round(app: SeasonApp) -> void:
	for frame in range(750000):
		await get_tree().physics_frame
		if app.season.physical.pending.is_empty():
			return
		if not app.round_ui._working:
			_check(false, "whole round stopped: " + app.round_ui.detail.text)
			return
	_check(false, "whole round exceeded bounded physical frame budget")
