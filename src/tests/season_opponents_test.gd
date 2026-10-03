extends "res://src/tests/season_sponsor_test.gd"

var _pack_count: int = 0
var _reroll_count: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_ledger_contracts()
	_playoff_contracts()
	_pack_contract()
	_check(_reroll_count > 0, "real seasons exercise paid rerolls")
	print("OPPONENT_POLICY packs=", _pack_count, " rerolls=", _reroll_count)
	await _opponent_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro paid opponent checks passed: own wallets, purchases, playoffs, replay and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _opponent_season(seed_value: int = 42, games: int = 0, format_version: int = 2) -> SeasonState:
	var season: SeasonState = SeasonState.create(seed_value, false, true, true)
	season.opponents._format = format_version
	for pick in range(4):
		season.choose_player(season.offers()[0])
	for game in range(games):
		_record(season)
	return season


func _audit(season: SeasonState) -> void:
	for key: String in season.opponents.clubs:
		var index: int = int(key)
		var club: Dictionary = season.opponents.clubs[key]
		var build: SeasonBuild = club.build
		var replay: SeasonBuild = SeasonBuild.from_data(
			build.to_data(), build._seed, build.roster()
		)
		_check(replay != null and replay.view() == build.view(), "shared opponent journal replays")
		var team: TeamMatchState = season._make_team(index)
		var starter: PlayerDefinition = team.roster[team.pitcher_index].definition
		var fixture: Dictionary = {"home": 0, "away": index}
		_check(
			String(starter.id) == season.opposing_starter(fixture), "announced live starter agrees"
		)
		var recipes: Array[String] = []
		for recipe: PitchDefinition in starter.starting_pitches:
			recipes.append(String(recipe.id))
		_check(SeasonFilmRoom.choices(season, fixture) == recipes, "scouting uses actual starter")
		var earned: int = 0
		var played: Array = []
		for result: Dictionary in season.results:
			if index in [result.home, result.away]:
				earned += 18 if SeasonState._winner(result) == index else 12
				played.append(result.id)
		var spent: int = 0
		var rolls: int = 0
		for event: Dictionary in build.to_data().events:
			if event.op == "reward":
				_check(
					played.has(event.game) and event.performance.is_empty(), "only real W/L income"
				)
				rolls = 0
			elif event.op == "buy":
				spent += 6
			elif event.op == "pack_open":
				spent += 8
				_pack_count += 1
			elif event.op == "reroll":
				rolls += 1
				_reroll_count += 1
				spent += 4
				_check(rolls <= 1, "at most one paid reroll per visit")
		_check(
			build.cash() == earned - spent and build.cash() >= 0, "single real wallet reconciles"
		)
		_check(build._bank.view().rewards.size() == played.size(), "one reward per actual fixture")
		var steps: int = 0
		for id: String in build.roster():
			var base: Dictionary = SeasonDevelopment.new("base").player(id)
			for stat: String in SeasonPlayerCatalog.STATS:
				var expected: int = base.stats[stat]
				for purchase: Dictionary in club.decisions:
					if purchase.player == id and purchase.stat == stat:
						expected += 1
				_check(
					build.player(id).stats[stat] == expected and expected <= 10,
					"all growth is a purchased step within the ordinary cap"
				)
				steps += expected - int(base.stats[stat])
			_check(build.player(id).mastery == base.mastery, "unsupported mastery never granted")
		_check(steps == club.decisions.size(), "no unrecorded growth")
		for offer: String in build._visit.get("offers", {}).values():
			_check(
				(
					offer
					in [
						"development.contact",
						"development.power",
						"development.fielding",
						"development.pitching"
					]
				),
				"published capability mask"
			)
		_check(
			build._bank.view().sponsors.is_empty() and build._bank.view().held.is_empty(),
			"no event sponsors or supplies from score-only results"
		)
		_check(club.roles.pitcher != club.roles.fielder, "legal committed defensive roles")
		var expected_strength: float = 0.0
		for id: String in build.roster():
			for stat: String in SeasonPlayerCatalog.STATS:
				expected_strength += float(build.player(id).stats[stat]) / 16.0
		_check(
			is_equal_approx(season._strength(index), expected_strength),
			"offscreen strength uses actual four ratings, no price proxy"
		)


func _ledger_contracts() -> void:
	SeasonSave.path = "user://opponent-contract-%d.json" % OS.get_process_id()
	var season: SeasonState = _opponent_season()
	for club: Dictionary in season.opponents.clubs.values():
		_check(club.build.cash() == 0 and club.build.revision() == 0, "zero start, no free items")
	_record(season)
	_audit(season)
	var committed: Dictionary = season.opponents.to_data()
	var saved_round: bool = SeasonSave.save(season)
	_check(saved_round, "checkpoint first complete paid round")
	if not saved_round:
		return
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.opponents.to_data() == committed, "exact AI replay")
	season.build.commit(_command(season.build, "open"))
	season.build.commit(_command(season.build, "reroll"))
	_check(season.opponents.to_data() == committed, "human spending cannot trigger enemy checkout")
	var first: Dictionary = season.player_results[0]
	_check(
		(
			not season.record_player_result(first.id, first.away_runs, first.home_runs)
			and season.opponents.to_data() == committed
		),
		"duplicate result cannot repay or rebuy"
	)
	_check(SeasonSave.save(season), "save after human purchase path")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for target: String in ["cursor", "role", "market", "event", "policy"]:
		var bad: Dictionary = saved.duplicate(true)
		match target:
			"cursor":
				bad.opponents.clubs["1"].cursor += 1
			"role":
				bad.opponents.clubs["1"].roles.pitcher = season.picks[0]
			"market":
				bad.opponents.clubs["1"].build.market = 0
			"event":
				bad.opponents.clubs["1"].build.events.pop_back()
			"policy":
				bad.opponents.policy = 3
		_check(SeasonSave._decode(bad) == null, "reject changed opponent " + target)
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	_record(season)
	SeasonSave.path = path + "/missing/save.json"
	_check(not SeasonSave.save(season), "failed whole-round write")
	SeasonSave.path = path
	_check(
		(
			FileAccess.get_file_as_string(path) == bytes
			and SeasonSave.restore().opponents.to_data() == committed
		),
		"entire earlier round survives"
	)
	_check(
		(
			SeasonSave.save(season)
			and SeasonSave.restore().opponents.to_data() == season.opponents.to_data()
		),
		"retry persists one coherent round"
	)
	_audit(season)
	# Existing Working seasons never receive retroactive opponent growth.
	var legacy: SeasonState = SeasonState.create(92, false, true)
	for pick in range(4):
		legacy.choose_player(legacy.offers()[0])
	legacy.build._format = 18
	_record(legacy)
	_check(SeasonSave.save(legacy), "old schema22")
	var old: SeasonState = SeasonSave.restore()
	_check(old != null and old.opponents == null, "legacy cohort remains unchanged")
	_check(
		SeasonSave.save(old) and SeasonSave.restore().opponents == null,
		"migration retains old cohort"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _playoff_contracts() -> void:
	for win: bool in [false, true]:
		var season: SeasonState = _opponent_season(51)
		var visits: Dictionary = {}
		while season.phase != SeasonState.Phase.COMPLETE:
			var game: Dictionary = season.pending_fixture()
			var home_wins: bool = (game.home == 0) == win
			_check(
				season.record_player_result(game.id, 0 if home_wins else 1, 1 if home_wins else 0),
				"complete supported real result boundary"
			)
			if season.round_index == 10 and visits.is_empty():
				for key: String in season.opponents.clubs:
					if not season.playoff_seeds.has(int(key)):
						visits[key] = season.opponents.clubs[key].build.revision()
		_audit(season)
		for key: String in visits:
			_check(
				season.opponents.clubs[key].build.revision() == visits[key],
				"regular-season elimination adds no purchases or games"
			)
		for key: String in season.opponents.clubs:
			var events: Array = season.opponents.clubs[key].build.to_data().events
			for position in range(events.size()):
				if events[position].op == "reward" and events[position].game >= 30:
					var event: Dictionary = events[position]
					if not event.win or event.game == 32:
						_check(
							position == events.size() - 1, "elimination/final pays but never shops"
						)
		SeasonSave.path = "user://opponent-playoffs-%s-%d.json" % [str(win), OS.get_process_id()]
		_check(SeasonSave.save(season) and SeasonSave.restore() != null, "full playoffs replay")
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(SeasonSave.path + suffix)


func _opponent_ui() -> void:
	SeasonSave.path = "user://opponent-ui-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(42, true)
	# Historical score-only fixture; physical rounds have separate integration coverage.
	app.season.physical = null
	app.season.opponents._format = 2
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
	_check(app.season.opponents != null, "new Working UI enables paid opponents")
	_record(app.season)
	var checkpoint: bool = app._checkpoint()
	_check(checkpoint, "save committed AI before human shop")
	if not checkpoint:
		app.queue_free()
		await _frames()
		return
	var before: Dictionary = app.season.opponents.to_data()
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "paid-opponent-pregame")
	var found: bool = false
	for node: Node in app.menu._body.find_children("*", "Label", true, false):
		if node.has_meta("opponent_build"):
			found = node.text.contains("purchased steps") and node.text.contains("Cash")
	_check(found, "visible committed balance and purchases")
	await _click(_button(app.menu, "SEASON HUB"))
	await _click(_button(app.menu, "SEASON SHOP"))
	await _frames()
	var shop: SeasonShopWindow = _shop(app)
	await _shop_bounds(shop, "paid-opponent-human-shop")
	await _click(shop._back)
	app.menu.show_lineup()
	await _frames()
	await _click(_button(app.menu, "PLAY GAME"))
	_check(
		app.lab != null and app.season.opponents.to_data() == before,
		"opening shop and launching cannot rerun enemy spending"
	)
	app.leave_game()
	await _frames()
	app.season = SeasonSave.restore()
	_check(
		app.season.opponents.to_data() == before, "unfinished restart preserves committed enemies"
	)
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _pack_contract() -> void:
	var roster: Array[String] = [
		"player.frankie_bell", "player.jo_lane", "player.jordan_lake", "player.rowan_chase"
	]
	var seed_value: int = 8
	var build: SeasonBuild = SeasonBuild.new(seed_value, roster)
	build._market = 1
	var club: Dictionary = {
		"profile": "Distributed",
		"roles": SeasonOpponentPolicy.roles(build),
		"cursor": 0,
		"decisions": []
	}
	_check(
		(
			build
			. commit(
				SeasonOpponentPolicy.command(
					build, "reward", {"game": 0, "win": true, "performance": {}}
				)
			)
			. ok
		),
		"paid pack fixture earns ordinary win income"
	)
	SeasonOpponentPolicy.checkout(build, club, 0)
	var events: Array = build.to_data().events
	var packs: Array = events.filter(
		func(event: Dictionary) -> bool: return event.op == "pack_open"
	)
	_check(packs.size() == 1 and build._visit.cards.size() == 3, "single fixed three-card pack")
	for card: String in build._visit.cards:
		_check(build._visit.cards.count(card) == 1, "fixed pack families are distinct")
	var choices: Array = club.decisions.filter(func(row: Dictionary) -> bool: return row.paid == 8)
	_check(choices.size() == 1 and choices[0].reason == "objective", "paid pack advances goal")
	var spent: int = 0
	for event: Dictionary in events:
		if event.op == "buy":
			spent += 6
		elif event.op == "pack_open":
			spent += 8
		elif event.op == "reroll":
			spent += 4
	_check(build.cash() == 18 - spent, "pack spends same real wallet")
	var replay: SeasonBuild = SeasonBuild.from_data(build.to_data(), seed_value, roster)
	_check(replay != null and replay.view() == build.view(), "paid pack exact journal replay")
	print("OPPONENT_PACK seed=", seed_value, " decisions=", club.decisions.size())
