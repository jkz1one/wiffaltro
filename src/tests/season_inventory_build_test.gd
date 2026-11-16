extends "res://src/tests/league_equipment_stage_test.gd"


## Controlled credited results and real seeded shop purchases, not earned-season play.
func _ready() -> void:
	var roster: Array[String] = []
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	var build: SeasonBuild = SeasonBuild.new(284, roster)
	check(build.enable_league_rules(LeagueRules.capture("equipment")), "closed context")
	check(
		(
			build
			. commit({"id": "inventory-rules-v1", "rev": 0, "op": SeasonInventoryResale.ENABLE_OP})
			. ok
		),
		"explicit fresh migration"
	)
	for game in range(2):
		check(
			(
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": game, "win": true}))
				. ok
			),
			"controlled reward"
		)
	check(build.commit(SeasonOpponentPolicy.command(build, "open")).ok, "seeded shop")
	check(
		(
			build
			. commit(
				SeasonOpponentPolicy.command(
					build, "equip", {"offer": _offer(build, "BAT-CON-01"), "replace": ""}
				)
			)
			. ok
		),
		"active paid"
	)
	check(
		(
			build
			. commit(
				SeasonOpponentPolicy.command(
					build, "spare_buy", {"offer": _offer(build, "BAT-POW-01")}
				)
			)
			. ok
		),
		"spare paid"
	)
	var wallet: Dictionary = build._bank.view()
	var before: Dictionary = build.to_data()
	var menu: Dictionary = SeasonOpponentPolicy.command(
		build, "inventory_sell", {"receipt": wallet.spare.id}
	)
	check(
		build.candidate(menu) != null and ClubCareer.same(before, build.to_data()),
		"cancel preview preserves owner"
	)
	var safe: SeasonBuild = build._fork()
	safe._visit.open = false
	check(safe.commit(menu).ok, "safe menu not dependent on open shop")
	check(
		safe._bank.view().gear == wallet.gear and safe._bank.view().spare.is_empty(),
		"safe sale preserves active"
	)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 2})).ok,
		"start attempt"
	)
	var attempt: Dictionary = build._match_inventory.duplicate(true)
	var sale: Dictionary = SeasonOpponentPolicy.command(
		build,
		"match_sell",
		{
			"game": 2,
			"receipt": wallet.spare.id,
			"first_pitch": null,
			"field_state": {"pa": 1, "boundary": 0, "grant": {}, "uses": [], "fielding": []}
		}
	)
	check(
		not (
			build
			. commit(
				SeasonOpponentPolicy.command(build, "inventory_sell", {"receipt": wallet.spare.id})
			)
			. ok
		),
		"menu route blocked during attempt"
	)
	check(build.commit(sale).ok, "inactive spare sold during safe live boundary")
	check(
		build._match_inventory.gear == attempt.gear,
		"spare sale cannot erase active first-release snapshot"
	)
	check(
		build._bank.view().gear == wallet.gear and build.cash() == int(wallet.cash) + 5,
		"active unchanged exact half refund"
	)
	var saved: Dictionary = build.to_data()
	var restored: SeasonBuild = SeasonBuild.from_data(
		JSON.parse_string(JSON.stringify(saved, "", true, true)), 284, roster
	)
	check(restored != null, "live spare sale cold Build replay")
	if restored != null:
		check(ClubCareer.same(restored.to_data(), saved), "cold exact receipt journal")
	check(
		build.commit(sale).replayed and ClubCareer.same(saved, build.to_data()),
		"same request retry pays once"
	)
	check(
		not (
			build
			. commit(
				SeasonOpponentPolicy.command(
					build,
					"match_sell",
					{
						"game": 2,
						"receipt": wallet.spare.id,
						"first_pitch": null,
						"field_state":
						{"pa": 1, "boundary": 0, "grant": {}, "uses": [], "fielding": []}
					}
				)
			)
			. ok
		),
		"fresh duplicate sale rejects"
	)
	print("Inventory Build checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
