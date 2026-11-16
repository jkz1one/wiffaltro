extends Node
## Exact five retained unlocks, independent channels, old headers and frozen journal replay.

var _failures: int = 0


func _ready() -> void:
	var credits: Array = []
	var progress: Array = []
	for index in range(20):
		credits.append(200)
		progress.append({"seasons": 1, "wins": 3})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(17, credits, progress)
	var old_snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	for id: String in StadiumInfieldStyles.PRICES:
		var command: Dictionary = _buy(ledger, id, 3)
		var before: int = ledger.balance()
		_check(ledger.commit(command).ok
			and ledger.balance() == before - StadiumInfieldStyles.PRICES[id],
			"exact individually priced base/footprint " + id)
		_check(ledger.commit(command).replayed, "idempotent style payment")
		_check(not ledger.commit(_buy(ledger, id, 3)).ok, "owned variant cannot be purchased twice")
	_check(ledger.balance() == 1940 and ledger.construction().copies.size() == 3,
		"five styles cost 2060 without manufacturing physical copies")
	for id: String in ["ST-062b", "ST-063b"]:
		_check(ledger.commit(_buy(ledger, id, 1)).ok, "older independent appearance remains buyable")
	var poles: Dictionary = {"id": "poles", "rev": ledger.revision(), "op": "stadium_buy",
		"item": "ST-037", "quantity": 4, "price_version": 7, "through": 20, "progress_through": 20}
	_check(ledger.commit(poles).ok, "four independently paid poles")
	var layout: Dictionary = StadiumInfieldStyles.upgrade(StadiumStarterLayout.empty())
	layout.bases = "ST-062d"
	layout.ground = "ST-063g"
	layout.styles = {"line": "ST-062b", "grass": "ST-063b"}
	var sites: Array = StadiumYardLightModels.SITES.keys()
	sites.sort()
	for index in range(4):
		layout.lights.append({"copy": "purchase:poles:%d" % index, "site": sites[index]})
	for id: String in StadiumInfieldModels.IDS:
		layout.ground = id
		var checked: Dictionary = StadiumHomeLayout.validate(layout, ledger.construction())
		_check(checked.ok and checked.live_units == 0
			and checked.night_qualified == StadiumInfieldStyles.NIGHT_VERIFIED,
			"exact owned footprint, independent bases and explicit lighting qualification")
		var revision: int = ledger.revision()
		_check(ledger.commit({"id": "draft%d" % revision, "rev": revision,
			"op": "stadium_draft", "layout": layout}).ok, "save exact independently selected draft")
		_check(ledger.commit({"id": "apply%d" % revision, "rev": revision + 1,
			"op": "stadium_apply", "layout": layout,
			"geometry": StadiumHomeLayout.geometry("backyard", layout)}).ok, "free complete apply")
	_check(ledger.balance() == 680 and StadiumLayoutSnapshot.matches(old_snapshot, ledger),
		"style swaps preserve balance and original immutable home prefix")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(snapshot.layout.version == 10 and StadiumLayoutSnapshot.matches(snapshot, ledger),
		"new family preserves exact masks and marker anchors")
	var bad: Dictionary = layout.duplicate(true)
	bad.bases = "ST-063g"
	_check(not StadiumHomeLayout.validate(bad, ledger.construction()).ok,
		"dirt unlock cannot impersonate a base set")
	bad = layout.duplicate(true)
	bad.ground = ["ST-063g", "ST-063h"]
	_check(not StadiumHomeLayout.validate(bad, ledger.construction()).ok,
		"unapproved overlapping footprint stack rejected")
	_check(not StadiumHomeLayout.validate(layout, StadiumStock.new_club()).ok,
		"none of the five styles is a starter grant")
	var stock: StadiumStock = ledger.construction()
	stock.styles.erase("ST-063j")
	_check(not StadiumHomeLayout.validate(layout, stock).ok,
		"owned bases cannot grant an independently locked footprint")
	stock = ledger.construction()
	stock.styles.erase("ST-062d")
	_check(not StadiumHomeLayout.validate(layout, stock).ok,
		"owned ground cannot grant an independently locked marker set")
	bad = layout.duplicate(true)
	bad.erase("bases")
	bad.version = 9
	bad.family = "reference-yard-lights-v9"
	_check(not StadiumHomeLayout.validate(bad, ledger.construction()).ok,
		"older layout family cannot smuggle a new footprint")
	var data: Dictionary = ledger.to_data()
	data.version = 14
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
	_check(ClubAssetLedger.from_data(data, 17, credits, progress) == null,
		"old light header cannot carry new infield receipts")
	var fresh: ClubAssetLedger = ClubAssetLedger.new(17, credits, progress)
	data = fresh.to_data()
	data.version = 14
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
	_check(ClubAssetLedger.from_data(data, 17, credits, progress) != null, "old light header readable")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 17, credits, progress)
	_check(restored != null and ClubCareer.same(restored.view(), ledger.view()),
		"complete ownership and last selected footprint replay exactly")
	_check(not StadiumInfieldStyles.quote(StadiumStock.new_club(), "ST-062c", "locked",
		{"seasons": 2, "wins": 4}).ok, "base set needs both retained progress gates")
	if _failures == 0:
		print("Wiffaltro owned infield checks passed: exact unlocks, channels and immutable replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _buy(ledger: ClubAssetLedger, item: String, version: int) -> Dictionary:
	return {"id": "infield:%d" % ledger.revision(), "rev": ledger.revision(), "op": "stadium_style",
		"item": item, "price_version": version, "through": 20, "progress_through": 20}


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
