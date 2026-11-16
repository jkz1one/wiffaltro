extends Node
## Journaled full-copy wall purchases and exact immutable manifests; runtime remains gated.

var _failures: int = 0


func _ready() -> void:
	var credits: Array = []
	var progress: Array = []
	for index in range(20):
		credits.append(1000)
		progress.append({"seasons": 1, "wins": 4})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(17, credits, progress)
	var original: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	for row: Array in [["ST-024", 23, 1050], ["ST-022", 19, 755], ["ST-023", 19, 755]]:
		var command: Dictionary = _buy(ledger, row[0], row[1])
		var balance: int = ledger.balance()
		_check(ledger.commit(command).ok and ledger.balance() == balance - row[2],
			"whole-run purchase pays blueprint once and every copy")
		_check(ledger.commit(command).replayed and ledger.balance() == balance - row[2],
			"retry does not duplicate wall inventory or spending")
	var layout: Dictionary = StadiumWallItems.upgrade(StadiumStarterLayout.empty())
	var stock: StadiumStock = ledger.construction()
	for row: Array in [["back", "ST-024"], ["left", "ST-022"], ["right", "ST-023"]]:
		var proposal: Dictionary = StadiumWallLayout.propose(layout.walls, stock, row[0], row[1])
		_check(proposal.ok, "complete paid manifest available")
		layout.walls = proposal.walls
	var checked: Dictionary = StadiumHomeLayout.validate(layout, stock)
	_check(checked.ok and checked.wall_panels.size() == 61 and checked.live_units == 0,
		"wall panels do not consume movable live-object budget")
	_check(checked.stored.size() == 3 and not checked.night_qualified,
		"placed walls are not stored and do not inherit a lighting qualification")
	var balance: int = ledger.balance()
	for shape: String in ["straight", "deeper_center", "straight"]:
		layout.walls = StadiumWallLayout.propose(layout.walls, stock, "back", "ST-024", shape).walls
		var revision: int = ledger.revision()
		_check(ledger.commit({"id": "draft%d" % revision, "rev": revision,
			"op": "stadium_draft", "layout": layout}).ok, "canonical free wall draft")
		_check(ledger.commit({"id": "apply%d" % revision, "rev": revision + 1,
			"op": "stadium_apply", "layout": layout,
			"geometry": StadiumHomeLayout.geometry("backyard", layout)}).ok, "atomic ledger replacement")
		_check(ledger.balance() == balance and ledger.construction().copies.size() == 64,
			"shape change cannot charge again or manufacture copies")
	_check(StadiumLayoutSnapshot.matches(original, ledger), "older home prefix remains unchanged")
	_check(StadiumLayoutSnapshot.capture(ledger).is_empty() == (not StadiumWallItems.RUNTIME_READY),
		"unfinished fixture integration cannot activate a wall snapshot")
	if StadiumWallItems.RUNTIME_READY:
		var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
		_check(StadiumLayoutSnapshot.valid(JSON.parse_string(JSON.stringify(snapshot))),
			"season-entry wall snapshot survives JSON integer-to-float decoding")
		snapshot.version = 7
		snapshot["environment"] = StadiumFixtureEnvironment.capture(snapshot, 9, 0)
		_check(StadiumLayoutSnapshot.valid(JSON.parse_string(JSON.stringify(snapshot))),
			"fixture wall snapshot preserves its environment across JSON decoding")
	_check(ClubAssetLedger.from_data(ledger.to_data(), 17, credits, progress) != null,
		"full wall journal replays exact ownership and geometry")
	var data: Dictionary = ledger.to_data()
	data.version = 15
	data.erase("wall_catalog")
	data.erase("wall_layout_catalog")
	data.erase("surface_catalog")
	data.erase("surface_layout_catalog")
	data.erase("surface_origin")
	data.erase("wall_piece_catalog")
	data.erase("advanced_layout_catalog")
	data.erase("scoreboard_catalog")
	data.erase("scoreboard_layout_catalog")
	data.erase("mounted_scoreboard_layout_catalog")
	data.erase("pool_catalog")
	data.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(data, 17, credits, progress) == null,
		"old header cannot smuggle wall receipts or new layout")
	data = ClubAssetLedger.new(17, credits, progress).to_data()
	data.version = 15
	data.erase("wall_catalog")
	data.erase("wall_layout_catalog")
	data.erase("surface_catalog")
	data.erase("surface_layout_catalog")
	data.erase("surface_origin")
	data.erase("wall_piece_catalog")
	data.erase("advanced_layout_catalog")
	data.erase("scoreboard_catalog")
	data.erase("scoreboard_layout_catalog")
	data.erase("mounted_scoreboard_layout_catalog")
	data.erase("pool_catalog")
	data.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(data, 17, credits, progress) != null,
		"untouched infield-era header still loads")
	var low: ClubAssetLedger = ClubAssetLedger.new(17, [1], [{"seasons": 20, "wins": 80}])
	var before: Dictionary = low.to_data()
	var command: Dictionary = _buy(low, "ST-024", 23)
	command.through = 1
	command.progress_through = 1
	_check(not low.commit(command).ok and ClubCareer.same(before, low.to_data()),
		"insufficient funds preserve journal and stock")
	for id: String in StadiumWallItems.PRICES:
		_check(not StadiumPurchases.quote(StadiumStock.new_club(), id, 1, "early", 8,
			{"seasons": 0, "wins": 0}).ok, "no invented early wall entitlement")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro owned wall checks passed: exact purchases, journal replay and gated geometry.")
	get_tree().quit(0 if _failures == 0 else 1)


func _buy(ledger: ClubAssetLedger, item: String, quantity: int) -> Dictionary:
	return {"id": "wall-buy%d" % ledger.revision(), "rev": ledger.revision(), "op": "stadium_buy",
		"item": item, "quantity": quantity, "price_version": StadiumWallItems.PRICE_VERSION,
		"through": 20, "progress_through": 20}


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
