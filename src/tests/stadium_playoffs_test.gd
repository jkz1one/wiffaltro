extends "res://src/tests/season_opponent_base_playoffs_test.gd"
## Long physical acceptance: actual production-owned roster and an applied Backyard through33 games.

var _property_key: String = ""


func _permanent_players() -> bool:
	return true


func _home_stadium() -> bool:
	return true


func _prepare_season() -> void:
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}]
	_check(ClubConstruction.save_draft(_app.season, layout, 0).ok, "actual saved home draft")
	_check(ClubConstruction.apply_draft(_app.season, layout, 1).ok, "actual atomic home activation")
	_property_key = StadiumLayoutSnapshot.key(_app.season.home_property)
	_check(not _property_key.is_empty(), "full season has a bound property identity")


func _audit_season() -> void:
	super._audit_season()
	var season: SeasonState = _app.season
	_check(SeasonSave.snapshot(season).version == 59
		and StadiumLayoutSnapshot.key(season.home_property) == _property_key,
		"whole season preserves exact applied home geometry")
	for result: Dictionary in season.player_results:
		_check(result.property == (_property_key if result.home == 0
			and not result.get("neutral", false) else ""), "every played field binds the correct venue")
	var evidence: Dictionary = ClubPlayerProgress.capture(season)
	_check(not evidence.is_empty() and evidence.games.size() == season.player_results.size()
		and ClubCareer.same(evidence, season.career.runs[-1].player_progress),
		"real stadium games retain exact permanent-player unlock evidence")
	_check(ClubPlayers.assets(season.career).construction().copies.size() == 3,
		"home play never duplicates or consumes persistent starter copies")
	print("STADIUM_BRACKET played=", season.player_results.size(),
		" owned=", ClubPlayers.owned(season.career).size(), " field=", _property_key)
