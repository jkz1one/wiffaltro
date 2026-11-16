extends Node
## Restore one genuine completed-human checkpoint; complete only the remaining AY02 AI job.
## Retained human evidence is validated separately. No human/first-AI replay or manufactured state.
# gdlint: disable=max-file-lines,max-returns

const SEED: int = 6
const INPUT: String = "res://src/tests/fixtures/ac02-public-completed-pending.json"
const INPUT_SHA: String = "af9a5c7d8e4d92e31290d5dabce9a006172f4065c8f3e00e529e28d4c7114356"
const HUMAN_REPORT: String = "res://src/tests/fixtures/ac02-public-retained-human-report17.json"
const HUMAN_REPORT_SHA: String = "d02ac9b3f844f35a09b2a6107b0a2769418514643c6a994f96d7334f6cc38163"
const FIRST_AI: String = "res://src/tests/fixtures/ac02-retained-first-ai-report17.json"
const FIRST_AI_SHA: String = "536e7b7d580f1679875c21be54778dc6e10996258b75901fe548633c4b0a472b"
const INPUT_BYTES: int = 385135
const MAX_ROUND_FRAMES: int = 288240
const MAX_JSON_BYTES: int = 8 * 1024 * 1024
const MAX_SAMPLES: int = 192

var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _output: String = ""
var _runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _app: SeasonApp
var _ai_reports: Array[Dictionary] = []
var _pending: Dictionary = {}
var _family_ids: Array[String] = []
var _assignment_verified: bool = false
var _retained_ai: int = 0
var _human_starts: int = 0
var _admitted: bool = false
var _started: int = 0
var _samples: Array[Dictionary] = []
var _failed_reason: String = ""
var _retained_human: int = 0
var _status: String = "not_started"
var _terminal: Dictionary = {}


func _ready() -> void:
	_started = Time.get_ticks_msec()
	var expected: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--ac02-complete-dir="):
			_output = argument.trim_prefix("--ac02-complete-dir=")
		elif argument.begins_with("--ac02-complete-runtime="):
			expected = argument.trim_prefix("--ac02-complete-runtime=")
		elif argument.begins_with("--ac02-complete-execution="):
			_execution = argument.trim_prefix("--ac02-complete-execution=")
		elif argument.begins_with("--ac02-complete-nonce="):
			_nonce = argument.trim_prefix("--ac02-complete-nonce=")
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if _check(args.size() == 5 and args.has("--physical-in-process")
		and _runtime.length() == 64 and _runtime == expected
		and _execution.length() == 64 and _nonce.length() == 32,
		"fixed source/run arguments and ordinary in-process jobs"):
		await _run()
	if is_instance_valid(_app):
		_terminal = _sample("terminal")
		_app.round_ui.cancel()
		_app.queue_free()
	_check(FileAccess.get_sha256(INPUT) == INPUT_SHA
		and FileAccess.get_sha256(HUMAN_REPORT) == HUMAN_REPORT_SHA
		and FileAccess.get_sha256(FIRST_AI) == FIRST_AI_SHA,
		"original retained checkpoint, human and first AI report bytes unchanged")
	await TestAudioDrain.finish(get_tree())
	_write("ac02-pending-completion-summary.json", {
		"schema": "AC02-PENDING-COMPLETION-v1", "pid": OS.get_process_id(),
		"runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"checks": _checks, "failures": _failures, "failed": _failed,
		"status": _status, "failed_reason": _failed_reason,
		"input_sha256": INPUT_SHA, "retained_human_report_sha256": HUMAN_REPORT_SHA,
		"season_seed": SEED, "venue_ordinal": 0, "assignment_version": 3,
		"family_ids": _family_ids, "round_reports": _family_ids.size(),
		"human_starts": _human_starts, "retained_human_reports": _retained_human,
		"retained_ai_reports": _retained_ai, "retained_first_ai_sha256": FIRST_AI_SHA,
		"new_ai_reports": _ai_reports.size(), "terminal": _terminal, "samples": _samples,
		"settled": _failures == 0 and _status == "settled",
		"wall_seconds": (Time.get_ticks_msec() - _started) / 1000.0,
		"manual_input_qualified": false, "performance_qualified": false,
		"independent_seed47_replay": false,
		"five_park_allocation_complete": false, "explicit_assignment_verified": _assignment_verified})
	print("AC02_PENDING_COMPLETION checks=%d failures=%d retained_human=%d new_ai=%d source=%s" % [
		_checks, _failures, _retained_human, _ai_reports.size(), _runtime])
	get_tree().quit(0 if _failures == 0 and _status == "settled" else 1)


func _run() -> void:
	if not _check(_output.is_absolute_path() and not _output.is_empty()
		and DirAccess.make_dir_recursive_absolute(_output) == OK
		and DirAccess.get_files_at(_output).is_empty()
		and DirAccess.get_directories_at(_output).is_empty(), "fresh isolated output"):
		return
	_admitted = true
	if not _check(FileAccess.get_sha256(INPUT) == INPUT_SHA
		and INPUT_SHA.length() == 64 and FileAccess.get_file_as_bytes(INPUT).size() == INPUT_BYTES
		and FileAccess.get_sha256(HUMAN_REPORT) == HUMAN_REPORT_SHA
		and FileAccess.get_file_as_bytes(HUMAN_REPORT).size() == 146437
		and FileAccess.get_sha256(FIRST_AI) == FIRST_AI_SHA
		and FileAccess.get_file_as_bytes(FIRST_AI).size() == 171487,
		"exact retained completed pending and original human report"):
		return
	SeasonSave.path = _output.path_join("public-season.json")
	PitchBatLabSettings.path = _output.path_join("public-settings.cfg")
	if not _check(DirAccess.copy_absolute(INPUT, SeasonSave.path) == OK
		and FileAccess.get_sha256(SeasonSave.path) == INPUT_SHA,
		"byte-copy retained save; ordinary loader owns decoding"):
		return
	if not _check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
		and not get_tree().paused, "ordinary unpaused fixed60 clock"):
		return
	await get_tree().process_frame
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	_pending = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	if not _check(_app.season != null and _app.season.physical != null
		and ClubCareer.same(_pending, SeasonSave.snapshot(_app.season))
		and _app.season.physical.pending.human.size() == 17
		and _app.season.physical.pending.reports.size() == 1
		and _app.season.physical.reports.is_empty()
		and _app.season.results.is_empty() and _app.lab == null
		and not _app.round_ui.process_jobs and not _app.round_ui._working,
		"ordinary exact save61 restore with retained human, one AI and zero settled results"):
		return
	_assignment_verified = _assignment(_app.season)
	if not _check(_assignment_verified, "actual Ac02 ordinal0 saved five-host golden map and quota"):
		return
	for fixture_id: int in range(3):
		var scheduled: Dictionary = SeasonVenues.fixture_for_id(_app.season, fixture_id)
		if not _check(_binding(
			SeasonVenues.for_fixture(_app.season, scheduled), _app.season, fixture_id),
			"actual opening fixture%d binds exact family and saved independent environment" % fixture_id):
			return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HUMAN_REPORT))
	var human: Dictionary = _app.season.physical.pending.human[16]
	var retained_checks: Array[String] = _retained_evidence(report, human)
	for error: String in retained_checks:
		_check(false, error)
	if not _check(retained_checks.is_empty()
		and _report_bound(report, _app.season, 0)
		and StadiumNpcYardTwoHumanEvidence.pending_valid(
			_app.season, _app.season.physical.pending.human)
		and ClubCareer.same(report.property, human.property)
		and report.away_runs == human.away_runs and report.home_runs == human.home_runs
		and report.plays.size() == human.plays.size()
		and ClubCareer.same(report.surfaces, human.surfaces)
		and ClubCareer.same(report.yard, human.yard),
		"retained original human report17 and pending evidence bind exact saved fixture"):
		return
	_retained_human += 1
	_family_ids.append(report.property.manifest.id)
	var first_ai: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIRST_AI))
	var first_row: Dictionary = _app.season.physical.pending.reports[0]
	var projection: Dictionary = SeasonRoundSettlement.project(_app.season)
	if not _check(first_row.fixture == 1 and _report_bound(first_ai, _app.season, 1)
		and ClubCareer.same(first_row.report, first_ai)
		and not projection.has("error") and projection.has("fixture")
		and ClubCareer.same(projection.fixture, {"id": 2, "round": 0, "away": 2, "home": 3})
		and ClubCareer.same(_pending, SeasonSave.snapshot(_app.season)),
		"ordinary projection consumes retained AE02 report and requests only missing AY02 fixture2"):
		return
	_retained_ai = 1
	_family_ids.append(first_ai.property.manifest.id)
	_write("ac02-retained-first-ai-report17.json", first_ai)
	_app.child_entered_tree.connect(func(node: Node) -> void:
		if node is PitchBatLab:
			_human_starts += 1)

	_write("ac02-retained-human-report17.json", report)
	_write("ac02-retained-human-evidence.json", human)
	_write("ac02-retained-pending.json", _pending)
	var restored: SeasonState = SeasonSave.restore()
	if not _check(restored != null and ClubCareer.same(_pending, SeasonSave.snapshot(restored)),
		"actual completed pending state survives exact saved replay"):
		return
	var forged: Dictionary = _pending.duplicate(true)
	forged.physical.pending.human[16].clear()
	_check(SeasonSave._decode(forged) == null,
		"stripped completed human venue evidence refuses pending replay")
	var assignment: String = SeasonVenues.key(_app.season.npc_venues)
	var home: String = StadiumLayoutSnapshot.key(_app.season.home_property)
	var ledger: Dictionary = ClubPlayers.assets(_app.season.career).to_data()
	_app.round_ui.runner.failed.connect(_on_failed)
	_app.round_ui.runner.finished.connect(_on_finished)
	_capture("restored_waiting")
	# Exactly the existing RESUME / RETRY action; no completed-human callback replay.
	_app.round_ui.resume()
	_capture("after_resume")
	if not await _complete_round():
		return
	if not _check(_app.season.results.size() == 3 and _app.season.player_results.size() == 1
		and _app.season.physical.reports.size() == 2
		and _app.season.physical.pending.is_empty() and _app.season.round_index == 1
		and _app._result_saved and _ai_reports.size() == 1 and _retained_ai == 1
		and _human_starts == 0,
		"ordinary AY02 job settles retained AC02/AE02 opening round exactly once"):
		return
	for index: int in range(_ai_reports.size()):
		var report_row: Dictionary = _ai_reports[index]
		if not _check(_report_bound(report_row, _app.season, index + 2)
			and ClubCareer.same(report_row, _app.season.physical.reports[index + 1].report)
			and ClubCareer.same(report_row, JSON.parse_string(JSON.stringify(report_row, "", true, true))),
			"actual AI fixture%d report15 binds saved owner and survives exact JSON reload" % (index + 2)):
			return
		_family_ids.append(report_row.property.manifest.id)
	if not _check(_family_ids == ["AC-02", "AE-02", "AY-02"],
		"retained AC02/AE02 report17 plus one new AY02 report15 supply exact family evidence"):
		return
	_check(ClubCareer.same(_app.season.physical.reports[0], first_row),
		"settlement preserves exact original first AI envelope without replay or replacement")
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
	_check(_app.lab == null and _app.round_ui.runner._lab == null,
		"ordinary resume leaves no managed human or AI lab")
	var settlement_errors: Array[String] = StadiumNpcYardTwoPublicChecks.settled(_app.season, 0)
	for error: String in settlement_errors:
		_check(false, error)
	_check(settlement_errors.is_empty(), "focused actual settled save and duplicate controls")
	_write("ac02-pending-final-save.json", after)
	_refused_start_preserves(after)
	_status = "settled"


func _complete_round() -> bool:
	var next_sample: int = Time.get_ticks_msec() + 10000
	for frame: int in range(MAX_ROUND_FRAMES):
		if _app.season.results.size() == 3 and _app.season.physical.pending.is_empty():
			_capture("settled")
			return true
		var lab: PitchBatLab = _app.round_ui.runner._lab
		if not _failed_reason.is_empty() or not _app.round_ui._working \
			or _app.round_ui.heading.text == "ROUND WAITING" \
			or (is_instance_valid(lab) and lab.get_meta("stadium_npc_runtime_interrupted", false)):
			_status = "round_waiting_or_refused"
			_capture(_status)
			_check(false, "ordinary round refused: " + _app.round_ui.detail.text + " " + _failed_reason)
			return false
		if get_tree().paused or Engine.time_scale != 1.0 or Engine.physics_ticks_per_second != 60:
			_status = "clock_refused"
			_capture(_status)
			_check(false, "ordinary round clock changed")
			return false
		if Time.get_ticks_msec() >= next_sample:
			_capture("progress")
			next_sample = Time.get_ticks_msec() + 10000
		await get_tree().physics_frame
	_status = "frame_limit"
	_capture(_status)
	_check(false, "original ordinary round frame bound exceeded")
	return false


func _on_failed(reason: String) -> void:
	_failed_reason = reason
	_capture("runner_failed")


func _on_finished(report: Dictionary) -> void:
	# UI connection persists the real report first; this listener only records evidence.
	_ai_reports.append(report.duplicate(true))
	_write("ac02-pending-ai-%d.json" % _ai_reports.size(), report)
	_capture("runner_finished")


func _capture(event: String) -> void:
	if _samples.size() < MAX_SAMPLES:
		var row: Dictionary = _sample(event)
		_samples.append(row)
		print("AC02_PENDING_OPERANDS ", JSON.stringify(row, "", true, true))


func _sample(event: String) -> Dictionary:
	var ui: SeasonRoundUI = _app.round_ui
	var runner: PhysicalMatchRunner = ui.runner
	var pending: Dictionary = _app.season.physical.pending if _app.season != null \
		and _app.season.physical != null else {}
	return {"event": event, "wall_msec": Time.get_ticks_msec() - _started,
		"notice": _app.notice, "save_error": SeasonSave.last_error,
		"heading": ui.heading.text, "detail": ui.detail.text,
		"status_text": ui.status.text, "working": ui._working,
		"projection_fixture": ui._projection.get("fixture", {}).duplicate(true),
		"projection_error": ui._projection.get("error", ""),
		"result_saved": _app._result_saved,
		"pending_reports": pending.get("reports", []).size(),
		"runner_running": runner._running, "runner_elapsed": runner._elapsed,
		"runner_stalled": runner._stalled, "runner_progress": runner._progress,
		"process_jobs": ui.process_jobs, "process_runner_running": ui.process_runner.running,
		"tree_paused": get_tree().paused, "time_scale": Engine.time_scale,
		"physics_ticks": Engine.physics_ticks_per_second, "lab": _lab_operands(runner._lab)}


func _lab_operands(lab: PitchBatLab) -> Dictionary:
	if not is_instance_valid(lab):
		return {}
	var row: Dictionary = {"process_mode": lab.process_mode,
		"processing": lab.is_processing(), "physics_processing": lab.is_physics_processing(),
		"automation_present": lab._automation != null,
		"releases": lab._automation.releases.size() if lab._automation != null else -1,
		"plays": lab._play_records.size(), "throw_number": lab._throw_number,
		"runtime_interrupted": lab.get_meta("stadium_npc_runtime_interrupted", false),
		"runtime_restoring": lab.get_meta("stadium_npc_runtime_restoring", false),
		"public_bound": lab.get_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND, false),
		"ay02_bound": lab.get_meta(StadiumNpcYardTwoRuntimeV1.PUBLIC_BOUND, false),
		"property_present": false, "lease": {}}
	var property: StadiumNpcYardTwoPropertyV1 = (
		lab.get_meta("stadium_property") as StadiumNpcYardTwoPropertyV1
		if lab.has_meta("stadium_property") else null)
	if property is StadiumNpcYardTwoPropertyV1:
		row.property_present = true
		# Passive cached AY02 operands only; never call validators from sampling.
		row.lease = {"phase": String(property.phase), "public_bound": property.public_bound,
			"installation_generation": property.installation_generation,
			"play_generation": property.play_generation,
			"retirement_reason": property._retirement_reason,
			"auditing": property._auditing, "geometry_scanning": property._geometry_scanning,
			"inside_tree": property.is_inside_tree(),
			"queued_for_deletion": property.is_queued_for_deletion(),
			"process_mode": property.process_mode,
			"processing": property.is_processing(),
			"physics_processing": property.is_physics_processing()}
	var state: MatchState = lab._match_state
	if state != null:
		row.merge({"phase": state.phase, "plate_appearance": state.plate_appearance_number,
			"simulation_seconds": state.elapsed_seconds, "inning": state.inning,
			"top_half": state.top_half, "away": state.away_team.runs,
			"home": state.home_team.runs, "balls": state.balls, "strikes": state.strikes,
			"outs": state.outs, "last_event": state.last_event})
	return row


func _retained_evidence(report: Dictionary, human: Dictionary) -> Array[String]:
	var season: SeasonState = _app.season
	var errors: Array[String] = []
	var fixture: Dictionary = season.pending_fixture()
	var expected: Dictionary = SeasonVenues.for_fixture(season, fixture)
	if human.is_empty() or not StadiumNpcYardTwoHumanEvidence.valid(human):
		errors.append("retained original human terminal evidence")
	if report.is_empty() or not PhysicalMatchReport.valid(report) \
		or not StadiumNpcPublicReport.matches(report, expected):
		errors.append("retained original automated report17")
	if not errors.is_empty():
		return errors
	var decoded: Variant = JSON.parse_string(JSON.stringify(report, "", true, true))
	if not PhysicalMatchReport.valid(decoded) or not ClubCareer.same(report, decoded):
		errors.append("report17 JSON reload")
	decoded = JSON.parse_string(JSON.stringify(human, "", true, true))
	if not StadiumNpcYardTwoHumanEvidence.valid(decoded) or not ClubCareer.same(human, decoded):
		errors.append("human evidence JSON reload")
	var bad: Dictionary = report.duplicate(true)
	bad.seed = (int(bad.seed) + 1) & 0x7fffffff
	if PhysicalMatchReport.valid(bad):
		errors.append("wrong report seed accepted")
	bad = report.duplicate(true)
	bad.property.binding.venue_id = "AY-03"
	if PhysicalMatchReport.valid(bad):
		errors.append("wrong venue accepted")
	bad = report.duplicate(true)
	bad.property.binding.environment_seed = (
		(int(bad.property.binding.environment_seed) + 1) & 0x7fffffff)
	if PhysicalMatchReport.valid(bad):
		errors.append("wrong saved environment seed accepted")
	bad = report.duplicate(true)
	bad.property.binding.erase("assignment_version")
	if PhysicalMatchReport.valid(bad):
		errors.append("missing assignment3 binding accepted")
	bad = expected.duplicate(true)
	bad.binding.fixture = (int(bad.binding.fixture) + 1) % 30
	bad.environment.fixture = bad.binding.fixture
	if StadiumNpcPublicReport.matches(report, bad):
		errors.append("wrong expected fixture accepted")
	bad = report.duplicate(true)
	bad.yard.append({"instance": "npc:AY-01:r1:forged", "surface": "CONE_BODY",
		"preterminal": true, "elapsed": 1.0})
	if PhysicalMatchReport.valid(bad):
		errors.append("foreign provenance accepted")
	bad = report.duplicate(true)
	bad.surfaces.pop_back()
	if PhysicalMatchReport.valid(bad):
		errors.append("missing play contacts accepted")
	bad = StadiumNpcPublicReport.core(report)
	bad.field = StadiumNpcSnapshot.FIELD
	if PhysicalMatchReport.valid(bad):
		errors.append("bare NPC report7 accepted")
	bad = human.duplicate(true)
	bad.request = "0".repeat(64)
	if StadiumNpcYardTwoHumanEvidence.accepts(season, fixture, bad,
		human.away_runs, human.home_runs, human.performance, {"base": human.base}):
		errors.append("wrong human request accepted")
	bad = human.duplicate(true)
	bad.fixture = (int(bad.fixture) + 1) % 30
	if StadiumNpcYardTwoHumanEvidence.valid(bad):
		errors.append("wrong human fixture accepted")
	if not StadiumPoolOwnedReport._source_hash(
		"ff4995cc3e6b58450d304ba18d368c040d223c688aa83ba5799b21a757a99d93"):
		errors.append("accepted Pool epoch lost")
	return errors


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


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		_failed.append(label)
		print("AC02_PENDING_COMPLETION_FAIL ", label)
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


func _assignment(season_value: SeasonState) -> bool:
	if not SeasonVenues.matches_season(season_value) or season_value.season_seed != SEED \
		or SeasonVenues.run_for(season_value) != 1 or season_value.difficulty != 1:
		return false
	var data: Dictionary = season_value.npc_venues
	if data.version != 3 or data.venue_ordinal != 0 or data.assignments.size() != 5 \
		or data.environments.size() != 32 or not ClubCareer.same(data.streams,
			{"layout": 622598292, "owner": 380739901, "environment": 668002606}) \
		or not ClubCareer.same(data.quota,
			{"backyard": 2, "expanded": 2, "club": 1, "mogul": 0}):
		return false
	var ids: Array[String] = ["AE-02", "AY-03", "AY-02", "AE-01", "AC-02"]
	var revisions: Array[int] = [1, 1, 1, 2, 1]
	for index: int in range(ids.size()):
		var entry: Dictionary = data.assignments[str(index + 1)]
		if entry.manifest.id != ids[index] \
			or entry.manifest.revision != revisions[index]:
			return false
	return true



func _binding(snapshot: Dictionary, season_value: SeasonState, fixture_id: int) -> bool:
	if snapshot.is_empty() or fixture_id < 0 or fixture_id > 2 or not _assignment(season_value):
		return false
	var ids: Array[String] = ["AC-02", "AE-02", "AY-02"]
	var hosts: Array[int] = [5, 1, 3]
	var away: Array[int] = [0, 4, 2]
	var fixture: Dictionary = SeasonVenues.fixture_for_id(season_value, fixture_id)
	return ClubCareer.same(fixture, {"id": fixture_id, "round": 0,
		"away": away[fixture_id], "home": hosts[fixture_id]}) \
		and StadiumNpcSnapshot.matches_fixture(snapshot, season_value, fixture) \
		and snapshot.version == 19 and snapshot.manifest.id == ids[fixture_id] \
		and snapshot.manifest.revision == 1 \
		and snapshot.binding.assignment_version == 3 \
		and snapshot.binding.assignment_key == SeasonVenues.key(season_value.npc_venues) \
		and snapshot.binding.owner_club == hosts[fixture_id] \
		and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season_value, fixture) \
		and snapshot.binding.environment_seed == snapshot.environment.seed \
		and ClubCareer.same(snapshot.environment, season_value.npc_venues.environments[str(fixture_id)]) \
		and snapshot.environment.mode == "day" and snapshot.environment.profile.is_empty()



func _report_bound(report: Dictionary, season_value: SeasonState, fixture_id: int) -> bool:
	var fixture: Dictionary = SeasonVenues.fixture_for_id(season_value, fixture_id)
	if not report.get("property") is Dictionary \
		or not _binding(report.property, season_value, fixture_id) \
		or not PhysicalMatchReport.valid(report):
		return false
	var expected: Dictionary = SeasonVenues.for_fixture(season_value, fixture)
	# Only the scheduled AY-02 r1 fixture uses its existing report15 envelope.
	if fixture_id == 2:
		return report.get("version") == 15 and report.resolver == StadiumNpcYardTwoReport.RESOLVER \
			and report.property.manifest.id == "AY-02" and report.property.manifest.revision == 1 \
			and StadiumNpcYardTwoReport.valid(report) and StadiumNpcYardTwoReport.matches(report, expected)
	return report.get("version") == 17 and report.resolver == StadiumNpcPublicReport.RESOLVER \
		and StadiumNpcPublicReport.valid(report) and StadiumNpcPublicReport.matches(report, expected)

