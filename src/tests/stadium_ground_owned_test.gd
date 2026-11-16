extends Node
## Paid once-only surface entitlements, closed progress and frozen earlier prefixes.

var _failures: int = 0


func _ready() -> void:
	var credits: Array = [500, 500, 500, 500]
	var progress: Array = []
	for index in range(4):
		progress.append({"seasons": 1, "wins": 5})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(7, credits, progress)
	var old: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var command: Dictionary = _buy(ledger, "ST-063e")
	_check(ledger.commit(command).ok and ledger.balance() == 1840, "worn patches charge 160 once")
	_check(ledger.commit(command).replayed and ledger.balance() == 1840, "retry cannot charge twice")
	_check(not ledger.commit(_buy(ledger, "ST-063e")).ok, "duplicate entitlement cannot be sold")
	_check(ledger.commit(_buy(ledger, "ST-063f")).ok and ledger.balance() == 1570,
		"clay independently costs 270")
	_check(not ledger.commit(_buy(ledger, "ST-063i")).ok, "fifth-season sand gate remains locked")
	var layout: Dictionary = StadiumGroundStyles.upgrade(StadiumStarterLayout.empty())
	layout.ground = "ST-063e"
	_check(ledger.commit({"id": "draft", "rev": 2, "op": "stadium_draft", "layout": layout}).ok,
		"ground is drafted independently of line and grass")
	layout.ground = "ST-063f"
	_check(not ledger.commit({"id": "unsaved", "rev": 3, "op": "stadium_apply", "layout": layout,
		"geometry": StadiumHomeLayout.geometry("backyard", layout)}).ok,
		"unsaved replacement cannot bypass the saved-draft requirement")
	_check(ledger.commit({"id": "draft-clay", "rev": 3, "op": "stadium_draft", "layout": layout}).ok,
		"save exact replacement before Apply")
	_check(ledger.commit({"id": "apply", "rev": 4, "op": "stadium_apply", "layout": layout,
		"geometry": StadiumHomeLayout.geometry("backyard", layout)}).ok, "free owned replacement")
	_check(ledger.balance() == 1570 and ledger.construction().copies.size() == 3,
		"switching does not consume money or fabricate physical copies")
	_check(StadiumLayoutSnapshot.matches(old, ledger), "prior home prefix remains exact")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(snapshot.layout.version == 5 and StadiumLayoutSnapshot.matches(snapshot, ledger),
		"new layout uses its explicit immutable geometry family")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 7, credits, progress)
	_check(restored != null and ClubCareer.same(restored.view(), ledger.view()),
		"ground journal reloads exact ownership and placement")
	_tamper(ledger, credits, progress, layout)
	if _failures == 0:
		print("Wiffaltro owned ground checks passed: exact entitlements, free swaps and old prefixes.")
	get_tree().quit(0 if _failures == 0 else 1)


func _buy(ledger: ClubAssetLedger, item: String) -> Dictionary:
	return {"id": "ground:%d" % ledger.revision(), "rev": ledger.revision(), "op": "stadium_style",
		"item": item, "price_version": 2, "through": 4, "progress_through": 4}


func _tamper(ledger: ClubAssetLedger, credits: Array, progress: Array, layout: Dictionary) -> void:
	var fresh: ClubAssetLedger = ClubAssetLedger.new(7, credits, progress)
	for patch: Dictionary in [{"item": "ST-063h"}, {"item": "ST-062a"}, {"item": true},
		{"price_version": 1}, {"price_version": true}, {"progress_through": 1}, {"through": 0}]:
		var command: Dictionary = _buy(fresh, "ST-063e")
		command.merge(patch, true)
		_check(not fresh.commit(command).ok and fresh.revision() == 0,
			"invalid receipt leaves no charge")
	var bad: Dictionary = layout.duplicate(true)
	bad.ground = ["ST-063e", "ST-063f"]
	_check(not StadiumHomeLayout.validate(bad, ledger.construction()).ok,
		"overlapping treatments cannot stack")
	bad = layout.duplicate(true)
	bad.ground = "ST-063i"
	_check(not StadiumHomeLayout.validate(bad, ledger.construction()).ok,
		"unowned ground cannot apply")
	var data: Dictionary = ledger.to_data()
	data.version = 9
	data.erase("ground_catalog")
	data.erase("ground_layout_catalog")
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
	_check(ClubAssetLedger.from_data(data, 7, credits, progress) == null,
		"old header cannot smuggle ground events")
	data = fresh.to_data()
	data.version = 9
	data.erase("ground_catalog")
	data.erase("ground_layout_catalog")
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
	_check(ClubAssetLedger.from_data(data, 7, credits, progress) != null,
		"earlier club-display header still loads")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
