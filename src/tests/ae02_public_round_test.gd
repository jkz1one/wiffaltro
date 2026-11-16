extends Node
## One real AE02 opening away game from a fixed saved Base ordinal0 test assignment.
## Production new-season UI remains ordinal0; ordinary Club and Expanded jobs settle the round.
## Existing automation supplies inputs; no fixture, phase, clock or result is manufactured.
# gdlint: disable=max-file-lines,max-returns

const FIXTURE = preload("res://src/tests/ae02_public_fixture.gd")
const SEED: int = 3
const MAX_MATCH_FRAMES: int = 144120
const MAX_ROUND_FRAMES: int = 288240
const MAX_JSON_BYTES: int = 8 * 1024 * 1024

var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _output: String = ""
var _runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _app: SeasonApp
var _human_starts: int = 0
var _ai_reports: Array[Dictionary] = []
var _pending: Dictionary = {}
var _terminal: Dictionary = {}
var _family_ids: Array[String] = []
var _assignment_verified: bool = false
var _round_error: String = ""
var _automation_ready: bool = true
var _admitted: bool = false
var _started: int = 0


func _ready() -> void:
	_started = Time.get_ticks_usec()
	var expected: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--ae02-public-dir="):
			_output = argument.trim_prefix("--ae02-public-dir=")
		elif argument.begins_with("--ae02-public-runtime="):
			expected = argument.trim_prefix("--ae02-public-runtime=")
		elif argument.begins_with("--ae02-public-execution="):
			_execution = argument.trim_prefix("--ae02-public-execution=")
		elif argument.begins_with("--ae02-public-nonce="):
			_nonce = argument.trim_prefix("--ae02-public-nonce=")
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if _check(args.size() == 5 and args.has("--physical-in-process")
		and _runtime.length() == 64 and _runtime == expected
		and _execution.length() == 64 and _nonce.length() == 32,
		"fixed source/run arguments and in-process round jobs"):
		await _run()
	if is_instance_valid(_app):
		_app.round_ui.cancel()
		_app._close_match()
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
	_write("ae02-public-round-summary.json", {
		"schema": "AE02-PUBLIC-ROUND-v1", "pid": OS.get_process_id(),
		"runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"checks": _checks, "failures": _failures, "failed": _failed,
		"season_seed": SEED, "fixture": 0, "assigned_owner": 5,
		"venue_ordinal": 0, "production_venue_ordinal": 0, "assignment_version": 3,
		"family_ids": _family_ids,
		"round_reports": _family_ids.size(),
		"human_starts": _human_starts, "ai_reports": _ai_reports.size(),
		"terminal": _terminal, "settled": _failures == 0 and not _terminal.is_empty(),
		"wall_seconds": (Time.get_ticks_usec() - _started) / 1000000.0,
		"manual_input_qualified": false, "performance_qualified": false,
		"independent_seed47_replay": false,
		"explicit_assignment_verified": _assignment_verified,
		"five_park_allocation_complete": false, "round_error": _round_error})
	print("AE02_PUBLIC_ROUND checks=%d failures=%d human=%d ai=%d source=%s" % [
		_checks, _failures, _human_starts, _ai_reports.size(), _runtime])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	if not _check(_output.is_absolute_path() and not _output.is_empty()
		and DirAccess.make_dir_recursive_absolute(_output) == OK
		and DirAccess.get_files_at(_output).is_empty()
		and DirAccess.get_directories_at(_output).is_empty(), "fresh isolated output"):
		return
	_admitted = true
	SeasonSave.path = _output.path_join("public-season.json")
	PitchBatLabSettings.path = _output.path_join("public-settings.cfg")
	if not _check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
		and not get_tree().paused, "ordinary unpaused fixed60 clock"):
		return
	# Test setup uses the same real allocator and draft helper as the installed-slice proofs.
	# Save first; SeasonApp's ordinary loader and managed away entry consume the fixture.
	var prepared: SeasonState = FIXTURE.season(SEED)
	if not _check(prepared != null and _assignment(prepared)
		and prepared.results.is_empty() and prepared.player_results.is_empty()
		and prepared.physical.pending.is_empty() and prepared.physical.reports.is_empty(),
		"fixed Base ordinal0 seed3 actual five-host assignment and genuine completed draft"):
		return
	_assignment_verified = true
	var initial: Dictionary = SeasonSave.snapshot(prepared)
	if not _check(initial.get("version") == 61 and SeasonSave.save(prepared),
		"real drafted AE02 fixture saved through save61 before ordinary app restore"):
		return
	await get_tree().process_frame
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	await get_tree().process_frame
	var restored: SeasonState = SeasonSave.restore()
	if not _check(_app.season != null and restored != null
		and ClubCareer.same(initial, SeasonSave.snapshot(_app.season))
		and ClubCareer.same(initial, SeasonSave.snapshot(restored)),
		"ordinary app and save61 restore exact assignment and genuine drafted season"):
		return
	_write("ae02-public-initial-save.json", SeasonSave.snapshot(_app.season))
	var fixture: Dictionary = _app.season.pending_fixture()
	if not _check(fixture == {"id": 0, "round": 0, "away": 0, "home": 5}
		and fixture == FIXTURE.fixture(_app.season)
		and SeasonState.field_for_fixture(fixture, _app.season).id == &"field.npc_venue",
		"real opening schedule selects AE02r1 without edited fixture or history"):
		return
	for fixture_id: int in range(3):
		var scheduled: Dictionary = SeasonVenues.fixture_for_id(_app.season, fixture_id)
		if not _check(_binding(SeasonVenues.for_fixture(_app.season, scheduled),
			_app.season, fixture_id),
			"opening fixture%d binds exact saved owner and day environment" % fixture_id):
			return
	var assignment: String = SeasonVenues.key(_app.season.npc_venues)
	var home: String = StadiumLayoutSnapshot.key(_app.season.home_property)
	var ledger: Dictionary = ClubPlayers.assets(_app.season.career).to_data()
	_app.child_entered_tree.connect(_configure_automation)
	_app.round_ui.runner.failed.connect(func(reason: String) -> void: _round_error = reason)
	_app.round_ui.runner.finished.connect(func(report: Dictionary) -> void:
		_ai_reports.append(report.duplicate(true))
		_write("ae02-public-ai-%d.json" % (_ai_reports.size() - 1), report))
	_app.play_season_game()
	if not _check(_app.lab != null and _automation_ready and _human_starts == 1
		and _app.lab._managed_match and not _app.lab._player_home
		and _app.lab._npc_season == _app.season
		and StadiumNpcSnapshot.matches_fixture(_app.lab._match_state.stadium,
			_app.season, fixture) and StadiumNpcPublicRuntime.installed_bound(
			_app.lab, _app.lab._match_state.stadium),
		"real managed away entry installs bound AE02r1 before ordinary inputs"):
		return
	var lab: PitchBatLab = _app.lab
	var state: MatchState = lab._match_state
	var live: WeakRef = weakref(lab)
	var last_progress: String = ""
	var stalled: int = 0
	var logged: int = -1
	for frame: int in range(MAX_MATCH_FRAMES):
		if not is_instance_valid(lab) or lab.has_meta("stadium_npc_runtime_interrupted") \
			or lab._automation == null:
			_check(false, "managed public game interrupted before natural completion")
			return
		if state.phase == MatchState.Phase.GAME_END and _app._result_recorded \
			and not _app.season.physical.pending.is_empty():
			break
		var progress: String = "%d:%d:%d" % [state.phase,
			state.plate_appearance_number, lab._throw_number]
		stalled = stalled + 1 if progress == last_progress else 0
		last_progress = progress
		if stalled > 1800 or state.elapsed_seconds >= PhysicalMatchRunner.MAX_SECONDS:
			_check(false, "ordinary managed game exceeded existing progress/time bounds")
			return
		if lab._automation.releases.size() % 25 == 0 \
			and logged != lab._automation.releases.size():
			logged = lab._automation.releases.size()
			print("AE02_PUBLIC_PROGRESS stage=human releases=", logged,
				" inning=", state.inning, " away=", state.away_team.runs,
				" home=", state.home_team.runs, " sim=", state.elapsed_seconds)
		await get_tree().physics_frame
	if not _check(state.phase == MatchState.Phase.GAME_END and _app._result_recorded
		and not _app.season.physical.pending.is_empty(),
		"natural game end reaches ordinary durable pending branch"):
		return
	_pending = SeasonSave.snapshot(_app.season)
	_write("ae02-public-pending.json", _pending)
	var terminal_checks: Dictionary = StadiumNpcBasePublicChecks.terminal(lab, _app.season)
	for error: String in terminal_checks.errors:
		_check(false, error)
	if not _check(terminal_checks.errors.is_empty(), "focused actual terminal report negatives"):
		return
	var report: Dictionary = terminal_checks.report
	var human: Dictionary = terminal_checks.human
	if not _check(report.get("version") == 17 and PhysicalMatchReport.valid(report)
		and _report_bound(report, _app.season, 0)
		and not human.is_empty() and _app.season.physical.pending.human.size() == 17
		and ClubCareer.same(human, _app.season.physical.pending.human[16]),
		"actual terminal report17 and human evidence bind same saved fixture"):
		return
	_family_ids.append(report.property.manifest.id)
	_terminal = {"away": state.away_team.runs, "home": state.home_team.runs,
		"inning": state.inning, "top_half": state.top_half,
		"releases": lab._automation.releases.size(), "plays": lab._play_records.size(),
		"simulation_seconds": state.elapsed_seconds, "report_version": report.version,
		"fixture_key": StadiumNpcSnapshot.key(state.stadium)}
	_write("ae02-public-report17.json", report)
	_write("ae02-public-human-evidence.json", human)
	restored = SeasonSave.restore()
	if not _check(restored != null and ClubCareer.same(_pending, SeasonSave.snapshot(restored)),
		"actual completed pending state survives exact saved replay"):
		return
	var forged: Dictionary = _pending.duplicate(true)
	forged.physical.pending.human[16].clear()
	_check(SeasonSave._decode(forged) == null,
		"stripped completed human venue evidence refuses pending replay")
	# Automation has no human outro. Use the existing completed-result resume branch.
	_app._commit_result()
	for frame: int in range(MAX_ROUND_FRAMES):
		if not _round_error.is_empty():
			_check(false, "ordinary AI job failed: " + _round_error)
			return
		if _app.season.results.size() == 3 and _app.season.physical.pending.is_empty():
			break
		if frame % 600 == 0:
			var current: Dictionary = _app.round_ui._projection.get("fixture", {})
			print("AE02_PUBLIC_PROGRESS stage=round fixture=", current.get("id", -1),
				" completed=", _ai_reports.size())
		await get_tree().physics_frame
	if not _check(_app.season.results.size() == 3 and _app.season.player_results.size() == 1
		and _app.season.physical.reports.size() == 2
		and _app.season.physical.pending.is_empty() and _app.season.round_index == 1
		and _app._result_saved and _ai_reports.size() == 2,
		"ordinary AC01 and AE01 jobs settle the actual AE02 opening round exactly once"):
		return
	for index: int in range(_ai_reports.size()):
		var report_row: Dictionary = _ai_reports[index]
		if not _check(_report_bound(report_row, _app.season, index + 1)
			and ClubCareer.same(report_row, _app.season.physical.reports[index].report)
			and ClubCareer.same(report_row, JSON.parse_string(JSON.stringify(report_row, "", true, true))),
			"actual AI fixture%d report17 binds saved owner and survives exact JSON reload" % (index + 1)):
			return
		_family_ids.append(report_row.property.manifest.id)
	if not _check(_family_ids == ["AE-02", "AC-01", "AE-01"],
		"actual AE02 human and scheduled Club/Expanded jobs supply exact report17 evidence"):
		return
	var after: Dictionary = SeasonSave.snapshot(_app.season)
	restored = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(after, SeasonSave.snapshot(restored)),
		"settled save61 restores exact results, reward history and assignment")
	_check(SeasonVenues.key(_app.season.npc_venues) == assignment
		and StadiumLayoutSnapshot.key(_app.season.home_property) == home
		and ClubCareer.same(ledger, ClubPlayers.assets(_app.season.career).to_data()),
		"away play preserves frozen venues and paid home inventory")
	var duplicate: SeasonState = SeasonSave._decode(after)
	_check(duplicate != null and not duplicate.callv("record_player_result",
		_pending.physical.pending.human) and ClubCareer.same(after, SeasonSave.snapshot(duplicate)),
		"same human result cannot settle again against next scheduled fixture")
	_check(_app._commit_result() and ClubCareer.same(after, SeasonSave.snapshot(_app.season)),
		"repeat completion callback cannot repay or repeat the round")
	_check(live.get_ref() == null and _app.lab == null,
		"ordinary resume disposes the played managed lab")
	var settlement_errors: Array[String] = StadiumNpcYardTwoPublicChecks.settled(_app.season, 0)
	for error: String in settlement_errors:
		_check(false, error)
	_check(settlement_errors.is_empty(), "focused actual settled save and duplicate controls")
	_write("ae02-public-final-save.json", after)
	_refused_start_preserves(after)


func _assignment(season_value: SeasonState) -> bool:
	if not SeasonVenues.matches_season(season_value) or season_value.season_seed != SEED \
		or SeasonVenues.run_for(season_value) != 1 or season_value.difficulty != 1:
		return false
	var data: Dictionary = season_value.npc_venues
	if data.version != 3 or data.venue_ordinal != 0 or data.assignments.size() != 5 \
		or data.environments.size() != 32 or not ClubCareer.same(data.streams,
			{"layout": 169751845, "owner": 1272751476, "environment": 1558738264}) \
		or not ClubCareer.same(data.quota,
			{"backyard": 2, "expanded": 2, "club": 1, "mogul": 0}):
		return false
	var ids: Array[String] = ["AC-01", "AY-01", "AE-01", "AY-02", "AE-02"]
	var revisions: Array[int] = [2, 2, 2, 1, 1]
	for index: int in range(ids.size()):
		var entry: Dictionary = data.assignments[str(index + 1)]
		if entry.manifest.id != ids[index] \
			or entry.manifest.revision != revisions[index]:
			return false
	return true


func _binding(snapshot: Dictionary, season_value: SeasonState, fixture_id: int) -> bool:
	if snapshot.is_empty() or fixture_id < 0 or fixture_id > 2 or not _assignment(season_value):
		return false
	var ids: Array[String] = ["AE-02", "AC-01", "AE-01"]
	var hosts: Array[int] = [5, 1, 3]
	var away: Array[int] = [0, 4, 2]
	var fixture: Dictionary = SeasonVenues.fixture_for_id(season_value, fixture_id)
	return fixture == {"id": fixture_id, "round": 0,
		"away": away[fixture_id], "home": hosts[fixture_id]} \
		and StadiumNpcSnapshot.matches_fixture(snapshot, season_value, fixture) \
		and snapshot.version == 19 and snapshot.manifest.id == ids[fixture_id] \
		and snapshot.manifest.revision == (1 if fixture_id == 0 else 2) \
		and snapshot.binding.assignment_version == 3 \
		and snapshot.binding.assignment_key == SeasonVenues.key(season_value.npc_venues) \
		and snapshot.binding.owner_club == hosts[fixture_id] \
		and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season_value, fixture) \
		and snapshot.binding.environment_seed == snapshot.environment.seed \
		and ClubCareer.same(snapshot.environment, season_value.npc_venues.environments[str(fixture_id)]) \
		and snapshot.environment.mode == "day" and snapshot.environment.profile.is_empty()


func _report_bound(report: Dictionary, season_value: SeasonState, fixture_id: int) -> bool:
	var fixture: Dictionary = SeasonVenues.fixture_for_id(season_value, fixture_id)
	return report.get("version") == 17 and PhysicalMatchReport.valid(report) \
		and report.resolver == StadiumNpcPublicReport.RESOLVER \
		and _binding(report.property, season_value, fixture_id) \
		and StadiumNpcPublicReport.matches(report, SeasonVenues.for_fixture(season_value, fixture))


func _refused_start_preserves(before: Dictionary) -> void:
	# Invalid public seed is an existing start refusal, not an injected readiness failure.
	var previous: SeasonState = _app.season
	var primary: String = FileAccess.get_sha256(SeasonSave.path)
	var backup: String = FileAccess.get_sha256(SeasonSave.path + ".bak")
	_app.begin_season(2147483648, true, true, true, true, false)
	_check(_app.season == previous and not _app.notice.is_empty()
		and ClubCareer.same(before, SeasonSave.snapshot(_app.season))
		and primary == FileAccess.get_sha256(SeasonSave.path)
		and backup == FileAccess.get_sha256(SeasonSave.path + ".bak"),
		"actual invalid new-season start preserves prior settled season and both save files")


func _configure_automation(node: Node) -> void:
	if not node is PitchBatLab:
		return
	var lab: PitchBatLab = node
	_automation_ready = _automation_ready and not lab.is_node_ready() \
		and lab._match_state == null and lab._automation == null
	lab._automation = MatchAutomation.new()
	lab._automation.seed = SeasonPhysicalFixtures.seed_for(_app.season, _app.season.pending_fixture())
	lab._automation.presentation_enabled = false
	_human_starts += 1


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		_failed.append(label)
		print("AE02_PUBLIC_FAIL ", label)
	return ok


func _write(name: String, value: Dictionary) -> void:
	if not _admitted:
		return
	var text: String = JSON.stringify(value, "", true, true)
	if text.to_utf8_buffer().size() > MAX_JSON_BYTES:
		_check(false, "bounded output " + name)
		return
	var file: FileAccess = FileAccess.open(_output.path_join(name), FileAccess.WRITE)
	if file == null:
		_check(false, "write output " + name)
		return
	file.store_string(text)
	file.flush()
	if file.get_error() != OK:
		_check(false, "flush output " + name)
	file.close()
