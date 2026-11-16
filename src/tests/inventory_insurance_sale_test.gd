extends "res://src/tests/inventory_prefix_test.gd"


## Controlled credited eligibility/funding; actual seeded purchase and accepted sale journals.
func _ready() -> void:
	var ids: Array[String] = []
	ids.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	var probe: SeasonBuild = SeasonBuild.new(0, ids)
	probe.enable_league_rules(LeagueRules.capture("dugout"))
	probe._supply_start = 3
	probe._visit.number = 3
	var selected: int = -1
	for seed_value in range(10000):
		probe._seed = seed_value
		var values: Array = probe._offers(0).values()
		if (
			values.has("E04")
			and (values.has("A10") or values.has("C03"))
			and probe._offers(1).values().any(
				func(item: Variant) -> bool: return item in ["A10", "C02", "C03"]
			)
		):
			selected = seed_value
			break
	check(selected >= 0, "seeded insurance and tactical stock")
	var build: SeasonBuild = SeasonBuild.new(selected, ids)
	build.enable_league_rules(LeagueRules.capture("dugout"))
	build._supply_start = 3
	check(
		(
			build
			. commit({"id": "inventory-rules-v1", "rev": 0, "op": SeasonInventoryResale.ENABLE_OP})
			. ok
		),
		"fresh capability"
	)
	for game in range(3):
		check(
			(
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": game, "win": true}))
				. ok
			),
			"controlled credit"
		)
	build.commit(SeasonOpponentPolicy.command(build, "open"))
	var sponsor: String = ""
	var first: String = ""
	for key: String in build._visit.offers:
		if build._visit.offers[key] == "E04":
			sponsor = key
		if build._visit.offers[key] in ["A10", "C03"]:
			first = key
	check(
		(
			build
			. commit(
				SeasonOpponentPolicy.command(
					build, "sponsor_buy", {"offer": sponsor, "replace": ""}
				)
			)
			. ok
		),
		"actual paid E04"
	)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "tactical_buy", {"offer": first})).ok,
		"actual insured supply"
	)
	var bought: bool = false
	for roll in range(6):
		var second: String = ""
		for key: String in build._visit.offers:
			if build._visit.offers[key] in ["A10", "C02", "C03"]:
				second = key
		if not second.is_empty():
			var bought_result: Dictionary = build.commit(
				SeasonOpponentPolicy.command(build, "tactical_buy", {"offer": second})
			)
			bought = bought_result.ok
			if not bought:
				print("INSURANCE_SECOND_BUY ", bought_result)
			break
		var rolled: Dictionary = build.commit(SeasonOpponentPolicy.command(build, "reroll"))
		if not rolled.ok:
			print("INSURANCE_REROLL ", rolled)
			break
	check(bought, "actual second unused supply")
	if not bought:
		get_tree().quit(1)
		return
	var insured: String = build._bank.view().held[0].id
	var unused: String = build._bank.view().held[1].id
	check(
		(
			build
			. commit(SeasonOpponentPolicy.command(build, "insure", {"game": 3, "receipt": insured}))
			. ok
		),
		"journal insurance mark"
	)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 3})).ok,
		"anchored attempt"
	)
	for before_use: bool in [false, true]:
		var current: SeasonBuild = build._fork()
		var state: MatchState = _paid_state(current)
		var own: TeamMatchState = state.away_team
		var e04: String = current._bank.view().sponsors[0].id
		if before_use:
			_sell_e04(current, state, e04)
		check(
			own.tactics.activate(
				state,
				own,
				insured,
				&"swing.contact" if current._bank.view().held[0].item == "C03" else &""
			),
			"runtime records insured activation"
		)
		_out(state)
		if not before_use:
			_sell_e04(current, state, e04)
		var proof: Dictionary = PhysicalInventoryPrefix.capture(
			state, own, SeasonInventoryRules.anchor(current, 3)
		)
		var command: Dictionary = SeasonOpponentPolicy.command(
			current,
			"match_supply_sell",
			{
				"game": 3,
				"receipt": unused,
				"first_pitch": [],
				"field_state": proof.get("field_state", {}),
				"inventory_prefix": proof
			}
		)
		var prior: Dictionary = current.to_data()
		var result: Dictionary = current.commit(command)
		if before_use:
			check(
				not result.ok and ClubCareer.same(prior, current.to_data()),
				"post-retirement forged insured activation rejects atomically"
			)
		else:
			check(
				result.ok,
				"earlier insured use remains valid after E04 sale: " + str(result.get("error"))
			)
			var cold: SeasonBuild = SeasonBuild.from_data(
				JSON.parse_string(JSON.stringify(current.to_data(), "", true, true)), selected, ids
			)
			check(
				cold != null and ClubCareer.same(cold.to_data(), current.to_data()),
				"insurance retirement and later resale cold replay"
			)
	print("Inventory insurance sale checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _sell_e04(build: SeasonBuild, state: MatchState, receipt: String) -> void:
	var sale: Dictionary = SeasonOpponentPolicy.command(
		build,
		"match_sell",
		{
			"game": 3,
			"receipt": receipt,
			"first_pitch": null if state.plate_appearance_number == 1 else [],
			"field_state": SeasonFieldSales.capture(state, state.away_team)
		}
	)
	check(build.commit(sale).ok, "accepted exact E04 sale cutoff")


func _paid_state(build: SeasonBuild) -> MatchState:
	var defs: Array[PlayerDefinition] = []
	for id: String in build.roster():
		defs.append(build.definition(id))
	var own: TeamMatchState = TeamMatchState.create("Insured paid team", defs)
	own.league_rules = build._league_rules.duplicate(true)
	own.league_ownership = build._bank.to_data()
	own.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	own.tactics.insured_receipt = SeasonSecondChance.target(build, 3)
	own.track_bases = true
	var other: TeamMatchState = _team(SeasonPlayerCatalog.ids().slice(4, 8), build._bank)
	var state: MatchState = MatchState.create(own, other)
	state.league_rules = build._league_rules.duplicate(true)
	own.field_supply.receipt = SeasonFieldGrant.receipt(3)
	MatchFieldSupply.sync_capacity(own, build._bank.view())
	return state
