extends "res://src/tests/season_opponent_sponsors_test.gd"
## Generated paid-copy units and complete shared physical use/settlement diagnostics.

var _tactical_probe: OpponentTacticalProbe = OpponentTacticalProbe.new()


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_tactical_units()
	if DisplayServer.get_name() != "headless":
		RenderingServer.set_render_loop_enabled(false)
	for item: String in SeasonOpponentTactics.ITEMS:
		await _tactical_game(item)
	RenderingServer.set_render_loop_enabled(true)
	await _tactical_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent tactical checks passed: paid held copies and shared real use.")
	get_tree().quit(0 if _failures == 0 else 1)


func _build(seed_value: int) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(
		seed_value,
		["player.alex_finch", "player.lee_stone", "player.rowan_chase", "player.gray_west"]
	)
	build._market = 8
	_check(
		(
			build
			. commit(
				SeasonOpponentPolicy.command(
					build,
					"reward",
					{"game": 0, "win": true, "performance": _performance(build, 0, 0)}
				)
			)
			. ok
		),
		"synthetic stock budget only, no earned-event claim"
	)
	return build


func _tactical_units() -> void:
	var purchased: Dictionary = {}
	var exposed: Dictionary = {}
	for seed_value in range(128):
		var build: SeasonBuild = _build(seed_value)
		var stock: Dictionary = SeasonOpponentMarket.offers(build, 0)
		var poor: SeasonBuild = build._fork()
		poor._bank.commit(
			{"id": "charge", "rev": poor._bank.revision(), "op": "charge", "amount": 18}
		)
		_check(stock == SeasonOpponentMarket.offers(poor, 0), "wallet cannot filter or force stock")
		for id: String in stock.values():
			if SeasonTacticalCatalog.catalog().has(id):
				_check(id in SeasonOpponentTactics.ITEMS, "only supported offensive tactical types")
				exposed[id] = true
		var old: SeasonBuild = build._fork()
		old._market = 7
		_check(
			not SeasonOpponentMarket.offers(old, 0).values().any(
				func(id: String) -> bool: return SeasonTacticalCatalog.catalog().has(id)
			),
			"historical market7 remains supply-free"
		)
		var pack: Array = SeasonOpponentMarket.pack(build)
		_check(
			pack.all(func(id: String) -> bool: return DevelopmentShopCatalog.CARDS.has(id)),
			"supplies never enter fixed development pack"
		)
		for profile: String in ["Distributed", "Featured hitter", "Pitching / defense"]:
			var buyer: SeasonBuild = _build(seed_value)
			var club: Dictionary = _club(buyer)
			club.profile = profile
			SeasonOpponentPolicy.checkout(buyer, club, 0)
			for row: Dictionary in club.decisions:
				if row.stat == "tactical":
					purchased[row.item] = true
					_check(
						row.paid == 3 and row.player == club.roles.hitter,
						"shared price and committed featured recipient"
					)
			_check(
				buyer._bank.view().held.size() <= 2 and buyer._visit.rerolls <= 1,
				"shared capacity and one competing paid reroll"
			)
			_audit(buyer, club)
	_check(exposed.size() == 2 and purchased.size() == 2, "both normal generated offers bought")
	for item: String in SeasonOpponentTactics.ITEMS:
		_buy_tactical(item)
	_capacity_guard()
	_readiness_guards()
	var pair: Array = [{"id": "plan", "item": "C03"}, {"id": "tape", "item": "A10"}]
	_check(
		SeasonOpponentTactics.select(pair, "featured", "featured", "swing.power").receipt == "tape",
		"Tape priority is independent of held purchase order"
	)
	_check(
		SeasonOpponentTactics.select(pair, "other", "featured", "swing.power").is_empty(),
		"other batters cannot consume featured supplies"
	)
	var tie: PlayerDefinition = _build(1).definition("player.rowan_chase")
	var expected: String = "swing.power" if tie.power > tie.contact else "swing.contact"
	_check(
		SeasonOpponentTactics.plan(tie) == expected,
		"Plan uses actual public stats with Contact ties"
	)
	print("NPC_TACTICAL_POLICY offered=", exposed.keys(), " bought=", purchased.keys())


func _audit(build: SeasonBuild, club: Dictionary) -> void:
	var spent: int = 0
	for row: Dictionary in club.decisions:
		spent += int(row.paid)
	for event: Dictionary in build.to_data().events:
		spent += 4 if event.op == "reroll" else 8 if event.op == "pack_skip" else 0
		_check(
			event.op not in ["sell_gear", "sponsor_sell", "sign", "discard"],
			"no replacement, free grant or disposal funds checkout"
		)
	_check(build.cash() == 18 - spent, "all purchases and skipped packs spend one actual wallet")
	var replay: SeasonBuild = SeasonBuild.from_data(build.to_data(), build._seed, build.roster())
	_check(
		replay != null and ClubCareer.same(replay.view(), build.view()), "exact paid market8 replay"
	)


func _buy_tactical(item: String) -> void:
	for seed_value in range(512):
		var build: SeasonBuild = _build(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		if not build._visit.offers.values().has(item):
			continue
		var club: Dictionary = _club(build)
		club["build"] = build
		# Isolate the exact offered identity; purchase itself still uses the real offer/price.
		var offer: String = ""
		for key: String in build._visit.offers:
			if build._visit.offers[key] == item:
				offer = key
		var command: Dictionary = SeasonOpponentPolicy.command(
			build, "tactical_buy", {"offer": offer}
		)
		var poor: SeasonBuild = build._fork()
		poor._bank.commit(
			{"id": "poor", "rev": poor._bank.revision(), "op": "charge", "amount": 18}
		)
		var before: Dictionary = poor.to_data()
		_check(
			not poor.commit(command).ok and ClubCareer.same(before, poor.to_data()),
			"unaffordable purchase rolls back stock, wallet and journal"
		)
		_check(
			build.commit(command).ok and build.cash() == 15, "actual generated card pays shared3"
		)
		var paid: Dictionary = build._bank.view().held[0]
		_check(paid.item == item and paid.paid == 3, "exact copy receipt, no proxy effect")
		before = build.to_data()
		_check(
			build.commit(command).replayed and ClubCareer.same(before, build.to_data()),
			"retry cannot duplicate paid held copy"
		)
		var stale: Dictionary = SeasonOpponentPolicy.command(
			build, "tactical_buy", {"offer": offer}
		)
		_check(
			not build.commit(stale).ok and ClubCareer.same(before, build.to_data()),
			"sold stock cannot supply a second copy"
		)
		club.decisions.append({"game": 0, "request": command.id, "player": club.roles.hitter,
			"stat": "tactical", "item": item, "paid": 3, "reason": "paid diagnostic"})
		_paid[item] = {"build": build, "club": club}
		return
	_check(false, "generated tactical offer missing " + item)


func _tactical_game(item: String) -> void:
	var build: SeasonBuild = _paid[item].build
	var club: Dictionary = _paid[item].club
	var away: Array[PlayerDefinition] = []
	var home: Array[PlayerDefinition] = []
	for id: String in build.roster():
		away.append(build.definition(id))
	for id: String in [
		"player.dakota_wells", "player.mika_reed", "player.jamie_nash", "player.quinn_riley"
	]:
		home.append(SeasonBuild.new(9, [id]).definition(id))
	var state: MatchState = MatchState.create(
		TeamMatchState.create("Paid supply diagnostic", away),
		TeamMatchState.create("Ordinary opposition", home)
	)
	state.away_team.ai_sponsor_choices = true
	state.away_team.ai_tactical_hitter = club.roles.hitter
	state.away_team.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	state.away_team.ai_tactical_initial.assign(state.away_team.tactics.held.duplicate(true))
	var before: Dictionary = build.to_data()
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var failures: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: failures.append(reason))
	_check(runner.start(state, 67), "paid supply actual physical game starts")
	for frame in range(300000):
		await get_tree().physics_frame
		_tactical_probe.observe(runner._lab, _check)
		if not report.is_empty() or not failures.is_empty():
			break
	_check(
		failures.is_empty() and PhysicalMatchReport.valid(report),
		"complete paid supply physics balances"
	)
	if not report.is_empty():
		_check(PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report, "", true, true))),
			"complete report survives the actual JSON boundary")
		_check(
			report.version == 3 and PhysicalTacticalEvidence.report_matches(report, state),
			"report3 binds complete held/consumed/remaining copies"
		)
		var row: Dictionary = report.tactics.teams[0]
		_check(
			(
				row.consumed.size() == 1
				and row.remaining.is_empty()
				and row.consumed[0].player == club.roles.hitter
			),
			"exact paid copy consumed at featured PA once"
		)
		for corruption: String in [
			"missing", "duplicate", "foreign", "swing", "pa", "paid", "remaining"
		]:
			var bad: Dictionary = report.duplicate(true)
			var proof: Dictionary = bad.tactics.teams[0]
			match corruption:
				"missing":
					proof.consumed.clear()
				"duplicate":
					proof.consumed.append(proof.consumed[0])
				"foreign":
					proof.consumed[0].receipt = "foreign"
				"swing":
					proof.consumed[0].swing = "swing.illegal"
				"pa":
					proof.consumed[0].pa += 1
				"paid":
					proof.initial[0].paid = 0
				"remaining":
					proof.remaining = proof.initial.duplicate(true)
			_check(
				not PhysicalMatchReport.valid(bad), "altered tactical " + corruption + " rejects"
			)
		var unpaid: MatchState = PhysicalMatchRequest.capture(state)
		unpaid.away_team.ai_tactical_initial.clear()
		_check(
			not PhysicalTacticalEvidence.report_matches(report, unpaid),
			"unowned-copy binding rejects"
		)
		var reward: Dictionary = SeasonOpponentPolicy.command(
			build,
			"reward",
			{
				"game": 1,
				"win": report.away_runs > report.home_runs,
				"performance": report.performance,
				"tactics": row.consumed
			}
		)
		var invalid: Dictionary = reward.duplicate(true)
		invalid.tactics[0].receipt = "foreign"
		_check(not build.commit(invalid).ok and ClubCareer.same(before, build.to_data()),
			"invalid copy evidence atomically rolls back reward and consumption")
		_check(
			build.commit(reward).ok and build._bank.view().held.is_empty(),
			"completed use settles shared bag"
		)
		var saved: Dictionary = build.to_data()
		_check(
			build.commit(reward).replayed and ClubCareer.same(saved, build.to_data()),
			"completed game retry cannot pay or consume twice"
		)
		_check(
			SeasonBuild.from_data(saved, build._seed, build.roster()) != null,
			"paid then consumed copy replays from purchase journal"
		)
	_check(
		(
			ClubCareer.same(before.events, build.to_data().events.slice(0, before.events.size()))
			and state.away_team.tactics.consumed.is_empty()
			and state.away_team.tactics.held.size() == 1
		),
		"physical request isolates original held copy and natural resources"
	)
	_check(
		_tactical_probe.tape_frames > 0 if item == "A10" else _tactical_probe.plan_frames > 0,
		"actual shared swing exercises supply " + item
	)
	print(
		"NPC_PAID_TACTICAL item=",
		item,
		" releases=",
		report.get("releases", []).size(),
		" ",
		_tactical_probe.summary()
	)
	runner.queue_free()
	await _frames()


func _tactical_ui() -> void:
	var app: SeasonApp = await _app()
	app.begin_season(SEED, true)
	app.season.opponents._format = 9
	_check(
		app.season.opponents._format == 9 and SeasonSave.snapshot(app.season).version == 53,
		"ordinary new Working start uses save53 / policy9"
	)
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
		_check(SeasonSave.restore() != null, "new partial drafts restore")
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-tactical-pregame")
	for item: String in SeasonOpponentTactics.ITEMS:
		var card: VBoxContainer = SeasonPlayerCard.panel(app.menu._body, false)
		SeasonPages.wrapped(
			card, "Paid diagnostic club • purchased and consumed in a complete physical game"
		)
		SeasonOpponentTacticsUI.preview(card, _paid[item].club)
		await _frames()
		await _lesson_capture(app, card, "opponent-paid-tactical-" + item)
	app.queue_free()
	await _frames()


func _readiness_guards() -> void:
	var build: SeasonBuild = _paid["A10"].build
	var roster: Array[PlayerDefinition] = []
	for id: String in build.roster():
		roster.append(build.definition(id))
	var team: TeamMatchState = TeamMatchState.create("Readiness unit", roster)
	team.ai_tactical_hitter = _paid["A10"].club.roles.hitter
	team.batting_index = build.roster().find(team.ai_tactical_hitter)
	team.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	var state: MatchState = MatchState.create(team, TeamMatchState.create("Unit opposition", roster))
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_state = state
	lab._match_mode = true
	lab._automation = MatchAutomation.new()
	state.between_batters = false
	SeasonOpponentTactics.prepare(lab)
	_check(team.tactics.held.size() == 1 and team.tactics.consumed.is_empty(),
		"between-pitch readiness cannot consume or choose a supply")
	state.between_batters = true
	SeasonOpponentTactics.prepare(lab)
	SeasonOpponentTactics.prepare(lab)
	_check(team.tactics.consumed.size() == 1 and team.tactics.held.is_empty(),
		"repeated pre-first-pitch preparation consumes one exact copy only")
	team.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	state.record_foul()
	SeasonOpponentTactics.prepare(lab)
	_check(team.tactics.consumed.size() == 1 and team.tactics.held.size() == 1,
		"foul cannot trigger a second activation in the same PA")
	lab.free()


func _capacity_guard() -> void:
	for seed_value in range(2048):
		var build: SeasonBuild = _build(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		var offers: Array[String] = []
		for key: String in build._visit.offers:
			if build._visit.offers[key] in SeasonOpponentTactics.ITEMS:
				offers.append(key)
		if offers.size() < 3:
			continue
		var club: Dictionary = _club(build)
		var generated: Dictionary = SeasonOpponentMarket.offers(build, 0)
		for index in range(2):
			_check(build.commit(SeasonOpponentPolicy.command(build, "tactical_buy",
				{"offer": offers[index]})).ok, "two ordinary paid slots can hold duplicate types")
		var before: Dictionary = build.to_data()
		_check(not build.commit(SeasonOpponentPolicy.command(build, "tactical_buy",
			{"offer": offers[2]})).ok and ClubCareer.same(before, build.to_data()),
			"full-bag purchase atomically preserves displayed offer, paid copies and Cash")
		_check(not SeasonOpponentTactics.purchase(build, club, 0)
			and SeasonOpponentTactics.useful_price(build) == 0,
			"policy cannot overflow or dispose held copies")
		_check(generated == SeasonOpponentMarket.offers(build, 0),
			"held capacity never filters ordinary generated stock")
		return
	_check(false, "ordinary generated three-supply capacity fixture missing")
