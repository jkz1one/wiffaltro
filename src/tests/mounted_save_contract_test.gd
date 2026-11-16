extends "res://src/tests/stadium_mounted_scoreboard_physical_test.gd"
## Input is disclosed synthetic funded history, captured through ordinary save construction.

func _ready() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		OS.get_environment("MOUNTED_SAVE_FIXTURE")))
	_season = SeasonSave._decode(raw)
	_check(_season != null, "captured full-precision fixture cold-loads")
	if _season == null:
		get_tree().quit(1)
		return
	for fixture: Dictionary in _season.schedule:
		if fixture.home == 0:
			_save_edges(SeasonPhysicalFixtures.match_for(_season, fixture))
			break
	var legacy: Dictionary = raw.duplicate(true)
	legacy.version = 59
	legacy.erase("npc_venues")
	legacy.erase("final_venue")
	var old: SeasonState = SeasonSave._decode(legacy)
	_check(old != null, "legacy no-assignment season cold-loads")
	var away_count: int = 0
	for fixture: Dictionary in _season.schedule:
		if fixture.away != 0:
			continue
		away_count += 1
		var venue: Dictionary = StadiumLayoutSnapshot.for_fixture(_season, fixture)
		_check(StadiumNpcSnapshot.matches_fixture(venue, _season, fixture),
			"away fixture binds exact assigned NPC venue")
		var forged: Dictionary = venue.duplicate(true)
		forged.binding.owner_club = 0
		_check(not StadiumNpcSnapshot.matches_fixture(forged, _season, fixture),
			"home-owner relabel cannot impersonate NPC authority")
		_check(not StadiumNpcSnapshot.matches_fixture(_season.home_property, _season, fixture),
			"owned home entry cannot impersonate away venue")
		if old != null:
			_check(StadiumLayoutSnapshot.for_fixture(old, fixture).is_empty(),
				"historical season without assignments retains empty away route")
	_check(away_count > 0, "away coverage executes")
	print("MOUNTED_SAVE_CONTRACT_RESULT ", JSON.stringify({"checks": _mounted_checks,
		"failures": _failures, "away_fixtures": away_count, "physical_games": 0}))
	get_tree().quit(0 if _failures == 0 else 1)
