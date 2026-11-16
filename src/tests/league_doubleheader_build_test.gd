extends Node
## Synthetic completed workloads exercise journal authority; not physical-game claims.

var checks: int = 0
var failures: int = 0
var roster: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func cold(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _ready() -> void:
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	for market in [0, 12]:
		_authority(market)
	_full_season()
	_recovery()
	_sale_context()
	_legacy_recovery()
	print("Doubleheader Build workload checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _build(seed_value: int = 551, market: int = 0) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(seed_value, roster)
	build._market = market
	check(build.enable_league_rules(LeagueRules.capture("doubleheader")), "closed workload build")
	return build


func _reward(build: SeasonBuild, game: int, pitcher: int = -1, count: int = 0) -> Dictionary:
	var pair: Dictionary = SeasonDoubleheaderBuild.pair_for(build, game)
	var performance: Dictionary = {}
	var initial: Dictionary = {}
	var remaining: Dictionary = {}
	for id: String in roster:
		performance[id] = MatchPerformance.empty_line()
		var player: PlayerMatchState = PlayerMatchState.create(build.definition(id))
		var start: float = maxf(0.0, player.stamina_max - float(pair.debt.get(id, 0.0)))
		initial[id] = {"capacity": player.stamina_max, "initial": start}
		remaining[id] = start
	var command: Dictionary = SeasonOpponentPolicy.command(
		build,
		"reward",
		{
			"game": game,
			"win": true,
			"performance": performance,
			"pitching": {"releases": [], "strikeouts": [], "calls": []},
			"tactics": [],
			"doubleheader_workload":
			{
				"version": 1,
				"pair": pair,
				"proof": {"version": 1, "initial": initial, "events": [], "remaining": remaining}
			}
		}
	)
	if pitcher >= 0:
		var id: String = roster[pitcher]
		var player: PlayerMatchState = PlayerMatchState.create(build.definition(id))
		var pitch: PitchDefinition = player.definition.starting_pitches[0]
		performance[id].pa = 1
		performance[id].outs = 1
		performance[id].pitches = count
		for index in range(count):
			player.stamina_remaining = remaining[id]
			var gear: float = SeasonGearCatalog.workload(player, 1.0)
			var sponsor: float = SeasonSponsorEffects.workload(player.definition, pitch)
			var paid: float = minf(
				remaining[id], MatchLabSupport.stamina_cost(pitch, 1.0) * gear * sponsor
			)
			var event: Dictionary = {
				"kind": "release",
				"pa": 1,
				"half": 0,
				"player": id,
				"recipe": String(pitch.id),
				"paid": paid,
				"before": remaining[id],
				"after": remaining[id] - paid,
				"effort": 1.0,
				"overdrive": 0.0,
				"base_cost": pitch.stamina_cost,
				"gear_scale": gear,
				"sponsor_scale": sponsor
			}
			command.doubleheader_workload.proof.events.append(event)
			command.pitching.releases.append(
				{"pa": 1, "half": 0, "player": id, "recipe": String(pitch.id)}
			)
			remaining[id] -= paid
	return command


func _authority(market: int) -> void:
	var build: SeasonBuild = _build(551, market)
	var command: Dictionary = _reward(build, 0, 0, 4)
	var before: Dictionary = build.to_data()
	var missing: Dictionary = command.duplicate(true)
	missing.erase("doubleheader_workload")
	check(
		not build.commit(missing).ok and build.to_data() == before,
		"missing workload rejects atomically"
	)
	for field: String in ["performance", "pitching", "tactics"]:
		missing = command.duplicate(true)
		missing.erase(field)
		check(
			not build.commit(missing).ok and build.to_data() == before,
			"missing exact evidence " + field
		)
	var wrong: Dictionary = command.duplicate(true)
	wrong.doubleheader_workload.pair.game = 1
	check(
		not build.commit(wrong).ok and build.to_data() == before, "wrong fixture envelope rejects"
	)
	wrong = command.duplicate(true)
	wrong.doubleheader_workload.proof.initial[roster[0]].capacity += 1.0
	check(not build.commit(wrong).ok and build.to_data() == before, "caller capacity rejects")
	wrong = command.duplicate(true)
	wrong.doubleheader_workload.proof.events[0].paid -= 1.0
	check(not build.commit(wrong).ok and build.to_data() == before, "caller release price rejects")
	check(build.commit(command).ok and build.cash() == 18, "validated first workload pays")
	check(
		build._sure_start == null and not build._sure_earned,
		"workload does not unlock or earn Sure Shot"
	)
	before = build.to_data()
	var retry: Dictionary = build.commit(cold(command))
	check(
		retry.ok and retry.replayed and build.to_data() == before,
		"full-precision cold reward retry"
	)
	wrong = cold(command)
	wrong.doubleheader_workload.proof.events[0].before += 0.000000001
	check(
		not build.commit(wrong).ok and build.to_data() == before,
		"same-ID sub-stringify-precision float change rejects"
	)
	var restored: SeasonBuild = SeasonBuild.from_data(cold(before), 551, roster)
	check(
		restored != null and restored.cash() == 18 and ClubCareer.same(restored.to_data(), before),
		"cold first workload replay"
	)
	var second: Dictionary = _reward(build, 3)
	check(
		second.doubleheader_workload.pair.debt[roster[0]] > 0.0,
		"partner journal derives absolute debt"
	)
	wrong = second.duplicate(true)
	wrong.doubleheader_workload.pair.debt.clear()
	check(not build.commit(wrong).ok and build.to_data() == before, "second leg cannot erase carry")
	check(
		build.commit(second).ok and build.cash() == 42, "validated second completed win sweeps once"
	)
	check(
		SeasonDoubleheaderBuild.context(build, 3).is_empty(),
		"already paid Build is not a pre-reward context"
	)
	var playoff: Dictionary = _reward(build, 30)
	check(
		playoff.doubleheader_workload.pair == {"game": 30, "first": -1, "debt": {}},
		"playoffs reset pair debt"
	)
	check(build.commit(playoff).ok and build.cash() == 60, "playoff ordinary reward")
	restored = SeasonBuild.from_data(cold(build.to_data()), 551, roster)
	check(restored != null and restored.cash() == 60, "cold multi-game workload replay")


func _recovery() -> void:
	var build: SeasonBuild
	var offer: String = ""
	for seed_value in range(128):
		var candidate: SeasonBuild = _build(seed_value)
		if not candidate.commit(_reward(candidate, 0, 0, 8)).ok:
			continue
		if not candidate.commit(SeasonOpponentPolicy.command(candidate, "open")).ok:
			continue
		for key: String in candidate._visit.offers:
			if candidate._visit.offers[key] == "C02":
				build = candidate
				offer = key
				break
		if build != null:
			break
	check(build != null, "found actual paid Recovery stock")
	if build == null:
		return
	check(
		build.commit(SeasonOpponentPolicy.command(build, "tactical_buy", {"offer": offer})).ok,
		"buy exact Recovery copy"
	)
	var receipt: String = build._bank.view().held[0].id
	var command: Dictionary = _reward(build, 3, 1, 1)
	var proof: Dictionary = command.doubleheader_workload.proof
	var id: String = roster[0]
	var before_stamina: float = proof.initial[id].initial
	var after_stamina: float = minf(
		proof.initial[id].capacity, before_stamina + proof.initial[id].capacity * 0.10
	)
	proof.events.push_front(
		{
			"kind": "recovery",
			"pa": 1,
			"half": 0,
			"player": id,
			"receipt": receipt,
			"before": before_stamina,
			"after": after_stamina
		}
	)
	proof.remaining[id] = after_stamina
	command.tactics = [{"receipt": receipt, "player": id, "pa": 1, "swing": ""}]
	var before: Dictionary = build.to_data()
	var wrong: Dictionary = command.duplicate(true)
	wrong.doubleheader_workload.proof.events[0].receipt = "other-copy"
	check(
		not build.commit(wrong).ok and build.to_data() == before,
		"unowned recovery receipt rejects atomically"
	)
	wrong = command.duplicate(true)
	wrong.tactics[0].player = roster[2]
	check(
		not build.commit(wrong).ok and build.to_data() == before,
		"recovery player substitution rejects"
	)
	check(command.performance[id].pitches == 0, "carried recovery subject has no current release")
	var completed: Dictionary = build.commit(command)
	check(
		completed.ok and build._bank.view().held.is_empty(),
		"exact carried zero-release Recovery consumed once"
	)
	if completed.ok:
		var restored: SeasonBuild = SeasonBuild.from_data(
			cold(build.to_data()), build._seed, roster
		)
		if restored == null or restored.cash() != build.cash():
			print(
				"Recovery replay diagnostic seed=",
				build._seed,
				" original cash=",
				build.cash(),
				" restored cash=",
				restored.cash() if restored != null else -1
			)
			var probe: SeasonBuild = _build(build._seed)
			for event: Dictionary in cold(build.to_data()).events:
				var applied: Dictionary = probe.commit(event)
				print("Recovery replay event ", event.rev, " ", event.op, ": ", applied)
				if not applied.ok:
					_diagnose_workload(probe, event)
					break
		check(
			restored != null and restored.cash() == build.cash(),
			"paid zero-release Recovery cold replay"
		)


func _sale_context() -> void:
	# Controlled paid-wallet fixture, deliberately not a fabricated Build save.
	var build: SeasonBuild = _build()
	for game in [0, 1, 2]:
		check(
			(
				build
				. _bank
				. commit(
					OwnershipFixtures.request(build._bank, "reward", {"game": game, "win": true})
				)
				. ok
			),
			"context fixture credit"
		)
	check(
		(
			build
			. _bank
			. commit(
				OwnershipFixtures.request(
					build._bank, "stock", {"offers": {"sponsor": "B03", "college": "B02"}}
				)
			)
			. ok
		),
		"context paid stock"
	)
	check(build._bank.commit(OwnershipFixtures.buy(build._bank, "sponsor")).ok, "context paid B03")
	check(build._bank.commit(OwnershipFixtures.buy(build._bank, "college")).ok, "context paid B02")
	var starting: Dictionary = build._bank.to_data()
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 6})).ok,
		"current attempt marker"
	)
	var receipt: String = build._bank.view().sponsors[0].id
	var sale: Dictionary = SeasonOpponentPolicy.command(
		build,
		"match_sell",
		{
			"game": 6,
			"receipt": receipt,
			"first_pitch": null,
			"field_state": {"pa": 4, "boundary": 3, "grant": {}, "uses": [], "fielding": []}
		}
	)
	check(build.commit(sale).ok, "accepted current attempt B03 sale")
	var context: Dictionary = SeasonDoubleheaderBuild.context(build, 6)
	check(not context.is_empty(), "bounded paid sale context")
	if not context.is_empty():
		check(
			ClubCareer.same(context.ownership, starting) and context.refund_through == 3,
			"exact initial paid wallet and inclusive B03 cutoff"
		)
		check(
			context.cost_context.size() == 1 and context.cost_context[0].after == 3,
			"sale-bound cost transition"
		)
		for id: String in roster:
			check(
				not context.cost_context[0].definitions[id].season_sponsors.has("B03"),
				"retired sponsor removed from transition"
			)
	check(
		not SeasonDoubleheaderBuild.validate(build, _reward(build, 6)).is_empty(),
		"future sale PA beyond completed appearances rejects"
	)
	var backdated: SeasonBuild = build._fork()
	var college: String = backdated._bank.view().sponsors[0].id
	var older_sale: Dictionary = SeasonOpponentPolicy.command(
		backdated,
		"match_sell",
		{
			"game": 6,
			"receipt": college,
			"first_pitch": null,
			"field_state": {"pa": 3, "boundary": 3, "grant": {}, "uses": [], "fielding": []}
		}
	)
	check(
		backdated.commit(older_sale).ok,
		"legacy sale reader fixture permits equal-cutoff earlier PA"
	)
	check(
		SeasonDoubleheaderBuild.context(backdated, 6).is_empty(),
		"Doubleheader context rejects decreasing sale PA"
	)
	var wrong_bank: SeasonBuild = build._fork()
	wrong_bank._bank._events[-1].id = "foreign-sale"
	check(
		SeasonDoubleheaderBuild.context(wrong_bank, 6).is_empty(),
		"sale wallet event must match exact Build operation"
	)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 6})).ok,
		"restart replaces attempt marker"
	)
	context = SeasonDoubleheaderBuild.context(build, 6)
	check(
		not context.is_empty() and context.refund_through == -1 and context.cost_context.is_empty(),
		"abandoned earlier sale not current attempt cutoff"
	)
	var tampered: SeasonBuild = build._fork()
	tampered._events.append({"id": "bad", "rev": tampered.revision(), "op": "open"})
	check(
		SeasonDoubleheaderBuild.context(tampered, 6).is_empty(),
		"post-attempt development operation rejects"
	)


func _legacy_recovery() -> void:
	var build: SeasonBuild = SeasonBuild.new(551, roster)
	check(
		(
			build
			. _bank
			. commit(OwnershipFixtures.request(build._bank, "reward", {"game": 0, "win": true}))
			. ok
		),
		"legacy fixture credit"
	)
	check(
		(
			build
			. _bank
			. commit(
				OwnershipFixtures.request(build._bank, "stock", {"offers": {"recovery": "C02"}})
			)
			. ok
		),
		"legacy paid stock"
	)
	check(
		build._bank.commit(OwnershipFixtures.buy(build._bank, "recovery")).ok,
		"legacy paid Recovery"
	)
	var receipt: String = build._bank.view().held[0].id
	var performance: Dictionary = {}
	for id: String in roster:
		performance[id] = MatchPerformance.empty_line()
	var action: Dictionary = {"receipt": receipt, "player": roster[0], "pa": 1, "swing": ""}
	var before: Dictionary = build.to_data()
	var claimed: Dictionary = {receipt: {"player": roster[0], "pa": 1}}
	check(
		(
			not SeasonTacticalPurchase.settle(build, [action], performance, 1, claimed).is_empty()
			and build.to_data() == before
		),
		"legacy zero-release C02 remains strict even with supplied local map"
	)


func _full_season() -> void:
	for market in [0, 12]:
		var build: SeasonBuild = _build(551, market)
		var games: Array[Dictionary] = []
		var club: int = 0 if market == 0 else 1
		for fixture: Dictionary in SeasonDoubleheaderRules.schedule():
			if club in [fixture.home, fixture.away]:
				games.append(fixture)
		games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.round < b.round)
		for fixture: Dictionary in games:
			var command: Dictionary = _reward(build, fixture.id)
			check(build.commit(command).ok, "full-season workload-backed completed reward")
			var before: Dictionary = build.to_data()
			var replay: Dictionary = build.commit(cold(command))
			check(
				replay.ok and replay.replayed and ClubCareer.same(build.to_data(), before),
				"full-season cold JSON retry"
			)
		check(
			build.cash() == 210 and build._visit.number == 10,
			"both builds get five sweeps and ten shops"
		)
		var restored: SeasonBuild = SeasonBuild.from_data(cold(build.to_data()), 551, roster)
		check(
			(
				restored != null
				and restored.cash() == 210
				and ClubCareer.same(restored.to_data(), build.to_data())
			),
			"cold ten-game workload-backed journal"
		)


func _diagnose_workload(build: SeasonBuild, command: Dictionary) -> void:
	var start: Dictionary = SeasonDoubleheaderBuild.context(build, int(command.game))
	var pair: Dictionary = SeasonDoubleheaderBuild.pair_for(build, int(command.game))
	var players: Array[PlayerDefinition] = []
	for id: String in build.roster():
		players.append(start.definitions[id])
	var team: TeamMatchState = TeamMatchState.create("diagnostic", players)
	team.league_rules = build._league_rules.duplicate(true)
	team.league_ownership = start.ownership.duplicate(true)
	team.league_pair = pair
	for player: PlayerMatchState in team.roster:
		player.stamina_remaining = maxf(
			0.0, player.stamina_max - float(pair.debt.get(String(player.definition.id), 0.0))
		)
	var wallet: Dictionary = PhysicalLeagueReport.wallet(team.league_rules, team.league_ownership)
	var envelope: Dictionary = command.doubleheader_workload
	print(
		"Recovery split wallet=",
		not wallet.is_empty(),
		" held=",
		wallet.get("held"),
		" cutoff=",
		start.refund_through,
		" pair_equal=",
		ClubCareer.same(envelope.pair, pair)
	)
	print("Recovery expected pair=", JSON.stringify(pair, "", true, true))
	print(
		"Recovery split generic=",
		PhysicalWorkloadEvidence.valid(
			envelope.proof,
			build.roster(),
			command.performance,
			command.pitching,
			command.tactics,
			wallet,
			pair,
			start.refund_through
		),
		" team=",
		PhysicalWorkloadEvidence.valid_for_team(
			envelope.proof,
			team,
			command.performance,
			command.pitching,
			command.tactics,
			start.refund_through,
			start.cost_context
		)
	)
	print("Recovery failed command=", JSON.stringify(command, "", true, true))
