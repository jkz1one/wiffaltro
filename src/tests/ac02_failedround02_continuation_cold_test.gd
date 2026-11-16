extends Node
## Separate cold proof of the continuation only; never passes the prior failed round.
## Fresh-process readback of a completed actual round. No app, lab, match or issuer is created.
const RETAINED_CHECKS = preload("res://src/tests/ac02_issued_round_retained_checks.gd")
const FILES: Array[String] = [
	"retained-ac02-public-pending.json",
	"retained-ac02-public-raw-report17.json",
	"retained-ac02-public-raw-human-evidence.json",
	"ac02-failedround02-ai-0.json",
	"ac02-failedround02-ai-1.json",
	"ac02-failedround02-final-save.json",
	"ac02-failedround02-continuation-summary.json"
]
const MAX_JSON_BYTES: int = 8 * 1024 * 1024
var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _output: String = ""
var _admitted: bool = false
var _io_failed: bool = false
var _input_sha: String = ""
var _runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _round_nonce: String = ""


func _ready() -> void:
	var args: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.split("=", true, 1)
		if parts.size() == 2 and not args.has(parts[0]):
			args[parts[0]] = parts[1]
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	_output = args.get("--ac02-cold-dir", "")
	_execution = args.get("--ac02-cold-execution", "")
	_nonce = args.get("--ac02-cold-nonce", "")
	_round_nonce = args.get("--ac02-cold-round-nonce", "")
	_input_sha = args.get("--ac02-cold-files-sha", "")
	if _check(
		(
			OS.get_cmdline_user_args().size() == 8
			and args.size() == 8
			and _runtime.length() == 64
			and args.get("--ac02-cold-runtime") == _runtime
			and _execution.length() == 64
			and _nonce.length() == 32
			and _input_sha.length() == 64
			and _round_nonce.length() == 32
			and _round_nonce != _nonce
			and args.has("--ac02-cold-input")
			and args.has("--ac02-cold-files")
		),
		"exact cold process and retained-input arguments"
	):
		_run(args)
	_write(
		"ac02-failedround02-continuation-cold-summary.json",
		{
			"schema": "AC02-FAILEDROUND02-CONTINUATION-COLD-v1",
			"pid": OS.get_process_id(),
			"runtime": _runtime,
			"execution": _execution,
			"nonce": _nonce,
			"input_manifest_sha256": _input_sha,
			"checks": _checks,
			"failures": _failures,
			"failed": _failed,
			"io_failed": _io_failed,
			"new_matches": 0,
			"live_issuer_authority": false,
			"original_failed_round_passed": false,
			"warm_owner_transition_qualified": false
		}
	)
	print(
		(
			"AC02_FAILEDROUND02_CONTINUATION_COLD checks=%d failures=%d source=%s"
			% [_checks, _failures, _runtime]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _run(args: Dictionary) -> void:
	var input: String = args["--ac02-cold-input"]
	var manifest_path: String = args["--ac02-cold-files"]
	if not _check(
		(
			_output.is_absolute_path()
			and input.is_absolute_path()
			and manifest_path.is_absolute_path()
			and _output != input
			and DirAccess.make_dir_recursive_absolute(_output) == OK
			and DirAccess.get_files_at(_output).is_empty()
			and DirAccess.get_directories_at(_output).is_empty()
		),
		"fresh isolated cold output"
	):
		return
	_admitted = true
	if not _check(
		(
			FileAccess.file_exists(manifest_path)
			and FileAccess.get_sha256(manifest_path) == _input_sha
		),
		"owner-bound exact actual round input manifest"
	):
		return
	var pins: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not _check(pins is Dictionary and pins.size() == FILES.size(), "bounded exact input set"):
		return
	_cold_continuation_inputs(input, pins)


func _cold_continuation_inputs(input: String, pins: Variant) -> void:
	var retained: Dictionary = {}
	var raw_inputs: Dictionary = {}
	for name: String in FILES:
		var path: String = input.path_join(name)
		if not _check(
			(
				pins.get(name) is String
				and pins[name].length() == 64
				and FileAccess.file_exists(path)
				and FileAccess.get_sha256(path) == pins[name]
			),
			"exact retained bytes " + name
		):
			return
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not _check(
			bytes.size() > 0 and bytes.size() <= MAX_JSON_BYTES, "bounded retained bytes " + name
		):
			return
		var copy_name: String = "ac02-failedround02-continuation-cold-input-" + name
		if not _write_bytes(copy_name, bytes):
			return
		raw_inputs[name] = {"file": copy_name, "sha256": pins[name]}
		var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if not _check(parsed is Dictionary, "retained JSON object " + name):
			return
		retained[name] = parsed
	# Persist the entire actual input set before any report/save acceptance or negative validator.
	if not _write("ac02-failedround02-continuation-cold-raw-inputs.json", raw_inputs):
		return
	if not _check(
		(
			(
				pins["retained-ac02-public-pending.json"]
				== "9ab142251549d47424aea3333741ea91d83fe3864e22033f4ea211c2d8826792"
			)
			and (
				pins["retained-ac02-public-raw-report17.json"]
				== "3003262988b1dddb0c2a8123942ce431aa832ec8af4318190584c94de8121a23"
			)
			and (
				pins["retained-ac02-public-raw-human-evidence.json"]
				== "beec57b32be037585e5fa6344c96fd59aa99890cd8b5ebfd87cbd8c7004bedaf"
			)
		),
		"cold historical inputs remain the exact prior failedround02 bytes"
	):
		return
	_cold_continuation_summary(input, pins, retained)


func _cold_continuation_summary(input: String, pins: Variant, retained: Dictionary) -> void:
	var summary: Dictionary = retained["ac02-failedround02-continuation-summary.json"]
	if not _check(
		(
			summary.get("schema") == "AC02-FAILEDROUND02-CONTINUATION-v1"
			and summary.get("runtime") == _runtime
			and summary.get("execution") == _execution
			and summary.get("nonce") == _round_nonce
			and summary.get("failures") == 0
			and summary.get("failed") == []
			and summary.get("settled") == true
			and summary.get("io_failed") == false
			and summary.get("family_ids") == ["AC-02", "AE-02", "AY-02"]
			and summary.get("new_human_starts") == 0
			and summary.get("new_ai_reports") == 2
			and (
				summary.get("retained_input_manifest_sha256")
				== "64f292e1b2676b6fe9ff120be6f20f183e8468d2125c2e620b2b76efffbc5edb"
			)
			and ClubCareer.same(summary.get("retained_human_score"), {"away": 6, "home": 5})
			and summary.get("retained_human_reports") == 1
			and summary.get("retained_ai_reports") == 0
			and summary.get("predecessor") == "failed-full-round-execution02"
			and summary.get("predecessor_status") == "failed"
			and summary.get("original_failed_round_passed") == false
			and summary.get("original_issuer_reused") == false
			and summary.get("warm_owner_transition_qualified") == false
			and (
				summary.get("predecessor_source_manifest_sha256")
				== "8f9081d02aaac97718d179c19d27d492624504a283d205551bff528becf76413"
			)
			and (
				summary.get("predecessor_execution_sha256")
				== "e4aea07536235be6d22068e6edde4a9f2a919b8d40fbf0ca86e01a6d1b3a7701"
			)
			and summary.get("predecessor_nonce") == "2d8444d31dc75fa11fd3d19eedd1306c"
			and (
				summary.get("predecessor_pretest_archive_sha256")
				== "069c5a433bf118197535b2923adfc2804b5b9c3734563298d745e7491eded077"
			)
			and (
				summary.get("predecessor_failed_outcome_archive_sha256")
				== "5591a47623db5cf1f7bc39f3e3bab70c0f45e81aa84533f7afe7fb3bb9156d32"
			)
		),
		"same successful retained-pending continuation from its distinct prior launch instance"
	):
		return
	var pending_data: Dictionary = retained["retained-ac02-public-pending.json"]
	var final_data: Dictionary = retained["ac02-failedround02-final-save.json"]
	var pending: SeasonState = SeasonSave._decode(pending_data)
	var settled: SeasonState = SeasonSave._decode(final_data)
	if not _check(
		(
			pending != null
			and settled != null
			and ClubCareer.same(SeasonSave.snapshot(pending), pending_data)
			and ClubCareer.same(SeasonSave.snapshot(settled), final_data)
		),
		"fresh cold save61 decoding preserves exact pending and final saves"
	):
		return
	var human: Dictionary = retained["retained-ac02-public-raw-human-evidence.json"]
	var report: Dictionary = retained["retained-ac02-public-raw-report17.json"]
	var result: Dictionary = RETAINED_CHECKS.terminal(pending, human, report)
	if not _check(
		(
			result.errors.is_empty()
			and pending.physical.pending.human.size() == 17
			and ClubCareer.same(human, pending.physical.pending.human[16])
			and ClubCareer.same(report.property, human.property)
			and report.away_runs == human.away_runs
			and report.home_runs == human.home_runs
			and report.plays.size() == human.plays.size()
			and ClubCareer.same(report.surfaces, human.surfaces)
			and ClubCareer.same(report.yard, human.yard)
		),
		"fresh cold report and human proof preserve the original fixture and terminal negatives"
	):
		return
	if not _check(
		(
			settled.results.size() == 3
			and settled.player_results.size() == 1
			and settled.physical.reports.size() == 2
			and settled.physical.pending.is_empty()
			and settled.round_index == 1
			and StadiumNpcYardTwoPublicChecks.settled(settled, 0).is_empty()
		),
		"fresh cold final round is normally settled exactly once"
	):
		return
	for index: int in range(2):
		var ai: Dictionary = retained["ac02-failedround02-ai-%d.json" % index]
		var fixture: Dictionary = SeasonVenues.fixture_for_id(settled, index + 1)
		var expected: Dictionary = SeasonVenues.for_fixture(settled, fixture)
		var matches: bool = (
			StadiumNpcPublicReport.matches(ai, expected)
			if index == 0
			else StadiumNpcYardTwoReport.matches(ai, expected)
		)
		if not _check(
			(
				PhysicalMatchReport.valid(ai)
				and matches
				and ClubCareer.same(ai, settled.physical.reports[index].report)
			),
			"fresh cold AI fixture%d report matches the settled original" % (index + 1)
		):
			return
	var forged: Dictionary = pending_data.duplicate(true)
	forged.physical.pending.human[16].clear()
	_check(SeasonSave._decode(forged) == null, "fresh cold stripped human evidence refuses")
	for name: String in FILES:
		if not _check(
			FileAccess.get_sha256(input.path_join(name)) == pins[name],
			"retained input unchanged " + name
		):
			return


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		_failed.append(label)
		print("AC02_FAILEDROUND02_CONTINUATION_COLD_FAIL ", label)
	return ok


func _write(name: String, value: Dictionary) -> bool:
	if not _admitted:
		return false
	return _write_bytes(name, JSON.stringify(value, "", true, true).to_utf8_buffer())


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
	return _cold_continuation_readback(name, bytes, file)


func _cold_continuation_readback(name: String, bytes: PackedByteArray, file: FileAccess) -> bool:
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
