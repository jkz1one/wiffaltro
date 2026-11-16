extends "res://src/tests/league_physical_proof_test.gd"
## Real detached game; paid ownership fixture is synthetic, not earned season progression.


func _ready() -> void:
	var season: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("dugout"), true
	)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "detached roster draft")
	var state: MatchState = MatchState.create(season._make_team(1, 8), season._make_team(2, 8))
	state.league_rules = LeagueRules.capture("dugout")
	var banks: Array[SeasonOwnership] = [fixture("dugout", 3), fixture("dugout", 4, ["E08", "G02"])]
	var teams: Array[TeamMatchState] = [state.away_team, state.home_team]
	for index in range(2):
		var bank: SeasonOwnership = banks[index]
		var team: TeamMatchState = teams[index]
		var row: Dictionary = budget_row(bank)
		team.league_ownership = bank.to_data()
		team.ai_budget = row.budget.duplicate(true)
		team.ai_tactical_initial.assign(row.initial.duplicate(true))
		team.tactics.held.assign(row.initial.duplicate(true))
		MatchFieldSupply.sync_capacity(team, bank.view())
		check(PhysicalLeagueReport.team_valid(team), "bound expanded paid bag")
	check(PhysicalMatchRequest.capture(state) != null, "expanded detached request admitted")
	var before: Array = [banks[0].to_data(), banks[1].to_data()]
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	var started_ms: int = Time.get_ticks_msec()
	var frames: int = 0
	var started: bool = runner.start(state, 443)
	check(started, "actual expanded-bag physical game starts")
	if started:
		for frame in range(300000):
			await get_tree().physics_frame
			frames += 1
			if not report.is_empty() or not errors.is_empty():
				break
	check(errors.is_empty() and not report.is_empty(), "expanded game completes: " + str(errors))
	if not report.is_empty():
		_audit_report(report, state)
		print(
			"LEAGUE_EXPANDED wall_ms=",
			Time.get_ticks_msec() - started_ms,
			" physics_frames=",
			frames,
			" releases=",
			report.physical.releases.size(),
			" score=",
			report.physical.away_runs,
			"-",
			report.physical.home_runs
		)
		for index in range(2):
			var proof: Dictionary = report.physical.tactics.teams[index]
			print(
				"LEAGUE_EXPANDED team=",
				index,
				" initial=",
				proof.initial.size(),
				" consumed=",
				proof.consumed.size(),
				" remaining=",
				proof.remaining.size(),
				" receipts=",
				proof.consumed
			)
	check(before == [banks[0].to_data(), banks[1].to_data()], "runner never mutates paid journals")
	runner.queue_free()
	await get_tree().process_frame
	print("League expanded-bag live checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)


func _audit_report(report: Dictionary, state: MatchState) -> void:
	check(
		report.get("version") == 27 and PhysicalMatchReport.valid(report), "expanded report27 valid"
	)
	check(PhysicalLeagueReport.matches(report, state), "report matches immutable expanded request")
	check(
		not PhysicalLeagueReport.matches(report, MatchState.new()),
		"null-team match rejects cleanly"
	)
	var normalized: Variant = JSON.parse_string(JSON.stringify(report))
	check(
		PhysicalMatchReport.valid(normalized) and PhysicalLeagueReport.matches(normalized, state),
		"JSON-normalized report replays and matches"
	)
	check(not PhysicalMatchReport.valid(report.physical), "stripped wrapper cannot enter legacy")
	for index in range(2):
		var proof: Dictionary = report.physical.tactics.teams[index]
		check(proof.initial.size() == 3 + index, "real three/four-copy initial evidence")
		check(proof.consumed.size() >= 3, "AI actually consumes at least three carried copies")
		check(
			proof.consumed.size() + proof.remaining.size() == proof.initial.size(),
			"every expanded paid copy reconciles consumed or remaining"
		)
		check(
			not PhysicalBaseEvidence.valid(
				PhysicalBaseEvidence.enriched(proof, report.physical.tactics.base),
				report.physical.teams[index].roster,
				report.physical.performance,
				index
			),
			"legacy evidence still rejects expanded bag"
		)
	var bad: Dictionary = report.duplicate(true)
	bad.league_rules = LeagueRules.capture("standard")
	check(not PhysicalMatchReport.valid(bad), "wrong profile rejects actual game")
	bad = report.duplicate(true)
	bad.physical.tactics.teams[0].initial[0].paid += 1
	check(not PhysicalMatchReport.valid(bad), "actual receipt repricing rejected")
	bad = report.duplicate(true)
	bad.physical.tactics.teams[0].initial[1].id = bad.physical.tactics.teams[0].initial[0].id
	check(not PhysicalMatchReport.valid(bad), "actual duplicate receipt rejected")
	bad = report.duplicate(true)
	bad.physical.erase("league_bound")
	check(not PhysicalMatchReport.valid(bad), "nested context marker removal rejected")
	bad = report.duplicate(true)
	var changed: bool = false
	for choice: Dictionary in bad.physical.choices.events:
		if choice.role == "bat":
			choice.mode = "wide"
			changed = true
			break
	check(changed and PhysicalMatchReport.valid(bad), "forged sponsor choice remains shape-valid")
	check(
		not PhysicalLeagueReport.matches(bad, state),
		"forged choice cannot invent sponsor entitlement"
	)
	var wrong: MatchState = PhysicalMatchRequest.capture(state)
	wrong.home_team.league_ownership = wrong.away_team.league_ownership.duplicate(true)
	check(not PhysicalLeagueReport.matches(report, wrong), "wrong ownership request rejected")
