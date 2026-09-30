extends "res://src/tests/season_earned_sponsor_test.gd"


func _ready() -> void:
	SeasonSave.path = "user://special-order-%d.json" % OS.get_process_id()
	_contracts()
	_persistence_order()
	await _order_ui()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Special Order checks passed: earned access, focused stock, persistence and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _order_fixture(buy: bool = true) -> SeasonState:
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._order_start = false
	probe._paid_rerolls = 3
	probe._visit.number = 3
	for seed_value in range(2000):
		probe._seed = seed_value
		if not probe._offers(4).values().has("J01"):
			continue
		var season: SeasonState = _new_club(seed_value)
		for game in range(3):
			_result(season, [])
		var build: SeasonBuild = season.build
		build.commit(_command(build, "open"))
		for roll in range(4):
			_check(build.commit(_command(build, "reroll")).ok, "ordinary paid reroll")
		if _offer(build, "J01").is_empty():
			continue
		if buy:
			_check(
				(
					build
					. commit(
						_command(
							build, "sponsor_buy", {"offer": _offer(build, "J01"), "replace": ""}
						)
					)
					. ok
				),
				"pay real sponsor price"
			)
		print("SPECIAL_ORDER_FIXTURE seed=", seed_value)
		return season
	_check(false, "earned sponsor reachable through generated stock")
	return null


func _contracts() -> void:
	var season: SeasonState = _order_fixture()
	var original: SeasonBuild = season.build
	_check(original._paid_rerolls == 4 and original.cash() == 14, "paid acquisition accounting")
	for category: String in SeasonSpecialOrder.CATEGORIES:
		var build: SeasonBuild = original._fork()
		var prior: Dictionary = build.view()
		var pack: Array = build._visit.cards.duplicate()
		var pool: Dictionary = SeasonSpecialOrder.pool(build, category)
		var command: Dictionary = _command(build, "focused_reroll", {"category": category})
		_check(build.preview(command).ok and build.view() == prior, "preview never changes state")
		_check(build.commit(command).ok, "supported category commits")
		var after: Dictionary = build.view()
		_check(
			after.wallet.cash == prior.wallet.cash - 12 and after.shop.rerolls == 5,
			"focus uses ordinary escalating price and counter"
		)
		_check(
			build._visit.cards == pack and after.shop.get("recruit") == prior.shop.get("recruit"),
			"pack/recruit stay fixed"
		)
		var seen: Dictionary = {}
		for id: String in after.shop.offers.values():
			_check(pool.has(id) and not seen.has(id), "only eligible distinct category identities")
			seen[id] = true
		_check(seen.size() == mini(4, pool.size()), "exact bounded fill")
		_check(
			build.commit(command).replayed and build.view() == after, "retry cannot charge again"
		)
		_check(
			not build.commit(_command(build, "focused_reroll", {"category": category})).ok,
			"second focused reroll rejected"
		)
		var restored: SeasonBuild = SeasonBuild.from_data(
			build.to_data(), build._seed, build._initial_roster, build._pool, build._blocked
		)
		_check(restored != null and restored.view() == after, "focused stock replays exactly")
	var small: SeasonBuild = original._fork()
	small._expanded_tactical_from = 13
	_check(
		small.commit(_command(small, "focused_reroll", {"category": "tactical"})).ok,
		"legacy three-card tactical pool can focus"
	)
	_check(
		small.view().shop.offers.size() == 3 and small.view().shop.unavailable_slots == 1,
		"small pool leaves unavailable position instead of duplicate or filler"
	)
	var before: Dictionary = original.to_data()
	for category: String in ["development", "abilities", "transformations", ""]:
		_check(
			(
				not original.commit(_command(original, "focused_reroll", {"category": category})).ok
				and original.to_data() == before
			),
			"unsupported/empty categories cannot spend"
		)
	var free: SeasonBuild = original._fork()
	free._visit.reroll_credit = 100
	var count: int = free._paid_rerolls
	_check(
		free.commit(_command(free, "reroll")).ok and free._paid_rerolls == count,
		"zero actual Cash cannot count toward access"
	)
	var sold: SeasonBuild = original._fork()
	var receipt: String = SeasonSchoolSponsors.active(sold, "J01").id
	_check(
		sold.commit(_command(sold, "sponsor_sell", {"receipt": receipt})).ok,
		"sponsor can be sold normally"
	)
	_check(
		not sold.commit(_command(sold, "focused_reroll", {"category": "gear"})).ok,
		"unowned sponsor cannot focus"
	)
	# Exactly three in this season, and only subsequent generation sees earned access.
	var fresh: SeasonState = _new_club(11)
	for game in range(2):
		_result(fresh, [])
	fresh.build.commit(_command(fresh.build, "open"))
	for roll in range(3):
		_check(
			not SeasonEarnedSponsors.eligible(fresh.build).has("J01"), "before third stays locked"
		)
		fresh.build.commit(_command(fresh.build, "reroll"))
	_check(
		(
			SeasonEarnedSponsors.eligible(fresh.build).has("J01")
			and not fresh.build.view().shop.offers.values().has("J01")
		),
		"no retroactive stock rewrite"
	)


func _persistence_order() -> void:
	var season: SeasonState = _order_fixture()
	_check(SeasonSave.save(season), "save earned access")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.career.order_access(), "earned access reloads")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for kind: String in ["start", "count", "type"]:
		var bad: Dictionary = data.duplicate(true)
		match kind:
			"start":
				bad.build.order_start = true
			"count":
				bad.career.runs[-1].order_rerolls = 3
			"type":
				bad.career.runs[-1].order_rerolls = 3.5
		_check(SeasonSave._decode(bad) == null, "reject changed starting/career proof")
	_check(restored.career.close(restored), "abandon retains committed shop feat")
	var fresh: SeasonState = _new_club(43, restored.career)
	_check(
		(
			fresh.build._order_start == true
			and fresh.build._paid_rerolls == 0
			and fresh.build.view().wallet.sponsors.is_empty()
		),
		"new season inherits access, no copy"
	)
	_check(SeasonSave.save(fresh) and SeasonSave.restore() != null, "new season replay")
	var legacy: SeasonState = _new_club(46)
	legacy.build._format = 22
	legacy.build._order_start = null
	legacy.build._rain_start = null
	legacy.build._transfer_start = null
	legacy.build._supply_start = null
	legacy.career.runs[-1].order_rerolls = null
	legacy.career.runs[-1].rain_earned = null
	legacy.career.runs[-1].transfer_earned = null
	legacy.career.runs[-1].supplies_used = null
	_check(SeasonSave.save(legacy), "legacy tracked career fixture saves")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	old.career.version = 3
	for run: Dictionary in old.career.runs:
		run.erase("order_rerolls")
		run.erase("rain_earned")
		run.erase("transfer_earned")
		run.erase("supplies_used")
	var migrated: SeasonState = SeasonSave._decode(old)
	_check(
		migrated != null and migrated.build._order_start == null,
		"legacy active season invents no shop progress"
	)
	_check(SeasonSave.save(migrated) and SeasonSave.restore() != null, "migrated career4 replays")


func _order_ui() -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _order_fixture()
	_check(SeasonSave.save(app.season), "paid UI fixture saved")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "special-order-small-shop")
	var before: Dictionary = app.season.build.to_data()
	await _click(_button(window, "SPECIAL ORDER • CHOOSE CATEGORY"))
	await _shop_bounds(window, "special-order-categories")
	await _click(_category_button(window, "gear"))
	_check(window._review_text.text.contains("Cash: 14 → 2"), "exact review price")
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "cancel leaves stock and cash unchanged")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_category_button(window, "gear"))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		app.season.build.to_data() == before and FileAccess.get_file_as_string(path) == bytes,
		"failed write rolls back focus and refund"
	)
	await _click(_button(window, "SPECIAL ORDER • CHOOSE CATEGORY"))
	await _click(_category_button(window, "gear"))
	await _click(window._confirm.get_ok_button())
	_check(
		app.season.cash() == 2 and app.season.build.view().shop.focused_used,
		"actual click commits focused stock once"
	)
	await _shop_bounds(window, "special-order-result")
	await _click(window._back)
	ClubSponsorProgressUI.show(app.menu)
	await _frames()
	await _menu_bounds(app, "special-order-earned-progress")
	app.play_season_game()
	await _frames()
	_check(app.lab != null, "focused stock does not block actual match launch")
	app.leave_game()
	await _frames()
	_check(SeasonSave.restore().build.view().shop.focused_used, "reload/restart cannot reset focus")
	app.begin_season(129, false)
	_check(
		app.season.build == null and app.season.career != null,
		"legacy season preserves earned club history"
	)
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "special-order-legacy-progress")
	app.queue_free()
	await _frames()


func _category_button(window: SeasonShopWindow, category: String) -> Button:
	for node: Node in window._body.find_children("*", "Button", true, false):
		if node.get_meta("focus_category", "") == category:
			return node
	return null
