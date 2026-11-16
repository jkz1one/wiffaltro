extends Node
## Resume an archived real human pending76 checkpoint through the actual child process.
var failures: int = 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pending-fixture="):
			path = arg.trim_prefix("--pending-fixture=")
	var season: SeasonState = SeasonSave._decode(
		JSON.parse_string(FileAccess.get_file_as_string(path))
	)
	check(season != null and season.league_live, "archived pending76 restores")
	if season == null:
		get_tree().quit(1)
		return
	var original: Dictionary = SeasonSave.snapshot(season)
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	add_child(worker)
	var reports: Array[Dictionary] = []
	var errors: Array[String] = []
	worker.finished.connect(func(value: Dictionary) -> void: reports.append(value))
	worker.failed.connect(func(value: String) -> void: errors.append(value))
	check(worker.start(season), "live76 child process starts")
	worker.cancel()
	check(not worker.running and reports.is_empty(), "cancel publishes nothing")
	check(worker.start(season), "live76 child restarts")
	var start: int = Time.get_ticks_msec()
	while worker.running and Time.get_ticks_msec() - start < 240000:
		await get_tree().process_frame
	check(
		reports.size() == 1 and errors.is_empty(),
		"child returns validated report27: " + str(errors)
	)
	check(
		ClubCareer.same(original, SeasonSave.snapshot(season)),
		"worker never changes owner checkpoint"
	)
	if reports.size() == 1:
		check(reports[0].version == 27, "wrapper survives IPC JSON")
		var projected: Dictionary = SeasonRoundSettlement.project(season)
		var envelope: Dictionary = {
			"fixture": projected.fixture.id,
			"request": SeasonPhysicalFixtures.request_key(projected.candidate, projected.fixture),
			"report": reports[0]
		}
		season.physical.pending.reports.append(envelope)
		var cold: SeasonState = SeasonSave._decode(
			JSON.parse_string(JSON.stringify(SeasonSave.snapshot(season)))
		)
		check(
			cold != null and cold.physical.pending.reports.size() == 1,
			"returned report cold pending replay"
		)
	worker.cancel()
	worker.queue_free()
	await get_tree().process_frame
	print("League process failures: ", failures)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
