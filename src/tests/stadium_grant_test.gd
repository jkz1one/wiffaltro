extends "res://src/tests/club_career_test.gd"
## Owner-approved legacy starter grant through real career save/replay; no live placement implied.


var _legacy_checks: int = 0


func _check(ok: bool, label: String) -> void:
	_legacy_checks += 1
	super._check(ok, label)


func _ready() -> void:
	SeasonSave.path = "user://stadium-grant-%d.json" % OS.get_process_id()
	var season: SeasonState = _new()
	_check(SeasonSave.save(season), "fresh profile saves grant marker")
	var saved: Dictionary = SeasonSave.snapshot(season)
	_check(saved.career.assets.version == ClubAssetLedger.VERSION
		and saved.career.assets.starter_grant == 1,
		"versioned once-per-club grant receipt")
	for malformed: Variant in [true, "22", {}, null, NAN, INF, 22.5]:
		var bad: Dictionary = saved.career.duplicate(true)
		bad.version = malformed
		_check(ClubCareer.from_data(bad) == null, "malformed career version returns a clean rejection")
	var stock: Dictionary = ClubPlayers.assets(season.career).construction().to_data()
	_check(stock.copies.size() == 3 and season.career.balance() == 0,
		"exact three starter copies with zero free CB")
	for attempt in range(3):
		season = SeasonSave.restore()
		_check(SeasonSave.save(season) and ClubPlayers.assets(season.career).construction().to_data()
			== stock, "reload/repeated save never duplicates grant")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.career.assets.version = 1
	legacy.career.assets.erase("starter_grant")
	legacy.career.assets.erase("starter_catalog")
	legacy.career.assets.erase("draft_catalog")
	legacy.career.assets.erase("property_catalog")
	legacy.career.assets.erase("construction_catalog")
	legacy.career.assets.erase("seating_catalog")
	legacy.career.assets.erase("seating_layout_catalog")
	legacy.career.assets.erase("land_catalog")
	legacy.career.assets.erase("style_catalog")
	legacy.career.assets.erase("appearance_catalog")
	legacy.career.assets.erase("display_catalog")
	legacy.career.assets.erase("display_layout_catalog")
	legacy.career.assets.erase("ground_catalog")
	legacy.career.assets.erase("ground_layout_catalog")
	legacy.career.assets.erase("bleacher_catalog")
	legacy.career.assets.erase("bleacher_layout_catalog")
	legacy.career.assets.erase("target_catalog")
	legacy.career.assets.erase("target_layout_catalog")
	legacy.career.assets.erase("net_catalog")
	legacy.career.assets.erase("net_layout_catalog")
	legacy.career.assets.erase("light_catalog")
	legacy.career.assets.erase("light_layout_catalog")
	legacy.career.assets.erase("infield_catalog")
	legacy.career.assets.erase("infield_layout_catalog")
	legacy.career.assets.erase("wall_catalog")
	legacy.career.assets.erase("wall_layout_catalog")
	legacy.career.assets.erase("surface_catalog")
	legacy.career.assets.erase("surface_layout_catalog")
	legacy.career.assets.erase("surface_origin")
	legacy.career.assets.erase("wall_piece_catalog")
	legacy.career.assets.erase("advanced_layout_catalog")
	legacy.career.assets.erase("scoreboard_catalog")
	legacy.career.assets.erase("scoreboard_layout_catalog")
	legacy.career.assets.erase("mounted_scoreboard_layout_catalog")
	legacy.career.assets.erase("pool_catalog")
	legacy.career.assets.erase("pool_layout_catalog")
	_check(legacy.career.assets.size() == 4 and legacy.career.assets.has_all(
		["version", "seed", "catalog", "events"]), "v1 fixture has exactly its historical header")
	for field: String in ["pool_catalog", "pool_layout_catalog"]:
		var polluted: Dictionary = legacy.duplicate(true)
		polluted.career.assets[field] = saved.career.assets[field]
		_check(SeasonSave._decode(polluted) == null,
			"v1 cannot smuggle later pool declarations: " + field)
	var migrated: SeasonState = SeasonSave._decode(legacy)
	_check(migrated != null and migrated.career.balance() == 0, "old ledger accepted without debit")
	_check(SeasonSave.save(migrated), "legacy grant committed atomically")
	_check(ClubPlayers.assets(SeasonSave.restore().career).construction().to_data() == stock,
		"no recorded grant earns exactly same three objects once")
	for field: String in ["starter_grant", "starter_catalog", "unknown_ownership"]:
		var bad: Dictionary = SeasonSave.snapshot(migrated)
		bad.career.assets[field] = "unrecognized"
		_check(SeasonSave._decode(bad) == null, "unknown ownership data preserved by rejection")
	for malformed: Variant in [true, 1, {}, null, []]:
		for field: String in ["catalog", "starter_catalog", "draft_catalog", "property_catalog"]:
			var bad: Dictionary = ClubPlayers.assets(season.career).to_data()
			bad[field] = malformed
			_check(ClubAssetLedger.from_data(bad, season.season_seed, [0]) == null,
				"malformed catalog guard cleanly rejects")
	var ledger: ClubAssetLedger = ClubAssetLedger.new(7, [220])
	var open: Dictionary = {"id": "pack", "op": "player_pack_open", "rev": 0,
		"through": 1, "price_version": 1}
	_check(ledger.commit(open).ok, "synthetic paid pack for migration isolation")
	var before: Dictionary = ledger.view()
	var data: Dictionary = ledger.to_data()
	data.version = 1
	data.erase("starter_grant")
	data.erase("starter_catalog")
	data.erase("draft_catalog")
	data.erase("property_catalog")
	data.erase("construction_catalog")
	data.erase("seating_catalog")
	data.erase("seating_layout_catalog")
	data.erase("land_catalog")
	data.erase("style_catalog")
	data.erase("appearance_catalog")
	data.erase("display_catalog")
	data.erase("display_layout_catalog")
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
	_check(data.size() == 4 and data.has_all(["version", "seed", "catalog", "events"]),
		"populated paid-pack v1 header excludes every later declaration")
	var upgraded: ClubAssetLedger = ClubAssetLedger.from_data(data, 7, [220])
	_check(upgraded != null and upgraded.view() == before,
		"legacy paid pack price, choices, ownership and balance remain exact")
	_check(upgraded.construction().copies.size() == 3, "grant does not compete with paid pack choices")
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro stadium grant checks passed: once-only legacy migration and unchanged packs.")
	print("LEGACY_GRANT_RESULT checks=", _legacy_checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)
