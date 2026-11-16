extends "res://src/tests/inventory_prefix_test.gd"


## Controlled loss credit, actual seeded Budget purchase, authoritative pregame and restart
## journals.
func _ready() -> void:
	var ids: Array[String] = []
	ids.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	var probe: SeasonBuild = SeasonBuild.new(0, ids)
	probe.enable_league_rules(LeagueRules.capture("dugout"))
	probe._visit.number = 1
	var seed_value: int = -1
	for seed_id in range(1000):
		probe._seed = seed_id
		if probe._offers(0).values().has("E08"):
			seed_value = seed_id
			break
	check(seed_value >= 0, "seeded Budget offer exists")
	var build: SeasonBuild = SeasonBuild.new(seed_value, ids)
	build.enable_league_rules(LeagueRules.capture("dugout"))
	check(
		(
			build
			. commit({"id": "inventory-rules-v1", "rev": 0, "op": SeasonInventoryResale.ENABLE_OP})
			. ok
		),
		"fresh rules"
	)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "reward", {"game": 0, "win": false})).ok,
		"controlled loss pays normal12"
	)
	build.commit(SeasonOpponentPolicy.command(build, "open"))
	var offer: String = ""
	for key: String in build._visit.offers:
		if build._visit.offers[key] == "E08":
			offer = key
	check(
		(
			build
			. commit(
				SeasonOpponentPolicy.command(build, "sponsor_buy", {"offer": offer, "replace": ""})
			)
			. ok
		),
		"paid Budget10 leaves2Cash"
	)
	var pregame: Dictionary = SeasonOpponentPolicy.command(build, "pregame", {"game": 1})
	check(
		build.commit(pregame).ok and build._pregames["1"].outcome == "granted",
		"actual once-fixture pregame generates Plan"
	)
	var copy: Dictionary = build._bank.view().held[0]
	check(
		copy.id == "budget:1" and copy.item == "C03" and copy.paid == 0,
		"generated receipt keeps actual paid zero"
	)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 1})).ok,
		"anchor initial generated copy"
	)
	var defs: Array[PlayerDefinition] = []
	for id: String in ids:
		defs.append(build.definition(id))
	var own: TeamMatchState = TeamMatchState.create("Budget owner", defs)
	own.league_rules = build._league_rules.duplicate(true)
	own.league_ownership = build._bank.to_data()
	own.track_bases = true
	own.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	var away: TeamMatchState = _team(SeasonPlayerCatalog.ids().slice(4, 8), build._bank)
	var state: MatchState = MatchState.create(away, own)
	state.league_rules = build._league_rules.duplicate(true)
	own.field_supply.receipt = SeasonFieldGrant.receipt(1)
	MatchFieldSupply.sync_capacity(own, build._bank.view())
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		state, own, SeasonInventoryRules.anchor(build, 1)
	)
	var sale: Dictionary = SeasonOpponentPolicy.command(
		build,
		"match_supply_sell",
		{
			"game": 1,
			"receipt": copy.id,
			"first_pitch": null,
			"field_state": proof.get("field_state", {}),
			"inventory_prefix": proof
		}
	)
	check(
		build.commit(sale).ok and build.cash() == 3 and build._bank.view().held.is_empty(),
		"unused free Plan pays half normal value once"
	)
	check(
		(
			build.commit(pregame).get("replayed", false)
			and build.cash() == 3
			and build._bank.view().held.is_empty()
		),
		"same pregame retry cannot regenerate after sale"
	)
	check(
		not build.commit(SeasonOpponentPolicy.command(build, "pregame", {"game": 1})).ok,
		"new pregame ID cannot farm same fixture"
	)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 1})).ok,
		"restart attempt"
	)
	check(
		(
			not build.commit(SeasonOpponentPolicy.command(build, "pregame", {"game": 1})).ok
			and build._bank.view().held.is_empty()
		),
		"restart does not reset Budget decision"
	)
	var restored: SeasonBuild = SeasonBuild.from_data(
		JSON.parse_string(JSON.stringify(build.to_data(), "", true, true)), seed_value, ids
	)
	check(
		restored != null and ClubCareer.same(restored.to_data(), build.to_data()),
		"Budget sale and restart cold replay"
	)
	print("Inventory Budget sale checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
