extends "res://src/tests/club_career_test.gd"
## Synthetic match results, real career validation and atomic shared-wallet transactions.


func _ready() -> void:
	SeasonSave.path = "user://seating-purchases-%d.json" % OS.get_process_id()
	var season: SeasonState = _new()
	_finish(season, "champion")
	_check(SeasonSave.save(season), "first complete career proof")
	_check(StadiumCareerProgress.capture(season.career) == [{"seasons": 1, "wins": 10}],
		"stadium progress excludes both playoff wins from the regular-season W gate")
	_check(not ClubConstruction.buy_copy(season, "ST-080", 1).ok,
		"money alone cannot bypass the two-season seating requirement")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "close first season")
	season = _new(52, club)
	_finish(season, "champion")
	_check(SeasonSave.save(season), "second complete career proof")
	var initial: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(initial.revision() == 2 and initial.to_data().events.all(
		func(event: Dictionary) -> bool: return event.op == "stadium_pennant"),
		"two championships journal two legitimate pennants before purchases")
	var before: Dictionary = SeasonSave.snapshot(season)
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(not ClubConstruction.buy_copy(season, "ST-080", 0).ok
		and ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes,
		"obsolete pre-award revision cannot purchase or mutate durable history")
	SeasonSave.path = path + "/missing/file.json"
	_check(not ClubConstruction.buy_copy(season, "ST-080", 2).ok
		and ClubCareer.same(before, SeasonSave.snapshot(season)), "failed purchase is atomic")
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == bytes, "failed purchase preserves saved bytes")
	_check(ClubConstruction.buy_copy(season, "ST-080", 2).ok
		and season.career.balance() == 225, "first spectator chair costs 150 blueprint plus 40 copy")
	_check(ClubConstruction.buy_copy(season, "ST-080", 2).replayed
		and season.career.balance() == 225, "double activation never repays the blueprint or copy")
	_check(ClubConstruction.buy_copy(season, "ST-080", 3).ok
		and season.career.balance() == 185, "next chair costs only its 40-CB copy price")
	_check(not ClubConstruction.buy_copy(season, "ST-027", 4).ok,
		"bleacher needs three complete seasons")
	club = season.career.fork()
	_check(club.close(season), "close second season")
	season = _new(53, club)
	_finish(season, "champion")
	_check(SeasonSave.save(season), "third complete career proof")
	_check(not ClubConstruction.buy_copy(season, "ST-027", 5).ok
		and season.career.balance() == 380, "unlocked item still requires its whole blueprint/copy cost")
	club = season.career.fork()
	_check(club.close(season), "close third season")
	season = _new(54, club)
	_finish(season, "champion")
	_check(SeasonSave.save(season), "fourth complete career proof")
	_check(ClubConstruction.buy_copy(season, "ST-027", 6).ok
		and season.career.balance() == 175, "bleacher uses same wallet and costs 300 plus 100")
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(ledger.construction().copies.size() == 10
		and ledger.view().stadium_active == StadiumStarterLayout.empty(),
		"three paid plus three starter plus four earned pennants stay stored without automatic placement")
	var events: Array = ledger.to_data().events
	_check(events.filter(func(event: Dictionary) -> bool:
		return event.op == "stadium_pennant").size() == 4
		and events.filter(func(event: Dictionary) -> bool:
		return event.op == "stadium_buy").size() == 3
		and ClubCareer.same(events.slice(0, 2), initial.to_data().events),
		"four earned awards and three exact paid copies retain original award prefix")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(ledger.to_data(),
		ClubPlayers.assets(restored.career).to_data()),
		"real save restores exact purchase/progress epochs")
	_tamper_seating(ledger, season.career)
	_progress_prefix(season)
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro seating purchase checks passed: career gates, shared wallet and exact replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _tamper_seating(ledger: ClubAssetLedger, career: ClubCareer) -> void:
	var progress: Array = StadiumCareerProgress.capture(career)
	for patch: Dictionary in [{"progress_through": 1}, {"progress_through": 99},
		{"progress_through": true}, {"progress_through": 2.5}, {"price_version": 1},
		{"item": "ST-028"}, {"progress": {"seasons": 99, "wins": 99}}]:
		var command: Dictionary = {"id": "bad", "rev": ledger.revision(), "op": "stadium_buy",
			"through": 4, "progress_through": 4, "price_version": 2, "item": "ST-080", "quantity": 1}
		command.merge(patch, true)
		var before: Dictionary = ledger.to_data()
		_check(not ledger.commit(command).ok and ledger.to_data() == before,
			"forged, stale or unsupported progress purchase rejects without mutation")
	var data: Dictionary = ledger.to_data()
	_check(data.events[2].op == "stadium_buy", "progress tamper targets first paid purchase")
	data.events[2].progress_through = 1
	_check(ClubAssetLedger.from_data(data, 51, ClubPlayers.income(career), progress) == null,
		"later-earned progress cannot retroactively authorize an earlier locked purchase")
	data = ledger.to_data()
	data.version = 5
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
	_check(ClubAssetLedger.from_data(data, 51, ClubPlayers.income(career), progress) == null,
		"old ledger cannot smuggle a new seating purchase")
	data = ledger.to_data()
	_check(ClubAssetLedger.from_data(data, 51, ClubPlayers.income(career)) == null,
		"credits without authoritative progress do not restore seating")
	_check(ledger.prefix(3) != null and ledger.fork() != null,
		"exact prefix and fork retain original progress context")


func _progress_prefix(season: SeasonState) -> void:
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "close completed run before abandonment probe")
	var active: SeasonState = _new(55, club)
	_record(active)
	_check(SeasonSave.save(active), "one actual win recorded in active run")
	var before: Array = StadiumCareerProgress.capture(active.career)
	_check(before.size() == 4, "active run does not enter an immutable purchasing prefix")
	club = active.career.fork()
	_check(club.close(active), "abandoned run preserves completed-match results")
	var after: Array = StadiumCareerProgress.capture(club)
	_check(after.size() == 5 and after[-1] == {"seasons": 0, "wins": 1}
		and ClubPlayers.income_through(club) == 4, "abandonment keeps win, adds no season or money")
	_check(ClubPlayers.assets(club) != null, "later closed progress preserves earlier purchase replay")
