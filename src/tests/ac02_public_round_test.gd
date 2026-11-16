extends Node
## One real AC02 opening away game from a fixed saved Base ordinal0 test assignment.
## Production new-season UI remains ordinal0; ordinary Expanded and AY02 jobs settle the round.
## Existing automation supplies inputs; no fixture, phase, clock or result is manufactured.
# gdlint: disable=max-file-lines,max-returns

const FIXTURE = preload("res://src/tests/ac02_public_fixture.gd")
const RETAINED_CHECKS = preload("res://src/tests/ac02_issued_round_retained_checks.gd")
const SEED: int = 6
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
var _initial_issue_id: int = 0
var _io_failed: bool = false


func _ready() -> void:
	_started = Time.get_ticks_usec()
	var expected: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--ac02-public-dir="):
			_output = argument.trim_prefix("--ac02-public-dir=")
		elif argument.begins_with("--ac02-public-runtime="):
			expected = argument.trim_prefix("--ac02-public-runtime=")
		elif argument.begins_with("--ac02-public-execution="):
			_execution = argument.trim_prefix("--ac02-public-execution=")
		elif argument.begins_with("--ac02-public-nonce="):
			_nonce = argument.trim_prefix("--ac02-public-nonce=")
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
		"fixed source/run arguments and in-process round jobs"
	):
		await _run()
	if _admitted:
		_write(
			"ac02-public-precleanup.json",
			{
				"checks": _checks,
				"failures": _failures,
				"failed": _failed,
				"io_failed": _io_failed,
				"round_error": _round_error,
				"terminal": _terminal,
				"pending": _pending,
				"ai_reports": _ai_reports
			}
		)
	if is_instance_valid(_app):
		_app.round_ui.cancel()
		_app._close_match()
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
	_write(
		"ac02-public-round-summary.json",
		{
			"schema": "AC02-PUBLIC-ROUND-v1",
			"pid": OS.get_process_id(),
			"runtime": _runtime,
			"execution": _execution,
			"nonce": _nonce,
			"checks": _checks,
			"failures": _failures,
			"failed": _failed,
			"season_seed": SEED,
			"fixture": 0,
			"assigned_owner": 5,
			"venue_ordinal": 0,
			"production_venue_ordinal": 0,
			"assignment_version": 3,
			"family_ids": _family_ids,
			"round_reports": _family_ids.size(),
			"human_starts": _human_starts,
			"ai_reports": _ai_reports.size(),
			"terminal": _terminal,
			"settled": _failures == 0 and not _terminal.is_empty(),
			"wall_seconds": (Time.get_ticks_usec() - _started) / 1000000.0,
			"manual_input_qualified": false,
			"performance_qualified": false,
			"independent_seed47_replay": false,
			"explicit_assignment_verified": _assignment_verified,
			"five_park_allocation_complete": false,
			"round_error": _round_error,
			"io_failed": _io_failed,
			"initial_issue_id": _initial_issue_id
		}
	)
	print(
		(
			"AC02_PUBLIC_ROUND checks=%d failures=%d human=%d ai=%d source=%s"
			% [_checks, _failures, _human_starts, _ai_reports.size(), _runtime]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


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
	if not _check(
		(
			Engine.physics_ticks_per_second == 60
			and Engine.time_scale == 1.0
			and not get_tree().paused
		),
		"ordinary unpaused fixed60 clock"
	):
		return
	# Test setup uses the same real allocator and draft helper as the installed-slice proofs.
	# Save first; SeasonApp's ordinary loader and managed away entry consume the fixture.
	var prepared: SeasonState = FIXTURE.season()
	if not _check(
		(
			prepared != null
			and _assignment(prepared)
			and prepared.results.is_empty()
			and prepared.player_results.is_empty()
			and prepared.physical.pending.is_empty()
			and prepared.physical.reports.is_empty()
		),
		"fixed Base ordinal0 seed6 actual five-host assignment and genuine completed draft"
	):
		return
	_assignment_verified = true
	var initial: Dictionary = SeasonSave.snapshot(prepared)
	if not _check(
		initial.get("version") == 61 and SeasonSave.save(prepared),
		"real drafted AC02 fixture saved through save61 before ordinary app restore"
	):
		return
	await get_tree().process_frame
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	await get_tree().process_frame
	var restored: SeasonState = SeasonSave.restore()
	if not _check(
		(
			_app.season != null
			and restored != null
			and ClubCareer.same(initial, SeasonSave.snapshot(_app.season))
			and ClubCareer.same(initial, SeasonSave.snapshot(restored))
		),
		"ordinary app and save61 restore exact assignment and genuine drafted season"
	):
		return
	if not _write("ac02-public-initial-save.json", SeasonSave.snapshot(_app.season)):
		return
	var fixture: Dictionary = _app.season.pending_fixture()
	if not _check(
		(
			ClubCareer.same(fixture, {"id": 0, "round": 0, "away": 0, "home": 5})
			and ClubCareer.same(fixture, FIXTURE.fixture(_app.season))
			and SeasonState.field_for_fixture(fixture, _app.season).id == &"field.npc_venue"
		),
		"real opening schedule selects AC02r1 without edited fixture or history"
	):
		return
	for fixture_id: int in range(3):
		var scheduled: Dictionary = SeasonVenues.fixture_for_id(_app.season, fixture_id)
		if not _check(
			_binding(SeasonVenues.for_fixture(_app.season, scheduled), _app.season, fixture_id),
			"opening fixture%d binds exact saved owner and day environment" % fixture_id
		):
			return
	var assignment: String = SeasonVenues.key(_app.season.npc_venues)
	var home: String = StadiumLayoutSnapshot.key(_app.season.home_property)
	var ledger: Dictionary = ClubPlayers.assets(_app.season.career).to_data()
	_app.child_entered_tree.connect(_configure_automation)
	_app.round_ui.runner.failed.connect(func(reason: String) -> void: _round_error = reason)
	_app.round_ui.runner.finished.connect(
		func(report: Dictionary) -> void:
			_ai_reports.append(report.duplicate(true))
			if not _write("ac02-public-ai-%d.json" % (_ai_reports.size() - 1), report):
				_io_failed = true
	)
	_app.play_season_game()
	if not _check(
		(
			_app.lab != null
			and _automation_ready
			and _human_starts == 1
			and _app.lab._managed_match
			and not _app.lab._player_home
			and _app.lab._npc_season == _app.season
			and StadiumNpcSnapshot.matches_fixture(
				_app.lab._match_state.stadium, _app.season, fixture
			)
			and StadiumNpcPublicRuntime.installed_bound(_app.lab, _app.lab._match_state.stadium)
		),
		"real managed away entry installs bound AC02r1 before ordinary inputs"
	):
		return
	var lab: PitchBatLab = _app.lab
	var state: MatchState = lab._match_state
	var initial_issue: Dictionary = _issued_observation(lab)
	if not _write("ac02-public-issued-start.json", initial_issue):
		return
	if not _check(
		initial_issue.get("active", false), "actual AC02 begins with issued ACTIVE ownership"
	):
		return
	_initial_issue_id = int(initial_issue.instance_id)
	var live: WeakRef = weakref(lab)
	var last_progress: String = ""
	var stalled: int = 0
	var logged: int = -1
	for frame: int in range(MAX_MATCH_FRAMES):
		if _io_failed:
			return
		if not is_instance_valid(lab):
			_check(false, "managed public game interrupted before natural completion")
			return
		# Settlement intentionally revokes before pending is durable. Once that
		# terminal boundary exists, validate its exact retained ticket below instead
		# of requiring the completed lab to retain live gameplay authority.
		if (
			state.phase == MatchState.Phase.GAME_END
			and _app._result_recorded
			and not _app.season.physical.pending.is_empty()
		):
			break
		if lab.has_meta("stadium_npc_runtime_interrupted") or lab._automation == null:
			_check(false, "managed public game interrupted before natural completion")
			return
		var progress: String = (
			"%d:%d:%d" % [state.phase, state.plate_appearance_number, lab._throw_number]
		)
		stalled = stalled + 1 if progress == last_progress else 0
		last_progress = progress
		if stalled > 1800 or state.elapsed_seconds >= PhysicalMatchRunner.MAX_SECONDS:
			_check(false, "ordinary managed game exceeded existing progress/time bounds")
			return
		if lab._automation.releases.size() % 25 == 0 and logged != lab._automation.releases.size():
			logged = lab._automation.releases.size()
			print(
				"AC02_PUBLIC_PROGRESS stage=human releases=",
				logged,
				" inning=",
				state.inning,
				" away=",
				state.away_team.runs,
				" home=",
				state.home_team.runs,
				" sim=",
				state.elapsed_seconds
			)
		await get_tree().physics_frame
	if not _check(
		(
			state.phase == MatchState.Phase.GAME_END
			and _app._result_recorded
			and not _app.season.physical.pending.is_empty()
		),
		"natural game end reaches ordinary durable pending branch"
	):
		return
	_pending = SeasonSave.snapshot(_app.season)
	if not _write("ac02-public-pending.json", _pending):
		return
	var retained: Dictionary = _retain_settlement_outputs(lab, fixture)
	if retained.is_empty():
		return
	# Same original terminal predicates, applied to actual pre-revocation outputs.
	# Never recapture through a revoked issuer or use retained data as live authority.
	var terminal_checks: Dictionary = RETAINED_CHECKS.terminal(
		_app.season, retained.human, retained.report
	)
	for error: String in terminal_checks.errors:
		_check(false, error)
	if not _check(terminal_checks.errors.is_empty(), "focused actual terminal report negatives"):
		return
	var report: Dictionary = terminal_checks.report
	var human: Dictionary = terminal_checks.human
	if not _check(
		(
			report.get("version") == 17
			and PhysicalMatchReport.valid(report)
			and _report_bound(report, _app.season, 0)
			and not human.is_empty()
			and _app.season.physical.pending.human.size() == 17
			and ClubCareer.same(human, _app.season.physical.pending.human[16])
		),
		"actual terminal report17 and human evidence bind same saved fixture"
	):
		return
	_family_ids.append(report.property.manifest.id)
	_terminal = {
		"away": state.away_team.runs,
		"home": state.home_team.runs,
		"inning": state.inning,
		"top_half": state.top_half,
		"releases": lab._automation.releases.size(),
		"plays": lab._play_records.size(),
		"simulation_seconds": state.elapsed_seconds,
		"report_version": report.version,
		"fixture_key": StadiumNpcSnapshot.key(state.stadium)
	}
	if not _write("ac02-public-report17.json", report):
		return
	if not _write("ac02-public-human-evidence.json", human):
		return
	restored = SeasonSave.restore()
	if not _check(
		restored != null and ClubCareer.same(_pending, SeasonSave.snapshot(restored)),
		"actual completed pending state survives exact saved replay"
	):
		return
	var forged: Dictionary = _pending.duplicate(true)
	forged.physical.pending.human[16].clear()
	_check(
		SeasonSave._decode(forged) == null,
		"stripped completed human venue evidence refuses pending replay"
	)
	# Automation has no human outro. Use the existing completed-result resume branch.
	_app._commit_result()
	for frame: int in range(MAX_ROUND_FRAMES):
		if _io_failed:
			return
		if not _round_error.is_empty():
			_check(false, "ordinary AI job failed: " + _round_error)
			return
		if _app.season.results.size() == 3 and _app.season.physical.pending.is_empty():
			break
		if frame % 600 == 0:
			var current: Dictionary = _app.round_ui._projection.get("fixture", {})
			print(
				"AC02_PUBLIC_PROGRESS stage=round fixture=",
				current.get("id", -1),
				" completed=",
				_ai_reports.size()
			)
		await get_tree().physics_frame
	if not _write("ac02-public-settlement-raw.json", SeasonSave.snapshot(_app.season)):
		return
	if not _check(
		(
			_app.season.results.size() == 3
			and _app.season.player_results.size() == 1
			and _app.season.physical.reports.size() == 2
			and _app.season.physical.pending.is_empty()
			and _app.season.round_index == 1
			and _app._result_saved
			and _ai_reports.size() == 2
		),
		"ordinary AE02 and AY02 jobs settle the actual AC02 opening round exactly once"
	):
		return
	for index: int in range(_ai_reports.size()):
		var report_row: Dictionary = _ai_reports[index]
		if not _check(
			(
				_report_bound(report_row, _app.season, index + 1)
				and ClubCareer.same(report_row, _app.season.physical.reports[index].report)
				and ClubCareer.same(
					report_row, JSON.parse_string(JSON.stringify(report_row, "", true, true))
				)
			),
			"family report fixture%d binds saved owner and survives exact JSON reload" % (index + 1)
		):
			return
		_family_ids.append(report_row.property.manifest.id)
	if not _check(
		_family_ids == ["AC-02", "AE-02", "AY-02"],
		"actual AC02/AE02 report17 and scheduled AY02 report15 supply exact family evidence"
	):
		return
	var after: Dictionary = SeasonSave.snapshot(_app.season)
	restored = SeasonSave.restore()
	_check(
		restored != null and ClubCareer.same(after, SeasonSave.snapshot(restored)),
		"settled save61 restores exact results, reward history and assignment"
	)
	_check(
		(
			SeasonVenues.key(_app.season.npc_venues) == assignment
			and StadiumLayoutSnapshot.key(_app.season.home_property) == home
			and ClubCareer.same(ledger, ClubPlayers.assets(_app.season.career).to_data())
		),
		"away play preserves frozen venues and paid home inventory"
	)
	var duplicate: SeasonState = SeasonSave._decode(after)
	_check(
		(
			duplicate != null
			and not duplicate.callv("record_player_result", _pending.physical.pending.human)
			and ClubCareer.same(after, SeasonSave.snapshot(duplicate))
		),
		"same human result cannot settle again against next scheduled fixture"
	)
	_check(
		_app._commit_result() and ClubCareer.same(after, SeasonSave.snapshot(_app.season)),
		"repeat completion callback cannot repay or repeat the round"
	)
	_check(
		live.get_ref() == null and _app.lab == null,
		"ordinary resume disposes the played managed lab"
	)
	var settlement_errors: Array[String] = StadiumNpcYardTwoPublicChecks.settled(_app.season, 0)
	for error: String in settlement_errors:
		_check(false, error)
	_check(settlement_errors.is_empty(), "focused actual settled save and duplicate controls")
	if not _write("ac02-public-final-save.json", after):
		return
	_refused_start_preserves(after)


func _issued_observation(lab: PitchBatLab) -> Dictionary:
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	var row: Dictionary = {
		"present": false,
		"active": false,
		"instance_id": 0,
		"generation": 0,
		"state": -1,
		"reason": "",
		"history": lab._ac02_issued_history
	}
	if issue == null or issue.get_script() != StadiumNpcAc02IssuedStateV1 or property == null:
		return row
	row["present"] = true
	row["instance_id"] = issue.get_instance_id()
	row["generation"] = issue.generation
	row["state"] = issue.state
	row["reason"] = issue.reason
	row["active"] = (
		row.history
		and issue.state == StadiumNpcAc02IssuedStateV1.Lifetime.ACTIVE
		and issue.generation == 1
		and property._ac02_generation == 1
		and property._ac02_issued_once
		and property._ac02_issue == issue
		and property._ac02_issue_pin == issue
		and lab._ac02_issued_owner == issue
	)
	return row


func _retain_settlement_outputs(lab: PitchBatLab, fixture: Dictionary) -> Dictionary:
	var ticket: Dictionary = _app._ac02_settlement_ticket
	var issue: StadiumNpcAc02IssuedStateV1 = ticket.get("issue") as StadiumNpcAc02IssuedStateV1
	var human_args: Variant = ticket.get("human")
	# Shape checks only make raw extraction safe; no retained object is serialized.
	if not _check(
		(
			issue != null
			and issue.get_script() == StadiumNpcAc02IssuedStateV1
			and human_args is Array
			and human_args.size() == 17
			and human_args[16] is Dictionary
		),
		"natural settlement exposes its actual captured report and human output"
	):
		return {}
	var report: Dictionary = issue._settlement_report.duplicate(true)
	var human: Dictionary = human_args[16].duplicate(true)
	var chronology: Dictionary = {
		"issuer": _issued_observation(lab),
		"initial_issue_id": _initial_issue_id,
		"ticket_fixture": ticket.get("fixture", {}),
		"ticket_fixture_id": ticket.get("fixture_id", -1),
		"fixture": fixture,
		"captured_human_args": human_args.duplicate(true),
		"evidence_origin":
		"actual SeasonApp ticket and before_settlement capture, never live recapture"
	}
	# Retain all producer outputs before ownership/data/negative terminal validators.
	if (
		not _write("ac02-public-raw-report17.json", report)
		or not _write("ac02-public-raw-human-evidence.json", human)
		or not _write("ac02-public-settlement-chronology.json", chronology)
	):
		return {}
	if not _check(
		(
			_app._ac02_settlement_owner_intact()
			and _app._ac02_resume_authorized()
			and issue.get_instance_id() == _initial_issue_id
			and issue.generation == 2
			and issue.state == StadiumNpcAc02IssuedStateV1.Lifetime.REVOKED
			and issue.reason == "settlement begins"
			and lab._ac02_issued_history
			and ticket.get("lab") == lab
			and ticket.get("state") == lab._match_state
			and ticket.get("season") == _app.season
			and ticket.get("fixture_id") == 0
			and ClubCareer.same(ticket.get("fixture"), fixture)
			and ClubCareer.same(human_args, _app.season.physical.pending.human)
		),
		"same issued owner captured exact fixture evidence under deep proof then naturally revoked"
	):
		return {}
	return {"human": human, "report": report}


func _assignment(season_value: SeasonState) -> bool:
	if (
		not SeasonVenues.matches_season(season_value)
		or season_value.season_seed != SEED
		or SeasonVenues.run_for(season_value) != 1
		or season_value.difficulty != 1
	):
		return false
	var data: Dictionary = season_value.npc_venues
	if (
		data.version != 3
		or data.venue_ordinal != 0
		or data.assignments.size() != 5
		or data.environments.size() != 32
		or not ClubCareer.same(
			data.streams, {"layout": 622598292, "owner": 380739901, "environment": 668002606}
		)
		or not ClubCareer.same(data.quota, {"backyard": 2, "expanded": 2, "club": 1, "mogul": 0})
	):
		return false
	var ids: Array[String] = ["AE-02", "AY-03", "AY-02", "AE-01", "AC-02"]
	var revisions: Array[int] = [1, 1, 1, 2, 1]
	for index: int in range(ids.size()):
		var entry: Dictionary = data.assignments[str(index + 1)]
		if entry.manifest.id != ids[index] or entry.manifest.revision != revisions[index]:
			return false
	return true


func _binding(snapshot: Dictionary, season_value: SeasonState, fixture_id: int) -> bool:
	if snapshot.is_empty() or fixture_id < 0 or fixture_id > 2 or not _assignment(season_value):
		return false
	var ids: Array[String] = ["AC-02", "AE-02", "AY-02"]
	var hosts: Array[int] = [5, 1, 3]
	var away: Array[int] = [0, 4, 2]
	var fixture: Dictionary = SeasonVenues.fixture_for_id(season_value, fixture_id)
	return (
		ClubCareer.same(
			fixture,
			{"id": fixture_id, "round": 0, "away": away[fixture_id], "home": hosts[fixture_id]}
		)
		and StadiumNpcSnapshot.matches_fixture(snapshot, season_value, fixture)
		and snapshot.version == 19
		and snapshot.manifest.id == ids[fixture_id]
		and snapshot.manifest.revision == 1
		and snapshot.binding.assignment_version == 3
		and snapshot.binding.assignment_key == SeasonVenues.key(season_value.npc_venues)
		and snapshot.binding.owner_club == hosts[fixture_id]
		and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season_value, fixture)
		and snapshot.binding.environment_seed == snapshot.environment.seed
		and ClubCareer.same(
			snapshot.environment, season_value.npc_venues.environments[str(fixture_id)]
		)
		and snapshot.environment.mode == "day"
		and snapshot.environment.profile.is_empty()
	)


func _report_bound(report: Dictionary, season_value: SeasonState, fixture_id: int) -> bool:
	var fixture: Dictionary = SeasonVenues.fixture_for_id(season_value, fixture_id)
	if (
		not report.get("property") is Dictionary
		or not _binding(report.property, season_value, fixture_id)
		or not PhysicalMatchReport.valid(report)
	):
		return false
	var expected: Dictionary = SeasonVenues.for_fixture(season_value, fixture)
	# Only the scheduled AY-02 r1 fixture uses its existing report15 envelope.
	if fixture_id == 2:
		return (
			report.get("version") == 15
			and report.resolver == StadiumNpcYardTwoReport.RESOLVER
			and report.property.manifest.id == "AY-02"
			and report.property.manifest.revision == 1
			and StadiumNpcYardTwoReport.valid(report)
			and StadiumNpcYardTwoReport.matches(report, expected)
		)
	return (
		report.get("version") == 17
		and report.resolver == StadiumNpcPublicReport.RESOLVER
		and StadiumNpcPublicReport.valid(report)
		and StadiumNpcPublicReport.matches(report, expected)
	)


func _refused_start_preserves(before: Dictionary) -> void:
	# Invalid public seed is an existing start refusal, not an injected readiness failure.
	var previous: SeasonState = _app.season
	var primary: String = FileAccess.get_sha256(SeasonSave.path)
	var backup: String = FileAccess.get_sha256(SeasonSave.path + ".bak")
	_app.begin_season(2147483648, true, true, true, true, false)
	_check(
		(
			_app.season == previous
			and not _app.notice.is_empty()
			and ClubCareer.same(before, SeasonSave.snapshot(_app.season))
			and primary == FileAccess.get_sha256(SeasonSave.path)
			and backup == FileAccess.get_sha256(SeasonSave.path + ".bak")
		),
		"actual invalid new-season start preserves prior settled season and both save files"
	)


func _configure_automation(node: Node) -> void:
	if not node is PitchBatLab:
		return
	var lab: PitchBatLab = node
	_automation_ready = (
		_automation_ready
		and not lab.is_node_ready()
		and lab._match_state == null
		and lab._automation == null
	)
	lab._automation = MatchAutomation.new()
	lab._automation.seed = SeasonPhysicalFixtures.seed_for(
		_app.season, _app.season.pending_fixture()
	)
	lab._automation.presentation_enabled = false
	_human_starts += 1


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		_failed.append(label)
		print("AC02_PUBLIC_FAIL ", label)
	return ok


func _write(name: String, value: Dictionary) -> bool:
	if not _admitted:
		return false
	var bytes: PackedByteArray = JSON.stringify(value, "", true, true).to_utf8_buffer()
	if bytes.size() > MAX_JSON_BYTES:
		_io_failed = true
		_check(false, "bounded output " + name)
		return false
	var path: String = _output.path_join(name)
	if FileAccess.file_exists(path):
		_io_failed = true
		_check(false, "fresh output " + name)
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_io_failed = true
		_check(false, "write output " + name)
		return false
	file.store_buffer(bytes)
	file.flush()
	var written: bool = file.get_error() == OK
	file.close()
	if not written:
		_io_failed = true
		_check(false, "flush output " + name)
		return false
	file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_io_failed = true
		_check(false, "readback output " + name)
		return false
	var identical: bool = (
		file.get_length() == bytes.size() and file.get_buffer(bytes.size()) == bytes
	)
	file.close()
	if not identical:
		_io_failed = true
		_check(false, "readback bytes " + name)
	return identical
