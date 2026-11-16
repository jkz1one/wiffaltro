extends "res://src/tests/league_doubleheader_build_test.gd"


## Controlled prior workload, actual seeded paid copies, ordinary state actions; no full-game claim.
func _ready() -> void:
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	var build: SeasonBuild
	for seed_value in range(128):
		var candidate: SeasonBuild = _build(seed_value)
		candidate.commit(
			{"id": "inventory-rules-v1", "rev": 0, "op": SeasonInventoryResale.ENABLE_OP}
		)
		candidate.commit(_reward(candidate, 0, 0, 8))
		candidate.commit(SeasonOpponentPolicy.command(candidate, "open"))
		var recovery: String = ""
		for key: String in candidate._visit.offers:
			if candidate._visit.offers[key] == "C02":
				recovery = key
		if recovery.is_empty():
			continue
		if not (
			candidate
			. commit(SeasonOpponentPolicy.command(candidate, "tactical_buy", {"offer": recovery}))
			. ok
		):
			continue
		for roll in range(4):
			var second: String = ""
			for key: String in candidate._visit.offers:
				if candidate._visit.offers[key] in ["A10", "C02", "C03"]:
					second = key
			if not second.is_empty():
				if (
					candidate
					. commit(
						SeasonOpponentPolicy.command(candidate, "tactical_buy", {"offer": second})
					)
					. ok
				):
					build = candidate
				break
			if (
				candidate.cash() < 6
				or not candidate.commit(SeasonOpponentPolicy.command(candidate, "reroll")).ok
			):
				break
		if build != null:
			break
	check(build != null, "actual seeded Recovery plus second unused copy")
	if build == null:
		get_tree().quit(1)
		return
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 3})).ok,
		"second leg inventory anchor"
	)
	var definitions: Array[PlayerDefinition] = []
	for id: String in roster:
		definitions.append(build.definition(id))
	var own: TeamMatchState = TeamMatchState.create("Paid carried team", definitions)
	own.league_rules = build._league_rules.duplicate(true)
	own.league_ownership = build._bank.to_data()
	own.league_pair = SeasonDoubleheaderBuild.pair_for(build, 3)
	own.track_bases = true
	own.tactics.held = SeasonTacticalCatalog.held(build._bank.view())
	for player: PlayerMatchState in own.roster:
		player.stamina_remaining = maxf(
			0.0,
			player.stamina_max - float(own.league_pair.debt.get(String(player.definition.id), 0.0))
		)
	var away_defs: Array[PlayerDefinition] = []
	for id: String in SeasonPlayerCatalog.ids().slice(4, 8):
		away_defs.append(ContentDB.get_player(StringName(id)))
	var away: TeamMatchState = TeamMatchState.create("Opponent", away_defs)
	away.league_rules = build._league_rules.duplicate(true)
	away.league_ownership = build._bank.to_data()
	away.league_pair = {"game": 3, "first": 0, "debt": {}}
	away.track_bases = true
	var state: MatchState = MatchState.create(away, own)
	state.league_rules = build._league_rules.duplicate(true)
	own.field_supply.receipt = SeasonFieldGrant.receipt(3)
	MatchFieldSupply.sync_capacity(own, build._bank.view())
	state.base_flow.prepare(state)
	var recovery: String = own.tactics.held[0].id
	var unused: String = own.tactics.held[1].id
	check(
		own.roster[0].stamina_remaining < own.roster[0].stamina_max,
		"validated first-leg debt lowers initial stamina"
	)
	check(
		own.tactics.activate(state, own, recovery),
		"Recovery legally activates before subject's first current release"
	)
	check(own.select_pitcher(1), "normal pitcher switch after recovery")
	var helper: Node = load("res://src/tests/inventory_prefix_test.gd").new()
	helper._out(state)
	helper.free()
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		state, own, SeasonInventoryRules.anchor(build, 3)
	)
	check(not proof.is_empty(), "carried recovery followed by completed PA captures")
	var cmd: Dictionary = SeasonOpponentPolicy.command(
		build,
		"match_supply_sell",
		{
			"game": 3,
			"receipt": unused,
			"first_pitch": [],
			"field_state": proof.get("field_state", {}),
			"inventory_prefix": proof
		}
	)
	var original_debt: Dictionary = SeasonDoubleheaderBuild.pair_for(build, 3).duplicate(true)
	var result: Dictionary = build.commit(cmd)
	check(
		result.ok,
		"Build reconstructs carried stamina for later unused sale: " + str(result.get("error"))
	)
	check(
		ClubCareer.same(original_debt, SeasonDoubleheaderBuild.pair_for(build, 3)),
		"resale does not rewrite original carried debt"
	)
	var restored: SeasonBuild = SeasonBuild.from_data(cold(build.to_data()), build._seed, roster)
	check(
		restored != null and ClubCareer.same(restored.to_data(), build.to_data()),
		"carried recovery and resale cold replay"
	)
	print("Inventory carried Recovery checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
