extends "res://src/tests/club_career_test.gd"
## Saved draft-only staging; no live geometry, debit or ownership transfer.


var _legacy_checks: int = 0


func _check(ok: bool, label: String) -> void:
	_legacy_checks += 1
	super._check(ok, label)


func _ready() -> void:
	SeasonSave.path = "user://stadium-draft-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(51, false, true, true)
	season.career = ClubCareer.new()
	_check(season.career.start(season) and SeasonSave.save(season), "new career before drafting")
	var draft: Dictionary = StadiumStarterLayout.empty()
	draft.receiver = "starter-v1:ST-079"
	draft.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
	var before: Dictionary = season.career.to_data()
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/profile.json"
	_check(not ClubConstruction.save_draft(season, draft, 0).ok
		and season.career.to_data() == before, "failed draft save preserves previous profile")
	SeasonSave.path = path
	_check(ClubConstruction.save_draft(season, draft, 0).ok, "draft saved through atomic season file")
	_check(ClubConstruction.save_draft(season, draft, 0).replayed,
		"same request is exactly idempotent")
	_check(season.career.balance() == 0 and season.player_results.is_empty(),
		"draft cannot pay or invent a played game")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(
		ClubPlayers.assets(restored.career).view().stadium_draft, draft), "saved draft resumes unchanged")
	var changed: Dictionary = draft.duplicate(true)
	changed.receiver = ""
	_check(not ClubConstruction.save_draft(season, changed, 0).ok, "conflicting stale draft rejected")
	_check(ClubConstruction.save_draft(season, changed, 1).ok, "new revision saves later draft")
	for pick in range(4):
		season.choose_player(season.offers()[0])
	_check(not ClubConstruction.save_draft(season, draft, 2).ok, "no midseason editor publication")
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var bad: Dictionary = ledger.to_data()
	bad.draft_catalog = "unknown"
	_check(ClubAssetLedger.from_data(bad, 51, [0]) == null,
		"unknown draft grammar preserved by rejection")
	bad = ledger.to_data()
	bad.version = 2
	bad.erase("draft_catalog")
	bad.erase("property_catalog")
	bad.erase("construction_catalog")
	bad.erase("seating_catalog")
	bad.erase("seating_layout_catalog")
	bad.erase("land_catalog")
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
	_check(ClubAssetLedger.from_data(bad, 51, [0]) == null, "old asset grammar cannot smuggle drafts")
	bad = before.assets.duplicate(true)
	bad.version = 2
	bad.erase("draft_catalog")
	bad.erase("property_catalog")
	bad.erase("construction_catalog")
	bad.erase("seating_catalog")
	bad.erase("seating_layout_catalog")
	bad.erase("land_catalog")
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
	_check(bad.size() == 6 and bad.has_all(
		["version", "seed", "catalog", "events", "starter_grant", "starter_catalog"]),
		"v2 fixture retains exactly its grant-only header")
	for field: String in ["pool_catalog", "pool_layout_catalog"]:
		var polluted: Dictionary = bad.duplicate(true)
		polluted[field] = before.assets[field]
		_check(ClubAssetLedger.from_data(polluted, 51, [0]) == null,
			"v2 cannot smuggle later pool declarations: " + field)
	var prior: ClubAssetLedger = ClubAssetLedger.from_data(bad, 51, [0])
	_check(prior != null and prior.view().stadium_draft == StadiumStarterLayout.empty(),
		"prior grant-only asset records migrate to an empty draft, not live geometry")
	var plain: ClubAssetLedger = ClubAssetLedger.new(51, [220])
	var edited: ClubAssetLedger = ClubAssetLedger.new(51, [220])
	for index in range(10):
		_check(edited.commit({"id": "draft:%d" % index, "rev": index,
			"op": "stadium_draft", "layout": draft}).ok, "synthetic free draft history")
	for wallet: ClubAssetLedger in [plain, edited]:
		_check(wallet.commit({"id": "pack", "rev": wallet.revision(), "op": "player_pack_open",
			"through": 1, "price_version": 1}).ok, "identical synthetic paid pack")
	_check(plain.view().pending.choices == edited.view().pending.choices
		and plain.balance() == edited.balance(), "free draft edits cannot reroll or discount packs")
	var paid: Dictionary = edited.view().pending.duplicate(true)
	_check(edited.commit({"id": "after-pack", "rev": edited.revision(),
		"op": "stadium_draft", "layout": changed}).ok and edited.view().pending == paid,
		"draft editing never discards a paid pending player choice")
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro stadium draft checks passed: atomic staging, replay and between-season edits.")
	print("LEGACY_DRAFT_RESULT checks=", _legacy_checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)
