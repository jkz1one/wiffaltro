extends "res://src/tests/season_opponent_heat_test.gd"
## Generated paid Recovery acquisition, true releases, version5 and exact shared settlement.

var _settled_club: Dictionary = {}
var _recovery_probe: OpponentRecoveryProbe = OpponentRecoveryProbe.new()


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	OpponentRecoveryBoundaries.capacity(_build, _check)
	_recovery_units()
	OpponentRecoveryBoundaries.run(_paid["C02"], _check)
	if DisplayServer.get_name() != "headless":
		RenderingServer.set_render_loop_enabled(false)
	await _recovery_game(false)
	await _recovery_game(true)
	RenderingServer.set_render_loop_enabled(true)
	await _recovery_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent Recovery checks passed: paid defensive use and actual releases.")
	get_tree().quit(0 if _failures == 0 else 1)


func _build(seed_value: int) -> SeasonBuild:
	var build: SeasonBuild = super._build(seed_value)
	build._market = 10
	return build


func _recovery_units() -> void:
	var bought: int = 0
	var exposed: int = 0
	for seed_value in range(128):
		var build: SeasonBuild = _build(seed_value)
		var stock: Dictionary = SeasonOpponentMarket.offers(build, 0)
		exposed += 1 if stock.values().has("C02") else 0
		var old: SeasonBuild = build._fork()
		old._market = 9
		_check(
			not SeasonOpponentMarket.offers(old, 0).values().has("C02"),
			"historical market9 has no Recovery stock"
		)
		var poor: SeasonBuild = build._fork()
		poor._bank.commit(
			{"id": "charge", "rev": poor._bank.revision(), "op": "charge", "amount": 18}
		)
		_check(stock == SeasonOpponentMarket.offers(poor, 0), "Recovery stock ignores wallet")
		for profile: String in ["Distributed", "Featured hitter", "Pitching / defense"]:
			var buyer: SeasonBuild = _build(seed_value)
			var club: Dictionary = _club(buyer)
			club.profile = profile
			SeasonOpponentPolicy.checkout(buyer, club, 0)
			for decision: Dictionary in club.decisions:
				if decision.get("item") == "C02":
					bought += 1
					_check(
						decision.paid == 4 and decision.player == club.roles.pitcher,
						"actual shared4-Cash Recovery receipt and saved pitcher role"
					)
			_audit(buyer, club)
	_check(exposed > 0 and bought > 0, "ordinary generated Recovery is offered and bought")
	for seed_value in range(512):
		var build: SeasonBuild = _build(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		for offer: String in build._visit.offers:
			if build._visit.offers[offer] != "C02":
				continue
			var command: Dictionary = SeasonOpponentPolicy.command(
				build, "tactical_buy", {"offer": offer}
			)
			var poor: SeasonBuild = build._fork()
			poor._bank.commit(
				{"id": "charge", "rev": poor._bank.revision(), "op": "charge", "amount": 15}
			)
			var before: Dictionary = poor.to_data()
			_check(
				not poor.commit(command).ok and ClubCareer.same(before, poor.to_data()),
				"three Cash cannot buy Recovery or mutate stock/journal"
			)
			_check(build.commit(command).ok and build.cash() == 14, "real offered Recovery costs4")
			before = build.to_data()
			_check(
				build.commit(command).replayed and ClubCareer.same(before, build.to_data()),
				"paid Recovery retry creates no extra copy"
			)
			var club: Dictionary = _club(build)
			club.build = build
			club.decisions.append(
				{
					"game": 0,
					"request": command.id,
					"player": club.roles.pitcher,
					"stat": "tactical",
					"item": "C02",
					"paid": 4,
					"reason": "paid diagnostic"
				}
			)
			_paid["C02"] = {"build": build, "club": club}
			_recovery_readiness(build, club)
			return
	_check(false, "generated paid Recovery diagnostic missing")


func _recovery_game(home_recovery: bool) -> void:
	var paid: Dictionary = _paid["C02"]
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
	var team: TeamMatchState = TeamMatchState.create("Paid Recovery", roster)
	team.ai_sponsor_choices = true
	team.ai_heat = true
	team.ai_recovery_pitcher = paid.club.roles.pitcher
	team.pitcher_index = build.roster().find(paid.club.roles.pitcher)
	team.fielder_index = (team.pitcher_index + 1) % 4
	team.ai_tactical_hitter = paid.club.roles.hitter
	team.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	team.ai_tactical_initial.assign(team.tactics.held.duplicate(true))
	var opposition: TeamMatchState = TeamMatchState.create("Ordinary opposition", other)
	var state: MatchState = MatchState.create(
		opposition if home_recovery else team, team if home_recovery else opposition
	)
	var before: Dictionary = build.to_data()
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var failures: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: failures.append(reason))
	_check(runner.start(state, 67), "paid Recovery physical request starts")
	var observed: int = _recovery_probe.releases
	for frame in range(300000):
		await get_tree().physics_frame
		_recovery_probe.observe(runner._lab, _check)
		if not report.is_empty() or not failures.is_empty():
			break
	_check(failures.is_empty() and PhysicalMatchReport.valid(report),
		"complete Recovery game balances")
	if not report.is_empty():
		_check(
			report.version == 5 and PhysicalTacticalEvidence.report_matches(report, state),
			"report5 binds paid Recovery/opposition/actual pitcher"
		)
		_check(
			PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report, "", true, true))),
			"Recovery report survives JSON boundary"
		)
		var changed: TeamMatchState = PhysicalMatchRequest._team(team)
		changed.ai_recovery_pitcher = build.roster()[(team.pitcher_index + 1) % 4]
		var changed_state: MatchState = MatchState.create(
			opposition if home_recovery else changed, changed if home_recovery else opposition)
		_check(not PhysicalTacticalEvidence.report_matches(report, changed_state),
			"paid report cannot retarget the committed Recovery beneficiary")
		var proof: Dictionary = report.tactics.teams[1 if home_recovery else 0]
		_check(
			proof.consumed.size() == 1 and proof.remaining.is_empty(),
			"exact paid Recovery consumed once"
		)
		for corruption: String in [
			"price", "target", "opposition", "release", "pitcher", "pa", "remaining", "missing",
			"ready", "capacity", "final", "cost", "refunder", "recovered_twice"
		]:
			var bad: Dictionary = report.duplicate(true)
			var row: Dictionary = bad.tactics.teams[1 if home_recovery else 0]
			match corruption:
				"ready":
					row.recovery.ready[0].remaining -= 1.0
				"capacity":
					row.recovery.initial.values()[0].capacity += 1.0
				"final":
					row.recovery.remaining[row.recovery.pitcher] += 1.0
				"cost":
					row.recovery.costs[0].paid += 1.0
				"refunder":
					row.recovery.refunders.append("foreign")
				"recovered_twice":
					row.consumed.append(row.consumed[0].duplicate(true))
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
			_check(not PhysicalMatchReport.valid(bad), "altered Recovery " + corruption + " rejects")
		var reward: Dictionary = SeasonOpponentPolicy.command(
			build,
			"reward",
			{
				"game": 1,
				"win":
				(
					report.home_runs > report.away_runs
					if home_recovery
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
			"invalid Recovery reward rolls back"
		)
		_check(
			build.commit(reward).ok and build._bank.view().held.is_empty(),
			"completed Recovery settles shared bag"
		)
		var saved: Dictionary = build.to_data()
		_settled_club = paid.club.duplicate(true)
		_settled_club.build = build
		_check(
			build.commit(reward).replayed and ClubCareer.same(saved, build.to_data()),
			"Recovery reward pays once"
		)
		_check(
			SeasonBuild.from_data(saved, build._seed, build.roster()) != null,
			"paid consumed Recovery replays"
		)
	_check(
		(
			_recovery_probe.releases > observed
			and team.tactics.consumed.is_empty()
			and team.tactics.held.size() == 1
		),
		"actual Recovery releases and isolated caller bag"
	)
	print(
		"NPC_PAID_RECOVERY home=",
		home_recovery,
		" releases=",
		report.get("releases", []).size(),
		" ",
		_recovery_probe.summary()
	)
	runner.queue_free()
	await _frames()


func _recovery_ui() -> void:
	var app: SeasonApp = await _app()
	app.begin_season(SEED, true)
	_check(
		app.season.opponents._format == 11 and SeasonSave.snapshot(app.season).version == 55,
		"ordinary new Working start uses save55/policy11"
	)
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
		_check(SeasonSave.restore() != null, "new partial drafts restore")
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-recovery-pregame")
	var card: VBoxContainer = SeasonPlayerCard.panel(app.menu._body, false)
	SeasonPages.wrapped(
		card, "Paid Recovery diagnostic • generated stock and two complete physical games"
	)
	SeasonOpponentTacticsUI.preview(
		card, _settled_club, app.season._make_team(0)
	)
	await _frames()
	await _lesson_capture(app, card, "opponent-paid-recovery")
	for node: Node in card.find_children("*", "Label", true, false):
		if node.has_meta("opponent_tactical_used"):
			var scroll: ScrollContainer = app.menu._body.get_parent()
			scroll.ensure_control_visible(node)
			await _frames()
			await _capture(get_viewport(), "opponent-paid-recovery-used")
			break
	app.queue_free()
	await _frames()


func _recovery_readiness(build: SeasonBuild, club: Dictionary) -> void:
	var roster: Array[PlayerDefinition] = []
	for id: String in build.roster():
		roster.append(build.definition(id))
	var state: MatchState = MatchState.create(
		TeamMatchState.create("Batting", roster), TeamMatchState.create("Recovery", roster)
	)
	var team: TeamMatchState = state.home_team
	team.ai_heat = true
	team.ai_recovery_pitcher = club.roles.pitcher
	team.pitcher_index = build.roster().find(club.roles.pitcher)
	# Boundary-only mixed bag; paid acquisition is checked separately above.
	team.tactics.held = [
		{"id": "boundary-recovery", "item": "C02", "paid": 4, "kind": "held"},
		{"id": "boundary-heat", "item": SeasonTacticalCatalog.HEAT, "paid": 5, "kind": "held"}
	]
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_state = state
	lab._match_mode = true
	lab._automation = MatchAutomation.new()
	var pitcher: PlayerMatchState = state.pitcher()
	var capacity: float = pitcher.stamina_max
	pitcher.stamina_remaining = capacity * 0.90001
	team.recovery.initialize(team)
	SeasonOpponentRecovery.prepare(lab)
	_check(team.tactics.consumed.is_empty(), "Recovery waits for ten percent actual expenditure")
	state.plate_appearance_number += 1
	pitcher.stamina_remaining = capacity * 0.89
	state.away_team.batting_index = build.roster().find(SeasonOpponentHeat.target(state.away_team))
	SeasonOpponentRecovery.prepare(lab)
	SeasonOpponentHeat.prepare(lab)
	SeasonOpponentRecovery.prepare(lab)
	_check(team.tactics.consumed.size() == 1 and team.tactics.held[0].item == (
		SeasonTacticalCatalog.HEAT), "Recovery takes precedence over Heat and cannot duplicate")
	_check(PhysicalRecoveryFlow.near(pitcher.stamina_remaining, capacity * 0.99),
		"shared Recovery restores ten percent of unchanged game-start capacity")
	state.record_ball()
	state.record_foul()
	state.cancel_pitch()
	SeasonOpponentRecovery.prepare(lab)
	_check(team.tactics.consumed.size() == 1, "ball, foul and canceled delivery cannot recover twice")
	state.plate_appearance_number += 1
	state.phase = MatchState.Phase.PRE_PITCH
	state.between_batters = true
	team.tactics.held.append(
		{"id": "boundary-recovery-2", "item": "C02", "paid": 4, "kind": "held"})
	pitcher.stamina_remaining = capacity * 0.5
	SeasonOpponentRecovery.prepare(lab)
	SeasonOpponentHeat.prepare(lab)
	_check(team.tactics.consumed.size() == 2 and team.tactics.held[0].item == "C02",
		"once-per-pitcher cap preserves next Recovery while legal Heat can be used")
	state.plate_appearance_number += 1
	var replacement: int = (team.pitcher_index + 1) % 4
	team.select_pitcher(replacement)
	state.pitcher().stamina_remaining *= 0.5
	var before: float = state.pitcher().stamina_remaining
	SeasonOpponentRecovery.prepare(lab)
	_check(team.tactics.consumed.size() == 2 and state.pitcher().stamina_remaining == before,
		"substitute cannot inherit the planned pitcher's unused Recovery")
	_check(pitcher.stamina_max == capacity and build._bank.view().held.size() == 1,
		"shared boundary use preserves original season ownership and stamina capacity")
	lab.free()
