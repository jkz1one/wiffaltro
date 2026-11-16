extends "res://src/tests/club_career_test.gd"
## Atomic active geometry, no-charge storage, old-save boundary and next-season inheritance.


func _ready() -> void:
	SeasonSave.path = "user://stadium-apply-%d.json" % OS.get_process_id()
	var path: String = SeasonSave.path
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(51, true)
	var season: SeasonState = app.season
	var current: Dictionary = SeasonSave.snapshot(season)
	_check(current.version == 63
		and season.home_property.layout.obstacles.is_empty(),
		"new Working club starts with a functional empty home template")
	var legacy: Dictionary = current.duplicate(true)
	legacy.version = 59
	legacy.erase("npc_venues")
	legacy.erase("final_venue")
	var historical: SeasonState = SeasonSave._decode(JSON.parse_string(
		JSON.stringify(legacy, "", true, true)))
	_check(historical != null and historical.npc_venues.is_empty()
		and historical.final_venue.is_empty()
		and ClubCareer.same(historical.home_property, season.home_property),
		"supported historical59 retains exact home without inventing later venues")
	for authority: String in ["npc_venues", "final_venue"]:
		var missing: Dictionary = current.duplicate(true)
		missing.erase(authority)
		_check(SeasonSave._decode(missing) == null, "current63 requires each frozen venue authority")
		var smuggled: Dictionary = legacy.duplicate(true)
		smuggled[authority] = current[authority]
		_check(SeasonSave._decode(smuggled) == null, "historical59 refuses later authority smuggling")
	var draft: Dictionary = StadiumStarterLayout.empty()
	draft.receiver = "starter-v1:ST-079"
	draft.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L2", "yaw": 0}]
	_check(ClubConstruction.save_draft(season, draft, 0).ok, "owned draft staged")
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/file.json"
	_check(not ClubConstruction.apply_draft(season, draft, 1).ok
		and ClubCareer.same(before, SeasonSave.snapshot(season)),
		"failed Apply publishes neither geometry nor journal mutation")
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == bytes, "failed Apply preserves saved bytes")
	_check(ClubConstruction.apply_draft(season, draft, 1).ok, "same failed request can retry")
	_check(ClubConstruction.apply_draft(season, draft, 1).replayed,
		"repeat Apply is the same receipt, not a second action")
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	_check(ClubPlayers.assets(season.career).revision() == 2 and season.career.balance() == 0
		and ClubCareer.same(season.home_property.layout, draft), "field and assets commit together once")
	_check(SeasonSave.restore() != null
		and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"applied field restores exactly")
	var stored: Dictionary = draft.duplicate(true)
	stored.receiver = ""
	_check(ClubConstruction.save_draft(season, stored, 2).ok, "move receiver into draft storage")
	_check(not ClubConstruction.apply_draft(season, stored, 1).ok
		and StadiumLayoutSnapshot.key(season.home_property) == key, "stale conflicting Apply rejected")
	_check(ClubConstruction.apply_draft(season, stored, 3).ok, "current storage plan applies free")
	_check(ClubPlayers.assets(season.career).construction().copies.size() == 3
		and season.career.balance() == 0 and season.home_property.layout.receiver == "",
		"stored copy remains owned with no refund or replacement grant")
	app.choose_player(app.season.offers()[0])
	key = StadiumLayoutSnapshot.key(season.home_property)
	_check(not ClubConstruction.apply_draft(season, draft, 4).ok
		and StadiumLayoutSnapshot.key(season.home_property) == key,
		"first draft pick locks home geometry")
	SeasonSave.path = path + "/missing/file.json"
	app.begin_season(61, true)
	_check(app.season == season and StadiumLayoutSnapshot.key(season.home_property) == key,
		"failed next-season checkpoint preserves current club and field")
	SeasonSave.path = path
	app.begin_season(61, true)
	_check(app.season != season and ClubCareer.same(app.season.home_property.layout, stored)
		and ClubPlayers.assets(app.season.career).construction().copies.size() == 3,
		"next Working season inherits the active layout without duplicating owned objects")
	app.begin_season(71, true, true, false)
	_check(SeasonSave.snapshot(app.season).version == 58 and app.season.home_property.is_empty(),
		"explicit historical ownership season retains its old field")
	app.choose_player(app.season.offers()[0])
	_check(not ClubConstruction.apply_draft(app.season, stored, 4).ok
		and app.season.home_property.is_empty(), "old in-progress season is not silently remodeled")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro stadium apply checks passed: atomic publication, storage and season locking.")
	get_tree().quit(0 if _failures == 0 else 1)
