class_name SeasonInventoryResale
extends RefCounted
## Explicit v1 operations preserve every legacy catalog fingerprint and sale contract.
## The Build aggregate validates live grant/use evidence; this ledger owns value and identity.

const RULE: String = "inventory-sales-v1"
const ENABLE_OP: String = "inventory_rules_v1"
const SALE_OP: String = "inventory_sale_v1"
const FIELD_OP: String = "field_sale_v1"
const NORMAL_VALUES: Dictionary = {"A10": 3, "C03": 3, "C02": 4, "tactical.extra_heat": 5}


static func enabled(bank: SeasonOwnership) -> bool:
	return bank != null and bank._state.get("inventory_rules") == RULE


static func enable(next: Dictionary, command: Dictionary) -> String:
	if not SeasonOwnership._keys(command, ["id", "rev", "op"]) or next.has("inventory_rules"):
		return "Inventory sale rules require one explicit migration."
	next["inventory_rules"] = RULE
	return ""


static func quote(bank: SeasonOwnership, receipt: String) -> Dictionary:
	if not enabled(bank):
		return _failure("This save has not enabled inventory sale rules v1.")
	var owned: Dictionary = SeasonOwnership._owned(bank.view(), receipt)
	if owned.is_empty():
		return _failure("This copy is no longer owned.")
	if owned.get("kind") != "held":
		var item: Dictionary = bank._catalog.get(owned.get("item"), {})
		if item.is_empty() or item.get("sale") == "blocked":
			return _failure("This item's sale contract is not supported.")
		var refund: int = int(owned.paid / 2) if item.sale == "half" else 0
		if (
			owned.kind == "sponsor"
			and (bank.sponsor_terms_valid() or bank.d4_sponsors_valid())
		):
			refund = SeasonSponsorCatalog.resale(owned) if item.sale == "half" else 0
		return {"ok": true, "refund": refund, "basis": owned.paid, "source": "purchased"}
	var origin: Dictionary = acquisition(bank, receipt)
	if origin.is_empty():
		return _failure("This copy has no valid acquisition provenance.")
	if origin.op in ["buy", "tactical_exchange"]:
		var acquired: Dictionary = _purchased_receipt(bank, receipt)
		if acquired.is_empty() or acquired.item != owned.item or acquired.paid != owned.paid:
			return _failure("The purchased copy differs from its acquisition receipt.")
		return {
			"ok": true, "refund": int(owned.paid / 2), "basis": owned.paid, "source": "purchased"
		}
	if owned.paid != 0 or not _generated_matches(origin, owned):
		return _failure("The generated copy's acquisition changed.")
	var basis: int = normal_value(bank, owned.item)
	if basis < 0:
		return _failure("This generated copy has no supported reference value.")
	return {"ok": true, "refund": int(basis / 2), "basis": basis, "source": "generated"}


static func acquisition(bank: SeasonOwnership, receipt: String) -> Dictionary:
	for event: Dictionary in bank._events:
		if event.get("id") == receipt:
			return event.duplicate(true)
	return {}


static func normal_value(bank: SeasonOwnership, item: String) -> int:
	if not NORMAL_VALUES.has(item):
		return -1
	var catalog: Dictionary = bank._catalog.get(item, {})
	# A future price table requires a new operation version, not a changed old refund.
	if catalog.get("kind") != "held" or catalog.get("price") != NORMAL_VALUES[item]:
		return -1
	return int(NORMAL_VALUES[item])


static func field_quote(bank: SeasonOwnership) -> Dictionary:
	if not enabled(bank):
		return _failure("This save has not enabled inventory sale rules v1.")
	var basis: int = normal_value(bank, "A10")
	return (
		_failure("Unsupported generated Tape value.")
		if basis < 0
		else {"ok": true, "refund": int(basis / 2), "basis": basis, "source": "generated"}
	)


static func field_retired(bank: SeasonOwnership, game: int) -> bool:
	var receipt: String = SeasonFieldGrant.receipt(game)
	for event: Dictionary in bank._events:
		if event.get("op") == FIELD_OP and event.get("game") == game:
			return true
		if event.get("op") == SALE_OP and event.get("receipt") == receipt:
			return true
	return false


static func apply(bank: SeasonOwnership, next: Dictionary, command: Dictionary) -> String:
	if not enabled(bank):
		return "This save has not enabled inventory sale rules v1."
	if (
		not SeasonOwnership._keys(command, ["id", "rev", "op", "receipt"])
		or not command.get("receipt") is String
	):
		return "Review an exact owned receipt; sale prices are derived."
	var owned: Dictionary = SeasonOwnership._owned(next, command.receipt)
	if owned.is_empty():
		return "This copy is no longer owned."
	if owned.kind != "held":
		return bank._sell(next, command.receipt)
	var result: Dictionary = quote(bank, command.receipt)
	if not result.ok:
		return result.error
	next.cash += int(result.refund)
	next.held.erase(owned)
	return ""


static func apply_field(bank: SeasonOwnership, next: Dictionary, command: Dictionary) -> String:
	if not enabled(bank):
		return "This save has not enabled inventory sale rules v1."
	if (
		not SeasonOwnership._keys(command, ["id", "rev", "op", "game"])
		or not SeasonOwnership._whole(command.get("game"), 0, 32)
	):
		return "Review the exact generated Tape fixture; its value is derived."
	var receipt: String = SeasonFieldGrant.receipt(int(command.game))
	if (
		command.id == receipt
		or bank._requests.has(receipt)
		or field_retired(bank, int(command.game))
		or next.rewards.has(str(int(command.game)))
	):
		return "This fixture's generated Tape was already acquired, retired or settled."
	var result: Dictionary = field_quote(bank)
	if not result.ok:
		return result.error
	# No transient held copy is inserted: Cash and the reserved identity commit together.
	next.cash += int(result.refund)
	return ""


static func _purchased_receipt(bank: SeasonOwnership, receipt: String) -> Dictionary:
	# Reconstruct only acquisition metadata, not whole banks or sale-prefix recursion.
	var stock: Dictionary = {}
	var copies: Dictionary = {}
	for event: Dictionary in bank._events:
		match event.get("op"):
			"stock":
				stock = event.offers.duplicate(true)
			"buy", "spare_buy":
				var item: String = str(stock.get(event.offer, ""))
				if bank._catalog.has(item):
					copies[event.id] = {
						"item": item,
						"paid":
						(
							int(bank._catalog[item].price)
							- int(event.get("wholesale_discount", event.get("discount", 0)))
						)
					}
				stock.erase(event.offer)
			"budget_grant":
				copies[event.id] = {"item": "C03", "paid": 0}
			"field_grant":
				copies[event.id] = {"item": "A10", "paid": 0}
			"insurance_grant":
				copies[event.id] = {"item": event.item, "paid": 0}
			"tactical_exchange":
				var source: Dictionary = copies.get(event.receipt, {})
				if not source.is_empty():
					copies[event.id] = {
						"item": event.item,
						"paid": SeasonTacticalExchange.cost(source.item, event.item)
					}
		if event.get("id") == receipt:
			return copies.get(receipt, {})
	return {}


static func _generated_matches(origin: Dictionary, owned: Dictionary) -> bool:
	match origin.get("op"):
		"budget_grant":
			return owned.item == "C03" and _fixture_identity(owned.id, "budget:")
		"insurance_grant":
			return (
				owned.item == origin.get("item")
				and SeasonSecondChance.ELIGIBLE.has(owned.item)
				and _fixture_identity(owned.id, "insurance:")
			)
		"field_grant":
			return (
				owned.item == "A10"
				and SeasonOwnership._whole(origin.get("game"), 0, 32)
				and owned.id == SeasonFieldGrant.receipt(int(origin.game))
			)
	return false


static func _fixture_identity(receipt: String, prefix: String) -> bool:
	if not receipt.begins_with(prefix):
		return false
	var value: String = receipt.trim_prefix(prefix)
	return (
		value.is_valid_int() and int(value) >= 0 and int(value) <= 32 and value == str(int(value))
	)


static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}
