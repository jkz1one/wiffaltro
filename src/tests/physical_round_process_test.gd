extends "res://src/tests/season_opponent_base_rounds_test.gd"
# Historical full-roster fixture; permanent-player defaults have separate integration tests.
## Complete child-process fixture, exact local parity, cancellation and hostile receipt rejection.


func _ready() -> void:
	SeasonSave.path = "user://process-check-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://process-check-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_app.begin_season(443, true, false)
	for pick in range(4):
		_app.choose_player(_app.season.offers()[0])
	var fixture: Dictionary = _app.season.pending_fixture()
	var human: Dictionary = await _human_report(_app.season, fixture)
	if human.is_empty():
		get_tree().quit(1)
		return
	_check(_app.round_ui.queue_human([fixture.id, human.away_runs, human.home_runs,
		human.performance, [], [], {}, [], [], {}, {}, [], _opponent_row(human, fixture)]),
		"completed human game is durably queued")
	var before: String = FileAccess.get_file_as_string(SeasonSave.path)
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	add_child(worker)
	var reports: Array[Dictionary] = []
	var errors: Array[String] = []
	worker.finished.connect(func(report: Dictionary) -> void: reports.append(report))
	worker.failed.connect(func(reason: String) -> void: errors.append(reason))
	_check(worker.start(_app.season), "same-binary child starts from pending checkpoint")
	var token: String = worker._token
	_check(not worker.start(_app.season), "busy worker cannot be overwritten")
	worker.cancel()
	await get_tree().process_frame
	_check(not worker.running and reports.is_empty() and errors.is_empty()
		and worker._pid == -1, "cancel releases only its own child without publishing")
	_check(not DirAccess.dir_exists_absolute(PhysicalJobFiles.directory(token)),
		"cancel removes job files")
	_check(worker.start(_app.season), "cancelled fixture restarts cleanly")
	var start: int = Time.get_ticks_msec()
	while worker.running and Time.get_ticks_msec() - start < 180000:
		await get_tree().process_frame
	_check(reports.size() == 1 and errors.is_empty(), "child completes one validated physical report")
	if reports.size() == 1:
		await _parity(worker, reports[0])
	_check(FileAccess.get_file_as_string(SeasonSave.path) == before,
		"child completion and cancellation never modify the owner's saved checkpoint")
	worker.queue_free()
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro physical process checks passed: "
			+ "same physics, isolated ownership and cancellation.")
	get_tree().quit(0 if _failures == 0 else 1)


func _parity(worker: PhysicalRoundProcess, report: Dictionary) -> void:
	var projection: Dictionary = SeasonRoundSettlement.project(_app.season)
	var local: Dictionary = await _human_report(projection.candidate, projection.fixture)
	_check(ClubCareer.same(local, report), "child/local fixed-step reports are exactly identical")
	_check(worker.start(_app.season), "new receipt authority starts for hostile-result checks")
	var envelope: Dictionary = {"version": 1, "token": worker._token,
		"request": worker._key, "fixture": int(worker._fixture.id), "report": report}
	_check(worker._valid(envelope), "matching fresh receipt validates normally")
	for key: String in ["token", "request", "fixture"]:
		var bad: Dictionary = envelope.duplicate(true)
		bad[key] = -1 if key == "fixture" else "wrong"
		_check(not worker._valid(bad), "mismatched authority rejects: " + key)
	var bad: Dictionary = envelope.duplicate(true)
	bad.report.away_runs += 1
	_check(not worker._valid(bad), "corrupted score cannot publish")
	worker.cancel()
	print("PROCESS_PARITY releases=", report.releases.size(), " score=",
		report.away_runs, ":", report.home_runs)
