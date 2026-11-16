extends Node
## Synthetic funding isolates once-only entitlements, exact layout ownership and replay.

var _failures: int = 0


func _ready() -> void:
	var credits: Array = []
	var progress: Array = []
	for index in range(12):
		credits.append(500)
		progress.append({"seasons": 1, "wins": 5})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(9, credits, progress)
	var before: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var total: int = 0
	for item: String in StadiumFieldStyles.PRICES:
		var command: Dictionary = _buy(ledger, item)
		var saved: Dictionary = ledger.to_data()
		_check(ledger.preview(command).ok and ledger.to_data() == saved, "appearance quote is pure")
		total += int(StadiumFieldStyles.PRICES[item])
		_check(ledger.commit(command).ok and ledger.balance() == 6000 - total,
			"one exact permanent entitlement charged")
		_check(ledger.commit(command).replayed and ledger.balance() == 6000 - total,
			"same receipt is idempotent")
		_check(not ledger.commit(_buy(ledger, item)).ok, "another request cannot rebuy an owned style")
	_check(ledger.construction().styles.size() == 6 and ledger.construction().copies.size() == 3,
		"six separate styles, no generated physical copies")
	_check(StadiumLayoutSnapshot.matches(before, ledger), "later unlocks preserve the previous field")
	var layout: Dictionary = StadiumFieldStyles.upgrade(StadiumStarterLayout.empty())
	layout.styles = {"line": "ST-062a", "grass": "ST-063d"}
	_check(ledger.commit({"id": "draft", "rev": ledger.revision(), "op": "stadium_draft",
		"layout": layout}).ok, "owned styles can be drafted")
	_check(ledger.commit({"id": "apply", "rev": ledger.revision(), "op": "stadium_apply",
		"layout": layout, "geometry": StadiumHomeLayout.geometry("backyard", layout)}).ok,
		"free application binds the correct appearance geometry")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(snapshot.layout.version == 3 and StadiumLayoutSnapshot.matches(snapshot, ledger),
		"version-three layout binds exact owned appearance")
	_check(StadiumLayoutSnapshot.capture(ledger, false).is_empty(),
		"old field profile is not reinterpreted")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 9, credits, progress)
	_check(restored != null and ClubCareer.same(restored.view(), ledger.view()),
		"style journal replay")
	_tamper(ledger, credits, progress, snapshot)
	if _failures == 0:
		print("Wiffaltro owned style checks passed: "
			+ "once-only prices, exact channels and saved ownership.")
	get_tree().quit(0 if _failures == 0 else 1)


func _buy(ledger: ClubAssetLedger, item: String) -> Dictionary:
	return {"id": "style:%d" % ledger.revision(), "rev": ledger.revision(), "op": "stadium_style",
		"item": item, "price_version": 1, "through": 12, "progress_through": 12}


func _tamper(ledger: ClubAssetLedger, credits: Array, progress: Array,
	snapshot: Dictionary) -> void:
	var fresh: ClubAssetLedger = ClubAssetLedger.new(9, credits, progress)
	for patch: Dictionary in [{"item": "ST-063e"}, {"item": "ST-080"}, {"item": true},
		{"price_version": true}, {"price_version": 99}, {"progress_through": 1},
		{"progress_through": true}, {"progress_through": 13}, {"quantity": 2}, {"through": 0}]:
		var command: Dictionary = _buy(fresh, "ST-062a")
		command.merge(patch, true)
		_check(not fresh.commit(command).ok and fresh.revision() == 0,
			"malformed, unavailable or stale entitlement request rejects")
	var poor: ClubAssetLedger = ClubAssetLedger.new(9, [100], [{"seasons": 1, "wins": 1}])
	_check(not poor.commit({"id": "poor", "rev": 0, "op": "stadium_style", "item": "ST-062a",
		"price_version": 1, "through": 1, "progress_through": 1}).ok, "unlocked does not mean affordable")
	var bad: Dictionary = ledger.to_data()
	bad.version = 7
	bad.erase("style_catalog")
	bad.erase("appearance_catalog")
	bad.erase("display_catalog")
	bad.erase("display_layout_catalog")
	bad.erase("ground_catalog")
	bad.erase("ground_layout_catalog")
	bad.erase("bleacher_catalog")
	bad.erase("bleacher_layout_catalog")
	bad.erase("target_catalog")
	bad.erase("target_layout_catalog")
	bad.erase("net_catalog")
	bad.erase("net_layout_catalog")
	bad.erase("light_catalog")
	bad.erase("light_layout_catalog")
	bad.erase("infield_catalog")
	bad.erase("infield_layout_catalog")
	bad.erase("wall_catalog")
	bad.erase("wall_layout_catalog")
	bad.erase("surface_catalog")
	bad.erase("surface_layout_catalog")
	bad.erase("surface_origin")
	bad.erase("wall_piece_catalog")
	bad.erase("advanced_layout_catalog")
	bad.erase("scoreboard_catalog")
	bad.erase("scoreboard_layout_catalog")
	bad.erase("mounted_scoreboard_layout_catalog")
	bad.erase("pool_catalog")
	bad.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(bad, 9, credits, progress) == null,
		"old schema rejects new styles")
	bad = fresh.to_data()
	bad.version = 7
	bad.erase("style_catalog")
	bad.erase("appearance_catalog")
	bad.erase("display_catalog")
	bad.erase("display_layout_catalog")
	bad.erase("ground_catalog")
	bad.erase("ground_layout_catalog")
	bad.erase("bleacher_catalog")
	bad.erase("bleacher_layout_catalog")
	bad.erase("target_catalog")
	bad.erase("target_layout_catalog")
	bad.erase("net_catalog")
	bad.erase("net_layout_catalog")
	bad.erase("light_catalog")
	bad.erase("light_layout_catalog")
	bad.erase("infield_catalog")
	bad.erase("infield_layout_catalog")
	bad.erase("wall_catalog")
	bad.erase("wall_layout_catalog")
	bad.erase("surface_catalog")
	bad.erase("surface_layout_catalog")
	bad.erase("surface_origin")
	bad.erase("wall_piece_catalog")
	bad.erase("advanced_layout_catalog")
	bad.erase("scoreboard_catalog")
	bad.erase("scoreboard_layout_catalog")
	bad.erase("mounted_scoreboard_layout_catalog")
	bad.erase("pool_catalog")
	bad.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(bad, 9, credits, progress) != null,
		"old club gains no free styles")
	bad = snapshot.duplicate(true)
	bad.layout.styles.line = "ST-063a"
	_check(not StadiumLayoutSnapshot.valid(bad), "grass entitlement cannot occupy baseline channel")
	bad = snapshot.duplicate(true)
	bad.inventory.styles.erase("ST-063d")
	_check(not StadiumLayoutSnapshot.valid(bad),
		"selected appearance requires exact owned entitlement")
	bad = snapshot.duplicate(true)
	bad.layout.styles.grass = ""
	_check(StadiumLayoutSnapshot.valid(bad) and not StadiumLayoutSnapshot.matches(bad, ledger),
		"structural presentation data cannot replace the saved active layout")
	for value: Variant in [true, null, "3", 3.5, 99]:
		bad = snapshot.duplicate(true)
		bad.layout.version = value
		_check(not StadiumLayoutSnapshot.valid(bad), "malformed appearance grammar rejects cleanly")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
