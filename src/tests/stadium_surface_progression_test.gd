extends Node
## Synthetic credits isolate shared-wallet and migration rules, not real earned-season evidence.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(31, [300])
	_check(ledger.surface_owned().is_empty() and ledger.view().surface_origin ==
		StadiumSurfaceProgression.ROUGH_ORIGIN, "new-origin ownership starts without turf or prep")
	var before: Dictionary = ledger.to_data()
	var grass: Dictionary = _buy(ledger, "grass")
	var stale: Dictionary = grass.duplicate(true)
	stale.rev = 99
	_check(not ledger.commit(stale).ok and ClubCareer.same(before, ledger.to_data()),
		"stale confirmation cannot spend or grant")
	_check(ledger.preview(grass).price == 120, "working grass quote is exact")
	_check(ClubCareer.same(before, ledger.to_data()), "preview cannot spend or grant")
	_check(not StadiumSurfaceProgression.style_error(ledger.surface_owned(), "ST-063a").is_empty(),
		"mowing waits for actual grass ownership")
	_check(ledger.commit(grass).ok and ledger.balance() == 180, "grass debits the shared wallet")
	_check(ledger.commit(grass).replayed and ledger.balance() == 180, "same request never pays twice")
	var changed: Dictionary = grass.duplicate(true)
	changed.item = "ground_prep"
	_check(not ledger.commit(changed).ok and ledger.balance() == 180,
		"an old request cannot be repurposed into another upgrade")
	_check(StadiumSurfaceProgression.style_error(ledger.surface_owned(), "ST-063a").is_empty(),
		"mowing becomes available after grass")
	_check(not StadiumSurfaceProgression.style_error(ledger.surface_owned(), "ST-063g").is_empty(),
		"advanced dirt cuts still require preparation")
	var prep: Dictionary = _buy(ledger, "ground_prep")
	_check(ledger.commit(prep).ok and ledger.balance() == 100, "separate preparation purchase")
	_check(StadiumSurfaceProgression.style_error(ledger.surface_owned(), "ST-063g").is_empty(),
		"dirt cuts become eligible after both distinct upgrades")
	_check(not ledger.commit(_buy(ledger, "grass")).ok and ledger.balance() == 100,
		"owned upgrade cannot be bought twice under a new request")
	var restored: ClubAssetLedger = _reload(ledger.to_data(), [300])
	_check(restored != null and ClubCareer.same(restored.view(), ledger.view()),
		"both paid entitlements and their one balance survive JSON roundtrip")
	_check(ledger.prefix(0).surface_owned().is_empty() and
		ledger.prefix(1).surface_owned() == ["grass"],
		"historical prefixes do not borrow future upgrades")
	var isolation: Array[String] = ledger.surface_owned()
	isolation.clear()
	_check(ledger.surface_owned().size() == 2, "ownership views cannot mutate the ledger")
	var poor: ClubAssetLedger = ClubAssetLedger.new_club(31, [79])
	var poor_before: Dictionary = poor.to_data()
	_check(not poor.commit(_buy(poor, "ground_prep")).ok and
		ClubCareer.same(poor_before, poor.to_data()), "insufficient money preserves all state")
	var dirt: ClubAssetLedger = ClubAssetLedger.new_club(31, [80])
	_check(dirt.commit(_buy(dirt, "ground_prep")).ok and not dirt.surface_owned().has("grass"),
		"well-maintained all-dirt play does not force a grass purchase")
	var unfunded: ClubAssetLedger = ClubAssetLedger.new_club(31)
	var free: Dictionary = _buy(unfunded, "grass")
	free.through = 0
	_check(not unfunded.commit(free).ok, "unearned funds cannot establish grass")
	_selections(ledger.surface_owned())
	_legacy()
	_tamper(ledger.to_data())
	if _failures == 0:
		print("Wiffaltro surface progression checks passed: "
			+ "separate purchases, safe legacy and exact replay.")
	print("SURFACE_PROGRESSION_RESULT ", JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures == 0 else 1)


func _selections(owned: Array[String]) -> void:
	for height: String in StadiumSurfaceProgression.HEIGHTS:
		var selected: Dictionary = StadiumSurfaceProgression.selection(owned, true, height)
		_check(StadiumSurfaceProgression.valid_selection(selected, owned), "all four owned turf heights")
	_check(StadiumSurfaceProgression.selection([], true).is_empty(), "unowned grass is not selectable")
	_check(StadiumSurfaceProgression.selection([], false).condition == "rough", "rough dirt first")
	_check(StadiumSurfaceProgression.selection(owned, false).condition == "prepared",
		"prepared dirt remains a free selectable alternative")
	var bad: Dictionary = StadiumSurfaceProgression.selection(owned, true)
	bad.height = "extreme"
	_check(not StadiumSurfaceProgression.valid_selection(bad, owned), "unknown grass length rejects")
	bad = StadiumSurfaceProgression.selection([], false)
	bad.condition = "prepared"
	_check(not StadiumSurfaceProgression.valid_selection(bad, []), "unowned preparation rejects")


func _legacy() -> void:
	var old: ClubAssetLedger = ClubAssetLedger.new(31, [300])
	var inventory: Dictionary = old.construction().to_data()
	var old_layout: Dictionary = old.view().stadium_active
	var data: Dictionary = old.to_data()
	data.version = 16
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
	for field: String in ["pool_catalog", "pool_layout_catalog"]:
		var smuggled: Dictionary = data.duplicate(true)
		smuggled[field] = old.to_data()[field]
		_check(_reload(smuggled, [300]) == null,
			"legacy16 rejects later pool header smuggling: " + field)
		var incomplete: Dictionary = old.to_data()
		incomplete.erase(field)
		_check(_reload(incomplete, [300]) == null,
			"current ledger cannot drop required pool identity: " + field)
	var migrated: ClubAssetLedger = _reload(data, [300])
	_check(migrated != null and migrated.surface_owned() == ["grass", "ground_prep"],
		"known older clubs retain their established grass and prepared condition")
	if migrated == null:
		return
	_check(migrated.balance() == 300 and migrated.revision() == 0 and
		ClubCareer.same(migrated.construction().to_data(), inventory) and
		ClubCareer.same(migrated.view().stadium_active, old_layout),
		"migration spends nothing and changes no existing copies, styles or active layout")
	var again: ClubAssetLedger = _reload(migrated.to_data(), [300])
	_check(again != null and ClubCareer.same(again.view(), migrated.view()),
		"upgraded legacy origin roundtrips without repeating grants")


func _tamper(data: Dictionary) -> void:
	for field: String in ["surface_catalog", "surface_origin"]:
		var bad: Dictionary = data.duplicate(true)
		bad[field] = "unknown"
		_check(_reload(bad, [300]) == null, "unknown surface identity preserves original by rejecting")
	for patch: Dictionary in [{"item": "unknown"}, {"through": 0}, {"price_version": 2},
		{"rev": 9}, {"extra": true}]:
		var bad: Dictionary = data.duplicate(true)
		bad.events[0].merge(patch, true)
		_check(_reload(bad, [300]) == null, "forged surface receipt rejects")
	var old: Dictionary = data.duplicate(true)
	old.version = 16
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
	_check(_reload(old, [300]) == null, "old version cannot smuggle new surface purchases")
	_check(_reload(data, [199]) == null, "erasing earned income cannot retain paid upgrades")


func _reload(data: Dictionary, credits: Array) -> ClubAssetLedger:
	return ClubAssetLedger.from_data(JSON.parse_string(JSON.stringify(data)), 31, credits)


func _buy(ledger: ClubAssetLedger, item: String) -> Dictionary:
	return {"id": "surface:%d" % ledger.revision(), "rev": ledger.revision(),
		"op": "stadium_surface", "through": 1, "price_version": StadiumSurfaceProgression.VERSION,
		"item": item}


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
