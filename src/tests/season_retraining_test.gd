extends "res://src/tests/season_earned_sponsor_test.gd"

var _retraining_fixture: Dictionary = {}


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://retraining-%d.json" % OS.get_process_id()
	_ledger()
	var season: SeasonState = _paid_retraining()
	if season != null:
		_paid_contract(season)
		_migration()
		_sponsor_adapters()
		await _retraining_ui()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro retraining checks passed: earned points, paid offers, replay, migration and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _growth(book: SeasonDevelopment, player: String, op: String, target: String) -> void:
	_check(
		(
			book
			. commit(
				{
					"id": "fixture:%d" % book.revision(),
					"rev": book.revision(),
					"op": op,
					"player": player,
					"target": target
				}
			)
			. ok
		),
		"isolated development fixture"
	)


func _move(book: SeasonDevelopment, player: String, remove: Array, add: Array) -> Dictionary:
	return {
		"id": "move:%d" % book.revision(),
		"rev": book.revision(),
		"op": "retrain",
		"player": player,
		"remove": remove,
		"add": add
	}


func _ledger() -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("retraining-unit")
	var player: String = "player.alex_finch"
	_growth(book, player, "recruit", "middle")
	var joined: Dictionary = book.player(player)
	_check(SeasonRetraining.choices(book, player).is_empty(), "recruit catch-up is not movable")
	_growth(book, player, "stat", "fielding")
	_growth(book, player, "stat", "fielding")
	var mastery: Dictionary = book.player(player).mastery
	var total: int = SeasonRetraining.count(book)
	var trained: Array = book.earned_players([player])
	var move: Dictionary = _move(book, player, ["fielding", "fielding"], ["contact", "power"])
	_check(book.commit(move).ok, "split two trained points into two destinations")
	_check(book.player(player).stats.fielding == joined.stats.fielding, "catch-up remains intact")
	_check(
		book.player(player).stats.contact == joined.stats.contact + 1, "first destination gains one"
	)
	_check(
		book.player(player).stats.power == joined.stats.power + 1, "second destination gains one"
	)
	_check(
		book.player(player).mastery == mastery and book.player(player).base == joined.base,
		"mastery and authored baseline stay unchanged"
	)
	_check(
		SeasonRetraining.count(book) == total and book.earned_players([player]) == trained,
		"no extra training points or trained-player credit"
	)
	_check(book.commit(move).replayed, "exact request is idempotent")
	var data: Dictionary = book.to_data()
	for changes: Dictionary in [
		{"remove": ["fielding", "fielding"], "add": ["contact", "contact"]},
		{"remove": ["contact", "power"], "add": ["contact", "pitching"]},
		{"remove": ["contact"], "add": ["fielding", "fielding"]},
		{"remove": ["contact", "power"], "add": ["mastery", "pitching"]},
		{"remove": ["contact", "power"], "add": ["pitching", 1]}
	]:
		var bad: Dictionary = _move(book, player, changes.remove, changes.add)
		_check(
			not book.commit(bad).ok and book.to_data() == data, "invalid redistribution is atomic"
		)
	var back: Dictionary = _move(book, player, ["contact", "power"], ["fielding", "fielding"])
	_check(book.commit(back).ok, "moved points remain movable on this same season instance")
	while book.player(player).stats.power < 9:
		_growth(book, player, "stat", "power")
	_check(
		not book.commit(_move(book, player, ["fielding", "fielding"], ["power", "power"])).ok,
		"destination nine cannot receive two"
	)
	var restored: SeasonDevelopment = SeasonDevelopment.from_data(book.to_data(), "retraining-unit")
	_check(
		restored != null and restored.player(player) == book.player(player),
		"exact provenance replay"
	)
	var fork: SeasonDevelopment = book.fork()
	_growth(fork, player, "stat", "power")
	_check(book.player(player).stats.power == 9, "fork owns independent profiles and events")


func _paid_retraining() -> SeasonState:
	if not _retraining_fixture.is_empty():
		return SeasonSave._decode(_retraining_fixture)
	for seed_value in range(100):
		var season: SeasonState = _new_club(seed_value)
		for game in range(6):
			_record(season)
			var build: SeasonBuild = season.build
			_check(build.commit(_command(build, "open")).ok, "open actual scheduled shop")
			for attempt in range(4):
				for offer: String in build._visit.offers.keys():
					var item: String = build._visit.offers[offer]
					if SeasonRetraining.count(build._book) >= 4 or build.cash() < 6:
						break
					if DevelopmentShopCatalog.item(item).get("op") != "stat":
						continue
					var stock: Dictionary = build._visit.offers.duplicate()
					_check(
						(
							build
							. commit(
								_command(
									build,
									"buy",
									{
										"offer": offer,
										"mode": "use",
										"player": season.picks[0],
										"pitch": "",
										"replace": ""
									}
								)
							)
							. ok
						),
						"pay for one real offered broad-stat point"
					)
					stock.erase(offer)
					_check(
						stock == build._visit.offers,
						"earning access does not replace displayed stock"
					)
					if SeasonRetraining.count(build._book) < 4:
						_check(
							SeasonRetraining.pool(build).is_empty(),
							"four applied paid points required"
						)
				if not _offer(build, SeasonRetraining.ID).is_empty() and build.cash() >= 8:
					_check(
						SeasonSave.save(season),
						"save actual paid training and offered transformation"
					)
					_retraining_fixture = JSON.parse_string(
						FileAccess.get_file_as_string(SeasonSave.path)
					)
					print("RETRAINING_FIXTURE seed=", seed_value, " visit=", build._visit.number)
					return season
				if attempt < 3 and build.cash() >= SeasonReclamation.price(build._visit) + 8:
					_check(build.commit(_command(build, "reroll")).ok, "pay ordinary reroll")
				else:
					break
	_check(false, "find real generated Retraining Camp stock")
	return null


func _purchase(build: SeasonBuild) -> Dictionary:
	var player: String = SeasonRetraining.targets(build)[0]
	var choice: Dictionary = SeasonRetraining.choices(build._book, player)[0]
	return _command(
		build,
		"retrain_buy",
		{
			"offer": _offer(build, SeasonRetraining.ID),
			"player": player,
			"remove": choice.remove,
			"add": choice.add
		}
	)


func _paid_contract(season: SeasonState) -> void:
	var build: SeasonBuild = season.build
	var before: Dictionary = build.to_data()
	var command: Dictionary = _purchase(build)
	for patch: Dictionary in [
		{"player": "player.foreign"},
		{"offer": "foreign"},
		{"remove": ["contact"]},
		{"add": ["mastery", "pitching"]},
		{"remove": command.add, "add": command.add}
	]:
		var bad: Dictionary = command.duplicate(true)
		bad.merge(patch, true)
		_check(
			not build.commit(bad).ok and build.to_data() == before,
			"invalid paid transformation preserves cash, stock and growth"
		)
	var cash: int = build.cash()
	var total: int = SeasonRetraining.count(build._book)
	var trained: Array = build._book.earned_players(build.roster())
	var match_before: MatchState = season.make_match()
	var pitcher: PlayerMatchState = match_before.pitcher()
	pitcher.spend_stamina(12)
	var stamina: float = pitcher.stamina_remaining
	_check(
		build.preview(command).ok and build.to_data() == before,
		"preview spends and changes nothing"
	)
	_check(build.commit(command).ok and build.cash() == cash - 8, "one full-price transformation")
	_check(
		(
			SeasonRetraining.count(build._book) == total
			and build._book.earned_players(build.roster()) == trained
		),
		"no growth reward or trained-player inflation"
	)
	_check(pitcher.stamina_remaining == stamina, "no retroactive workload refill")
	_check(
		build.commit(command).replayed and build.cash() == cash - 8,
		"purchase retry cannot double pay"
	)
	_check(SeasonSave.save(season), "save transformed paid season")
	var loaded: SeasonState = SeasonSave.restore()
	_check(
		(
			loaded != null
			and (
				JSON.parse_string(JSON.stringify(loaded.build.to_data()))
				== JSON.parse_string(JSON.stringify(build.to_data()))
			)
		),
		"exact build and career reconstruction"
	)
	var state: MatchState = loaded.make_match()
	var team: TeamMatchState = (
		state.home_team if loaded.pending_fixture().home == 0 else state.away_team
	)
	for runtime: PlayerMatchState in team.roster:
		var profile: Dictionary = loaded.build.player(String(runtime.definition.id))
		_check(
			(
				SeasonPlayerCard.values(runtime.definition)
				== [
					profile.stats.contact,
					profile.stats.power,
					profile.stats.fielding,
					profile.stats.pitching
				]
			),
			"all four runtime ratings use transformed profile"
		)
	var forged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	forged.build.events[-1].add = ["pitching", "pitching", "pitching"]
	_check(SeasonSave._decode(forged) == null, "forged extra points reject whole save")
	for card: String in build._visit.cards:
		_check(card != SeasonRetraining.ID, "development packs never contain transformations")


func _migration() -> void:
	var season: SeasonState = _paid_retraining()
	# Genuine old-format journal, before the first new-category offer was generated.
	var old: SeasonState = _new_club(67)
	old.build._format = 37
	_record(old)
	old.build.commit(_command(old.build, "open"))
	var stock: Dictionary = old.build.view().shop
	_check(SeasonSave.save(old), "Build37 save")
	var loaded: SeasonState = SeasonSave.restore()
	_check(
		loaded != null and not loaded.build._retraining_enabled,
		"older active runs remain prospective"
	)
	_check(loaded.build.view().shop == stock, "old stock and receipts remain exact")
	_check(
		SeasonSave.save(loaded) and not SeasonSave.restore().build._retraining_enabled,
		"migration and repeat saves preserve old-season eligibility"
	)
	_check(season.build._retraining_enabled, "new Working seasons enable seasonal training access")
	var partial: SeasonState = SeasonState.create(19, false, true, true)
	partial.build._format = 37
	partial.choose_player(partial.offers()[0])
	_check(SeasonSave.save(partial), "old partial draft saves")
	partial = SeasonSave.restore()
	while partial.picks.size() < 4:
		partial.choose_player(partial.offers()[0])
	_check(not partial.build._retraining_enabled, "finishing old draft preserves prospective gate")


func _sponsor_adapters() -> void:
	# Isolated sponsor adapters use the genuinely paid training fixture and controlled ownership.
	var season: SeasonState = _paid_retraining()
	var build: SeasonBuild = season.build
	_check(
		SeasonSpecialOrder.pool(build, "transformation") == {SeasonRetraining.ID: 1.0},
		"focused category only contains supported eligible identity"
	)
	_check(SeasonRaincheck.quote(build, SeasonRetraining.ID).price == 8, "fixed reservation price")
	var rain: SeasonBuild = build._fork()
	rain._bank._state.sponsors.append(
		{"id": "rain-fixture", "item": "G01", "kind": "sponsor", "paid": 12}
	)
	_check(
		(
			rain
			. commit(_command(rain, "reserve_offer", {"offer": _offer(rain, SeasonRetraining.ID)}))
			. ok
		),
		"reserve offered transformation"
	)
	_check(
		(
			rain
			. commit(
				_command(
					rain, "reward", {"game": rain._visit.number, "win": true, "performance": {}}
				)
			)
			. ok
		),
		"isolated next-game settlement"
	)
	_check(rain.commit(_command(rain, "open")).ok, "open actual reservation destination")
	var carried: Dictionary = SeasonRaincheck.protected_offer(rain)
	_check(
		carried.values() == [SeasonRetraining.ID] and rain._visit.offers.size() == 4,
		"carried transformation occupies one ordinary slot"
	)
	_check(
		(
			rain.commit(_command(rain, "reroll")).ok
			and SeasonRaincheck.protected_offer(rain) == carried
		),
		"reroll protects transformation"
	)
	var rain_cash: int = rain.cash()
	_check(
		(
			rain.commit(_purchase(rain)).ok
			and rain.cash() == rain_cash - 8
			and SeasonRaincheck.protected_offer(rain).is_empty()
		),
		"pay and consume carried offer once"
	)
	build._bank._state.sponsors.append(
		{"id": "focus-fixture", "item": "J01", "kind": "sponsor", "paid": 12}
	)
	var pack: Array = build._visit.cards.duplicate()
	_check(
		build.commit(_command(build, "focused_reroll", {"category": "transformation"})).ok,
		"actual focus transaction succeeds with one eligible transformation"
	)
	_check(
		(
			build._visit.offers.size() == 1
			and build._visit.unavailable_slots == 3
			and build._visit.cards == pack
		),
		"no duplicated transformations, extra pack stock or hidden filler"
	)
	build._visit["union_credit"] = 3
	var cash: int = build.cash()
	var paid: Dictionary = _purchase(build)
	_check(
		build.commit(paid).ok and build.cash() == cash - 8 and build._visit.union_credit == 3,
		"Union credit neither subsidizes nor gets consumed by transformation"
	)


func _retraining_ui() -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _paid_retraining()
	_check(app._checkpoint(), "UI checkpoint")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	var before: Dictionary = app.season.build.to_data()
	await _click(_button(window, "RETRAIN PLAYER"))
	await _shop_bounds(window, "retraining-player")
	var player: String = SeasonRetraining.targets(app.season.build)[0]
	await _click(_button(window, "RETRAIN " + app.season.build.definition(player).display_name))
	var choice: Dictionary = SeasonRetraining.choices(app.season.build._book, player)[0]
	await _click(_button(window, "REMOVE " + SeasonRetrainingUI._pair(choice.remove)))
	await _shop_bounds(window, "retraining-destinations")
	await _click(_button(window, "ADD " + SeasonRetrainingUI._pair(choice.add)))
	_check(
		window._confirm.visible and window._review_text.text.contains("zero gained"),
		"complete final review"
	)
	for stat: String in SeasonPlayerCatalog.STATS:
		_check(
			window._review_text.text.contains(stat.capitalize() + ":"),
			"all before/after stats visible"
		)
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "cancel preserves cash, offer and all points")
	await _click(_button(window, "ADD " + SeasonRetrainingUI._pair(choice.add)))
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		app.season.build.to_data() == before and FileAccess.get_file_as_string(path) == bytes,
		"failed write rolls back whole transformation and preserves prior bytes"
	)
	var command: Dictionary = _purchase(app.season.build)
	window._preview(command, SeasonRetrainingUI.review(app.season.build, command))
	await _frames()
	await _click(window._confirm.get_ok_button())
	_check(
		SeasonSave.restore().build.to_data() == app.season.build.to_data(),
		"successful retry saves exact change"
	)
	app.lab = PitchBatLab.new()
	_check(not app.commit_shop(command), "no in-game transformation or stamina reset")
	app.lab.free()
	app.lab = null
	app.queue_free()
	await _frames()
