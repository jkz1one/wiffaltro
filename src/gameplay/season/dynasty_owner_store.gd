extends RefCounted
## One closed owner manifest is sole authority for selection, lineage and exact
## immutable session references. Single-writer process interruption consistency;
## not power-loss durability, authentication, migration or multiwriter locking.

const Owner = preload("res://src/gameplay/season/dynasty_career_owner.gd")
const Transport = preload("res://src/gameplay/season/durable_owner_store.gd")
const MAX_BYTES: int = 1024 * 1024
const MAX_INTENT_BYTES: int = 2 * MAX_BYTES
const MAX_SNAPSHOT_BYTES: int = 8 * 1024 * 1024
const MAX_REVISION: int = 2147483647
const VERSION: int = 1
const ORIGIN_INTENT_VERSION: int = 2
const SUFFIXES: Array[String] = [
	"", ".committed", ".intent", ".tmp", ".committed.tmp", ".intent.tmp", ".bak"
]
static var last_error: String = ""
static var _test_stop_after: String = ""
static var _test_record: bool = false
static var _test_steps: Array[String] = []


static func create(payload: Dictionary, path: String) -> Dictionary:
	return _transport().callv("create", [payload, path])


static func transact(request: Dictionary, path: String) -> Dictionary:
	return _transport().callv("transact", [request, path])


static func inspect(path: String) -> Dictionary:
	return _transport().callv("inspect", [path])


static func restore(path: String) -> Dictionary:
	return _transport().callv("restore", [path])


static func commit(request: Dictionary, path: String) -> Dictionary:
	return _transport().callv("commit", [request, path])


static func _exact_retry(path: String, found: Dictionary) -> Dictionary:
	return _transport().callv("_exact_retry", [path, found])


static func retry_pending(path: String) -> Dictionary:
	return _transport().callv("retry_pending", [path])


static func _retry_precommit(intent: Dictionary, path: String) -> Dictionary:
	return _transport().callv("_retry_precommit", [intent, path])


static func repair_snapshot(path: String, reference: Dictionary) -> Dictionary:
	return _transport().callv("repair_snapshot", [path, reference])


static func repair(path: String) -> Dictionary:
	return _transport().callv("repair", [path])


static func read_snapshot(path: String, reference: Dictionary) -> Dictionary:
	return _transport().callv("read_snapshot", [path, reference])


static func _complete(intent: Dictionary, path: String) -> Dictionary:
	return _transport().callv("_complete", [intent, path])


static func _repair_pending_references(path: String, before: Dictionary, after: Dictionary) -> bool:
	return _transport().callv("_repair_pending_references", [path, before, after])


static func _new_references_ready(path: String, before: Dictionary, after: Dictionary) -> bool:
	return _transport().callv("_new_references_ready", [path, before, after])


static func _stage_snapshots(
	path: String, owner: Dictionary, snapshots: Dictionary, origin: Dictionary = {}
) -> bool:
	return _transport().callv("_stage_snapshots", [path, owner, snapshots, origin])


static func _repair_object(path: String, reference: Dictionary, encoded: String) -> bool:
	return _transport().callv("_repair_object", [path, reference, encoded])


static func _read_object(path: String, reference: Dictionary) -> Dictionary:
	return _transport().callv("_read_object", [path, reference])


static func _read_object_bytes(path: String, reference: Dictionary) -> Dictionary:
	return _transport().callv("_read_object_bytes", [path, reference])


static func _parse_snapshot(encoded: String) -> Variant:
	return _transport().callv("_parse_snapshot", [encoded])


static func _prune_unreferenced(path: String, retained: Array[Dictionary]) -> bool:
	return _transport().callv("_prune_unreferenced", [path, retained])


static func _object_filename_digest(name: String) -> String:
	return _transport().callv("_object_filename_digest", [name])


static func _object_path(path: String, reference: Dictionary, replica: String) -> String:
	return _transport().callv("_object_path", [path, reference, replica])


static func _references(owner: Dictionary) -> Array[Dictionary]:
	return _transport().callv("_references", [owner])


static func _selected_reference(owner: Dictionary) -> Dictionary:
	return _transport().callv("_selected_reference", [owner])


static func _contains_reference(references: Array[Dictionary], target: Dictionary) -> bool:
	return _transport().callv("_contains_reference", [references, target])


static func _reference_valid(value: Variant) -> bool:
	return _transport().callv("_reference_valid", [value])


static func _request_valid(value: Dictionary) -> bool:
	return _transport().callv("_request_valid", [value])


static func _binding(request: Dictionary) -> Dictionary:
	return _transport().callv("_binding", [request])


static func _same_action(owner: Dictionary, binding: Dictionary) -> bool:
	return _transport().callv("_same_action", [owner, binding])


static func fingerprint(value: Variant) -> String:
	return _transport().callv("fingerprint", [value])


static func _record(owner: Dictionary, path: String, revision: int) -> Dictionary:
	return _transport().callv("_record", [owner, path, revision])


static func _record_valid(value: Variant, path: String) -> Dictionary:
	return _transport().callv("_record_valid", [value, path])


static func _read_record(file_path: String, path: String) -> Dictionary:
	return _transport().callv("_read_record", [file_path, path])


static func _read_intent(path: String) -> Dictionary:
	return _transport().callv("_read_intent", [path])


static func _read_json(path: String, limit: int) -> Variant:
	return _transport().callv("_read_json", [path, limit])


static func _write_atomic(encoded: String, destination: String, label: String) -> bool:
	return _transport().callv("_write_atomic", [encoded, destination, label])


static func _clear_intent(path: String) -> bool:
	return _transport().callv("_clear_intent", [path])


static func _outcome(path: String, expected: Dictionary, reason: String) -> Dictionary:
	return _transport().callv("_outcome", [path, expected, reason])


static func _inspection(
	status: String, reason: String, record: Dictionary = {}, pending: Dictionary = {}
) -> Dictionary:
	return _transport().callv("_inspection", [status, reason, record, pending])


static func _result(
	status: String,
	reason: String,
	owner: Dictionary = {},
	needs_repair: bool = false,
	revision: int = 0
) -> Dictionary:
	return _transport().callv("_result", [status, reason, owner, needs_repair, revision])


static func _same(left: Dictionary, right: Dictionary) -> bool:
	return _transport().callv("_same", [left, right])


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return _transport().callv("_whole", [value, minimum, maximum])


static func _digest(value: Variant) -> bool:
	return _transport().callv("_digest", [value])


static func _canonical(path: String) -> String:
	return _transport().callv("_canonical", [path])


static func _isolated(path: String) -> bool:
	return _transport().callv("_isolated", [path])


static func _encoded(value: Dictionary) -> String:
	return _transport().callv("_encoded", [value])


static func _interrupt(step: String) -> bool:
	if _test_record:
		_test_steps.append(step)
	return _test_stop_after == step


static func _transport() -> RefCounted:
	return Transport.new(Owner, _active_save_path, _interrupt, _get_error, _set_error)


static func _active_save_path() -> String:
	return SeasonSave.path


static func _get_error() -> String:
	return last_error


static func _set_error(value: String) -> void:
	last_error = value
