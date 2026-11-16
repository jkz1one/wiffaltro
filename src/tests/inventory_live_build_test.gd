extends "res://src/tests/inventory_prefix_test.gd"


## Controlled credited funding/earned eligibility and resolver records, not a full season.
func _ready() -> void:
	var ids: Array[String] = []
	ids.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	var probe: SeasonBuild = SeasonBuild.new(0, ids)
	probe.enable_league_rules(LeagueRules.capture("dugout"))
	probe._field_start = true
	probe._jump_start = false
	probe._visit.number = 2
	var seed_value: int = -1
	for value in range(10000):
		probe._seed = value
		if probe._offers(0).values().has("B01"):
			seed_value = value
			break
	check(seed_value >= 0, "real seeded Field offer exists")
	var build: SeasonBuild = SeasonBuild.new(seed_value, ids)
	build.enable_league_rules(LeagueRules.capture("dugout"))
	build._field_start = true
	build._jump_start = false
	check(
		(
			build
			. commit({"id": "inventory-rules-v1", "rev": 0, "op": SeasonInventoryResale.ENABLE_OP})
			. ok
		),
		"fresh explicit rules"
	)
	for game in range(2):
		check(
			(
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": game, "win": true}))
				. ok
			),
			"controlled funding"
		)
	check(build.commit(SeasonOpponentPolicy.command(build, "open")).ok, "seeded shop opens")
	var offer: String = ""
	for key: String in build._visit.offers:
		if build._visit.offers[key] == "B01":
			offer = key
	check(not offer.is_empty(), "paid Field offer reproduced")
	check(
		(
			build
			. commit(
				SeasonOpponentPolicy.command(build, "sponsor_buy", {"offer": offer, "replace": ""})
			)
			. ok
		),
		"actual Field purchase"
	)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 2})).ok,
		"real journal attempt"
	)
	var own: TeamMatchState = _build_team(build)
	var other: TeamMatchState = _team(SeasonPlayerCatalog.ids().slice(4, 8), build._bank)
	var state: MatchState = MatchState.create(other, own)
	state.league_rules = build._league_rules.duplicate(true)
	own.field_supply.receipt = SeasonFieldGrant.receipt(2)
	for index in range(3):
		_out(state)
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		state, own, SeasonInventoryRules.anchor(build, 2)
	)
	check(not proof.is_empty(), "earned completed prefix captured")
	var cmd: Dictionary = SeasonOpponentPolicy.command(
		build,
		"match_supply_sell",
		{
			"game": 2,
			"receipt": SeasonFieldGrant.receipt(2),
			"first_pitch": SeasonReclamation.receipts(build._match_inventory),
			"field_state": proof.get("field_state", {}),
			"inventory_prefix": proof
		}
	)
	var before: Dictionary = build.to_data()
	var cash: int = build.cash()
	check(
		build.candidate(cmd) != null and ClubCareer.same(before, build.to_data()),
		"cancel preview leaves owner unchanged"
	)
	var outcome: Dictionary = build.commit(cmd)
	check(outcome.ok, "earned Field sale through Build: " + str(outcome.get("error")))
	check(
		build.cash() == cash + 1 and SeasonInventoryResale.field_retired(build._bank, 2),
		"half normal value paid once and durable retirement"
	)
	var saved: Dictionary = build.to_data()
	var cold: SeasonBuild = SeasonBuild.from_data(
		JSON.parse_string(JSON.stringify(saved, "", true, true)), seed_value, ids
	)
	check(cold != null, "cold Build replays earned proof and sale")
	if cold != null:
		check(ClubCareer.same(saved, cold.to_data()), "cold full journal exact")
		check(
			cold.commit(cmd).get("replayed", false) and cold.cash() == cash + 1,
			"cold same-ID retry pays once"
		)
	check(
		not (
			build
			. commit(
				SeasonOpponentPolicy.command(
					build,
					"match_supply_sell",
					{
						"game": 2,
						"receipt": SeasonFieldGrant.receipt(2),
						"first_pitch": cmd.first_pitch,
						"field_state": proof.field_state,
						"inventory_prefix": proof
					}
				)
			)
			. ok
		),
		"fresh ID cannot sell retired copy again"
	)
	var completed: SeasonBuild = build._fork()
	state.continue_after_dead_ball()
	_out(state)
	var settlement: Dictionary = SeasonOpponentPolicy.command(
		completed,
		"reward",
		{
			"game": 2,
			"win": true,
			"performance": state.performance.snapshot(state),
			"fielding": proof.field_state.fielding.duplicate(true),
			"field_supply": proof.field_state.grant.duplicate(true),
			"tactics": []
		}
	)
	var paid: Dictionary = completed.commit(settlement)
	check(paid.ok, "controlled completion after live sale: " + str(paid.get("error")))
	check(
		not completed._bank.view().held.any(
			func(row: Dictionary) -> bool: return row.id == SeasonFieldGrant.receipt(2)
		),
		"completion cannot regrant sold generated copy"
	)
	var settled_cold: SeasonBuild = SeasonBuild.from_data(
		JSON.parse_string(JSON.stringify(completed.to_data(), "", true, true)), seed_value, ids
	)
	check(
		settled_cold != null and ClubCareer.same(settled_cold.to_data(), completed.to_data()),
		"sale and controlled completion cold replay"
	)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 2})).ok,
		"restart creates new attempt"
	)
	check(build._match_inventory.field_retired_before, "restart captures durable retirement")
	check(
		not (
			build
			. commit(
				SeasonOpponentPolicy.command(
					build,
					"match_supply_sell",
					{
						"game": 2,
						"receipt": SeasonFieldGrant.receipt(2),
						"first_pitch": cmd.first_pitch,
						"field_state": proof.field_state,
						"inventory_prefix": proof
					}
				)
			)
			. ok
		),
		"old proof cannot pay on restarted attempt"
	)
	var restarted: SeasonBuild = SeasonBuild.from_data(
		JSON.parse_string(JSON.stringify(build.to_data(), "", true, true)), seed_value, ids
	)
	check(
		restarted != null and restarted._match_inventory.field_retired_before,
		"restart tombstone cold replay"
	)
	print("Inventory live Build checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _build_team(build: SeasonBuild) -> TeamMatchState:
	var definitions: Array[PlayerDefinition] = []
	for id: String in build.roster():
		definitions.append(build.definition(id))
	var team: TeamMatchState = TeamMatchState.create("Paid Build", definitions)
	team.league_rules = build._league_rules.duplicate(true)
	team.league_ownership = build._bank.to_data()
	team.track_bases = true
	team.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	MatchFieldSupply.sync_capacity(team, build._bank.view())
	return team
