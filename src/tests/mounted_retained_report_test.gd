extends Node
var _report: Dictionary = {}
var _error: String = ""

func _ready() -> void:
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(FileAccess.get_file_as_string(
		OS.get_environment("MOUNTED_SAVE_FIXTURE"))))
	if season == null:
		push_error("retained input must cold-load")
		get_tree().quit(1)
		return
	var fixture: Dictionary = {}
	for row: Dictionary in season.schedule:
		if row.home == 0:
			fixture = row
			break
	var source: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	var request: String = SeasonPhysicalFixtures.request_key(season, fixture)
	var evidence: String = OS.get_environment("MOUNTED_RETAINED_REPORT")
	if OS.get_environment("MOUNTED_CAPTURE") == "1":
		var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
		add_child(runner)
		runner.finished.connect(func(report: Dictionary) -> void: _report = report)
		runner.failed.connect(func(reason: String) -> void: _error = reason)
		if not runner.start(source, int(source.stadium.environment.seed), PitchBatLab.FIELD_ID,
			ClubPlayers.assets(season.career)):
			push_error("baseline physical runner did not start")
			get_tree().quit(1)
			return
		for frame in range(200000):
			if not _report.is_empty() or not _error.is_empty():
				break
			await get_tree().process_frame
		runner.cancel()
		runner.queue_free()
		if _report.is_empty() or not _error.is_empty():
			push_error("baseline physical report missing: " + _error)
			get_tree().quit(1)
			return
		var file: FileAccess = FileAccess.open(evidence, FileAccess.WRITE)
		file.store_string(JSON.stringify({"fixture": fixture.id, "request": request,
			"report": _report}, "", true, true))
		file.close()
	var retained: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(evidence))
	var resolver: SeasonPhysicalFixtures = SeasonPhysicalFixtures.new()
	resolver.reports.append(retained)
	var ok: bool = retained.request == request and PhysicalMatchReport.valid(retained.report) \
		and PhysicalStadiumReport.matches(retained.report, source.stadium) \
		and not resolver.resolve(season, fixture).is_empty()
	print("MOUNTED_RETAINED_RESULT ", JSON.stringify({"pass": ok,
		"releases": retained.report.releases.size(), "request": request,
		"report_sha256": JSON.stringify(retained.report, "", true, true).sha256_text()}))
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if ok else 1)
