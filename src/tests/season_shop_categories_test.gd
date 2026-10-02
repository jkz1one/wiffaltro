extends "res://src/tests/season_raincheck_test.gd"

var _rain_source: Dictionary = {}
var _focus_source: Dictionary = {}


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://shop-categories-%d.json" % OS.get_process_id()
	_focus_contract()
	_reservation_contracts()
	_legacy_categories()
	await _categories_ui()
	await _reserved_ui(false)
	await _reserved_ui(true)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro shop category checks passed: paid focus, carry, capacity, discounts and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _saved(season: SeasonState) -> Dictionary:
	_check(SeasonSave.save(season), "save real generated purchases and career")
	return JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))


func _focus_fixture() -> SeasonState:
	if _focus_source.is_empty():
		var season: SeasonState = _order_fixture()
		_record(season)
		_check(season.build.commit(_command(season.build, "open")).ok, "fund next focus visit")
		_focus_source = _saved(season)
	return SeasonSave._decode(_focus_source)


func _focus_contract() -> void:
	var season: SeasonState = _focus_fixture()
	var build: SeasonBuild = season.build
	var pool: Dictionary = SeasonSpecialOrder.pool(build, "ability")
	_check(
		pool == {SeasonAbilities.COUNT: 1.0, SeasonAbilities.HANDS: 2.0},
		"ordinary eligibility and rarity weights; Sky stays earned-only"
	)
	var before: Dictionary = build.view()
	var fixed_pack: Array = build._visit.cards.duplicate()
	var recruits: Array = build._recruits.duplicate(true)
	var command: Dictionary = _command(build, "focused_reroll", {"category": "ability"})
	_check(build.preview(command).ok and build.view() == before, "focus preview is inert")
	_check(build.commit(command).ok, "pay focused learned-category reroll")
	_check(
		(
			build.cash() == before.wallet.cash - 4
			and build._visit.offers.size() == 2
			and build._visit.unavailable_slots == 2
		),
		"two distinct abilities, two unavailable slots"
	)
	_check(
		build._visit.cards == fixed_pack and build._recruits == recruits,
		"pack and recruiting remain fixed"
	)
	_check(build.commit(command).replayed, "focus retry never pays again")
	_check(
		not build.commit(_command(build, "focused_reroll", {"category": "ability"})).ok,
		"second focused use unavailable"
	)
	var player: String = build.roster()[0]
	var buy: Dictionary = _ability_buy(build, SeasonAbilities.COUNT, player)
	_check(build.commit(buy).ok, "buy and assign actual focused ability")
	var loaded: SeasonState = SeasonSave._decode(_saved(season))
	_check(
		loaded.build._abilities.ids(player).has(SeasonAbilities.COUNT),
		"focused purchase replays exact owner"
	)
	var rival: SeasonBuild = build._fork()
	rival._market = 1
	_check(SeasonSpecialOrder.pool(rival, "ability").is_empty(), "AI market remains gated")
	var sky: SeasonBuild = build._fork()
	sky._abilities.start = 3
	_check(
		SeasonSpecialOrder.pool(sky, "ability").has(SeasonAbilities.SKY),
		"earned Sky enters same category without replacing current stock"
	)
	for id: String in sky.roster():
		sky._abilities.learned[id] = []
		for item: String in SeasonAbilities.ITEMS:
			sky._abilities.learned[id].append(
				{"item": item, "slot": SeasonAbilities.ITEMS[item].slot}
			)
	_check(
		SeasonSpecialOrder.pool(sky, "ability").is_empty(),
		"no duplicate learning when every current player already knows the category"
	)


func _ability_buy(build: SeasonBuild, item: String, player: String) -> Dictionary:
	var target: Dictionary = {}
	for candidate: Dictionary in build._abilities.targets(build, item):
		if candidate.player == player:
			target = candidate.duplicate()
			break
	target["offer"] = _offer(build, item)
	return _command(build, "ability_buy", target)


func _reservation_fixture(ability: bool) -> SeasonState:
	if _rain_source.is_empty():
		_rain_source = _saved(_rain_fixture())
	var season: SeasonState = SeasonSave._decode(_rain_source)
	for visit in range(4):
		var build: SeasonBuild = season.build
		for attempt in range(3):
			for item: String in build._visit.offers.values():
				if (
					SeasonAbilities.ITEMS.has(item)
					if ability
					else DevelopmentShopCatalog.item(item).get("op") == "stat"
				):
					return season
			if build.cash() >= SeasonReclamation.price(build._visit) + 12:
				_check(build.commit(_command(build, "reroll")).ok, "pay search reroll")
			else:
				break
		_record(season)
		_check(build.commit(_command(build, "open")).ok, "next actual scheduled search")
	_check(false, "real reservable ability/development offer")
	return null


func _selected(build: SeasonBuild, ability: bool) -> String:
	for item: String in build._visit.offers.values():
		if (
			SeasonAbilities.ITEMS.has(item)
			if ability
			else DevelopmentShopCatalog.item(item).get("op") == "stat"
		):
			return item
	return ""


func _carry(season: SeasonState, item: String) -> SeasonState:
	var build: SeasonBuild = season.build
	var before: Dictionary = build.view()
	var reserve: Dictionary = _command(build, "reserve_offer", {"offer": _offer(build, item)})
	_check(build.preview(reserve).ok and build.view() == before, "reservation preview pure")
	_check(
		build.commit(reserve).ok and build.cash() == before.wallet.cash,
		"reserve unpurchased offer without price or ownership"
	)
	season = SeasonSave._decode(_saved(season))
	_record(season)
	_check(season.build.commit(_command(season.build, "open")).ok, "generate next destination")
	_check(
		(
			SeasonRaincheck.protected_offer(season.build).values() == [item]
			and season.build._visit.offers.size() == 4
		),
		"carry occupies one of four slots"
	)
	return SeasonSave._decode(_saved(season))


func _development_buy(build: SeasonBuild, item: String, hold: bool = false) -> Dictionary:
	var target: Dictionary = {"player": "", "pitch": "", "replace": ""}
	if not hold:
		target = build.targets(item)[0].duplicate()
	target.merge({"offer": _offer(build, item), "mode": "hold" if hold else "use"})
	return _command(build, "buy", target)


func _reservation_contracts() -> void:
	for ability: bool in [false, true]:
		var season: SeasonState = _reservation_fixture(ability)
		var item: String = _selected(season.build, ability)
		season = _carry(season, item)
		var build: SeasonBuild = season.build
		var protected: Dictionary = SeasonRaincheck.protected_offer(build)
		var focused: SeasonBuild = build._fork()
		focused._bank._state.sponsors.append(
			{"id": "focus-adapter", "item": "J01", "kind": "sponsor", "paid": 12}
		)
		_check(
			focused.commit(_command(focused, "focused_reroll", {"category": "ability"})).ok,
			"focus respects carried development or learned offer"
		)
		_check(
			(
				SeasonRaincheck.protected_offer(focused) == protected
				and focused._visit.offers.size() == (2 if ability else 3)
			),
			"protected identity excluded from distinct focused draws; no extra slot"
		)
		var price: int = build._visit.rain_price
		_check(
			(
				build.commit(_command(build, "reroll")).ok
				and SeasonRaincheck.protected_offer(build) == protected
			),
			"ordinary reroll keeps carry"
		)
		var command: Dictionary = (
			_ability_buy(build, item, build.roster()[0])
			if ability
			else _development_buy(build, item)
		)
		var cash: int = build.cash()
		_check(
			build.commit(command).ok and build.cash() == cash - price,
			"carried offer uses ordinary paid assignment"
		)
		_check(SeasonRaincheck.protected_offer(build).is_empty(), "purchase consumes protection")
		_check(
			build.commit(command).replayed and build.cash() == cash - price,
			"exact purchase retry cannot duplicate learning or growth"
		)
		var loaded: SeasonState = SeasonSave._decode(_saved(season))
		_check(loaded.build.view() == build.view(), "carry purchase rebuilds exact saved shop")
		if not ability:
			_development_capacity(item)
	_quotes_and_revalidation()


func _development_capacity(item: String) -> void:
	var season: SeasonState = _reservation_fixture(false)
	season = _carry(season, item)
	var build: SeasonBuild = season.build
	# Isolated transaction adapters: source reservation and destination stock are genuine.
	build._visit.union_credit = 3
	build._bank._state.held = [{"id": "one", "item": "A10"}, {"id": "two", "item": "C03"}]
	var before: Dictionary = build.view()
	_check(
		not build.commit(_development_buy(build, item, true)).ok and build.view() == before,
		"full shared bag cannot hold reserved development or consume credit"
	)
	var command: Dictionary = _development_buy(build, item)
	var student: SeasonBuild = build._fork()
	student._bank._state.sponsors.append(
		{"id": "school-adapter", "item": "J10", "kind": "sponsor", "paid": 6}
	)
	student._scholarships["school-adapter"] = {"player": command.player, "uses": 3}
	_check(not student.preview(command).ok, "two applicable concessions require explicit choice")
	var scholarship: Dictionary = command.duplicate(true)
	scholarship["concession"] = "scholarship"
	var student_cash: int = student.cash()
	_check(
		(
			student.commit(scholarship).ok
			and student.cash() == student_cash - 2
			and student._visit.union_credit == 3
			and student._scholarships["school-adapter"].uses == 2
		),
		"carried training uses chosen scholarship without banking or stacking Union"
	)
	var preview: Dictionary = build.preview(command)
	_check(
		(
			preview.ok
			and SeasonRaincheckUI.purchase_review(build, command, preview).contains(
				"discount now: 3"
			)
		),
		"review distinguishes locked base from current concession"
	)
	_check(
		(
			build.commit(command).ok
			and build.cash() == before.wallet.cash - before.shop.rain_price + 3
		),
		"immediate use remains legal with full bag and spends current Union credit once"
	)
	_check(
		build._visit.union_credit == 0 and build.view().wallet.held == before.wallet.held,
		"no reserved extra slot or removed held copy"
	)


func _quotes_and_revalidation() -> void:
	var season: SeasonState = _reservation_fixture(false)
	var build: SeasonBuild = season.build
	for item: String in DevelopmentShopCatalog.CARDS:
		_check(
			SeasonRaincheck.quote(build, item).price == DevelopmentShopCatalog.item(item).price,
			"all six fixed-price development cards quote ordinary base"
		)
	for item: String in ["pack", "recruit", "development.unknown", SeasonAbilities.SKY]:
		_check(
			SeasonRaincheck.quote(build, item).is_empty(), "unsupported or locked offer excluded"
		)
	var item: String = _selected(build, false)
	_check(
		build.commit(_command(build, "reserve_offer", {"offer": _offer(build, item)})).ok,
		"reserve before destination invalidation"
	)
	# Controlled no-recipient case; saved invalid commands are separately rejected by replay.
	for player: String in build.roster():
		for stat: String in SeasonPlayerCatalog.STATS:
			build._book._players[player].stats[stat] = SeasonDevelopment.STAT_CAP
		for pitch: String in build._book._players[player].active:
			build._book._players[player].mastery[pitch] = SeasonDevelopment.PITCH_CAP
	_next_shop(build)
	_check(
		SeasonRaincheck.protected_offer(build).is_empty() and build._visit.offers.size() == 4,
		"invalid recipient at delivery keeps exactly four ordinary replacement slots"
	)


func _legacy_categories() -> void:
	var season: SeasonState = _focus_fixture()
	season.build._format = 38
	_check(
		(
			SeasonSpecialOrder.pool(season.build, "ability").is_empty()
			and SeasonRaincheck.quote(season.build, SeasonAbilities.COUNT).is_empty()
			and SeasonRaincheck.quote(season.build, "development.contact").is_empty()
		),
		"old replay keeps prior category semantics"
	)
	var old: Dictionary = _saved(season)
	var stock: Dictionary = season.build._visit.duplicate(true)
	var loaded: SeasonState = SeasonSave._decode(old)
	_check(loaded != null and loaded.build._visit == stock, "migration never redraws current stock")
	_check(
		not SeasonSpecialOrder.pool(loaded.build, "ability").is_empty(),
		"migrated season may explicitly use newly supported category"
	)
	var bad: Dictionary = old.duplicate(true)
	bad.build.events.append(_command(season.build, "focused_reroll", {"category": "ability"}))
	_check(SeasonSave._decode(bad) == null, "old-format new-category command rejects")


func _categories_ui() -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _focus_fixture()
	_check(app._checkpoint(), "save focused UI source")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	await _click(_button(window, "SPECIAL ORDER • CHOOSE CATEGORY"))
	await _shop_bounds(window, "learned-focus-categories")
	var before: Dictionary = app.season.build.view()
	await _click(_category_button(window, "ability"))
	_check(window._review_text.text.contains("Learned Abilities"), "category named in final review")
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.view() == before, "UI cancellation spends nothing")
	await _click(_category_button(window, "ability"))
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		app.season.build.view() == before and FileAccess.get_file_as_string(path) == bytes,
		"failed focus save restores stock, money and once-per-visit allowance"
	)
	await _click(_button(window, "SPECIAL ORDER • CHOOSE CATEGORY"))
	await _click(_category_button(window, "ability"))
	await _click(window._confirm.get_ok_button())
	await _click(_button(window, "LEARN Work the Count"))
	await _shop_bounds(window, "focused-ability-players")
	await _click(_button(window, "TEACH ", true))
	await _click(window._confirm.get_ok_button())
	_check(
		SeasonSave.restore().build._abilities.learned == app.season.build._abilities.learned,
		"UI focused purchase saves exact player assignment"
	)
	app.queue_free()
	await _frames()


func _reserved_ui(ability: bool) -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _reservation_fixture(ability)
	var item: String = _selected(app.season.build, ability)
	_check(app._checkpoint(), "checkpoint new reservation UI")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	await _click(_button(window, "RAINCHECK • RESERVE & LEAVE"))
	await _shop_bounds(window, "reserve-learned" if ability else "reserve-development")
	var label: String = (
		"RESERVE %s • base %d Cash"
		% [
			SeasonRaincheck.quote(app.season.build, item).name,
			SeasonRaincheck.quote(app.season.build, item).price
		]
	)
	var before: Dictionary = app.season.build.view()
	await _click(_button(window, label))
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.view() == before, "new-category reservation cancellation is inert")
	await _click(_button(window, label))
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		app.season.build.view() == before and FileAccess.get_file_as_string(path) == bytes,
		"failed new-category reservation preserves prior bytes and all stock"
	)
	await _click(_button(window, "RAINCHECK • RESERVE & LEAVE"))
	await _click(_button(window, label))
	await _click(window._confirm.get_ok_button())
	_check(SeasonSave.restore().build._reservation.item == item, "new reservation saved exactly")
	_record(app.season)
	_check(app._checkpoint(), "record next scheduled game")
	app.open_shop()
	await _frames()
	window = _shop(app)
	var build: SeasonBuild = app.season.build
	var command: Dictionary = (
		_ability_buy(build, item, build.roster()[0]) if ability else _development_buy(build, item)
	)
	window._preview(command, "Purchase the carried offer")
	await _frames()
	if not ability:
		_check(
			window._review_text.text.contains("Raincheck base: 6 Cash • discount now: 0 • pay: 6"),
			"carried training review separates base and actual current price"
		)
	await _click(window._confirm.get_ok_button())
	_check(
		SeasonRaincheck.protected_offer(SeasonSave.restore().build).is_empty(),
		"confirmed carried purchase persists and frees its protected slot"
	)
	app.queue_free()
	await _frames()
