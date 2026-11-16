extends "res://src/tests/season_ownership_test.gd"
## Synthetic capacity contracts; these do not unlock or offer an unfinished sponsor.


func _ready() -> void:
	_removal()
	_replacement()
	_pairs()
	_other_capacity()
	_invalid()
	_persistence()
	if _failures == 0:
		print(
			"Wiffaltro sponsor set checks passed: final capacity, exact sales, rollback and replay."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _catalog() -> Dictionary:
	var catalog: Dictionary = {
		"capacity":
		{
			"kind": "sponsor",
			"price": 14,
			"sale": "half",
			"rarity": "Uncommon",
			"sponsor_delta": 2,
			"peer_rarity": "Common"
		},
		"replacement":
		{
			"kind": "sponsor",
			"price": 16,
			"sale": "half",
			"rarity": "Uncommon",
			"sponsor_delta": 2,
			"peer_rarity": "Common"
		},
		"uncommon": {"kind": "sponsor", "price": 12, "sale": "half", "rarity": "Uncommon"},
		"blocked": {"kind": "sponsor", "price": 0, "sale": "blocked", "rarity": "Common"},
		"card": {"kind": "held", "price": 0, "sale": "zero"},
		"bat": {"kind": "gear", "slot": "bat", "price": 0, "sale": "half"}
	}
	for index in range(9):
		catalog["common%d" % index] = {
			"kind": "sponsor", "price": 8, "sale": "half", "rarity": "Common"
		}
	catalog.common0.sale = "zero"
	return catalog


func _bank(expanded: bool = true) -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new(_catalog())
	for game in range(6):
		_ok(
			bank.commit(OwnershipFixtures.request(bank, "reward", {"game": game, "win": true})),
			"fund synthetic contract"
		)
	var offers: Dictionary = {}
	var item_ids: Array = _catalog().keys()
	item_ids.sort()
	for id: String in item_ids:
		offers[id] = id
	_ok(bank.commit(OwnershipFixtures.request(bank, "stock", {"offers": offers})), "stock")
	if expanded:
		_ok(bank.commit(OwnershipFixtures.buy(bank, "capacity")), "paid extra capacity")
		for index in range(6):
			_ok(bank.commit(OwnershipFixtures.buy(bank, "common%d" % index)), "paid Common")
	return bank


func _id(bank: SeasonOwnership, item: String) -> String:
	for owned: Dictionary in bank.view().sponsors:
		if owned.item == item:
			return owned.id
	return ""


func _group(bank: SeasonOwnership, sales: Array, purchases: Array = []) -> Dictionary:
	return OwnershipFixtures.request(bank, "sponsor_set", {"sales": sales, "purchases": purchases})


func _purchase(offer: String, discount: int = 0) -> Dictionary:
	return {"offer": offer, "discount": discount}


func _removal() -> void:
	var bank: SeasonOwnership = _bank()
	_check(bank.view().capacity.sponsors == 7 and bank.view().sponsors.size() == 7, "seven active")
	var capacity: String = _id(bank, "capacity")
	_reject(bank, _group(bank, [capacity]), "losing extra capacity needs an explicit extra sale")
	var command: Dictionary = _group(bank, [capacity, _id(bank, "common1")])
	var before: Dictionary = bank.view()
	var quote: Dictionary = bank.preview(command)
	_check(quote.ok and bank.view() == before, "cancelled group preview changes nothing")
	_check(quote.after.cash == before.cash + 11, "preview exact two-receipt refund")
	var reverse: SeasonOwnership = bank.fork()
	var reversed: Dictionary = command.duplicate(true)
	reversed.sales.reverse()
	_ok(reverse.commit(reversed), "reverse sale order")
	_ok(bank.commit(command), "capacity sponsor can be first sale in complete resolution")
	_check(bank.view() == reverse.view(), "sale order does not change final ownership")
	_check(bank.view().sponsors.size() == 5 and bank.view().capacity.sponsors == 5, "no reserve")
	_check(bank.view().cash == before.cash + 11, "both and only reviewed refunds")
	var settled: Dictionary = bank.view()
	_ok(bank.commit(command), "same group retry")
	_check(bank.view() == settled, "retry cannot duplicate refunds")
	bank = _bank()
	before = bank.view()
	_ok(bank.commit(_group(bank, [_id(bank, "capacity"), _id(bank, "common0")])), "zero-sale peer")
	_check(bank.cash() == before.cash + 7, "zero-sale exception remains zero in a group")


func _replacement() -> void:
	var bank: SeasonOwnership = _bank()
	_ok(
		bank.commit(OwnershipFixtures.request(bank, "charge", {"amount": bank.cash() - 9})),
		"exact funding boundary"
	)
	var command: Dictionary = _group(bank, [_id(bank, "capacity")], [_purchase("replacement")])
	var poor: SeasonOwnership = bank.fork()
	# Commit a real charge before deriving the poor bank's fresh revision.
	_ok(poor.commit(OwnershipFixtures.request(poor, "charge", {"amount": 1})), "one Cash short")
	_reject(
		poor,
		_group(poor, [_id(poor, "capacity")], [_purchase("replacement")]),
		"combined proceeds insufficient"
	)
	_ok(bank.commit(command), "replacement uses final capacity and old sale proceeds")
	_check(bank.cash() == 0 and bank.view().sponsors.size() == 7, "no intermediate capacity loss")
	var receipt: Dictionary = SeasonOwnership._owned(
		bank.view(), SeasonSponsorSet.receipt_id(command.id, 0)
	)
	_check(receipt.item == "replacement" and receipt.paid == 16, "full paid receipt, not net cost")
	_reject(bank, _group(bank, [], [_purchase("uncommon")]), "incompatible peer blocked")
	bank = _bank()
	command = _group(
		bank,
		[_id(bank, "capacity"), _id(bank, "common1"), _id(bank, "common2")],
		[_purchase("uncommon")]
	)
	_ok(bank.commit(command), "explicit removals permit a different final rarity loadout")
	_check(
		bank.view().sponsors.size() == 5 and bank.view().capacity.sponsors == 5,
		"replacement cannot keep departed capacity"
	)
	bank = _bank(false)
	_ok(bank.commit(OwnershipFixtures.buy(bank, "uncommon")), "old incompatible sponsor")
	_reject(bank, _group(bank, [], [_purchase("capacity")]), "capacity purchase cannot hide peer")
	_ok(
		bank.commit(_group(bank, [_id(bank, "uncommon")], [_purchase("capacity")])),
		"explicit incompatible sale permits capacity sponsor"
	)


func _pairs() -> void:
	for reverse: bool in [false, true]:
		var bank: SeasonOwnership = _bank(false)
		for index in range(5):
			_ok(bank.commit(OwnershipFixtures.buy(bank, "common%d" % index)), "base five")
		var purchases: Array = [_purchase("common5", 2), _purchase("capacity")]
		if reverse:
			purchases.reverse()
		var command: Dictionary = _group(bank, [], purchases)
		var before: int = bank.cash()
		_ok(bank.commit(command), "pair capacity validated after both purchases")
		_check(
			bank.view().sponsors.size() == 7 and bank.cash() == before - 20,
			"both purchase orders charge exact combined price"
		)
		var common: Dictionary = SeasonOwnership._owned(bank.view(), _id(bank, "common5"))
		_check(common.paid == 6, "discount belongs to exact selected receipt")
		before = bank.cash()
		_ok(
			bank.commit(_group(bank, [_id(bank, "capacity"), common.id])), "discounted group resale"
		)
		_check(bank.cash() == before + 10, "refund based on paid six, not list eight")
	var bank: SeasonOwnership = _bank(false)
	var command: Dictionary = _group(bank, [], [_purchase("capacity"), _purchase("uncommon")])
	_reject(bank, command, "pair capacity does not override final rarity restriction")
	command.purchases.reverse()
	_reject(bank, command, "rarity validation also independent of purchase order")
	# A malformed rarity contract cannot enter trusted stock.
	for field: String in ["rarity", "peer_rarity"]:
		var catalog: Dictionary = _catalog()
		catalog.capacity[field] = "Legendary"
		var invalid: SeasonOwnership = SeasonOwnership.new(catalog)
		_reject(
			invalid,
			OwnershipFixtures.request(invalid, "stock", {"offers": {"x": "capacity"}}),
			"unsupported rarity metadata"
		)


func _invalid() -> void:
	var bank: SeasonOwnership = _bank()
	var capacity: String = _id(bank, "capacity")
	for sales: Array in [[capacity, capacity], [capacity, "foreign"], [null]]:
		_reject(bank, _group(bank, sales), "invalid exact sale list")
	for purchases: Array in [
		[null],
		[{"offer": "replacement"}],
		[{"offer": "missing", "discount": 0}],
		[_purchase("replacement"), _purchase("replacement")],
		[_purchase("bat")],
		[_purchase("card")],
		[_purchase("replacement", 5)],
		[_purchase("replacement", -1)],
		[{"offer": "replacement", "discount": 1.5}],
		[{"offer": "replacement", "discount": true}],
		[{"offer": "replacement", "discount": 0, "paid": 0}],
		[_purchase("common6"), _purchase("common7"), _purchase("common8")]
	]:
		_reject(bank, _group(bank, [capacity], purchases), "invalid purchase list is atomic")
	_reject(bank, _group(bank, [], []), "empty operation")
	var command: Dictionary = _group(bank, [capacity, _id(bank, "common1")])
	command["cash"] = 100
	_reject(bank, command, "cannot inject balance")
	command = _group(bank, [capacity, _id(bank, "common1")])
	command.sales = "all"
	_reject(bank, command, "cannot use implicit sale selection")
	command = _group(bank, [capacity, _id(bank, "common1")])
	command.purchases = "none"
	_reject(bank, command, "malformed purchase container")
	bank = _bank(false)
	for offer: String in ["bat", "card", "blocked", "common1"]:
		_ok(bank.commit(OwnershipFixtures.buy(bank, offer)), "wrong-kind and blocked fixtures")
	for receipt: String in [bank.view().gear.bat.id, bank.view().held[0].id]:
		_reject(
			bank, _group(bank, [receipt]), "cannot sell Gear or held card through sponsor group"
		)
	_reject(
		bank,
		_group(bank, [_id(bank, "common1"), _id(bank, "blocked")]),
		"late blocked sale rolls back earlier valid sale"
	)
	command = _group(bank, [_id(bank, "common1")])
	_ok(
		bank.commit(OwnershipFixtures.request(bank, "reward", {"game": 6, "win": false})),
		"change wallet after review"
	)
	_reject(bank, command, "stale group cannot settle")
	bank = _bank(false)
	_ok(
		bank.commit(
			OwnershipFixtures.request(bank, "stock", {"offers": {"a": "common1", "b": "common1"}})
		),
		"two offers for one identity"
	)
	_reject(
		bank,
		_group(bank, [], [_purchase("a"), _purchase("b")]),
		"second duplicate identity rolls back first purchase and both offers"
	)


func _other_capacity() -> void:
	var catalog: Dictionary = _catalog()
	catalog.common1["held_delta"] = 1
	var bank: SeasonOwnership = SeasonOwnership.new(catalog)
	_ok(
		bank.commit(OwnershipFixtures.request(bank, "reward", {"game": 0, "win": true})), "fund bag"
	)
	_ok(
		bank.commit(
			OwnershipFixtures.request(
				bank, "stock", {"offers": {"bag": "common1", "a": "card", "b": "card", "c": "card"}}
			)
		),
		"held capacity fixture"
	)
	for offer: String in ["bag", "a", "b", "c"]:
		_ok(bank.commit(OwnershipFixtures.buy(bank, offer)), "fill shared bag")
	_reject(bank, _group(bank, [_id(bank, "common1")]), "group cannot hide held overflow")
	_ok(
		bank.commit(
			OwnershipFixtures.request(bank, "discard", {"receipts": [bank.view().held[0].id]})
		),
		"separate explicit held resolution"
	)
	_ok(bank.commit(_group(bank, [_id(bank, "common1")])), "resolved held capacity permits sale")
	_check(bank.view().held.size() == 2 and bank.view().capacity.held == 2, "two owned held remain")
	bank = _bank(false)
	_ok(bank.commit(OwnershipFixtures.buy(bank, "capacity")), "rarity guard for ordinary path")
	_reject(bank, OwnershipFixtures.buy(bank, "uncommon"), "ordinary buy obeys peer restriction")
	_ok(bank.commit(OwnershipFixtures.buy(bank, "common1")), "ordinary compatible peer")
	_reject(
		bank,
		OwnershipFixtures.buy(bank, "uncommon", _id(bank, "common1")),
		"ordinary replacement cannot bypass peer restriction"
	)


func _persistence() -> void:
	var bank: SeasonOwnership = _bank()
	var command: Dictionary = _group(bank, [_id(bank, "capacity")], [_purchase("replacement", 4)])
	_ok(bank.commit(command), "persist group purchase")
	var data: Dictionary = JSON.parse_string(JSON.stringify(bank.to_data()))
	var restored: SeasonOwnership = SeasonOwnership.from_data(data, _catalog())
	_check(restored != null and restored.view() == bank.view(), "JSON replay exact state")
	if restored == null:
		return
	_ok(restored.commit(command), "restored retry idempotent")
	_check(restored.view() == bank.view(), "restored retry no additional charge")
	var changed: Dictionary = command.duplicate(true)
	changed.purchases[0].discount = 0
	_reject(restored, changed, "retry cannot change paid discount")
	var native_copy: SeasonOwnership = bank.fork()
	var json_command: Dictionary = JSON.parse_string(JSON.stringify(command))
	_ok(native_copy.commit(json_command), "JSON retry against native event is idempotent")
	var identity: String = SeasonSponsorSet.receipt_id(command.id, 0)
	_ok(
		restored.commit(_group(restored, [identity, _id(restored, "common1")])),
		"sell generated copy"
	)
	var collision: Dictionary = OwnershipFixtures.request(
		restored, "reward", {"game": 6, "win": true}
	)
	collision.id = identity
	_reject(restored, collision, "sold grouped identity cannot be reused as a normal request")
	var again: SeasonOwnership = SeasonOwnership.from_data(restored.to_data(), _catalog())
	_check(again != null and again.view() == restored.view(), "sale replay retains reserved ids")
	if again != null:
		_reject(again, collision, "identity reservation survives replay")
	var tampered: Dictionary = data.duplicate(true)
	tampered.events[-1].sales.clear()
	_check(
		SeasonOwnership.from_data(tampered, _catalog()) == null,
		"replay rejects omitted explicit sale and incompatible resulting peers"
	)
	# Preexisting request identity collision must fail before publishing the group.
	bank = _bank(false)
	command = _group(bank, [], [_purchase("common1")])
	identity = SeasonSponsorSet.receipt_id(command.id, 0)
	collision = OwnershipFixtures.request(bank, "reward", {"game": 6, "win": true})
	collision.id = identity
	_ok(bank.commit(collision), "existing request owns future derived identity")
	command.rev = bank.revision()
	_reject(bank, command, "generated receipt cannot collide with prior event identity")
