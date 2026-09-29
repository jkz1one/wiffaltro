extends "res://src/tests/season_sponsor_test.gd"
## Controlled offer fixtures test atomic contracts; actual generated paid saves/UI are separate.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_pair_contracts()
	_discount_contracts()
	_student_contracts()
	_season_end_contracts()
	_migration()
	await _discount_ui()
	await _actual_ui("F04")
	await _actual_ui("J10")
	await _sponsor_ui({"E06": SeasonSponsorCatalog.SCHOOL_ITEMS.E06})
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro school sponsor checks passed: paired lessons, earned credit, scholarships and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _unit_build(ids: Array) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(112, ROSTER)
	for game in range(5):
		build.commit(_command(build, "reward", {"game": game, "win": true}))
	build.commit(_command(build, "open"))
	for id: String in ids:
		build._visit.offers = {"sponsor": id}
		var extra: Dictionary = {"offer": "sponsor", "replace": ""}
		if id == "J10":
			extra["student"] = ROSTER[0]
		_check(
			build.commit(_command(build, "sponsor_buy", extra)).ok,
			"controlled paid sponsor fixture"
		)
	return build


func _unit_offer(build: SeasonBuild, id: String) -> String:
	var offer: String = "fixture:%d" % build.revision()
	build._visit.offers[offer] = id
	return offer


func _buy_card(
	build: SeasonBuild, id: String, player: String, concession: String = ""
) -> Dictionary:
	var extra: Dictionary = {
		"offer": _unit_offer(build, id), "mode": "use", "player": player, "pitch": "", "replace": ""
	}
	if not concession.is_empty():
		extra["concession"] = concession
	return _command(build, "buy", extra)


func _hit_stats(roster: Array, count: int) -> Dictionary:
	var stats: MatchPerformance = MatchPerformance.new()
	for index in range(count):
		stats.complete(StringName(roster[index]), &"rival.pitcher", "single", 0)
	return stats.players


func _pair_contracts() -> void:
	var build: SeasonBuild = _unit_build(["F04"])
	var id: String = "lesson.pitch.knuckleball"
	var targets: Array[Dictionary] = build.targets(id)
	var first: Dictionary = targets[0]
	var second: Dictionary = {}
	for target: Dictionary in targets:
		if target.player != first.player:
			second = target
			break
	var request: Dictionary = _command(
		build, "lesson_pair", {"offer": _unit_offer(build, id), "first": first, "second": second}
	)
	var before: Dictionary = build.to_data()
	var cash_before: int = build.cash()
	var poor: SeasonBuild = build._fork()
	_check(poor._charge(poor.cash() - 20).is_empty(), "controlled below-pair-price wallet")
	var poor_before: Dictionary = poor.view()
	_check(
		not poor.commit(request).ok and poor.view() == poor_before,
		"insufficient combined price rolls back both learners and offer"
	)
	var bad: Dictionary = request.duplicate(true)
	bad.second = first
	_check(
		not build.commit(bad).ok and build.to_data() == before, "same recipient rejected atomically"
	)
	bad = request.duplicate(true)
	bad.second.replace = "missing.recipe"
	_check(
		not build.commit(bad).ok and build.to_data() == before,
		"invalid second replacement rolls back first learning"
	)
	_check(build.preview(request).ok and build.to_data() == before, "paired preview is nonmutating")
	_check(
		build.commit(request).ok and build.cash() == cash_before - 21,
		"Rare14 lesson teaches two for21"
	)
	_check(
		(
			build.player(first.player).active.has("pitch.knuckleball")
			and build.player(second.player).active.has("pitch.knuckleball")
		),
		"same exact recipe on distinct players"
	)
	_check(
		(
			build.player(first.player).mastery["pitch.knuckleball"] == 1
			and build.player(second.player).mastery["pitch.knuckleball"] == 1
		),
		"new recipes start at one"
	)
	_check(
		build.commit(request).replayed and build.cash() == cash_before - 21,
		"retry never pays or teaches twice"
	)
	_check(not SeasonSchoolSponsors.pair_available(build, "lesson.pitch.drop"), "once per visit")
	build.commit(_command(build, "reroll"))
	_check(
		not SeasonSchoolSponsors.pair_available(build, "lesson.pitch.drop"),
		"reroll cannot refresh paired use"
	)
	var tutor: Dictionary = SeasonSchoolSponsors.active(build, "F04")
	_check(build.commit(_command(build, "sponsor_sell", {"receipt": tutor.id})).ok, "sell tutor")
	_check(
		(
			build
			. commit(
				_command(build, "sponsor_buy", {"offer": _unit_offer(build, "F04"), "replace": ""})
			)
			. ok
		),
		"rebuy tutor in controlled stock"
	)
	_check(
		not SeasonSchoolSponsors.pair_available(build, "lesson.pitch.drop"),
		"sell and rebuy cannot refresh paired use"
	)
	_check(
		not SeasonSchoolSponsors.pair_available(build, "lesson.pitch.switchback"),
		"unsupported Exotic excluded"
	)
	_check(
		SeasonSchoolSponsors.pair_price(10) == 15 and SeasonSchoolSponsors.pair_price(11) == 17,
		"half-price rounding contract"
	)
	# Personal remembered mastery is distinct, including a forgotten recipient-specific recipe.
	build = _unit_build(["F04"])
	for index in range(2):
		var player: String = ROSTER[index]
		var book: SeasonDevelopment = build._book
		var original: String = book.player(player).active[0]
		book.commit(
			{
				"id": "learn:%d" % index,
				"rev": book.revision(),
				"op": "learn",
				"player": player,
				"target": "pitch.knuckleball",
				"replace": book.player(player).active[0]
			}
		)
		for level in range(index + 1):
			book.commit(
				{
					"id": "master:%d:%d" % [index, level],
					"rev": book.revision(),
					"op": "mastery",
					"player": player,
					"target": "pitch.knuckleball"
				}
			)
		book.commit(
			{
				"id": "forget:%d" % index,
				"rev": book.revision(),
				"op": "learn",
				"player": player,
				"target": original,
				"replace": "pitch.knuckleball"
			}
		)
	var selected: Array = []
	for player: String in ROSTER.slice(0, 2):
		for target: Dictionary in build.targets(id):
			if target.player == player:
				selected.append(target)
				break
	_check(selected.size() == 2, "both remembered recipients legal")
	if selected.size() == 2:
		_check(
			(
				build
				. commit(
					_command(
						build,
						"lesson_pair",
						{
							"offer": _unit_offer(build, id),
							"first": selected[0],
							"second": selected[1]
						}
					)
				)
				. ok
			),
			"paired relearning"
		)
		_check(
			(
				build.player(ROSTER[0]).mastery["pitch.knuckleball"] == 2
				and build.player(ROSTER[1]).mastery["pitch.knuckleball"] == 3
			),
			"own remembered levels, never donor copying"
		)


func _discount_contracts() -> void:
	var build: SeasonBuild = _unit_build(["E06", "J10"])
	_check(
		not SeasonSchoolSponsors.qualifies_union(build, _hit_stats(ROSTER, 2)),
		"two hitters insufficient"
	)
	_check(
		SeasonSchoolSponsors.qualifies_union(build, _hit_stats(ROSTER, 3)),
		"three distinct hitters qualify"
	)
	var repeat: Dictionary = _hit_stats(ROSTER, 1)
	repeat[ROSTER[0]].h = 10
	_check(
		not SeasonSchoolSponsors.qualifies_union(build, repeat),
		"one star cannot substitute for three contributors"
	)
	build._visit["union_credit"] = 3
	var request: Dictionary = _buy_card(build, "development.contact", ROSTER[0])
	var before: Dictionary = build.to_data()
	_check(
		not build.commit(request).ok and build.to_data() == before,
		"explicit choice required when both qualify"
	)
	request["concession"] = "scholarship"
	var cash_before: int = build.cash()
	_check(build.commit(request).ok and build.cash() == cash_before - 2, "student card6 costs2")
	_check(
		build.view().shop.union_credit == 3 and SeasonSchoolSponsors.scholarship(build).uses == 2,
		"scholarship leaves Union credit intact"
	)
	request = _buy_card(build, "development.power", ROSTER[0], "union")
	cash_before = build.cash()
	_check(
		build.commit(request).ok and build.cash() == cash_before - 3,
		"Union card6 costs3, no stacking"
	)
	_check(
		build.view().shop.union_credit == 0 and SeasonSchoolSponsors.scholarship(build).uses == 2,
		"Union leaves scholarship allowance intact"
	)
	build._visit["union_credit"] = 3
	request = _command(
		build,
		"buy",
		{
			"offer": _unit_offer(build, "development.mastery"),
			"mode": "hold",
			"player": "",
			"pitch": "",
			"replace": ""
		}
	)
	cash_before = build.cash()
	_check(
		build.commit(request).ok and build.cash() == cash_before - 5, "held mastery acquired for5"
	)
	var held: Dictionary = build.view().wallet.held[0]
	_check(
		held.paid == 5 and build.view().shop.union_credit == 0,
		"discounted paid receipt, credit consumed at acquisition"
	)
	var target: Dictionary = build.targets(held.item)[0]
	target["receipt"] = held.id
	cash_before = build.cash()
	_check(
		build.commit(_command(build, "use", target)).ok and build.cash() == cash_before,
		"held use never discounts or refunds again"
	)
	build._visit["union_credit"] = 3
	cash_before = build.cash()
	_check(
		build.commit(_command(build, "pack_open")).ok and build.cash() == cash_before - 5,
		"Union pack8 costs5"
	)
	_check(
		build.commit(_command(build, "pack_skip")).ok and build.view().shop.union_credit == 0,
		"paid skipped pack consumes credit"
	)
	_check(
		SeasonSchoolSponsors.scholarship(build).uses == 2,
		"pack/mastery/holds do not spend scholarship"
	)
	build._visit["union_credit"] = 3
	var sponsor: Dictionary = SeasonSchoolSponsors.active(build, "E06")
	build.commit(_command(build, "sponsor_sell", {"receipt": sponsor.id}))
	_check(build.view().shop.union_credit == 3, "granted credit survives sponsor sale")
	build.commit(_command(build, "leave_shop"))
	_check(build.view().shop.union_credit == 0, "departure expires Union credit")


func _student_contracts() -> void:
	var build: SeasonBuild = _unit_build(["J10"])
	var receipt: Dictionary = SeasonSchoolSponsors.active(build, "J10")
	_check(SeasonSponsorCatalog.resale(receipt) == 0, "zero resale from purchase")
	for index in range(3):
		var before: int = build.cash()
		_check(
			(
				build.commit(_buy_card(build, "development.fielding", ROSTER[0])).ok
				and build.cash() == before - 2
			),
			"successful targeted purchase consumes one subsidy"
		)
	_check(
		(
			SeasonSchoolSponsors.active(build, "J10").is_empty()
			and build.view().scholarships.is_empty()
		),
		"third use retires exact sponsor without refund"
	)
	var before: int = build.cash()
	_check(
		(
			build.commit(_buy_card(build, "development.power", ROSTER[0])).ok
			and build.cash() == before - 6
		),
		"fourth purchase full price"
	)
	_check(
		not SeasonSchoolSponsors.eligible_student(build, ROSTER[0]),
		"trained student cannot reset by rebuy"
	)
	_check(
		SeasonSchoolSponsors.eligible_student(build, ROSTER[1]),
		"untouched baseline remains eligible"
	)
	build._book.commit(
		{
			"id": "catchup",
			"rev": build._book.revision(),
			"op": "recruit",
			"player": ROSTER[1],
			"target": "early"
		}
	)
	_check(
		not SeasonSchoolSponsors.eligible_student(build, ROSTER[1]),
		"generated catch-up excluded by Proposal"
	)
	build = _unit_build(["J10"])
	var student: Dictionary = SeasonSchoolSponsors.scholarship(build)
	# An unrelated earned step after nomination never invalidates the fixed student.
	var own_recipe: String = build.player(ROSTER[0]).active[0]
	_check(
		(
			build
			. _book
			. commit(
				{
					"id": "external-growth",
					"rev": build._book.revision(),
					"op": "mastery",
					"player": ROSTER[0],
					"target": own_recipe
				}
			)
			. ok
		),
		"ordinary mastery after nomination"
	)
	_check(
		SeasonSchoolSponsors.scholarship(build) == student,
		"later growth preserves student and allowance"
	)
	_check(
		build.commit(_buy_card(build, "development.power", ROSTER[0])).ok,
		"fixed student still receives broad-stat subsidy after mastery"
	)
	before = build.cash()
	receipt = SeasonSchoolSponsors.active(build, "J10")
	_check(
		build.commit(_command(build, "sponsor_sell", {"receipt": receipt.id})).ok,
		"manual scholarship sale"
	)
	_check(
		build.cash() == before and build.view().scholarships.is_empty(),
		"manual sale pays zero and removes instance progress"
	)
	build = _unit_build(["J10"])
	before = build.cash()
	_check(SeasonSchoolSponsors.departure(build, ROSTER[0]).is_empty(), "student departure retires")
	_check(
		build.cash() == before and SeasonSchoolSponsors.active(build, "J10").is_empty(),
		"retirement never grants Cash"
	)


func _actual_season(id: String, require_lesson: bool = false) -> SeasonState:
	for seed_value in range(3000):
		var season: SeasonState = _funded_season(seed_value, 3)
		var build: SeasonBuild = season.build
		if _offer(build, id).is_empty():
			continue
		if require_lesson:
			var found: bool = false
			for item: String in build.view().shop.offers.values():
				if DevelopmentShopCatalog.item(item).get("op") == "learn":
					found = true
			if not found:
				continue
		return season
	_check(false, "actual generated sponsor fixture reachable")
	return null


func _actual_ui(id: String) -> void:
	var prefix: String = "user://school-%s-%d" % [id, OS.get_process_id()]
	SeasonSave.path = prefix + ".json"
	PitchBatLabSettings.path = prefix + ".cfg"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _actual_season(id, id == "F04")
	_check(app._checkpoint(), "save actual offered sponsor")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _click(_sponsor_button(window, _offer(app.season.build, id)))
	if id == "J10":
		await _click(_metadata_button(window, "student"))
	_check(
		window._review_text.text.contains(SeasonSponsorCatalog.item(id).effect),
		"full contract disclosed"
	)
	await _shop_bounds(window, "school-" + id)
	await _click(window._confirm.get_ok_button())
	_check(SeasonSave.restore() != null, "paid nomination/sponsor replays")
	if id == "F04":
		await _click(_metadata_button(window, "pair_offer"))
		await _click(_metadata_button(window, "pair_first"))
		await _click(_metadata_button(window, "pair_second"))
		_check(
			window._review_text.text.contains("learned level"),
			"both resulting mastery levels disclosed"
		)
		var before: Dictionary = app.season.build.to_data()
		await _click(window._confirm.get_cancel_button())
		_check(app.season.build.to_data() == before, "cancel changes no learning or Cash")
		window._refresh()
		await _frames()
		await _click(_metadata_button(window, "pair_offer"))
		await _click(_metadata_button(window, "pair_first"))
		await _click(_metadata_button(window, "pair_second"))
		var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
		SeasonSave.path = prefix + "/missing/save.json"
		await _click(window._confirm.get_ok_button())
		_check(
			app.season.build.to_data() == before,
			"failed pair save rolls back both recipients and cost"
		)
		SeasonSave.path = prefix + ".json"
		_check(
			FileAccess.get_file_as_string(SeasonSave.path) == bytes, "previous save bytes preserved"
		)
		await _click(_metadata_button(window, "pair_offer"))
		await _click(_metadata_button(window, "pair_first"))
		await _click(_metadata_button(window, "pair_second"))
		await _click(window._confirm.get_ok_button())
		_check(
			app.season.build.view().shop.pair_used and SeasonSave.restore() != null,
			"paid paired result/flag survives replay"
		)
	await _click(window._back)
	app.queue_free()
	await _frames()
	for suffix: String in [".json", ".json.bak", ".json.tmp", ".cfg"]:
		DirAccess.remove_absolute(prefix + suffix)


func _metadata_button(window: SeasonShopWindow, key: String) -> Button:
	for child: Node in window._body.get_children():
		if child is Button and child.has_meta(key):
			return child
	return null


func _union_season() -> SeasonState:
	for seed_value in range(3000):
		var season: SeasonState = _funded_season(seed_value, 3)
		if (
			not _offer(season.build, "E06").is_empty()
			and not _offer(season.build, "J10").is_empty()
		):
			for id: String in ["E06", "J10"]:
				var extra: Dictionary = {"offer": _offer(season.build, id), "replace": ""}
				if id == "J10":
					extra["student"] = season.build.roster()[0]
				_check(
					season.build.commit(_command(season.build, "sponsor_buy", extra)).ok,
					"actual generated paid school sponsors"
				)
			return season
	_check(false, "actual Union/Scholarship combination reachable")
	return null


func _earn_union(season: SeasonState, open_shop: bool = true) -> void:
	var state: MatchState = season.make_match()
	var game: Dictionary = season.pending_fixture()
	state.top_half = game.away == 0
	for hitter in range(3):
		state.record_hit(BallPlayOutcome.Result.SINGLE)
	_check(
		season.record_player_result(
			game.id,
			1 if game.away == 0 else 0,
			1 if game.home == 0 else 0,
			state.performance.snapshot(state)
		),
		"three credited hitter result settles"
	)
	_check(
		season.build.view().shop.get("union_credit", 0) == 0,
		"pending trigger is not spendable before next shop"
	)
	if not open_shop:
		return
	_check(
		(
			season.build.commit(_command(season.build, "open")).ok
			and season.build.view().shop.union_credit == 3
		),
		"next eligible shop grants one actual credit"
	)


func _season_end_contracts() -> void:
	var season: SeasonState = _union_season()
	var playoff_credit: bool = false
	while season.phase != SeasonState.Phase.COMPLETE:
		_earn_union(season, false)
		if season.shop_available():
			_check(season.build.commit(_command(season.build, "open")).ok, "eligible shop opens")
			_check(
				season.build.view().shop.get("union_credit", 0) == 3,
				"new qualifying game grants exactly three, never banks or stacks"
			)
			if season.phase == SeasonState.Phase.FINAL:
				playoff_credit = true
	_check(playoff_credit, "semifinal contributors receive credit in the playoff shop")
	_check(
		not season.shop_available() and season.build.view().shop.get("union_credit", 0) == 0,
		"final contributors create no usable credit or extra shop"
	)
	_check(SeasonSave._build_history_valid(season, season.build), "completed history valid")
	var forbidden: SeasonBuild = season.build.candidate(_command(season.build, "open"))
	_check(
		forbidden != null and not SeasonSave._build_history_valid(season, forbidden),
		"post-final shop injection rejected by season history validation"
	)


func _discount_ui() -> void:
	var prefix: String = "user://school-discount-%d" % OS.get_process_id()
	SeasonSave.path = prefix + ".json"
	PitchBatLabSettings.path = prefix + ".cfg"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _union_season()
	_earn_union(app.season)
	var build: SeasonBuild = app.season.build
	var card: String = ""
	for attempt in range(5):
		for id: String in build.view().shop.offers.values():
			if DevelopmentShopCatalog.item(id).get("op") == "stat":
				card = id
				break
		if not card.is_empty():
			break
		_check(build.commit(_command(build, "reroll")).ok, "actual reroll preserves Union credit")
	_check(
		not card.is_empty() and build.view().shop.union_credit == 3, "actual eligible stock found"
	)
	_check(app._checkpoint(), "save earned credit and fixed student")
	_check(SeasonSave.restore().build.view() == build.view(), "credit/student provenance replays")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _click(_offer_button(window, _offer(build, card)))
	var target_button: Button
	for child: Node in window._body.get_children():
		if (
			child is Button
			and child.has_meta("target")
			and child.get_meta("target").player == build.roster()[0]
		):
			target_button = child
			break
	await _click(target_button)
	_check(
		_metadata_button(window, "concession") != null,
		"both applicable subsidies require visible choice"
	)
	await _shop_bounds(window, "school-concession")
	var chosen: Button
	for child: Node in window._body.get_children():
		if child is Button and child.get_meta("concession", "") == "scholarship":
			chosen = child
	await _click(chosen)
	_check(
		(
			window._review_text.text.contains("pay 2 Cash")
			and window._review_text.text.contains("remaining: 3 → 2")
		),
		"exact price and remaining use preview"
	)
	var before: Dictionary = build.to_data()
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = prefix + "/missing/save.json"
	await _click(window._confirm.get_ok_button())
	_check(
		app.season.build.to_data() == before,
		"failed discounted save rolls back growth, cash and use"
	)
	SeasonSave.path = prefix + ".json"
	_check(
		FileAccess.get_file_as_string(SeasonSave.path) == bytes,
		"discount failure preserves old save"
	)
	var target: Dictionary = {
		"offer": _offer(app.season.build, card),
		"mode": "use",
		"player": build.roster()[0],
		"pitch": "",
		"replace": "",
		"concession": "scholarship"
	}
	window._preview(window._request("buy", target), "Reviewed fixed student • pay 2 Cash")
	await _click(window._confirm.get_ok_button())
	_check(
		(
			SeasonSchoolSponsors.scholarship(app.season.build).uses == 2
			and app.season.build.view().shop.union_credit == 3
		),
		"successful choice preserves other credit"
	)
	_check(SeasonSave.restore() != null, "discounted growth saves and replays")
	await _click(window._back)
	_check(
		SeasonSave.restore().build.view().shop.union_credit == 0,
		"Back durably expires leftover Union credit"
	)
	app.queue_free()
	await _frames()
	for suffix: String in [".json", ".json.bak", ".json.tmp", ".cfg"]:
		DirAccess.remove_absolute(prefix + suffix)


func _migration() -> void:
	SeasonSave.path = "user://school-migrate-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(_seed_for("F05", 10), false, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 10
	_record(season)
	season.build.commit(_command(season.build, "open"))
	_check(
		(
			season
			. build
			. commit(
				_command(
					season.build,
					"sponsor_buy",
					{"offer": _offer(season.build, "F05"), "replace": ""}
				)
			)
			. ok
		),
		"actual paid schema14 sponsor"
	)
	var before: Dictionary = season.build.view()
	_check(SeasonSave.save(season), "save old stock and paid ownership")
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == before, "old visit remains exact")
	_check(
		(
			restored.build.to_data().school_sponsor_from == 2
			and FileAccess.get_file_as_string(SeasonSave.path) == bytes
		),
		"next-visit migration without load rewrite"
	)
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		restored.build.view().shop.offers == season.build.view().shop.offers,
		"old same-visit generator frozen"
	)
	_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "migrated visit replays")
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(
		SeasonSave.save(restored) and SeasonSave.restore() != null, "expanded next visit replays"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
