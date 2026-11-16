extends "res://src/tests/league_doubleheader_build_test.gd"
## Differential unit evidence, not physical-game or earned-shop claims.
## Oracle is the frozen pre-optimization helper with only class_name removed.
## Paid wallet/development fixtures are controlled journals, not restorable Build saves.

const OldContext = preload("res://src/tests/league_doubleheader_projection_oracle.gd")


func _ready() -> void:
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	_basics_and_completed_rewards()
	_budget_contexts()
	_provenance_and_legends()
	_sales_and_gear()
	_association_group()
	_double_major_current_abilities()
	_bad_histories()
	_output_isolation()
	_allocation_diagnostic()
	print("Doubleheader projection differential checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _serialized(value: Variant) -> Variant:
	# All stored definition fields, not a hand-picked subset: nested pitch/delivery
	# resources, mastery, ability order, calibration, gear and sponsor maps included.
	if value is Resource:
		var result: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			var name: String = property.name
			if (
				(int(property.usage) & PROPERTY_USAGE_STORAGE) == 0
				or name in ["script", "resource_local_to_scene", "resource_path", "resource_name"]
			):
				continue
			result[name] = _serialized(value.get(name))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _serialized(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_serialized(entry))
		return result
	if value is Vector3:
		return {"vector3": [value.x, value.y, value.z]}
	if value is Vector2:
		return {"vector2": [value.x, value.y]}
	return String(value) if value is StringName else value


func _exact(left: Variant, right: Variant) -> bool:
	# Full-precision float serialization prevents a loose approximate comparison.
	return (
		JSON.stringify(_serialized(left), "", true, true)
		== JSON.stringify(_serialized(right), "", true, true)
	)


func _canonical(context: Dictionary, old: bool = false) -> Dictionary:
	if context.is_empty():
		return {}
	var ids: Array = context.build.roster() if old else context.roster
	var definitions: Dictionary = {}
	for id: String in ids:
		definitions[id] = context.build.definition(id) if old else context.definitions.get(id)
	return {
		"roster": ids,
		"definitions": _serialized(definitions),
		"ownership": context.build._bank.to_data() if old else context.ownership,
		"refund_through": context.refund_through,
		"cost_context": _serialized(context.cost_context)
	}


func _input_snapshot(build: SeasonBuild) -> Dictionary:
	var definitions: Dictionary = {}
	var authored: Dictionary = {}
	for id: String in build.roster():
		definitions[id] = _serialized(build.definition(id))
		authored[id] = _serialized(ContentDB.get_player(StringName(id)))
	return {
		"build": build.to_data(),
		"book": build._book.to_data(),
		"players": build._book._players.duplicate(true),
		"bank": build._bank.to_data(),
		"wallet": build._bank.view(),
		"abilities": build._abilities.learned.duplicate(true),
		"legends": build._legends.duplicate(true),
		"definitions": definitions,
		"authored": authored
	}


func _compare(build: SeasonBuild, game: int, label: String, accepted: bool = true) -> Dictionary:
	var before: Dictionary = _input_snapshot(build)
	var expected: Dictionary = OldContext.context(build, game)
	var actual: Dictionary = SeasonDoubleheaderBuild.context(build, game)
	check(expected.is_empty() == (not accepted), label + ": oracle acceptance")
	check(actual.is_empty() == (not accepted), label + ": projection acceptance")
	check(_exact(_canonical(actual), _canonical(expected, true)), label + ": exact differential")
	check(_exact(_input_snapshot(build), before), label + ": input and authored content unchanged")
	if not actual.is_empty():
		check(
			SeasonOwnership._keys(
				actual, ["roster", "definitions", "ownership", "refund_through", "cost_context"]
			),
			label + ": no history-bearing Build in output"
		)
		check(
			actual.definitions.keys() == actual.roster, label + ": canonical IDs and roster order"
		)
	return actual


func _validate_both(
	build: SeasonBuild, command: Dictionary, label: String, accepted: bool = true
) -> void:
	var old_error: String = OldContext.validate(build, command)
	var new_error: String = SeasonDoubleheaderBuild.validate(build, command)
	check(old_error == new_error and new_error.is_empty() == accepted, label)


func _basics_and_completed_rewards() -> void:
	var reordered: Array[String] = []
	reordered.assign(SeasonPlayerCatalog.ids().slice(4, 8))
	reordered.reverse()
	var varied: SeasonBuild = SeasonBuild.new(551, reordered)
	check(
		varied.enable_league_rules(LeagueRules.capture("doubleheader")),
		"ordered mixed-delivery fixture"
	)
	_compare(varied, 0, "noncanonical roster order and mixed natural deliveries")
	var serialized: Dictionary = _serialized(varied.definition(reordered[0]))
	check(
		(
			serialized.has("natural_delivery")
			and serialized.has("season_gear")
			and serialized.has("season_sponsors")
			and serialized.has("season_abilities")
			and serialized.has("season_alley_calibrated")
			and serialized.has("starting_pitches")
		),
		"serializer includes complete player gameplay fields"
	)
	check(
		(
			serialized.natural_delivery.has("release_offset_pitcher_frame_m")
			and serialized.starting_pitches[0].has("delivery_profile")
			and serialized.starting_pitches[0].has("mastery_level")
			and serialized.starting_pitches[0].has("mastery_movement_scale")
			and serialized.starting_pitches[0].has("gear_command_scale")
		),
		"serializer includes nested delivery, mastery and gear calibration"
	)
	for market in [0, 12]:
		var build: SeasonBuild = _build(551, market)
		var label: String = "human" if market == 0 else "AI"
		_compare(build, 0, label + " no-sale first leg")
		var first: Dictionary = _reward(build, 0, 0, 4)
		_validate_both(build, first, label + " first-leg workload validation")
		check(build.commit(first).ok, label + ": first completed reward")
		_compare(build, 0, label + " already-paid reward", false)
		_compare(build, 3, label + " second leg")
		check(
			_exact(OldContext.pair_for(build, 3), SeasonDoubleheaderBuild.pair_for(build, 3)),
			label + ": exact journal-derived second-leg debt"
		)
		var second: Dictionary = _reward(build, 3, 1, 3)
		check(
			not second.doubleheader_workload.pair.debt.is_empty(), label + ": nonempty carry debt"
		)
		_validate_both(build, second, label + " second-leg workload validation")
		var wrong: Dictionary = second.duplicate(true)
		wrong.doubleheader_workload.pair.debt.clear()
		_validate_both(build, wrong, label + " forged debt rejected identically", false)
		check(build.commit(second).ok, label + ": second completed reward")
		_compare(build, 30, label + " playoff")
		var playoff: Dictionary = _reward(build, 30)
		_validate_both(build, playoff, label + " playoff workload validation")
		check(
			playoff.doubleheader_workload.pair == {"game": 30, "first": -1, "debt": {}},
			label + ": playoff reset remains exact"
		)
		var restored: SeasonBuild = SeasonBuild.from_data(
			cold(build.to_data()), build._seed, roster
		)
		check(restored != null, label + ": genuine Build history cold replays")
		if restored != null:
			_compare(restored, 30, label + " cold restored playoff")


func _funded(market: int = 0) -> SeasonBuild:
	var build: SeasonBuild = _build(551, market)
	# Real ownership commits but synthetic funding, explicitly not a full Build save.
	for game in range(6):
		check(
			(
				build
				. _bank
				. commit(
					OwnershipFixtures.request(build._bank, "reward", {"game": game, "win": true})
				)
				. ok
			),
			"controlled wallet funding"
		)
	return build


func _buy_item(build: SeasonBuild, item: String) -> String:
	var offer: String = "projection:%d" % build._bank.revision()
	check(
		(
			build
			. _bank
			. commit(OwnershipFixtures.request(build._bank, "stock", {"offers": {offer: item}}))
			. ok
		),
		"controlled real catalog stock " + item
	)
	var paid: Dictionary = build._bank.commit(OwnershipFixtures.buy(build._bank, offer))
	check(paid.ok, "controlled paid copy " + item)
	if not paid.ok:
		return ""
	for receipt: Dictionary in build._bank.view().sponsors:
		if receipt.item == item:
			return receipt.id
	for receipt: Dictionary in build._bank.view().gear.values():
		if receipt.get("item") == item:
			return receipt.id
	return ""


func _start(build: SeasonBuild) -> void:
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 6})).ok,
		"controlled current attempt marker"
	)


func _sell(
	build: SeasonBuild, receipt: String, pa: int, boundary: int, fields: Dictionary = {}
) -> bool:
	var command: Dictionary = SeasonOpponentPolicy.command(
		build,
		"match_sell",
		{
			"game": 6,
			"receipt": receipt,
			"first_pitch": null,
			"field_state": {"pa": pa, "boundary": boundary, "grant": {}, "uses": [], "fielding": []}
		}
	)
	command.merge(fields, true)
	var result: Dictionary = build.commit(command)
	check(result.ok, "accepted controlled match sale: " + str(result.get("error", "")))
	return result.ok


func _budget_contexts() -> void:
	for market in [0, 12]:
		var build: SeasonBuild = _funded(market)
		_buy_item(build, "E08")
		check(
			(
				build
				. _bank
				. commit(
					OwnershipFixtures.request(build._bank, "charge", {"amount": build.cash() - 4})
				)
				. ok
			),
			"controlled Budget threshold"
		)
		var pregrant: Dictionary = build._bank.to_data()
		_compare(build, 6, "Budget before pregame market %d" % market)
		check(
			build.commit(SeasonOpponentPolicy.command(build, "pregame", {"game": 6})).ok,
			"Budget pregame commitment"
		)
		check(build._pregames["6"].outcome == "granted", "Budget actually grants paid-journal copy")
		var context: Dictionary = _compare(build, 6, "Budget granted market %d" % market)
		if not context.is_empty():
			check(
				_exact(context.ownership, pregrant if market == 12 else build._bank.to_data()),
				"only AI context strips current Budget grant"
			)
		var wrong: SeasonBuild = build._fork()
		if market == 12:
			wrong._bank._events[-1].id = "budget:foreign"
			_compare(wrong, 6, "AI Budget exact suffix identity", false)
			wrong = build._fork()
			wrong._events.append({"id": "after-budget", "rev": wrong.revision(), "op": "open"})
			_compare(wrong, 6, "AI Budget must be latest Build operation", false)
	var inactive: SeasonBuild = _build(551, 12)
	check(
		inactive.commit(SeasonOpponentPolicy.command(inactive, "pregame", {"game": 6})).ok,
		"inactive AI pregame"
	)
	_compare(inactive, 6, "AI pregame without grant")


func _grow(
	build: SeasonBuild, player: String, op: String, target: String, fields: Dictionary = {}
) -> void:
	var command: Dictionary = {
		"id": "projection-growth:%d" % build._book.revision(),
		"rev": build._book.revision(),
		"player": player,
		"op": op,
		"target": target
	}
	command.merge(fields)
	check(build._book.commit(command).ok, "controlled valid development provenance " + op)


func _provenance_and_legends() -> void:
	for market in [0, 12]:
		var build: SeasonBuild = _funded(market)
		_buy_item(build, "B02")
		var legend: String = _buy_item(build, "E05")
		_grow(build, roster[0], "stat", "contact")
		_grow(build, roster[0], "mastery", build.player(roster[0]).active[0])
		_grow(build, roster[1], "mastery", build.player(roster[1]).active[0])
		_grow(build, roster[2], "recruit", "late")
		var recipe: String = ""
		for candidate: String in DevelopmentShopCatalog.LESSON_PRICES:
			if not build.player(roster[3]).active.has(candidate):
				recipe = candidate
				break
		check(not recipe.is_empty(), "controlled unlearned recipe exists")
		if not recipe.is_empty():
			_grow(build, roster[3], "learn", recipe, {"replace": build.player(roster[3]).active[0]})
		build._legends[legend] = ["double", "single", "triple"]
		var context: Dictionary = _compare(
			build, 6, "trained provenance and receipt stamps market %d" % market
		)
		if not context.is_empty():
			for id: String in roster:
				check(
					context.definitions[id].season_sponsors.get("B02") == 2,
					"B02 counts earned players, not upgrades, learning or recruit catch-up"
				)
				check(
					context.definitions[id].season_sponsors.get("E05") == 3,
					"E05 uses exact active receipt stamps"
				)
		_grow(build, roster[3], "stat", "fielding")
		context = _compare(build, 6, "later earned growth market %d" % market)
		if not context.is_empty():
			check(
				context.definitions[roster[0]].season_sponsors.B02 == 3,
				"later earned growth changes B02 through provenance"
			)


func _sales_and_gear() -> void:
	for gear: String in ["D02", "A04"]:
		var ai: SeasonBuild = _funded(12)
		_buy_item(ai, gear)
		_compare(ai, 6, "AI no-sale workload gear " + gear)
		for same_boundary in [false, true]:
			var build: SeasonBuild = _funded()
			var gear_receipt: String = _buy_item(build, gear)
			var strikecraft: String = _buy_item(build, "B03")
			var college: String = _buy_item(build, "B02")
			_start(build)
			var label: String = "%s %s cutoffs" % [gear, "equal" if same_boundary else "distinct"]
			var start: Dictionary = _compare(build, 6, label + " before sales")
			if not start.is_empty():
				check(
					start.refund_through == 99999 and start.cost_context.is_empty(),
					"active B03 unlimited cutoff"
				)
				check(
					start.definitions[roster[0]].season_gear.misc == gear,
					"exact starting workload gear"
				)
			_sell(build, gear_receipt, 1, 0)
			var context: Dictionary = _compare(build, 6, label + " before-first-release gear sale")
			if not context.is_empty():
				check(
					context.cost_context.size() == 1 and context.cost_context[0].after == 0,
					"before-first-release retirement cutoff is zero"
				)
			_sell(build, strikecraft, 1 if same_boundary else 4, 0 if same_boundary else 3)
			_sell(build, college, 1 if same_boundary else 6, 0 if same_boundary else 5)
			context = _compare(build, 6, label + " multiple sales")
			if not context.is_empty():
				check(
					context.refund_through == (0 if same_boundary else 3),
					"B03 inclusive retirement cutoff"
				)
				check(
					context.cost_context.size() == (1 if same_boundary else 3),
					"equal cutoffs coalesce, distinct cutoffs remain ordered"
				)
				for id: String in roster:
					check(
						context.definitions[id].season_gear.misc == gear,
						"initial definition retains sold gear"
					)
					check(
						(
							not context.cost_context[-1].definitions[id].season_gear.has("misc")
							and not context.cost_context[-1].definitions[id].season_sponsors.has(
								"B03"
							)
							and not context.cost_context[-1].definitions[id].season_sponsors.has(
								"B02"
							)
						),
						"final transition retires every sold effect"
					)
			_start(build)
			context = _compare(build, 6, label + " replaced attempt marker")
			if not context.is_empty():
				check(
					context.refund_through == -1 and context.cost_context.is_empty(),
					"restart excludes abandoned sale timeline"
				)


func _association_group() -> void:
	var build: SeasonBuild = _funded()
	var association: String = _buy_item(build, "J05")
	var auxiliary: Array = []
	for id: String in ["D01", "F02", "F03", "G04", "F01", "E08"]:
		auxiliary.append(_buy_item(build, id))
	check(
		build._bank.view().sponsors.size() == 7, "controlled Association occupies seven paid slots"
	)
	_start(build)
	_sell(build, association, 3, 2, {"sales": [auxiliary[0]], "discard": []})
	var context: Dictionary = _compare(build, 6, "Association auxiliary sponsor sale")
	if not context.is_empty():
		check(
			context.cost_context.size() == 1 and build._bank.view().sponsors.size() == 5,
			"one grouped journal operation retires both exact receipts"
		)
		check(context.ownership.events[-1].op == "buy", "group context owns original paid wallet")


func _double_major_current_abilities() -> void:
	var build: SeasonBuild = _funded()
	var sponsor: String = _buy_item(build, "F09")
	# Controlled learned-slot fixture, not claimed as a naturally stocked shop save.
	build._major.player = roster[0]
	build._abilities.learned[roster[0]] = [
		{"id": "fixture:hands", "item": SeasonAbilities.HANDS, "slot": "Fielding", "paid": 10},
		{"id": "fixture:sky", "item": SeasonAbilities.SKY, "slot": "Fielding", "paid": 12}
	]
	_start(build)
	_compare(build, 6, "Double Major before explicit forgetting")
	_sell(build, sponsor, 2, 1, {"major": {"player": "", "forget": "fixture:hands"}})
	check(
		build._abilities.ids(roster[0]) == [SeasonAbilities.SKY],
		"sale actually forgets selected Fielding ability"
	)
	var context: Dictionary = _compare(build, 6, "Double Major current-ability semantics")
	if not context.is_empty():
		check(
			(
				context.definitions[roster[0]].season_abilities == [SeasonAbilities.SKY]
				and (
					context.cost_context[0].definitions[roster[0]].season_abilities
					== [SeasonAbilities.SKY]
				)
			),
			"projection preserves old current abilities, never invents pre-sale ability history"
		)


func _bad_histories() -> void:
	var build: SeasonBuild = _funded()
	var first: String = _buy_item(build, "B03")
	var second: String = _buy_item(build, "B02")
	_start(build)
	_sell(build, first, 4, 3)
	_sell(build, second, 5, 4)
	_compare(build, 6, "negative fixture begins valid")
	for mode: String in [
		"sale-id",
		"bank-tail",
		"wrong-game",
		"development-tail",
		"decreasing-pa",
		"decreasing-boundary",
		"fractional-boundary",
		"missing-field",
		"bank-prefix-revision"
	]:
		var wrong: SeasonBuild = build._fork()
		match mode:
			"sale-id":
				wrong._bank._events[-1].id = "foreign-sale"
			"bank-tail":
				check(
					(
						wrong
						. _bank
						. commit(OwnershipFixtures.request(wrong._bank, "charge", {"amount": 0}))
						. ok
					),
					"controlled unexpected wallet suffix"
				)
			"wrong-game":
				wrong._events[-1].game = 7
			"development-tail":
				wrong._events.append({"id": "contamination", "rev": wrong.revision(), "op": "open"})
			"decreasing-pa":
				wrong._events[-1].field_state = {"pa": 3, "boundary": 3}
			"decreasing-boundary":
				wrong._events[-2].field_state = {"pa": 4, "boundary": 4}
				wrong._events[-1].field_state = {"pa": 4, "boundary": 3}
			"fractional-boundary":
				wrong._events[-1].field_state.boundary = 4.5
			"missing-field":
				wrong._events[-1].erase("field_state")
			"bank-prefix-revision":
				wrong._bank._events[0].rev = 1
		_compare(wrong, 6, "malformed " + mode, false)
	# Cash is a derived cache, not exported authority: both implementations replay
	# the exact wallet journal and ignore an unrelated corrupted cached balance.
	var cached: SeasonBuild = build._fork()
	cached._bank._state.cash += 1
	var cached_context: Dictionary = _compare(
		cached, 6, "derived cash cache is not history authority"
	)
	check(
		_exact(_canonical(cached_context), _canonical(SeasonDoubleheaderBuild.context(build, 6))),
		"cached cash mutation cannot change projected definitions, ownership or sale cutoffs"
	)
	var no_marker: SeasonBuild = _build()
	no_marker._match_inventory = {"game": 6}
	_compare(no_marker, 6, "inventory without journal attempt", false)
	var ai: SeasonBuild = build._fork()
	ai._market = 12
	_compare(ai, 6, "AI cannot inherit human sale attempt", false)
	var future: Dictionary = _reward(build, 6)
	_validate_both(build, future, "future sale beyond completed PA rejects identically", false)


func _output_isolation() -> void:
	var build: SeasonBuild = _funded()
	var gear: String = _buy_item(build, "D02")
	_buy_item(build, "B03")
	_start(build)
	_sell(build, gear, 2, 1)
	var before: Dictionary = _input_snapshot(build)
	var first: Dictionary = SeasonDoubleheaderBuild.context(build, 6)
	var second: Dictionary = SeasonDoubleheaderBuild.context(build, 6)
	check(not first.is_empty() and not second.is_empty(), "two independent output projections")
	if first.is_empty() or second.is_empty():
		return
	var expected: Dictionary = _canonical(second).duplicate(true)
	var initial: PlayerDefinition = first.definitions[roster[0]]
	var transition: PlayerDefinition = first.cost_context[0].definitions[roster[0]]
	var transition_before: Variant = _serialized(transition)
	initial.contact = 99
	initial.season_abilities.append("fixture:mutated")
	initial.season_gear["misc"] = "fixture:mutated"
	initial.season_sponsors["B03"] = false
	initial.starting_pitches[0].stamina_cost = 999.0
	initial.starting_pitches[0].mastery_level = 99
	check(
		_exact(transition, transition_before),
		"initial mutable output cannot alter transition output"
	)
	transition.power = 99
	transition.season_sponsors.clear()
	transition.starting_pitches[0].stamina_cost = 888.0
	first.roster.reverse()
	first.ownership.events[0].id = "fixture:mutated"
	first.ownership.events.append({"op": "fixture:mutated"})
	first.cost_context[0].after = 99999
	first.cost_context.append({"after": 99999, "definitions": {}})
	first.definitions.erase(roster[1])
	check(
		_exact(_input_snapshot(build), before),
		"output mutations leave Build/book/bank/catalog unchanged"
	)
	check(
		_exact(_canonical(second), expected),
		"output mutations leave earlier independent projection unchanged"
	)
	check(
		_exact(_canonical(SeasonDoubleheaderBuild.context(build, 6)), expected),
		"output mutations leave future projection unchanged"
	)


func _retained_sample(build: SeasonBuild, old: bool) -> Dictionary:
	var before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var context: Dictionary = (
		OldContext.context(build, 3) if old else SeasonDoubleheaderBuild.context(build, 3)
	)
	var retained: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var valid: bool = not context.is_empty()
	context = {}
	var released: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	return {
		"old": old,
		"valid": valid,
		"retained_delta": retained - before,
		"after_release_delta": released - before
	}


func _allocation_diagnostic() -> void:
	# One deterministic, validator-accepted synthetic workload creates substantial
	# genuine Build history. No full season, performance threshold or leak claim.
	var build: SeasonBuild = _build()
	var command: Dictionary = _reward(build, 0, 0, 128)
	check(build.commit(command).ok, "allocation sample has validated 128-release Build history")
	_compare(build, 3, "allocation sample exact semantics")
	# Warm both paths, then report alternating retained and post-release deltas.
	_retained_sample(build, true)
	_retained_sample(build, false)
	var samples: Array = []
	for index in range(3):
		samples.append(_retained_sample(build, true))
		samples.append(_retained_sample(build, false))
	print(
		"DOUBLEHEADER_PROJECTION_MEMORY ",
		JSON.stringify(
			{"release_events": 128, "samples": samples, "diagnostic_only": true}, "", true, true
		)
	)
