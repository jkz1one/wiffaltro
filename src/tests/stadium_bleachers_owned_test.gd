extends Node
## Closed-progress purchases, exact same-side conflicts and older snapshot preservation.

var _failures: int = 0


func _ready() -> void:
	var credits: Array = []
	var progress: Array = []
	for index in range(20):
		credits.append(500)
		progress.append({"seasons": 1, "wins": 5})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(8, credits, progress)
	var original: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	for tier: String in ["expanded", "club"]:
		_check(ledger.commit({"id": tier, "rev": ledger.revision(), "op": "stadium_land",
			"tier": tier, "through": 20, "progress_through": 20, "price_version": 1}).ok,
			"real ordered land prerequisite " + tier)
	_check(ledger.commit(_buy(ledger, "ST-028")).ok and ledger.balance() == 7170,
		"aluminum costs 480 blueprint plus 150 copy after land")
	_check(ledger.commit(_buy(ledger, "ST-075")).ok and ledger.balance() == 6550,
		"roofed timber costs 480 plus 140 independently")
	var layout: Dictionary = StadiumBleacherItems.upgrade(StadiumStarterLayout.empty())
	layout.bleachers = [{"copy": "purchase:bleacher:2:0", "site": "SIDE-SEAT-L"},
		{"copy": "purchase:bleacher:3:0", "site": "SIDE-SEAT-R"}]
	_check(ledger.commit({"id": "draft", "rev": 4, "op": "stadium_draft", "layout": layout}).ok,
		"mixed assemblies can be drafted")
	_check(ledger.commit({"id": "apply", "rev": 5, "op": "stadium_apply", "layout": layout,
		"geometry": StadiumHomeLayout.geometry("club", layout)}).ok, "exact saved arrangement applied")
	_check(StadiumLayoutSnapshot.matches(original, ledger), "old home prefix remains unchanged")
	_check(StadiumLayoutSnapshot.matches(StadiumLayoutSnapshot.capture(ledger), ledger),
		"new ground and complete boundary capture exact seating")
	_check(ledger.construction().copies.size() == 5
		and not ledger.construction().blueprints.has("ST-027"), "no old assembly granted or consumed")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 8, credits, progress)
	_check(restored != null and ClubCareer.same(restored.view(), ledger.view()),
		"journal replays exactly")
	var data: Dictionary = ledger.to_data()
	data.version = 10
	data.erase("bleacher_catalog")
	data.erase("bleacher_layout_catalog")
	data.erase("target_catalog")
	data.erase("target_layout_catalog")
	data.erase("net_catalog")
	data.erase("net_layout_catalog")
	data.erase("light_catalog")
	data.erase("light_layout_catalog")
	data.erase("infield_catalog")
	data.erase("infield_layout_catalog")
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
	_check(ClubAssetLedger.from_data(data, 8, credits, progress) == null,
		"old header rejects new purchases")
	var fresh: ClubAssetLedger = ClubAssetLedger.new(8, credits, progress)
	data = fresh.to_data()
	data.version = 10
	data.erase("bleacher_catalog")
	data.erase("bleacher_layout_catalog")
	data.erase("target_catalog")
	data.erase("target_layout_catalog")
	data.erase("net_catalog")
	data.erase("net_layout_catalog")
	data.erase("light_catalog")
	data.erase("light_layout_catalog")
	data.erase("infield_catalog")
	data.erase("infield_layout_catalog")
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
	_check(ClubAssetLedger.from_data(data, 8, credits, progress) != null,
		"older ground header stays valid")
	for patch: Dictionary in [{"price_version": 3}, {"price_version": true},
		{"item": "ST-027"}, {"progress_through": 1}, {"quantity": 0}]:
		var command: Dictionary = _buy(fresh, "ST-028")
		command.merge(patch, true)
		_check(not fresh.commit(command).ok and fresh.revision() == 0, "invalid purchase has no effects")
	var bad: Dictionary = layout.duplicate(true)
	bad.bleachers[1].copy = bad.bleachers[0].copy
	_check(not StadiumHomeLayout.validate(bad, ledger.construction(), "club").ok,
		"one exact copy cannot fill two sites")
	_check(not StadiumHomeLayout.validate(layout, ledger.construction(), "expanded").ok,
		"roofed assembly cannot bypass its property gate")
	if _failures == 0:
		print("Wiffaltro owned bleacher checks passed: prices, exact copies, land and historic prefixes.")
	get_tree().quit(0 if _failures == 0 else 1)


func _buy(ledger: ClubAssetLedger, item: String) -> Dictionary:
	return {"id": "bleacher:%d" % ledger.revision(), "rev": ledger.revision(), "op": "stadium_buy",
		"item": item, "quantity": 1, "price_version": 4, "through": 20, "progress_through": 20}


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
