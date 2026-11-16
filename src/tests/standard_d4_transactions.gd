extends "res://src/tests/standard_d4_transactions_fixture_base.gd"
func _settlement_and_rollback() -> void:
	var build: SeasonBuild = _build()
	_check(_buy(build, "B02", SHORT.B02).ok, "controlled Community College short-term copy")
	_check(
		(
			build
			. _book
			. commit(
				{
					"id": "authored-growth",
					"rev": build._book.revision(),
					"op": "stat",
					"player": ROSTER[0],
					"target": "pitching"
				}
			)
			. ok
		),
		"authored earned-growth fixture"
	)
	var growth: Dictionary = build._book.to_data().duplicate(true)
	_check(
		build.definition(ROSTER[0]).season_sponsors.get("B02") == 1,
		"Community College normal active modifier"
	)
	for game in [6, 7]:
		var before: Dictionary = build.to_data().duplicate(true)
		var wallet: Dictionary = build._bank.view().duplicate(true)
		var bad: Dictionary = _command(
			build,
			"reward",
			{"game": game, "win": true, "performance": _performance(), "tactics": [{}]}
		)
		_check(
			(
				not build.commit(bad).ok
				and build.to_data() == before
				and build._bank.view() == wallet
				and build._book.to_data() == growth
			),
			"late settlement rejection rolls back reward duration and growth"
		)
		var good: Dictionary = _command(
			build, "reward", {"game": game, "win": true, "performance": _performance()}
		)
		var cash: int = build.cash()
		_check(
			build.preview(good).ok and build.to_data() == before and build._bank.view() == wallet,
			"full settlement preview cannot age"
		)
		_check(
			build.commit(good).ok and build.cash() == cash + 18 and build._bank.completion_closed(),
			"all settlement ends with exact reward and closure"
		)
		_check(
			(
				build._bank._events.back().op == "sponsor_game_end"
				and build.roster_for_game(game) == ROSTER
				and int(build._visit.number) == game + 1
			),
			"closure follows roster and visit settlement"
		)
		var after: Dictionary = build.to_data().duplicate(true)
		_check(
			build.commit(good).replayed and build.to_data() == after,
			"Build reward retry does not consume another game"
		)
		_check(
			_receipt(build, "B02").get("games_remaining", 0) == (1 if game == 6 else 0),
			"remaining duration follows own accepted games"
		)
		_check(
			ClubPlayerProgress._sponsor_counts(build).get(game) == 1,
			"final covered game retains progress sponsor credit"
		)
		_check(build._book.to_data() == growth, "expiry preserves all earned growth")
	_check(
		(
			not build.definition(ROSTER[0]).season_sponsors.has("B02")
			and (
				build.player(ROSTER[0]).stats.pitching
				> SeasonPlayerCatalog.profile(ROSTER[0]).stats.pitching
			)
		),
		"next-game modifier absent while growth remains"
	)
	_check(
		(
			build.commit(_command(build, "open")).ok
			and _buy(build, "B02", SHORT.B02).ok
			and _receipt(build, "B02").get("games_remaining") == 2
		),
		"expired slot permits ordinary later reacquisition"
	)


func _wholesale(grouped: bool) -> void:
	var build: SeasonBuild = _build()
	_check(_buy(build, "J02", "unit:wholesale").ok, "controlled Wholesale access")
	build._visit.offers = {SHORT.A07: "A07", SHORT.B02: "B02"}
	var fields: Dictionary = {
		"first": {"offer": SHORT.A07, "replace": ""},
		"second": {"offer": SHORT.B02, "replace": ""},
		"discounted": SHORT.B02
	}
	if grouped:
		fields.sales = []
	var request: Dictionary = _command(build, "wholesale", fields)
	var before: Dictionary = build.to_data().duplicate(true)
	var cash: int = build.cash()
	_check(
		build.preview(request).ok and build.to_data() == before,
		"Wholesale preview does not acquire or age"
	)
	_check(
		build.commit(request).ok and build.commit(request).replayed,
		"Wholesale direct/grouped idempotent purchase"
	)
	var first: Dictionary = _receipt(build, "A07")
	var second: Dictionary = _receipt(build, "B02")
	_check(
		(
			first.get("terms") == {"rule": RULE, "source_offer": SHORT.A07, "duration": 2}
			and second.get("terms") == {"rule": RULE, "source_offer": SHORT.B02, "duration": 2}
		),
		"Wholesale preserves both original offer identities"
	)
	_check(
		first.get("paid") == 14 and second.get("paid") == 9 and build.cash() == cash - 23,
		"unchanged cheaper-item discount"
	)
	if first.is_empty() or second.is_empty():
		return
	_check(
		(
			SeasonSponsorCatalog.resale(first) == 7
			and SeasonSponsorCatalog.resale(second) == 4
			and first.games_remaining == 2
			and second.games_remaining == 2
		),
		"actual-paid early refund with unconsumed duration"
	)
	cash = build.cash()
	fields = {"receipt": second.id}
	if grouped:
		fields.sales = []
	_check(
		build.commit(_command(build, "sponsor_sell", fields)).ok and build.cash() == cash + 4,
		"discounted early cancellation credits floor nine over two"
	)


func _ready() -> void:
	_selector()
	_context_and_legacy()
	for item: String in SHORT:
		_bank_expiry(item)
	_bank_refusals()
	for grouped: bool in [false, true]:
		_removal(grouped)
		_wholesale(grouped)
		_live_removal(grouped)
	_raincheck()
	_settlement_and_rollback()
	_generation_replay()
	_generated_expiry()
	_ai_expiry()
	await TestAudioDrain.finish(get_tree())
	print(
		(
			"STANDARD_D4_TRANSACTIONS checks=%d failures=%d controlled_stock=true physical_games=0"
			% [_checks, _failures]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)
