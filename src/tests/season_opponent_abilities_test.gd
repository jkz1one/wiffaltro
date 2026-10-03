extends "res://src/tests/season_opponent_lessons_test.gd"
## Unit rewards isolate stock; saved rounds play actual physical fixtures.

var _paid_sky: SeasonBuild


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_ability_units()
	await _sky_offscreen()
	await _ability_rounds()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent ability checks passed: paid learning, slots and physical replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _build(seed_value: int) -> SeasonBuild:
	var build: SeasonBuild = super._build(seed_value)
	build._market = 5
	return build


func _new(physical: bool) -> SeasonState:
	var season: SeasonState = SeasonState.create(SEED, false, true, true)
	season.opponents._format = 6
	season.physical = SeasonPhysicalFixtures.new() if physical else null
	season.career = ClubCareer.new()
	_check(season.career.start(season), "ability policy career starts")
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "ability policy draft completes")
	return season


func _ability_units() -> void:
	var exposed: Dictionary = {}
	var bought: Dictionary = {}
	for seed_value in range(96):
		var build: SeasonBuild = _build(seed_value)
		var stock: Dictionary = SeasonOpponentAbilities.offers(build, 0)
		var categories: Dictionary = {}
		for id: String in stock.values():
			var category: String = "development"
			if SeasonAbilities.ITEMS.has(id):
				category = "ability"
				exposed[id] = true
			elif SeasonOpponentGear.INITIAL.has(id):
				category = "gear"
			elif id.begins_with("lesson."):
				category = "lesson"
			_check(category != "development" or DevelopmentShopCatalog.CARDS.has(id),
				"only finite supported stock")
			categories[category] = true
		_check(stock.size() == 4 and categories.size() >= 2, "ordinary diversity repair")
		var poor: SeasonBuild = build._fork()
		poor._bank.commit({"id": "unit-charge", "rev": poor._bank.revision(),
			"op": "charge", "amount": 18})
		_check(SeasonOpponentAbilities.offers(poor, 0) == stock,
			"cash never filters ability exposure")
		_check(build._abilities.start == null and build._abilities.pool(build).size() == 3,
			"published AI access is independent of human Sky unlock")
		var pack: Array = SeasonOpponentMarket.pack(build)
		var families: Dictionary = {}
		for id: String in pack:
			_check(DevelopmentShopCatalog.CARDS.has(id), "pack remains development only")
			families[DevelopmentShopCatalog.item(id).family] = true
		_check(pack.size() == 3 and families.size() == 3, "fixed pack keeps distinct families")
		for profile: String in ["Distributed", "Featured hitter", "Pitching / defense"]:
			var candidate: SeasonBuild = _build(seed_value)
			var club: Dictionary = _club(candidate)
			club.profile = profile
			SeasonOpponentPolicy.checkout(candidate, club, 0)
			for row: Dictionary in club.decisions:
				if row.stat != "ability":
					continue
				bought[row.item] = true
				_check(row.player == (club.roles.hitter if profile == "Featured hitter"
					else club.roles.fielder), "ability uses exact committed role")
				_check(row.paid == SeasonAbilities.ITEMS[row.item].price,
					"same shared actual price")
				_check((row.item == SeasonAbilities.COUNT) == (profile == "Featured hitter"),
					"featured hitter alone buys Work the Count")
				_check(row.item != SeasonAbilities.SKY or profile == "Pitching / defense",
					"Sky only for pitching profile")
			_audit(candidate, club)
	_check(exposed.size() == 3 and bought.size() == 3, "all three abilities exposed and policy bought")
	for item: String in SeasonAbilities.ITEMS:
		_buy_ability(item)
	var human: SeasonBuild = _build(0)
	human._market = 0
	_check(not human._abilities.pool(human).has(SeasonAbilities.SKY),
		"AI access never grants human Sky discovery")
	for market: int in [1, 2, 3, 4]:
		human._market = market
		_check(human._abilities.pool(human).is_empty(), "historical AI ability pool stays empty")
	print("NPC_ABILITY_EXPOSURE offered=", exposed.size(), " purchased=", bought.keys())


func _buy_ability(item: String) -> void:
	var build: SeasonBuild
	var offer: String = ""
	for seed_value in range(256):
		build = _build(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		for key: String in build._visit.offers:
			if build._visit.offers[key] == item:
				offer = key
				break
		if not offer.is_empty():
			break
	_check(not offer.is_empty(), "actual generated ability offer: " + item)
	if offer.is_empty():
		return
	var club: Dictionary = _club(build)
	club.profile = "Featured hitter" if item == SeasonAbilities.COUNT else "Pitching / defense"
	var player: String = club.roles.hitter if item == SeasonAbilities.COUNT else club.roles.fielder
	var before: Dictionary = build.to_data()
	var bad: Dictionary = SeasonOpponentPolicy.command(build, "ability_buy", {
		"offer": offer, "player": "player.ari_banks", "replace": ""})
	_check(not build.commit(bad).ok and ClubCareer.same(build.to_data(), before),
		"foreign recipient rejects atomically")
	var poor: SeasonBuild = build._fork()
	poor._bank.commit({"id": "poor-unit", "rev": poor._bank.revision(),
		"op": "charge", "amount": 18})
	var poor_before: Dictionary = poor.to_data()
	_check(not poor.commit(SeasonOpponentPolicy.command(poor, "ability_buy", {
		"offer": offer, "player": player, "replace": ""})).ok
		and ClubCareer.same(poor.to_data(), poor_before), "unaffordable learning rolls back")
	var command: Dictionary = SeasonOpponentPolicy.command(build, "ability_buy", {
		"offer": offer, "player": player, "replace": ""})
	_check(build.commit(command).ok and build.cash() == 18 - SeasonAbilities.ITEMS[item].price,
		"actual shared paid learned transaction")
	_check(build.definition(player).season_abilities.has(item)
		and ContentDB.get_player(StringName(player)).season_abilities.is_empty(),
		"committed definition carries paid ability; natural resource remains isolated")
	before = build.to_data()
	command.id = "sold:" + item
	command.rev = build.revision()
	_check(not build.commit(command).ok and ClubCareer.same(build.to_data(), before),
		"sold offer rejects without second charge")
	_check(not SeasonOpponentAbilities.targets(build, club).any(
		func(goal: Dictionary) -> bool: return goal.player == player),
		"known/full role skips learning; Sky never expands Fielding capacity")
	if item != SeasonAbilities.COUNT:
		_check(build._abilities.pool(build).has(SeasonAbilities.COUNT),
			"unpreferred legal stock remains available")
	var replay: SeasonBuild = SeasonBuild.from_data(before, build._seed, build.roster())
	_check(replay != null and replay._abilities.learned == build._abilities.learned,
		"exact paid receipt replay")
	if item == SeasonAbilities.SKY:
		_paid_sky = build
	var fork: SeasonBuild = build._fork()
	fork._abilities.learned[player].clear()
	_check(build._abilities.ids(player).has(item), "forked learned state never mutates source")


func _audit(build: SeasonBuild, club: Dictionary) -> void:
	var spent: int = 0
	for row: Dictionary in club.decisions:
		spent += int(row.paid)
	for event: Dictionary in build.to_data().events:
		if event.op == "reroll":
			spent += 4
		elif event.op == "pack_skip":
			spent += 8
		_check(event.op not in ["sell_gear", "sponsor_buy", "tactical_buy", "sign"],
			"no sidegrades or gated acquisitions")
	_check(build.cash() == 18 - spent and build.cash() >= 0 and build._visit.rerolls <= 1,
		"one competing wallet includes skipped packs and at most one reroll")
	var replay: SeasonBuild = SeasonBuild.from_data(build.to_data(), build._seed, build.roster())
	_check(replay != null and ClubCareer.same(replay.to_data(), build.to_data())
		and replay._abilities.learned == build._abilities.learned, "entire acquisition journal replays")


func _ability_rounds() -> void:
	SeasonSave.path = "user://opponent-abilities-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://opponent-abilities-%d.cfg" % OS.get_process_id()
	var app: SeasonApp = await _app()
	app.begin_season(SEED, true)
	app.season.opponents._format = 6
	_check(SeasonSave.save(app.season), "historical policy6 startup saves explicitly")
	_check(app.season.opponents._format == 6 and SeasonSave.restore() != null,
		"ordinary Working UI saves policy6 before draft")
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
		_check(SeasonSave.restore() != null, "each partial ability draft restores")
	_check(SeasonSave.snapshot(app.season).version == 50, "save50 explicitly binds Build41/policy6")
	for round_number in range(3):
		var pending: Dictionary = app.season.pending_fixture()
		app.round_ui.begin([pending.id, 0 if pending.home == 0 else 1,
			1 if pending.home == 0 else 0, {}, [], [], {}, [], [], {}, {}, []])
		await _wait_lesson_round(app)
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
			SeasonSave.snapshot(app.season)), "whole ability stock/journal/request/reward replay")
	var count: int = 0
	for club: Dictionary in app.season.opponents.clubs.values():
		for row: Dictionary in club.decisions:
			count += 1 if row.stat == "ability" else 0
	_check(count > 0 and app.season.physical.reports.size() == 6,
		"actual round rewards acquire abilities; six complete physical AI games")
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-abilities-pregame")
	var found: bool = false
	for node: Node in app.menu._body.find_children("*", "Label", true, false):
		if node.has_meta("opponent_ability_role"):
			found = true
			await _lesson_capture(app, node.get_parent(), "opponent-abilities-secondary")
			break
	_check(found, "next opponent exposes committed learned slot and acquisition rule")
	# Same production component, rendered using a genuinely paid committed club.
	for key: String in app.season.opponents.clubs:
		var club: Dictionary = app.season.opponents.clubs[key]
		if not club.decisions.any(func(row: Dictionary) -> bool: return row.stat == "ability"):
			continue
		var card: VBoxContainer = SeasonPlayerCard.panel(app.menu._body, false)
		SeasonPages.wrapped(card, "Committed club • " + app.season.teams[int(key)].name)
		SeasonOpponentAbilitiesUI.preview(card, club)
		await _frames()
		await _lesson_capture(app, card, "opponent-paid-ability")
		break
	var saved: Dictionary = SeasonSave.snapshot(app.season)
	for field: String in ["version", "policy", "market", "journal", "decision", "receipt", "request"]:
		var bad: Dictionary = saved.duplicate(true)
		match field:
			"request": bad.physical.reports[0].request = "0".repeat(64)
			"receipt":
				for key: String in bad.opponents.clubs:
					for event: Dictionary in bad.opponents.clubs[key].build.events:
						if event.op == "ability_buy":
							event.player = "player.ari_banks"
			"version": bad.version = 49
			"policy": bad.opponents.policy = 5
			"market": bad.opponents.clubs["1"].build.market = 4
			"journal": bad.opponents.clubs["1"].build.events.pop_back()
			"decision": bad.opponents.clubs["1"].decisions.append({"stat": "ability", "paid": 0})
		_check(SeasonSave._decode(bad) == null, "reject altered ability " + field)
	var committed: Dictionary = app.season.opponents.to_data()
	app.season.build.commit(SeasonOpponentPolicy.command(app.season.build, "open"))
	_check(ClubCareer.same(committed, app.season.opponents.to_data()), "no human counter-shopping")
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	print("NPC_ABILITY_ROUNDS games=6 abilities=", count)


func _sky_offscreen() -> void:
	_check(_paid_sky != null, "generated paid Sky fixture exists")
	if _paid_sky == null:
		return
	var club: Dictionary = _club(_paid_sky)
	var away: Array[PlayerDefinition] = []
	var home: Array[PlayerDefinition] = []
	for id: String in _paid_sky.roster():
		away.append(_paid_sky.definition(id))
	for id: String in ["player.dakota_wells", "player.mika_reed",
		"player.jamie_nash", "player.quinn_riley"]:
		home.append(SeasonBuild.new(9, [id]).definition(id))
	var state: MatchState = MatchState.create(TeamMatchState.create("Paid Sky fixture", away),
		TeamMatchState.create("Authored opposition", home))
	state.away_team.pitcher_index = _paid_sky.roster().find(club.roles.pitcher)
	state.away_team.fielder_index = _paid_sky.roster().find(club.roles.fielder)
	_check(state.away_team.roster[state.away_team.fielder_index].definition.season_abilities.has(
		SeasonAbilities.SKY), "exact paid recipient starts as primary fielder")
	var before: Dictionary = _paid_sky.to_data()
	var learned: Dictionary = _paid_sky._abilities.learned.duplicate(true)
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var failure: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: failure.append(reason))
	_check(runner.start(state, 67), "actual paid-Sky detached physical fixture starts")
	var probe: OpponentAbilityProbe = OpponentAbilityProbe.new()
	for frame in range(300000):
		await get_tree().physics_frame
		probe.observe(runner._lab, _check)
		if not report.is_empty() or not failure.is_empty():
			break
	_check(failure.is_empty() and PhysicalMatchReport.valid(report), "paid-Sky real AI game completes")
	_check(probe.sky_launches > 0, "actual offscreen fair high launches use paid Sky")
	_check(ClubCareer.same(before, _paid_sky.to_data()) and learned == _paid_sky._abilities.learned,
		"detached match cannot mutate paid ownership or receipts")
	print("NPC_PAID_SKY_GAME ", probe.summary(), " pitches=", report.get("releases", []).size())
	runner.queue_free()
	await _frames()
