extends "res://src/tests/season_opponent_base_rounds_test.gd"
# Historical full-roster fixture; permanent-player defaults have separate integration tests.
## Production default backend: killed-child fallback, atomic round, durable process restart.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://process-ui-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://process-ui-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_app.begin_season(443, true, _permanent_players(), _home_stadium())
	_prepare_season()
	for pick in range(4):
		_app.choose_player(_app.season.offers()[0])
	for round_number in range(2):
		var fixture: Dictionary = _app.season.pending_fixture()
		var report: Dictionary = await _human_report(_app.season, fixture)
		if report.is_empty():
			break
		_app.round_ui.process_jobs = true
		var human: Array = [fixture.id, report.away_runs, report.home_runs,
			report.performance, [], [], {}, [], [], {}, {}, [], _opponent_row(report, fixture)]
		if not _app.season.home_property.is_empty():
			human.append([])
			human.append(StadiumLayoutSnapshot.key(report.get("property", {})))
		_app.round_ui.begin(human)
		_check(_app.round_ui.process_runner.running, "normal desktop UI starts independent physics")
		if round_number == 0:
			await _killed_child()
		else:
			await _restart_partial()
		await _wait_round()
		_audit_season()
	_check(_app.season.player_results.size() == 2 and _app.season.physical.reports.size() == 4,
		"two rounds atomically settle six actual physical games")
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro physical process UI checks passed: fallback, restart and exact round replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _killed_child() -> void:
	get_window().size = Vector2i(700, 400)
	await get_tree().process_frame
	await _capture("process-round-running-small")
	var checkpoint: String = FileAccess.get_file_as_string(SeasonSave.path)
	# Revalidate after every awaited frame/capture; a failed child may reset _pid to -1.
	var child_pid: int = _kill_probe_pid()
	if child_pid <= 0:
		_check(false, "kill probe requires this test's running positive child PID")
		return
	# External termination preserves Godot's child handle for its normal exit-code reader.
	if OS.get_name() == "Windows":
		OS.execute("taskkill", ["/PID", str(child_pid), "/F"])
	else:
		OS.execute("kill", ["-TERM", str(child_pid)])
	var started: int = Time.get_ticks_msec()
	while _app.round_ui._working and Time.get_ticks_msec() - started < 10000:
		await get_tree().process_frame
	_check(not _app.round_ui._working and not _app.round_ui.process_jobs,
		"failed child pauses and selects explicit slower retry")
	_check(FileAccess.get_file_as_string(SeasonSave.path) == checkpoint,
		"failed child cannot publish a partial result")
	await _capture("process-round-fallback-small")
	get_window().size = Vector2i(1280, 720)
	_app.round_ui.resume()
	_check(_app.round_ui.runner._running and not _app.round_ui.process_runner.running,
		"retry uses the original physical runner")


func _restart_partial() -> void:
	var started: int = Time.get_ticks_msec()
	while _app.season.physical.pending.get("reports", []).is_empty() \
		and _app.round_ui._working and Time.get_ticks_msec() - started < 180000:
		await get_tree().process_frame
	_check(_app.season.physical.pending.get("reports", []).size() == 1,
		"first independent game saves before starting the second")
	_app.round_ui.cancel()
	_check(not _app.round_ui.process_runner.running, "Pause stops active child")
	var saved: SeasonState = SeasonSave.restore()
	_check(saved != null and saved.physical.pending.reports.size() == 1,
		"completed child report survives the normal save reader")
	_app.queue_free()
	await get_tree().process_frame
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_check(_app.round_ui.process_jobs and not _app.round_ui._working,
		"restarted default backend awaits owner Resume")
	await _capture("process-round-restored")
	_app.round_ui.resume()


func _wait_round() -> void:
	var started: int = Time.get_ticks_msec()
	while _app.round_ui._working and Time.get_ticks_msec() - started < 300000:
		await get_tree().process_frame
	_check(_app.season.physical.pending.is_empty(), "whole round finishes within benchmark window")


func _permanent_players() -> bool:
	return false # Preserve the historical full-roster fixture.


func _prepare_season() -> void:
	pass


func _home_stadium() -> bool:
	return false # Preserve the historical field for older ownership/process fixtures.


func _kill_probe_pid() -> int:
	# No caller-supplied PID: read only this test's current owned runner.
	if not is_instance_valid(_app) or _app.is_queued_for_deletion() \
		or not _app.is_inside_tree() or not is_instance_valid(_app.round_ui):
		return -1
	var owner: SeasonRoundUI = _app.round_ui
	if owner.is_queued_for_deletion() or owner.get_parent() != _app \
		or owner.app != _app or not is_instance_valid(owner.process_runner):
		return -1
	var worker: PhysicalRoundProcess = owner.process_runner
	if worker.is_queued_for_deletion() or worker.get_parent() != owner \
		or not worker.is_inside_tree() or not worker.running:
		return -1
	var child_pid: int = worker._pid
	if child_pid <= 0 or child_pid == OS.get_process_id() \
		or not OS.is_process_running(child_pid):
		return -1
	return child_pid
