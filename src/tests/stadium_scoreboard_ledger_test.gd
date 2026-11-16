extends Node
## Journal-only paid ownership; new physical board placement remains separately gated.

var _failures: int = 0
var _credits: Array = []
var _progress: Array = []


func _ready() -> void:
	for index in range(22):
		_credits.append(100000)
		_progress.append({"seasons": 1, "wins": 4})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(21, _credits, _progress)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var frozen_key: String = StadiumLayoutSnapshot.key(snapshot)
	for id: String in StadiumScoreboardCatalog.IDS:
		var before: Dictionary = _state(ledger)
		var command: Dictionary = _buy(ledger, id, 2)
		var quote: Dictionary = ledger.preview(command)
		var price: Dictionary = StadiumScoreboardCatalog.item(id)
		_check(quote.ok and ClubCareer.same(before, _state(ledger)), "preview is fully detached")
		_check(ledger.commit(command).ok
			and ledger.balance() == before.balance - price.blueprint_price - 2 * price.copy_price,
			"one shared wallet pays exact blueprint and copies")
		before = _state(ledger)
		_check(ledger.commit(command).replayed and ClubCareer.same(before, _state(ledger)),
			"same journal request replays without another charge or grant")
		var changed: Dictionary = command.duplicate(true)
		changed.quantity = 1
		_check(not ledger.commit(changed).ok and ClubCareer.same(before, _state(ledger)),
			"reused request with changed quantity rejects atomically")
		_check(ledger.commit(_buy(ledger, id, 1)).ok
			and ledger.balance() == before.balance - price.copy_price,
			"repeat purchase pays only another physical copy")
	_check(ledger.construction().copies.size() == 9 and ledger.scoreboards().copies.size() == 3,
		"standard manual/video ownership and electronic extension remain distinct")
	var detached: StadiumScoreboardOwnership = ledger.scoreboards()
	detached.copies.clear()
	_check(ledger.scoreboards().copies.size() == 3, "extension reads cannot mutate ledger")
	var restored: ClubAssetLedger = _restore(ledger.to_data())
	_check(restored != null and ClubCareer.same(_state(restored), _state(ledger)),
		"JSON replay restores exact shared spending and all ownership")
	_check(StadiumLayoutSnapshot.key(snapshot) == frozen_key
		and StadiumLayoutSnapshot.matches(snapshot, ledger),
		"later stored board purchases leave old frozen snapshot key and prefix valid")
	_rejections(ledger)
	_migration()
	_capacity()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro scoreboard ledger passed: shared wallet, immutable history and capacity.")
	get_tree().quit(0 if _failures == 0 else 1)


func _rejections(ledger: ClubAssetLedger) -> void:
	var before: Dictionary = _state(ledger)
	for field: String in ["price_version", "through", "progress_through", "rev", "item", "quantity"]:
		var command: Dictionary = _buy(ledger, "ST-090", 1)
		match field:
			"price_version": command.price_version = 2
			"through": command.through = 0
			"progress_through": command.progress_through -= 1
			"rev": command.rev -= 1
			"item": command.item = "ST-041"
			"quantity": command.quantity = 9223372036854775807
		_check(not ledger.commit(command).ok and ClubCareer.same(before, _state(ledger)),
			"bad/stale command preserves every ledger component: " + field)
	var poor_credits: Array = []
	poor_credits.resize(22)
	poor_credits.fill(1)
	var poor: ClubAssetLedger = ClubAssetLedger.new(21, poor_credits, _progress)
	var poor_before: Dictionary = _state(poor)
	_check(not poor.commit(_buy(poor, "ST-090", 1)).ok
		and ClubCareer.same(poor_before, _state(poor)) and poor.scoreboards().blueprints.is_empty(),
		"insufficient funds grants neither blueprint nor copy")
	for invalid: String in ["missing", "wrong"]:
		var data: Dictionary = ledger.to_data()
		if invalid == "missing":
			data.erase("scoreboard_catalog")
		else:
			data.scoreboard_catalog = "forged"
		_check(_restore(data) == null, "current header requires the exact scoreboard contract")


func _migration() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(21, _credits, _progress)
	_check(ledger.commit(_old_buy(ledger, "ST-039", 1, 3)).ok, "populate old manual ownership")
	_check(ledger.commit(_wall(ledger, 1)).ok, "populate old wall-piece ownership")
	var frozen: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var key: String = StadiumLayoutSnapshot.key(frozen)
	var old: Dictionary = ledger.to_data()
	old.version = 19
	old.erase("scoreboard_catalog")
	old.erase("scoreboard_layout_catalog")
	old.erase("mounted_scoreboard_layout_catalog")
	old.erase("pool_catalog")
	old.erase("pool_layout_catalog")
	var migrated: ClubAssetLedger = _restore(old)
	_check(migrated != null and migrated.scoreboards().copies.is_empty()
		and migrated.scoreboards().blueprints.is_empty()
		and ClubCareer.same(_state(migrated), _state(ledger)),
		"populated ledger19 migrates without a grant, charge or changed layout")
	_check(StadiumLayoutSnapshot.matches(frozen, migrated)
		and StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.capture(migrated)) == key,
		"migration preserves exact old snapshot capture and paid-prefix match")
	_check(migrated.commit(_buy(migrated, "ST-090", 1)).ok, "explicit post-migration electronic buy")
	old.events = migrated.to_data().events
	_check(_restore(old) == null, "valid old header rejects newer scoreboard events")
	_check(StadiumLayoutSnapshot.matches(frozen, migrated)
		and StadiumLayoutSnapshot.key(frozen) == key,
		"stored electronic extension does not rewrite historical snapshots")
	var before: int = migrated.balance()
	_check(migrated.commit(_buy(migrated, "ST-039", 1)).ok
		and migrated.balance() == before - 100,
		"legacy manual blueprint is not charged again by the new operation")
	before = migrated.balance()
	_check(migrated.commit(_old_buy(migrated, "ST-039", 1, 3)).ok
		and migrated.balance() == before - 100,
		"new-route ownership remains usable through the historic operation")
	var cross: Dictionary = _buy(ledger, "ST-090", 1)
	cross.id = ledger.to_data().events[0].id
	_check(not ledger.commit(cross).ok, "legacy and scoreboard operations share request identity")


func _capacity() -> void:
	for order: Array in [["standard", "electronic", "wall"], ["electronic", "standard", "wall"],
		["wall", "standard", "electronic"], ["electronic", "wall", "standard"]]:
		var ledger: ClubAssetLedger = ClubAssetLedger.new(21, _credits, _progress)
		var electronic_request: Dictionary = {}
		for kind: String in order:
			var command: Dictionary = _old_buy(ledger, "ST-001", 4091, 1) if kind == "standard" \
				else _buy(ledger, "ST-090", 1) if kind == "electronic" else _wall(ledger, 1)
			_check(ledger.commit(command).ok, "each purchase order reaches combined4096")
			if kind == "electronic":
				electronic_request = command
		var before: Dictionary = _state(ledger)
		_check(ledger.commit(electronic_request).replayed
			and ClubCareer.same(before, _state(ledger)), "exact retry succeeds at full capacity")
		for command: Dictionary in [_old_buy(ledger, "ST-001", 1, 1), _wall(ledger, 1),
			_buy(ledger, "ST-039", 1), _buy(ledger, "ST-040", 1), _buy(ledger, "ST-090", 1)]:
			_check(not ledger.commit(command).ok and ClubCareer.same(before, _state(ledger)),
				"all purchase directions reject combined4097 without mutation")
		var loaded: ClubAssetLedger = _restore(ledger.to_data())
		_check(loaded != null and ClubCareer.same(_state(loaded), before),
			"interleaved full-capacity journal round-trips")


func _buy(ledger: ClubAssetLedger, id: String, quantity: int) -> Dictionary:
	return {"id": "board-%d" % ledger.revision(), "rev": ledger.revision(),
		"op": "stadium_scoreboard", "through": 22, "progress_through": 22,
		"price_version": StadiumScoreboardPurchases.VERSION, "item": id, "quantity": quantity}


func _old_buy(ledger: ClubAssetLedger, id: String, quantity: int, price: int) -> Dictionary:
	var result: Dictionary = _buy(ledger, id, quantity)
	result.id = "standard-%d" % ledger.revision()
	result.op = "stadium_buy"
	result.price_version = price
	if price == 1:
		result.erase("progress_through")
	return result


func _wall(ledger: ClubAssetLedger, quantity: int) -> Dictionary:
	var result: Dictionary = _buy(ledger, "ST-024-L", quantity)
	result.id = "wall-%d" % ledger.revision()
	result.op = "stadium_wall_piece"
	return result


func _state(ledger: ClubAssetLedger) -> Dictionary:
	return {"balance": ledger.balance(), "view": ledger.view(),
		"stock": ledger.construction().to_data(), "walls": ledger.wall_pieces().to_data(),
		"boards": ledger.scoreboards().to_data(), "data": ledger.to_data()}


func _restore(value: Dictionary) -> ClubAssetLedger:
	return ClubAssetLedger.from_data(JSON.parse_string(JSON.stringify(value)), 21, _credits, _progress)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
