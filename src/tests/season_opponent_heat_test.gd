extends "res://src/tests/season_opponent_tactics_test.gd"
## Generated paid Heat acquisition, true releases, version4 and exact shared settlement.

var _heat_probe: OpponentHeatProbe = OpponentHeatProbe.new()


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_heat_units()
	_heat_terminal_unit()
	_heat_history_unit()
	if DisplayServer.get_name() != "headless":
		RenderingServer.set_render_loop_enabled(false)
	await _heat_game(false)
	await _heat_game(true)
	RenderingServer.set_render_loop_enabled(true)
	await _heat_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent Heat checks passed: paid defensive use and actual releases.")
	get_tree().quit(0 if _failures == 0 else 1)


func _build(seed_value: int) -> SeasonBuild:
	var build: SeasonBuild = super._build(seed_value)
	build._market = 9
	return build


func _heat_units() -> void:
	_heat_capacity()
	var bought: int = 0
	var exposed: int = 0
	for seed_value in range(128):
		var build: SeasonBuild = _build(seed_value)
		var stock: Dictionary = SeasonOpponentMarket.offers(build, 0)
		exposed += 1 if stock.values().has(SeasonTacticalCatalog.HEAT) else 0
		var old: SeasonBuild = build._fork()
		old._market = 8
		_check(
			not SeasonOpponentMarket.offers(old, 0).values().has(SeasonTacticalCatalog.HEAT),
			"historical market8 has no Heat stock"
		)
		var poor: SeasonBuild = build._fork()
		poor._bank.commit(
			{"id": "charge", "rev": poor._bank.revision(), "op": "charge", "amount": 18}
		)
		_check(stock == SeasonOpponentMarket.offers(poor, 0), "Heat stock ignores wallet")
		for profile: String in ["Distributed", "Featured hitter", "Pitching / defense"]:
			var buyer: SeasonBuild = _build(seed_value)
			var club: Dictionary = _club(buyer)
			club.profile = profile
			SeasonOpponentPolicy.checkout(buyer, club, 0)
			for decision: Dictionary in club.decisions:
				if decision.get("item") == SeasonTacticalCatalog.HEAT:
					bought += 1
					_check(
						decision.paid == 5 and decision.player == club.roles.pitcher,
						"actual shared5-Cash Heat receipt and saved pitcher role"
					)
			_audit(buyer, club)
	_check(exposed > 0 and bought > 0, "ordinary generated Heat is offered and bought")
	for seed_value in range(512):
		var build: SeasonBuild = _build(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		for offer: String in build._visit.offers:
			if build._visit.offers[offer] != SeasonTacticalCatalog.HEAT:
				continue
			var command: Dictionary = SeasonOpponentPolicy.command(
				build, "tactical_buy", {"offer": offer}
			)
			var poor: SeasonBuild = build._fork()
			poor._bank.commit(
				{"id": "charge", "rev": poor._bank.revision(), "op": "charge", "amount": 14}
			)
			var before: Dictionary = poor.to_data()
			_check(
				not poor.commit(command).ok and ClubCareer.same(before, poor.to_data()),
				"four Cash cannot buy Heat or mutate stock/journal"
			)
			_check(build.commit(command).ok and build.cash() == 13, "real offered Heat costs5")
			before = build.to_data()
			_check(
				build.commit(command).replayed and ClubCareer.same(before, build.to_data()),
				"paid Heat retry creates no extra copy"
			)
			var club: Dictionary = _club(build)
			club.build = build
			club.decisions.append(
				{
					"game": 0,
					"request": command.id,
					"player": club.roles.pitcher,
					"stat": "tactical",
					"item": SeasonTacticalCatalog.HEAT,
					"paid": 5,
					"reason": "paid diagnostic"
				}
			)
			_paid[SeasonTacticalCatalog.HEAT] = {"build": build, "club": club}
			_heat_readiness(build, club)
			return
	_check(false, "generated paid Heat diagnostic missing")


func _heat_readiness(build: SeasonBuild, club: Dictionary) -> void:
	var roster: Array[PlayerDefinition] = []
	for id: String in build.roster():
		roster.append(build.definition(id))
	var state: MatchState = MatchState.create(
		TeamMatchState.create("Batting", roster), TeamMatchState.create("Paid Heat", roster)
	)
	var team: TeamMatchState = state.home_team
	team.ai_heat = true
	team.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_state = state
	lab._match_mode = true
	lab._automation = MatchAutomation.new()
	state.away_team.batting_index = build.roster().find(SeasonOpponentHeat.target(state.away_team))
	state.between_batters = false
	SeasonOpponentHeat.prepare(lab)
	_check(team.tactics.consumed.is_empty(), "between-pitch Heat cannot activate")
	state.between_batters = true
	var first: int = state.away_team.batting_index
	state.away_team.advance_batter()
	SeasonOpponentHeat.prepare(lab)
	_check(team.tactics.consumed.is_empty(), "lower-Power opponent preserves Heat")
	state.away_team.batting_index = first
	SeasonOpponentHeat.prepare(lab)
	SeasonOpponentHeat.prepare(lab)
	_check(
		team.tactics.consumed.size() == 1 and team.tactics.held.is_empty(), "one paid Heat per PA"
	)
	for id: StringName in PitchBatLab.PITCH_IDS:
		var source: PitchDefinition = ContentDB.get_pitch(id)
		var before: float = source.nominal_velocity_mps
		var shared: PitchDefinition = MatchTactics.pitch(source, state)
		_check(
			(
				shared.id == source.id
				and is_equal_approx(shared.nominal_velocity_mps, before * 1.05)
				and source.nominal_velocity_mps == before
			),
			"every recipe keeps identity/natural asset under Heat"
		)
	var rocket: PlayerDefinition = state.pitcher().definition.duplicate(true) as PlayerDefinition
	rocket.season_gear = {"ball": "BALL-VEL-03"}
	for id: StringName in PitchBatLab.PITCH_IDS:
		var mastered: PitchDefinition = PitchMastery.apply(ContentDB.get_pitch(id), 5)
		var rated: PitchDefinition = MatchLabSupport.rated_pitch(mastered, rocket, 1.0)
		var heated: PitchDefinition = MatchTactics.pitch(rated, state)
		_check(
			(
				is_equal_approx(heated.nominal_velocity_mps, mastered.nominal_velocity_mps * 1.155)
				and heated.id == mastered.id
				and heated.mastery_level == 5
			),
			"level5/mastery plus Rocket Ball plus Heat stack once for every recipe"
		)
	state.record_ball()
	state.record_foul()
	_check(team.tactics.active(state) == SeasonTacticalCatalog.HEAT, "balls and fouls retain Heat")
	state.cancel_pitch()
	SeasonOpponentHeat.prepare(lab)
	_check(team.tactics.consumed.size() == 1, "canceled delivery cannot duplicate Heat")
	team.select_pitcher(1)
	_check(
		team.tactics.active(state).is_empty(), "substitution retires Heat instead of transferring"
	)
	state.plate_appearance_number += 1
	_check(team.tactics.active(state).is_empty(), "Heat cannot extend to next PA")
	_check(
		ClubCareer.same(build.to_data(), _paid[SeasonTacticalCatalog.HEAT].build.to_data()),
		"readiness units do not settle season ownership"
	)
	_check(club.roles.has("pitcher"), "paid decision retains saved role")
	lab.free()


func _heat_game(home_heat: bool) -> void:
	var paid: Dictionary = _paid[SeasonTacticalCatalog.HEAT]
	var build: SeasonBuild = SeasonBuild.from_data(
		paid.build.to_data(), paid.build._seed, paid.build.roster()
	)
	var roster: Array[PlayerDefinition] = []
	var other: Array[PlayerDefinition] = []
	for id: String in build.roster():
		roster.append(build.definition(id))
	for id: String in [
		"player.dakota_wells", "player.mika_reed", "player.jamie_nash", "player.quinn_riley"
	]:
		other.append(SeasonBuild.new(9, [id]).definition(id))
	var team: TeamMatchState = TeamMatchState.create("Paid Heat", roster)
	team.ai_sponsor_choices = true
	team.ai_heat = true
	team.ai_tactical_hitter = paid.club.roles.hitter
	team.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	team.ai_tactical_initial.assign(team.tactics.held.duplicate(true))
	var opposition: TeamMatchState = TeamMatchState.create("Ordinary opposition", other)
	var state: MatchState = MatchState.create(
		opposition if home_heat else team, team if home_heat else opposition
	)
	var before: Dictionary = build.to_data()
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var failures: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: failures.append(reason))
	_check(runner.start(state, 67), "paid Heat physical request starts")
	var observed: int = _heat_probe.releases
	for frame in range(300000):
		await get_tree().physics_frame
		_heat_probe.observe(runner._lab, _check)
		if not report.is_empty() or not failures.is_empty():
			break
	_check(failures.is_empty() and PhysicalMatchReport.valid(report), "complete Heat game balances")
	if not report.is_empty():
		_check(
			report.version == 4 and PhysicalTacticalEvidence.report_matches(report, state),
			"report4 binds paid Heat/opposition/actual pitcher"
		)
		_check(
			PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report, "", true, true))),
			"Heat report survives JSON boundary"
		)
		var proof: Dictionary = report.tactics.teams[1 if home_heat else 0]
		_check(
			proof.consumed.size() == 1 and proof.remaining.is_empty(),
			"exact paid Heat consumed once"
		)
		for corruption: String in [
			"price", "target", "opposition", "release", "pitcher", "pa", "remaining", "missing"
		]:
			var bad: Dictionary = report.duplicate(true)
			var row: Dictionary = bad.tactics.teams[1 if home_heat else 0]
			match corruption:
				"price":
					row.initial[0].paid = 3
				"target":
					row.opposition.target = "foreign"
				"opposition":
					row.opposition.stances.pop_back()
				"release":
					row.pitching.pop_back()
				"pitcher":
					row.consumed[0].player = opposition.roster[0].definition.id
				"pa":
					row.consumed[0].pa += 1
				"remaining":
					row.remaining = row.initial.duplicate(true)
				"missing":
					row.consumed.clear()
			_check(not PhysicalMatchReport.valid(bad), "altered Heat " + corruption + " rejects")
		var reward: Dictionary = SeasonOpponentPolicy.command(
			build,
			"reward",
			{
				"game": 1,
				"win":
				(
					report.home_runs > report.away_runs
					if home_heat
					else report.away_runs > report.home_runs
				),
				"performance": report.performance,
				"tactics": proof.consumed
			}
		)
		var invalid: Dictionary = reward.duplicate(true)
		invalid.tactics[0].receipt = "foreign"
		_check(
			not build.commit(invalid).ok and ClubCareer.same(before, build.to_data()),
			"invalid Heat reward rolls back"
		)
		_check(
			build.commit(reward).ok and build._bank.view().held.is_empty(),
			"completed Heat settles shared bag"
		)
		var saved: Dictionary = build.to_data()
		_check(
			build.commit(reward).replayed and ClubCareer.same(saved, build.to_data()),
			"Heat reward pays once"
		)
		_check(
			SeasonBuild.from_data(saved, build._seed, build.roster()) != null,
			"paid consumed Heat replays"
		)
	_check(
		(
			_heat_probe.releases > observed
			and team.tactics.consumed.is_empty()
			and team.tactics.held.size() == 1
		),
		"actual Heat releases and isolated caller bag"
	)
	print(
		"NPC_PAID_HEAT home=",
		home_heat,
		" releases=",
		report.get("releases", []).size(),
		" ",
		_heat_probe.summary()
	)
	runner.queue_free()
	await _frames()


func _heat_ui() -> void:
	var app: SeasonApp = await _app()
	app.begin_season(SEED, true)
	_check(
		app.season.opponents._format == 10 and SeasonSave.snapshot(app.season).version == 54,
		"ordinary new Working start uses save54/policy10"
	)
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
		_check(SeasonSave.restore() != null, "new partial drafts restore")
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-heat-pregame")
	var card: VBoxContainer = SeasonPlayerCard.panel(app.menu._body, false)
	SeasonPages.wrapped(
		card, "Paid Heat diagnostic • generated stock and two complete physical games"
	)
	SeasonOpponentTacticsUI.preview(
		card, _paid[SeasonTacticalCatalog.HEAT].club, app.season._make_team(0)
	)
	await _frames()
	await _lesson_capture(app, card, "opponent-paid-heat")
	app.queue_free()
	await _frames()


func _heat_capacity() -> void:
	for seed_value in range(2048):
		var build: SeasonBuild = _build(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		var offers: Array[String] = []
		for key: String in build._visit.offers:
			if build._visit.offers[key] in SeasonOpponentTactics.supported(9):
				offers.append(key)
		if offers.size() < 3 or not build._visit.offers.values().has(SeasonTacticalCatalog.HEAT):
			continue
		for index in range(2):
			_check(
				(
					build
					. commit(
						SeasonOpponentPolicy.command(
							build, "tactical_buy", {"offer": offers[index]}
						)
					)
					. ok
				),
				"actual Heat/Tape/Plan share two paid held slots"
			)
		var before: Dictionary = build.to_data()
		_check(
			(
				not (
					build
					. commit(
						SeasonOpponentPolicy.command(build, "tactical_buy", {"offer": offers[2]})
					)
					. ok
				)
				and ClubCareer.same(before, build.to_data())
			),
			"third actual supply cannot overflow or alter Cash, stock or journal"
		)
		_check(
			SeasonOpponentTactics.useful_price(build) == 0,
			"full supply bag does not justify a tactical reroll"
		)
		return
	_check(false, "generated mixed Heat capacity fixture missing")


func _heat_terminal_unit() -> void:
	# A seeded boundary unit, not an earned-performance/full physical-game fixture.
	var build: SeasonBuild = _paid[SeasonTacticalCatalog.HEAT].build
	var own: Array[PlayerDefinition] = []
	var other: Array[PlayerDefinition] = []
	for id: String in build.roster():
		own.append(build.definition(id))
	for id: String in [
		"player.dakota_wells", "player.mika_reed", "player.jamie_nash", "player.quinn_riley"
	]:
		other.append(SeasonBuild.new(9, [id]).definition(id))
	var opposition: TeamMatchState = TeamMatchState.create("Boundary batting club", other)
	var strongest: String = SeasonOpponentHeat.target(opposition)
	var index: int = other.find(
		other.filter(func(player: PlayerDefinition) -> bool: return String(player.id) == strongest)[0]
	)
	var target: PlayerDefinition = other[index]
	other.remove_at(index)
	other.append(target)
	opposition = TeamMatchState.create("Boundary batting club", other)
	var team: TeamMatchState = TeamMatchState.create("Boundary Heat club", own)
	team.ai_heat = true
	team.ai_sponsor_choices = true
	team.ai_tactical_hitter = _paid[SeasonTacticalCatalog.HEAT].club.roles.hitter
	team.tactics.held = [
		{"id": "boundary-heat-1", "item": SeasonTacticalCatalog.HEAT, "paid": 5, "kind": "held"},
		{"id": "boundary-heat-2", "item": SeasonTacticalCatalog.HEAT, "paid": 5, "kind": "held"}
	]
	team.ai_tactical_initial.assign(team.tactics.held.duplicate(true))
	var fresh: TeamMatchState = PhysicalMatchRequest._team(team)
	var state: MatchState = MatchState.create(team, opposition)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_state = state
	lab._match_mode = true
	lab._automation = MatchAutomation.new()
	state.top_half = false
	opposition.batting_index = 3
	state.plate_appearance_number = 10
	SeasonOpponentHeat.prepare(lab)
	var ordinal: Array[int] = [0, 0]
	for pa in range(1, 17):
		var half: int = 5 if pa == 16 else int((pa - 1) / 3)
		var batting: TeamMatchState = team if half % 2 == 0 else opposition
		var defense: TeamMatchState = opposition if half % 2 == 0 else team
		var batter: PlayerMatchState = batting.roster[ordinal[half % 2] % 4]
		ordinal[half % 2] += 1
		state.sides.rows.append(
			{
				"pa": pa,
				"half": half,
				"player": String(batter.definition.id),
				"left": batter.bats_left()
			}
		)
		state.performance.complete(
			batter.definition.id,
			defense.current_pitcher().definition.id,
			"triple" if pa == 16 else "out",
			0
		)
		defense.current_pitcher().pitch_count += 1
		if half % 2 == 1:
			state.sure_shot.releases.append(
				{
					"pa": pa,
					"half": half,
					"player": String(team.current_pitcher().definition.id),
					"recipe": String(team.current_pitcher().definition.starting_pitches[0].id)
				}
			)
	state.inning = 3
	opposition.runs = MatchState.MERCY_RUNS - 1
	state.plate_appearance_number = 17
	SeasonOpponentHeat.prepare(lab)
	opposition.tactics.held = [
		{"id": "boundary-base", "item": SeasonTacticalCatalog.BASE, "paid": 8, "kind": "held"}
	]
	state.bases.third = opposition.roster[2].definition.id
	_check(
		opposition.tactics.activate(state, opposition, "boundary-base"),
		"shared human Base causes immediate mercy ending"
	)
	_check(
		state.phase == MatchState.Phase.GAME_END and team.tactics.consumed.size() == 2,
		"terminal Heat is consumed before a mercy ending with no phantom pitch or PA"
	)
	var proof: Dictionary = SeasonOpponentTactics.evidence(state, team)
	_check(
		PhysicalHeatTerminal.ended(proof, 10, 0)
		and not PhysicalHeatTerminal.ended(proof, 1, 0),
		"third-inning terminal use requires the actual mercy margin"
	)
	var walkoff: Dictionary = proof.duplicate(true)
	walkoff.terminal.half = (MatchState.REGULATION_INNINGS - 1) * 2 + 1
	_check(PhysicalHeatTerminal.ended(walkoff, 1, 0), "regulation terminal allows a walk-off")
	var performance: Dictionary = state.performance.snapshot(state)
	var roster: Array = own.map(func(player: PlayerDefinition) -> String: return String(player.id))
	_check(
		(
			SeasonPerformance.valid(performance, roster + proof.opposition.roster)
			and PhysicalHeatEvidence.valid(proof, roster, performance, 0)
		),
		"terminal Heat proof balances completed PAs and exact next PA"
	)
	_check(
		PhysicalTacticalEvidence.matches(proof, fresh, opposition),
		"terminal use binds initial Heat and opposing target"
	)
	_check(
		PhysicalHeatTerminal.human(proof, opposition.tactics.consumed, {"home": 0}),
		"terminal Heat binds actual Base ledger"
	)
	_check(
		not PhysicalHeatTerminal.human(proof, [], {"home": 0}),
		"missing Base consumption cannot authorize terminal Heat"
	)
	for corruption: String in ["pa", "half", "pitcher", "advance", "missing"]:
		var bad: Dictionary = proof.duplicate(true)
		match corruption:
			"pa":
				bad.terminal.pa += 1
			"half":
				bad.terminal.half += 2
			"pitcher":
				bad.terminal.pitcher = strongest
			"advance":
				bad.terminal.advance.to = 3
			"missing":
				bad.erase("terminal")
		_check(
			not PhysicalHeatEvidence.valid(bad, roster, performance, 0),
			"invalid terminal Heat " + corruption + " rejects"
		)
	lab.free()


func _heat_history_unit() -> void:
	var ids: Array[String] = [
		"player.dakota_wells", "player.mika_reed", "player.jamie_nash", "player.quinn_riley"
	]
	for seed_value in range(128):
		var build: SeasonBuild = SeasonBuild.new(seed_value, ids)
		build.commit(
			SeasonOpponentPolicy.command(
				build, "reward", {"game": 0, "win": true, "performance": _performance(build, 0, 0)}
			)
		)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		for offer: String in build._visit.offers:
			if build._visit.offers[offer] != "development.power":
				continue
			_check(
				(
					build
					. commit(
						SeasonOpponentPolicy.command(
							build,
							"buy",
							{
								"offer": offer,
								"mode": "use",
								"player": "player.quinn_riley",
								"pitch": "",
								"replace": ""
							}
						)
					)
					. ok
				),
				"actual paid Power upgrade changes the opposing Heat target"
			)
			build.commit(
				SeasonOpponentPolicy.command(
					build,
					"reward",
					{"game": 1, "win": false, "performance": _performance(build, 0, 0)}
				)
			)
			var restored: SeasonBuild = SeasonBuild.from_data(build.to_data(), seed_value, ids)
			_check(restored != null, "complete paid human development journal validates")
			var before: Dictionary = restored.to_data()
			var early: TeamMatchState = PhysicalHeatEvidence.replay_team(restored, 0, ids)
			var developed: TeamMatchState = PhysicalHeatEvidence.replay_team(restored, 1, ids)
			_check(
				(
					early != null
					and developed != null
					and SeasonOpponentHeat.target(early) == "player.dakota_wells"
					and SeasonOpponentHeat.target(developed) == "player.quinn_riley"
				),
				"Heat replay binds each game's actual earned Power, not initial or future ratings"
			)
			_check(
				(
					ClubCareer.same(before, restored.to_data())
					and PhysicalHeatEvidence.replay_team(restored, 999, ids) == null
				),
				"historical target reconstruction is read-only and rejects missing game"
			)
			return
	_check(false, "actual generated human Power offer missing")
