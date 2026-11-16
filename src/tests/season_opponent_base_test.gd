extends "res://src/tests/season_opponent_budget_test.gd"
## Actual generated Base stock/physical use; terminal proof is an explicit scripted boundary.

var _base_paid: SeasonBuild
var _base_club: Dictionary = {}


func _ready() -> void:
	_base_units()
	if _base_paid != null:
		_terminal_base()
		_terminal_base(true)
		_terminal_base(false, true)
		_priority_base()
		_budget_base_pair()
		await _base_game(false)
		await _base_game(true)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent Base checks passed: paid stock, physical scoring and terminal proof.")
	get_tree().quit(0 if _failures == 0 else 1)


func _base_build(seed_value: int) -> SeasonBuild:
	var build: SeasonBuild = _build(seed_value)
	build._market = 12
	return build


func _base_units() -> void:
	var bought: int = 0
	var counts: Dictionary = {}
	var weights: Dictionary = SeasonOpponentTactics.pool(12)
	var total: float = 0.0
	for weight: float in weights.values():
		total += weight
	_check(weights.size() == 5 and is_equal_approx(weights[SeasonTacticalCatalog.BASE] / total, 0.05),
		"five-type pool retains ordinary5% conditional Base weight")
	for seed_value in range(512):
		var build: SeasonBuild = _base_build(seed_value)
		for item: String in SeasonOpponentMarket.offers(build, 0).values():
			if weights.has(item):
				counts[item] = counts.get(item, 0) + 1
		var club: Dictionary = _club(build)
		SeasonOpponentPolicy.checkout(build, club, 0)
		bought += club.decisions.filter(func(row: Dictionary) -> bool:
			return row.get("item") == SeasonTacticalCatalog.BASE).size()
		if _base_paid != null:
			continue
		build = _base_build(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		for offer: String in build._visit.offers.keys():
			if build._visit.offers[offer] != SeasonTacticalCatalog.BASE:
				continue
			var before: int = build.cash()
			_check(build.commit(SeasonOpponentPolicy.command(build, "tactical_buy",
				{"offer": offer})).ok and build.cash() == before - 8, "actual offered Base costs8")
			_base_paid = build
			_base_club = _club(build)
			break
	_check(_base_paid != null and bought > 0 and counts.size() == 5,
		"ordinary finite stock exposes all five and policy buys paid Base")
	_check(not SeasonOpponentTactics.supported(11).has(SeasonTacticalCatalog.BASE),
		"historical market11 stays four-type")
	if _base_paid != null:
		var partial: TeamMatchState = _base_team(_base_paid)
		partial.ai_base = false
		_check(PhysicalMatchRequest._team(partial) == null, "Base cannot enter historical market policy")
		partial = _base_team(_base_paid)
		partial.ai_budget = {}
		_check(PhysicalMatchRequest._team(partial) == null,
			"Base requires the complete prior policy chain")
	print("NPC_BASE_STOCK ", counts, " policy_purchases=", bought)


func _base_team(build: SeasonBuild) -> TeamMatchState:
	_budget_club = _base_club
	var team: TeamMatchState = _budget_team(build)
	team.ai_base = true
	SeasonOpponentBudget.prepare(team, build, 1)
	return team


func _base_other(controlled: bool = false) -> TeamMatchState:
	var definitions: Array[PlayerDefinition] = []
	for id: String in ["player.dakota_wells", "player.mika_reed",
		"player.jamie_nash", "player.quinn_riley"]:
		definitions.append(SeasonBuild.new(9, [id]).definition(id))
	var team: TeamMatchState = TeamMatchState.create("Base opposition", definitions)
	if controlled:
		team.ai_sponsor_choices = true
		team.ai_base = true
		team.ai_heat = true
		team.ai_recovery_pitcher = String(definitions[0].id)
		team.ai_tactical_hitter = String(definitions[0].id)
		team.ai_budget = {"game": 1, "cash": 0, "active": false, "before": [], "outcome": "inactive"}
	return team


func _terminal_base(extra: bool = false, mercy: bool = false) -> void:
	var state: MatchState = MatchState.create(_base_other(true), _base_team(_base_paid))
	var fresh: MatchState = PhysicalMatchRequest.capture(state)
	_check(fresh != null, "paid Base plus empty controlled defense captures")
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_mode = true
	lab._match_state = state
	lab._automation = MatchAutomation.new()
	for appearance in range(15 if mercy else 33 if extra else 27):
		if mercy and appearance == 3:
			for homer in range(9):
				SeasonOpponentChoices.prepare(lab)
				_boundary_release(state)
				state.begin_ball_in_play()
				state.record_hit(BallPlayOutcome.Result.HOME_RUN)
				state.continue_after_dead_ball()
		SeasonOpponentChoices.prepare(lab)
		for strike in range(3):
			_boundary_release(state)
			state.record_strike(false)
			state.continue_after_dead_ball()
	SeasonOpponentChoices.prepare(lab)
	_boundary_release(state)
	state.begin_ball_in_play()
	if extra:
		var position: Vector3 = Vector3(30, 0, 30)
		var rating: int = state.fielder().definition.fielding
		state.base_flow.tag(state, position, rating, 1.0, 1.0, String(state.fielder().definition.id))
		var tagged: TagAdvanceResult = TagAdvanceResolver.resolve(state.bases, position, rating)
		_check(tagged.advanced_from_second, "shared catch advances the actual extra-inning runner")
		state.record_ball_in_play_out(tagged.runs_scored)
	else:
		state.record_hit(BallPlayOutcome.Result.TRIPLE)
	state.continue_after_dead_ball()
	var before: Dictionary = state.performance.snapshot(state)
	SeasonOpponentChoices.prepare(lab)
	_check(state.phase == MatchState.Phase.GAME_END and state.home_team.runs == (10 if mercy else 1)
		and ClubCareer.same(before, state.performance.snapshot(state)),
		"shared AI Base ends scripted walk-off/mercy without fake PA or RBI")
	for index in range(2):
		var team: TeamMatchState = state.away_team if index == 0 else state.home_team
		var proof: Dictionary = SeasonOpponentTactics.evidence(state, team)
		var roster: Array = team.roster.map(func(player: PlayerMatchState) -> String:
			return String(player.definition.id))
		_check(PhysicalBaseEvidence.valid(proof, roster, before, index),
			"both terminal proofs preserve actual readiness and exact bag")
		var restored: Dictionary = JSON.parse_string(JSON.stringify(proof))
		_check(PhysicalBaseEvidence.valid(restored, roster, before, index),
			"terminal proof survives JSON")
		_check(PhysicalTacticalEvidence.matches(proof, fresh.away_team if index == 0 else fresh.home_team,
			fresh.home_team if index == 0 else fresh.away_team), "terminal binds immutable paid source")
		if index == 0:
			_check(PhysicalBaseEvidence.human(proof, state.home_team.tactics.consumed, 1)
				and not PhysicalBaseEvidence.human(proof, [], 1),
				"opponent terminal requires the exact corresponding human Base ledger")
			_check(not PhysicalBaseEvidence.human(proof, ["malformed"], 1),
				"malformed human ledger rejects without a script exception")
		var bad: Dictionary = proof.duplicate(true)
		if extra:
			bad.base.tags[0].rating += 1
			_check(not PhysicalTacticalEvidence.matches(bad,
				fresh.away_team if index == 0 else fresh.home_team,
				fresh.home_team if index == 0 else fresh.away_team), "edited AI catcher rating rejects")
		bad = proof.duplicate(true)
		bad.base.advances.clear()
		_check(not PhysicalBaseEvidence.valid(bad, roster, before, index),
			"missing terminal advance fails")
	lab.free()


func _boundary_release(state: MatchState) -> void:
	_check(state.begin_pitch(), "scripted boundary pitch is legal")
	var recipe: StringName = state.pitcher().definition.starting_pitches[0].id
	state.pitcher().spend_stamina(0.1)
	state.note_pitch_released(recipe, 0.1)


func _base_game(home: bool) -> void:
	var team: TeamMatchState = _base_team(_base_paid)
	var other: TeamMatchState = _base_other()
	var state: MatchState = MatchState.create(other if home else team, team if home else other)
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	var retained: Array = [null]
	runner.failed.connect(func(reason: String) -> void:
		errors.append(reason)
		if retained[0] != null:
			_debug_base(PhysicalMatchReport.capture(retained[0])))
	_check(runner.start(state, 67), "paid Base physical fixture starts")
	retained[0] = runner._lab
	for frame in range(300000):
		await get_tree().physics_frame
		if not report.is_empty() or not errors.is_empty():
			break
	_check(errors.is_empty() and PhysicalMatchReport.valid(report),
		"paid Base physical report balances")
	if not report.is_empty():
		var index: int = 1 if home else 0
		var proof: Dictionary = PhysicalBaseEvidence.enriched(report.tactics.teams[index],
			report.tactics.base)
		_check(report.version == 7 and PhysicalTacticalEvidence.report_matches(report, state),
			"report7 binds actual paid source and rules")
		_check(PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report))),
			"report7 JSON agrees")
		for field: String in ["price", "ready", "score", "result", "policy", "extra", "used"]:
			var bad: Dictionary = report.duplicate(true)
			match field:
				"price": bad.tactics.teams[index].initial[0].paid = 0
				"ready": bad.tactics.base.ready[0].away += 1
				"score": bad.away_runs += 1
				"result": bad.tactics.base.results[0].rbi += 1
				"policy": bad.tactics.teams[index].version = 4
				"extra": bad.tactics.teams[index]["base"] = bad.tactics.base
				"used":
					bad.tactics.teams[index].consumed.clear()
					bad.tactics.teams[index].remaining.clear()
			_check(not PhysicalMatchReport.valid(bad), "changed Base report " + field + " rejects")
		var consumed: int = proof.consumed.size()
		_check(consumed <= 1 and proof.remaining.size() == 1 - consumed, "no forced use or free copy")
		var build: SeasonBuild = _base_paid._fork()
		_check(build.commit(SeasonOpponentPolicy.command(build, "reward", {"game": 1,
			"win": (report.home_runs > report.away_runs) == home,
			"performance": report.performance, "tactics": proof.consumed})).ok,
			"actual consumed Base settles or unused Base carries")
		_check(SeasonBuild.from_data(build.to_data(), build._seed, build.roster()) != null,
			"market12 paid Base journal replays")
		print("NPC_BASE_GAME home=", home, " releases=", report.releases.size(),
			" consumed=", consumed, " supply_runs=", PhysicalBaseReport.runs(report, index))
	runner.queue_free()
	await _frames()


func _debug_base(report: Dictionary) -> void:
	print("BASE_DEBUG flow=", PhysicalBaseReport.flow_valid(report),
		" links=", PhysicalBaseReport.links(report))
	for index in range(2):
		if not report.tactics.clubs[index]:
			continue
		var row: Dictionary = PhysicalBaseEvidence.enriched(report.tactics.teams[index],
			report.tactics.base)
		var preempted: Variant = PhysicalBaseBag.preempted(row, index)
		print("BASE_DEBUG side=", index, " valid=", PhysicalBaseEvidence.valid(row,
			report.teams[index].roster, report.performance, index), " preempted=", preempted,
			" terminal=", PhysicalBaseEvidence.terminal(row, index))
		if preempted != null:
			print("BASE_DEBUG recovery=", PhysicalRecoveryEvidence.valid(
				PhysicalBaseBag.recovery(row, true), report.teams[index].roster,
				report.performance, index, preempted))


func _priority_base(pair: SeasonBuild = null) -> void:
	var home: TeamMatchState = _base_team(_base_paid if pair == null else pair)
	home.ai_tactical_hitter = String(home.roster[1].definition.id)
	if pair == null:
		# Explicit two-copy selection boundary, not a claimed second generated purchase.
		home.tactics.held.append({"id": "boundary-tape", "item": "A10", "paid": 3, "kind": "held"})
		home.ai_tactical_initial.assign(home.tactics.held.duplicate(true))
		home.ai_budget.before = home.tactics.held.duplicate(true)
	var deferred: String = home.tactics.held[1].id
	var item: String = home.tactics.held[1].item
	var state: MatchState = MatchState.create(_base_other(true), home)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_mode = true
	lab._match_state = state
	lab._automation = MatchAutomation.new()
	for appearance in range(60):
		if state.phase == MatchState.Phase.GAME_END:
			break
		SeasonOpponentChoices.prepare(lab)
		if state.plate_appearance_number == 5:
			_check(home.tactics.consumed.size() == 1 and home.tactics.held.size() == 1
				and home.tactics.held[0].item == item, "Base preempts the featured offensive copy")
			SeasonOpponentChoices.prepare(lab)
			_check(home.tactics.consumed.size() == 1, "repeated readiness cannot consume a second card")
		if state.plate_appearance_number == 4:
			_boundary_release(state)
			state.begin_ball_in_play()
			state.record_hit(BallPlayOutcome.Result.TRIPLE)
			state.continue_after_dead_ball()
		else:
			for strike in range(3):
				_boundary_release(state)
				state.record_strike(false)
				state.continue_after_dead_ball()
	var row: Dictionary = SeasonOpponentTactics.evidence(state, home)
	var roster: Array = home.roster.map(func(player: PlayerMatchState) -> String:
		return String(player.definition.id))
	_check(state.phase == MatchState.Phase.GAME_END and home.tactics.consumed.size() == 2
		and home.tactics.consumed[0].has("advance")
		and home.tactics.consumed[1].receipt == deferred,
		"deferred offensive copy remains usable at a later featured PA")
	_check(PhysicalBaseEvidence.valid(row, roster, state.performance.snapshot(state), 1),
		"Base priority and later offensive use replay in exact chronological order")
	if pair != null:
		_check(SeasonOpponentBudget.commit(pair, 1), "exact projected grant commits once")
		_check(pair.commit(SeasonOpponentPolicy.command(pair, "reward", {"game": 1,
			"win": true, "performance": state.performance.snapshot(state),
			"tactics": row.consumed})).ok and pair._bank.view().held.is_empty(),
			"paid Base plus zero-paid Plan settle together through the shared wallet")
		_check(SeasonBuild.from_data(pair.to_data(), pair._seed, pair.roster()) != null,
			"Base/Budget purchase, grant, delayed use and reward replay exactly")
	lab.free()


func _budget_base_pair() -> void:
	for seed_value in range(8192):
		var build: SeasonBuild = _base_build(seed_value)
		var stock: Dictionary = SeasonOpponentMarket.offers(build, 0)
		if not stock.values().has(SeasonTacticalCatalog.BASE) or not stock.values().has("E08"):
			continue
		_check(build.commit(SeasonOpponentPolicy.command(build, "open")).ok, "open actual mixed stock")
		# Diagnostic legal purchase ordering; not a claim about the AI's sponsor-first ranking.
		for item: String in [SeasonTacticalCatalog.BASE, "E08"]:
			for offer: String in build._visit.offers.keys():
				if build._visit.offers[offer] != item:
					continue
				var fields: Dictionary = {"offer": offer}
				if item == "E08":
					fields["replace"] = ""
				_check(build.commit(SeasonOpponentPolicy.command(build,
					"sponsor_buy" if item == "E08" else "tactical_buy", fields)).ok,
					"both actual generated offers are paid at full price")
				break
		_check(build.cash() == 0 and SeasonBudgetBites.outcome(build) == "granted",
			"paid8-Cash Base and10-Cash sponsor leave one real grant slot")
		_priority_base(build)
		print("NPC_BASE_BUDGET_PAIR seed=", seed_value)
		return
	_check(false, "bounded ordinary stock search finds Base/Budget pair")
