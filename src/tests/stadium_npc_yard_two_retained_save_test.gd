extends Node
## Replay only the byte-pinned actual R13 save. Never starts a match or a round job.
# gdlint: disable=max-returns

const MAX_JSON_BYTES: int = 8 * 1024 * 1024
const MAX_DIFF_NODES: int = 100000
const MAX_DIFF_SAMPLES: int = 16
const OLD_RUNTIME: String = "38c2d9f45e53664636a4908e1674f41eca507b9df45f3982d3865318039391aa"
const OLD_EXECUTION: String = "68488c3ab5c8a61819273b565d95be217d3b73cd83e15757dd3ece1b6dea66e3"
const INPUT_PINS: Dictionary = {
	"ay02-public-final-save.json":
		"aabce07259d737e7dbbeb8f00139a7963cbeb457b948c23af49336b956106067",
	"public-season.json":
		"aabce07259d737e7dbbeb8f00139a7963cbeb457b948c23af49336b956106067",
	"ay02-public-pending.json":
		"8bed43608de088e434c3ca84fec72c837e9075aeddb9830b8e3726d7e985349f",
	"ay02-public-predraft.json":
		"5bbd833b0c9f02b974a9dfeb6f05488e6399b758d6e1edf827b268cea870eb67",
	"ay02-public-report15.json":
		"20bbc936bbb2a60775cfd0bc73233f746b6648e8b7b5b2a5667c1f7873377564",
	"ay02-public-human-evidence.json":
		"629d68642b0613a0c2bbfcfba3931254b78a3bb5a835d1e50e29fb616a7bd2a4",
	"ay02-public-ai-0.json":
		"99aec5d78505f2d3123e8a697ff76d89c7e9381316b04db20d17b4fdf6be61e8",
	"ay02-public-ai-1.json":
		"0fdfd84fe320ada44f8f871115a9ffeecad07d37da01bb2b979644b6bacd0057",
	"ay02-public-round-summary.json":
		"b6c3ecb00a063702d2cb4bb045ad56b34f07a0863620f93518a97a39d376947e",
}

var _input: String = ""
var _output: String = ""
var _runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _checks: Array[Dictionary] = []
var _failed: Array[String] = []
var _details: Dictionary = {}


func _ready() -> void:
	var started: int = Time.get_ticks_usec()
	var expected: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--ay02-retained-dir="):
			_input = argument.trim_prefix("--ay02-retained-dir=")
		elif argument.begins_with("--ay02-replay-dir="):
			_output = argument.trim_prefix("--ay02-replay-dir=")
		elif argument.begins_with("--ay02-replay-runtime="):
			expected = argument.trim_prefix("--ay02-replay-runtime=")
		elif argument.begins_with("--ay02-replay-execution="):
			_execution = argument.trim_prefix("--ay02-replay-execution=")
		elif argument.begins_with("--ay02-replay-nonce="):
			_nonce = argument.trim_prefix("--ay02-replay-nonce=")
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if not _check(args.size() == 5 and _runtime.length() == 64 and _runtime == expected
		and _execution.length() == 64 and _nonce.length() == 32
		and _input.is_absolute_path() and _output.is_absolute_path()
		and _input.simplify_path() != _output.simplify_path(), "fixed retained replay arguments"):
		get_tree().quit(1)
		return
	if not _check(DirAccess.make_dir_recursive_absolute(_output) == OK
		and DirAccess.get_files_at(_output).is_empty()
		and DirAccess.get_directories_at(_output).is_empty(), "fresh replay output"):
		get_tree().quit(1)
		return
	_run()
	for name: String in INPUT_PINS:
		_check(FileAccess.get_sha256(_input.path_join(name)) == INPUT_PINS[name],
			"retained input unchanged: " + name)
	var summary: Dictionary = {
		"schema": "AY02-RETAINED-SAVE-REPLAY-v1", "pid": OS.get_process_id(),
		"runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"original_runtime": OLD_RUNTIME, "original_execution": OLD_EXECUTION,
		"input_pins": INPUT_PINS, "checks": _checks, "failures": _failed.size(),
		"failed": _failed, "details": _details, "games_started": 0,
		"wall_seconds": (Time.get_ticks_usec() - started) / 1000000.0,
		"new_game_evidence": false, "manual_input_qualified": false,
		"performance_qualified": false, "independent_seed47_replay": false}
	var text: String = JSON.stringify(summary, "", true, true)
	var file: FileAccess = FileAccess.open(
		_output.path_join("ay02-retained-save-replay.json"), FileAccess.WRITE)
	if file == null or text.to_utf8_buffer().size() > 128 * 1024:
		get_tree().quit(1)
		return
	file.store_string(text)
	file.flush()
	var written: bool = file.get_error() == OK
	file.close()
	print("AY02_RETAINED_SAVE_REPLAY checks=%d failures=%d games=0 source=%s" % [
		_checks.size(), _failed.size(), _runtime])
	get_tree().quit(0 if written and _failed.is_empty() else 1)


func _run() -> void:
	var data: Dictionary = {}
	for name: String in INPUT_PINS:
		var value: Dictionary = _read(name)
		if value.is_empty():
			return
		data[name] = value
	var original: Dictionary = data["ay02-public-round-summary.json"]
	if not _check(original.runtime == OLD_RUNTIME and original.execution == OLD_EXECUTION
		and original.human_starts == 1 and original.ai_reports == 2
		and original.terminal.away == 4 and original.terminal.home == 0
		and original.terminal.plays == 124 and original.failures == 2
		and original.failed == ["settled public season save/reload",
			"focused actual settled save and duplicate controls"], "actual failed R13 provenance"):
		return
	var final_save: Dictionary = data["ay02-public-final-save.json"]
	SeasonSave.last_error = ""
	var season: SeasonState = SeasonSave._decode(final_save)
	_details["retained_decode_error"] = SeasonSave.last_error
	if not _check(season != null, "exact retained final-save decodes"):
		return
	var before: Dictionary = SeasonSave.snapshot(season)
	if not _check(ClubCareer.same(final_save, before) and season.round_index == 1
		and season.results.size() == 3 and season.player_results.size() == 1
		and season.physical.reports.size() == 2 and season.physical.pending.is_empty(),
		"actual settled save61 round state exact"):
		return
	var old_path: String = SeasonSave.path
	SeasonSave.path = _input.path_join("public-season.json")
	var disk: SeasonState = SeasonSave.restore()
	_details["disk_restore_error"] = SeasonSave.last_error
	SeasonSave.path = old_path
	_check(disk != null and ClubCareer.same(before, SeasonSave.snapshot(disk)),
		"original full-precision disk save still restores exactly")
	_details["default"] = _roundtrip(before, false)
	_details["full_precision"] = _roundtrip(before, true)
	_check(not _details.default.exact and _details.default.differences.count > 0
		and not _details.default.differences.truncated,
		"original default stringify failure reproduced with exact value differences")
	_check(_details.full_precision.decoded and _details.full_precision.exact
		and _details.full_precision.differences.count == 0
		and not _details.full_precision.differences.truncated,
		"full precision fixes exact roundtrip without changing validation")
	var pending: Dictionary = data["ay02-public-pending.json"]
	SeasonSave.last_error = ""
	var checkpoint: SeasonState = SeasonSave._decode(pending)
	_details["pending_decode_error"] = SeasonSave.last_error
	if not _check(checkpoint != null and ClubCareer.same(pending, SeasonSave.snapshot(checkpoint)),
		"actual completed-human pending save restores exactly"):
		return
	var human: Dictionary = data["ay02-public-human-evidence.json"]
	var report: Dictionary = data["ay02-public-report15.json"]
	_check(StadiumNpcYardTwoHumanEvidence.valid(human) and PhysicalMatchReport.valid(report)
		and StadiumNpcYardTwoReport.matches(report,
			SeasonVenues.for_fixture(checkpoint, checkpoint.pending_fixture()))
		and pending.physical.pending.human.size() == 17
		and ClubCareer.same(pending.physical.pending.human[16], human)
		and ClubCareer.same(final_save.results[0].yard_evidence, human),
		"actual pending17, human evidence, report15 and settled result join")
	var forged: Dictionary = pending.duplicate(true)
	forged.physical.pending.human[16].clear()
	_check(SeasonSave._decode(forged) == null,
		"existing stripped completed-human evidence negative preserved")
	var duplicate_accepted: bool = season.callv("record_player_result", pending.physical.pending.human)
	_check(not duplicate_accepted and ClubCareer.same(before, SeasonSave.snapshot(season)),
		"actual completed pending result cannot settle or pay again")
	SeasonSave.last_error = ""
	var helper_errors: Array[String] = StadiumNpcYardTwoPublicChecks.settled(season, 0)
	_details["settled_helper_errors"] = helper_errors
	_details["settled_helper_last_error"] = SeasonSave.last_error
	_check(helper_errors.is_empty() and ClubCareer.same(before, SeasonSave.snapshot(season)),
		"all existing settled helper controls pass unchanged except stringify precision")
	for index: int in range(2):
		var ai: Dictionary = data["ay02-public-ai-%d.json" % index]
		_check(PhysicalMatchReport.valid(ai) and ai.field == "field.commons_park"
			and ai.version != 15 and ClubCareer.same(season.physical.reports[index].report, ai),
			"retained Commons AI report exact: " + str(index))
	var initial: Dictionary = data["ay02-public-predraft.json"]
	_check(ClubCareer.same(initial.npc_venues, final_save.npc_venues)
		and ClubCareer.same(initial.home_property, final_save.home_property),
		"actual saved assignment and paid home layout preserved")


func _roundtrip(before: Dictionary, full_precision: bool) -> Dictionary:
	var text: String = JSON.stringify(before, "", true, true) if full_precision \
		else JSON.stringify(before)
	var parsed: Variant = JSON.parse_string(text)
	SeasonSave.last_error = ""
	var restored: SeasonState = SeasonSave._decode(parsed)
	var decode_error: String = SeasonSave.last_error
	SeasonSave.last_error = ""
	var snapshot: Dictionary = {} if restored == null else SeasonSave.snapshot(restored)
	var snapshot_error: String = SeasonSave.last_error
	var differences: Dictionary = {"count": 0, "visited": 0, "truncated": false, "samples": []}
	_diff(before, parsed, "$", 0, differences)
	return {"decoded": restored != null,
		"exact": restored != null and ClubCareer.same(before, snapshot),
		"decode_error": decode_error, "snapshot_error": snapshot_error,
		"encoded_bytes": text.to_utf8_buffer().size(), "encoded_sha256": text.sha256_text(),
		"differences": differences}


func _diff(a: Variant, b: Variant, path: String, depth: int, result: Dictionary) -> void:
	if result.visited >= MAX_DIFF_NODES or depth > 64:
		result.truncated = true
		return
	result.visited += 1
	if a is Dictionary and b is Dictionary and a.size() == b.size():
		for key: Variant in a:
			if not b.has(key):
				_difference(a, b, path, result)
				return
			_diff(a[key], b[key], path + "." + str(key), depth + 1, result)
	elif a is Array and b is Array and a.size() == b.size():
		for index: int in range(a.size()):
			_diff(a[index], b[index], path + "[" + str(index) + "]", depth + 1, result)
	elif (a is float or a is int) and (b is float or b is int):
		if PackedFloat64Array([float(a)]).to_byte_array() \
			!= PackedFloat64Array([float(b)]).to_byte_array():
			_difference(a, b, path, result)
	elif a != b:
		_difference(a, b, path, result)


func _difference(a: Variant, b: Variant, path: String, result: Dictionary) -> void:
	result.count += 1
	if result.samples.size() >= MAX_DIFF_SAMPLES:
		return
	var row: Dictionary = {"path": path,
		"before": JSON.stringify(a, "", true, true).left(256),
		"after": JSON.stringify(b, "", true, true).left(256)}
	if (a is float or a is int) and (b is float or b is int):
		row["before_float64_hex"] = PackedFloat64Array([float(a)]).to_byte_array().hex_encode()
		row["after_float64_hex"] = PackedFloat64Array([float(b)]).to_byte_array().hex_encode()
	result.samples.append(row)


func _read(name: String) -> Dictionary:
	var path: String = _input.path_join(name)
	if not _check(FileAccess.get_sha256(path) == INPUT_PINS[name], "retained input pin: " + name):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not _check(file != null and file.get_length() <= MAX_JSON_BYTES, "bounded input: " + name):
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not _check(value is Dictionary and not value.is_empty(), "JSON dictionary: " + name):
		return {}
	return value


func _check(ok: bool, label: String) -> bool:
	_checks.append({"name": label, "passed": ok})
	if not ok:
		_failed.append(label)
		print("AY02_RETAINED_SAVE_FAIL ", label)
	return ok
