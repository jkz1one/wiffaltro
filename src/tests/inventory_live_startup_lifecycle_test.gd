extends "res://src/tests/season_loadout_ui_test.gd"
## A hub entry abandons a real durable attempt; a fresh attempt must be opened after it.

func _ready() -> void:
	var retained: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--retained="):
			retained = arg.trim_prefix("--retained=")
	SeasonSave.path = "user://live-startup-lifecycle.json"
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	var season: SeasonState = SeasonSave._decode(
		JSON.parse_string(FileAccess.get_file_as_string(retained)))
	_check(season != null, "genuine retained round restores")
	if season != null:
		var build: SeasonBuild = season.build
		var game: int = int(season.pending_fixture().id)
		var bank: Dictionary = build._bank.to_data()
		_check(build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game":game})).ok,
			"actual current fixture anchor opens")
		_check(SeasonSave.save(season), "open attempt durable")
		var anchor: Dictionary = SeasonInventoryRules.anchor(build,game)
		_app.season = season
		_app.show_season()
		_check(season.build != build and not SeasonInventoryRules.closed(build)
			and SeasonInventoryRules.closed(season.build),
			"hub swaps Build and closes actual attempt, not stale pointer")
		_check(SeasonPhysicalFixtures.match_for(season,season.pending_fixture()) == null,
			"closed attempt cannot start physical fixture")
		_check(ClubCareer.same(bank,season.build._bank.to_data()), "close pays no money or inventory")
		var cold: SeasonState = SeasonSave.restore()
		_check(cold != null and SeasonInventoryRules.closed(cold.build)
			and ClubCareer.same(SeasonSave.snapshot(cold),SeasonSave.snapshot(season)),
			"closed attempt cold restores exactly")
		_check(season.build.commit(SeasonOpponentPolicy.command(
			season.build,"match_inventory",{"game":game})).ok,
			"same fixture explicitly reopens with a fresh attempt")
		_check(not SeasonInventoryRules.closed(season.build)
			and not ClubCareer.same(anchor,SeasonInventoryRules.anchor(season.build,game)),
			"restart uses new identity")
		_check(SeasonPhysicalFixtures.match_for(season,season.pending_fixture()) != null,
			"fresh attempt physical request admitted without relaxing closed guard")
		_check(ClubCareer.same(bank,season.build._bank.to_data()), "reopen preserves earned bank")
		_check(SeasonSave.save(season), "fresh attempt durable")
		cold = SeasonSave.restore()
		_check(cold != null and not SeasonInventoryRules.closed(cold.build)
			and ClubCareer.same(SeasonSave.snapshot(cold),SeasonSave.snapshot(season)),
			"fresh attempt cold restores exactly")
	_app.queue_free()
	await _frames()
	print("Inventory live startup lifecycle failures: ",_failures)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
