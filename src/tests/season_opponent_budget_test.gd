extends "res://src/tests/season_opponent_recovery_test.gd"
# Historical full-roster fixture; permanent-player defaults have separate integration tests.
## Paid generated stock, pure commitments, free-copy provenance and real physical use.

var _budget_paid: SeasonBuild
var _budget_club: Dictionary = {}


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_budget_units()
	if DisplayServer.get_name() != "headless":
		RenderingServer.set_render_loop_enabled(false)
	if _budget_paid != null:
		await _budget_game(false)
		await _budget_game(true)
	RenderingServer.set_render_loop_enabled(true)
	await _budget_ui_review()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent Budget checks passed: paid sponsor, committed grant and physical use.")
	get_tree().quit(0 if _failures == 0 else 1)


func _budget_build(seed_value: int) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(seed_value, ["player.alex_finch", "player.lee_stone",
		"player.rowan_chase", "player.gray_west"])
	build._market = 11
	_check(build.commit(SeasonOpponentPolicy.command(build, "reward", {
		"game": 0, "win": false, "performance": {}})).ok, "synthetic twelve-Cash stock fixture")
	return build


func _budget_units() -> void:
	var policy_bought: int = 0
	for seed_value in range(256):
		var build: SeasonBuild = _budget_build(seed_value)
		var old: SeasonBuild = build._fork()
		old._market = 10
		_check(not SeasonOpponentSponsors.pool(old).has("E08"), "market10 pool stays frozen")
		var club: Dictionary = _club(build)
		club.profile = "Distributed"
		var poor: SeasonBuild = build._fork()
		poor._charge(8)
		_check(SeasonOpponentSponsors.offers(poor, 0) == SeasonOpponentSponsors.offers(build, 0),
			"budget qualification never filters stock by Cash")
		SeasonOpponentPolicy.checkout(build, club, 0)
		policy_bought += club.decisions.filter(func(row: Dictionary) -> bool:
			return row.get("item") == "E08").size()
		if _budget_paid != null:
			continue
		var candidate: SeasonBuild = _budget_build(seed_value)
		candidate.commit(SeasonOpponentPolicy.command(candidate, "open"))
		for offer: String in candidate._visit.offers:
			if candidate._visit.offers[offer] != "E08":
				continue
			_check(candidate.commit(SeasonOpponentPolicy.command(candidate, "sponsor_buy", {
				"offer": offer, "replace": ""})).ok, "actual generated sponsor costs10")
			_budget_paid = candidate
			_budget_club = _club(candidate)
			_budget_club.profile = "Distributed"
			break
	_check(policy_bought > 0 and _budget_paid != null, "bounded policy buys actual Budget stock")
	if _budget_paid == null:
		return
	_check(_budget_paid.cash() == 2, "paid sponsor leaves two Cash")
	for cash_value: int in [0, 4, 5]:
		for held_count in range(3):
			var build: SeasonBuild = _budget_paid._fork()
			# Boundary-only fixture; full round tests use earned wallets and ordinary copies.
			build._bank._state.cash = cash_value
			build._bank._state.held.clear()
			for index in range(held_count):
				build._bank._state.held.append({"id": "paid:%d" % index,
					"item": "A10", "paid": 3, "kind": "held"})
			var team: TeamMatchState = _budget_team(build)
			var before: Dictionary = build.to_data()
			SeasonOpponentBudget.prepare(team, build, 1)
			var expected: int = 1 if cash_value <= 4 and held_count < 2 else 0
			_check(team.tactics.held.size() == held_count + expected, "threshold/shared capacity")
			var copies: Array = team.tactics.held.duplicate(true)
			SeasonOpponentBudget.prepare(team, build, 1)
			_check(ClubCareer.same(copies, team.tactics.held)
				and ClubCareer.same(before, build.to_data()), "projection/restart never mutates or duplicates")
	var copy: SeasonBuild = _budget_paid._fork()
	_check(SeasonOpponentBudget.commit(copy, 1), "once-game commitment succeeds")
	var valid_team: TeamMatchState = _budget_team(_budget_paid)
	SeasonOpponentBudget.prepare(valid_team, _budget_paid, 1)
	var malformed: TeamMatchState = PhysicalMatchRequest._team(valid_team)
	_check(malformed != null, "valid Budget source can be copied")
	malformed.ai_recovery_pitcher = ""
	_check(PhysicalMatchRequest._team(malformed) == null, "partial Budget policy rejects at capture")
	malformed = PhysicalMatchRequest._team(valid_team)
	malformed.ai_budget.cash = 5
	_check(PhysicalMatchRequest._team(malformed) == null, "contradictory grant rejects at capture")
	var before: Dictionary = copy.to_data()
	_check(SeasonOpponentBudget.commit(copy, 1) and ClubCareer.same(before, copy.to_data()),
		"repeat commit creates no new receipt")
	_check(SeasonBuild.from_data(copy.to_data(), copy._seed, copy.roster()) != null,
		"grant journal round-trips")
	_budget_atomic_and_carry()
	print("NPC_BUDGET_POLICY purchases=", policy_bought)


func _budget_atomic_and_carry() -> void:
	var inactive: SeasonBuild = _budget_build(11)
	var untouched: Dictionary = inactive.to_data()
	_check(SeasonOpponentBudget.commit(inactive, 1)
		and ClubCareer.same(untouched, inactive.to_data()), "inactive sponsor adds no grant journal")
	var opponents: SeasonOpponents = SeasonOpponents.new()
	opponents._format = 12
	var build: SeasonBuild = _budget_paid._fork()
	var club: Dictionary = _club(build)
	club["build"] = build
	opponents.clubs["1"] = club
	var before: Dictionary = build.to_data()
	opponents.settle([{"id": 1, "home": 1, "away": 0, "home_runs": 1, "away_runs": 0,
		"performance": {}, "ai_tactics": {"1": {"consumed": [{"receipt": "foreign",
			"player": club.roles.hitter, "pa": 1, "swing": "swing.contact"}]}}}], [])
	_check(ClubCareer.same(before, opponents.clubs["1"].build.to_data()),
		"invalid round reward cannot publish the prior grant or its journal")
	_check(SeasonOpponentBudget.commit(build, 1), "unused grant starts in exact shared bag")
	_check(build.commit(SeasonOpponentPolicy.command(build, "reward", {
		"game": 1, "win": false, "performance": {}, "tactics": []})).ok,
		"synthetic carry boundary preserves unused copy")
	var team: TeamMatchState = _budget_team(build)
	SeasonOpponentBudget.prepare(team, build, 2)
	_check(team.ai_budget.outcome == "cash" and team.tactics.held.size() == 1
		and team.tactics.held[0].id == "budget:1" and team.tactics.held[0].paid == 0,
		"rich following game carries old Plan without a new grant")
	_check(PhysicalMatchRequest._team(team) != null, "carried zero-paid copy captures legally")


func _budget_team(build: SeasonBuild) -> TeamMatchState:
	var definitions: Array[PlayerDefinition] = []
	for id: String in build.roster():
		definitions.append(build.definition(id))
	var team: TeamMatchState = TeamMatchState.create("Paid Budget Bites", definitions)
	var role: Dictionary = _budget_club.roles
	team.ai_sponsor_choices = true
	team.ai_heat = true
	team.ai_recovery_pitcher = role.pitcher
	team.ai_tactical_hitter = role.hitter
	team.pitcher_index = build.roster().find(role.pitcher)
	team.fielder_index = build.roster().find(role.fielder)
	return team


func _budget_game(home: bool) -> void:
	var build: SeasonBuild = _budget_paid._fork()
	var team: TeamMatchState = _budget_team(build)
	SeasonOpponentBudget.prepare(team, build, 1)
	var definitions: Array[PlayerDefinition] = []
	for id: String in ["player.dakota_wells", "player.mika_reed",
		"player.jamie_nash", "player.quinn_riley"]:
		definitions.append(SeasonBuild.new(9, [id]).definition(id))
	var opposition: TeamMatchState = TeamMatchState.create("Ordinary opposition", definitions)
	var state: MatchState = MatchState.create(
		opposition if home else team, team if home else opposition)
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	_check(runner.start(state, 67), "budget physical match starts")
	for frame in range(300000):
		await get_tree().physics_frame
		if not report.is_empty() or not errors.is_empty():
			break
	_check(errors.is_empty() and PhysicalMatchReport.valid(report), "real Budget game balances")
	if not report.is_empty():
		var proof: Dictionary = report.tactics.teams[1 if home else 0]
		_check(report.version == 6 and proof.version == 4
			and PhysicalTacticalEvidence.report_matches(report, state), "report6 binds exact grant")
		_check(proof.initial[0].paid == 0 and proof.consumed.size() == 1
			and proof.remaining.is_empty(), "ordinary Plan consumed once on featured batter")
		_check(PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report))), "JSON proof agrees")
		for field: String in ["cash", "active", "game", "before", "outcome", "paid", "copy", "missing"]:
			var bad: Dictionary = report.duplicate(true)
			var row: Dictionary = bad.tactics.teams[1 if home else 0]
			match field:
				"cash": row.budget.cash = 5
				"active": row.budget.active = false
				"game": row.budget.game = 2
				"before": row.budget.before = row.initial.duplicate(true)
				"outcome": row.budget.outcome = "full"
				"paid": row.initial[0].paid = 3
				"copy": row.initial[0].id = "invented"
				"missing": row.consumed.clear()
			_check(not PhysicalMatchReport.valid(bad), "altered grant " + field + " rejects")
		_check(SeasonOpponentBudget.commit(build, 1), "settlement publishes exact projected pregame")
		var reward: Dictionary = SeasonOpponentPolicy.command(build, "reward", {
			"game": 1, "win": (report.home_runs > report.away_runs) == home,
			"performance": report.performance, "tactics": proof.consumed})
		_check(build.commit(reward).ok and build._bank.view().held.is_empty(),
			"zero-paid copy settles through shared reward")
		_check(SeasonBuild.from_data(build.to_data(), build._seed, build.roster()) != null,
			"full grant/consumption journal replays")
		_budget_club.build = build
		print("NPC_BUDGET_GAME home=", home, " releases=", report.releases.size())
	runner.queue_free()
	await _frames()


func _budget_ui_review() -> void:
	var app: SeasonApp = await _app()
	app.begin_season(SEED, true, false)
	app.season.opponents._format = 12
	_check(SeasonSave.save(app.season), "historical policy12 partial draft saves")
	_check(app.season.opponents._format == 12 and SeasonSave.snapshot(app.season).version == 56,
		"new ordinary Working start is policy12/save56")
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
		_check(SeasonSave.restore() != null, "partial policy12 draft restores")
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-budget-pregame")
	if not _budget_club.is_empty():
		var card: VBoxContainer = SeasonPlayerCard.panel(app.menu._body, false)
		SeasonPages.wrapped(card, "Paid Budget Bites diagnostic • two complete physical games")
		SeasonOpponentSponsorsUI.preview(card, _budget_club)
		SeasonOpponentTacticsUI.preview(card, _budget_club, app.season._make_team(0))
		await _frames()
		app.menu._body.get_parent().scroll_vertical = 100000
		await _frames()
		await _capture(get_viewport(), "opponent-budget-history")
	app.queue_free()
	await _frames()
