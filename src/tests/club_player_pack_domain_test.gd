extends Node
## Actual production pack component, not a fake Ledger or full owner/save qualification.
## Synthetic income and the explicit test journal supply already-validated outer context.
## Global request/revision guards below are harness bookkeeping, NOT production coverage.

const Pack = preload("res://src/gameplay/season/club_player_pack.gd")
const Catalog = preload("res://src/gameplay/season/club_player_catalog.gd")
const Value = preload("res://src/gameplay/season/club_value_contract.gd")

var checks: int = 0
var failures: int = 0


func _ready() -> void:
	_paid_choice()
	_reducer_aliases()
	_refusals()
	_shared_context()
	_exhaustion()
	print("Production pack component checks: %d, failures: %d, outer_ledger=false"
		% [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _journal(credits: Array, seed_value: int = 17) -> Dictionary:
	return {
		"context": {
			"seed": seed_value, "credits": credits.duplicate(true), "spent": 0,
			"through": 0, "opened": 0, "pack_owned": [], "pending": {}, "loading": false
		},
		"events": [], "requests": {}, "revision": 0
	}


func _open(journal: Dictionary, identity: String, through: int = 2) -> Dictionary:
	return {"id": identity, "rev": journal.revision, "op": "player_pack_open",
		"through": through, "price_version": Catalog.PRICE_VERSION}


func _pick(journal: Dictionary, identity: String, player: String) -> Dictionary:
	return {"id": identity, "rev": journal.revision, "op": "player_pack_pick",
		"pack": journal.context.pending.get("id", ""), "player": player}


# Harness normalization preserves JSON whole-number transport before component admission.
# The real Ledger retains its original full schema/revision/request guards unchanged.
func _event(command: Dictionary, credit_count: int) -> Dictionary:
	var result: Dictionary = command.duplicate(true)
	if not Value.whole(result.get("rev"), 0, 4096):
		return {}
	result.rev = int(result.rev)
	if result.get("op") == "player_pack_open":
		if not Value.whole(result.get("through"), 0, credit_count) \
			or not Value.whole(result.get("price_version"), 0, 999):
			return {}
		result.through = int(result.through)
		result.price_version = int(result.price_version)
	return result


func _commit(journal: Dictionary, command: Dictionary) -> Dictionary:
	var event: Dictionary = _event(command, journal.context.credits.size())
	if event.is_empty():
		return {"ok": false, "replayed": false}
	if journal.requests.has(event.id):
		return {"ok": journal.requests[event.id] == event, "replayed": true}
	if event.rev != journal.revision:
		return {"ok": false, "replayed": false}
	var prepared: Dictionary = Pack.prepare(journal.context, event)
	if not prepared.ok:
		return prepared
	Pack._apply_prepared(journal.context, prepared)
	journal.events.append(event.duplicate(true))
	journal.requests[event.id] = event.duplicate(true)
	journal.revision += 1
	return {"ok": true, "replayed": false}


func _replay(events: Array, credits: Array, seed_value: int = 17) -> Dictionary:
	var journal: Dictionary = _journal(credits, seed_value)
	journal.context.loading = true
	for event: Dictionary in events:
		var applied: Dictionary = _commit(journal, event)
		if not applied.ok or applied.replayed:
			return {}
	journal.context.loading = false
	return journal


func _paid_choice() -> void:
	var journal: Dictionary = _journal([35, 65, 0])
	var opening: Dictionary = _open(journal, "open:0")
	var frozen: Dictionary = journal.duplicate(true)
	var offered: Dictionary = Pack.prepare(journal.context, opening)
	check(offered.ok and offered.price == 80 and offered.balance_after == 20,
		"production preparation quotes the existing full charge")
	check(journal == frozen, "production preparation preserves all input state")
	check(offered.choices == Catalog.offers(Catalog.initial_owned(), 17, 0),
		"production preparation uses actual deterministic catalog")
	check(_commit(journal, opening).ok, "production reducer publishes paid reveal")
	check(journal.context.spent == 80 and journal.context.opened == 1
		and journal.context.through == 2, "one charge and exact epoch/sequence transition")
	var paid: Dictionary = journal.context.pending.duplicate(true)
	check(paid == {"id": "open:0", "sequence": 0, "paid": 80,
		"price_version": Catalog.PRICE_VERSION, "choices": offered.choices},
		"paid record contains exact quote, sequence and choices")
	check(_commit(journal, opening).replayed and journal.context.spent == 80,
		"test journal duplicate guard prevents a second reducer call, not outer Ledger coverage")
	var events: Array = JSON.parse_string(JSON.stringify(journal.events))
	check(events[0].rev is float and events[0].through is float,
		"cold fixture genuinely crosses JSON numeric transport")
	var restored: Dictionary = _replay(events, [35, 65, 0])
	check(not restored.is_empty() and restored.context == journal.context,
		"actual production preparation/reducer reconstruct exact paid reveal after JSON")
	if restored.is_empty():
		return
	var choice: String = paid.choices[1]
	var selected: Dictionary = _pick(restored, "pick:0", choice)
	check(_commit(restored, selected).ok, "production reducer publishes one owned card")
	check(restored.context.pack_owned == [choice] and restored.context.pending.is_empty()
		and restored.context.spent == 80, "selection replaces pending without another debit")
	check(journal.context.pending == paid and journal.context.pack_owned.is_empty(),
		"cold restored state does not alias prior live record")
	var picked: Dictionary = restored.duplicate(true)
	check(_commit(restored, selected).replayed and restored == picked,
		"test journal retry guard preserves published choice")
	var again: Dictionary = _replay(JSON.parse_string(JSON.stringify(restored.events)), [35, 65, 0])
	check(not again.is_empty() and again.context == restored.context,
		"actual component replays both paid opening and choice after JSON")
	check(_replay(events, [35, 5, 0]).is_empty(),
		"production affordability rejects replay after supplied income is reduced")
	var altered: Array = events.duplicate(true)
	altered[0].price_version = 999
	check(_replay(altered, [35, 65, 0]).is_empty(), "unknown historical pack price rejects")
	var next: Dictionary = _journal([35, 65, 180])
	next.context = restored.context.duplicate(true)
	next.context.credits = [35, 65, 180]
	var next_offer: Dictionary = Pack.prepare(next.context, _open(next, "next", 3))
	check(next_offer.ok and not next_offer.choices.has(choice),
		"new income can fund a next pack; already purchased character stays excluded")


func _reducer_aliases() -> void:
	var journal: Dictionary = _journal([35, 65])
	var actual: Dictionary = Pack.prepare(journal.context, _open(journal, "alias-open"))
	check(actual.ok, "direct actual-prepared alias fixture")
	if not actual.ok:
		return
	Pack._apply_prepared(journal.context, actual)
	var paid: Dictionary = journal.context.pending.duplicate(true)
	actual.choices.clear()
	check(journal.context.pending == paid,
		"pending choices detach from the exact prepared object passed to reducer")
	var borrowed: Array = journal.context.pack_owned
	var choice: String = paid.choices[0]
	actual = Pack.prepare(journal.context, _pick(journal, "alias-pick", choice))
	check(actual.ok, "direct selection alias fixture")
	if not actual.ok:
		return
	Pack._apply_prepared(journal.context, actual)
	check(borrowed == [choice] and journal.context.pack_owned == borrowed,
		"real reducer appends in place to caller-borrowed pack-owned array")


func _refuse(context: Dictionary, event: Dictionary, label: String) -> void:
	var frozen: Dictionary = context.duplicate(true)
	check(not Pack.prepare(context, event).ok and context == frozen, label)


func _refusals() -> void:
	var journal: Dictionary = _journal([35, 65, 0])
	check(_commit(journal, _open(journal, "paid")).ok, "paid refusal fixture")
	_refuse(journal.context, _open(journal, "another"), "unresolved paid pack blocks another")
	for player: String in ["player.alex_finch", "player.ash_cole", "player.unknown"]:
		_refuse(journal.context, _pick(journal, "bad", player),
			"non-offered identity cannot replace saved choice: " + player)
	var bad: Dictionary = _pick(journal, "wrong-pack", journal.context.pending.choices[0])
	bad.pack = "foreign"
	_refuse(journal.context, bad, "foreign paid pack identity refuses")
	var fresh: Dictionary = _journal([35, 65, 0])
	_refuse(fresh.context, _pick(fresh, "no-paid", "player.ari_banks"),
		"cannot pick before purchase")
	for through: int in [0, 3]:
		_refuse(fresh.context, _open(fresh, "no-income", through),
			"zero or unearned completion record cannot fund pack")
	fresh.context.through = 3
	_refuse(fresh.context, _open(fresh, "old-epoch"), "cannot spend against retired income epoch")
	fresh.context.through = 0
	fresh.context.spent = 21
	_refuse(fresh.context, _open(fresh, "poor"), "shared spent amount prevents overspend")
	fresh.context.spent = 0
	bad = _open(fresh, "wrong-price")
	bad.price_version = 999
	_refuse(fresh.context, bad, "unknown current price refuses")
	_refuse(fresh.context, {"op": "stadium_buy"}, "component refuses foreign business operation")


func _shared_context() -> void:
	var journal: Dictionary = _journal([35, 65])
	# Synthetic already-validated outer context, not a real stadium transaction fixture.
	journal.context.spent = 20
	journal.context.through = 2
	journal.revision = 7
	journal.requests["shared-id"] = {"id": "shared-id", "rev": 6, "op": "stadium_style"}
	var prior: Dictionary = journal.duplicate(true)
	check(not _commit(journal, _open(journal, "shared-id")).ok and journal == prior,
		"test journal preserves global cross-domain request ID, not production guard coverage")
	var opening: Dictionary = _open(journal, "pack-after-stadium")
	check(Pack.prepare(journal.context, opening).balance_after == 0,
		"production business rules include unrelated shared spending in price affordability")
	check(_commit(journal, opening).ok and journal.revision == 8
		and journal.context.spent == 100 and journal.context.opened == 1,
		"pack sequence does not substitute for global revision or total spending")
	check(journal.requests["shared-id"] == prior.requests["shared-id"],
		"production component never edits unrelated global requests")


func _exhaustion() -> void:
	var journal: Dictionary = _journal([2000], 29)
	for index in range(18):
		var opening: Dictionary = _open(journal, "open:%d" % index, 1)
		var offered: Dictionary = Pack.prepare(journal.context, opening)
		check(offered.ok and offered.choices.size() == mini(3, 18 - index),
			"production offer reports actual remaining pool")
		if not offered.ok:
			return
		check(_commit(journal, opening).ok, "production opening during exhaustion")
		var choice: String = journal.context.pending.choices[0]
		var borrowed: Array = journal.context.pack_owned
		var expected: Array = borrowed.duplicate()
		expected.append(choice)
		expected.sort()
		check(_commit(journal, _pick(journal, "pick:%d" % index, choice)).ok,
			"production selection during exhaustion")
		check(journal.context.pack_owned.size() == index + 1
			and borrowed == expected and journal.context.pack_owned == borrowed,
			"one identity appended/sorted in the same borrowed array per production selection")
	var frozen: Dictionary = journal.duplicate(true)
	check(not _commit(journal, _open(journal, "empty", 1)).ok and journal == frozen,
		"exhausted pool cannot burn currency or substitute earned-only character")
	check(journal.context.spent == 1440 and 2000 - journal.context.spent == 560
		and journal.context.pack_owned.size() == 18,
		"all eighteen real pack characters preserve exact existing accounting")
	var restored: Dictionary = _replay(JSON.parse_string(JSON.stringify(journal.events)), [2000], 29)
	check(not restored.is_empty() and restored.context == journal.context,
		"actual production component cold-replays complete paid sequence")
