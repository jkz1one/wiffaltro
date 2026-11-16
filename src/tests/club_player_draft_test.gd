extends "res://src/tests/club_career_test.gd"
## Current production entry and snapshot access; score-free draft and hostile save checks.


func _ready() -> void:
	SeasonSave.path = "user://owned-draft-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	app.begin_season(443, true)
	var season: SeasonState = app.season
	_check(season != null and season.player_access == ClubPlayerCatalog.initial_owned(),
		"production season starts from twelve owned identities")
	if season == null:
		get_tree().quit(1)
		return
	_check(season.draft_pool.size() == 12, "no locked player in fresh draft")
	for pick in range(4):
		_check(season.offers().size() == 3 and season.offers().all(
			func(id: String) -> bool: return season.player_access.has(id)), "three real owned choices")
		app.choose_player(season.offers()[0])
		season = app.season
		_check(SeasonSave.restore() != null, "every partial draft checkpoint restores")
	var all_ids: Array = []
	for team: Dictionary in season.teams:
		_check(team.roster.size() == 4, "all six clubs have four actual players")
		for id: String in team.roster:
			_check(not all_ids.has(id), "twenty-four distinct league identities")
			all_ids.append(id)
	_check(season.build._pool.size() == 12 and season.build._pool.all(
		func(id: String) -> bool: return season.player_access.has(id)), "owned recruit pool frozen")
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	_check(snapshot.version == 63 and snapshot.opponents.policy == 13,
		"current owned home and neutral-final schema retain physical opponent policy13")
	_check(SeasonSave._decode(snapshot) != null, "owned player and full NPC allocation replay")
	_check(SeasonVenues.matches_season(season) and SeasonFinalVenue.matches_season(season),
		"current NPC and neutral-final assignments match their seed and season")
	var cold: SeasonState = SeasonSave._decode(JSON.parse_string(
		JSON.stringify(snapshot, "", true, true)))
	_check(cold != null and ClubCareer.same(cold.player_access, season.player_access)
		and ClubCareer.same(cold.home_property, season.home_property)
		and ClubCareer.same(cold.npc_venues, season.npc_venues)
		and ClubCareer.same(cold.final_venue, season.final_venue),
		"full-precision cold save retains owned pool and all three venue authorities")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.version = 59
	legacy.erase("npc_venues")
	legacy.erase("final_venue")
	var retained: SeasonState = SeasonSave._decode(JSON.parse_string(
		JSON.stringify(legacy, "", true, true)))
	_check(retained != null and retained.npc_venues.is_empty() and retained.final_venue.is_empty()
		and retained.player_access == season.player_access
		and ClubCareer.same(retained.home_property, season.home_property)
		and retained.opponents._format == 13,
		"historical save59 retains owned home and players without inventing venue assignments")
	var missing: Dictionary = snapshot.duplicate(true)
	missing.erase("npc_venues")
	_check(SeasonSave._decode(missing) == null, "current save cannot erase NPC venue authority")
	missing = snapshot.duplicate(true)
	missing.erase("final_venue")
	_check(SeasonSave._decode(missing) == null, "current save cannot erase neutral-final authority")
	print("OWNED_DRAFT_SCHEMA current=", snapshot.version, " legacy=", legacy.version)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.player_access.append("player.alex_finch")
	bad.player_access.sort()
	_check(SeasonSave._decode(bad) == null, "unknown earned-only entitlement cannot enter draft")
	bad = snapshot.duplicate(true)
	bad.pool.reverse()
	_check(SeasonSave._decode(bad) == null, "owned draft permutation bound to seed and access")
	bad = snapshot.duplicate(true)
	bad.erase("player_access")
	_check(SeasonSave._decode(bad) == null, "new schema cannot erase entitlement snapshot")
	bad = snapshot.duplicate(true)
	bad.version = 57
	_check(SeasonSave._decode(bad) == null, "historical grammar cannot smuggle owned snapshot")
	app.queue_free()
	await get_tree().process_frame
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro owned draft checks passed: twelve starters, separate NPCs and exact saves.")
	get_tree().quit(0 if _failures == 0 else 1)
