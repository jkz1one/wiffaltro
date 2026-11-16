extends "res://src/tests/stadium_target_owned_test.gd"
## Exact paid poles, complete-preset qualification and seeded fixture environment snapshots.


func _ready() -> void:
	var credits: Array = [220, 195, 220, 195]
	var progress: Array = []
	for index in range(4):
		progress.append({"seasons": 1, "wins": 2})
	var untouched: StadiumStock = StadiumStock.new_club()
	for progress_case: Dictionary in [{"seasons": 2, "wins": 8}, {"seasons": 3, "wins": 7}]:
		_check(not StadiumPurchases.quote(untouched, "ST-037", 1, "locked", 7,
			progress_case).ok, "both season and win gates are required")
	_check(not StadiumPurchases.quote(untouched, "ST-037", 1, "old-price", 6,
		{"seasons": 3, "wins": 8}).ok, "older price families cannot buy lights")
	var ledger: ClubAssetLedger = ClubAssetLedger.new(9, credits, progress)
	var buy: Dictionary = {"id": "lights", "rev": 0, "op": "stadium_buy", "item": "ST-037",
		"quantity": 5, "price_version": 7, "through": 4, "progress_through": 4}
	_check(ledger.commit(buy).ok and ledger.balance() == 205, "blueprint300 plus five copies325")
	_check(ledger.commit(buy).replayed and ledger.balance() == 205, "light purchase retries once")
	var layout: Dictionary = StadiumLightItems.upgrade(StadiumStarterLayout.empty())
	var sites: Array = StadiumYardLightModels.SITES.keys()
	sites.sort()
	for index in range(4):
		layout.lights.append({"copy": "purchase:lights:%d" % index, "site": sites[index]})
	var checked: Dictionary = StadiumHomeLayout.validate(layout, ledger.construction())
	_check(checked.ok and checked.night_qualified and checked.live_units == 0,
		"four exact owned sites qualify independently of live budget")
	_check(not StadiumLandUI._night_change(layout, ledger.construction(),
		"expanded", "club").is_empty()
		and StadiumLandUI._night_change(layout, ledger.construction(), "backyard", "expanded").is_empty(),
		"land expansion explicitly previews loss of yard-night eligibility")
	_check(checked.stored.has("purchase:lights:4"), "fifth pole stays stored without extra light")
	var partial: Dictionary = layout.duplicate(true)
	partial.lights.pop_back()
	_check(not StadiumHomeLayout.validate(partial, ledger.construction()).night_qualified,
		"three installed poles cannot qualify from a fourth stored copy")
	_check(not StadiumHomeLayout.validate(layout, ledger.construction(), "club").night_qualified,
		"yard profile cannot silently qualify future tall Club structures")
	var invalid: Dictionary = layout.duplicate(true)
	invalid.lights[1].copy = invalid.lights[0].copy
	_check(not StadiumHomeLayout.validate(invalid, ledger.construction()).ok,
		"one copy cannot occupy two sites")
	_check(ledger.commit({"id": "draft", "rev": 1, "op": "stadium_draft", "layout": layout}).ok,
		"exact light draft")
	_check(ledger.commit({"id": "apply", "rev": 2, "op": "stadium_apply", "layout": layout,
		"geometry": StadiumHomeLayout.geometry("backyard", layout)}).ok, "light layout applies free")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(snapshot.version == 3 and StadiumLayoutSnapshot.matches(snapshot, ledger),
		"season-entry ownership remains distinct from fixture environment")
	for seed in range(6):
		var fixture: Dictionary = snapshot.duplicate(true)
		fixture.version = 5
		fixture["environment"] = StadiumFixtureEnvironment.capture(fixture, seed, 0)
		_check(StadiumLayoutSnapshot.valid(fixture)
			and fixture.environment.mode == ("night" if StadiumFixtureEnvironment.is_night_seed(seed)
				else "day"),
			"eligible deterministic pool retains both daytime and night fixtures")
		var bad: Dictionary = fixture.duplicate(true)
		bad.environment.mode = "day" if fixture.environment.mode == "night" else "night"
		_check(not StadiumLayoutSnapshot.valid(bad), "fixture environment cannot be freely switched")
		bad = fixture.duplicate(true)
		bad.layout.lights.pop_back()
		_check(not StadiumLayoutSnapshot.valid(bad), "partial preset cannot retain qualified profile")
	for patch: Variant in [null, {}, [{"copy": "purchase:lights:0", "site": "unknown"}],
		[{"copy": "not-owned", "site": "YLIGHT-FL"}]]:
		var malformed: Dictionary = layout.duplicate(true)
		malformed.lights = patch
		_check(not StadiumHomeLayout.validate(malformed, ledger.construction()).ok,
			"malformed or unowned placement rejected")
	var old: Dictionary = ledger.to_data()
	old.version = 13
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
	_check(ClubAssetLedger.from_data(old, 9, credits, progress) == null,
		"old net header cannot smuggle new light purchases")
	var fresh: ClubAssetLedger = ClubAssetLedger.new(9, credits, progress)
	old = fresh.to_data()
	old.version = 13
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
	_check(ClubAssetLedger.from_data(old, 9, credits, progress) != null, "old net header readable")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 9, credits, progress)
	_check(restored != null and ClubCareer.same(restored.view(), ledger.view()),
		"paid light layout replays from exact journal")
	if _failures == 0:
		print("Wiffaltro owned light checks passed: exact copies, presets and seeded fixture binding.")
	get_tree().quit(0 if _failures == 0 else 1)
