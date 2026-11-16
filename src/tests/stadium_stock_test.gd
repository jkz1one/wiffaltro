extends Node
## Synthetic ownership/price proposal only. No user career is charged or migrated.

var _failures: int = 0


func _ready() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	_check(stock.blueprints == StadiumCatalog.STARTERS and stock.copies.size() == 3,
		"exact three starter types and individual copies, no lights or spectator seats")
	var initial: Dictionary = stock.to_data()
	_check(StadiumStock.from_data(initial).to_data() == initial, "new-club grant roundtrip")
	var progress: Dictionary = {"seasons": 30, "wins": 100, "strikeouts": 300,
		"hits": 200, "homers": 50}
	var quote: Dictionary = stock.quote("ST-041", 2, progress, "sign")
	_check(quote.ok and quote.cost == 150 and quote.blueprint_cost == 100 and quote.copy_cost == 50,
		"blueprint once plus two distinct copies")
	_check(stock.to_data() == initial, "quote/cancel does not mutate ownership")
	var next: StadiumStock = StadiumStock.from_data(quote.state)
	_check(next != null and next.copies.size() == 5, "candidate retains all starter copies")
	quote = next.quote("ST-041", 1, progress, "another-sign")
	_check(quote.ok and quote.cost == 25 and quote.blueprint_cost == 0,
		"existing blueprint never charged again")
	_check(not next.quote("ST-041", 2, progress, "sign").ok, "copy receipt cannot be duplicated")
	quote = next.quote("ST-001", 1, {}, "extra-cone")
	_check(quote.ok and quote.cost == 40, "extra starter copy has ordinary paid price")
	quote = next.quote("ST-062a", 1, progress, "chalk")
	_check(quote.ok and quote.cost == 115 and quote.style_cost == 115,
		"style is one entitlement, not blueprint-plus-copy")
	var style: StadiumStock = StadiumStock.from_data(quote.state)
	_check(style != null and style.copies.size() == next.copies.size()
		and not style.quote("ST-062a", 1, progress, "again").ok, "no repeat style purchase")
	_check(not next.quote("ST-044", 1, progress, "pennant").ok, "championship history not sold")
	_check(not next.quote("ST-006", 1, {}, "pool").ok, "locked identity cannot be acquired")
	_check(not next.quote("ST-041", 0, progress, "zero").ok, "no zero-count purchase")
	var legacy: StadiumStock = StadiumStock.new()
	_check(StadiumStock.from_data(legacy.to_data()) != null and legacy.copies.is_empty(),
		"ambiguous prior club stays unresolved, with no invented grant or debit")
	_check(not legacy.quote("ST-001", 1, progress, "legacy").ok,
		"starter reconciliation is explicit before a starter-copy purchase")
	legacy.blueprints.append("ST-001")
	legacy.copies["purchase:old-cone:0"] = {"item": "ST-001", "paid": 40, "source": "purchase-v1"}
	var legacy_before: Dictionary = legacy.to_data()
	var grant: Dictionary = legacy.starter_quote()
	_check(grant.ok and grant.cost == 0 and not grant.replayed
		and legacy.to_data() == legacy_before, "legacy grant is inert until atomic owner commit")
	var granted: StadiumStock = StadiumStock.from_data(grant.state)
	_check(granted != null and granted.copies.size() == 4
		and granted.copies["purchase:old-cone:0"].paid == 40,
		"old paid cone preserved; one separate starter cone, lawn chair and backstop chair")
	_check(granted.starter_quote().replayed and granted.starter_quote().state == grant.state,
		"recorded starter grant never duplicates on reload/restart")
	for change: String in ["copy", "price", "blueprint", "catalog", "source"]:
		var bad: Dictionary = initial.duplicate(true)
		match change:
			"copy": bad.copies.erase("starter-v1:ST-001")
			"price": bad.copies["starter-v1:ST-001"].paid = 40
			"blueprint": bad.blueprints.erase("ST-001")
			"catalog": bad.catalog = "unknown"
			"source": bad.copies["starter-v1:ST-001"].source = "template"
		_check(StadiumStock.from_data(bad) == null, "reject altered ownership " + change)
	_check(not quote.placement_verified, "ownership does not prove collision or placement readiness")
	if _failures == 0:
		print("Wiffaltro stadium stock checks passed: "
			+ "starter copies, inert quotes and preserved ownership.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
