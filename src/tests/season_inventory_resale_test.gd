extends Node
## Synthetic ledger fixtures. Live earned-grant and consumption admission belong to Build tests.

var checks: int = 0
var failures: int = 0


func _ready() -> void:
	_legacy_and_migration()
	_purchased_supplies()
	_generated_supplies()
	_provenance_negatives()
	_wholesale_and_named_purchases()
	_field_atomic_retirement()
	_spare_and_contracts()
	print("Inventory resale ledger checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _request(bank: SeasonOwnership, op: String, fields: Dictionary = {}) -> Dictionary:
	return OwnershipFixtures.request(bank, op, fields)


func _bank(migrate: bool = true, equipment: bool = false) -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	if equipment:
		check(
			bank.enable_league_rules(LeagueRules.capture("equipment")), "closed Equipment fixture"
		)
	for game: int in range(7):
		check(
			bank.commit(_request(bank, "reward", {"game": game, "win": true})).ok,
			"synthetic fixture funding"
		)
	if migrate:
		check(
			bank.commit(_request(bank, SeasonInventoryResale.ENABLE_OP)).ok, "explicit v1 migration"
		)
	return bank


func _buy(bank: SeasonOwnership, item: String, discount: int = 0, spare: bool = false) -> String:
	var offer: String = "resale-offer:%d" % bank.revision()
	check(bank.commit(_request(bank, "stock", {"offers": {offer: item}})).ok, "stock exact item")
	var command: Dictionary = _request(
		bank, "spare_buy" if spare else "buy", {"offer": offer, "replace": "", "discard": []}
	)
	if discount > 0:
		command["discount"] = discount
	check(bank.commit(command).ok, "purchase exact copy " + item)
	return command.id


func _sell(bank: SeasonOwnership, receipt: String) -> Dictionary:
	return bank.commit(_request(bank, SeasonInventoryResale.SALE_OP, {"receipt": receipt}))


func _cold(bank: SeasonOwnership) -> SeasonOwnership:
	var restored: SeasonOwnership = SeasonOwnership.from_data(
		JSON.parse_string(JSON.stringify(bank.to_data())), bank._catalog
	)
	check(restored != null, "cold JSON ledger replay")
	if restored != null:
		check(restored.view() == bank.view(), "cold replay preserves balances and exact copies")
	return restored


func _legacy_and_migration() -> void:
	var bank: SeasonOwnership = _bank(false)
	var receipt: String = _buy(bank, "A10")
	var old: Dictionary = bank.to_data()
	check(not _sell(bank, receipt).ok, "legacy save cannot silently admit new sale operation")
	check(
		not bank.commit(_request(bank, "sell", {"receipt": receipt, "discard": []})).ok,
		"legacy held sale contract unchanged"
	)
	check(bank.to_data() == old, "failed new operation leaves legacy journal unchanged")
	var restored: SeasonOwnership = _cold(bank)
	check(
		restored != null and not SeasonInventoryResale.enabled(restored),
		"legacy replay stays unmigrated"
	)
	check(
		bank.commit(_request(bank, SeasonInventoryResale.ENABLE_OP)).ok,
		"explicit checkpoint migration"
	)
	check(
		not bank.commit(_request(bank, SeasonInventoryResale.ENABLE_OP)).ok,
		"migration cannot repeat"
	)
	check(bank.to_data().catalog == old.catalog, "migration never changes catalog fingerprint")
	check(
		bank.to_data().events.slice(0, old.events.size()) == old.events,
		"legacy event prefix unchanged"
	)
	check(_sell(bank, receipt).ok, "existing unused copy becomes sellable only after migration")
	_cold(bank)


func _purchased_supplies() -> void:
	for item: String in [
		"A10", "C02", "C03", "tactical.extra_heat", "tactical.take_base", "development.contact"
	]:
		var bank: SeasonOwnership = _bank()
		var receipt: String = _buy(bank, item)
		var owned: Dictionary = SeasonOwnership._owned(bank.view(), receipt)
		var quote: Dictionary = SeasonInventoryResale.quote(bank, receipt)
		var before: Dictionary = bank.to_data()
		check(
			quote.ok and quote.source == "purchased" and quote.refund == int(owned.paid / 2),
			"purchased actual-paid half, floor odd prices " + item
		)
		check(bank.to_data() == before, "quote is mutation-free")
		var cash: int = bank.cash()
		var revision: int = bank.revision()
		var command: Dictionary = _request(
			bank, SeasonInventoryResale.SALE_OP, {"receipt": receipt}
		)
		var spoof: Dictionary = command.duplicate(true)
		spoof["basis"] = 999
		check(not bank.commit(spoof).ok, "caller cannot set basis")
		check(bank.commit(command).ok and bank.cash() == cash + int(owned.paid / 2), "exact refund")
		check(bank.revision() == revision + 1, "one bank event per sale")
		check(
			(
				bank.commit(command).get("replayed", false)
				and bank.cash() == cash + int(owned.paid / 2)
			),
			"same request replay does not pay twice"
		)
		check(not _sell(bank, receipt).ok, "new request cannot resell retired copy")
		_cold(bank)
	var bank: SeasonOwnership = _bank()
	var discounted: String = _buy(bank, "C02", 3)
	check(
		SeasonInventoryResale.quote(bank, discounted).refund == 0,
		"discounted paid1 rounds down to0"
	)
	check(_sell(bank, discounted).ok, "discounted unused supply sells")
	var free_purchase: String = _buy(bank, "A10", 3)
	var quote: Dictionary = SeasonInventoryResale.quote(bank, free_purchase)
	check(
		quote.ok and quote.source == "purchased" and quote.basis == 0 and quote.refund == 0,
		"zero-paid purchase is not a generated grant"
	)
	check(_sell(bank, free_purchase).ok, "zero-paid purchase can still be removed")
	_cold(bank)


func _generated_supplies() -> void:
	for item: String in SeasonSecondChance.ELIGIBLE:
		var bank: SeasonOwnership = _bank()
		var command: Dictionary = _request(bank, "insurance_grant", {"item": item})
		command.id = "insurance:8"
		check(bank.commit(command).ok, "synthetic completed insurance grant " + item)
		var owned: Dictionary = SeasonOwnership._owned(bank.view(), command.id)
		var quote: Dictionary = SeasonInventoryResale.quote(bank, command.id)
		check(
			(
				owned.paid == 0
				and quote.ok
				and quote.source == "generated"
				and quote.basis == SeasonInventoryResale.NORMAL_VALUES[item]
				and quote.refund == int(SeasonInventoryResale.NORMAL_VALUES[item] / 2)
			),
			"generated normal reference half without fabricated purchase cost " + item
		)
		check(_sell(bank, command.id).ok, "unused insurance replacement sells")
		_cold(bank)
	var field: SeasonOwnership = _bank()
	var grant: Dictionary = _request(field, "field_grant", {"game": 8})
	grant.id = SeasonFieldGrant.receipt(8)
	check(field.commit(grant).ok, "synthetic settled Field grant")
	check(SeasonInventoryResale.quote(field, grant.id).refund == 1, "owned generated Tape refunds1")
	check(
		_sell(field, grant.id).ok and SeasonInventoryResale.field_retired(field, 8),
		"owned generated Tape retirement remains discoverable"
	)
	_cold(field)
	var budget: SeasonOwnership = _bank()
	_buy(budget, "E08")
	check(
		budget.commit(_request(budget, "charge", {"amount": budget.cash() - 4})).ok,
		"Budget threshold fixture"
	)
	var budget_grant: Dictionary = _request(budget, "budget_grant")
	budget_grant.id = "budget:8"
	check(budget.commit(budget_grant).ok, "exact Budget grant")
	check(
		SeasonInventoryResale.quote(budget, budget_grant.id).refund == 1, "generated Plan refunds1"
	)
	check(_sell(budget, budget_grant.id).ok, "Budget unused copy sells")
	_cold(budget)
	var forged: SeasonOwnership = _bank()
	var wrong: Dictionary = _request(forged, "insurance_grant", {"item": "A10"})
	wrong.id = "ordinary-copy"
	check(forged.commit(wrong).ok, "legacy internal grant accepts synthetic identity")
	check(
		not SeasonInventoryResale.quote(forged, wrong.id).ok and not _sell(forged, wrong.id).ok,
		"unsupported generated identity is not a price authority"
	)


func _provenance_negatives() -> void:
	var bank: SeasonOwnership = _bank()
	var receipt: String = _buy(bank, "C02", 1)
	var wrong_paid: SeasonOwnership = bank.fork()
	wrong_paid._state.held[0].paid = 100
	check(
		not SeasonInventoryResale.quote(wrong_paid, receipt).ok,
		"altered paid is not acquisition authority"
	)
	var wrong_item: SeasonOwnership = bank.fork()
	wrong_item._state.held[0].item = "tactical.extra_heat"
	check(not SeasonInventoryResale.quote(wrong_item, receipt).ok, "altered owned item is rejected")
	for prefix: String in ["budget:", "insurance:", "field-supply:"]:
		var renamed: SeasonOwnership = bank.fork()
		renamed._state.held[0].id = prefix + "8"
		check(
			not SeasonInventoryResale.quote(renamed, prefix + "8").ok,
			"renaming a purchased receipt cannot invent grant provenance " + prefix
		)
	var exchange: Dictionary = _request(
		bank, "tactical_exchange", {"receipt": receipt, "item": "tactical.extra_heat"}
	)
	check(bank.commit(exchange).ok, "synthetic exact tactical exchange")
	var quote: Dictionary = SeasonInventoryResale.quote(bank, exchange.id)
	check(
		quote.ok and quote.source == "purchased" and quote.basis == 1 and quote.refund == 0,
		"exchange refunds only actual new receipt charge, not inherited investment"
	)
	check(_sell(bank, exchange.id).ok, "exchanged unused receipt sells")
	_cold(bank)


func _wholesale_and_named_purchases() -> void:
	var bank: SeasonOwnership = _bank()
	check(
		bank.commit(_request(bank, "stock", {"offers": {"wholesale-resale": "C02"}})).ok,
		"stock Wholesale receipt fixture"
	)
	var purchase: Dictionary = _request(
		bank,
		"buy",
		{"offer": "wholesale-resale", "replace": "", "discard": [], "wholesale_discount": 1}
	)
	check(bank.commit(purchase).ok, "actual Wholesale-discount acquisition")
	var quote: Dictionary = SeasonInventoryResale.quote(bank, purchase.id)
	check(
		quote.ok and quote.source == "purchased" and quote.basis == 3 and quote.refund == 1,
		"Wholesale uses actual discounted receipt, rounding down"
	)
	check(_sell(bank, purchase.id).ok, "Wholesale unused copy sells")
	for prefix: String in ["budget:", "insurance:", "field-supply:"]:
		var named: SeasonOwnership = _bank()
		check(
			named.commit(_request(named, "stock", {"offers": {"named-purchase": "A10"}})).ok,
			"stock misleading receipt-name fixture"
		)
		var command: Dictionary = _request(
			named, "buy", {"offer": "named-purchase", "replace": "", "discard": [], "discount": 3}
		)
		command.id = prefix + "8"
		check(named.commit(command).ok, "synthetic purchased receipt has grant-looking name")
		var result: Dictionary = SeasonInventoryResale.quote(named, command.id)
		check(
			result.ok and result.source == "purchased" and result.refund == 0,
			"exact buy provenance beats misleading receipt prefix " + prefix
		)
		check(_sell(named, command.id).ok, "misleading name cannot inflate refund")
		_cold(named)


func _field_atomic_retirement() -> void:
	var bank: SeasonOwnership = _bank()
	var command: Dictionary = _request(bank, SeasonInventoryResale.FIELD_OP, {"game": 8})
	var before: Dictionary = bank.to_data()
	var cash: int = bank.cash()
	var revision: int = bank.revision()
	var quote: Dictionary = SeasonInventoryResale.field_quote(bank)
	check(
		quote.ok and quote.refund == 1 and bank.to_data() == before,
		"generated value quote does not mutate"
	)
	check(
		bank.preview(command).ok and bank.to_data() == before,
		"generated quote/cancel do not mutate"
	)
	var spoof: Dictionary = command.duplicate(true)
	spoof["item"] = "tactical.extra_heat"
	check(not bank.commit(spoof).ok, "runtime grant item cannot be spoofed")
	check(bank.commit(command).ok and bank.cash() == cash + 1, "grouped runtime Tape sale")
	check(
		bank.revision() == revision + 1 and bank.view().held.is_empty(),
		"one event, no transient or carried copy"
	)
	check(SeasonInventoryResale.field_retired(bank, 8), "fixture retirement recorded")
	check(
		(
			bank.commit(command).get("replayed", false)
			and bank.cash() == cash + 1
			and bank.revision() == revision + 1
		),
		"same grouped Field request retry cannot repay"
	)
	check(
		not bank.commit(_request(bank, SeasonInventoryResale.FIELD_OP, {"game": 8})).ok,
		"fresh request cannot farm same generated fixture"
	)
	var restored: SeasonOwnership = _cold(bank)
	if restored == null:
		return
	check(SeasonInventoryResale.field_retired(restored, 8), "cold restart keeps fixture retirement")
	var grant: Dictionary = _request(restored, "field_grant", {"game": 8})
	grant.id = SeasonFieldGrant.receipt(8)
	check(not restored.commit(grant).ok, "reserved receipt cannot be regranted after sale")
	check(
		not restored.commit(_request(restored, SeasonInventoryResale.FIELD_OP, {"game": 8})).ok,
		"cold restart cannot repay"
	)
	check(
		not restored.commit(_request(restored, SeasonInventoryResale.FIELD_OP, {"game": 0})).ok,
		"completed fixture cannot mint runtime Tape sale"
	)


func _spare_and_contracts() -> void:
	var bank: SeasonOwnership = _bank(true, true)
	var active: String = _buy(bank, "BAT-CON-01")
	var spare: String = _buy(bank, "BAT-POW-01", 0, true)
	var gear: Dictionary = bank.view().gear.duplicate(true)
	var evidence: Array = SeasonReclamation.receipts(bank.view())
	check(_sell(bank, spare).ok and bank.view().spare.is_empty(), "inactive spare sells")
	check(
		(
			bank.view().gear == gear
			and SeasonReclamation.receipts(bank.view()) == evidence
			and bank.view().gear.bat.id == active
		),
		"spare sale preserves active exact receipt and evidence"
	)
	_cold(bank)
	var catalog: Dictionary = OwnershipFixtures.catalog()
	var contracts: SeasonOwnership = SeasonOwnership.new(catalog)
	check(
		contracts.commit(_request(contracts, "reward", {"game": 0, "win": true})).ok,
		"contract funding"
	)
	check(
		contracts.commit(_request(contracts, SeasonInventoryResale.ENABLE_OP)).ok,
		"contract migration"
	)
	var locked: String = _buy(contracts, "fixture.blocked")
	var zero: String = _buy(contracts, "fixture.zero_sale")
	check(not _sell(contracts, locked).ok, "authored blocked contract preserved")
	var cash: int = contracts.cash()
	check(
		_sell(contracts, zero).ok and contracts.cash() == cash,
		"authored zero-refund contract preserved"
	)
	_cold(contracts)
