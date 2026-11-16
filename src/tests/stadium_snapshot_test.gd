extends "res://src/tests/club_career_test.gd"
## Versioned field snapshots and prefix binding, before runtime/season activation is exposed.


var _legacy_checks: int = 0


func _check(ok: bool, label: String) -> void:
	_legacy_checks += 1
	super._check(ok, label)


func _ready() -> void:
	SeasonSave.path = "user://stadium-snapshot-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(51, true, true, false)
	var season: SeasonState = app.season
	_check(SeasonSave.snapshot(season).version == 58,
		"existing owned season stays historically shaped")
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var initial: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(StadiumLayoutSnapshot.matches(initial, ledger), "initial empty owned layout binds")
	season.home_property = initial.duplicate(true)
	_check(SeasonSave.save(season), "explicit property snapshot persists under schema59")
	var saved: Dictionary = SeasonSave.snapshot(season)
	_check(saved.version == 59 and saved.player_access == season.player_access,
		"new schema retains owned-player access")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.home_property == initial, "exact snapshot survives reload")
	_check(restored != null and StadiumLayoutSnapshot.key(restored.home_property)
		== StadiumLayoutSnapshot.key(initial), "JSON numeric decoding preserves physical identity")
	var draft: Dictionary = StadiumStarterLayout.empty()
	draft.receiver = "starter-v1:ST-079"
	draft.obstacles = [{"copy": "starter-v1:ST-003", "site": "O-R2", "yaw": 270}]
	_check(ClubConstruction.save_draft(season, draft, ledger.revision()).ok,
		"stage a new owned layout")
	ledger = ClubPlayers.assets(season.career)
	var apply: Dictionary = {"id": "apply:1", "rev": ledger.revision(), "op": "stadium_apply",
		"layout": draft, "geometry": StadiumProperty.signature("backyard")}
	var invalid: Dictionary = apply.duplicate(true)
	invalid.geometry = "unrecognized"
	_check(not ledger.commit(invalid).ok, "reject mismatched geometry contract")
	invalid = apply.duplicate(true)
	invalid.layout.receiver = ""
	_check(not ledger.commit(invalid).ok, "apply cannot silently replace the saved draft")
	_check(ClubPlayers.transact(season, apply).ok, "journal records an owned active layout")
	_check(ClubPlayers.transact(season, apply).replayed, "same activation receipt is idempotent")
	ledger = ClubPlayers.assets(season.career)
	_check(StadiumLayoutSnapshot.matches(initial, ledger) and season.home_property == initial,
		"later asset edits cannot mutate an already captured season field")
	var next: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(next.layout == draft and next.revision == 2 and next != initial,
		"next snapshot uses the new committed layout")
	_check(StadiumLayoutSnapshot.key(next) != StadiumLayoutSnapshot.key(initial),
		"physical identity changes with exact field snapshot")
	_check(StadiumLayoutSnapshot.for_fixture(season, {"home": 1, "away": 0}).is_empty()
		and StadiumLayoutSnapshot.for_fixture(season, {"home": 0, "neutral": true}).is_empty(),
		"away and neutral fixtures never receive the club's home geometry")
	_check(StadiumLayoutSnapshot.for_fixture(season, {"home": 0}) == initial,
		"home fixture receives frozen season geometry")
	for field: String in ["version", "tier", "geometry", "revision", "layout"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.home_property[field] = false
		_check(SeasonSave._decode(bad) == null, "reject malformed saved property " + field)
	var bad: Dictionary = saved.duplicate(true)
	bad.version = 58
	_check(SeasonSave._decode(bad) == null, "old grammar cannot smuggle a field snapshot")
	bad = saved.duplicate(true)
	bad.erase("home_property")
	_check(SeasonSave._decode(bad) == null, "new grammar requires the field snapshot")
	bad = saved.duplicate(true)
	bad.home_property.revision = 4096
	_check(SeasonSave._decode(bad) == null, "snapshot cannot refer to uncommitted ownership history")
	bad = saved.duplicate(true)
	bad.home_property.layout = draft
	_check(SeasonSave._decode(bad) == null, "valid geometry still needs its exact ownership prefix")
	var older: Dictionary = ledger.to_data()
	older.version = 3
	older.erase("property_catalog")
	older.erase("construction_catalog")
	older.erase("seating_catalog")
	older.erase("seating_layout_catalog")
	older.erase("land_catalog")
	older.erase("style_catalog")
	older.erase("appearance_catalog")
	older.erase("display_catalog")
	older.erase("display_layout_catalog")
	older.erase("ground_catalog")
	older.erase("ground_layout_catalog")
	older.erase("bleacher_catalog")
	older.erase("bleacher_layout_catalog")
	older.erase("target_catalog")
	older.erase("target_layout_catalog")
	older.erase("net_catalog")
	older.erase("net_layout_catalog")
	older.erase("light_catalog")
	older.erase("light_layout_catalog")
	older.erase("infield_catalog")
	older.erase("infield_layout_catalog")
	older.erase("wall_catalog")
	older.erase("wall_layout_catalog")
	older.erase("surface_catalog")
	older.erase("surface_layout_catalog")
	older.erase("surface_origin")
	older.erase("wall_piece_catalog")
	older.erase("advanced_layout_catalog")
	older.erase("scoreboard_catalog")
	older.erase("scoreboard_layout_catalog")
	older.erase("mounted_scoreboard_layout_catalog")
	older.erase("pool_catalog")
	older.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(older, 51, [0]) == null,
		"old asset grammar cannot smuggle active layout operations")
	var empty_old: ClubAssetLedger = ClubAssetLedger.new(51, [0])
	older = empty_old.to_data()
	older.version = 3
	older.erase("property_catalog")
	older.erase("construction_catalog")
	older.erase("seating_catalog")
	older.erase("seating_layout_catalog")
	older.erase("land_catalog")
	older.erase("style_catalog")
	older.erase("appearance_catalog")
	older.erase("display_catalog")
	older.erase("display_layout_catalog")
	older.erase("ground_catalog")
	older.erase("ground_layout_catalog")
	older.erase("bleacher_catalog")
	older.erase("bleacher_layout_catalog")
	older.erase("target_catalog")
	older.erase("target_layout_catalog")
	older.erase("net_catalog")
	older.erase("net_layout_catalog")
	older.erase("light_catalog")
	older.erase("light_layout_catalog")
	older.erase("infield_catalog")
	older.erase("infield_layout_catalog")
	older.erase("wall_catalog")
	older.erase("wall_layout_catalog")
	older.erase("surface_catalog")
	older.erase("surface_layout_catalog")
	older.erase("surface_origin")
	older.erase("wall_piece_catalog")
	older.erase("advanced_layout_catalog")
	older.erase("scoreboard_catalog")
	older.erase("scoreboard_layout_catalog")
	older.erase("mounted_scoreboard_layout_catalog")
	older.erase("pool_catalog")
	older.erase("pool_layout_catalog")
	_check(older.size() == 7 and older.has_all(
		["version", "seed", "catalog", "events", "starter_grant", "starter_catalog", "draft_catalog"]),
		"v3 fixture retains exactly its draft-era header")
	for field: String in ["pool_catalog", "pool_layout_catalog"]:
		var polluted: Dictionary = older.duplicate(true)
		polluted[field] = empty_old.to_data()[field]
		_check(ClubAssetLedger.from_data(polluted, 51, [0]) == null,
			"v3 cannot smuggle later pool declarations: " + field)
	var migrated: ClubAssetLedger = ClubAssetLedger.from_data(older, 51, [0])
	_check(migrated != null and migrated.view().stadium_active == StadiumStarterLayout.empty(),
		"old drafts migrate without silently activating geometry")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro stadium snapshot checks passed: exact ownership prefixes and frozen fields.")
	print("LEGACY_SNAPSHOT_RESULT checks=", _legacy_checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)
