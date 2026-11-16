extends RefCounted
## Shared durable manifest protocol. Domain validation is fixed by its caller.
## Validators never come from requests or persisted data. Single-writer interruption consistency;
## not power-loss durability, authentication, migration or multiwriter locking.

const MAX_BYTES: int = 1024 * 1024
const MAX_INTENT_BYTES: int = 2 * MAX_BYTES
const MAX_SNAPSHOT_BYTES: int = 8 * 1024 * 1024
const MAX_REVISION: int = 2147483647
const VERSION: int = 1
const ORIGIN_INTENT_VERSION: int = 2
const SUFFIXES: Array[String] = [
	"", ".committed", ".intent", ".tmp", ".committed.tmp", ".intent.tmp", ".bak"
]
var last_error: String:
	get:
		return _error_read.call()
	set(value):
		_error_write.call(value)
var _domain: Object
var _active_path: Callable
var _fault: Callable
var _error_read: Callable
var _error_write: Callable

func _init(
	domain: Object, active_path: Callable, fault: Callable,
	error_read: Callable, error_write: Callable
) -> void:
	_domain = domain
	_active_path = active_path
	_fault = fault
	_error_read = error_read
	_error_write = error_write

func create(payload: Dictionary, path: String) -> Dictionary:
	return commit(
		{
			"op": "create",
			"request_id": "create:" + fingerprint(payload),
			"expected_revision": 0,
			"payload": payload
		},
		path
	)

func transact(request: Dictionary, path: String) -> Dictionary:
	return commit(request, path)

func inspect(path: String) -> Dictionary:
	return _protocol_inspect(self, path)

static func _protocol_inspect(
	ctx: RefCounted, path: String
) -> Dictionary:
	ctx.last_error = ""
	if not ctx._isolated(path):
		return ctx._inspection("blocked", "An isolated closed-owner manifest path is required.")
	var primary: Dictionary = ctx._read_record(path, path)
	var mirror: Dictionary = ctx._read_record(path + ".committed", path)
	if FileAccess.file_exists(path + ".intent"):
		var intent: Dictionary = ctx._read_intent(path)
		if intent.is_empty():
			return ctx._inspection(
				"blocked", "Invalid owner intent; manifest and object evidence preserved."
			)
		for record: Dictionary in [primary, mirror]:
			if (
				not record.is_empty()
				and not ctx._same(record, intent.before)
				and not ctx._same(record, intent.after)
			):
				return ctx._inspection(
					"blocked", "Owner replicas conflict with the exact pending transition."
				)
		if ctx._same(primary, intent.after) or ctx._same(mirror, intent.after):
			return ctx._inspection(
				"recoverable", "Joint owner commit is proven; exact repair remains.", intent.after
			)
		if (
			intent.before.is_empty()
			and not FileAccess.file_exists(path)
			and not FileAccess.file_exists(path + ".committed")
		):
			return ctx._inspection(
				"pending",
				"Initial owner proposal awaits its exact request retry.",
				{},
				intent.after.owner
			)
		if not intent.before.is_empty() and ctx._same(primary, intent.before):
			return ctx._inspection(
				"pending",
				"Uncommitted owner intent locks its exact request and target.",
				intent.before,
				intent.after.owner
			)
		return ctx._inspection(
			"blocked",
			"Source-only mirror and unavailable primary are ambiguous; no rollback selected."
		)
	if not primary.is_empty() and not mirror.is_empty():
		if not ctx._same(primary, mirror):
			return ctx._inspection(
				"blocked", "Different valid owner replicas lack a validating intent."
			)
		return ctx._inspection("ready", "", primary)
	if not primary.is_empty() or not mirror.is_empty():
		return ctx._inspection(
			"recoverable",
			"One owner manifest replica is unavailable.",
			primary if not primary.is_empty() else mirror
		)
	if (
		FileAccess.file_exists(path)
		or FileAccess.file_exists(path + ".committed")
		or FileAccess.file_exists(path + ".bak")
	):
		return ctx._inspection(
			"blocked", "Invalid or legacy owner evidence cannot initialize a replacement."
		)
	return ctx._inspection("empty", "")

func restore(path: String) -> Dictionary:
	var found: Dictionary = inspect(path)
	if found.status not in ["ready", "recoverable"]:
		return _result("blocked" if found.status == "blocked" else "not_committed", found.reason)
	var ref: Dictionary = _selected_reference(found.owner)
	var object: Dictionary = _read_object(path, ref)
	if not object.get("ok", false):
		return _result(
			"blocked",
			"The exact selected snapshot is unavailable; no older snapshot or .bak fallback is permitted."
		)
	var season: Variant = _domain.validate_selected(found.owner, object.snapshot)
	if season == null:
		return _result(
			"blocked",
			"Selected snapshot failed full source qualification against its owner manifest."
		)
	var result: Dictionary = _result(
		"committed",
		"",
		found.owner,
		found.status != "ready" or object.needs_repair,
		int(found.revision)
	)
	result["qualified_selected_season"] = season
	result["playability"] = "qualified"
	return result

func commit(request: Dictionary, path: String) -> Dictionary:
	return _protocol_commit(self, request, path)

static func _protocol_commit(
	ctx: RefCounted, request: Dictionary, path: String
) -> Dictionary:
	if not ctx._request_valid(request) or not ctx._isolated(path):
		return ctx._result("blocked", "Invalid owner request or nonisolated path.")
	var binding: Dictionary = ctx._binding(request)
	var found: Dictionary = ctx.inspect(path)
	if found.status == "blocked":
		return ctx._result("blocked", found.reason)
	if found.status == "pending":
		if not ctx._same_action(found.pending, binding):
			return ctx._result(
				"blocked", "Pending owner intent permits only its exact admitted request."
			)
		return ctx._retry_precommit(ctx._read_intent(path), path)
	if found.status in ["ready", "recoverable"]:
		if ctx._same_action(found.owner, binding):
			return ctx._exact_retry(path, found)
		if found.owner.last_action.id == request.request_id:
			return ctx._result(
				"blocked", "An existing request ID cannot be reused with changed operands."
			)
		if found.status != "ready":
			return ctx._result(
				"blocked", "Repair committed owner redundancy before requesting a new transition."
			)
	if int(request.expected_revision) != int(found.revision) or int(found.revision) >= MAX_REVISION:
		return ctx._result(
			"blocked", "Stale owner revision; no source replay or durable change performed."
		)
	if (found.status == "empty") != (request.op == "create"):
		return ctx._result(
			"blocked", "Owner creation and existing-owner transitions are separate operations."
		)
	var before: Dictionary = {} if found.status == "empty" else ctx._read_record(path, path)
	var sources: Dictionary = {}
	var references: Variant = ctx._domain.required_references(found.owner, request)
	if not references is Array or references.size() > 2:
		return ctx._result("blocked", "The owner operation requested an invalid source set.")
	var previous_refs: Array[Dictionary] = ctx._references(found.owner)
	for reference: Variant in references:
		if not ctx._reference_valid(reference) or not ctx._contains_reference(previous_refs, reference):
			return ctx._result(
				"blocked", "A requested source is not bound by the current owner manifest."
			)
		var source: Dictionary = ctx._read_object(path, reference)
		if not source.get("ok", false):
			return ctx._result(
				"blocked",
				"An exact required snapshot is unavailable; inactive references were preserved."
			)
		sources[reference.sha256] = source.snapshot
	var projected: Dictionary = ctx._domain.project(found.owner, request, sources)
	if (
		not projected.get("owner") is Dictionary
		or not projected.get("receipt") is Dictionary
		or not projected.get("snapshots") is Dictionary
		or projected.snapshots.size() > 2
	):
		return ctx._result("blocked", "Owner source qualification or transition projection failed.")
	var owner: Dictionary = ctx._domain.normalize(projected.owner)
	if (
		owner.is_empty()
		or not ctx._same_action(owner, binding)
		or not ctx._domain.transition_valid(found.owner, owner, projected.receipt)
	):
		return ctx._result("blocked", "Projected owner or bounded transition receipt failed admission.")
	if not ctx._domain.new_request_admitted(found.owner, request, owner):
		return ctx._result("blocked", "This League is not unlocked for a new owner session.")
	var after: Dictionary = ctx._record(owner, path, int(found.revision) + 1)
	var intent: Dictionary = {
		"version": VERSION,
		"path": ctx._canonical(path),
		"before": before,
		"after": after,
		"receipt": projected.receipt
	}
	var origin: Dictionary = projected.get("origin", {})
	if not origin.is_empty():
		if (
			request.op != "create"
			or not before.is_empty()
			or not ctx._domain.origin_intent_valid(owner, origin)
		):
			return ctx._result("blocked", "Invalid explicit access-origin evidence role.")
		intent.version = ORIGIN_INTENT_VERSION
		intent["origin"] = origin
	elif request.op == "create" and ctx._domain.storage_requires_origin(owner):
		return ctx._result("blocked", "Access-bearing creation requires its exact origin evidence.")
	if (
		ctx._encoded(after).to_utf8_buffer().size() > MAX_BYTES
		or ctx._encoded(intent).to_utf8_buffer().size() > MAX_INTENT_BYTES
	):
		return ctx._result(
			"blocked", "Owner manifest or intent exceeds its bounded size; sessions are unchanged."
		)
	# Reconcile only known unreferenced owned files under a stable authority.
	# This also bounds orphan preparation across repeated interrupted processes.
	if not ctx._prune_unreferenced(path, previous_refs):
		return ctx._result(
			"blocked", "Could not safely reconcile unreferenced prepared snapshot objects."
		)
	if not ctx._stage_snapshots(path, owner, projected.snapshots, origin):
		return ctx._result(
			"not_committed",
			"Snapshot preparation was interrupted or invalid; previous owner remains authoritative."
		)
	if not origin.is_empty():
		var evidence: Dictionary = ctx._read_object(path, origin.reference)
		if not evidence.get("ok", false) or evidence.needs_repair:
			return ctx._result(
				"not_committed", "Exact origin replicas are not both durable; owner is unchanged."
			)
	if not ctx._new_references_ready(path, found.owner, owner):
		return ctx._result(
			"not_committed",
			"Exact target snapshot replicas are not both durable; manifest was not changed."
		)
	if not ctx._write_atomic(ctx._encoded(intent), path + ".intent", "intent"):
		return ctx._outcome(path, owner, "Interrupted while preparing the joint owner intent.")
	var result: Dictionary = ctx._complete(intent, path)
	if result.status == "committed" and ctx._domain.storage_requires_origin(owner):
		# New access owners publish only a read-back of the exact committed object.
		var checked: Dictionary = ctx.restore(path)
		if checked.status == "committed":
			return checked
		result["playability"] = "blocked"
		result["reason"] = checked.reason
		return result
	if result.status == "committed" and projected.has("qualified_selected_season"):
		result["qualified_selected_season"] = projected.qualified_selected_season
		result["playability"] = "qualified"
	return result

func _exact_retry(path: String, found: Dictionary) -> Dictionary:
	if found.status == "recoverable":
		repair(path)
	var restored: Dictionary = restore(path)
	if restored.status == "committed":
		return restored
	# An unavailable selected body cannot undo an already proven transaction.
	# Keep the historical commit, but explicitly forbid live-owner promotion.
	var result: Dictionary = _result(
		"committed", restored.reason, found.owner, true, int(found.revision)
	)
	result["playability"] = "blocked"
	return result

func retry_pending(path: String) -> Dictionary:
	var found: Dictionary = inspect(path)
	if found.status == "pending":
		return _retry_precommit(_read_intent(path), path)
	if found.status in ["ready", "recoverable"]:
		return repair(path)
	return _result("blocked", "No valid exact admitted owner intent is available for retry.")

func _retry_precommit(intent: Dictionary, path: String) -> Dictionary:
	return _protocol_retry_precommit(self, intent, path)

static func _protocol_retry_precommit(
	ctx: RefCounted, intent: Dictionary, path: String
) -> Dictionary:
	if intent.is_empty():
		return ctx._result(
			"indeterminate", "Owner intent could not be revalidated; no owner may be promoted."
		)
	var before: Dictionary = intent.before.get("owner", {})
	var origin_source: Dictionary = {}
	if intent.get("version") == ORIGIN_INTENT_VERSION:
		origin_source = ctx._read_object(path, intent.origin.reference)
		if (
			not origin_source.get("ok", false)
			or not ctx._domain.qualify_origin(intent.after.owner, intent.origin, origin_source.snapshot)
		):
			return ctx._result(
				"blocked",
				"Pending access origin is missing, corrupt or unqualified; all evidence is preserved."
			)
	var source: Dictionary = {}
	if not before.is_empty():
		# A cold proposal is not an authenticated claim that source qualification
		# already happened. Rebind its retained source once before any writes.
		# Fresh project commits already qualified this source, and proven after
		# witnesses use repair instead: neither route repeats this historical check.
		var selected: Dictionary = ctx._domain.storage_pending_source(before, intent.receipt)
		if selected.has("error"):
			return ctx._result("blocked", selected.error)
		var reference: Dictionary = selected.reference
		source = ctx._read_object(path, reference)
		if not source.get("ok", false) or ctx._domain.validate_selected(before, source.snapshot) == null:
			return ctx._result(
				"blocked",
				"Pending source failed exact owner qualification; all evidence is preserved."
			)
	# A compact target is also only a proposal. Qualify it sequentially after
	# the before SeasonState has expired, never once for each identical replica.
	var target: Dictionary = ctx._read_object(path, ctx._selected_reference(intent.after.owner))
	if not target.get("ok", false):
		return ctx._result(
			"blocked", "Pending selected target is unavailable; all evidence is preserved."
		)
	if intent.receipt.kind == "checkpoint":
		if not ctx._domain.validate_checkpoint_extension(
			before, intent.after.owner, source.snapshot, target.snapshot
		):
			return ctx._result(
				"blocked",
				"Pending checkpoint failed exact source extension; all evidence is preserved."
			)
	elif ctx._domain.validate_selected(intent.after.owner, target.snapshot) == null:
		return ctx._result(
			"blocked",
			"Pending selected target failed full qualification; all evidence is preserved."
		)
	if not ctx._domain.request_binding_valid(
		before,
		intent.after.owner,
		target.snapshot,
		intent.get("origin", {}),
		origin_source.get("snapshot")
	):
		return ctx._result(
			"blocked",
			"Pending target does not match its exact request fingerprint; all evidence is preserved."
		)
	if ctx._domain.storage_requires_recovery(intent.after.owner):
		var replay_sources: Dictionary = {}
		for reference: Dictionary in intent.receipt.source_references:
			var retained: Dictionary = ctx._read_object(path, reference)
			if not retained.get("ok", false):
				return ctx._result("blocked", "Joint-career retry source is unavailable.")
			replay_sources[reference.sha256] = retained.snapshot
		if not ctx._domain.validate_recovery(
			before,
			intent.after.owner,
			intent.receipt,
			replay_sources,
			target.snapshot,
			origin_source.get("snapshot")
		):
			return ctx._result("blocked", "Joint-career transition failed exact source replay.")
	return ctx._complete(intent, path)

func repair_snapshot(path: String, reference: Dictionary) -> Dictionary:
	var found: Dictionary = inspect(path)
	if found.status not in ["ready", "recoverable", "pending"]:
		return _result("blocked", "Snapshot repair requires valid bound owner evidence.")
	var allowed: Array[Dictionary] = _references(found.owner)
	allowed.append_array(_references(found.pending))
	if not _reference_valid(reference) or not _contains_reference(allowed, reference):
		return _result("blocked", "Snapshot repair cannot use an unreferenced object.")
	var object: Dictionary = _read_object(path, reference)
	if not object.get("ok", false):
		return _result("blocked", "Neither exact same-digest snapshot copy is available.")
	if object.needs_repair and not _repair_object(path, reference, object.encoded):
		return _result(
			"not_committed", "Snapshot replica repair interrupted; owner selection is unchanged."
		)
	return _result("committed", "Exact snapshot redundancy restored; owner selection is unchanged.")

func repair(path: String) -> Dictionary:
	return _protocol_repair(self, path)

static func _protocol_repair(
	ctx: RefCounted, path: String
) -> Dictionary:
	var found: Dictionary = ctx.inspect(path)
	if found.status not in ["ready", "recoverable"]:
		return ctx._result(
			"blocked",
			"Repair requires an unambiguously committed owner; pending evidence is retained."
		)
	var reference: Dictionary = ctx._selected_reference(found.owner)
	var object: Dictionary = ctx._read_object(path, reference)
	if not object.get("ok", false):
		return ctx._result("blocked", "Neither exact selected-snapshot replica can supply recovery.")
	if object.needs_repair and not ctx._repair_object(path, reference, object.encoded):
		return ctx._result(
			"committed",
			"Selected snapshot is recoverable; exact replica repair remains.",
			found.owner,
			true,
			int(found.revision)
		)
	var chosen: Dictionary = ctx._record(found.owner, path, int(found.revision))
	if (
		not ctx._same(ctx._read_record(path, path), chosen)
		and not ctx._write_atomic(ctx._encoded(chosen), path, "repair_primary")
	):
		return ctx._outcome(path, found.owner, "Owner primary repair interrupted.")
	if (
		not ctx._same(ctx._read_record(path + ".committed", path), chosen)
		and not ctx._write_atomic(ctx._encoded(chosen), path + ".committed", "repair_mirror")
	):
		return ctx._outcome(path, found.owner, "Owner mirror repair interrupted.")
	if not ctx._clear_intent(path):
		return ctx._outcome(path, found.owner, "Committed owner intent cleanup remains.")
	# Cleanup is an optimization after commitment, never grounds for rollback.
	var result: Dictionary = ctx._outcome(path, found.owner, "")
	if result.status == "committed" and not result.needs_repair:
		result["cleanup_pending"] = not ctx._prune_unreferenced(path, ctx._references(found.owner))
	return result

func read_snapshot(path: String, reference: Dictionary) -> Dictionary:
	# Only resolve a reference proven reachable from current/pending authority.
	var found: Dictionary = inspect(path)
	if found.status not in ["ready", "recoverable", "pending"]:
		return {}
	var allowed: Array[Dictionary] = _references(found.owner)
	allowed.append_array(_references(found.pending))
	if not _contains_reference(allowed, reference):
		return {}
	var object: Dictionary = _read_object(path, reference)
	return object.snapshot if object.get("ok", false) else {}

func _complete(intent: Dictionary, path: String) -> Dictionary:
	return _protocol_complete(self, intent, path)

static func _protocol_complete(
	ctx: RefCounted, intent: Dictionary, path: String
) -> Dictionary:
	if intent.is_empty():
		return ctx._result(
			"indeterminate", "Owner intent could not be revalidated; no owner may be promoted."
		)
	var before_owner: Dictionary = intent.before.get("owner", {})
	if intent.get("version") == ORIGIN_INTENT_VERSION:
		var origin: Dictionary = ctx._read_object(path, intent.origin.reference)
		if (
			not origin.get("ok", false)
			or (
				origin.needs_repair
				and not ctx._repair_object(path, intent.origin.reference, origin.encoded)
			)
		):
			return ctx._result(
				"blocked",
				"Pending origin replicas are incomplete; the exact intent remains locked."
			)
	if not ctx._repair_pending_references(path, before_owner, intent.after.owner):
		return ctx._result(
			"blocked",
			"Pending target snapshot evidence is incomplete; the exact intent remains locked."
		)
	if not ctx._write_atomic(ctx._encoded(intent.after), path, "primary"):
		return ctx._outcome(path, intent.after.owner, "Interrupted at the joint owner commit boundary.")
	if not ctx._write_atomic(ctx._encoded(intent.after), path + ".committed", "mirror"):
		return ctx._outcome(path, intent.after.owner, "Owner committed; mirror repair may remain.")
	if not ctx._clear_intent(path):
		return ctx._outcome(path, intent.after.owner, "Owner committed; intent cleanup may remain.")
	var result: Dictionary = ctx._outcome(path, intent.after.owner, "")
	if result.status == "committed" and not result.needs_repair:
		result["cleanup_pending"] = not ctx._prune_unreferenced(path, ctx._references(intent.after.owner))
	return result

func _repair_pending_references(path: String, before: Dictionary, after: Dictionary) -> bool:
	var retained: Array[Dictionary] = _references(before)
	var selected: Dictionary = _selected_reference(after)
	var repairs: Array[Dictionary] = []
	for reference: Dictionary in _references(after):
		if not _contains_reference(retained, reference) or _same(reference, selected):
			var object: Dictionary = _read_object(path, reference)
			if not object.get("ok", false):
				return false
			if object.needs_repair:
				repairs.append({"reference": reference, "encoded": object.encoded})
	for item: Dictionary in repairs:
		if not _repair_object(path, item.reference, item.encoded):
			return false
	return true

func _new_references_ready(path: String, before: Dictionary, after: Dictionary) -> bool:
	var retained: Array[Dictionary] = _references(before)
	var selected: Dictionary = _selected_reference(after)
	for reference: Dictionary in _references(after):
		if not _contains_reference(retained, reference) or _same(reference, selected):
			var object: Dictionary = _read_object(path, reference)
			if not object.get("ok", false) or object.needs_repair:
				return false
	return true

func _stage_snapshots(
	path: String, owner: Dictionary, snapshots: Dictionary, origin: Dictionary = {}
) -> bool:
	return _protocol_stage_snapshots(self, path, owner, snapshots, origin)

static func _protocol_stage_snapshots(
	ctx: RefCounted,
	path: String,
	owner: Dictionary,
	snapshots: Dictionary,
	origin: Dictionary = {}
) -> bool:
	var refs: Array[Dictionary] = ctx._references(owner)
	if not origin.is_empty():
		if not ctx._domain.origin_intent_valid(owner, origin):
			return false
		refs.append(origin.reference)
	# Validate all prepared bytes before writing any of them.
	for digest: Variant in snapshots:
		if not ctx._digest(digest) or not snapshots[digest] is String:
			return false
		var encoded: String = snapshots[digest]
		var reference: Dictionary = {"sha256": digest, "bytes": encoded.to_utf8_buffer().size()}
		if (
			not ctx._reference_valid(reference)
			or not ctx._contains_reference(refs, reference)
			or encoded.sha256_text() != digest
			or not ctx._parse_snapshot(encoded) is Dictionary
		):
			return false
	if DirAccess.make_dir_recursive_absolute(ctx._canonical(path) + ".objects") != OK:
		return false
	var index: int = 0
	for digest: String in snapshots:
		var encoded: String = snapshots[digest]
		var reference: Dictionary = {"sha256": digest, "bytes": encoded.to_utf8_buffer().size()}
		for replica: String in ["a", "b"]:
			var destination: String = ctx._object_path(path, reference, replica)
			if not ctx._read_object_bytes(destination, reference).get("ok", false):
				if not ctx._write_atomic(encoded, destination, "object%d.%s" % [index, replica]):
					return false
			if not ctx._read_object_bytes(destination, reference).get("ok", false):
				return false
		index += 1
	return true

func _repair_object(path: String, reference: Dictionary, encoded: String) -> bool:
	if (
		encoded.sha256_text() != reference.sha256
		or encoded.to_utf8_buffer().size() != int(reference.bytes)
	):
		return false
	for replica: String in ["a", "b"]:
		var destination: String = _object_path(path, reference, replica)
		if not _read_object_bytes(destination, reference).get("ok", false):
			if not _write_atomic(encoded, destination, "repair_object." + replica):
				return false
	return true

func _read_object(path: String, reference: Dictionary) -> Dictionary:
	if not _reference_valid(reference):
		return {"ok": false}
	var first: Dictionary = _read_object_bytes(_object_path(path, reference, "a"), reference)
	var second: Dictionary = _read_object_bytes(_object_path(path, reference, "b"), reference)
	if not first.ok and not second.ok:
		return {"ok": false}
	var encoded: String = first.encoded if first.ok else second.encoded
	var snapshot: Variant = _parse_snapshot(encoded)
	if not snapshot is Dictionary:
		return {"ok": false}
	return {
		"ok": true,
		"encoded": encoded,
		"snapshot": snapshot,
		"needs_repair": not first.ok or not second.ok
	}

func _read_object_bytes(path: String, reference: Dictionary) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	if file.get_length() != int(reference.bytes) or file.get_length() > MAX_SNAPSHOT_BYTES:
		file.close()
		return {"ok": false}
	var bytes: PackedByteArray = file.get_buffer(int(file.get_length()))
	var error: Error = file.get_error()
	file.close()
	var encoded: String = bytes.get_string_from_utf8()
	if (
		(error != OK and error != ERR_FILE_EOF)
		or encoded.to_utf8_buffer() != bytes
		or encoded.sha256_text() != reference.sha256
	):
		return {"ok": false}
	return {"ok": true, "encoded": encoded}

func _parse_snapshot(encoded: String) -> Variant:
	var json: JSON = JSON.new()
	if json.parse(encoded) != OK or not json.data is Dictionary:
		return null
	# Owner envelopes are not season snapshots, even if their bytes are valid JSON.
	if json.data.has("owner") or json.data.has("selected") or json.data.has("snapshot_ref"):
		return null
	return json.data

func _prune_unreferenced(path: String, retained: Array[Dictionary]) -> bool:
	return _protocol_prune_unreferenced(self, path, retained)

static func _protocol_prune_unreferenced(
	ctx: RefCounted, path: String, retained: Array[Dictionary]
) -> bool:
	# Never clean through ambiguous/invalid manifest evidence or a pending intent.
	var found: Dictionary = ctx.inspect(path)
	if (
		found.status not in ["ready", "empty"]
		or FileAccess.file_exists(path + ".intent")
		or retained.size() > 4
	):
		return false
	for committed: Dictionary in ctx._references(found.owner):
		if not ctx._contains_reference(retained, committed):
			return false
	var root: String = ctx._canonical(path) + ".objects"
	if not DirAccess.dir_exists_absolute(root):
		return true
	var directory: DirAccess = DirAccess.open(root)
	if directory == null:
		return false
	var names: PackedStringArray = directory.get_files()
	for name: String in names:
		var digest: String = ctx._object_filename_digest(name)
		if digest.is_empty():
			continue
		var keep: bool = false
		for reference: Dictionary in retained:
			if reference.sha256 == digest and not name.ends_with(".tmp"):
				keep = true
				break
		if not keep:
			if directory.is_link(name) or DirAccess.remove_absolute(root + "/" + name) != OK:
				return false
			if ctx._interrupt("objects.prune"):
				return false
	return true

func _object_filename_digest(name: String) -> String:
	for suffix: String in [".a.json", ".b.json", ".a.json.tmp", ".b.json.tmp"]:
		if name.ends_with(suffix):
			var digest: String = name.trim_suffix(suffix)
			return digest if _digest(digest) else ""
	return ""

func _object_path(path: String, reference: Dictionary, replica: String) -> String:
	return _canonical(path) + ".objects/" + reference.sha256 + "." + replica + ".json"

func _references(owner: Dictionary) -> Array[Dictionary]:
	return _domain.storage_references(owner)

func _selected_reference(owner: Dictionary) -> Dictionary:
	return _domain.storage_selected_reference(owner)

func _contains_reference(references: Array[Dictionary], target: Dictionary) -> bool:
	for reference: Dictionary in references:
		if _same(reference, target):
			return true
	return false

func _reference_valid(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.size() == 2
		and _digest(value.get("sha256"))
		and _whole(value.get("bytes"), 1, MAX_SNAPSHOT_BYTES)
	)

func _request_valid(value: Dictionary) -> bool:
	return (
		(
			value.get("op")
			in [
				"create",
				"checkpoint",
				"switch",
				"close",
				"begin_next",
				"choose_next",
				"player_assets",
				"stadium_assets"
			]
		)
		and value.get("request_id") is String
		and not value.request_id.is_empty()
		and value.request_id.length() <= 160
		and _whole(value.get("expected_revision"), 0, MAX_REVISION)
	)

func _binding(request: Dictionary) -> Dictionary:
	return {
		"id": request.request_id,
		"kind": request.op,
		"expected_revision": int(request.expected_revision),
		"fingerprint": fingerprint(request)
	}

func _same_action(owner: Dictionary, binding: Dictionary) -> bool:
	return _same(owner.get("last_action", {}), binding)

func fingerprint(value: Variant) -> String:
	# Full-precision JSON numeric identity, not authenticity or blanket rounding.
	return (
		JSON
		. stringify(JSON.parse_string(JSON.stringify(value, "", true, true)), "", true, true)
		. sha256_text()
	)

func _record(owner: Dictionary, path: String, revision: int) -> Dictionary:
	return {"version": VERSION, "path": _canonical(path), "revision": revision, "owner": owner}

func _record_valid(value: Variant, path: String) -> Dictionary:
	if (
		not value is Dictionary
		or value.size() != 4
		or not _whole(value.get("version"), VERSION, VERSION)
		or value.get("path") != _canonical(path)
		or not _whole(value.get("revision"), 1, MAX_REVISION)
	):
		return {}
	var owner: Dictionary = _domain.normalize(value.get("owner"))
	if (
		owner.is_empty()
		or owner.get("revision") != value.revision
		or owner.last_action.expected_revision != value.revision - 1
	):
		return {}
	return _record(owner, path, int(value.revision))

func _read_record(file_path: String, path: String) -> Dictionary:
	return _record_valid(_read_json(file_path, MAX_BYTES), path)

func _read_intent(path: String) -> Dictionary:
	return _protocol_read_intent(self, path)

static func _protocol_read_intent(
	ctx: RefCounted, path: String
) -> Dictionary:
	var value: Variant = ctx._read_json(path + ".intent", MAX_INTENT_BYTES)
	if (
		not value is Dictionary
		or not ctx._whole(value.get("version"), VERSION, ORIGIN_INTENT_VERSION)
		or value.size() != (6 if value.version == ORIGIN_INTENT_VERSION else 5)
		or value.get("path") != ctx._canonical(path)
		or not value.get("before") is Dictionary
		or not value.get("receipt") is Dictionary
	):
		return {}
	var after: Dictionary = ctx._record_valid(value.get("after"), path)
	if after.is_empty():
		return {}
	var before: Dictionary = {}
	if not value.before.is_empty():
		before = ctx._record_valid(value.before, path)
		if before.is_empty() or after.revision != before.revision + 1:
			return {}
	elif after.revision != 1:
		return {}
	if not ctx._domain.transition_valid(before.get("owner", {}), after.owner, value.receipt):
		return {}
	var result: Dictionary = {
		"version": int(value.version),
		"path": ctx._canonical(path),
		"before": before,
		"after": after,
		"receipt": value.receipt
	}
	if value.version == ORIGIN_INTENT_VERSION:
		if not before.is_empty() or not ctx._domain.origin_intent_valid(after.owner, value.get("origin")):
			return {}
		result["origin"] = value.origin
	elif before.is_empty() and ctx._domain.storage_requires_origin(after.owner):
		return {}
	return result

func _read_json(path: String, limit: int) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	if file.get_length() > limit:
		file.close()
		return null
	var encoded: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	return json.data if json.parse(encoded) == OK else null

func _write_atomic(encoded: String, destination: String, label: String) -> bool:
	return _protocol_write_atomic(self, encoded, destination, label)

static func _protocol_write_atomic(
	ctx: RefCounted, encoded: String, destination: String, label: String
) -> bool:
	var file: FileAccess = FileAccess.open(destination + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	if ctx._interrupt(label + ".open"):
		file.close()
		return false
	file.store_string(encoded)
	if ctx._interrupt(label + ".write"):
		file.close()
		return false
	file.flush()
	if ctx._interrupt(label + ".flush"):
		file.close()
		return false
	var error: Error = file.get_error()
	file.close()
	if error != OK or ctx._interrupt(label + ".close"):
		return false
	if DirAccess.rename_absolute(destination + ".tmp", destination) != OK:
		return false
	return not ctx._interrupt(label + ".rename")

func _clear_intent(path: String) -> bool:
	if (
		FileAccess.file_exists(path + ".intent")
		and DirAccess.remove_absolute(path + ".intent") != OK
	):
		return false
	return not _interrupt("intent.clear")

func _outcome(path: String, expected: Dictionary, reason: String) -> Dictionary:
	var found: Dictionary = inspect(path)
	if found.status in ["ready", "recoverable"] and _same(found.owner, expected):
		return _result(
			"committed", reason, found.owner, found.status != "ready", int(found.revision)
		)
	if found.status in ["empty", "pending", "ready"]:
		return _result("not_committed", reason)
	return _result("indeterminate", reason + " No live owner may be promoted.")

func _inspection(
	status: String, reason: String, record: Dictionary = {}, pending: Dictionary = {}
) -> Dictionary:
	last_error = reason
	return {
		"status": status,
		"reason": reason,
		"owner": record.get("owner", {}),
		"revision": int(record.get("revision", 0)),
		"pending": pending
	}

func _result(
	status: String,
	reason: String,
	owner: Dictionary = {},
	needs_repair: bool = false,
	revision: int = 0
) -> Dictionary:
	last_error = reason
	return {
		"status": status,
		"reason": reason,
		"owner": owner,
		"needs_repair": needs_repair,
		"revision": revision,
		"playability":
		"unqualified" if status == "committed" and not owner.is_empty() else "blocked"
	}

func _same(left: Dictionary, right: Dictionary) -> bool:
	return not left.is_empty() and not right.is_empty() and fingerprint(left) == fingerprint(right)

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and value >= minimum
		and value <= maximum
	)

func _digest(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true

func _canonical(path: String) -> String:
	return ProjectSettings.globalize_path(path).simplify_path()

func _isolated(path: String) -> bool:
	if path.is_empty():
		return false
	var target: String = _canonical(path)
	var active: String = _canonical(_active_path.call())
	if active.begins_with(target + ".objects/"):
		return false
	for suffix: String in SUFFIXES:
		if target + suffix in [active, active + ".bak", active + ".tmp"]:
			return false
	return true

func _encoded(value: Dictionary) -> String:
	return JSON.stringify(value, "", true, true)

func _interrupt(step: String) -> bool:
	return _fault.call(step)
