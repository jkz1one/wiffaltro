extends "res://src/tests/season_raincheck_test.gd"


func _ready() -> void:
	SeasonSave.path = "user://transfer-%d.json" % OS.get_process_id()
	_mastery_contract()
	_pair_access()
	var season: SeasonState = _transfer_fixture()
	if season != null:
		_transfer_contract(season)
		await _transfer_ui(season)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Transfer Station checks passed: provenance, personal mastery, replay and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _book_action(
	book: SeasonDevelopment, player: String, op: String, target: String, other: String = ""
) -> void:
	var cmd: Dictionary = {
		"id": "paid-fixture:%d" % book.revision(),
		"rev": book.revision(),
		"player": player,
		"op": op,
		"target": target
	}
	if op == "learn":
		cmd["replace"] = other
	_check(book.commit(cmd).ok, "controlled mastery fixture")


func _mastery_contract() -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("transfer-proof")
	var a: String = "player.alex_finch"
	var b: String = "player.ash_cole"
	_book_action(book, a, "learn", "pitch.drop")
	_book_action(book, b, "learn", "pitch.riser")
	for level in range(3):
		_book_action(book, a, "mastery", "pitch.drop")
	_book_action(book, b, "mastery", "pitch.riser")
	var origin: String = SeasonPitchExchange.learned(book, a)["pitch.drop"]
	var request: Dictionary = {
		"id": "exchange-one",
		"rev": book.revision(),
		"op": "exchange",
		"player": a,
		"other": b,
		"first": "pitch.drop",
		"second": "pitch.riser"
	}
	var before: Dictionary = book.to_data()
	_check(book.preview(request).ok and book.to_data() == before, "two-player preview pure")
	_check(book.commit(request).ok, "exchange learned access")
	_check(
		book.player(a).mastery["pitch.riser"] == 1 and book.player(b).mastery["pitch.drop"] == 1,
		"donor mastery not cloned"
	)
	_check(
		book.player(a).mastery["pitch.drop"] == 4 and book.player(b).mastery["pitch.riser"] == 2,
		"outgoing mastery remembered personally"
	)
	_check(
		SeasonPitchExchange.learned(book, b)["pitch.drop"] == origin,
		"original acquisition follows recipe"
	)
	_check(book.commit(request).replayed, "book retry cannot swap twice")
	request = {
		"id": "exchange-back",
		"rev": book.revision(),
		"op": "exchange",
		"player": a,
		"other": b,
		"first": "pitch.riser",
		"second": "pitch.drop"
	}
	_check(
		(
			book.commit(request).ok
			and book.player(a).mastery["pitch.drop"] == 4
			and book.player(b).mastery["pitch.riser"] == 2
		),
		"later return restores recipient memory"
	)
	var restored: SeasonDevelopment = SeasonDevelopment.from_data(book.to_data(), "transfer-proof")
	_check(
		(
			restored != null
			and restored.player(a) == book.player(a)
			and restored.player(b) == book.player(b)
		),
		"both profiles replay atomically"
	)
	for field: String in ["first", "other", "second"]:
		var bad: Dictionary = {
			"id": "bad",
			"rev": book.revision(),
			"op": "exchange",
			"player": a,
			"other": b,
			"first": "pitch.drop",
			"second": "pitch.riser"
		}
		bad[field] = "pitch.overhand_four_seam" if field != "other" else a
		var state: Dictionary = book.to_data()
		_check(
			not book.commit(bad).ok and book.to_data() == state,
			"invalid exchange mutates neither player"
		)


func _pair_access() -> void:
	# Controlled stock, real paid paired transaction: the two recipients may learn the same recipe.
	var roster: Array[String] = [
		"player.alex_finch", "player.ash_cole", "player.eli_frost", "player.frankie_bell"
	]
	var build: SeasonBuild = SeasonBuild.new(79, roster)
	build._transfer_start = false
	for game in range(3):
		_check(
			build.commit(_command(build, "reward", {"game": game, "win": true})).ok, "pair funds"
		)
	build.commit(_command(build, "open"))
	build._visit.offers = {"tutor": "F04", "lesson": "lesson.pitch.drop"}
	_check(
		build.commit(_command(build, "sponsor_buy", {"offer": "tutor", "replace": ""})).ok,
		"controlled paid Open Book"
	)
	var cmd: Dictionary = _command(
		build,
		"lesson_pair",
		{
			"offer": "lesson",
			"first": {"player": roster[0], "pitch": "", "replace": ""},
			"second": {"player": roster[1], "pitch": "", "replace": ""}
		}
	)
	_check(build.preview(cmd).ok and not build._transfer_earned, "pair preview does not unlock")
	_check(build.commit(cmd).ok and build._transfer_earned, "paid Open Book pair unlocks access")
	_check(
		SeasonTransfer.options(build).is_empty(),
		"same-recipe pair earns access without inventing exchange"
	)


func _transfer_fixture() -> SeasonState:
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._visit.number = 3
	for seed_value in range(4000):
		probe._seed = seed_value
		var count: int = 0
		for id: String in probe._offers(0).values():
			count += int(id.begins_with("lesson."))
		if count < 2:
			continue
		var season: SeasonState = _new_club(seed_value)
		for game in range(3):
			_result(season, [])
		var build: SeasonBuild = season.build
		build.commit(_command(build, "open"))
		var players: Array[String] = []
		for offer: String in build._visit.offers.keys():
			var id: String = build._visit.offers[offer]
			if not id.begins_with("lesson."):
				continue
			for target: Dictionary in build.targets(id):
				if players.has(target.player):
					continue
				var fields: Dictionary = target.duplicate()
				fields.merge({"offer": offer, "mode": "use"})
				if build.commit(_command(build, "buy", fields)).ok:
					players.append(target.player)
					break
		if not build._transfer_earned or SeasonTransfer.options(build).is_empty():
			continue
		_result(season, [])
		build.commit(_command(build, "open"))
		for roll in range(3):
			var offer: String = _offer(build, "F07")
			if not offer.is_empty():
				if build.commit(_command(build, "sponsor_buy", {"offer": offer, "replace": ""})).ok:
					print("TRANSFER_FIXTURE seed=", seed_value, " cash=", build.cash())
					return season
				break
			if not build.commit(_command(build, "reroll")).ok:
				break
	_check(false, "generated paid lessons and earned sponsor reachable")
	return null


func _transfer_contract(season: SeasonState) -> void:
	var build: SeasonBuild = season.build._fork()
	var row: Dictionary = SeasonTransfer.options(build)[0]
	var before: Dictionary = build.to_data()
	var cash: int = build.cash()
	var a: Dictionary = build.player(row.player)
	var b: Dictionary = build.player(row.other)
	var cmd: Dictionary = _command(build, "transfer_pitch", row)
	_check(build.preview(cmd).ok and build.to_data() == before, "shop preview pure")
	_check(build.commit(cmd).ok and build.cash() == cash, "exchange free after paid ownership")
	_check(
		(
			build.player(row.player).active.size() == a.active.size()
			and build.player(row.other).active.size() == b.active.size()
		),
		"no added repertoire slot"
	)
	_check(build.commit(cmd).replayed, "exact retry")
	_check(not build.commit(_command(build, "transfer_pitch", row)).ok, "once per visit")
	var restored: SeasonBuild = SeasonBuild.from_data(
		build.to_data(), build._seed, build._initial_roster, build._pool, build._blocked
	)
	_check(
		(
			restored != null
			and restored.player(row.player) == build.player(row.player)
			and restored.player(row.other) == build.player(row.other)
		),
		"paid build exchange replays"
	)
	var recipes: Array[String] = []
	for pitch: PitchDefinition in build.definition(row.player).starting_pitches:
		recipes.append(str(pitch.id))
	_check(
		recipes.has(row.second) and not recipes.has(row.first),
		"actual match definition uses exchanged recipe"
	)
	var sale: String = SeasonSchoolSponsors.active(build, "F07").id
	_check(
		build.commit(_command(build, "sponsor_sell", {"receipt": sale})).ok,
		"sponsor sells normally"
	)
	_check(
		build._visit.transfer_used and build.player(row.player).active.has(row.second),
		"sale retains completed exchange"
	)
	_check(SeasonSave.save(season), "save earned access")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var bad: Dictionary = data.duplicate(true)
	bad.career.runs[-1].transfer_earned = false
	_check(SeasonSave._decode(bad) == null, "career evidence binds to purchase replay")
	var saved: SeasonState = SeasonSave.restore()
	_check(saved.career.transfer_access() and saved.career.close(saved), "abandon retains access")
	var fresh: SeasonState = _new_club(8921, saved.career)
	_check(
		fresh.build._transfer_start == true and fresh.build.view().wallet.sponsors.is_empty(),
		"access not free ownership"
	)
	var legacy: SeasonState = _new_club(8931)
	legacy.build._format = 24
	legacy.build._transfer_start = null
	legacy.build._supply_start = null
	legacy.build._checkout_start = null
	legacy.build._association_start = null
	legacy.build._freezer_start = null
	legacy.build._sides_start = null
	legacy.build._jump_start = null
	legacy.build._batch_start = null
	legacy.build._sure_start = null
	legacy.build._field_start = null
	legacy.build._copy.start = null
	legacy.build._abilities.start = null
	legacy.build._major.start = null
	legacy.career.runs[-1].transfer_earned = null
	legacy.career.runs[-1].supplies_used = null
	legacy.career.runs[-1].checkout_earned = null
	legacy.career.runs[-1].association_earned = null
	legacy.career.runs[-1].freezer_earned = null
	legacy.career.runs[-1].sides_earned = null
	legacy.career.runs[-1].jump_earned = null
	legacy.career.runs[-1].batch_used = null
	legacy.career.runs[-1].sure_earned = null
	legacy.career.runs[-1].field_outs = null
	legacy.career.runs[-1].copy_earned = null
	legacy.career.runs[-1].sky_outs = null
	legacy.career.runs[-1].major_earned = null
	_check(SeasonSave.save(legacy), "legacy build24 saves")
	data = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 5
	for historical: Dictionary in data.career.runs:
		historical.erase("collection")
	data.career.runs[-1].erase("transfer_earned")
	data.career.runs[-1].erase("supplies_used")
	data.career.runs[-1].erase("checkout_earned")
	data.career.runs[-1].erase("association_earned")
	data.career.runs[-1].erase("freezer_earned")
	data.career.runs[-1].erase("sides_earned")
	data.career.runs[-1].erase("jump_earned")
	data.career.runs[-1].erase("batch_used")
	data.career.runs[-1].erase("sure_earned")
	data.career.runs[-1].erase("field_outs")
	data.career.runs[-1].erase("copy_earned")
	data.career.runs[-1].erase("sky_outs")
	data.career.runs[-1].erase("major_earned")
	var migrated: SeasonState = SeasonSave._decode(data)
	_check(
		migrated != null and migrated.build._transfer_start == null,
		"legacy migration does not invent progress"
	)
	_check(
		SeasonSave.save(migrated) and SeasonSave.restore() != null, "career6 migration roundtrip"
	)


func _transfer_ui(season: SeasonState) -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	_check(SeasonSave.save(season), "save paid UI fixture")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _click(_button(window, "TRANSFER STATION • EXCHANGE PITCHES"))
	await _shop_bounds(window, "transfer-select")
	var before: Dictionary = app.season.build.to_data()
	await _click(_button(window, "REVIEW EXCHANGE"))
	_check(
		window._review_text.text.contains("repertoire sizes stay fixed"),
		"review includes both player consequences"
	)
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "cancel changes neither player")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_button(window, "REVIEW EXCHANGE"))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		app.season.build.to_data() == before and FileAccess.get_file_as_string(path) == bytes,
		"failed save rolls back both players and use flag"
	)
	await _click(_button(window, "TRANSFER STATION • EXCHANGE PITCHES"))
	await _click(_button(window, "REVIEW EXCHANGE"))
	await _click(window._confirm.get_ok_button())
	_check(app.season.build._visit.transfer_used, "UI exchange committed")
	_check(
		ClubCareer.same(SeasonSave.restore().build.to_data(), app.season.build.to_data()),
		"exchange reloads exactly"
	)
	await _shop_bounds(window, "transfer-result")
	await _click(window._back)
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "transfer-progress")
	app.play_season_game()
	await _frames()
	_check(app.lab != null, "exchanged roster launches actual match")
	app.leave_game()
	await _frames()
	_check(SeasonSave.restore().build._visit.transfer_used, "restart cannot reset exchange")
	app.queue_free()
	await _frames()
