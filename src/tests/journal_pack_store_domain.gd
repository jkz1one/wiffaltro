extends RefCounted
## Synthetic test domain for the actual durable transport. Not Dynasty or earned-career authority.
## All journal/business validation executes production code; funding is fixed explicitly here.
const Journal = preload("res://src/gameplay/season/club_asset_journal.gd")
const Pack = preload("res://src/gameplay/season/club_player_pack.gd")
const Catalog = preload("res://src/gameplay/season/club_player_catalog.gd")
const Value = preload("res://src/gameplay/season/club_value_contract.gd")
const CREDITS: Array = [35, 65, 0]
const SEED: int = 17
const MAX_EVENTS: int = 4096
const HEADER: Array = ["version", "seed", "catalog", "events"]
const OWNER_FIELDS: Array = ["version", "revision", "last_action", "reference", "request"]
const RECEIPT_FIELDS: Array = ["version", "kind", "request_id", "expected_revision",
	"fingerprint", "before_hash", "after_hash", "source_references", "new_references"]


func fingerprint(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value, "", true, true)),
		"", true, true).sha256_text()


func _snapshot_encoded(value: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value, "", true, true)),
		"", true, true)


func _snapshot_reference(value: Dictionary) -> Dictionary:
	var encoded: String = _snapshot_encoded(value)
	return {"sha256": encoded.sha256_text(), "bytes": encoded.to_utf8_buffer().size()}


func _reference_valid(value: Variant) -> bool:
	if not value is Dictionary or not Journal.keys(value, ["sha256", "bytes"]):
		return false
	if not value.sha256 is String or value.sha256.length() != 64 \
		or not Value.whole(value.bytes, 1, 8 * 1024 * 1024):
		return false
	for character: String in value.sha256:
		if character not in "0123456789abcdef":
			return false
	return true


func _request_valid(request: Variant) -> bool:
	if not request is Dictionary or request.get("op") not in ["create", "checkpoint"]:
		return false
	var fields: Array = ["op", "request_id", "expected_revision",
		"payload" if request.op == "create" else "command"]
	if not Journal.keys(request, fields) or not request.request_id is String \
		or request.request_id.is_empty() or request.request_id.length() > 160 \
		or not Value.whole(request.expected_revision, 0, MAX_EVENTS):
		return false
	if request.op == "create":
		return request.expected_revision == 0 and Journal.same(request.payload,
			{"seed": SEED, "credits": CREDITS})
	return request.command is Dictionary and _normalize_event(request.command).ok


func _binding(request: Dictionary) -> Dictionary:
	return {"id": request.request_id, "kind": request.op,
		"expected_revision": int(request.expected_revision), "fingerprint": fingerprint(request)}


func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or not Journal.keys(value, OWNER_FIELDS) \
		or not Value.whole(value.version, 1, 1) \
		or not Value.whole(value.revision, 1, MAX_EVENTS + 1) \
		or not _reference_valid(value.reference) or not _request_valid(value.request):
		return {}
	if value.request.expected_revision != value.revision - 1 \
		or not Journal.same(value.last_action, _binding(value.request)):
		return {}
	return value.duplicate(true)


func _new_state() -> Dictionary:
	return {"context": {"seed": SEED, "credits": CREDITS.duplicate(), "spent": 0,
		"through": 0, "opened": 0, "pack_owned": [], "pending": {}, "loading": false},
		"events": [], "requests": {}}


func _revision(state: Dictionary) -> int:
	return state.events.size()


func _normalize_event(command: Dictionary) -> Dictionary:
	if command.get("op") not in ["player_pack_open", "player_pack_pick"]:
		return Journal.error("Unsupported test domain.")
	var fields: Array = ["id", "rev", "op"]
	fields.append_array(["through", "price_version"] if command.op == "player_pack_open"
		else ["pack", "player"])
	var normalized: Dictionary = Journal.normalize_request(command, fields, MAX_EVENTS)
	if not normalized.ok:
		return normalized
	var event: Dictionary = normalized.event
	if event.op == "player_pack_open":
		var error: Dictionary = Journal.normalize_income(event, CREDITS)
		if not error.is_empty():
			return error
	elif not event.pack is String or not event.player is String:
		return Journal.error("Invalid player selection.")
	return normalized


func _commit(command: Dictionary, state: Dictionary) -> Dictionary:
	var normalized: Dictionary = _normalize_event(command)
	if not normalized.ok:
		return normalized
	var event: Dictionary = normalized.event
	var status: Dictionary = Journal.request_status(
		event, state.requests, _revision.bind(state), MAX_EVENTS)
	if not status.ok or status.replayed:
		return status
	var prepared: Dictionary = Pack.prepare(state.context, event)
	if not prepared.ok:
		return prepared
	Pack._apply_prepared(state.context, prepared)
	Journal.append(state.events, state.requests, event)
	return status


func _event_valid(_header: Dictionary, event: Dictionary) -> bool:
	return _normalize_event(event).ok


func _snapshot(state: Dictionary) -> Dictionary:
	return {"version": 1, "seed": SEED, "catalog": Catalog.signature(),
		"events": Journal.serialized_events(state.events)}


func _restore(snapshot: Dictionary) -> Dictionary:
	if not Journal.valid_credits(CREDITS) or not Journal.valid_header(
		snapshot, HEADER, SEED, Catalog.signature, 1, MAX_EVENTS):
		return {}
	var state: Dictionary = _new_state()
	state.context.loading = true
	if not Journal.replay(snapshot.events, snapshot, _event_valid, _commit.bind(state)):
		return {}
	state.context.loading = false
	return state


func validate_selected(value: Variant, snapshot: Variant) -> Variant:
	var owner: Dictionary = normalize(value)
	if owner.is_empty() or not snapshot is Dictionary \
		or not Journal.same(owner.reference, _snapshot_reference(snapshot)):
		return null
	var state: Dictionary = _restore(snapshot)
	if state.is_empty() or state.events.size() + 1 != owner.revision:
		return null
	if owner.request.op == "checkpoint" and (state.events.is_empty() \
		or not Journal.same(state.events[-1], _normalize_event(owner.request.command).event)):
		return null
	return state


func required_references(before: Variant, request: Variant) -> Array[Dictionary]:
	var owner: Dictionary = normalize(before)
	var result: Array[Dictionary] = []
	if not owner.is_empty() and request is Dictionary and request.get("op") == "checkpoint":
		result.append(owner.reference)
	return result


func project(before: Variant, request: Variant, sources: Dictionary = {}) -> Dictionary:
	if not before is Dictionary or not _request_valid(request):
		return {}
	var owner: Dictionary = {} if before.is_empty() else normalize(before)
	if (not before.is_empty() and owner.is_empty()) \
		or request.expected_revision != owner.get("revision", 0) \
		or (owner.is_empty() != (request.op == "create")):
		return {}
	var state: Dictionary = _new_state()
	if not owner.is_empty():
		var restored: Variant = validate_selected(owner, sources.get(owner.reference.sha256))
		if restored == null:
			return {}
		state = restored
		var applied: Dictionary = _commit(request.command, state)
		if not applied.ok or applied.replayed:
			return {}
	var snapshot: Dictionary = _snapshot(state)
	var ref: Dictionary = _snapshot_reference(snapshot)
	var after: Dictionary = {"version": 1, "revision": int(request.expected_revision) + 1,
		"last_action": _binding(request), "reference": ref, "request": request.duplicate(true)}
	return {"owner": after, "receipt": _receipt(owner, after),
		"snapshots": {ref.sha256: _snapshot_encoded(snapshot)}}


func _receipt(before: Dictionary, after: Dictionary) -> Dictionary:
	return {"version": 1, "kind": after.request.op, "request_id": after.request.request_id,
		"expected_revision": after.request.expected_revision,
		"fingerprint": fingerprint(after.request), "before_hash": fingerprint(before),
		"after_hash": fingerprint(after), "source_references": required_references(
			before, after.request), "new_references": [after.reference]}


func transition_valid(before: Variant, after: Variant, receipt: Variant) -> bool:
	if not before is Dictionary or not receipt is Dictionary \
		or not Journal.keys(receipt, RECEIPT_FIELDS):
		return false
	var target: Dictionary = normalize(after)
	var prior: Dictionary = {} if before.is_empty() else normalize(before)
	return not target.is_empty() and (before.is_empty() or not prior.is_empty()) \
		and target.revision == prior.get("revision", 0) + 1 \
		and (prior.is_empty() == (target.request.op == "create")) \
		and Journal.same(receipt, _receipt(prior, target))


func new_request_admitted(before: Dictionary, request: Dictionary, after: Dictionary) -> bool:
	var target: Dictionary = normalize(after)
	return not target.is_empty() and _request_valid(request) \
		and request.expected_revision == before.get("revision", 0) \
		and Journal.same(target.request, request)


func request_binding_valid(before: Variant, after: Variant, snapshot: Variant = null,
	origin: Dictionary = {}, origin_snapshot: Variant = null) -> bool:
	var target: Dictionary = normalize(after)
	return before is Dictionary and not target.is_empty() and origin.is_empty() \
		and origin_snapshot == null and target.request.expected_revision == before.get("revision", 0) \
		and validate_selected(target, snapshot) != null


func validate_checkpoint_extension(before: Variant, after: Variant,
	source: Variant, target: Variant) -> bool:
	var prior: Dictionary = normalize(before)
	var next: Dictionary = normalize(after)
	if prior.is_empty() or next.is_empty() or next.request.op != "checkpoint" \
		or validate_selected(prior, source) == null or validate_selected(next, target) == null:
		return false
	var replay: Dictionary = project(prior, next.request, {prior.reference.sha256: source})
	return not replay.is_empty() and Journal.same(replay.owner, next)


func validate_recovery(before: Dictionary, after: Dictionary, receipt: Dictionary,
	sources: Dictionary, target: Dictionary, origin: Variant) -> bool:
	if origin != null or not transition_valid(before, after, receipt) \
		or validate_selected(after, target) == null:
		return false
	var replay: Dictionary = project(before, after.request, sources)
	return not replay.is_empty() and Journal.same(replay.owner, after) \
		and Journal.same(replay.receipt, receipt)


func storage_references(value: Dictionary) -> Array[Dictionary]:
	var owner: Dictionary = normalize(value)
	var result: Array[Dictionary] = []
	if not owner.is_empty():
		result.append(owner.reference)
	return result


func storage_selected_reference(value: Dictionary) -> Dictionary:
	var owner: Dictionary = normalize(value)
	return {} if owner.is_empty() else owner.reference


func storage_pending_source(before: Dictionary, receipt: Dictionary) -> Dictionary:
	var owner: Dictionary = normalize(before)
	if owner.is_empty() or receipt.get("kind") != "checkpoint":
		return {"error": "Invalid player-domain source request."}
	return {"reference": owner.reference}


func storage_requires_origin(_value: Dictionary) -> bool:
	return false  # This explicitly synthetic domain has no external origin envelope.


func storage_requires_recovery(_value: Dictionary) -> bool:
	return true  # Every uncommitted intent must replay the actual journal.


func origin_intent_valid(_after: Dictionary, _origin: Variant) -> bool:
	return false


func qualify_origin(_after: Dictionary, _origin: Dictionary, _snapshot: Variant) -> bool:
	return false
