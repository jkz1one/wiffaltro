extends "res://src/tests/physical_round_process_ui_test.gd"
## Real away/home games and child-process failure/restart with immutable schema59 geometry.

var _property_key: String = ""


func _permanent_players() -> bool:
	return true


func _prepare_season() -> void:
	_retain_historical_venues(_app, _check)
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}]
	_check(ClubConstruction.save_draft(_app.season, layout, 0).ok, "owned home draft saved")
	_check(ClubPlayers.transact(_app.season, {"id": "property:apply", "rev": 1,
		"op": "stadium_apply", "geometry": StadiumProperty.signature("backyard"),
		"layout": layout}).ok, "owned layout enters its persistent journal")
	_app.season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(_app.season.career))
	_property_key = StadiumLayoutSnapshot.key(_app.season.home_property)
	_check(SeasonSave.save(_app.season), "property snapshot persists before the first draft pick")


func _audit_season() -> void:
	super._audit_season()
	var season: SeasonState = _app.season
	_check(SeasonSave.snapshot(season).version == 59
		and StadiumLayoutSnapshot.key(season.home_property) == _property_key,
		"saved and restarted season keeps exact home geometry")
	for result: Dictionary in season.player_results:
		_check(result.property == (_property_key if result.home == 0 else ""),
			"human result binds home geometry while away results retain the park")
	var saved: Dictionary = SeasonSave.snapshot(season)
	var bad: Dictionary = saved.duplicate(true)
	bad.results[-1].property = "wrong-played-field"
	_check(SeasonSave._decode(bad) == null, "result from another layout cannot be replayed")
	bad = saved.duplicate(true)
	bad.results[-1].erase("property")
	_check(SeasonSave._decode(bad) == null, "new-schema human result cannot omit its played field")
	bad = saved.duplicate(true)
	bad.home_property.layout.receiver = ""
	_check(SeasonSave._decode(bad) == null, "saved field cannot detach a previously played receiver")
	print("STADIUM_SEASON games=", season.player_results.size(), " field=", _property_key)


func _home_stadium() -> bool:
	return true


func _killed_child() -> void:
	# Never pass PID0 to the inherited external-termination probe after admission failure.
	if not _app.round_ui.process_runner.running or _app.round_ui.process_runner._pid <= 0:
		_check(false, "kill probe requires this test's running positive child PID")
		get_tree().quit(1)
		return
	await super._killed_child()


func _retain_historical_venues(app: SeasonApp, check: Callable) -> void:
	# This process test explicitly qualifies legacy park and owned-starter reports.
	# Current NPC human settlement has its own terminal-evidence contract: never synthesize it
	# from an automated preparation report. Exercise the supported historical save59 profile.
	var current: Dictionary = SeasonSave.snapshot(app.season)
	check.call(current.version == 63 and not app.season.npc_venues.is_empty()
		and not app.season.final_venue.is_empty(), "current startup freezes both venue authorities")
	var cold: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(current, "", true, true)))
	check.call(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), current),
		"current63 fixture cold-reloads before explicit historical projection")
	for field: String in ["npc_venues", "final_venue"]:
		var bad: Dictionary = current.duplicate(true)
		bad.erase(field)
		check.call(SeasonSave._decode(bad) == null,
			"current63 cannot silently drop frozen venue authority: " + field)
	var legacy: Dictionary = current.duplicate(true)
	legacy.version = 59
	legacy.erase("npc_venues")
	legacy.erase("final_venue")
	var restored: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(legacy, "", true, true)))
	check.call(restored != null, "historical starter process fixture decodes exact save59")
	for field: String in ["npc_venues", "final_venue"]:
		var smuggled: Dictionary = legacy.duplicate(true)
		smuggled[field] = current[field]
		check.call(SeasonSave._decode(smuggled) == null,
			"historical59 rejects later venue authority smuggling: " + field)
	if restored == null:
		return
	check.call(restored.npc_venues.is_empty() and restored.final_venue.is_empty()
		and ClubCareer.same(restored.home_property, app.season.home_property)
		and ClubCareer.same(restored.career.to_data(), app.season.career.to_data())
		and ClubCareer.same(restored.schedule, app.season.schedule),
		"legacy59 preserves exact owned home, paid/earned career and schedule without venues")
	check.call(SeasonSave.save(restored), "explicit historical fixture persists through public save")
	app.season = restored
