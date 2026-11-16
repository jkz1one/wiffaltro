extends Node
## Ownership-backed adapter contract only; full physical games are separate qualification.

var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	for league: String in ["standard", "dugout"]:
		var rules: Dictionary = LeagueRules.capture(league)
		var capacity: int = 3 if league == "dugout" else 2
		for count in range(1, capacity + 1):
			var bank: SeasonOwnership = fixture(league, count)
			var row: Dictionary = budget_row(bank)
			var before: Dictionary = bank.to_data()
			check(
				PhysicalBudgetEvidence.league_shape(row, rules, before),
				"bound budget count%d %s" % [count, league]
			)
			check(
				row.budget.outcome == ("full" if count == capacity else "granted"),
				"capacity derived outcome"
			)
			if league == "dugout" and count >= 2:
				check(not PhysicalBudgetEvidence.shape(row, 12), "legacy full-at-two unchanged")
			var forged: Dictionary = row.duplicate(true)
			forged.budget.cash += 1
			check(not PhysicalBudgetEvidence.league_shape(forged, rules, before), "cash binds bank")
			forged = row.duplicate(true)
			forged.budget.active = false
			check(
				not PhysicalBudgetEvidence.league_shape(forged, rules, before), "sponsor binds bank"
			)
			forged = row.duplicate(true)
			forged.initial[0].paid += 1
			check(
				not PhysicalBudgetEvidence.league_shape(forged, rules, before),
				"paid tamper refused"
			)
			forged = row.duplicate(true)
			forged.initial.append(forged.initial[0].duplicate(true))
			check(
				not PhysicalBudgetEvidence.league_shape(forged, rules, before),
				"duplicate receipt refused"
			)
			check(
				not PhysicalBudgetEvidence.league_shape(
					row, LeagueRules.capture("standard" if league == "dugout" else "dugout"), before
				),
				"wrong league refused"
			)
			var unknown: Dictionary = rules.duplicate(true)
			unknown.version = 2
			check(PhysicalLeagueReport.wallet(unknown, before).is_empty(), "unknown rules rejected")
			unknown = rules.duplicate(true)
			unknown.held = 99
			check(PhysicalLeagueReport.wallet(unknown, before).is_empty(), "raw capacity rejected")
			check(bank.to_data() == before, "validation is read-only")
	var large: SeasonOwnership = fixture("dugout", 4, ["E08", "G02"])
	var wallet: Dictionary = PhysicalLeagueReport.wallet(
		LeagueRules.capture("dugout"), large.to_data()
	)
	check(wallet.capacity == {"held": 4, "sponsors": 3}, "four requires actual Small Batch")
	check(
		PhysicalBudgetEvidence.league_shape(
			budget_row(large), LeagueRules.capture("dugout"), large.to_data()
		),
		"four-copy full outcome"
	)
	var combined: SeasonOwnership = fixture("dugout", 3, ["E08", "G02", "F09"])
	check(combined.view().capacity == {"held": 3, "sponsors": 3}, "Double Major arithmetic")
	var bag: Dictionary = {
		"initial": large.view().held, "consumed": [], "remaining": large.view().held
	}
	check(not PhysicalRecoveryEvidence.bag(bag), "legacy recovery rejects expanded bag")
	var three: SeasonOwnership = fixture("dugout", 3)
	bag = {"initial": three.view().held, "consumed": [], "remaining": three.view().held}
	check(not PhysicalRecoveryEvidence.bag(bag), "legacy recovery rejects three copies")
	var mixed: SeasonOwnership = fixture("dugout", 2)
	var card: String = String(DevelopmentShopCatalog.CARDS.keys()[0])
	check(
		mixed.commit(OwnershipFixtures.request(mixed, "reward", {"game": 9, "win": true})).ok,
		"mixed fixture cash"
	)
	check(
		mixed.commit(OwnershipFixtures.request(mixed, "stock", {"offers": {"card": card}})).ok,
		"mixed fixture stock"
	)
	check(mixed.commit(OwnershipFixtures.buy(mixed, "card")).ok, "development card occupies bag")
	check(
		mixed.commit(OwnershipFixtures.request(mixed, "charge", {"amount": mixed.cash() - 4})).ok,
		"mixed fixture charge"
	)
	var mixed_row: Dictionary = budget_row(mixed)
	check(
		PhysicalBudgetEvidence.league_shape(
			mixed_row, LeagueRules.capture("dugout"), mixed.to_data()
		),
		"development occupancy yields full"
	)
	mixed_row.budget.outcome = "granted"
	mixed_row.initial.append({"id": "budget:8", "item": "C03", "paid": 0, "kind": "held"})
	check(
		not PhysicalBudgetEvidence.league_shape(
			mixed_row, LeagueRules.capture("dugout"), mixed.to_data()
		),
		"cannot grant fourth shared item"
	)
	_contexts(three)
	check(not PhysicalLeagueReport.valid({}), "malformed wrapper rejected")
	print("League physical proof checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func fixture(league: String, count: int, sponsors: Array = ["E08"]) -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	check(bank.enable_league_rules(LeagueRules.capture(league)), "fixture enable")
	for game in range(8):
		check(
			bank.commit(OwnershipFixtures.request(bank, "reward", {"game": game, "win": true})).ok,
			"fixture cash"
		)
	var offers: Dictionary = {}
	for sponsor: String in sponsors:
		offers[sponsor] = sponsor
	for index in range(count):
		offers["held%d" % index] = "A10"
	check(
		bank.commit(OwnershipFixtures.request(bank, "stock", {"offers": offers})).ok,
		"fixture stock"
	)
	for sponsor: String in sponsors:
		check(bank.commit(OwnershipFixtures.buy(bank, sponsor)).ok, "fixture sponsor")
	for index in range(count):
		check(bank.commit(OwnershipFixtures.buy(bank, "held%d" % index)).ok, "fixture held")
	check(
		bank.commit(OwnershipFixtures.request(bank, "charge", {"amount": bank.cash() - 4})).ok,
		"fixture exact cash"
	)
	return bank


func budget_row(bank: SeasonOwnership) -> Dictionary:
	var wallet: Dictionary = bank.view()
	var initial: Array = SeasonTacticalCatalog.held(wallet)
	var outcome: String = "full" if wallet.held.size() >= wallet.capacity.held else "granted"
	if outcome == "granted":
		initial.append({"id": "budget:8", "item": "C03", "paid": 0, "kind": "held"})
	return {
		"version": 4,
		"budget":
		{
			"game": 8,
			"cash": 4,
			"active": true,
			"before": SeasonTacticalCatalog.held(wallet),
			"outcome": outcome
		},
		"initial": initial
	}


func _contexts(bank: SeasonOwnership) -> void:
	var state: MatchState = MatchState.new()
	state.away_team = TeamMatchState.new()
	state.home_team = TeamMatchState.new()
	check(PhysicalLeagueReport.capture_context_valid(state), "legacy capture context unchanged")
	state.league_rules = LeagueRules.capture("dugout")
	for team: TeamMatchState in [state.away_team, state.home_team]:
		team.league_rules = state.league_rules.duplicate(true)
		team.league_ownership = bank.to_data()
		team.tactics.held.assign(SeasonTacticalCatalog.held(bank.view()))
		MatchFieldSupply.sync_capacity(team, bank.view())
	check(PhysicalLeagueReport.capture_context_valid(state), "bound capture context")
	check(PhysicalLeagueReport.team_valid(state.home_team), "human capacity bound")
	state.home_team.field_supply.capacity += 1
	check(not PhysicalLeagueReport.team_valid(state.home_team), "forged human capacity rejected")
	MatchFieldSupply.sync_capacity(state.home_team, bank.view())
	state.home_team.field_supply.reserved += 1
	check(
		not PhysicalLeagueReport.team_valid(state.home_team), "forged human reserved count rejected"
	)
	state.league_rules = {}
	check(not PhysicalLeagueReport.capture_context_valid(state), "stripped capture header rejected")
	state.league_rules = LeagueRules.capture("dugout")
	state.home_team.league_rules = LeagueRules.capture("standard")
	check(not PhysicalLeagueReport.capture_context_valid(state), "divergent team capture rejected")
