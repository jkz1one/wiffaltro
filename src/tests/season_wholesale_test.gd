extends "res://src/tests/season_school_test.gd"
## Controlled stock covers boundaries; paid generated seasons cover UI/replay/runtime.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_gear_pairs()
	_other_pairs()
	_migration()
	await _sponsor_ui(SeasonSponsorCatalog.WHOLESALE_ITEMS)
	for kind: String in ["gear", "gear-replacement", "sponsor", "lesson"]:
		await _pair_ui(kind)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro wholesale checks passed: atomic pairs, receipts, migration and actual UI.")
	get_tree().quit(0 if _failures == 0 else 1)


func _pair(build: SeasonBuild, a: String, b: String) -> Dictionary:
	var first: String = _unit_offer(build, a)
	var second: String = first + ":second"
	build._visit.offers[second] = b
	return _command(
		build,
		"wholesale",
		{
			"first": SeasonWholesale.targets(build, first)[0],
			"second": SeasonWholesale.targets(build, second)[0],
			"discounted":
			first if SeasonWholesale.item(a).price <= SeasonWholesale.item(b).price else second
		}
	)


func _gear_pairs() -> void:
	var build: SeasonBuild = _unit_build(["J02", "F05"])
	var request: Dictionary = _pair(build, "BAT-CON-01", "BALL-HYB-01")
	var before: Dictionary = build.view()
	var invalid: Dictionary = request.duplicate(true)
	invalid.discounted = request.second.offer
	_check(not build.commit(invalid).ok and build.view() == before, "cannot discount dearer item")
	invalid = request.duplicate(true)
	invalid.second.replace = "foreign-receipt"
	_check(not build.commit(invalid).ok and build.view() == before, "invalid second target atomic")
	_check(build.preview(request).ok and build.view() == before, "pair preview does not mutate")
	_check(build.commit(request).ok and build.cash() == before.wallet.cash - 20, "10+12 costs20")
	var gear: Dictionary = build.view().wallet.gear
	_check(gear.bat.paid == 8 and gear.ball.paid == 12, "discount attached to exact receipt")
	_check(build.commit(request).replayed and build.cash() == before.wallet.cash - 20, "retry once")
	_check(not SeasonWholesale.available(build), "once per visit")
	build.commit(_command(build, "reroll"))
	var sponsor: Dictionary = SeasonSchoolSponsors.active(build, "J02")
	build.commit(_command(build, "sponsor_sell", {"receipt": sponsor.id}))
	build.commit(
		_command(build, "sponsor_buy", {"offer": _unit_offer(build, "J02"), "replace": ""})
	)
	_check(not SeasonWholesale.available(build), "reroll and sell/rebuy do not renew use")
	var cash_before: int = build.cash()
	build.commit(_command(build, "sell_gear", {"receipt": gear.bat.id}))
	_check(build.cash() == cash_before + 4, "later resale uses discounted8, returns4")
	build = _unit_build(["J02", "F05"])
	for id: String in ["BAT-CON-01", "BALL-MOV-01"]:
		_check(
			(
				build
				. commit(_command(build, "equip", {"offer": _unit_offer(build, id), "replace": ""}))
				. ok
			),
			"controlled old paid Gear"
		)
	gear = build.view().wallet.gear
	build._used_gear[gear.bat.id] = true
	build._used_gear[gear.ball.id] = true
	build._charge(build.cash() - 8)
	request = _pair(build, "BAT-POW-01", "BALL-VEL-01")
	before = build.view()
	var poor: SeasonBuild = build._fork()
	poor._bank._state.cash = 7
	var poor_before: Dictionary = poor.view()
	_check(
		not poor.commit(request).ok and poor.view() == poor_before,
		"insufficient combined funds rolls back sales, purchases and Reclamation"
	)
	_check(
		build.commit(request).ok and build.cash() == 0,
		"both old5-Cash sales finance18-Cash pair from wallet8"
	)
	_check(
		build.view().shop.reroll_credit == 2 and build.view().used_gear.is_empty(),
		"two qualified replacements award one separate credit; new receipts inherit no use"
	)
	build = _unit_build(["J02"])
	request = _pair(build, "BAT-CON-01", "BAT-POW-01")
	before = build.view()
	_check(
		not build.commit(request).ok and build.view() == before, "two Bats never create reserves"
	)
	request = _pair(build, "BAT-CON-01", "BALL-MOV-01")
	request.discounted = request.second.offer
	_check(
		build.commit(request).ok and build.view().wallet.gear.ball.paid == 8,
		"equal-price player selection discounts second receipt"
	)
	_check(
		SeasonWholesale.reduction(11) == 2 and SeasonWholesale.reduction(20) == 4,
		"quarter rounding and max4"
	)


func _other_pairs() -> void:
	var build: SeasonBuild = _unit_build(["J02", "E06", "J10"])
	build._visit["union_credit"] = 3
	_check(
		SeasonWholesale.targets(build, _unit_offer(build, "development.power")).is_empty(),
		"development and its concessions excluded"
	)
	var request: Dictionary = _pair(build, "F04", "F01")
	var before: int = build.cash()
	_check(
		build.commit(request).ok and build.cash() == before - 18, "two sponsor slots paid together"
	)
	_check(
		build.view().shop.union_credit == 3 and SeasonSchoolSponsors.scholarship(build).uses == 3,
		"Union and Summer allowances untouched"
	)
	build = _unit_build(["J02", "F01", "F02", "F03"])
	request = _pair(build, "F04", "E06")
	var snapshot: Dictionary = build.view()
	_check(
		not build.commit(request).ok and build.view() == snapshot, "two additions exceed capacity"
	)
	request.second.replace = SeasonSchoolSponsors.active(build, "F02").id
	_check(
		build.commit(request).ok and build.view().wallet.sponsors.size() == 5,
		"explicit existing replacement resolves combined capacity"
	)
	build = _unit_build(["J02"])
	request = _pair(build, "J10", "F04")
	_check(
		build.commit(request).ok and SeasonSchoolSponsors.scholarship(build).uses == 3,
		"discounted Summer receipt owns fixed student"
	)
	var student: Dictionary = SeasonSchoolSponsors.active(build, "J10")
	_check(
		student.paid == 5 and SeasonSponsorCatalog.resale(student) == 0,
		"Summer retains zero resale despite discount"
	)
	build = _unit_build(["J02"])
	request = _pair(build, "lesson.pitch.knuckleball", "lesson.pitch.drop")
	var a: String = build._visit.offers[request.first.offer]
	var b: String = build._visit.offers[request.second.offer]
	# Use separate learners so both ordinary targets stay valid through the pair.
	for target: Dictionary in SeasonWholesale.targets(build, request.second.offer):
		if target.player != request.first.player:
			request.second = target
			break
	before = build.cash()
	var cost: int = SeasonWholesale.item(a).price + SeasonWholesale.item(b).price
	cost -= SeasonWholesale.reduction(
		mini(SeasonWholesale.item(a).price, SeasonWholesale.item(b).price)
	)
	_check(build.commit(request).ok and build.cash() == before - cost, "two lessons charge once")
	_check(
		(
			build.player(request.first.player).active.has(DevelopmentShopCatalog.item(a).recipe)
			and build.player(request.second.player).active.has(
				DevelopmentShopCatalog.item(b).recipe
			)
		),
		"both exact lessons learned"
	)


func _generated_pair(build: SeasonBuild, kind: String) -> Dictionary:
	var stock: Dictionary = build.view().shop.offers
	for first: String in stock:
		if SeasonWholesale.category(stock[first]) != kind or stock[first] == "J02":
			continue
		for second: String in stock:
			if (
				first == second
				or SeasonWholesale.category(stock[second]) != kind
				or stock[second] == "J02"
			):
				continue
			for a: Dictionary in SeasonWholesale.targets(build, first):
				for b: Dictionary in SeasonWholesale.targets(build, second):
					var chosen: String = (
						first
						if (
							SeasonWholesale.item(stock[first]).price
							<= (SeasonWholesale.item(stock[second]).price)
						)
						else second
					)
					var request: Dictionary = _command(
						build, "wholesale", {"first": a, "second": b, "discounted": chosen}
					)
					if build.preview(request).ok:
						return request
	return {}


func _paid_wholesale(kind: String, replace_gear: bool = false) -> SeasonState:
	var probe: SeasonBuild = _unit_build(["J02"])
	probe._visit.number = 3
	# Probe ordinary unowned stock; actual returned fixtures use full paid journals.
	probe._bank._state.sponsors = []
	for seed_value in range(10000):
		probe._seed = seed_value
		probe._visit.offers = probe._offers(0)
		if _offer(probe, "J02").is_empty():
			continue
		var count: int = 0
		for id: String in probe._visit.offers.values():
			if id != "J02" and SeasonWholesale.category(id) == kind:
				count += 1
		if count < 2:
			continue
		var season: SeasonState = _funded_season(seed_value, 3)
		var offer: String = _offer(season.build, "J02")
		if offer.is_empty():
			continue
		if not (
			season
			. build
			. commit(_command(season.build, "sponsor_buy", {"offer": offer, "replace": ""}))
			. ok
		):
			continue
		var pair: Dictionary = _generated_pair(season.build, kind)
		if pair.is_empty():
			continue
		if replace_gear:
			for target: Dictionary in [pair.first, pair.second]:
				season.build.commit(_command(season.build, "equip", target))
			if not season.build.commit(_command(season.build, "reroll")).ok:
				continue
			pair = _generated_pair(season.build, kind)
			if (
				pair.is_empty()
				or (pair.first.replace.is_empty() and pair.second.replace.is_empty())
			):
				continue
		return season
	_check(false, "actual paid Wholesale pair reachable: " + kind)
	return null


func _drive_pair(window: SeasonShopWindow, request: Dictionary) -> void:
	await _click(_button(window._body, "WHOLESALE • BUY TWO"))
	for target: Dictionary in [request.first, request.second]:
		await _click(_meta_exact(window, "wholesale_offer", target.offer))
		await _click(_meta_exact(window, "wholesale_target", target))
	var discount: Button = _meta_exact(window, "wholesale_discount", request.discounted)
	if discount != null:
		await _click(discount)


func _meta_exact(window: SeasonShopWindow, key: String, value: Variant) -> Button:
	for child: Node in window._body.find_children("*", "Control", true, false):
		if child is Button and child.has_meta(key) and child.get_meta(key) == value:
			return child
	return null


func _pair_ui(kind: String) -> void:
	var prefix: String = "user://wholesale-%s-%d" % [kind, OS.get_process_id()]
	SeasonSave.path = prefix + ".json"
	PitchBatLabSettings.path = prefix + ".cfg"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	var category: String = "gear" if kind == "gear-replacement" else kind
	app.season = _paid_wholesale(category, kind == "gear-replacement")
	if app.season == null:
		app.queue_free()
		return
	_check(app._checkpoint(), "save generated paid Wholesale")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	var request: Dictionary = _generated_pair(app.season.build, category)
	var before: Dictionary = app.season.build.view()
	await _drive_pair(window, request)
	_check(
		window._confirm.visible and window._review_text.text.contains("discount"),
		"pair review visible"
	)
	if kind == "gear-replacement":
		_check(
			window._review_text.text.contains("sell "), "old paid replacement proceeds disclosed"
		)
	await _shop_bounds(window, "wholesale-" + kind)
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.view() == before, "cancel pair unchanged")
	window._refresh()
	await _frames()
	await _drive_pair(window, request)
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = prefix + "/missing/save.json"
	await _click(window._confirm.get_ok_button())
	_check(app.season.build.view() == before, "failed save rolls back entire pair")
	SeasonSave.path = prefix + ".json"
	_check(
		FileAccess.get_file_as_string(SeasonSave.path) == bytes, "old paid bytes survive failure"
	)
	window._refresh()
	await _frames()
	await _drive_pair(window, request)
	await _click(window._confirm.get_ok_button())
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == app.season.build.view(),
		"pair replays exactly"
	)
	_check(app.season.build.view().shop.get("wholesale_used", false), "saved once-visit flag")
	window.size = Vector2i(1000, 650)
	await _shop_bounds(window, "wholesale-complete-" + kind)
	app.queue_free()
	await _frames()
	for suffix: String in ["", ".bak", ".tmp", ".cfg"]:
		DirAccess.remove_absolute(prefix + ("" if suffix == ".cfg" else ".json") + suffix)


func _migration() -> void:
	SeasonSave.path = "user://wholesale-migrate-%d.json" % OS.get_process_id()
	var season: SeasonState = SeasonState.create(_seed_for("F01", 12), false, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	season.build._format = 12
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
					{"offer": _offer(season.build, "F01"), "replace": ""}
				)
			)
			. ok
		),
		"actual paid schema16"
	)
	var before: Dictionary = season.build.view()
	_check(SeasonSave.save(season), "save old paid shop")
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == before, "old paid stock exact")
	_check(
		(
			restored.build.to_data().wholesale_from == 2
			and FileAccess.get_file_as_string(SeasonSave.path) == bytes
		),
		"next-visit gate without rewriting old save"
	)
	season.build.commit(_command(season.build, "reroll"))
	restored.build.commit(_command(restored.build, "reroll"))
	_check(
		restored.build.view().shop.offers == season.build.view().shop.offers, "old reroll frozen"
	)
	_record(restored)
	restored.build.commit(_command(restored.build, "open"))
	_check(
		SeasonSponsorCatalog.catalog(restored.build._sponsor_catalog_version()).has("J02"),
		"next visit activates catalogue8"
	)
	_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "migration replays")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
