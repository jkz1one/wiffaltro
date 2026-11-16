extends "res://src/tests/league_physical_proof_test.gd"
## Two real detached physical games. Paid setup is synthetic; this is not save77/earned-season
## acceptance.

var human_recoveries: int = 0


func _ready() -> void:
	var season: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("doubleheader"), true
	)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "detached Doubleheader draft")
	var first: MatchState = MatchState.create(season._make_team(1, 0), season._make_team(0, 0))
	first.league_rules = LeagueRules.capture("doubleheader")
	first.home_team.track_bases = true
	var ai_bank: SeasonOwnership = _paid_bank(["C02", "A10"])
	var human_bank: SeasonOwnership = _paid_bank(["C02", "C02"])
	_bind(first.away_team, ai_bank, 0, {})
	_bind(first.home_team, human_bank, 0, {})
	var report: Dictionary = await _run(first, 443)
	if report.is_empty():
		get_tree().quit(1)
		return
	var cold_first: Dictionary = JSON.parse_string(JSON.stringify(report, "", true, true))
	check(
		(
			PhysicalDoubleheaderReport.valid(cold_first)
			and PhysicalDoubleheaderReport.matches(cold_first, first)
		),
		"completed first-leg physical C02 report cold-binds before return fixture"
	)
	var ai_debt: Dictionary = PhysicalWorkloadEvidence.net_debt(cold_first.workload[0], {})
	var human_debt: Dictionary = PhysicalWorkloadEvidence.net_debt(cold_first.workload[1], {})
	check(
		(
			ClubCareer.same(ai_debt, PhysicalWorkloadEvidence.net_debt(report.workload[0], {}))
			and ClubCareer.same(
				human_debt, PhysicalWorkloadEvidence.net_debt(report.workload[1], {})
			)
		),
		"actual first-leg release/recovery debt is identical after cold serialization"
	)
	check(
		human_debt.values().any(func(value: float) -> bool: return value > 0.0),
		"first human game establishes actual used workload"
	)
	check(human_recoveries > 0, "human actually activates paid C02 during physical game")
	for index in range(2):
		var bank: SeasonOwnership = ai_bank if index == 0 else human_bank
		var ids: Array = report.uses[index].map(
			func(action: Dictionary) -> String: return action.receipt
		)
		if not ids.is_empty():
			check(
				bank.commit(OwnershipFixtures.request(bank, "discard", {"receipts": ids})).ok,
				"physical consumed copies removed from synthetic paid journal"
			)
	var copied: MatchState = PhysicalMatchRequest.capture(first)
	check(copied != null, "first source remains fresh and unmutated")
	var second: MatchState = MatchState.create(copied.home_team, copied.away_team)
	second.league_rules = first.league_rules.duplicate(true)
	_bind(second.away_team, human_bank, 3, human_debt)
	_bind(second.home_team, ai_bank, 3, ai_debt)
	for team: TeamMatchState in [second.away_team, second.home_team]:
		for player: PlayerMatchState in team.roster:
			check(
				PhysicalRecoveryFlow.near(
					player.stamina_remaining,
					maxf(
						0.0,
						(
							player.stamina_max
							- float(team.league_pair.debt.get(String(player.definition.id), 0.0))
						)
					)
				),
				"return leg retains exact absolute workload at swapped venue"
			)
	var second_report: Dictionary = await _run(second, 443 + 3 * 104729)
	if not second_report.is_empty():
		check(
			second_report.pair[0].first == 0 and second_report.pair[1].first == 0,
			"second report binds exact first fixture"
		)
		var bad: Dictionary = second_report.duplicate(true)
		bad.pair[0] = {"game": 3, "first": -1, "debt": {}}
		check(not PhysicalDoubleheaderReport.valid(bad), "forged fresh second leg rejected")
	# Independent paid boundary fixture; first leg may legitimately consume both C02 copies.
	_exhausted_boundary(first, _paid_bank(["C02"]))
	print(
		(
			"Doubleheader detached live checks: %d, failures: %d, human_recoveries: %d"
			% [checks, failures, human_recoveries]
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)


func _paid_bank(items: Array) -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	check(
		bank.enable_league_rules(LeagueRules.capture("doubleheader")),
		"actual-catalog paid journal profile"
	)
	for game in range(8):
		check(
			bank.commit(OwnershipFixtures.request(bank, "reward", {"game": game, "win": true})).ok,
			"synthetic preparation credit"
		)
	var offers: Dictionary = {"strikecraft": "B03"}
	for index in range(items.size()):
		offers["supply%d" % index] = items[index]
	check(
		bank.commit(OwnershipFixtures.request(bank, "stock", {"offers": offers})).ok,
		"controlled stock"
	)
	check(bank.commit(OwnershipFixtures.buy(bank, "strikecraft")).ok, "paid refund sponsor")
	for index in range(items.size()):
		check(bank.commit(OwnershipFixtures.buy(bank, "supply%d" % index)).ok, "paid tactical copy")
	return bank


func _bind(team: TeamMatchState, bank: SeasonOwnership, game: int, debt: Dictionary) -> void:
	team.league_rules = LeagueRules.capture("doubleheader")
	team.league_ownership = bank.to_data()
	team.league_pair = {
		"game": game, "first": SeasonDoubleheaderRules.first(game), "debt": debt.duplicate(true)
	}
	team.tactics.held = SeasonTacticalCatalog.held(bank.view())
	MatchFieldSupply.sync_capacity(team, bank.view())
	for player: PlayerMatchState in team.roster:
		player.definition.season_sponsors["B03"] = true
		player.stamina_remaining = maxf(
			0.0, player.stamina_max - float(debt.get(String(player.definition.id), 0.0))
		)
	if team.ai_base:
		team.ai_tactical_initial.assign(team.tactics.held.duplicate(true))
		team.ai_budget = {
			"game": game,
			"cash": bank.cash(),
			"active": false,
			"before": team.tactics.held.duplicate(true),
			"outcome": "inactive"
		}


func _run(source: MatchState, seed_value: int) -> Dictionary:
	var before: Array = [
		source.away_team.league_ownership.duplicate(true),
		source.home_team.league_ownership.duplicate(true)
	]
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	var started_ms: int = Time.get_ticks_msec()
	var frames: int = 0
	var played: MatchState
	var started: bool = runner.start(source, seed_value)
	check(started, "actual Doubleheader physical request starts")
	if started:
		played = runner._lab._match_state
		for frame in range(300000):
			await get_tree().physics_frame
			frames += 1
			if not report.is_empty() or not errors.is_empty():
				break
			var human: TeamMatchState = (
				played.home_team if not played.home_team.ai_base else played.away_team
			)
			if (
				played.phase == MatchState.Phase.PRE_PITCH
				and played.between_batters
				and played.defensive_team() == human
			):
				var pitcher: PlayerMatchState = played.pitcher()
				if pitcher.stamina_max - pitcher.stamina_remaining >= pitcher.stamina_max * 0.1:
					for copy: Dictionary in human.tactics.held.duplicate(true):
						if copy.item == "C02" and human.tactics.activate(played, human, copy.id):
							human_recoveries += 1
	check(
		errors.is_empty() and not report.is_empty(),
		"physical workload game completes: " + str(errors)
	)
	if not report.is_empty():
		check(
			report.version == 28 and PhysicalDoubleheaderReport.valid(report),
			"report28 chronology validates"
		)
		check(
			PhysicalDoubleheaderReport.matches(report, source),
			"report28 binds exact pregame debt and capacity"
		)
		check(
			PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report, "", true, true))),
			"cold JSON workload replay"
		)
		check(not PhysicalMatchReport.valid(report.physical), "stripped workload wrapper rejected")
		var old: Dictionary = report.duplicate(true)
		old.version = 27
		old.resolver = PhysicalLeagueReport.RESOLVER
		for key: String in ["pair", "workload", "uses"]:
			old.erase(key)
		old.physical.erase("doubleheader_bound")
		check(not PhysicalLeagueReport.valid(old), "old report27 cannot relabel Doubleheader")
		for index in range(2):
			var expected: TeamMatchState = source.away_team if index == 0 else source.home_team
			var actual: TeamMatchState = played.away_team if index == 0 else played.home_team
			var envelope: Dictionary = PhysicalWorkloadEvidence.capture_human(played, actual)
			check(
				PhysicalWorkloadEvidence.human_matches(
					envelope,
					expected,
					report.physical.performance,
					report.physical.teams[index].pitching,
					report.uses[index],
					99999
				),
				"shared human/AI workload envelope binds"
			)
			var bad: Dictionary = report.duplicate(true)
			var id: String = report.physical.teams[index].roster[0]
			bad.workload[index].remaining[id] += 1.0
			check(not PhysicalDoubleheaderReport.valid(bad), "single-field final healing rejected")
			print(
				"DOUBLEHEADER_LIVE game=",
				expected.league_pair.game,
				" side=",
				index,
				" net=",
				PhysicalWorkloadEvidence.net_cost(report.workload[index]),
				" events=",
				report.workload[index].events.size(),
				" uses=",
				report.uses[index]
			)
		print(
			"DOUBLEHEADER_LIVE wall_ms=",
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
	check(
		before == [source.away_team.league_ownership, source.home_team.league_ownership],
		"runner never mutates original paid journals"
	)
	runner.queue_free()
	await get_tree().process_frame
	return report


func _exhausted_boundary(source: MatchState, bank: SeasonOwnership) -> void:
	var exhausted: MatchState = PhysicalMatchRequest.capture(source)
	var human: TeamMatchState = exhausted.home_team
	var id: String = String(human.current_pitcher().definition.id)
	var debt: Dictionary = {id: human.current_pitcher().stamina_max + 20.0}
	_bind(human, bank, 3, debt)
	_bind(exhausted.away_team, _paid_bank([]), 3, {})
	check(
		human.current_pitcher().stamina_remaining == 0.0,
		"over-capacity carried debt starts exhausted"
	)
	check(
		PhysicalMatchRequest.capture(exhausted) != null,
		"bounded exhausted-start request can be reconstructed"
	)
	var copies: Array = human.tactics.held.filter(
		func(copy: Dictionary) -> bool: return copy.item == "C02"
	)
	check(not copies.is_empty(), "independent paid recovery exists for boundary fixture")
	if not copies.is_empty():
		check(
			human.tactics.activate(exhausted, human, copies[0].id),
			"exhausted pitcher can activate owned recovery before first release"
		)
		check(
			PhysicalRecoveryFlow.near(
				human.current_pitcher().stamina_remaining,
				human.current_pitcher().stamina_max * 0.10
			),
			"actual exhausted recovery capped at10 percent capacity"
		)
		check(
			(
				human.recovery.workload_events.size() == 1
				and human.recovery.workload_events[0].before == 0.0
			),
			"zero-start recovery recorded before any current-game pitch"
		)
