extends "res://src/tests/paid_shop_ui_test.gd"
## Real offscreen games through durable round checkpoints; the human receipt is a score fixture.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://physical-round-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://physical-round-%d.cfg" % OS.get_process_id()
	await _round()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro physical round checks passed: saved jobs, "
			+ "two real fixtures and atomic settlement.")
	get_tree().quit(0 if _failures == 0 else 1)


func _round() -> void:
	var historical: SeasonState = _new(false)
	var fixture: Dictionary = historical.pending_fixture()
	_check(historical.record_player_result(fixture.id, 1, 2) and SeasonSave.save(historical),
		"historical season still saves through its frozen score resolver")
	var old_scores: Array = historical.results.duplicate(true)
	_check(SeasonSave.restore().physical == null
		and ClubCareer.same(SeasonSave.restore().results, old_scores), "old scores never rerun physics")
	var season: SeasonState = _new(true)
	_check(SeasonSave.save(season), "new physical format saves before any result")
	var ledgers: Dictionary = season.opponents.to_data()
	var bank: Dictionary = season.build.to_data()
	fixture = season.pending_fixture()
	_check(not season.record_player_result(fixture.id, 1, 2)
		and season.build.to_data() == bank, "direct incomplete settlement cannot mutate the season")
	var app: SeasonApp = await _app()
	app.round_ui.begin([fixture.id, 1, 2, {}, [], [], {}, [], [], {}, {}, []])
	await _frames()
	_check(app.round_ui._working and app.round_ui.runner._running, "real job starts after checkpoint")
	_check(get_viewport().get_visible_rect().encloses(app.round_ui.panel.get_global_rect()),
		"initial running layout fits before any viewport resize")
	await _capture(get_viewport(), "round-running")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape, true)
	await _frames()
	_check(app.season.results.is_empty() and ClubCareer.same(app.season.opponents.to_data(), ledgers)
		and ClubCareer.same(app.season.build.to_data(), bank), "cancel grants no results or club rewards")
	_check(not app.season.shop_available() and app.loadout._blocked(),
		"shopping and loadout mutations wait until atomic round settlement")
	var pending_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	_check(SeasonSave.restore().physical.pending.human[0] == fixture.id,
		"completed human score survives cancellation and restart")
	var good_path: String = SeasonSave.path
	SeasonSave.path = "user://missing-round-directory/season.json"
	app.round_ui.resume()
	_check(not app.round_ui._working and not app.round_ui.runner._running,
		"failed checkpoint does not start a job")
	SeasonSave.path = good_path
	_check(FileAccess.get_file_as_string(good_path) == pending_bytes, "failed save preserves bytes")
	app.queue_free()
	await _frames()
	app = await _app()
	_check(app.round_ui.shade.visible and not app.round_ui._working, "restored jobs wait for Resume")
	await _capture(get_viewport(), "round-restored")
	get_window().size = Vector2i(700, 400)
	await _frames()
	_check(get_viewport().get_visible_rect().encloses(app.round_ui.panel.get_global_rect()),
		"round lightbox fits the smaller viewport")
	_check(app.round_ui.action.size.y >= 48, "resume action retains its minimum height")
	await _capture(get_viewport(), "round-restored-small")
	get_window().size = Vector2i(1280, 720)
	await _frames()
	await _click(app.round_ui.action)
	var runner: PhysicalMatchRunner = app.round_ui.runner
	runner._elapsed = PhysicalMatchRunner.MAX_SECONDS
	await get_tree().process_frame
	_check(not app.round_ui._working and runner._lab == null, "physical failure exposes retry")
	await _capture(get_viewport(), "round-failure")
	await _click(app.round_ui.action)
	var before_report: String = FileAccess.get_file_as_string(good_path)
	SeasonSave.path = "user://missing-round-directory/season.json"
	await _wait_reports(app, 1)
	_check(app.season.physical.pending.reports.size() == 1, "first actual fixture checkpoints")
	_check(not app.round_ui._working and FileAccess.get_file_as_string(good_path) == before_report,
		"completed report save failure preserves the prior checkpoint and pauses")
	SeasonSave.path = good_path
	_check(SeasonSave.restore().physical.pending.reports.is_empty(),
		"failed report write never publishes a partial round")
	app.round_ui.resume()
	await _frames()
	# Stop the next fixture, then rebuild a fresh App from the saved prefix.
	app.round_ui.cancel()
	_check(SeasonSave.restore().physical.pending.reports.size() == 1,
		"completed AI report survives restart independently of unfinished job")
	_tamper(app.season)
	app.queue_free()
	await _frames()
	app = await _app()
	app.round_ui.resume()
	await _wait_reports(app, 2)
	_check(app.season.player_results.size() == 1 and app.season.results.size() == 3
		and app.season.physical.reports.size() == 2 and app.season.physical.pending.is_empty(),
		"one human receipt and both physical scores settle together")
	await _capture(get_viewport(), "round-complete")
	var saved: Dictionary = SeasonSave.snapshot(app.season)
	_check(SeasonSave.restore() != null and ClubCareer.same(
		SeasonSave.snapshot(SeasonSave.restore()), saved),
		"save replay reproduces reports and every ledger"
	)
	for club: Dictionary in app.season.opponents.clubs.values():
		_check(club.build._bank.view().rewards.size() == 1,
			"each AI club has exactly one own-fixture reward")
	_check(app.season.build._bank.view().rewards.size() == 1, "human reward pays exactly once")
	_check(SeasonSave.save(app.season) and ClubCareer.same(SeasonSave.snapshot(app.season), saved),
		"duplicate save does not rerun games, buy again or change receipts")
	var bad: Dictionary = saved.duplicate(true)
	bad.physical.reports.pop_back()
	_check(SeasonSave._decode(bad) == null,
		"missing committed report cannot fall back to invented score"
	)
	bad = saved.duplicate(true)
	bad.physical.reports.append(bad.physical.reports[0].duplicate(true))
	_check(SeasonSave._decode(bad) == null, "duplicate/unused report rejected")
	bad = saved.duplicate(true)
	bad.opponents.clubs["1"].cursor += 1
	_check(SeasonSave._decode(bad) == null, "AI checkout state must exactly replay")
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _new(physical: bool) -> SeasonState:
	var season: SeasonState = SeasonState.create(443, false, true, true)
	season.career = ClubCareer.new()
	_check(season.career.start(season), "tracked club starts")
	if physical:
		season.physical = SeasonPhysicalFixtures.new()
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "draft completes")
	return season


func _app() -> SeasonApp:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	return app


func _wait_reports(app: SeasonApp, count: int) -> void:
	for frame in range(150000):
		await get_tree().physics_frame
		if (app.season.physical.reports.size() >= count
			or app.season.physical.pending.get("reports", []).size() >= count):
			return
		if not app.round_ui._working:
			_check(false, "round stopped unexpectedly: " + app.round_ui.detail.text)
			return
	_check(false, "physical fixture exceeded bounded frame budget")


func _tamper(season: SeasonState) -> void:
	var data: Dictionary = SeasonSave.snapshot(season)
	for field: String in ["request", "fixture", "seed", "version", "difficulty", "capacity", "extra"]:
		var bad: Dictionary = data.duplicate(true)
		match field:
			"request": bad.physical.pending.reports[0].request = "a".repeat(64)
			"fixture": bad.physical.pending.reports[0].fixture = 32
			"seed": bad.physical.pending.reports[0].report.seed += 1
			"version": bad.physical.version = 2
			"difficulty": bad.difficulty = 2
			"capacity":
				var team: Dictionary = bad.physical.pending.reports[0].report.teams[0]
				team.workload[team.roster[0]].capacity += 1.0
			"extra": bad.physical.pending.injected = true
		_check(SeasonSave._decode(bad) == null, "reject inconsistent pending " + field)
	var before: Dictionary = season.build.to_data()
	var proposal: Dictionary = SeasonRoundSettlement.project(season)
	_check(proposal.has("fixture") and season.build.to_data() == before,
		"job discovery pays only the disposable candidate")
