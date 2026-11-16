extends Node
## Source-prepared component controls. No install, issuer, ticket, GAME_END, or AI work.
const GETTER_PROBE = preload("res://src/tests/ac02_settlement_getter_probe.gd")
const LEGACY = preload("res://src/tests/ac02_receipt_legacy_season_save.gd")
const FIXTURE: String = \
	"res://src/tests/ac02_save_receipt_inputs/ac02-save-receipt-public-season.json"
const TWIN: String = ("res://src/tests/ac02_save_receipt_inputs/ac02-save-receipt-ac02-public" + \
	"-pending.json")
const FIXTURE_SHA256: String = "9ab142251549d47424aea3333741ea91d83fe3864e22033f4ea211c2d8826792"
const INVALID_RECEIPT: String = \
	"Invalid settlement save transaction. The previous save was preserved."
var _output: String = ""
var _sequence: int = 0
var _case: String = "prerequisites"
var _aborted: bool = false
var _io_failed: bool = false
var _assertions: int = 0
var _saves: int = 0
var _rows: Array[Dictionary] = []
var _failures: Array[String] = []
var _original_path: String = ""
var _original_error: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 1 and args[0].begins_with("--ac02-canonical-output="):
		_output = args[0].trim_prefix("--ac02-canonical-output=")
	if (
		_output.is_empty()
		or not _output.is_absolute_path()
		or DirAccess.dir_exists_absolute(_output)
		or FileAccess.file_exists(_output)
	):
		print("AC02_CANONICAL_FAIL invalid argument or reused evidence path")
		get_tree().quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		print("AC02_CANONICAL_FAIL cannot create fresh evidence directory")
		get_tree().quit(1)
		return
	_original_path = SeasonSave.path
	_original_error = SeasonSave.last_error
	_run.call_deferred()


func _run() -> void:
	if not _begin("retained_fixture_provenance"):
		return
	var fixture_bytes: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE)
	var twin_bytes: PackedByteArray = FileAccess.get_file_as_bytes(TWIN)
	# Preserve raw bytes in run-local scratch before any JSON parse or restore.
	if (
		not _bytes(_output.path_join("retained-public-season.json"), fixture_bytes)
		or not _bytes(_output.path_join("retained-ac02-public-pending.json"), twin_bytes)
	):
		return
	if not _record(
		"raw_copies",
		{
			"bytes": fixture_bytes.size(),
			"fixture_sha256": FileAccess.get_sha256(FIXTURE),
			"twin_sha256": FileAccess.get_sha256(TWIN),
			"copied_sha256": FileAccess.get_sha256(_output.path_join("retained-public-season.json"))
		}
	):
		return
	if not _check(
		(
			fixture_bytes.size() == 214108
			and fixture_bytes == twin_bytes
			and FileAccess.get_sha256(FIXTURE) == FIXTURE_SHA256
			and (
				FileAccess.get_file_as_bytes(_output.path_join("retained-public-season.json"))
				== fixture_bytes
			)
		),
		"retained source and both exact raw scratch copies match before parse"
	):
		return
	var payload: Variant = JSON.parse_string(fixture_bytes.get_string_from_utf8())
	if not _check(
		(
			payload is Dictionary
			and payload.get("version") == 61
			and payload.get("career", {}).get("version") == 22
			and payload.get("physical", {}).get("pending", {}).get("human", []).size() == 17
		),
		"genuine retained save61 career22 pending record, not a synthesized completion"
	):
		return
	if not _complete():
		return
	_settlement_receipt_sinks()


func _settlement_receipt_sinks() -> void:
	if not _unissued_refusals() or not _successive_receipts() or not _invalid_sinks():
		return
	for kind: String in ["open_temp"]:
		if not _receipt_failure(kind):
			return
	for kind: String in [
		"success", "snapshot_invalid", "decode_invalid", "open_temp", "null_success"
	]:
		if not _ordinary_parity(kind):
			return
	if not _check(
		_saves == 19 and _rows.size() == 10,
		"exact bounded component workload:19 save invocations,10 terminal rows"
	):
		return
	SeasonSave.path = _original_path
	SeasonSave.last_error = _original_error
	if (
		not _write("summary.json", _summary(true))
		or not _write("ACTIVE_STAGE.json", {"stage": "done"})
	):
		return
	print("AC02_CANONICAL_DONE settlement-save-components=1 failures=0")
	get_tree().quit(0)


func _unissued_refusals() -> bool:
	if not _begin("never_issued_total_refusal_and_busy_guard"):
		return false
	SeasonSave.path = _output.path_join("unissued-must-not-save.json")
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.new()
	var app: SeasonApp = SeasonApp.new()
	var native: Node = Node.new()
	var probe: Variant = GETTER_PROBE.new()
	var inputs: Array = [null, false, 1, "", [], {}, native, app, probe]
	var labels: Array[String] = [
		"null",
		"bool",
		"integer",
		"string",
		"array",
		"dictionary",
		"native_node",
		"unattached_exact_season_app",
		"scripted_getter_probe"
	]
	var intact: bool = true
	for index: int in range(inputs.size()):
		if not _record(
			"issuer_refusal_start", {"kind": labels[index], "files": _files(SeasonSave.path)}
		):
			intact = false
			break
		var saved: bool = issue.save_settlement(inputs[index])
		var result: Dictionary = {
			"kind": labels[index],
			"saved": saved,
			"error": SeasonSave.last_error,
			"files": _files(SeasonSave.path),
			"state": issue.state,
			"generation": issue.generation,
			"reason": issue.reason,
			"cleanup_null": issue._cleanup_career == null,
			"saving": issue._settlement_saving,
			"lost": issue._settlement_save_lost,
			"getter_events": probe.events.duplicate()
		}
		if (
			not _record("issuer_refusal_return", result)
			or not _check(
				(
					not saved
					and (
						SeasonSave.last_error
						== "The completed AC-02 game lost its settlement owner. The save was not attempted."
					)
					and issue.state == StadiumNpcAc02IssuedStateV1.Lifetime.PREPARING
					and issue.generation == 1
					and issue.reason.is_empty()
					and issue._cleanup_career == null
					and not issue._settlement_saving
					and not issue._settlement_save_lost
					and probe.events.is_empty()
					and (
						_files(SeasonSave.path)
						== {
							"primary": {"kind": "absent"},
							"backup": {"kind": "absent"},
							"temporary": {"kind": "absent"}
						}
					)
				),
				(
					"never-issued lifetime refuses without app getters, identity transfer or save output:"
					+ labels[index]
				)
			)
		):
			intact = false
			break
	# Release every unattached test-owned Node even when a recorded assertion failed.
	app.free()
	native.free()
	probe.free()
	if not intact:
		return false
	var busy: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.new()
	busy._settlement_saving = true
	if not _record(
		"busy_guard_start", {"saving": busy._settlement_saving, "lost": busy._settlement_save_lost}
	):
		return false
	var saved: bool = busy.save_settlement(null)
	if not _record(
		"busy_guard_return",
		{
			"saved": saved,
			"error": SeasonSave.last_error,
			"saving": busy._settlement_saving,
			"lost": busy._settlement_save_lost,
			"files": _files(SeasonSave.path)
		}
	):
		return false
	if not _check(
		(
			not saved
			and busy._settlement_saving
			and busy._settlement_save_lost
			and busy._cleanup_career == null
			and busy.state == StadiumNpcAc02IssuedStateV1.Lifetime.PREPARING
			and busy.generation == 1
			and busy.reason.is_empty()
			and (
				SeasonSave.last_error
				== "The AC-02 settlement save was reentered. Ownership was not transferred."
			)
			and (
				_files(SeasonSave.path)
				== {
					"primary": {"kind": "absent"},
					"backup": {"kind": "absent"},
					"temporary": {"kind": "absent"}
				}
			)
		),
		"component-only busy flag rejects and marks loss before I/O; not natural reentry evidence"
	):
		return false
	return _complete()


func _successive_receipts() -> bool:
	if not _begin("two_successive_receipts_and_replay"):
		return false
	var season: SeasonState = _fresh("two-receipts", false)
	if season == null:
		return false
	return _successive_career_receipts(season)


func _successive_career_receipts(season: SeasonState) -> bool:
	var original: ClubCareer = season.career
	var original_raw: Array = _raw(original).duplicate(true)
	var receipts: Array = []
	var careers: Array[ClubCareer] = [original]
	for step: int in range(2):
		var old: ClubCareer = season.career
		var old_raw: Array = _raw(old).duplicate(true)
		var prior_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SeasonSave.path)
		var receipt: Array = []
		if not _record(
			"save_start",
			{
				"step": step,
				"old_id": old.get_instance_id(),
				"primary": _path_info(SeasonSave.path),
				"receipt_empty": receipt.is_empty()
			}
		):
			return false
		_saves += 1
		var saved: bool = SeasonSave.save(season, receipt)
		var observed: Dictionary = _receipt_observation(season, old, old_raw, receipt, saved)
		observed["step"] = step
		observed["backup_is_prior_bytes"] = (
			FileAccess.get_file_as_bytes(SeasonSave.path + ".bak") == prior_bytes
		)
		if not _record("save_return", observed):
			return false
		if not _check(
			(
				saved
				and SeasonSave.last_error.is_empty()
				and observed.valid_shape
				and observed.season_exact
				and observed.old_exact
				and observed.new_exact
				and observed.new_fresh
				and observed.new_exact_script
				and observed.plain_owned_readonly
				and observed.old_saved_new_semantically_equal
				and observed.old_unchanged
				and observed.disk_semantically_equal
				and observed.backup_is_prior_bytes
			),
			"actual durable save publishes exact fresh career and one detached raw receipt"
		):
			return false
		for earlier: ClubCareer in careers:
			if not _check(
				season.career != earlier, "every real save publishes a fresh exact career identity"
			):
				return false
		careers.append(season.career)
		receipts.append(receipt)
	if not _check(
		(
			receipts[0][0][2] == receipts[1][0][1]
			and receipts[0][0][2] != receipts[1][0][2]
			and _same_raw(receipts[0][0][3], receipts[1][0][3])
			and _disjoint(receipts[0][0][3], receipts[1][0][3])
			and _same_raw(original_raw, _raw(original))
		),
		"first genuine publication is second old-at-write; receipt trees and old objects stay independent"
	):
		return false
	return _successive_receipt_replay(season, original, receipts, careers)


func _successive_receipt_replay(
	season: SeasonState, original: ClubCareer, receipts: Array, careers: Array[ClubCareer]
) -> bool:
	var before: Dictionary = _observation(season, season.career, true, "")
	var current: ClubCareer = season.career
	var replay: Array = receipts[0]
	if not _record("replay_start", {"receipt": _receipt_ids(replay), "before": before}):
		return false
	_saves += 1
	var replayed: bool = SeasonSave.save(season, replay)
	var after: Dictionary = _observation(season, current, replayed, SeasonSave.last_error)
	if not _record("replay_return", {"receipt": _receipt_ids(replay), "after": after}):
		return false
	if not _check(
		(
			not replayed
			and SeasonSave.last_error == INVALID_RECEIPT
			and season.career == current
			and _same_raw(before.raw, after.raw)
			and before.files == after.files
			and replay.size() == 1
			and replay[0][1] == original
			and replay[0][2] == careers[1]
		),
		"populated real receipt replay rejects before disk or career publication"
	):
		return false
	return _complete()


func _invalid_sinks() -> bool:
	if not _begin("invalid_receipt_output_sinks"):
		return false
	var season: SeasonState = _fresh("invalid-sinks", false)
	if season == null:
		return false
	var readonly: Array = []
	readonly.make_read_only()
	var sinks: Array = [{}, "", [null], [["malformed"]], readonly]
	var labels: Array[String] = [
		"empty_dictionary", "empty_string", "nonempty_null", "malformed_nested", "readonly_empty"
	]
	for index: int in range(sinks.size()):
		var old: ClubCareer = season.career
		var before: Dictionary = _observation(season, old, true, "")
		var sink_before: String = JSON.stringify(sinks[index], "", true, true)
		if not _record(
			"negative_start", {"kind": labels[index], "before": before, "sink": sink_before}
		):
			return false
		_saves += 1
		var saved: bool = SeasonSave.save(season, sinks[index])
		var after: Dictionary = _observation(season, old, saved, SeasonSave.last_error)
		if not _record(
			"negative_return",
			{
				"kind": labels[index],
				"after": after,
				"sink": JSON.stringify(sinks[index], "", true, true)
			}
		):
			return false
		if not _check(
			(
				not saved
				and SeasonSave.last_error == INVALID_RECEIPT
				and season.career == old
				and _same_raw(before.raw, after.raw)
				and before.files == after.files
				and JSON.stringify(sinks[index], "", true, true) == sink_before
			),
			"invalid output sink is rejected without consuming or mutating it:" + labels[index]
		):
			return false
	return _complete()


func _receipt_failure(kind: String) -> bool:
	if not _begin("receipt_failure_" + kind):
		return false
	var season: SeasonState = _fresh("receipt-failure-" + kind, false)
	if season == null or not _block(kind, SeasonSave.path):
		return false
	var old: ClubCareer = season.career
	var raw_before: Array = _raw(old).duplicate(true)
	var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(SeasonSave.path)
	var receipt: Array = []
	if not _record(
		"failure_start",
		{
			"kind": kind,
			"old_id": old.get_instance_id(),
			"files": _files(SeasonSave.path),
			"raw": raw_before
		}
	):
		return false
	_saves += 1
	var saved: bool = SeasonSave.save(season, receipt)
	var observed: Dictionary = _observation(season, old, saved, SeasonSave.last_error)
	observed["receipt_size"] = receipt.size()
	observed["exact_checkpoint_retained"] = (
		checkpoint == FileAccess.get_file_as_bytes(SeasonSave.path)
	)
	if not _record("failure_return", observed):
		return false
	if not _check(
		(
			not saved
			and SeasonSave.last_error == _error_for(kind)
			and receipt.is_empty()
			and season.career == old
			and _same_raw(raw_before, _raw(old))
			and observed.exact_checkpoint_retained
		),
		"pre-rename failure preserves exact primary bytes and old identity, returning no receipt"
	):
		return false
	return _complete()


func _ordinary_parity(kind: String) -> bool:
	if not _begin("ordinary_parity_" + kind):
		return false
	var actual: Dictionary = _parity_side(kind, false)
	if _aborted:
		return false
	var historical: Dictionary = _parity_side(kind, true)
	if _aborted:
		return false
	if not _record("parity_return", {"actual": actual, "historical": historical}):
		return false
	var expected_success: bool = kind in ["success", "null_success"]
	if not _check(
		(
			actual == historical
			and actual.saved == expected_success
			and actual.error == _error_for(kind)
			and actual.career_replaced == expected_success
			and actual.old_unchanged
			and (expected_success or actual.prior_bytes_preserved)
		),
		(
			"ordinary/null save output bytes, errors and publication behavior match rename-only "
			+ "retained original"
		)
	):
		return false
	return _complete()


func _parity_side(kind: String, historical: bool) -> Dictionary:
	var side: String = "original" if historical else "candidate"
	var season: SeasonState = _fresh("parity-" + kind + "-" + side, historical)
	if season == null:
		return {}
	var path: String = LEGACY.path if historical else SeasonSave.path
	if kind in ["open_temp", "backup"] and not _block(kind, path):
		return {}
	if kind == "snapshot_invalid":
		season.npc_venues = {"version": -1}
	elif kind == "decode_invalid":
		season.difficulty = -1
	var old: ClubCareer = season.career
	var old_raw: Array = _raw(old).duplicate(true)
	var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if not _record(
		"parity_start",
		{"kind": kind, "side": side, "old_id": old.get_instance_id(), "files": _files(path)}
	):
		return {}
	_saves += 1
	var saved: bool
	if historical:
		saved = LEGACY.save(season)
	elif kind == "null_success":
		saved = SeasonSave.save(season, null)
	else:
		saved = SeasonSave.save(season)
	var error: String = LEGACY.last_error if historical else SeasonSave.last_error
	var result: Dictionary = {
		"saved": saved,
		"error": error,
		"career_replaced": season.career != old,
		"old_unchanged": _same_raw(old_raw, _raw(old)),
		"raw": _raw(season.career).duplicate(true),
		"files": _files(path),
		"prior_bytes_preserved": checkpoint == FileAccess.get_file_as_bytes(path)
	}
	_record("parity_side_return", {"kind": kind, "side": side, "result": result})
	return result


func _fresh(label: String, historical: bool) -> SeasonState:
	var folder: String = _output.path_join(label)
	if not _check(
		not DirAccess.dir_exists_absolute(folder) and DirAccess.make_dir_absolute(folder) == OK,
		"fresh isolated checkpoint directory:" + label
	):
		return null
	var path: String = folder.path_join("season.json")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		_output.path_join("retained-public-season.json")
	)
	if (
		not _bytes(path, bytes)
		or not _record(
			"restore_start",
			{"path": path, "sha256": FileAccess.get_sha256(path), "historical": historical}
		)
	):
		return null
	if not _check(
		FileAccess.get_sha256(path) == FIXTURE_SHA256,
		"exact raw fixture copied to isolated checkpoint before restore"
	):
		return null
	var season: SeasonState
	if historical:
		LEGACY.path = path
		season = LEGACY.restore()
	else:
		SeasonSave.path = path
		season = SeasonSave.restore()
	var error: String = LEGACY.last_error if historical else SeasonSave.last_error
	if not _record(
		"restore_return",
		{
			"nonnull": season != null,
			"error": error,
			"checkpoint_unchanged": FileAccess.get_file_as_bytes(path) == bytes
		}
	):
		return null
	if not _check(
		(
			season != null
			and error.is_empty()
			and season.get_script() == SeasonState
			and season.career != null
			and season.career.get_script() == ClubCareer
			and not season.physical.pending.is_empty()
			and FileAccess.get_file_as_bytes(path) == bytes
		),
		"shipping restore accepts retained pending bytes without changing the checkpoint"
	):
		return null
	return season


func _block(kind: String, path: String) -> bool:
	var blocker: String = path + (".tmp" if kind == "open_temp" else ".bak")
	var made: Error = DirAccess.make_dir_absolute(blocker)
	if not _record("blocker_created", {"kind": kind, "path": blocker, "error": made}):
		return false
	return _check(
		made == OK and DirAccess.dir_exists_absolute(blocker),
		"test-owned directory blocks the selected write boundary"
	)


func _receipt_observation(
	season: SeasonState, old: ClubCareer, old_raw: Array, receipt: Array, saved: bool
) -> Dictionary:
	var result: Dictionary = {
		"saved": saved,
		"error": SeasonSave.last_error,
		"receipt": _receipt_ids(receipt),
		"files": _files(SeasonSave.path),
		"valid_shape": receipt.size() == 1 and receipt[0] is Array and receipt[0].size() == 4
	}
	if not result.valid_shape:
		return result
	var row: Array = receipt[0]
	var raw: Array = _raw(season.career)
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var disk_career: Variant = disk.get("career") if disk is Dictionary else null
	var disk_raw: Array = []
	if disk_career is Dictionary:
		disk_raw = [
			disk_career.get("current"),
			disk_career.get("runs"),
			disk_career.get("assets"),
			disk_career.get("pennants", {}),
			disk_career.get("plaques", {})
		]
	result["season_exact"] = row[0] == season
	result["old_exact"] = row[1] == old
	result["new_exact"] = row[2] == season.career
	result["new_fresh"] = row[2] != old
	result["new_exact_script"] = season.career != null and season.career.get_script() == ClubCareer
	result["plain_owned_readonly"] = (
		_readonly_plain(row[3]) and _disjoint(row[3], _raw(old)) and _disjoint(row[3], raw)
	)
	result["old_saved_new_semantically_equal"] = (
		_same_raw(old_raw, row[3]) and _same_raw(row[3], raw)
	)
	result["old_unchanged"] = _same_raw(old_raw, _raw(old))
	result["disk_semantically_equal"] = _same_raw(row[3], disk_raw)
	result["old_raw"] = old_raw
	result["saved_raw"] = row[3]
	result["new_raw"] = raw.duplicate(true)
	return result


static func _raw(career: ClubCareer) -> Array:
	return [career.current, career.runs, career._assets, career._pennants, career._plaques]


static func _same_raw(left: Variant, right: Variant) -> bool:
	# Independent semantic comparator over RAW backing values, never career.to_data().
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
		return is_finite(float(left)) and is_finite(float(right)) and left == right
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		if left.size() != right.size():
			return false
		for key: Variant in left:
			if not right.has(key) or not _same_raw(left[key], right[key]):
				return false
		return true
	if left is Array:
		if left.size() != right.size():
			return false
		for index: int in range(left.size()):
			if not _same_raw(left[index], right[index]):
				return false
		return true
	return typeof(left) in [TYPE_NIL, TYPE_BOOL, TYPE_STRING] and left == right


static func _readonly_plain(value: Variant) -> bool:
	if value is Array or value is Dictionary:
		if not value.is_read_only():
			return false
		for key: Variant in value:
			if value is Dictionary:
				if typeof(key) != TYPE_STRING or not _readonly_plain(value[key]):
					return false
			elif not _readonly_plain(key):
				return false
		return true
	return (
		typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING]
		or (typeof(value) == TYPE_FLOAT and is_finite(value))
	)


static func _disjoint(left: Variant, right: Variant) -> bool:
	# Corresponding containers in the semantically equal raw trees must be independent.
	if left is Array and right is Array:
		if is_same(left, right) or left.size() != right.size():
			return false
		for index: int in range(left.size()):
			if not _disjoint(left[index], right[index]):
				return false
	elif left is Dictionary and right is Dictionary:
		if is_same(left, right) or left.size() != right.size():
			return false
		for key: Variant in left:
			if not right.has(key) or not _disjoint(left[key], right[key]):
				return false
	return true


static func _receipt_ids(receipt: Array) -> Dictionary:
	var result: Dictionary = {"size": receipt.size()}
	if receipt.size() == 1 and receipt[0] is Array:
		result["row_size"] = receipt[0].size()
		if receipt[0].size() == 4:
			for index: int in range(3):
				result["slot_%d_id" % index] = (
					receipt[0][index].get_instance_id() if receipt[0][index] is Object else 0
				)
	return result


static func _path_info(path: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(path):
		return {"kind": "directory"}
	if not FileAccess.file_exists(path):
		return {"kind": "absent"}
	return {
		"kind": "file",
		"bytes": FileAccess.get_file_as_bytes(path).size(),
		"sha256": FileAccess.get_sha256(path)
	}


static func _files(path: String) -> Dictionary:
	return {
		"primary": _path_info(path),
		"backup": _path_info(path + ".bak"),
		"temporary": _path_info(path + ".tmp")
	}


static func _observation(
	season: SeasonState, old: ClubCareer, saved: bool, error: String
) -> Dictionary:
	return {
		"saved": saved,
		"error": error,
		"career_replaced": season.career != old,
		"career_id": season.career.get_instance_id(),
		"raw": _raw(season.career).duplicate(true),
		"files": _files(SeasonSave.path)
	}


static func _error_for(kind: String) -> String:
	match kind:
		"snapshot_invalid":
			return "The saved away-park assignment is invalid. The previous save was preserved."
		"decode_invalid":
			return "Season data failed validation. The previous save was preserved."
		"open_temp":
			return "Could not save season. Your current session is still available."
		"backup":
			return "Could not back up the previous season save. Retry before closing."
	return ""


func _begin(label: String) -> bool:
	_case = label
	return _record("case_start", {})


func _complete() -> bool:
	_rows.append({"label": _case, "passed": true})
	return _write("controls.json", _rows) and _record("case_complete", {})


func _record(stage: String, detail: Dictionary) -> bool:
	_sequence += 1
	var value: Dictionary = {
		"case": _case,
		"stage": stage,
		"sequence": _sequence,
		"ticks_msec": Time.get_ticks_msec(),
		"detail": detail
	}
	return _write("stage-%05d.json" % _sequence, value) and _write("ACTIVE_STAGE.json", value)


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	# Both start/return observations and this result are durable before failure handling.
	if not _record("assertion_result", {"ok": condition, "description": description}):
		return false
	if condition:
		return true
	_aborted = true
	_failures.append(_case + ": " + description)
	_write("summary.json", _summary(false))
	SeasonSave.path = _original_path
	SeasonSave.last_error = _original_error
	print("AC02_CANONICAL_FAIL " + _case + ": " + description)
	get_tree().quit(1)
	return false


func _summary(passed: bool) -> Dictionary:
	return {
		"passed": passed,
		"controls": _rows,
		"control_count": _rows.size(),
		"assertions": _assertions,
		"save_invocations": _saves,
		"failures": _failures,
		"component_only": true,
		"issuer_installs": 0,
		"natural_GAME_END": false,
		"settlement_wrapper_qualified": false,
		"ai_continuation_qualified": false,
		"historical_family_wide_parity": false,
		"rename_failure_injected": false,
		"backup_failure_injected": false,
		"backup_failure_coverage": "pending_separate_expected_error_phase",
		"all_save_failure_paths_qualified": false,
		"unknown_or_foreign_reentrant_replacements_tested": false
	}


func _write(name: String, value: Variant) -> bool:
	return _bytes(
		_output.path_join(name), (JSON.stringify(value, "\t", true, true) + "\n").to_utf8_buffer()
	)


func _bytes(path: String, value: PackedByteArray) -> bool:
	if _io_failed:
		return false
	var file: FileAccess = FileAccess.open(path + ".evidence-tmp", FileAccess.WRITE)
	if file == null:
		return _io_failure("cannot open evidence:" + path)
	file.store_buffer(value)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".evidence-tmp", path) != OK:
		return _io_failure("cannot flush/rename evidence:" + path)
	return true


func _io_failure(reason: String) -> bool:
	_io_failed = true
	_aborted = true
	SeasonSave.path = _original_path
	SeasonSave.last_error = _original_error
	print("AC02_CANONICAL_FAIL " + reason)
	get_tree().quit(1)
	return false
