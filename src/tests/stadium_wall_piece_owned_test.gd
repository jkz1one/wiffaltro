extends Node

var _failures: int = 0
var _credits: Array = []
var _progress: Array = []


func _ready() -> void:
	for index in range(20):
		_credits.append(100000)
		_progress.append({"seasons": 1, "wins": 4})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(17, _credits, _progress)
	var initial: Dictionary = ledger.to_data()
	for id: String in StadiumWallPieceCatalog.DATA:
		var command: Dictionary = _buy(ledger, id, 2)
		var piece: Dictionary = StadiumWallPieceCatalog.item(id)
		var price: int = StadiumWallPieceOwnership.BLUEPRINT_PRICES[piece.material]
		var before: int = ledger.balance()
		var untouched: Dictionary = _state(ledger)
		_check(
			ledger.preview(command).ok and ClubCareer.same(untouched, _state(ledger)),
			"preview cannot mutate ownership or spending"
		)
		_check(
			ledger.commit(command).ok and ledger.balance() == before - price - 2 * piece.copy_price,
			"each exact variant pays its own blueprint and copies"
		)
		_check(ledger.commit(command).replayed, "identical request cannot mint duplicates")
		before = ledger.balance()
		_check(
			ledger.commit(_buy(ledger, id, 1)).ok and ledger.balance() == before - piece.copy_price,
			"later copies do not repay a blueprint"
		)
	_check(
		(
			ledger.wall_pieces().blueprints.size() == 8
			and ledger.wall_pieces().stock.copies.size() == 24
			and ledger.construction().copies.size() == 3
		),
		"separate variants preserve original starter stock"
	)
	var detached: StadiumWallPieceOwnership = ledger.wall_pieces()
	detached.stock.copies.clear()
	_check(ledger.wall_pieces().stock.copies.size() == 24, "read access is isolated")
	var loaded: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 17, _credits, _progress
	)
	_check(
		(
			loaded != null
			and ClubCareer.same(loaded.wall_pieces().to_data(), ledger.wall_pieces().to_data())
			and loaded.balance() == ledger.balance()
		),
		"JSON journal replay reproduces exact ownership and shared balance"
	)
	var old: Dictionary = initial.duplicate(true)
	old.version = 17
	old.erase("wall_piece_catalog")
	old.erase("advanced_layout_catalog")
	old.erase("scoreboard_catalog")
	old.erase("scoreboard_layout_catalog")
	old.erase("mounted_scoreboard_layout_catalog")
	old.erase("pool_catalog")
	old.erase("pool_layout_catalog")
	loaded = ClubAssetLedger.from_data(old, 17, _credits, _progress)
	_check(
		loaded != null and loaded.wall_pieces().stock.copies.is_empty(),
		"old ledger gets empty extension without grants or charges"
	)
	old.events = ledger.to_data().events
	_check(
		ClubAssetLedger.from_data(old, 17, _credits, _progress) == null,
		"old header cannot smuggle extension purchases"
	)
	_rejections(ledger)
	_capacity()
	_populated_legacy()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro wall piece ownership passed: exact blueprints, journal and shared capacity."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _rejections(ledger: ClubAssetLedger) -> void:
	var before: Dictionary = _state(ledger)
	for row: Array in [
		["quantity", 0],
		["quantity", true],
		["quantity", 1.5],
		["price_version", 2],
		["progress_through", 19],
		["item", "ST-024"],
		["through", 0],
		["rev", 0]
	]:
		var command: Dictionary = _buy(ledger, "ST-024-L", 1)
		command[row[0]] = row[1]
		_check(not ledger.commit(command).ok, "invalid purchase rejected: " + row[0])
	_check(ClubCareer.same(before, _state(ledger)), "failed purchases are atomic")
	var poor_credits: Array = []
	poor_credits.resize(20)
	poor_credits.fill(1)
	var poor: ClubAssetLedger = ClubAssetLedger.new(17, poor_credits, _progress)
	var poor_before: Dictionary = _state(poor)
	_check(
		(
			not poor.commit(_buy(poor, "ST-024-L", 1)).ok
			and ClubCareer.same(poor_before, _state(poor))
		),
		"no second wallet or unaffordable entitlement"
	)
	var piece: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	_check(
		not piece.quote("ST-024-L", 1, "gate", {"seasons": 2, "wins": 100}).ok,
		"parent progress gate remains enforced"
	)
	var data: Dictionary = ledger.wall_pieces().to_data()
	data.blueprints.clear()
	_check(StadiumWallPieceOwnership.from_data(data) == null, "copies require exact entitlement")


func _capacity() -> void:
	for pieces_first: bool in [true, false]:
		var ledger: ClubAssetLedger = ClubAssetLedger.new(17, _credits, _progress)
		var piece: Dictionary = _buy(ledger, "ST-024-L", 4092 if pieces_first else 1)
		var standard: Dictionary = {
			"id": "standard",
			"rev": 0,
			"op": "stadium_buy",
			"through": 20,
			"progress_through": 20,
			"price_version": 8,
			"item": "ST-024",
			"quantity": 1 if pieces_first else 4092
		}
		var first: Dictionary = piece if pieces_first else standard
		var second: Dictionary = standard if pieces_first else piece
		_check(ledger.commit(first).ok, "first family can approach shared capacity")
		second.rev = ledger.revision()
		_check(ledger.commit(second).ok, "both families may exactly fill shared capacity")
		var before: Dictionary = _state(ledger)
		var overflow: Dictionary = first.duplicate(true)
		overflow.id = "overflow"
		overflow.rev = ledger.revision()
		overflow.quantity = 1
		_check(
			not ledger.commit(overflow).ok and ClubCareer.same(before, _state(ledger)),
			"combined cap enforced atomically in both purchase orders"
		)
		var loaded: ClubAssetLedger = ClubAssetLedger.from_data(
			JSON.parse_string(JSON.stringify(ledger.to_data())), 17, _credits, _progress
		)
		_check(
			loaded != null and ClubCareer.same(before, _state(loaded)),
			"interleaved full inventory and balance replay exactly"
		)


func _state(ledger: ClubAssetLedger) -> Dictionary:
	return {
		"journal": ledger.to_data(),
		"view": ledger.view(),
		"standard": ledger.construction().to_data(),
		"pieces": ledger.wall_pieces().to_data()
	}


func _populated_legacy() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(17, _credits, _progress)
	_check(
		(
			ledger
			. commit(
				{
					"id": "old-wall",
					"rev": 0,
					"op": "stadium_buy",
					"through": 20,
					"progress_through": 20,
					"price_version": 8,
					"item": "ST-024",
					"quantity": 23
				}
			)
			. ok
		),
		"legacy wall receipt purchased"
	)
	var old: Dictionary = ledger.to_data()
	old.version = 17
	old.erase("wall_piece_catalog")
	old.erase("advanced_layout_catalog")
	old.erase("scoreboard_catalog")
	old.erase("scoreboard_layout_catalog")
	old.erase("mounted_scoreboard_layout_catalog")
	old.erase("pool_catalog")
	old.erase("pool_layout_catalog")
	var loaded: ClubAssetLedger = ClubAssetLedger.from_data(old, 17, _credits, _progress)
	_check(
		loaded != null and ClubCareer.same(_state(ledger), _state(loaded)),
		"populated legacy journal preserves money, layouts and inventory with empty extension"
	)
	var before: int = loaded.balance()
	_check(
		loaded.commit(_buy(loaded, "ST-024-L", 1)).ok and loaded.balance() == before - 375,
		"owning standard blueprint grants no low blueprint discount"
	)


func _buy(ledger: ClubAssetLedger, id: String, quantity: int) -> Dictionary:
	return {
		"id": "piece%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_wall_piece",
		"through": 20,
		"progress_through": 20,
		"price_version": 1,
		"item": id,
		"quantity": quantity
	}


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
