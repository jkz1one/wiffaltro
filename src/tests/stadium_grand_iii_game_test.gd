extends "res://src/tests/stadium_grand_i_game_test.gd"
## Exact Grand I helper inheritance; only explicit Grand III orchestration is overridden.
## Frozen predecessor assertions and thresholds remain unchanged.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--grand-iii-study-report-dir="):
			_report_dir = argument.trim_prefix("--grand-iii-study-report-dir=")
	var season: SeasonState = SeasonState.create(443, true, true, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var before: Dictionary = SeasonSave.snapshot(season)
	var source: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	var first: Dictionary = await _game(source, 47, 1)
	if first.is_empty() or _failures > 0:
		get_tree().quit(1)
		return
	var fixture: Dictionary = StadiumGrandIIIFixtureStudy.capture(first.venue)
	if not StadiumGrandIIIFixtureStudy.valid(fixture):
		_check(false, "complete-game canonical fixture capture succeeds")
		print(
			"GRAND_III_CAPTURE_DIAGNOSTIC ",
			StadiumGrandIIIFixtureStudy.capture_diagnostic(first.venue)
		)
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	var path: String = "user://grand-iii-study-fixture-%d.json" % OS.get_process_id()
	_check(
		StadiumGrandIIIFixtureStudy.save(path, fixture),
		"frozen authoring fixture persists atomically"
	)
	var loaded: Dictionary = StadiumGrandIIIFixtureStudy.load_file(path)
	_check(
		ClubCareer.same(loaded, fixture),
		"saved fixture loads without regenerated or missing pieces"
	)
	if not StadiumGrandIIIFixtureStudy.valid(loaded):
		_check(false, "complete-game saved fixture is valid before replay")
		DirAccess.remove_absolute(path)
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	var second: Dictionary = await _game(source, 47, 2, loaded)
	if not _report_dir.is_empty():
		var raw_first: String = FileAccess.get_file_as_string(
			_report_dir.path_join("grand-iii-game-1.json")
		)
		var raw_second: String = FileAccess.get_file_as_string(
			_report_dir.path_join("grand-iii-game-2.json")
		)
		_check(
			not raw_first.is_empty() and raw_first == raw_second,
			"both complete saved raw game files are byte-identical"
		)
	DirAccess.remove_absolute(path)
	_check(
		not second.is_empty() and ClubCareer.same(first, second),
		"same fresh teams, seed and complete candidate reproduce full observed game evidence"
	)
	_check(
		ClubCareer.same(before, SeasonSave.snapshot(season)),
		"detached authoring games do not award or mutate the originating season"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Grand III authoring games passed: two complete real games and exact study replay."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _game(source: MatchState, seed_value: int, ordinal: int, frozen: Variant = null) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(viewport)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_grand_iii_lab_only", true)
	lab._sky_backdrop_enabled = false
	viewport.add_child(lab)
	var installed: bool = (
		StadiumGrandIIILab.install(lab)
		if frozen == null
		else (StadiumGrandIIILab.install_frozen(lab, frozen))
	)
	_check(installed, "full game explicitly installs the requested isolated candidate")
	if _failures > 0:
		viewport.queue_free()
		return {}
	var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
	var venue: Dictionary = property.get_meta("candidate_venue").duplicate(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._configured_match = PhysicalMatchRequest.capture(source)
	_check(lab._configured_match != null, "authoring teams start from a fresh copied match")
	lab._automation = MatchAutomation.new()
	lab._automation.seed = seed_value
	# Automation was attached after the explicit lab opt-in, so adopt the ordinary runner pause mode.
	lab.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab._start_new_match()
	var progress: String = ""
	var stalled: int = 0
	var logged: int = -1
	var paused: bool = false
	var start: int = Time.get_ticks_usec()
	for frame in range(144000):
		await get_tree().physics_frame
		var state: MatchState = lab._match_state
		if state.phase == MatchState.Phase.GAME_END:
			break
		var next: String = (
			"%d:%d:%d" % [state.phase, state.plate_appearance_number, lab._throw_number]
		)
		stalled = stalled + 1 if next == progress else 0
		progress = next
		if stalled > 1800 or state.elapsed_seconds >= PhysicalMatchRunner.MAX_SECONDS:
			_check(false, "real candidate game exceeded the ordinary time/progress limit")
			break
		if lab._automation.releases.size() % 25 == 0 and logged != lab._automation.releases.size():
			logged = lab._automation.releases.size()
			print(
				"GRAND_III_GAME_PROGRESS game=",
				ordinal,
				" releases=",
				logged,
				" inning=",
				state.inning,
				" score=",
				state.away_team.runs,
				"-",
				state.home_team.runs
			)
		if not paused and lab._automation.releases.size() >= 3:
			paused = true
			var elapsed: float = state.elapsed_seconds
			var pitch: Vector3 = lab._pitch_actor.global_position
			get_tree().paused = true
			for wait_frame in range(4):
				await get_tree().process_frame
			_check(
				state.elapsed_seconds == elapsed and lab._pitch_actor.global_position == pitch,
				"pause interrupts the full candidate game without hidden motion or clock advancement"
			)
			get_tree().paused = false
	_check(
		lab._match_state.phase == MatchState.Phase.GAME_END,
		"candidate game reaches a real final score, without simulated-result fallback"
	)
	var report: Dictionary = {}
	if lab._match_state.phase == MatchState.Phase.GAME_END:
		report = _capture(lab, venue, seed_value)
		_audit(lab, report)
		_check(
			ClubCareer.same(venue, property.get_meta("candidate_venue")),
			"complete authored field stays frozen for the entire game"
		)
		print(
			"GRAND_III_GAME_COMPLETE game=",
			ordinal,
			" releases=",
			report.releases.size(),
			" score=",
			report.score,
			" simulated_seconds=",
			report.elapsed,
			" wall_ms=",
			(Time.get_ticks_usec() - start) / 1000.0,
			" evidence_sha=",
			JSON.stringify(report, "", true, true).sha256_text()
		)
		if not _report_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(_report_dir)
			var file: FileAccess = FileAccess.open(
				_report_dir.path_join("grand-iii-game-%d.json" % ordinal), FileAccess.WRITE
			)
			_check(file != null, "unqualified authoring evidence file opens")
			if file != null:
				file.store_string(JSON.stringify(report, "", true, true))
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	return report


func _capture(lab: PitchBatLab, venue: Dictionary, seed_value: int) -> Dictionary:
	var report: Dictionary = super._capture(lab, venue, seed_value)
	report.kind = "UNQUALIFIED_GRAND_III_AUTHORING_STUDY"
	report.version = "grand-iii-video-study-v2"
	return report
