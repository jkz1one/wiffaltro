extends Node

var _failures: int = 0


func _ready() -> void:
	_transactions()
	_capacity()
	_sponsor_limits()
	_replay()
	if _failures == 0:
		print("Wiffaltro ownership checks passed: atomic transactions, capacity and replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _funded() -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new(OwnershipFixtures.catalog())
	_ok(
		bank.commit(OwnershipFixtures.request(bank, "reward", {"game": 0, "win": true})),
		"real reward rule"
	)
	_ok(
		bank.commit(
			OwnershipFixtures.request(
				bank,
				"stock",
				{
					"offers":
					{
						"a": "fixture.bat6",
						"b": "fixture.bat15",
						"c": "fixture.ball0",
						"d": "fixture.misc99",
						"e": "fixture.card",
						"f": "fixture.card",
						"g": "fixture.card",
						"h": "fixture.capacity",
						"i": "fixture.blocked",
						"j": "fixture.zero_sale"
					}
				}
			)
		),
		"fixture stock"
	)
	return bank


func _transactions() -> void:
	var bank: SeasonOwnership = _funded()
	var buy: Dictionary = OwnershipFixtures.buy(bank, "a")
	var original: String = JSON.stringify(bank.to_data())
	_check(bank.preview(buy).after.cash == 12, "preview shows full price")
	_check(JSON.stringify(bank.to_data()) == original, "cancelled preview changes nothing")
	_ok(bank.commit(buy), "purchase into empty slot")
	_check(bank.cash() == 12 and bank.view().gear.bat.paid == 6, "actual paid receipt")
	_ok(bank.commit(buy), "same request idempotent")
	_check(bank.cash() == 12, "retry never charges twice")
	var changed: Dictionary = buy.duplicate(true)
	changed.offer = "b"
	_reject(bank, changed, "reused transaction id cannot change meaning")
	_reject(bank, OwnershipFixtures.buy(bank, "b"), "replacement must be explicit")
	_reject(bank, OwnershipFixtures.buy(bank, "d"), "unaffordable purchase")
	_reject(bank, OwnershipFixtures.buy(bank, "c", buy.id), "wrong-slot replacement")
	var replacement: Dictionary = OwnershipFixtures.buy(bank, "b", buy.id)
	_ok(bank.commit(replacement), "sale proceeds can fund replacement")
	_check(bank.cash() == 0 and bank.view().gear.bat.paid == 15, "new full receipt not net charge")
	_check(bank.view().gear.bat.id == replacement.id, "exactly one equipped Bat")
	var sale: Dictionary = OwnershipFixtures.request(
		bank, "sell", {"receipt": replacement.id, "discard": []}
	)
	_ok(bank.commit(sale), "Gear sale")
	_check(bank.cash() == 7 and bank.view().gear.bat.is_empty(), "floor half and neutral fallback")
	_ok(bank.commit(sale), "sale retry")
	_check(bank.cash() == 7, "retry never doubles sale proceeds")
	var free: Dictionary = OwnershipFixtures.buy(bank, "c")
	_ok(bank.commit(free), "free Gear still creates a receipt")
	_ok(
		bank.commit(OwnershipFixtures.request(bank, "sell", {"receipt": free.id, "discard": []})),
		"free Gear sale"
	)
	_check(bank.cash() == 7, "free receipt has zero resale")
	var snapshot: Dictionary = bank.view()
	snapshot.cash = 5000
	snapshot.stock.clear()
	_check(bank.cash() == 7 and not bank.view().stock.is_empty(), "views cannot mutate ownership")
	_reject(
		bank,
		OwnershipFixtures.request(bank, "reward", {"game": 0, "win": false}),
		"one reward per fixture even under a new transaction id"
	)
	var stale: Dictionary = OwnershipFixtures.buy(bank, "j")
	_ok(
		bank.commit(OwnershipFixtures.request(bank, "reward", {"game": 1, "win": false})),
		"loss reward"
	)
	_reject(bank, stale, "stale preview cannot settle")
	var exception: Dictionary = OwnershipFixtures.buy(bank, "j")
	_ok(bank.commit(exception), "explicit zero-sale sponsor fixture")
	var before: int = bank.cash()
	_ok(
		bank.commit(
			OwnershipFixtures.request(bank, "sell", {"receipt": exception.id, "discard": []})
		),
		"exception sale"
	)
	_check(bank.cash() == before, "zero-sale exception does not become half-price")


func _capacity() -> void:
	var bank: SeasonOwnership = _funded()
	var first: Dictionary = OwnershipFixtures.buy(bank, "e")
	_ok(bank.commit(first), "first held slot")
	_ok(bank.commit(OwnershipFixtures.buy(bank, "f")), "second held slot")
	_reject(bank, OwnershipFixtures.buy(bank, "g"), "free grants cannot bypass full capacity")
	var sponsor: Dictionary = OwnershipFixtures.buy(bank, "h")
	_ok(bank.commit(sponsor), "capacity sponsor fixture")
	_ok(bank.commit(OwnershipFixtures.buy(bank, "g")), "third card with explicit capacity")
	_reject(
		bank,
		OwnershipFixtures.request(bank, "sell", {"receipt": sponsor.id, "discard": []}),
		"capacity-lowering sale cannot hide or delete a card"
	)
	_reject(
		bank,
		OwnershipFixtures.request(
			bank, "sell", {"receipt": sponsor.id, "discard": [first.id, first.id]}
		),
		"duplicate discard rollback"
	)
	_ok(
		bank.commit(
			OwnershipFixtures.request(bank, "sell", {"receipt": sponsor.id, "discard": [first.id]})
		),
		"explicit atomic capacity resolution"
	)
	_check(bank.view().held.size() == 2 and bank.view().capacity.held == 2, "no overflow storage")
	var blocked: Dictionary = OwnershipFixtures.buy(bank, "i")
	_ok(bank.commit(blocked), "unsupported-sale sponsor fixture")
	_reject(
		bank,
		OwnershipFixtures.request(bank, "sell", {"receipt": blocked.id, "discard": []}),
		"unimplemented sponsor sale contract stays gated"
	)


func _replay() -> void:
	var catalog: Dictionary = OwnershipFixtures.catalog()
	var bank: SeasonOwnership = _funded()
	_ok(bank.commit(OwnershipFixtures.buy(bank, "a")), "save fixture")
	var data: Dictionary = JSON.parse_string(JSON.stringify(bank.to_data()))
	var restored: SeasonOwnership = SeasonOwnership.from_data(data, catalog)
	_check(restored != null and restored.view() == bank.view(), "JSON replay preserves all state")
	_check(SeasonOwnership.from_data(data) == null, "unknown catalog cannot silently discard Gear")
	var changed_catalog: Dictionary = catalog.duplicate(true)
	changed_catalog["fixture.bat6"].price = 2
	_check(
		SeasonOwnership.from_data(data, changed_catalog) == null,
		"changed catalog cannot silently rewrite actual paid receipts"
	)
	data.events.append(data.events[-1].duplicate(true))
	_check(SeasonOwnership.from_data(data, catalog) == null, "duplicate saved purchase rejected")
	data = bank.to_data()
	data["spare_gear"] = ["fixture.bat15"]
	_check(SeasonOwnership.from_data(data, catalog) == null, "unknown ownership data fails closed")
	data = bank.to_data()
	data.events[-1]["paid"] = 0
	_check(SeasonOwnership.from_data(data, catalog) == null, "saved command cannot forge receipt")
	data = bank.to_data()
	data.events[0].win = "yes"
	_check(SeasonOwnership.from_data(data, catalog) == null, "malformed reward rejected")
	data = bank.to_data()
	data.events[0].rev = 0.5
	_check(SeasonOwnership.from_data(data, catalog) == null, "fractional revision rejected")


func _reject(bank: SeasonOwnership, command: Dictionary, label: String) -> void:
	var before: String = JSON.stringify(bank.to_data())
	var state: Dictionary = bank.view()
	_check(not bank.commit(command).ok, label)
	_check(JSON.stringify(bank.to_data()) == before and bank.view() == state, label + " is atomic")


func _ok(result: Dictionary, label: String) -> void:
	_check(result.ok, label + ": " + str(result.get("error", "")))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _sponsor_limits() -> void:
	var bank: SeasonOwnership = _funded()
	var offers: Dictionary = {}
	for index in range(6):
		offers["s%d" % index] = "fixture.sponsor%d" % index
	_ok(bank.commit(OwnershipFixtures.request(bank, "stock", {"offers": offers})), "sponsor stock")
	var first: String = ""
	for index in range(5):
		var command: Dictionary = OwnershipFixtures.buy(bank, "s%d" % index)
		if index == 0:
			first = command.id
		_ok(bank.commit(command), "active sponsor slot")
	_reject(bank, OwnershipFixtures.buy(bank, "s5"), "sixth sponsor cannot enter reserve")
	_ok(bank.commit(OwnershipFixtures.buy(bank, "s5", first)), "explicit sponsor replacement")
	_check(bank.view().sponsors.size() == 5, "exactly five active sponsors")
	_reject(
		bank,
		OwnershipFixtures.request(bank, "stock", {"offers": {"s0": "fixture.card"}}),
		"previously consumed offer cannot be resurrected"
	)
