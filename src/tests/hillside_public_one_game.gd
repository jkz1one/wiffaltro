extends Node
## Explicit neutral qualification: one genuine SeasonApp game, no earned final or settlement.
## Only the app commit/UI poll is held; the original lab and pre-ready automation remain live.
## Persist only the genuine drafted save. Fixture32 participants are an in-memory test binding.
# gdlint: disable=max-returns,max-file-lines

const FIXTURE = preload("res://src/tests/hillside_public_fixture.gd")
const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const MAX_FRAMES: int = 144120
const MAX_WALL_MSEC: int = 850000
const MAX_JSON_BYTES: int = 8 * 1024 * 1024
const OPERANDS: Array[String] = [
	"hillside-public-prepared-save.json",
	"hillside-public-drafted-save.json",
	"hillside-public-fixture32.json",
	"hillside-public-memory-before.json",
	"hillside-public-report23.json",
	"hillside-public-memory-after.json",
	"hillside-public-restored-save-after.json",
	"public-season.json"
]
var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _output: String = ""
var _admitted: bool = false
var _started: int = 0
var _app: SeasonApp
var _automation: MatchAutomation
var _starts: int = 0
var _automation_pre_ready: bool = false
var _stalled_ticks: int = 0
var _progress: String = ""
var _lab: PitchBatLab
var _report: Dictionary = {}
var _reports: int = 0
var _game_error: String = ""
var _samples: Array[Dictionary] = []
var _terminal: Dictionary = {}
var _save_sha: String = ""
var _complete: bool = false


func _ready() -> void:
	_started = Time.get_ticks_msec()
	var expected: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--hillside-public-game-dir="):
			_output = argument.trim_prefix("--hillside-public-game-dir=")
		elif argument.begins_with("--hillside-public-game-runtime="):
			expected = argument.trim_prefix("--hillside-public-game-runtime=")
		elif argument.begins_with("--hillside-public-game-execution="):
			_execution = argument.trim_prefix("--hillside-public-game-execution=")
		elif argument.begins_with("--hillside-public-game-nonce="):
			_nonce = argument.trim_prefix("--hillside-public-game-nonce=")
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if _check(
		(
			args.size() == 5
			and args.has("--physical-in-process")
			and _runtime.length() == 64
			and _runtime == expected
			and _execution.length() == 64
			and _nonce.length() == 32
		),
		"exact source and run arguments"
	):
		await _run()
	await _dispose()
	await TestAudioDrain.finish(get_tree())
	var exact: Dictionary = {}
	if _failures == 0 and _complete:
		var candidate: Dictionary = _native_exact()
		if _check(
			candidate.assertions == 7 and candidate.failures == 0,
			"seven exact native canonical comparisons and unchanged save bytes"
		):
			exact = candidate
			print("HILLSIDE_PUBLIC_GAME_EXACT ", JSON.stringify(exact, "", true, true))
	_write(
		"hillside-public-one-game-summary.json",
		{
			"schema": "HILLSIDE-PUBLIC-ONE-GAME-v1",
			"pid": OS.get_process_id(),
			"runtime": _runtime,
			"execution": _execution,
			"nonce": _nonce,
			"checks": _checks,
			"failures": _failures,
			"failed": _failed,
			"status": "completed" if _complete and _failures == 0 else "failed",
			"game_error": _game_error,
			"reports": _reports,
			"completed_games": 1 if _complete and _failures == 0 else 0,
			"season_seed": 6,
			"fixture": 32,
			"away": 0,
			"batting_home": 1,
			"venue_owner": "finals-venue:hillside:v1",
			"explicit_qualification": true,
			"synthetic_participants": true,
			"earned_final": false,
			"settled": false,
			"public_selection_released": false,
			"manual_input_qualified": false,
			"performance_qualified": false,
			"independent_seed47_replay": false,
			"saved_draft_sha256": _save_sha,
			"native_exact": exact,
			"terminal": _terminal,
			"samples": _samples,
			"wall_seconds": (Time.get_ticks_msec() - _started) / 1000.0
		}
	)
	print(
		(
			"HILLSIDE_PUBLIC_ONE_GAME checks=%d failures=%d reports=%d source=%s"
			% [_checks, _failures, _reports, _runtime]
		)
	)
	get_tree().quit(0 if _complete and _failures == 0 else 1)


func _run() -> void:
	if not _check(
		(
			_output.is_absolute_path()
			and not _output.is_empty()
			and DirAccess.make_dir_recursive_absolute(_output) == OK
			and DirAccess.get_files_at(_output).is_empty()
			and DirAccess.get_directories_at(_output).is_empty()
		),
		"fresh isolated output"
	):
		return
	_admitted = true
	SeasonSave.path = _output.path_join("public-season.json")
	PitchBatLabSettings.path = _output.path_join("public-settings.cfg")
	if not _check(_clock_valid(), "ordinary unpaused fixed60 clock"):
		return
	var prepared: SeasonState = FIXTURE.season()
	if not _check(
		(
			prepared != null
			and prepared.results.is_empty()
			and prepared.player_results.is_empty()
			and prepared.physical.reports.is_empty()
			and prepared.physical.pending.is_empty()
			and prepared.final_fixture.is_empty()
			and SeasonFinalVenue.matches_season(prepared)
		),
		"genuine completed draft and pre-draft fixed venue"
	):
		return
	var initial: Dictionary = SeasonSave.snapshot(prepared).duplicate(true)
	_write(OPERANDS[0], initial)
	if not _check(
		initial.version == 67 and initial.opponents.policy == 13 and SeasonSave.save(prepared),
		"genuine current-policy drafted save67 written once"
	):
		return
	_save_sha = FileAccess.get_sha256(SeasonSave.path)
	var season: SeasonState = SeasonSave.restore()
	if not _check(
		season != null and ClubCareer.same(initial, SeasonSave.snapshot(season)),
		"exact engine-canonical draft restore before explicit test binding"
	):
		return
	_write(OPERANDS[1], SeasonSave.snapshot(season))
	var fixture: Dictionary = FIXTURE.fixture(season)
	season.phase = SeasonState.Phase.FINAL
	var original_phase: int = season.phase
	var expected: Dictionary = SeasonFinalVenue.for_fixture(season, fixture)
	var source: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	if not _check(
		(
			ClubCareer.same(fixture, {"id": 32, "round": 11, "away": 0, "home": 1, "neutral": true})
			and _binding(expected, season, fixture)
			and source != null
			and ClubCareer.same(source.stadium, expected)
			and not source.away_team.ai_base
			and source.home_team.ai_base
		),
		"explicit neutral32 binds saved venue independently of batting home and player away role"
	):
		return
	_write(OPERANDS[2], {"fixture": fixture, "property": expected})
	var before: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	_write(OPERANDS[3], before)
	_app = SeasonApp.new()
	add_child(_app)
	# Existing explicit qualification hold: never commit this non-earned final to the season.
	# set_process(false) affects only the app's UI/commit poll, not its live child lab.
	_app.set_process(false)
	_app.season = season
	_app._fixture_id = 32
	_app.notice = ""
	_app.child_entered_tree.connect(_configure_automation)
	_app._open_match(source, false, true, &"field.npc_venue")
	_lab = _app.lab
	var pending: bool = is_instance_valid(_lab) and R.pending_hillside(_lab)
	for frame: int in range(180):
		await get_tree().physics_frame
		if not is_instance_valid(_lab) or _app.lab != _lab:
			break
		var candidate: StadiumNpcPublicProperty = R._property(_lab)
		if candidate != null and candidate.issued and _lab.hillside_public_pending == null:
			break
	if not _check(
		(
			pending
			and is_instance_valid(_lab)
			and _app.lab == _lab
			and _starts == 1
			and _automation_pre_ready
			and _app.notice.is_empty()
			and not _app.is_processing()
			and _lab.is_processing()
			and _lab.is_physics_processing()
			and _automation != null
			and _lab._automation == _automation
		),
		"ordinary SeasonApp pending admission starts one live original pre-ready automated game"
	):
		return
	var live: WeakRef = weakref(_lab)
	var property: StadiumNpcPublicProperty = R._property(_lab)
	if not _check(
		(
			property != null
			and property.issued
			and property.public_bound
			and property.venue_id == "HILLSIDE"
			and property.objects.size() == 8
			and property.ordinary_callbacks()
			and property.callback_intact()
			and StadiumHillsideEnvironmentV1.installed(_lab, property.environment_lease)
			and _lab._managed_match
			and not _lab._player_home
			and _lab._npc_season == season
			and _lab._automation != null
			and R.installed_bound(_lab, expected)
			and property.display == null
			and property.score_display_intact()
			and property.route_obstacles().is_empty()
			and property.hillside_support != null
			and not property.hillside_support.pending
			and property.boundary.get_script() == StadiumHillsidePublicContactAdapter
			and property.public_automation == _automation
			and property.boundary.contact_applied.get_connections().size() == 1
			and property.boundary.contact_applied.is_connected(property._club_contact)
			and StadiumNpcSnapshot.matches_fixture(_lab._match_state.stadium, season, fixture)
		),
		"ordinary public callback graph, original managed automation and exact player-away neutral roles"
	):
		return
	_log_sample("started")
	var next_sample: int = Time.get_ticks_msec() + 10000
	for frame: int in range(MAX_FRAMES):
		if (
			not is_instance_valid(_lab)
			or _app.lab != _lab
			or not _clock_valid()
			or _lab._automation != _automation
			or not _lab.is_processing()
			or not _lab.is_physics_processing()
			or _app.is_processing()
			or _app._result_recorded
			or _app._result_saved
		):
			_game_error = "original app/lab/automation or no-settlement hold changed"
			_check(false, "game stopped before a natural complete report: " + _game_error)
			return
		if _lab._match_state.phase == MatchState.Phase.GAME_END:
			_report = PhysicalMatchReport.capture(_lab)
			_reports += 1
			_terminal = _sample("finished")
			_samples.append(_terminal)
			print("HILLSIDE_PUBLIC_GAME_OPERANDS ", JSON.stringify(_terminal, "", true, true))
			break
		var progress: String = (
			"%d:%d:%d"
			% [
				_lab._match_state.phase,
				_lab._match_state.plate_appearance_number,
				_lab._throw_number
			]
		)
		_stalled_ticks = _stalled_ticks + 1 if progress == _progress else 0
		_progress = progress
		if (
			_lab.has_meta("stadium_npc_runtime_interrupted")
			or _lab._match_state.elapsed_seconds >= PhysicalMatchRunner.MAX_SECONDS
			or _stalled_ticks > 1800
			or Time.get_ticks_msec() - _started >= MAX_WALL_MSEC
		):
			_game_error = "ordinary progress/time bound"
			_check(false, "ordinary game interrupted or exceeded existing progress/time bounds")
			return
		if Time.get_ticks_msec() >= next_sample:
			_log_sample("progress")
			next_sample = Time.get_ticks_msec() + 10000
		await get_tree().physics_frame
	if not _check(
		(
			_reports == 1
			and _game_error.is_empty()
			and not _report.is_empty()
			and _terminal.get("phase") == MatchState.Phase.GAME_END
			and _terminal.get("releases", 0) > 0
			and _terminal.get("plays", 0) > 0
		),
		"one natural full game emits one terminal report with real releases and plays"
	):
		return
	if not _check(
		(
			SeasonOwnership._whole(_report.get("version"), 23, 23)
			and _report.get("resolver") is String
			and _report.resolver == StadiumHillsidePublicReport.RESOLVER
			and PhysicalMatchReport.valid(_report)
			and StadiumHillsidePublicReport.valid(_report)
			and StadiumHillsidePublicReport.matches(_report, expected)
			and StadiumHillsideDefinitionV1.matches(_report.property.manifest)
			and _report.surfaces.size() == _lab._play_records.size()
			and ClubCareer.same(_report.yard, property.provenance)
		),
		"complete real report23 validates against exact neutral fixture32 saved venue"
	):
		return
	_write(OPERANDS[4], _report)
	var decoded: Variant = JSON.parse_string(JSON.stringify(_report, "", true, true))
	_check(
		(
			PhysicalMatchReport.valid(decoded)
			and StadiumHillsidePublicReport.valid(decoded)
			and ClubCareer.same(_report, decoded)
		),
		"actual report23 full-precision JSON reload"
	)
	_report_refusals(_report)
	await _dispose()
	_check(
		_app == null and live.get_ref() == null, "ordinary app close disposes actual completed lab"
	)
	_check(
		(
			PhysicalMatchReport.valid(_report)
			and StadiumHillsidePublicReport.valid(_report)
			and StadiumHillsidePublicReport.matches(_report, expected)
			and StadiumHillsideDefinitionV1.matches(_report.property.manifest)
		),
		(
			"cold terminal report23 and original Hillside event evidence remain valid after actual "
			+ "lab disposal"
		)
	)
	var after: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	_write(OPERANDS[5], after)
	_check(
		(
			ClubCareer.same(before, after)
			and season.phase == original_phase
			and ClubCareer.same(fixture, season.final_fixture)
			and _binding(SeasonFinalVenue.for_fixture(season, fixture), season, fixture)
			and season.results.is_empty()
			and season.player_results.is_empty()
			and season.physical.reports.is_empty()
			and season.physical.pending.is_empty()
		),
		"explicit in-memory binding and season remain exact with no result, archive or settlement"
	)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			restored != null
			and ClubCareer.same(initial, SeasonSave.snapshot(restored))
			and restored.final_fixture.is_empty()
			and FileAccess.get_sha256(SeasonSave.path) == _save_sha
			and not FileAccess.file_exists(SeasonSave.path + ".bak")
			and not FileAccess.file_exists(SeasonSave.path + ".tmp")
		),
		"original drafted save bytes and ordinary restore unchanged; synthetic final never persisted"
	)
	if restored != null:
		_write(OPERANDS[6], SeasonSave.snapshot(restored))
	_complete = _failures == 0


func _configure_automation(node: Node) -> void:
	if not node is PitchBatLab:
		return
	var lab: PitchBatLab = node
	_starts += 1
	_automation_pre_ready = not lab.is_node_ready() and lab._automation == null and _starts == 1
	if not _automation_pre_ready:
		return
	_automation = MatchAutomation.new()
	_automation.seed = SeasonPhysicalFixtures.seed_for(_app.season, _app.season.pending_fixture())
	_automation.presentation_enabled = false
	lab._automation = _automation


func _dispose() -> void:
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
		_app = null
	await get_tree().process_frame


func _binding(snapshot: Dictionary, season: SeasonState, fixture: Dictionary) -> bool:
	return (
		StadiumNpcSnapshot.valid(snapshot)
		and SeasonOwnership._whole(snapshot.get("version"), 25, 25)
		and snapshot.authority == "neutral-final-hillside-v1"
		and snapshot.manifest.id == "HILLSIDE"
		and snapshot.manifest.revision == 1
		and snapshot.binding.fixture == 32
		and snapshot.binding.away == 0
		and snapshot.binding.batting_home == 1
		and snapshot.binding.neutral
		and snapshot.binding.venue_owner == "finals-venue:hillside:v1"
		and snapshot.binding.selection == "explicit-qualification"
		and snapshot.binding.league == "standard"
		and not snapshot.binding.has("owner_club")
		and snapshot.environment.mode == "day"
		and snapshot.environment.profile == StadiumHillsideEnvironmentV1.PROFILE
		and snapshot.binding.assignment_key == SeasonFinalVenue.key(season.final_venue)
		and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture)
	)


func _report_refusals(report: Dictionary) -> void:
	var bad: Dictionary = report.duplicate(true)
	bad.seed += 1
	_check(
		not PhysicalMatchReport.valid(bad) and _raw_report_types_refuse(report),
		"wrong match seed and raw report numeric types refuse report23"
	)
	bad = report.duplicate(true)
	bad.resolver = "physical-ai-neutral-final-v1"
	_check(
		not PhysicalMatchReport.valid(bad) and _old_resolvers_refuse(report),
		"Long Yard, Grand I/II/III and Pool Party resolvers cannot borrow Hillside report23"
	)
	bad = report.duplicate(true)
	bad.property.binding.neutral = false
	_check(not PhysicalMatchReport.valid(bad), "non-neutral binding refuses report23")
	bad = report.duplicate(true)
	bad.property.binding.venue_owner = "1"
	_check(not PhysicalMatchReport.valid(bad), "batting home cannot replace neutral venue owner")
	bad = report.duplicate(true)
	bad.property.manifest.id = "LONG-YARD"
	_check(
		not PhysicalMatchReport.valid(bad) and _old_bindings_refuse(report),
		"Long Yard, Grand I/II/III and Pool Party bindings cannot borrow Hillside report23"
	)


func _raw_report_types_refuse(report: Dictionary) -> bool:
	for wrong: Variant in [true, "23", 23.5, null, [], {}]:
		var bad: Dictionary = report.duplicate(true)
		bad.version = wrong
		if PhysicalMatchReport.valid(bad):
			return false
	for wrong: Variant in [true, "3351334", 3351334.5, null, [], {}]:
		var bad: Dictionary = report.duplicate(true)
		bad.seed = wrong
		if PhysicalMatchReport.valid(bad):
			return false
	return true


func _old_resolvers_refuse(report: Dictionary) -> bool:
	for resolver: String in [
		StadiumLongYardPublicReport.RESOLVER,
		StadiumGrandIPublicReport.RESOLVER,
		StadiumGrandIIPublicReport.RESOLVER,
		StadiumGrandIIIPublicReport.RESOLVER,
		StadiumPoolPartyPublicReport.RESOLVER
	]:
		var bad: Dictionary = report.duplicate(true)
		bad.resolver = resolver
		if PhysicalMatchReport.valid(bad):
			return false
	return (
		not StadiumLongYardPublicReport.valid(report)
		and not StadiumGrandIPublicReport.valid(report)
		and not StadiumGrandIIPublicReport.valid(report)
		and not StadiumGrandIIIPublicReport.valid(report)
		and not StadiumPoolPartyPublicReport.valid(report)
	)


func _old_bindings_refuse(report: Dictionary) -> bool:
	for version: int in [
		StadiumNpcSnapshot.FINAL_FIXTURE_VERSION,
		StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION,
		StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION,
		StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION,
		StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION
	]:
		var bad: Dictionary = report.duplicate(true)
		bad.property.version = version
		if PhysicalMatchReport.valid(bad):
			return false
	for venue: String in ["LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III", "POOL-PARTY"]:
		var bad: Dictionary = report.duplicate(true)
		bad.property.manifest.id = venue
		bad.property.binding.venue_id = venue
		if PhysicalMatchReport.valid(bad):
			return false
	return true


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
		"disk_save_same":
		(
			ClubCareer.same(drafted, values["public-season.json"])
			and hashes["public-season.json"] == _save_sha
		),
		"report_property_same": ClubCareer.same(report.property, values[OPERANDS[2]].property),
		"final_record_same": ClubCareer.same(drafted.final_venue, restored.final_venue),
		"report_reload_same":
		(
			ClubCareer.same(_report, report)
			and PhysicalMatchReport.valid(report)
			and StadiumHillsidePublicReport.valid(report)
		)
	}
	var failures: int = 0
	for name: String in checks:
		if not checks[name]:
			failures += 1
	return {
		"schema": "HILLSIDE-PUBLIC-NATIVE-EXACT-v1",
		"assertions": checks.size(),
		"failures": failures,
		"checks": checks,
		"outputs": hashes,
		"saved_draft_sha256": _save_sha
	}


func _log_sample(event: String) -> void:
	if _samples.size() < 180:
		var row: Dictionary = _sample(event)
		_samples.append(row)
		print("HILLSIDE_PUBLIC_GAME_OPERANDS ", JSON.stringify(row, "", true, true))


func _sample(event: String) -> Dictionary:
	var row: Dictionary = {
		"event": event,
		"wall_msec": Time.get_ticks_msec() - _started,
		"app_processing": _app.is_processing(),
		"lab_processing": _lab.is_processing(),
		"lab_physics_processing": _lab.is_physics_processing(),
		"automation_id": _automation.get_instance_id(),
		"stalled_ticks": _stalled_ticks,
		"progress": _progress,
		"game_error": _game_error,
		"reports": _reports,
		"status": "completed" if _reports == 1 else "running",
		"tree_paused": get_tree().paused,
		"time_scale": Engine.time_scale,
		"physics_ticks": Engine.physics_ticks_per_second,
		"result_recorded": _app._result_recorded,
		"result_saved": _app._result_saved
	}
	var state: MatchState = _lab._match_state
	row.merge(
		{
			"phase": state.phase,
			"plate_appearance": state.plate_appearance_number,
			"releases": _automation.releases.size(),
			"plays": _lab._play_records.size(),
			"throw_number": _lab._throw_number,
			"simulation_seconds": state.elapsed_seconds,
			"inning": state.inning,
			"top_half": state.top_half,
			"away": state.away_team.runs,
			"home": state.home_team.runs,
			"balls": state.balls,
			"strikes": state.strikes,
			"outs": state.outs,
			"runtime_interrupted": _lab.has_meta("stadium_npc_runtime_interrupted")
		}
	)
	var property: StadiumNpcPublicProperty = R._property(_lab)
	if property != null:
		row["lease"] = {
			"issued": property.issued,
			"public_bound": property.public_bound,
			"suspended": property.suspended,
			"retirement_reason": property.retirement_reason,
			"inside_tree": property.is_inside_tree()
		}
	return row


func _clock_valid() -> bool:
	return (
		not get_tree().paused and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60
	)


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		_failed.append(label)
		push_error("HILLSIDE_PUBLIC_ONE_GAME " + label)
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
