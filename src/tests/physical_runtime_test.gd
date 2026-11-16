extends Node
## Explicit real-clock benchmark. No score substitution, time scaling or skipped physics.

var _report: Dictionary = {}
var _error: String = ""
var _frames: int = 0
var _failures: int = 0


func _ready() -> void:
	var season: SeasonState = SeasonState.create(443, true, true, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var before: Dictionary = SeasonSave.snapshot(season)
	var state: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	runner.finished.connect(func(report: Dictionary) -> void: _report = report)
	runner.failed.connect(func(reason: String) -> void: _error = reason)
	var start: int = Time.get_ticks_usec()
	_check(runner.start(state, 47), "ordinary current-policy physical job starts")
	while runner._running and _frames < 150000:
		await get_tree().physics_frame
		_frames += 1
	var wall_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	_check(not runner._running and _error.is_empty() and not _report.is_empty(),
		"real physical job finishes without fallback")
	if runner._running:
		runner.cancel()
	if not _report.is_empty():
		_audit(wall_ms)
	_check(ClubCareer.same(before, SeasonSave.snapshot(season)), "benchmark never settles the owner")
	runner.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro physical runtime checks passed: measured actual physics and validation.")
	get_tree().quit(0 if _failures == 0 else 1)


func _audit(wall_ms: float) -> void:
	var text: String = JSON.stringify(_report, "", true, true)
	var timings: Array = []
	for repeat in range(5):
		var start: int = Time.get_ticks_usec()
		_check(PhysicalMatchReport.valid(JSON.parse_string(text)), "full parsed report validation")
		timings.append((Time.get_ticks_usec() - start) / 1000.0)
	print("PHYSICAL_RUNTIME ", JSON.stringify({"wall_ms": wall_ms, "physics_frames": _frames,
		"simulated_seconds": _report.elapsed, "releases": _report.releases.size(),
		"score": [_report.away_runs, _report.home_runs], "report_bytes": text.to_utf8_buffer().size(),
		"parse_validate_ms": timings, "physics_hz": Engine.physics_ticks_per_second,
		"time_scale": Engine.time_scale, "max_fps": Engine.max_fps,
		"engine": Engine.get_version_info().string}))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runtime-report="):
			var file: FileAccess = FileAccess.open(argument.trim_prefix("--runtime-report="),
				FileAccess.WRITE)
			_check(file != null, "benchmark evidence file opens")
			if file != null:
				file.store_string(text)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
