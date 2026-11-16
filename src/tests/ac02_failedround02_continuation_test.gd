extends "res://src/tests/ac02_public_round_test.gd"
## Continue the retained pending save from failed full-round execution02 only.
## This is not a rerun or a pass of that failed round. Its original issuer is dead.
## Override both lifecycle entry points; reuse only the unchanged test helpers below.
## No human inputs, play entry, issuer capture, ticket reconstruction or profile mutation.

const RETAINED_FILES: Dictionary = {
	"ac02-public-initial-save.json":
	"91a8456218b62c6fffa171c97090fed1b2296da4161accbbef93bdab724f7524",
	"ac02-public-issued-start.json":
	"2c2e7cea2dc2914e36aece792420f4bf3f4b1fd68ce6a434a9175941caea6346",
	"ac02-public-pending.json": "9ab142251549d47424aea3333741ea91d83fe3864e22033f4ea211c2d8826792",
	"ac02-public-precleanup.json":
	"6a00751ed9bf1b284130bfa87b406ddc8af233534b076e373478773a6e206cb3",
	"ac02-public-raw-human-evidence.json":
	"beec57b32be037585e5fa6344c96fd59aa99890cd8b5ebfd87cbd8c7004bedaf",
	"ac02-public-raw-report17.json":
	"3003262988b1dddb0c2a8123942ce431aa832ec8af4318190584c94de8121a23",
	"ac02-public-settlement-chronology.json":
	"9af49e1ab57a9cd92855221e7cf29a387161f0819f2e0986998ae28c5bc1cf40",
	"public-season.json": "9ab142251549d47424aea3333741ea91d83fe3864e22033f4ea211c2d8826792",
	"public-season.json.bak": "5186867baef5a284fb4ed7ef243951387a3e515344fd177c23e6abc3dc330066"
}

const PREDECESSOR_SOURCE: String = \
	"8f9081d02aaac97718d179c19d27d492624504a283d205551bff528becf76413"
const PREDECESSOR_EXECUTION: String = \
	"e4aea07536235be6d22068e6edde4a9f2a919b8d40fbf0ca86e01a6d1b3a7701"
const PREDECESSOR_NONCE: String = "2d8444d31dc75fa11fd3d19eedd1306c"
const PREDECESSOR_ARCHIVE: String = \
	"069c5a433bf118197535b2923adfc2804b5b9c3734563298d745e7491eded077"
const PREDECESSOR_INPUT_MANIFEST: String = \
	"64f292e1b2676b6fe9ff120be6f20f183e8468d2125c2e620b2b76efffbc5edb"
const PREDECESSOR_FAILED_ARCHIVE: String = \
	"5591a47623db5cf1f7bc39f3e3bab70c0f45e81aa84533f7afe7fb3bb9156d32"
var _input: String = ""
var _input_manifest: String = ""
var _input_sha: String = ""
var _settled: bool = false


func _ready() -> void:
	_started = Time.get_ticks_usec()
	var args: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.split("=", true, 1)
		if parts.size() == 2 and not args.has(parts[0]):
			args[parts[0]] = parts[1]
	_output = args.get("--ac02-cont-dir", "")
	_input = args.get("--ac02-cont-input", "")
	_input_manifest = args.get("--ac02-cont-files", "")
	_input_sha = args.get("--ac02-cont-files-sha", "")
	_execution = args.get("--ac02-cont-execution", "")
	_nonce = args.get("--ac02-cont-nonce", "")
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if _check(
		(
			OS.get_cmdline_user_args().size() == 8
			and args.size() == 7
			and OS.get_cmdline_user_args().has("--physical-in-process")
			and _runtime.length() == 64
			and args.get("--ac02-cont-runtime") == _runtime
			and _execution.length() == 64
			and _nonce.length() == 32
			and _nonce != PREDECESSOR_NONCE
			and _input_sha == PREDECESSOR_INPUT_MANIFEST
		),
		"exact source-bound continuation arguments and ordinary in-process jobs"
	):
		await _run()
	if _admitted:
		_write(
			"ac02-failedround02-continuation-precleanup.json",
			{
				"checks": _checks,
				"failures": _failures,
				"failed": _failed,
				"io_failed": _io_failed,
				"round_error": _round_error,
				"new_ai_reports": _ai_reports,
				"new_human_starts": _human_starts,
				"current_save":
				(
					SeasonSave.snapshot(_app.season)
					if is_instance_valid(_app) and _app.season != null
					else {}
				)
			}
		)
	if is_instance_valid(_app):
		_app.round_ui.cancel()
		_app._close_match()
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
	_write(
		"ac02-failedround02-continuation-summary.json",
		{
			"schema": "AC02-FAILEDROUND02-CONTINUATION-v1",
			"pid": OS.get_process_id(),
			"runtime": _runtime,
			"execution": _execution,
			"nonce": _nonce,
			"checks": _checks,
			"failures": _failures,
			"failed": _failed,
			"io_failed": _io_failed,
			"round_error": _round_error,
			"retained_input_manifest_sha256": _input_sha,
			"predecessor": "failed-full-round-execution02",
			"predecessor_status": "failed",
			"predecessor_source_manifest_sha256": PREDECESSOR_SOURCE,
			"predecessor_execution_sha256": PREDECESSOR_EXECUTION,
			"predecessor_nonce": PREDECESSOR_NONCE,
			"predecessor_pretest_archive_sha256": PREDECESSOR_ARCHIVE,
			"predecessor_failed_outcome_archive_sha256": PREDECESSOR_FAILED_ARCHIVE,
			"original_issuer_reused": false,
			"warm_owner_transition_qualified": false,
			"season_seed": SEED,
			"venue_ordinal": 0,
			"assignment_version": 3,
			"family_ids": _family_ids,
			"new_human_starts": _human_starts,
			"retained_human_reports": 1 if _family_ids.size() > 0 else 0,
			"retained_ai_reports": 0,
			"new_ai_reports": _ai_reports.size(),
			"retained_human_score": _terminal,
			"settled": _settled and _failures == 0 and not _io_failed,
			"explicit_assignment_verified": _assignment_verified,
			"wall_seconds": (Time.get_ticks_usec() - _started) / 1000000.0,
			"manual_input_qualified": false,
			"performance_qualified": false,
			"five_park_allocation_complete": false,
			"original_failed_round_passed": false
		}
	)
	print(
		(
			(
				"AC02_FAILEDROUND02_CONTINUATION checks=%d failures=%d retained_human=%d new_human=%d "
				+ "new_ai=%d source=%s"
			)
			% [
				_checks,
				_failures,
				1 if _family_ids.size() > 0 else 0,
				_human_starts,
				_ai_reports.size(),
				_runtime
			]
		)
	)
	get_tree().quit(0 if _settled and _failures == 0 and not _io_failed else 1)


func _run() -> void:
	if not _check(
		(
			_output.is_absolute_path()
			and _input.is_absolute_path()
			and _input_manifest.is_absolute_path()
			and _output != _input
			and DirAccess.make_dir_recursive_absolute(_output) == OK
			and DirAccess.get_files_at(_output).is_empty()
			and DirAccess.get_directories_at(_output).is_empty()
		),
		"fresh isolated continuation output"
	):
		return
	_admitted = true
	if not _check(
		(
			FileAccess.file_exists(_input_manifest)
			and FileAccess.get_sha256(_input_manifest) == _input_sha
		),
		"owner-bound exact predecessor input manifest"
	):
		return
	var pins: Variant = JSON.parse_string(FileAccess.get_file_as_string(_input_manifest))
	if not _check(
		pins is Dictionary and ClubCareer.same(pins, RETAINED_FILES),
		"only the nine exact failedround02 raw inputs are admitted"
	):
		return
	var raw_inputs: Dictionary = {}
	for name: String in RETAINED_FILES:
		var path: String = _input.path_join(name)
		if not _check(
			FileAccess.file_exists(path) and FileAccess.get_sha256(path) == RETAINED_FILES[name],
			"exact predecessor bytes " + name
		):
			return
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not _check(
			bytes.size() > 0 and bytes.size() <= MAX_JSON_BYTES, "bounded predecessor bytes " + name
		):
			return
		var copy_name: String = "retained-" + name
		if not _write_bytes(copy_name, bytes):
			return
		raw_inputs[name] = {"file": copy_name, "sha256": RETAINED_FILES[name]}
	# All nine exact byte copies precede any game/save/report acceptance predicates.
	await _failed_round_retained_inputs(raw_inputs)


func _failed_round_retained_inputs(raw_inputs: Dictionary) -> void:
	if not _write("ac02-failedround02-retained-inputs.json", raw_inputs):
		return
	_pending = JSON.parse_string(
		FileAccess.get_file_as_string(_output.path_join("retained-ac02-public-pending.json"))
	)
	var report: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_output.path_join("retained-ac02-public-raw-report17.json"))
	)
	var human: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			_output.path_join("retained-ac02-public-raw-human-evidence.json")
		)
	)
	var chronology: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			_output.path_join("retained-ac02-public-settlement-chronology.json")
		)
	)
	var failed: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_output.path_join("retained-ac02-public-precleanup.json"))
	)
	if not _check(
		(
			_pending.version == 61
			and _pending.physical.pending.reports.is_empty()
			and _pending.physical.pending.human.size() == 17
			and _pending.results.is_empty()
			and report.away_runs == 6
			and report.home_runs == 5
			and human.away_runs == 6
			and human.home_runs == 5
			and ClubCareer.same(human, _pending.physical.pending.human[16])
			and ClubCareer.same(chronology.captured_human_args, _pending.physical.pending.human)
			and failed.failures == 1
			and failed.ai_reports.is_empty()
			and (
				failed.failed
				== [
					"same issued owner captured exact fixture evidence under deep proof then naturally revoked"
				]
			)
			and RETAINED_FILES["public-season.json"] == RETAINED_FILES["ac02-public-pending.json"]
		),
		"original failed human terminal 6-5, durable pending, and zero prior AI remain bound"
	):
		return
	SeasonSave.path = _output.path_join("public-season.json")
	PitchBatLabSettings.path = _output.path_join("public-settings.cfg")
	if not _check(
		(
			(
				DirAccess.copy_absolute(
					_output.path_join("retained-public-season.json"), SeasonSave.path
				)
				== OK
			)
			and FileAccess.get_sha256(SeasonSave.path) == RETAINED_FILES["public-season.json"]
		),
		"byte-copy exact retained save for the ordinary loader"
	):
		return
	if not _check(
		(
			Engine.physics_ticks_per_second == 60
			and Engine.time_scale == 1.0
			and not get_tree().paused
		),
		"ordinary unpaused fixed60 clock"
	):
		return
	await get_tree().process_frame
	_app = SeasonApp.new()
	_app.child_entered_tree.connect(
		func(node: Node) -> void:
			if node is PitchBatLab:
				_human_starts += 1
	)
	get_tree().root.add_child(_app)
	if not _check(
		(
			_app.season != null
			and _app.season.physical != null
			and ClubCareer.same(_pending, SeasonSave.snapshot(_app.season))
			and _app.season.physical.pending.human.size() == 17
			and _app.season.physical.pending.reports.is_empty()
			and _app.season.physical.reports.is_empty()
			and _app.season.results.is_empty()
			and _app.lab == null
			and _human_starts == 0
			and _app._ac02_settlement_ticket.is_empty()
			and not _app.round_ui.process_jobs
			and not _app.round_ui._working
		),
		"ordinary restore has exact pending and no human lab or revived process-local issuer ticket"
	):
		return
	_assignment_verified = _assignment(_app.season)
	if not _check(
		_assignment_verified, "actual Ac02 ordinal0 saved five-host golden map and quota"
	):
		return
	await _failed_round_ai_fixtures(report, human)


func _failed_round_ai_fixtures(report: Dictionary, human: Dictionary) -> void:
	for fixture_id: int in range(3):
		var scheduled: Dictionary = SeasonVenues.fixture_for_id(_app.season, fixture_id)
		if not _check(
			_binding(SeasonVenues.for_fixture(_app.season, scheduled), _app.season, fixture_id),
			"original opening fixture%d binds exact family and saved environment" % fixture_id
		):
			return
	var terminal_checks: Dictionary = RETAINED_CHECKS.terminal(_app.season, human, report)
	for error: String in terminal_checks.errors:
		_check(false, error)
	if not _check(
		(
			terminal_checks.errors.is_empty()
			and _report_bound(report, _app.season, 0)
			and StadiumNpcYardTwoHumanEvidence.pending_valid(
				_app.season, _app.season.physical.pending.human
			)
			and ClubCareer.same(report.property, human.property)
			and report.away_runs == human.away_runs
			and report.home_runs == human.home_runs
			and report.plays.size() == human.plays.size()
			and ClubCareer.same(report.surfaces, human.surfaces)
			and ClubCareer.same(report.yard, human.yard)
		),
		"unchanged original terminal and negative validators accept only exact retained AC02 evidence"
	):
		return
	_family_ids.append(report.property.manifest.id)
	_terminal = {"away": report.away_runs, "home": report.home_runs}
	var projection: Dictionary = SeasonRoundSettlement.project(_app.season)
	if not _check(
		(
			not projection.has("error")
			and projection.has("fixture")
			and ClubCareer.same(projection.fixture, {"id": 1, "round": 0, "away": 4, "home": 1})
			and ClubCareer.same(_pending, SeasonSave.snapshot(_app.season))
		),
		"ordinary projection consumes retained human and requests missing AE02 fixture1 first"
	):
		return
	await _failed_round_restore_pending()


func _failed_round_restore_pending() -> void:
	var restored: SeasonState = SeasonSave.restore()
	if not _check(
		restored != null and ClubCareer.same(_pending, SeasonSave.snapshot(restored)),
		"actual retained pending survives exact saved replay"
	):
		return
	var forged: Dictionary = _pending.duplicate(true)
	forged.physical.pending.human[16].clear()
	if not _check(
		SeasonSave._decode(forged) == null,
		"stripped completed human evidence refuses pending replay"
	):
		return
	var assignment: String = SeasonVenues.key(_app.season.npc_venues)
	var home: String = StadiumLayoutSnapshot.key(_app.season.home_property)
	var ledger: Dictionary = ClubPlayers.assets(_app.season.career).to_data()
	_app.round_ui.runner.failed.connect(func(reason: String) -> void: _round_error = reason)
	_app.round_ui.runner.finished.connect(
		func(ai: Dictionary) -> void:
			_ai_reports.append(ai.duplicate(true))
			if not _write("ac02-failedround02-ai-%d.json" % (_ai_reports.size() - 1), ai):
				_io_failed = true
	)
	# Existing RESUME / RETRY route only. Never replay _commit_result on retained human data.
	_app.round_ui.resume()
	if not await _failed_round_resume_jobs():
		return
	if not _write("ac02-failedround02-settlement-raw.json", SeasonSave.snapshot(_app.season)):
		return
	if not _failed_round_verify_settlement():
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
		_app.lab == null and _app.round_ui.runner._lab == null,
		"ordinary resume leaves no managed human or AI lab"
	)
	var settlement_errors: Array[String] = StadiumNpcYardTwoPublicChecks.settled(_app.season, 0)
	for error: String in settlement_errors:
		_check(false, error)
	_check(settlement_errors.is_empty(), "focused actual settled save and duplicate controls")
	if not _write("ac02-failedround02-final-save.json", after):
		return
	_refused_start_preserves(after)
	_failed_round_retained_unchanged()


func _failed_round_retained_unchanged() -> void:
	for name: String in RETAINED_FILES:
		if not _check(
			(
				FileAccess.get_sha256(_input.path_join(name)) == RETAINED_FILES[name]
				and (
					FileAccess.get_sha256(_output.path_join("retained-" + name))
					== RETAINED_FILES[name]
				)
			),
			"original and retained-copy bytes unchanged " + name
		):
			return
	_settled = _failures == 0 and not _io_failed


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		_failed.append(label)
		print("AC02_FAILEDROUND02_CONTINUATION_FAIL ", label)
	return ok


func _write_bytes(name: String, bytes: PackedByteArray) -> bool:
	if not _admitted:
		return false
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
	return _failed_round_readback(name, bytes, file)


func _failed_round_readback(name: String, bytes: PackedByteArray, file: FileAccess) -> bool:
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


func _failed_round_resume_jobs() -> bool:
	for frame: int in range(MAX_ROUND_FRAMES):
		if _io_failed:
			return false
		if not _round_error.is_empty():
			_check(false, "ordinary AI job failed: " + _round_error)
			return false
		if _app.season.results.size() == 3 and _app.season.physical.pending.is_empty():
			break
		if (
			not _app.round_ui._working
			or _app.round_ui.heading.text == "ROUND WAITING"
			or get_tree().paused
			or Engine.time_scale != 1.0
			or Engine.physics_ticks_per_second != 60
		):
			_check(false, "ordinary resume paused, refused, or changed the fixed60 clock")
			return false
		if frame % 600 == 0:
			var current: Dictionary = _app.round_ui._projection.get("fixture", {})
			print(
				"AC02_FAILEDROUND02_CONTINUATION_PROGRESS fixture=",
				current.get("id", -1),
				" new_ai=",
				_ai_reports.size()
			)
		await get_tree().physics_frame
	return true


func _failed_round_verify_settlement() -> bool:
	if not _check(
		(
			_app.season.results.size() == 3
			and _app.season.player_results.size() == 1
			and _app.season.physical.reports.size() == 2
			and _app.season.physical.pending.is_empty()
			and _app.season.round_index == 1
			and _app._result_saved
			and _ai_reports.size() == 2
			and _human_starts == 0
			and _app._ac02_settlement_ticket.is_empty()
		),
		"two genuine scheduled AE02 and AY02 jobs settle retained AC02 pending exactly once"
	):
		return false
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
			"new AI fixture%d report binds saved owner and survives exact JSON reload" % (index + 1)
		):
			return false
		_family_ids.append(report_row.property.manifest.id)
	if not _check(
		_family_ids == ["AC-02", "AE-02", "AY-02"],
		"one retained AC02 and two new AE02/AY02 reports supply the exact scheduled families"
	):
		return false
	return true
