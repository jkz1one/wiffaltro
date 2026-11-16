extends RefCounted
## Bounded single-writer process-interruption recovery, not authentication or a
## power-loss/fsync guarantee. Never reads or changes SeasonSave.path.
## Primary atomic rename commits. The mirror always copies the SAME committed
## revision; .bak is legacy evidence, never an automatic rollback authority.

const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const MAX_BYTES: int = 1024 * 1024
const MAX_INTENT_BYTES: int = 2 * MAX_BYTES + 4096
const MAX_REVISION: int = 2147483647
const VERSION: int = 1
const SUFFIXES: Array[String] = [
	"", ".committed", ".intent", ".tmp", ".committed.tmp", ".intent.tmp", ".bak"
]
static var last_error: String = ""
# Deterministic interruption seam used only by the isolated recovery scene.
static var _test_stop_after: String = ""
static var _test_record: bool = false
static var _test_steps: Array[String] = []


static func save(value: Variant, path: String) -> bool:
	return commit(value, path).status == "committed"


static func restore(path: String) -> Dictionary:
	var found: Dictionary = inspect(path)
	# A source-only pending intent locks its exact target. Do not open a mutable
	# old owner while that transaction is unresolved; retry commit(pending, path).
	return found.lineage if found.status in ["ready", "recoverable"] else {}


static func inspect(path: String) -> Dictionary:
	last_error = ""
	if not _isolated(path):
		return _inspection("blocked", "An isolated Dynasty checkpoint path is required.")
	var primary: Dictionary = _read_record(path, path)
	var mirror: Dictionary = _read_record(path + ".committed", path)
	if FileAccess.file_exists(path + ".intent"):
		var intent: Dictionary = _read_intent(path)
		if intent.is_empty():
			return _inspection(
				"blocked", "Invalid Dynasty transition intent; all evidence preserved."
			)
		var before: Dictionary = intent.before
		var after: Dictionary = intent.after
		for record: Dictionary in [primary, mirror]:
			if not record.is_empty() and not _same(record, before) and not _same(record, after):
				return _inspection(
					"blocked", "Dynasty transition evidence conflicts; no authority selected."
				)
		if _same(primary, after) or _same(mirror, after):
			return _inspection(
				"recoverable", "Committed Dynasty revision needs exact replication.", after
			)
		if (
			before.is_empty()
			and not FileAccess.file_exists(path)
			and not FileAccess.file_exists(path + ".committed")
		):
			return _inspection(
				"pending",
				"Initial Dynasty creation awaits its exact pending target.",
				{},
				after.lineage
			)
		if not before.is_empty() and _same(primary, before):
			return _inspection(
				"pending",
				"Uncommitted Dynasty transition locks its exact pending target.",
				before,
				after.lineage
			)
		return _inspection(
			"blocked",
			(
				"Missing or invalid primary with source-only intent is ambiguous; no rollback or "
				+ "repair performed."
			)
		)
	if not primary.is_empty() and not mirror.is_empty():
		if not _same(primary, mirror):
			return _inspection(
				"blocked", "Different valid Dynasty replicas lack a validating intent."
			)
		return _inspection("ready", "", primary)
	if not primary.is_empty() or not mirror.is_empty():
		return _inspection(
			"recoverable",
			"One committed Dynasty replica is missing or invalid.",
			primary if not primary.is_empty() else mirror
		)
	if (
		FileAccess.file_exists(path)
		or FileAccess.file_exists(path + ".committed")
		or FileAccess.file_exists(path + ".bak")
	):
		return _inspection(
			"blocked",
			"Dynasty authority is invalid or legacy-only; retained evidence cannot reset this path."
		)
	# Temporary files never witness a commit. Reads preserve them; a fresh write
	# may replace them only when every recognized authority artifact is absent.
	return _inspection("empty", "")


static func commit(value: Variant, path: String) -> Dictionary:
	return _commit(value, path, false)


static func commit_capture(snapshot: Variant, path: String) -> Dictionary:
	var found: Dictionary = inspect(path)
	if found.status not in ["ready", "recoverable"]:
		return _result(
			"blocked",
			(
				"Capture requires committed Dynasty authority; resume an admitted pending target with "
				+ "exact commit first."
			)
		)
	# The only source-replay entry point. The projector decodes this snapshot
	# once; all subsequent store validation uses bounded compact checkpoints.
	var captured: Dictionary = Lineage.capture_current(found.lineage, snapshot)
	if captured.is_empty():
		return _result(
			"blocked",
			"Dynasty capture rejected its source replay, start identity or journal extension."
		)
	return _commit(captured, path, true)


static func _commit(value: Variant, path: String, capture: bool) -> Dictionary:
	var checked: Dictionary = Lineage.normalize(value)
	if checked.is_empty() or not _isolated(path):
		return _result("blocked", "Invalid Dynasty checkpoint or nonisolated path.")
	var found: Dictionary = inspect(path)
	if found.status == "blocked":
		return _result("blocked", found.reason)
	if found.status == "pending":
		if not Lineage.Profile.same(checked, found.pending):
			return _result("blocked", "An existing intent permits only its exact pending target.")
		return _complete(_read_intent(path), path)
	if found.status == "recoverable":
		if not Lineage.Profile.same(checked, found.lineage):
			return _result(
				"blocked", "Repair the committed revision before requesting a different successor."
			)
		return repair(path)
	var previous: Dictionary = {}
	var revision: int = 1
	if found.status == "ready":
		previous = _read_record(path, path)
		if Lineage.Profile.same(checked, previous.lineage):
			return _result("committed", "", previous.lineage, false, int(previous.revision))
		var admitted: bool = (
			Lineage.capture_transition_valid(previous.lineage, checked)
			if capture
			else _admitted(previous.lineage, checked)
		)
		if not admitted or int(previous.revision) >= MAX_REVISION:
			return _result(
				"blocked",
				"Existing Dynasty authority rejects this identity, revision or lifecycle change."
			)
		revision = int(previous.revision) + 1
	elif capture or not _initial(checked):
		return _result(
			"blocked",
			"A fresh Dynasty path accepts only its exact active first-generation creation."
		)
	var after: Dictionary = _record(checked, path, revision)
	if _encoded(after).to_utf8_buffer().size() > MAX_BYTES:
		return _result("blocked", "Dynasty checkpoint exceeds its bounded reader size.")
	var intent: Dictionary = {
		"version": VERSION, "path": _canonical(path), "before": previous, "after": after
	}
	if capture:
		intent["kind"] = "capture"
	if _encoded(intent).to_utf8_buffer().size() > MAX_INTENT_BYTES:
		return _result("blocked", "Dynasty transition intent exceeds its bounded reader size.")
	if not _write_atomic(intent, path + ".intent", "intent"):
		return _outcome(path, checked, "Interrupted while preparing the Dynasty transition intent.")
	return _complete(intent, path)


static func repair(path: String) -> Dictionary:
	var found: Dictionary = inspect(path)
	if found.status == "ready":
		return _result("committed", "", found.lineage, false, int(found.revision))
	if found.status != "recoverable":
		return _result(
			"blocked",
			(
				"Repair requires an unambiguously committed Dynasty revision; pending or conflicting "
				+ "evidence is preserved."
			)
		)
	var chosen: Dictionary = _record(found.lineage, path, int(found.revision))
	# Replicate the selected revision without incrementing it or admitting a
	# different state. A target witness is retained until its peer is committed.
	if not _same(_read_record(path, path), chosen):
		if not _write_atomic(chosen, path, "repair_primary"):
			return _outcome(
				path, found.lineage, "Interrupted while repairing the committed Dynasty primary."
			)
	if not _same(_read_record(path + ".committed", path), chosen):
		if not _write_atomic(chosen, path + ".committed", "repair_mirror"):
			return _outcome(
				path, found.lineage, "Interrupted while repairing the committed Dynasty mirror."
			)
	if not _clear_intent(path):
		return _outcome(
			path,
			found.lineage,
			"Committed Dynasty replicas are intact; intent cleanup remains pending."
		)
	return _outcome(path, found.lineage, "")


static func _complete(intent: Dictionary, path: String) -> Dictionary:
	if intent.is_empty():
		return _result(
			"indeterminate",
			"Dynasty intent could not be revalidated; no live owner may be promoted."
		)
	var after: Dictionary = intent.after
	if not _write_atomic(after, path, "primary"):
		return _outcome(path, after.lineage, "Interrupted at the Dynasty primary commit boundary.")
	if not _write_atomic(after, path + ".committed", "mirror"):
		return _outcome(
			path, after.lineage, "Dynasty primary committed; mirror completion requires inspection."
		)
	if not _clear_intent(path):
		return _outcome(
			path,
			after.lineage,
			"Dynasty primary and mirror committed; intent cleanup remains pending."
		)
	return _outcome(path, after.lineage, "")


static func _clear_intent(path: String) -> bool:
	if FileAccess.file_exists(path + ".intent"):
		if DirAccess.remove_absolute(path + ".intent") != OK:
			return false
	return not _interrupt("intent.clear")


static func _outcome(path: String, expected: Dictionary, reason: String) -> Dictionary:
	var found: Dictionary = inspect(path)
	if found.status in ["ready", "recoverable"] and Lineage.Profile.same(found.lineage, expected):
		return _result(
			"committed", reason, found.lineage, found.status != "ready", int(found.revision)
		)
	if found.status in ["empty", "pending", "ready"]:
		return _result("not_committed", reason)
	return _result("indeterminate", reason + " No live owner may be promoted.")


static func _inspection(
	status: String, reason: String, record: Dictionary = {}, pending: Dictionary = {}
) -> Dictionary:
	last_error = reason
	return {
		"status": status,
		"reason": reason,
		"lineage": record.get("lineage", {}),
		"revision": int(record.get("revision", 0)),
		"pending": pending
	}


static func _result(
	status: String,
	reason: String,
	lineage: Dictionary = {},
	needs_repair: bool = false,
	revision: int = 0
) -> Dictionary:
	last_error = reason
	return {
		"status": status,
		"reason": reason,
		"lineage": lineage,
		"needs_repair": needs_repair,
		"revision": revision
	}


static func _record(lineage: Dictionary, path: String, revision: int) -> Dictionary:
	return {"version": VERSION, "path": _canonical(path), "revision": revision, "lineage": lineage}


static func _record_valid(value: Variant, path: String) -> Dictionary:
	if (
		not Lineage.Profile.keys(value, ["version", "path", "revision", "lineage"])
		or not Lineage.Profile.whole(value.version, VERSION, VERSION)
		or value.path != _canonical(path)
		or not Lineage.Profile.whole(value.revision, 1, MAX_REVISION)
	):
		return {}
	var lineage: Dictionary = Lineage.normalize(value.lineage)
	return {} if lineage.is_empty() else _record(lineage, path, int(value.revision))


static func _read_record(file_path: String, root_path: String) -> Dictionary:
	return _record_valid(_read_json(file_path, MAX_BYTES), root_path)


static func _read_intent(path: String) -> Dictionary:
	var value: Variant = _read_json(path + ".intent", MAX_INTENT_BYTES)
	var capture: bool = value is Dictionary and value.get("kind") == "capture"
	var fields: Array = ["version", "path", "before", "after"]
	if capture:
		fields.append("kind")
	if (
		not Lineage.Profile.keys(value, fields)
		or not Lineage.Profile.whole(value.version, VERSION, VERSION)
		or value.path != _canonical(path)
		or not value.before is Dictionary
	):
		return {}
	var after: Dictionary = _record_valid(value.after, path)
	if after.is_empty():
		return {}
	var before: Dictionary = {}
	if value.before.is_empty():
		if capture or after.revision != 1 or not _initial(after.lineage):
			return {}
	else:
		before = _record_valid(value.before, path)
		if (
			before.is_empty()
			or after.revision != before.revision + 1
			or Lineage.Profile.same(before.lineage, after.lineage)
		):
			return {}
		var admitted: bool = (
			Lineage.capture_transition_valid(before.lineage, after.lineage)
			if capture
			else _admitted(before.lineage, after.lineage)
		)
		if not admitted:
			return {}
	var result: Dictionary = {
		"version": VERSION, "path": _canonical(path), "before": before, "after": after
	}
	if capture:
		result["kind"] = "capture"
	return result


static func _read_json(path: String, maximum: int) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	if file.get_length() > maximum:
		file.close()
		return null
	var encoded: String = file.get_as_text()
	var error: Error = file.get_error()
	file.close()
	if error != OK and error != ERR_FILE_EOF:
		return null
	var json: JSON = JSON.new()
	return json.data if json.parse(encoded) == OK else null


static func _write_atomic(value: Dictionary, destination: String, label: String) -> bool:
	var file: FileAccess = FileAccess.open(destination + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	if _interrupt(label + ".open"):
		file.close()
		return false
	file.store_string(_encoded(value))
	if _interrupt(label + ".write"):
		file.close()
		return false
	file.flush()
	if _interrupt(label + ".flush"):
		file.close()
		return false
	var error: Error = file.get_error()
	file.close()
	if error != OK or _interrupt(label + ".close"):
		return false
	if DirAccess.rename_absolute(destination + ".tmp", destination) != OK:
		return false
	return not _interrupt(label + ".rename")


static func _interrupt(step: String) -> bool:
	if _test_record:
		_test_steps.append(step)
	return _test_stop_after == step


static func _encoded(value: Dictionary) -> String:
	return JSON.stringify(value, "", true, true)


static func _canonical(path: String) -> String:
	return ProjectSettings.globalize_path(path).simplify_path()


static func _isolated(path: String) -> bool:
	if path.is_empty():
		return false
	var target: String = _canonical(path)
	var active: String = _canonical(SeasonSave.path)
	for suffix: String in SUFFIXES:
		if target + suffix in [active, active + ".bak", active + ".tmp"]:
			return false
	return true


static func _same(left: Dictionary, right: Dictionary) -> bool:
	return not left.is_empty() and not right.is_empty() and Lineage.Profile.same(left, right)


static func _initial(value: Dictionary) -> bool:
	return (
		value.generation == 0
		and value.state == "active"
		and Lineage.Profile.same(value, Lineage.create(value.start_profile))
	)


static func _admitted(before: Dictionary, after: Dictionary) -> bool:
	if before.id != after.id or before.owner_id != after.owner_id:
		return false
	if after.generation == before.generation:
		var candidates: Array[Dictionary] = [before, Lineage.pause(before), Lineage.resume(before)]
		for outcome: String in ["win", "loss", "abandon"]:
			candidates.append(Lineage.close(before, outcome))
		for candidate: Dictionary in candidates:
			if not candidate.is_empty() and Lineage.Profile.same(candidate, after):
				return true
		return false
	if after.generation != before.generation + 1 or after.last_transition.is_empty():
		return false
	var projected: Dictionary = Lineage.advance(before, after.last_transition.request)
	return not projected.is_empty() and Lineage.Profile.same(projected.lineage, after)
