extends Node
## One real new-season AY03 away game, then the ordinary two Commons jobs and save.
## Existing automation supplies inputs; no fixture, phase, clock or result is manufactured.
# gdlint: disable=max-file-lines,max-returns

const SEED: int = 1
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
var _automation_ready: bool = true
var _admitted: bool = false
var _started: int = 0


func _ready() -> void:
	_started = Time.get_ticks_usec()
	var expected: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--ay03-public-dir="):
			_output = argument.trim_prefix("--ay03-public-dir=")
		elif argument.begins_with("--ay03-public-runtime="):
			expected = argument.trim_prefix("--ay03-public-runtime=")
		elif argument.begins_with("--ay03-public-execution="):
			_execution = argument.trim_prefix("--ay03-public-execution=")
		elif argument.begins_with("--ay03-public-nonce="):
			_nonce = argument.trim_prefix("--ay03-public-nonce=")
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
	_write("ay03-public-round-summary.json", {
		"schema": "AY03-PUBLIC-ROUND-R13-v1", "pid": OS.get_process_id(),
		"runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"checks": _checks, "failures": _failures, "failed": _failed,
		"season_seed": SEED, "fixture": 0, "assigned_owner": 5,
		"human_starts": _human_starts, "ai_reports": _ai_reports.size(),
		"terminal": _terminal, "settled": _failures == 0 and not _terminal.is_empty(),
		"wall_seconds": (Time.get_ticks_usec() - _started) / 1000000.0,
		"manual_input_qualified": false, "performance_qualified": false,
		"independent_seed47_replay": false, "five_park_allocation_complete": false})
	print("AY03_PUBLIC_ROUND checks=%d failures=%d human=%d ai=%d source=%s" % [
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
	await get_tree().process_frame
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	await get_tree().process_frame
	_app.begin_season(SEED, true, true, true, true, false)
	if not _check(_app.season != null and _app.season.phase == SeasonState.Phase.DRAFT
		and _app.season.picks.is_empty() and _app.season.physical != null
		and SeasonVenues.owner_for(SEED) == 2 and SeasonVenues.ay03_owner_for(SEED) == 5
		and SeasonVenues.matches_season(_app.season),
		"ordinary new Working season saves independently selected opening host before draft"):
		return
	var initial: Dictionary = SeasonSave.snapshot(_app.season)
	var restored: SeasonState = SeasonSave.restore()
	if not _check(initial.get("version") == 61 and restored != null
		and ClubCareer.same(initial, SeasonSave.snapshot(restored)),
		"pre-draft save61 roundtrip preserves actual assignment and career identity"):
		return
	_write("ay03-public-predraft.json", initial)
	for index: int in range(4):
		var offers: Array[String] = _app.season.offers()
		if not _check(offers.size() == 3, "ordinary current draft offer"):
			return
		_app.choose_player(offers[0])
		if not _check(_app.season.picks.size() == index + 1
			and _app.season.picks[index] == offers[0], "genuine first-offer draft choice"):
			return
	var fixture: Dictionary = _app.season.pending_fixture()
	if not _check(fixture == {"id": 0, "round": 0, "away": 0, "home": 5}
		and _app.season.results.is_empty()
		and SeasonState.field_for_fixture(fixture, _app.season).id == &"field.npc_venue",
		"real opening schedule selects AY03 without edited fixture or history"):
		return
	var assignment: String = SeasonVenues.key(_app.season.npc_venues)
	var home: String = StadiumLayoutSnapshot.key(_app.season.home_property)
	var ledger: Dictionary = ClubPlayers.assets(_app.season.career).to_data()
	_app.child_entered_tree.connect(_configure_automation)
	_app.round_ui.runner.finished.connect(func(report: Dictionary) -> void:
		_ai_reports.append(report.duplicate(true))
		_write("ay03-public-ai-%d.json" % (_ai_reports.size() - 1), report))
	_app.play_season_game()
	if not _check(_app.lab != null and _automation_ready and _human_starts == 1
		and _app.lab._managed_match and not _app.lab._player_home
		and _app.lab._npc_season == _app.season
		and StadiumNpcSnapshot.matches_fixture(_app.lab._match_state.stadium,
			_app.season, fixture) and StadiumNpcYardThreeRuntimeV1.installed_bound(
			_app.lab, _app.lab._match_state.stadium),
		"real managed away entry installs bound AY03 before ordinary inputs"):
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
			print("AY03_PUBLIC_PROGRESS stage=human releases=", logged,
				" inning=", state.inning, " away=", state.away_team.runs,
				" home=", state.home_team.runs, " sim=", state.elapsed_seconds)
		await get_tree().physics_frame
	if not _check(state.phase == MatchState.Phase.GAME_END and _app._result_recorded
		and not _app.season.physical.pending.is_empty(),
		"natural game end reaches ordinary durable pending branch"):
		return
	_pending = SeasonSave.snapshot(_app.season)
	_write("ay03-public-pending.json", _pending)
	var terminal_checks: Dictionary = StadiumNpcYardThreePublicChecks.terminal(lab, _app.season)
	for error: String in terminal_checks.errors:
		_check(false, error)
	if not _check(terminal_checks.errors.is_empty(), "focused actual terminal report negatives"):
		return
	var report: Dictionary = terminal_checks.report
	var human: Dictionary = terminal_checks.human
	if not _check(report.get("version") == 16 and PhysicalMatchReport.valid(report)
		and StadiumNpcYardThreeReport.matches(report, SeasonVenues.for_fixture(_app.season, fixture))
		and not human.is_empty() and _app.season.physical.pending.human.size() == 17
		and ClubCareer.same(human, _app.season.physical.pending.human[16]),
		"actual terminal report16 and human evidence bind same saved fixture"):
		return
	_terminal = {"away": state.away_team.runs, "home": state.home_team.runs,
		"inning": state.inning, "top_half": state.top_half,
		"releases": lab._automation.releases.size(), "plays": lab._play_records.size(),
		"simulation_seconds": state.elapsed_seconds, "report_version": report.version,
		"fixture_key": StadiumNpcSnapshot.key(state.stadium)}
	_write("ay03-public-report16.json", report)
	_write("ay03-public-human-evidence.json", human)
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
		if _app.season.results.size() == 3 and _app.season.physical.pending.is_empty():
			break
		if frame % 600 == 0:
			var current: Dictionary = _app.round_ui._projection.get("fixture", {})
			print("AY03_PUBLIC_PROGRESS stage=round fixture=", current.get("id", -1),
				" completed=", _ai_reports.size())
		await get_tree().physics_frame
	if not _check(_app.season.results.size() == 3 and _app.season.player_results.size() == 1
		and _app.season.physical.reports.size() == 2
		and _app.season.physical.pending.is_empty() and _app.season.round_index == 1
		and _app._result_saved and _ai_reports.size() == 2,
		"normal two Commons jobs settle one actual complete round exactly once"):
		return
	for report_row: Dictionary in _ai_reports:
		_check(PhysicalMatchReport.valid(report_row)
			and report_row.field == "field.commons_park" and report_row.version != 16,
			"unselected opponents retain ordinary Commons report path")
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
	_write("ay03-public-final-save.json", after)


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
		print("AY03_PUBLIC_FAIL ", label)
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
