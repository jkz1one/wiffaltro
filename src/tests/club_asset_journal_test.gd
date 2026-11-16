extends Node
## Actual production journal contracts plus actual player-pack business component.
## This adapter chooses the player domain and supplies synthetic credited income only.
## It does NOT qualify stadium handlers, full Ledger envelopes, OwnerStore or physical play.

const Journal = preload("res://src/gameplay/season/club_asset_journal.gd")
const Pack = preload("res://src/gameplay/season/club_player_pack.gd")
const Catalog = preload("res://src/gameplay/season/club_player_catalog.gd")
const OPEN_FIELDS: Array = ["id", "rev", "op", "through", "price_version"]
const PICK_FIELDS: Array = ["id", "rev", "op", "pack", "player"]
const HEADER_FIELDS: Array = ["version", "seed", "catalog", "events"]
const MAX_EVENTS: int = 4096
var checks: int = 0
var failures: int = 0
var revision_calls: int = 0
var signature_calls: int = 0


func _ready() -> void:
	_lifecycle()
	_request_guards()
	_header_guards()
	_replay_guards()
	print("Production journal and pack checks: %d, failures: %d, outer_stadium=false"
		% [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _new(credits: Array = [35, 65, 0]) -> Dictionary:
	return {"context": {"seed": 17, "credits": credits.duplicate(true), "spent": 0,
		"through": 0, "opened": 0, "pack_owned": [], "pending": {}, "loading": false},
		"events": [], "requests": {}}


func _revision(state: Dictionary) -> int:
	return state.events.size()


func _counted_revision(state: Dictionary) -> int:
	revision_calls += 1
	return _revision(state)


func _signature() -> String:
	signature_calls += 1
	return Catalog.signature()


func _open(state: Dictionary, identity: String = "paid:0", through: int = 2) -> Dictionary:
	return {"id": identity, "rev": _revision(state), "op": "player_pack_open",
		"through": through, "price_version": Catalog.PRICE_VERSION}


func _pick(state: Dictionary, identity: String = "pick:0") -> Dictionary:
	return {"id": identity, "rev": _revision(state), "op": "player_pack_pick",
		"pack": state.context.pending.id, "player": state.context.pending.choices[0]}


# Domain selection is the adapter boundary. All common validation is production code.
func _normalize(command: Dictionary, credits: Array) -> Dictionary:
	if command.get("op") not in ["player_pack_open", "player_pack_pick"]:
		return Journal.error("This focused adapter handles only the player-pack domain.")
	var result: Dictionary = Journal.normalize_request(command,
		OPEN_FIELDS if command.op == "player_pack_open" else PICK_FIELDS, MAX_EVENTS)
	if not result.ok:
		return result
	var event: Dictionary = result.event
	if event.op == "player_pack_open":
		var income_error: Dictionary = Journal.normalize_income(event, credits)
		if not income_error.is_empty():
			return income_error
	elif not event.pack is String or not event.player is String:
		return Journal.error("Invalid player selection.")
	return result


func _commit(command: Dictionary, state: Dictionary) -> Dictionary:
	var normalized: Dictionary = _normalize(command, state.context.credits)
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


func _validate_player_event(_header: Dictionary, event: Dictionary, credits: Array) -> bool:
	return _normalize(event, credits).ok


func _serialize(state: Dictionary) -> Dictionary:
	# Real shared header/event fields in their legacy version1 shape, not a new save format.
	return {"version": 1, "seed": state.context.seed, "catalog": Catalog.signature(),
		"events": Journal.serialized_events(state.events)}


func _restore(value: Dictionary, credits: Array = [35, 65, 0]) -> Dictionary:
	if not Journal.valid_credits(credits) or not Journal.valid_header(
		value, HEADER_FIELDS, 17, Catalog.signature, 56, MAX_EVENTS):
		return {}
	var state: Dictionary = _new(credits)
	state.context.loading = true
	if not Journal.replay(value.events, value,
		_validate_player_event.bind(credits), _commit.bind(state)):
		return {}
	state.context.loading = false
	return state


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _lifecycle() -> void:
	var state: Dictionary = _new()
	check(Journal.valid_credits(state.context.credits), "actual journal admits synthetic income")
	var opening: Dictionary = _open(state)
	var before: Dictionary = state.duplicate(true)
	var transported: Dictionary = _json(opening)
	var transported_before: Dictionary = transported.duplicate(true)
	var normalized: Dictionary = _normalize(transported, state.context.credits)
	check(normalized.ok and normalized.event.rev is int and normalized.event.through is int
		and normalized.event.price_version is int, "actual production normalization after JSON")
	check(state == before and transported == transported_before
		and transported.rev is float and transported.through is float,
		"normalization preserves the actual JSON command and its original numeric types")
	check(_commit(opening, state).ok, "real journal plus pack component commits paid opening")
	check(state.context.spent == 80 and state.context.pending.choices.size() == 3
		and state.events.size() == 1 and state.requests.size() == 1,
		"one canonical event and one charge publish the paid choice")
	before = state.duplicate(true)
	var retry: Dictionary = _commit(_json(opening), state)
	check(retry.ok and retry.replayed and state == before,
		"actual production request identity makes paid retry inert across JSON")
	var saved: Dictionary = _serialize(state)
	var prior_pending: Dictionary = state.context.pending.duplicate(true)
	var cold: Dictionary = _json(saved)
	check(cold.version is float and cold.events[0].rev is float,
		"cold fixture uses actual JSON number transport")
	var restored: Dictionary = _restore(cold)
	check(not restored.is_empty() and Journal.same(restored, state),
		"production header and replay reconstruct exact paid state")
	if restored.is_empty():
		return
	check(_commit(_json(opening), restored).replayed and Journal.same(restored, state),
		"production retry recognition survives actual replay reconstruction")
	var selection: Dictionary = _pick(restored)
	check(_commit(selection, restored).ok and restored.context.spent == 80
		and restored.context.pending.is_empty() and restored.context.pack_owned.size() == 1,
		"choice journals exactly once without another charge")
	before = restored.duplicate(true)
	retry = _commit(_json(selection), restored)
	check(retry.ok and retry.replayed and restored == before,
		"actual journal protects repeated choice")
	var completed: Dictionary = _restore(_json(_serialize(restored)))
	check(not completed.is_empty() and Journal.same(completed, restored),
		"complete production event replay restores purchase and ownership")
	check(state.context.pending == prior_pending
		and state.context.pack_owned.is_empty(), "restored mutation does not alias original state")
	var serialized: Array = Journal.serialized_events(restored.events)
	serialized[0].id = "mutated-output"
	check(restored.events[0].id == opening.id, "production serialization returns detached events")
	var source_event: Dictionary = {"id": "copy", "rev": 0, "payload": {"value": 1}}
	var events: Array = []
	var requests: Dictionary = {}
	Journal.append(events, requests, source_event)
	source_event.payload.value = 2
	check(events[0].payload.value == 1 and requests.copy.payload.value == 1,
		"production append detaches both event and request record from source object")
	events[0].payload.value = 3
	check(source_event.payload.value == 2 and requests.copy.payload.value == 1,
		"event array mutation cannot alias source or separate request record")


func _request_guards() -> void:
	var state: Dictionary = _new()
	var opening: Dictionary = _open(state)
	check(_commit(opening, state).ok, "global request fixture commits through real components")
	var frozen: Dictionary = state.duplicate(true)
	for patch: Dictionary in [{"id": ""}, {"id": "x".repeat(121)}, {"rev": true},
		{"rev": 0.5}, {"rev": NAN}, {"rev": INF}, {"rev": "1"}, {"extra": true},
		{"through": -1}, {"through": 4}, {"through": true}, {"price_version": 0}]:
		var bad: Dictionary = _open(state, "bad")
		bad.merge(patch, true)
		check(not _commit(bad, state).ok and state == frozen,
			"actual shared schema/numeric rejection preserves all state: " + str(patch))
	var conflict: Dictionary = opening.duplicate(true)
	conflict.through = 1
	check(not _commit(conflict, state).ok and state == frozen,
		"global ID cannot be reused with a different normalized command")
	var foreign: Dictionary = {"id": opening.id, "rev": 0, "op": "stadium_style"}
	check(not Journal.request_status(foreign, state.requests, _revision.bind(state), MAX_EVENTS).ok
		and state == frozen, "real global identity rejects cross-domain collision")
	revision_calls = 0
	check(Journal.request_status(opening, state.requests,
		_counted_revision.bind(state), 1).replayed and revision_calls == 0,
		"duplicate identity is recognized before stale/full checks or revision callback")
	var fresh: Dictionary = _open(state, "new")
	revision_calls = 0
	check(Journal.request_status(fresh, state.requests,
		_counted_revision.bind(state), MAX_EVENTS).ok and revision_calls == 2,
		"fresh matching request preserves exact lazy revision call order")
	fresh.rev += 1
	revision_calls = 0
	check(not Journal.request_status(fresh, state.requests,
		_counted_revision.bind(state), MAX_EVENTS).ok and revision_calls == 1,
		"future revision fails before the second revision call")
	fresh.rev = _revision(state)
	check(not Journal.request_status(fresh, state.requests, _revision.bind(state), 1).ok,
		"new event refuses a full journal")


func _header_guards() -> void:
	var saved: Dictionary = _serialize(_new())
	check(Journal.valid_header(_json(saved), HEADER_FIELDS, 17, Catalog.signature, 56, MAX_EVENTS),
		"actual common header accepts JSON whole-number fields")
	for patch: Dictionary in [{"version": true}, {"version": 0}, {"version": 57},
		{"version": 1.5}, {"seed": true}, {"seed": -1}, {"seed": 18}, {"seed": "17"},
		{"catalog": "foreign"}, {"catalog": 1}, {"events": {}}, {"extra": true}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.merge(patch, true)
		check(not Journal.valid_header(bad, HEADER_FIELDS, 17, Catalog.signature, 56, MAX_EVENTS),
			"production common header refuses malformed identity: " + str(patch))
	signature_calls = 0
	var early: Dictionary = saved.duplicate(true)
	early.extra = true
	check(not Journal.valid_header(early, HEADER_FIELDS, 17, _signature, 56, MAX_EVENTS)
		and signature_calls == 0, "wrong keys reject before computing catalog signature")
	early = saved.duplicate(true)
	early.seed = 18
	check(not Journal.valid_header(early, HEADER_FIELDS, 17, _signature, 56, MAX_EVENTS)
		and signature_calls == 0, "wrong seed rejects before signature callback")
	check(Journal.valid_header(saved, HEADER_FIELDS, 17, _signature, 56, MAX_EVENTS)
		and signature_calls == 1, "valid header invokes actual signature exactly once")
	var long: Dictionary = saved.duplicate(true)
	long.events = [{}, {}]
	check(not Journal.valid_header(long, HEADER_FIELDS, 17, Catalog.signature, 56, 1),
		"shared header enforces exact supplied event cap")
	for credits: Variant in [[true], [-1], [NAN], [INF], [1.5], ["35"], {}, null]:
		check(not Journal.valid_credits(credits),
			"actual production income validator refuses invalid input")
	check(Journal.income([35, 65, 180], 2) == 100,
		"production income prefix excludes later earnings")


func _replay_guards() -> void:
	var state: Dictionary = _new()
	check(_commit(_open(state), state).ok, "replay refusal fixture")
	var saved: Dictionary = _serialize(state)
	var frozen_saved: Dictionary = saved.duplicate(true)
	var repeated: Dictionary = saved.duplicate(true)
	repeated.events.append(repeated.events[0].duplicate(true))
	check(_restore(_json(repeated)).is_empty(),
		"production replay rejects duplicated rows rather than treating them as safe UI retries")
	var malformed: Dictionary = saved.duplicate(true)
	malformed.events.append("not-an-event")
	check(_restore(malformed).is_empty(), "production replay refuses non-dictionary row")
	malformed = saved.duplicate(true)
	malformed.events[0].through = 99
	check(_restore(malformed).is_empty(), "real domain normalization rejects impossible replay epoch")
	malformed = saved.duplicate(true)
	malformed.events[0].op = "stadium_style"
	check(_restore(malformed).is_empty(), "player-only adapter cannot silently validate stadium event")
	check(_restore(saved, [35, 5, 0]).is_empty(),
		"actual journal replay propagates real production pack affordability failure")
	check(not Journal.replay([], saved, Callable(), _commit.bind(_new()))
		and not Journal.replay([], saved, _validate_player_event.bind([35, 65, 0]), Callable()),
		"production replay never substitutes a permissive default for missing callbacks")
	var restored: Dictionary = _restore(saved)
	check(not restored.is_empty() and restored.context.pending == state.context.pending
		and saved == frozen_saved,
		"production normalization/replay preserve input header and events across successes/failures")
