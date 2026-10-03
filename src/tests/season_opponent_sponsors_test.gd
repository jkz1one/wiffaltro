extends "res://src/tests/season_opponent_lessons_test.gd"
## Synthetic credited-stat units; paid diagnostic games use real physical controllers.

var _paid: Dictionary = {}


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_sponsor_units()
	# Hidden diagnostics still run complete physics; render the reviewed UI afterward.
	if DisplayServer.get_name() != "headless":
		RenderingServer.set_render_loop_enabled(false)
	for item: String in SeasonOpponentSponsors.ITEMS:
		await _paid_game(item)
	RenderingServer.set_render_loop_enabled(true)
	await _sponsor_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent sponsor checks passed: "
			+ "paid stock, qualifications and physical effects.")
	get_tree().quit(0 if _failures == 0 else 1)


func _build(seed_value: int) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(seed_value, ["player.alex_finch", "player.lee_stone",
		"player.rowan_chase", "player.gray_west"])
	build._market = 6
	_check(build.commit(SeasonOpponentPolicy.command(build, "reward", {
		"game": 0, "win": true, "performance": _performance(build, 1, 2)})).ok,
		"explicit synthetic walk/Single qualification fixture")
	return build


func _performance(build: SeasonBuild, walks: int, singles: int) -> Dictionary:
	var result: Dictionary = {}
	for id: String in build.roster() + ["player.dakota_wells", "player.mika_reed",
		"player.jamie_nash", "player.quinn_riley"]:
		result[id] = MatchPerformance.empty_line()
	result[build.roster()[0]].merge({"pa": walks + singles, "h": singles, "bb": walks}, true)
	result["player.dakota_wells"].merge({"p_h": singles, "p_bb": walks}, true)
	_check(SeasonPerformance.valid(result, result.keys()), "synthetic box score balances")
	return result


func _sponsor_units() -> void:
	var exposed: Dictionary = {}
	var bought: Dictionary = {}
	for seed_value in range(128):
		var build: SeasonBuild = _build(seed_value)
		var stock: Dictionary = SeasonOpponentSponsors.offers(build, 0)
		var categories: Dictionary = {}
		for id: String in stock.values():
			var category: String = "development"
			if SeasonOpponentSponsors.ITEMS.has(id):
				category = "sponsor"
				exposed[id] = true
			elif SeasonOpponentGear.INITIAL.has(id):
				category = "gear"
			elif SeasonAbilities.ITEMS.has(id):
				category = "ability"
			elif id.begins_with("lesson."):
				category = "lesson"
			_check(category != "development" or DevelopmentShopCatalog.CARDS.has(id),
				"finite supported union only")
			categories[category] = true
		_check(stock.size() == 4 and categories.size() >= 2, "ordinary category repair")
		var poor: SeasonBuild = build._fork()
		poor._bank.commit({"id": "unit-charge", "rev": poor._bank.revision(),
			"op": "charge", "amount": 18})
		_check(SeasonOpponentSponsors.offers(poor, 0) == stock, "wallet never filters stock")
		var no_events: SeasonBuild = SeasonBuild.new(seed_value, build.roster())
		no_events._market = 6
		no_events.commit(SeasonOpponentPolicy.command(no_events, "reward", {
			"game": 0, "win": true, "performance": _performance(no_events, 0, 0)}))
		_check(SeasonOpponentSponsors.offers(no_events, 0) == stock,
			"qualification never filters or forces stock")
		var pack: Array = SeasonOpponentMarket.pack(build)
		_check(pack.size() == 3 and pack.all(func(id: String) -> bool:
			return DevelopmentShopCatalog.CARDS.has(id)), "fixed pack remains development only")
		for profile: String in ["Distributed", "Featured hitter", "Pitching / defense"]:
			var candidate: SeasonBuild = _build(seed_value)
			var club: Dictionary = _club(candidate)
			club.profile = profile
			SeasonOpponentPolicy.checkout(candidate, club, 0)
			for row: Dictionary in club.decisions:
				if row.stat == "sponsor":
					bought[row.item] = true
					_check(SeasonOpponentSponsors.qualifies(candidate, club, row.item)
						and row.paid == SeasonSponsorCatalog.item(row.item).price,
						"only qualified profile sponsors at shared actual prices")
			_audit(candidate, club)
	_check(exposed.size() == 4 and bought.size() >= 3, "all four offered, qualified policy purchases")
	_qualification_guards()
	for item: String in SeasonOpponentSponsors.ITEMS:
		_buy_sponsor(item)
	print("NPC_SPONSOR_EXPOSURE offered=", exposed.keys(), " policy_bought=", bought.keys())


func _qualification_guards() -> void:
	var build: SeasonBuild = _build(1)
	var club: Dictionary = _club(build)
	_check(SeasonOpponentSponsors.qualifies(build, club, "D01"),
		"recent own credited walk qualifies")
	_check(not SeasonOpponentSponsors.qualifies(build, club, "B02"),
		"baseline and learning alone never qualify College")
	_check(SeasonOpponentSponsors.qualifies(build, club, "B03"),
		"three known usable primary recipes")
	club.roles.pitcher = "player.rowan_chase"
	_check(not SeasonOpponentSponsors.qualifies(build, club, "B03"),
		"two-recipe arm skips Strikecraft")
	for game in range(1, 3):
		build.commit(SeasonOpponentPolicy.command(build, "reward", {
			"game": game, "win": false, "performance": _performance(build, 0, 0)}))
	_check(not SeasonOpponentSponsors.qualifies(build, club, "D01"),
		"walk signal expires after two games")
	_check(not SeasonOpponentSponsors.qualifies(build, club, "A07"), "Deli needs two latest Singles")
	for game in range(3, 8):
		build.commit(SeasonOpponentPolicy.command(build, "reward", {
			"game": game, "win": true, "performance": _performance(build, 1, 2)}))
	_check(not SeasonOpponentSponsors.qualifies(build, club, "D01"),
		"fewer than three regular games left")
	_check(SeasonOpponentSponsors.qualifies(build, club, "A07"), "two actual credited Singles signal")
	club.profile = "Distributed"
	_check(SeasonOpponentSponsors.targets(build, club).is_empty(), "unqualified profile has no target")
	club.profile = "Featured hitter"
	_check(SeasonOpponentSponsors.targets(build, club) == ["A07"],
		"profile preserves authored preference")


func _buy_sponsor(item: String) -> void:
	var build: SeasonBuild
	var offer: String = ""
	for seed_value in range(512):
		build = _build(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		if item == "B02":
			var development: String = ""
			for key: String in build._visit.offers:
				if build._visit.offers[key] == "development.contact":
					development = key
			if development.is_empty() or not build._visit.offers.values().has(item):
				continue
			_check(build.commit(SeasonOpponentPolicy.command(build, "buy", {"offer": development,
				"mode": "use", "player": build.roster()[0], "pitch": "", "replace": ""})).ok,
				"College diagnostic has actual paid club-earned development")
		for key: String in build._visit.offers:
			if build._visit.offers[key] == item:
				offer = key
				break
		if not offer.is_empty():
			break
	_check(not offer.is_empty(), "real generated sponsor offer " + item)
	if offer.is_empty():
		return
	var before: Dictionary = build.to_data()
	var poor: SeasonBuild = build._fork()
	poor._bank.commit({"id": "poor-unit", "rev": poor._bank.revision(),
		"op": "charge", "amount": poor.cash()})
	var poor_before: Dictionary = poor.to_data()
	_check(not poor.commit(SeasonOpponentPolicy.command(poor, "sponsor_buy", {
		"offer": offer, "replace": ""})).ok and ClubCareer.same(poor.to_data(), poor_before),
		"unaffordable sponsor rolls back exact stock and wallet")
	_check(not build.commit(SeasonOpponentPolicy.command(build, "sponsor_buy", {
		"offer": "foreign-offer", "replace": ""})).ok and ClubCareer.same(build.to_data(), before),
		"foreign stock rejects atomically")
	var club: Dictionary = _club(build)
	club["build"] = build
	club.profile = "Featured hitter" if item == "A07" else "Pitching / defense"
	var cash: int = build.cash()
	_check(SeasonOpponentSponsors.purchase(build, club, 0), "qualified actual paid purchase " + item)
	_check(build.cash() == cash - SeasonSponsorCatalog.item(item).price
		and build._bank.view().sponsors[0].paid == SeasonSponsorCatalog.item(item).price,
		"exact debit and paid receipt")
	before = build.to_data()
	_check(not build.commit(SeasonOpponentPolicy.command(build, "sponsor_buy", {
		"offer": offer, "replace": ""})).ok and ClubCareer.same(before, build.to_data()),
		"sold sponsor cannot charge twice")
	_check(not SeasonOpponentSponsors.pool(build).has(item), "exact owned identity leaves future pool")
	var replay: SeasonBuild = SeasonBuild.from_data(before, build._seed, build.roster())
	_check(replay != null and ClubCareer.same(replay.to_data(), before), "paid sponsor exact replay")
	for id: String in build.roster():
		_check(ContentDB.get_player(StringName(id)).season_sponsors.is_empty(),
			"paid effects never mutate natural resources")
	_paid[item] = {"build": build, "club": club}


func _audit(build: SeasonBuild, club: Dictionary) -> void:
	var spent: int = 0
	for row: Dictionary in club.decisions:
		spent += int(row.paid)
	for event: Dictionary in build.to_data().events:
		spent += 4 if event.op == "reroll" else 8 if event.op == "pack_skip" else 0
		_check(event.op not in ["sell_gear", "tactical_buy", "sign"], "gated systems stay absent")
	_check(build.cash() == 18 - spent and build.cash() >= 0 and build._visit.rerolls <= 1,
		"one competing reward wallet and bounded reroll")
	_check(SeasonBuild.from_data(build.to_data(), build._seed, build.roster()) != null,
		"entire acquisition journal replays")


func _paid_game(item: String) -> void:
	_check(_paid.has(item), "paid diagnostic exists " + item)
	if not _paid.has(item):
		return
	var build: SeasonBuild = _paid[item].build
	var club: Dictionary = _paid[item].club
	var away: Array[PlayerDefinition] = []
	var home: Array[PlayerDefinition] = []
	for id: String in build.roster():
		away.append(build.definition(id))
	for id: String in ["player.dakota_wells", "player.mika_reed",
		"player.jamie_nash", "player.quinn_riley"]:
		home.append(SeasonBuild.new(9, [id]).definition(id))
	var state: MatchState = MatchState.create(TeamMatchState.create("Paid sponsor fixture", away),
		TeamMatchState.create("Authored opposition", home))
	state.away_team.pitcher_index = build.roster().find(club.roles.pitcher)
	state.away_team.fielder_index = build.roster().find(club.roles.fielder)
	if item == "D01":
		state.home_team.pitcher_index = 3
		state.home_team.fielder_index = 1
	var before: Dictionary = build.to_data()
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var failures: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: failures.append(reason))
	_check(runner.start(state, 11 if item == "D01" else 67), "paid sponsor physical fixture starts")
	var probe: OpponentSponsorProbe = OpponentSponsorProbe.new()
	for frame in range(300000):
		await get_tree().physics_frame
		probe.observe(runner._lab, _check)
		if not report.is_empty() or not failures.is_empty():
			break
	_check(failures.is_empty() and PhysicalMatchReport.valid(report),
		"paid sponsor real AI game finishes")
	_check(ClubCareer.same(before, build.to_data()), "detached match leaves caller receipts unchanged")
	if item == "A07":
		_check(probe.deli_swings > 0, "actual Singles exercise paid Deli Contact benefit")
	elif item == "B02":
		_check(probe.college_releases > 0, "paid development exercises actual College workload")
	elif item == "B03":
		_check(probe.refunds > 0, "real distinct-recipe strikeout refunds paid Strikecraft")
	elif item == "D01" and not report.is_empty():
		var expected: int = SeasonSponsorCatalog.earnings(build._bank.view().sponsors,
			build.roster(), report.performance).D01
		var cash: int = build.cash()
		var reward: Dictionary = SeasonOpponentPolicy.command(build, "reward", {
			"game": 1, "win": report.away_runs > report.home_runs, "performance": report.performance})
		_check(build.commit(reward).ok and build.income_for_game(1).D01 == expected
			and build.cash() == cash + (18 if reward.win else 12) + expected,
			"only actual credited own walks settle capped sponsor income")
		_check(expected > 0, "physical diagnostic supplies real earning walks")
		before = build.to_data()
		reward.id = "duplicate-reward"
		reward.rev = build.revision()
		_check(not build.commit(reward).ok and ClubCareer.same(before, build.to_data()),
			"completed game cannot pay sponsor or base reward twice")
	print("NPC_PAID_SPONSOR_GAME item=", item, " ", probe.summary(),
		" pitches=", report.get("releases", []).size())
	runner.queue_free()
	await _frames()


func _sponsor_ui() -> void:
	var app: SeasonApp = await _app()
	app.begin_season(SEED, true)
	_check(app.season.opponents._format == 7 and SeasonSave.restore() != null,
		"ordinary Working start saves policy7")
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
		_check(SeasonSave.restore() != null, "partial sponsor drafts restore")
	_check(SeasonSave.snapshot(app.season).version == 51, "save51 binds policy7 and market6")
	var before: Dictionary = SeasonSave.snapshot(app.season)
	app.season.physical.projecting = true
	var pending: Dictionary = app.season.pending_fixture()
	_check(not app.season.record_player_result(pending.id, 0, 1),
		"new event-qualified policy refuses result-only human evidence")
	app.season.physical.projecting = false
	_check(ClubCareer.same(before, SeasonSave.snapshot(app.season)),
		"missing statistics cannot mutate rewards or stock")
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-sponsors-pregame")
	var card: VBoxContainer = SeasonPlayerCard.panel(app.menu._body, false)
	SeasonPages.wrapped(card, "Paid diagnostic club • actual paid receipt and physical walk earnings")
	SeasonOpponentSponsorsUI.preview(card, _paid.D01.club)
	await _frames()
	await _lesson_capture(app, card, "opponent-paid-sponsor-income")
	app.queue_free()
	await _frames()
