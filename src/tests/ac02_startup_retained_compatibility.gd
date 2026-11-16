extends Node
## Cold compatibility only over untouched old-source retained outputs.
## No app/lab/issuer, new game, settlement replay or current-source round claim.
const RETAINED_CHECKS = preload("res://src/tests/ac02_issued_round_retained_checks.gd")
const PINS: Dictionary = {
	"ac02-public-pending.json": "9ab142251549d47424aea3333741ea91d83fe3864e22033f4ea211c2d8826792",
	"ac02-public-raw-report17.json":
	"3003262988b1dddb0c2a8123942ce431aa832ec8af4318190584c94de8121a23",
	"ac02-public-raw-human-evidence.json":
	"beec57b32be037585e5fa6344c96fd59aa99890cd8b5ebfd87cbd8c7004bedaf",
}
var _checks: int = 0
var _failed: Array[String] = []
var _terminal_errors: Array = []


func _ready() -> void:
	var args: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.split("=", true, 1)
		if parts.size() == 2 and not args.has(parts[0]):
			args[parts[0]] = parts[1]
	var input: String = args.get("--startup-compat-input", "")
	var output: String = args.get("--startup-compat-output", "")
	var admitted: bool = _check(
		(
			OS.get_cmdline_user_args().size() == 2
			and args.size() == 2
			and input.is_absolute_path()
			and output.is_absolute_path()
			and input != output
			and DirAccess.make_dir_recursive_absolute(output) == OK
			and DirAccess.get_files_at(output).is_empty()
			and DirAccess.get_directories_at(output).is_empty()
		),
		"exact paths and fresh isolated output"
	)
	if admitted:
		_run(input)
		for name: String in PINS:
			_check(
				FileAccess.get_sha256(input.path_join(name)) == PINS[name],
				"retained original unchanged after validation " + name
			)
		var summary: Dictionary = {
			"scope": "cold compatibility of untouched prior-source retained outputs",
			"checks": _checks,
			"failures": _failed.size(),
			"failed": _failed,
			"terminal_errors": _terminal_errors,
			"original_input_sha256": PINS,
			"original_provenance":
			"warm-settlement-execution04/support/fixture_inputs; original identities not relabeled",
			"current_validation_runtime": StadiumPoolPartyAssetIntegrity.source_sha256(),
			"new_matches": 0,
			"settlement_replayed": false,
			"live_issuer_authority": false
		}
		var file: FileAccess = FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
		if file == null:
			_check(false, "summary output opened")
		else:
			file.store_string(JSON.stringify(summary, "", true, true))
			if file.get_error() != OK:
				_check(false, "summary output written")
			file.close()
	print(
		"STARTUP_PREPARING retained compatibility checks=%d failures=%d" % [_checks, _failed.size()]
	)
	get_tree().quit(0 if _failed.is_empty() else 1)


func _run(input: String) -> void:
	var retained: Dictionary = {}
	for name: String in PINS:
		var path: String = input.path_join(name)
		if not _check(
			FileAccess.file_exists(path) and FileAccess.get_sha256(path) == PINS[name],
			"exact retained original " + name
		):
			return
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not _check(
			bytes.size() > 0 and bytes.size() <= 8 * 1024 * 1024, "bounded bytes " + name
		):
			return
		var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if not _check(parsed is Dictionary, "retained JSON object " + name):
			return
		retained[name] = parsed
	var pending_data: Dictionary = retained["ac02-public-pending.json"]
	var pending: SeasonState = SeasonSave._decode(pending_data)
	if not _check(
		pending != null and ClubCareer.same(SeasonSave.snapshot(pending), pending_data),
		"cold decode preserves exact original pending save"
	):
		return
	var human: Dictionary = retained["ac02-public-raw-human-evidence.json"]
	var report: Dictionary = retained["ac02-public-raw-report17.json"]
	var result: Dictionary = RETAINED_CHECKS.terminal(pending, human, report)
	_terminal_errors = result.errors
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
		"original retained terminal negatives and human/report relations still accepted"
	):
		return
	var forged: Dictionary = pending_data.duplicate(true)
	forged.physical.pending.human[16].clear()
	_check(SeasonSave._decode(forged) == null, "cold stripped human evidence refuses")


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failed.append(label)
		print("STARTUP_PREPARING retained compatibility FAIL ", label)
	return ok
