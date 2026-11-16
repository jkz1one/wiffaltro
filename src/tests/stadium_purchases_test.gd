extends Node
## Synthetic income fixtures test exact common-wallet accounting, not real season rewards.

var _failures: int = 0


func _ready() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(17, [40, 80, 0])
	var initial: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var command: Dictionary = _buy(ledger, "copy:0", "ST-001", 1, 1)
	var before: Dictionary = ledger.to_data()
	_check(ledger.preview(command).balance_after == 80 and ledger.to_data() == before,
		"quote is pure and uses one shared balance")
	_check(ledger.commit(command).ok and ledger.balance() == 80, "exact 40-CB copy charge")
	_check(ledger.commit(command).replayed and ledger.construction().copies.size() == 4,
		"same request restores the same owned copy without another charge")
	var copy: String = "purchase:copy:0:0"
	_check(ledger.construction().copies[copy].paid == 40, "copy retains its actual price receipt")
	var isolated: StadiumStock = ledger.construction()
	isolated.copies.clear()
	_check(ledger.construction().copies.size() == 4, "returned stock cannot mutate journal ownership")
	var open: Dictionary = {"id": "pack:0", "rev": 1, "op": "player_pack_open",
		"through": 2, "price_version": ClubPlayerCatalog.PRICE_VERSION}
	_check(ledger.commit(open).ok and ledger.balance() == 0, "player pack spends remaining CB")
	var pending: Dictionary = ledger.view().pending
	_check(not ledger.commit(_buy(ledger, "poor", "ST-079", 1, 2)).ok,
		"construction cannot overspend funds already paid for a pack")
	_check(ledger.view().pending == pending, "failed construction does not alter the paid reveal")
	_check(StadiumLayoutSnapshot.matches(initial, ledger), "purchase cannot rewrite an older field")
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.obstacles = [{"copy": copy, "site": "O-L1", "yaw": 0}]
	_check(ledger.commit({"id": "draft", "rev": 2, "op": "stadium_draft", "layout": layout}).ok,
		"purchased exact copy can be drafted while pack selection remains saved")
	_check(ledger.commit({"id": "apply", "rev": 3, "op": "stadium_apply", "layout": layout,
		"geometry": StadiumProperty.signature("backyard")}).ok, "paid copy can become the active field")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(snapshot.version == 3 and StadiumLayoutSnapshot.matches(snapshot, ledger),
		"current field binds paid ownership at the exact active journal prefix")
	var json: Dictionary = JSON.parse_string(JSON.stringify(snapshot, "", true, true))
	_check(StadiumLayoutSnapshot.key(json) == StadiumLayoutSnapshot.key(snapshot),
		"JSON numeric conversion preserves paid field identity")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 17, [40, 80, 0])
	_check(restored != null and ClubCareer.same(restored.construction().to_data(),
		ledger.construction().to_data()) and restored.view().pending == pending,
		"exact ownership, remaining wallet and unresolved pack survive replay")
	_tamper(ledger, snapshot, command)
	var next: ClubAssetLedger = ledger.with_credits([40, 80, 0, 100])
	_check(next.commit(_buy(next, "copy:later", "ST-003", 2, 4)).ok and next.balance() == 10,
		"two separately identified copies cost exactly two copy prices")
	_check(StadiumLayoutSnapshot.matches(snapshot, next),
		"later purchases preserve frozen old inventory")
	for stock_copy: String in next.construction().copies:
		_check(next.construction().copies[stock_copy].item != "ST-080",
			"no spectator identity substituted")
	if _failures == 0:
		print("Wiffaltro stadium purchase checks passed: "
			+ "shared wallet, exact copies and frozen ownership.")
	get_tree().quit(0 if _failures == 0 else 1)


func _tamper(ledger: ClubAssetLedger, snapshot: Dictionary, original: Dictionary) -> void:
	var funded: ClubAssetLedger = ledger.with_credits([400, 800, 0])
	for patch: Dictionary in [{"item": "ST-080"}, {"item": true}, {"quantity": 0},
		{"quantity": true}, {"quantity": 1.5}, {"through": 0}, {"through": 3},
		{"price_version": 99}, {"price_version": true}, {"rev": 99}, {"extra": true}]:
		var changed: Dictionary = _buy(funded, "invalid", "ST-001", 1, 2)
		changed.merge(patch, true)
		var before: Dictionary = funded.to_data()
		_check(not funded.commit(changed).ok and funded.to_data() == before,
			"malformed, unavailable or unearned purchase rejects without mutation")
	var altered: Dictionary = original.duplicate(true)
	altered.item = "ST-003"
	_check(not ledger.commit(altered).ok, "request ID cannot be reused for another item")
	var forged: Dictionary = snapshot.duplicate(true)
	forged.inventory.copies["purchase:copy:0:0"].paid = 0
	_check(not StadiumLayoutSnapshot.valid(forged), "paid price cannot be forged")
	forged = snapshot.duplicate(true)
	forged.inventory.copies["purchase:unearned:0"] = {"item": "ST-001", "paid": 40,
		"source": "purchase-v1"}
	_check(StadiumLayoutSnapshot.valid(forged) and not StadiumLayoutSnapshot.matches(forged, ledger),
		"structural inventory declaration cannot substitute for paid journal ownership")
	forged = snapshot.duplicate(true)
	forged.revision = 0
	_check(not StadiumLayoutSnapshot.matches(forged, ledger),
		"unearned prefix cannot own paid geometry")
	var old: Dictionary = ledger.to_data()
	old.version = 4
	old.erase("construction_catalog")
	old.erase("seating_catalog")
	old.erase("seating_layout_catalog")
	old.erase("land_catalog")
	old.erase("style_catalog")
	old.erase("appearance_catalog")
	old.erase("display_catalog")
	old.erase("display_layout_catalog")
	old.erase("ground_catalog")
	old.erase("ground_layout_catalog")
	old.erase("bleacher_catalog")
	old.erase("bleacher_layout_catalog")
	old.erase("target_catalog")
	old.erase("target_layout_catalog")
	old.erase("net_catalog")
	old.erase("net_layout_catalog")
	old.erase("light_catalog")
	old.erase("light_layout_catalog")
	old.erase("infield_catalog")
	old.erase("infield_layout_catalog")
	old.erase("wall_catalog")
	old.erase("wall_layout_catalog")
	old.erase("surface_catalog")
	old.erase("surface_layout_catalog")
	old.erase("surface_origin")
	old.erase("wall_piece_catalog")
	old.erase("advanced_layout_catalog")
	old.erase("scoreboard_catalog")
	old.erase("scoreboard_layout_catalog")
	old.erase("mounted_scoreboard_layout_catalog")
	old.erase("pool_catalog")
	old.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(old, 17, [40, 80, 0]) == null,
		"old schema cannot smuggle a paid construction event")
	var empty: ClubAssetLedger = ClubAssetLedger.new(17, [40])
	old = empty.to_data()
	old.version = 4
	old.erase("construction_catalog")
	old.erase("seating_catalog")
	old.erase("seating_layout_catalog")
	old.erase("land_catalog")
	old.erase("style_catalog")
	old.erase("appearance_catalog")
	old.erase("display_catalog")
	old.erase("display_layout_catalog")
	old.erase("ground_catalog")
	old.erase("ground_layout_catalog")
	old.erase("bleacher_catalog")
	old.erase("bleacher_layout_catalog")
	old.erase("target_catalog")
	old.erase("target_layout_catalog")
	old.erase("net_catalog")
	old.erase("net_layout_catalog")
	old.erase("light_catalog")
	old.erase("light_layout_catalog")
	old.erase("infield_catalog")
	old.erase("infield_layout_catalog")
	old.erase("wall_catalog")
	old.erase("wall_layout_catalog")
	old.erase("surface_catalog")
	old.erase("surface_layout_catalog")
	old.erase("surface_origin")
	old.erase("wall_piece_catalog")
	old.erase("advanced_layout_catalog")
	old.erase("scoreboard_catalog")
	old.erase("scoreboard_layout_catalog")
	old.erase("mounted_scoreboard_layout_catalog")
	old.erase("pool_catalog")
	old.erase("pool_layout_catalog")
	var migrated: ClubAssetLedger = ClubAssetLedger.from_data(old, 17, [40])
	_check(migrated != null and migrated.balance() == 40
		and migrated.construction().copies.size() == 3,
		"old assets migrate without inventing extra copies or spending")


func _buy(ledger: ClubAssetLedger, id: String, item: String, quantity: int,
	through: int) -> Dictionary:
	return {"id": id, "rev": ledger.revision(), "op": "stadium_buy", "item": item,
		"quantity": quantity, "through": through, "price_version": StadiumPurchases.VERSION}


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
