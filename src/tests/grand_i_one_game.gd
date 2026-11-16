extends Node
## Explicit neutral qualification: one genuine detached game, no earned final or settlement.
## Persist only the genuine drafted save. Fixture32 participants are an in-memory test binding.
# gdlint: disable=max-returns,max-file-lines

const FIXTURE = preload("res://src/tests/grand_i_public_fixture.gd")
const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const MAX_FRAMES: int = 144120
const MAX_WALL_MSEC: int = 1750000
const MAX_JSON_BYTES: int = 8 * 1024 * 1024
const OPERANDS: Array[String] = ["grand-i-prepared-save.json", "grand-i-drafted-save.json",
	"grand-i-fixture32.json", "grand-i-memory-before.json", "grand-i-report19.json",
	"grand-i-memory-after.json", "grand-i-restored-save-after.json", "public-season.json"]
var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _output: String = ""
var _admitted: bool = false
var _started: int = 0
var _runner: PhysicalMatchRunner
var _lab: PitchBatLab
var _report: Dictionary = {}
var _reports: int = 0
var _runner_error: String = ""
var _samples: Array[Dictionary] = []
var _terminal: Dictionary = {}
var _save_sha: String = ""
var _complete: bool = false


func _ready() -> void:
	_started = Time.get_ticks_msec()
	var expected: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--grand-i-game-dir="):
			_output = argument.trim_prefix("--grand-i-game-dir=")
		elif argument.begins_with("--grand-i-game-runtime="):
			expected = argument.trim_prefix("--grand-i-game-runtime=")
		elif argument.begins_with("--grand-i-game-execution="):
			_execution = argument.trim_prefix("--grand-i-game-execution=")
		elif argument.begins_with("--grand-i-game-nonce="):
			_nonce = argument.trim_prefix("--grand-i-game-nonce=")
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if _check(args.size() == 5 and args.has("--physical-in-process")
		and _runtime.length() == 64 and _runtime == expected
		and _execution.length() == 64 and _nonce.length() == 32, "exact source and run arguments"):
		await _run()
	if is_instance_valid(_runner):
		_runner.cancel()
		_runner.queue_free()
	await TestAudioDrain.finish(get_tree())
	var exact: Dictionary = {}
	if _failures == 0 and _complete:
		var candidate: Dictionary = _native_exact()
		if _check(candidate.assertions == 7 and candidate.failures == 0,
			"seven exact native canonical comparisons and unchanged save bytes"):
			exact = candidate
			print("GRAND_I_GAME_EXACT ", JSON.stringify(exact, "", true, true))
	_write("grand-i-one-game-summary.json", {
		"schema": "GRAND-I-ONE-GAME-v1", "pid": OS.get_process_id(),
		"runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"checks": _checks, "failures": _failures, "failed": _failed,
		"status": "completed" if _complete and _failures == 0 else "failed",
		"runner_error": _runner_error, "reports": _reports,
		"completed_games": 1 if _complete and _failures == 0 else 0,
		"season_seed": 6, "fixture": 32, "away": 0, "batting_home": 1,
		"venue_owner": "finals-venue:grand-i:v1", "explicit_qualification": true,
		"synthetic_participants": true, "earned_final": false, "settled": false,
		"public_selection_released": false, "manual_input_qualified": false,
		"performance_qualified": false, "independent_seed47_replay": false,
		"saved_draft_sha256": _save_sha, "native_exact": exact,
		"terminal": _terminal, "samples": _samples,
		"wall_seconds": (Time.get_ticks_msec() - _started) / 1000.0})
	print("GRAND_I_ONE_GAME checks=%d failures=%d reports=%d source=%s" % [
		_checks, _failures, _reports, _runtime])
	get_tree().quit(0 if _complete and _failures == 0 else 1)


func _run() -> void:
	if not _check(_output.is_absolute_path() and not _output.is_empty()
		and DirAccess.make_dir_recursive_absolute(_output) == OK
		and DirAccess.get_files_at(_output).is_empty()
		and DirAccess.get_directories_at(_output).is_empty(), "fresh isolated output"):
		return
	_admitted = true
	SeasonSave.path = _output.path_join("public-season.json")
	PitchBatLabSettings.path = _output.path_join("public-settings.cfg")
	if not _check(_clock_valid(), "ordinary unpaused fixed60 clock"):
		return
	var prepared: SeasonState = FIXTURE.season()
	if not _check(prepared != null and prepared.results.is_empty()
		and prepared.player_results.is_empty() and prepared.physical.reports.is_empty()
		and prepared.physical.pending.is_empty() and prepared.final_fixture.is_empty()
		and SeasonFinalVenue.matches_season(prepared),
		"genuine completed draft and pre-draft fixed venue"):
		return
	var initial: Dictionary = SeasonSave.snapshot(prepared).duplicate(true)
	_write(OPERANDS[0], initial)
	if not _check(initial.version == 63 and initial.opponents.policy == 13
		and SeasonSave.save(prepared), "genuine current-policy drafted save63 written once"):
		return
	_save_sha = FileAccess.get_sha256(SeasonSave.path)
	var season: SeasonState = SeasonSave.restore()
	if not _check(season != null and ClubCareer.same(initial, SeasonSave.snapshot(season)),
		"exact engine-canonical draft restore before explicit test binding"):
		return
	_write(OPERANDS[1], SeasonSave.snapshot(season))
	var original_phase: int = season.phase
	var fixture: Dictionary = FIXTURE.fixture(season)
	var expected: Dictionary = SeasonFinalVenue.for_fixture(season, fixture)
	var source: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	if not _check(ClubCareer.same(fixture,
		{"id": 32, "round": 11, "away": 0, "home": 1, "neutral": true})
		and _binding(expected, season, fixture) and source != null
		and ClubCareer.same(source.stadium, expected)
		and not source.away_team.ai_base and source.home_team.ai_base,
		"explicit neutral32 binds saved venue independently of batting home and player away role"):
		return
	_write(OPERANDS[2], {"fixture": fixture, "property": expected})
	var before: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	_write(OPERANDS[3], before)
	_runner = PhysicalMatchRunner.new()
	add_child(_runner)
	_runner.failed.connect(func(reason: String) -> void: _runner_error = reason)
	_runner.finished.connect(_finished)
	if not _check(_runner.start(source, SeasonPhysicalFixtures.seed_for(season, fixture),
		&"field.npc_venue", null, {}, season) and _runner._running and _runner._lab != null,
		"ordinary detached PhysicalMatchRunner starts one fresh real game"):
		return
	_lab = _runner._lab
	var live: WeakRef = weakref(_lab)
	var property: StadiumNpcPublicProperty = R._property(_lab)
	if not _check(property != null and property.issued and property.public_bound
		and property.venue_id == "GRAND-I" and property.objects.size() == 75
		and property.ordinary_callbacks() and property.callback_intact()
		and StadiumGrandIEnvironmentV1.installed(_lab, property.environment_lease)
		and not _lab._managed_match and not _lab._player_home
		and _lab._npc_season == season and _lab._automation != null
		and R.installed_bound(_lab, expected)
		and StadiumNpcSnapshot.matches_fixture(_lab._match_state.stadium, season, fixture),
		"ordinary public callback graph, detached automation and exact player-away neutral roles"):
		return
	_log_sample("started")
	var next_sample: int = Time.get_ticks_msec() + 10000
	for frame: int in range(MAX_FRAMES):
		if _reports > 0:
			break
		if not _runner_error.is_empty() or not _runner._running \
			or not is_instance_valid(_runner._lab) or not _clock_valid():
			_check(false, "runner failed or stopped before a natural complete report: " + _runner_error)
			return
		if _lab.has_meta("stadium_npc_runtime_interrupted") or _lab._automation == null \
			or _runner._elapsed >= PhysicalMatchRunner.MAX_SECONDS \
			or _runner._stalled >= PhysicalMatchRunner.STALL_SECONDS \
			or Time.get_ticks_msec() - _started >= MAX_WALL_MSEC:
			_check(false, "ordinary game interrupted or exceeded existing progress/time bounds")
			return
		if Time.get_ticks_msec() >= next_sample:
			_log_sample("progress")
			next_sample = Time.get_ticks_msec() + 10000
		await get_tree().physics_frame
	if not _check(_reports == 1 and _runner_error.is_empty() and not _report.is_empty()
		and _terminal.get("phase") == MatchState.Phase.GAME_END
		and _terminal.get("releases", 0) > 0 and _terminal.get("plays", 0) > 0,
		"one natural full game emits one terminal report with real releases and plays"):
		return
	if not _check(_report.get("version") == 19
		and _report.get("resolver") == StadiumGrandIPublicReport.RESOLVER
		and PhysicalMatchReport.valid(_report) and StadiumGrandIPublicReport.valid(_report)
		and StadiumGrandIPublicReport.matches(_report, expected),
		"complete real report19 validates against exact neutral fixture32 saved venue"):
		return
	_write(OPERANDS[4], _report)
	var decoded: Variant = JSON.parse_string(JSON.stringify(_report, "", true, true))
	_check(PhysicalMatchReport.valid(decoded) and StadiumGrandIPublicReport.valid(decoded)
		and ClubCareer.same(_report, decoded), "actual report19 full-precision JSON reload")
	_report_refusals(_report)
	await get_tree().process_frame
	_check(not _runner._running and _runner._lab == null and _runner._viewport == null
		and live.get_ref() == null, "ordinary successful runner disposes actual lab")
	var after: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	_write(OPERANDS[5], after)
	_check(ClubCareer.same(before, after) and season.phase == original_phase
		and ClubCareer.same(fixture, season.final_fixture)
		and _binding(SeasonFinalVenue.for_fixture(season, fixture), season, fixture)
		and season.results.is_empty() and season.player_results.is_empty()
		and season.physical.reports.is_empty() and season.physical.pending.is_empty(),
		"explicit in-memory binding and season remain exact with no result, archive or settlement")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(initial, SeasonSave.snapshot(restored))
		and restored.final_fixture.is_empty() and FileAccess.get_sha256(SeasonSave.path) == _save_sha
		and not FileAccess.file_exists(SeasonSave.path + ".bak")
		and not FileAccess.file_exists(SeasonSave.path + ".tmp"),
		"original drafted save bytes and ordinary restore unchanged; synthetic final never persisted")
	if restored != null:
		_write(OPERANDS[6], SeasonSave.snapshot(restored))
	_complete = _failures == 0


func _finished(report: Dictionary) -> void:
	_reports += 1
	_report = report.duplicate(true)
	_terminal = _sample("finished")
	_samples.append(_terminal)
	print("GRAND_I_GAME_OPERANDS ", JSON.stringify(_terminal, "", true, true))


func _binding(snapshot: Dictionary, season: SeasonState, fixture: Dictionary) -> bool:
	return (not snapshot.is_empty() and snapshot.version == 21
		and snapshot.authority == "neutral-final-grand-i-v1" and snapshot.manifest.id == "GRAND-I"
		and snapshot.manifest.revision == 1 and snapshot.binding.fixture == 32
		and snapshot.binding.away == 0 and snapshot.binding.batting_home == 1
		and snapshot.binding.neutral and snapshot.binding.venue_owner == "finals-venue:grand-i:v1"
		and snapshot.binding.selection == "explicit-qualification"
		and snapshot.binding.league == "standard" and not snapshot.binding.has("owner_club")
		and snapshot.environment.mode == "night"
		and snapshot.environment.profile == StadiumGrandIEnvironmentV1.PROFILE
		and snapshot.binding.assignment_key == SeasonFinalVenue.key(season.final_venue)
		and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture))


func _report_refusals(report: Dictionary) -> void:
	var bad: Dictionary = report.duplicate(true)
	bad.seed += 1
	_check(not PhysicalMatchReport.valid(bad), "wrong match seed refuses report19")
	bad = report.duplicate(true)
	bad.resolver = "physical-ai-neutral-final-v1"
	_check(not PhysicalMatchReport.valid(bad), "Long Yard report18 resolver refuses Grand report19")
	bad = report.duplicate(true)
	bad.property.binding.neutral = false
	_check(not PhysicalMatchReport.valid(bad), "non-neutral binding refuses report19")
	bad = report.duplicate(true)
	bad.property.binding.venue_owner = "1"
	_check(not PhysicalMatchReport.valid(bad), "batting home cannot replace neutral venue owner")
	bad = report.duplicate(true)
	bad.property.manifest.id = "LONG-YARD"
	_check(not PhysicalMatchReport.valid(bad), "different venue refuses Grand Gardens I report19")


func _native_exact() -> Dictionary:
	var values: Dictionary = {}
	var hashes: Dictionary = {}
	for name: String in OPERANDS:
		var path: String = _output.path_join(name)
		values[name] = JSON.parse_string(FileAccess.get_file_as_string(path))
		hashes[name] = FileAccess.get_sha256(path)
	var drafted: Dictionary = values[OPERANDS[1]]
	var restored: Dictionary = values[OPERANDS[6]]
	var report: Dictionary = values[OPERANDS[4]]
	var checks: Dictionary = {
		"initial_restore_same": ClubCareer.same(values[OPERANDS[0]], drafted),
		"memory_season_same": ClubCareer.same(values[OPERANDS[3]], values[OPERANDS[5]]),
		"saved_restore_same": ClubCareer.same(drafted, restored),
		"disk_save_same": ClubCareer.same(drafted, values["public-season.json"])
			and hashes["public-season.json"] == _save_sha,
		"report_property_same": ClubCareer.same(report.property, values[OPERANDS[2]].property),
		"final_record_same": ClubCareer.same(drafted.final_venue, restored.final_venue),
		"report_reload_same": ClubCareer.same(_report, report)
			and PhysicalMatchReport.valid(report) and StadiumGrandIPublicReport.valid(report)}
	var failures: int = 0
	for name: String in checks:
		if not checks[name]:
			failures += 1
	return {"schema": "GRAND-I-NATIVE-EXACT-v1", "assertions": checks.size(),
		"failures": failures, "checks": checks, "outputs": hashes,
		"saved_draft_sha256": _save_sha}


func _log_sample(event: String) -> void:
	if _samples.size() < 180:
		var row: Dictionary = _sample(event)
		_samples.append(row)
		print("GRAND_I_GAME_OPERANDS ", JSON.stringify(row, "", true, true))


func _sample(event: String) -> Dictionary:
	var row: Dictionary = {"event": event, "wall_msec": Time.get_ticks_msec() - _started,
		"runner_running": _runner._running, "runner_elapsed": _runner._elapsed,
		"runner_stalled": _runner._stalled, "runner_progress": _runner._progress,
		"runner_error": _runner_error, "reports": _reports,
		"status": "completed" if _reports == 1 else "running" if _runner._running else "stopped",
		"tree_paused": get_tree().paused, "time_scale": Engine.time_scale,
		"physics_ticks": Engine.physics_ticks_per_second}
	if is_instance_valid(_lab):
		var state: MatchState = _lab._match_state
		row.merge({"phase": state.phase, "plate_appearance": state.plate_appearance_number,
			"releases": _lab._automation.releases.size() if _lab._automation != null else -1,
			"plays": _lab._play_records.size(), "throw_number": _lab._throw_number,
			"simulation_seconds": state.elapsed_seconds, "inning": state.inning,
			"top_half": state.top_half, "away": state.away_team.runs, "home": state.home_team.runs,
			"balls": state.balls, "strikes": state.strikes, "outs": state.outs,
			"runtime_interrupted": _lab.has_meta("stadium_npc_runtime_interrupted")})
		var property: StadiumNpcPublicProperty = (_lab.get_meta("stadium_property")
			as StadiumNpcPublicProperty if _lab.has_meta("stadium_property") else null)
		if property != null:
			row["lease"] = {"issued": property.issued, "public_bound": property.public_bound,
				"suspended": property.suspended, "retirement_reason": property.retirement_reason,
				"inside_tree": property.is_inside_tree()}
	return row


func _clock_valid() -> bool:
	return not get_tree().paused and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		_failed.append(label)
		push_error("GRAND_I_ONE_GAME " + label)
	return ok


func _write(name: String, value: Dictionary) -> void:
	if not _admitted:
		return
	var data: String = JSON.stringify(value, "", true, true)
	if data.to_utf8_buffer().size() > MAX_JSON_BYTES:
		_check(false, "bounded output " + name)
		return
	var file: FileAccess = FileAccess.open(_output.path_join(name), FileAccess.WRITE)
	if file == null:
		_check(false, "write output " + name)
		return
	file.store_string(data)
	file.flush()
	if file.get_error() != OK:
		_check(false, "flush output " + name)
	file.close()
