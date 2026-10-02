extends "res://src/tests/season_special_order_test.gd"


func _ready() -> void:
	SeasonSave.path = "user://raincheck-%d.json" % OS.get_process_id()
	var season: SeasonState = _rain_fixture()
	if season != null:
		_rain_contracts(season)
		_rain_persistence(season)
		await _rain_ui(season)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro Raincheck checks passed: paid access, protected offers, replay and UI.")
	get_tree().quit(0 if _failures == 0 else 1)


func _rain_fixture() -> SeasonState:
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._visit.number = 3
	for seed_value in range(5000):
		probe._seed = seed_value
		if not probe._offers(0).values().has("E07"):
			continue
		var season: SeasonState = _new_club(seed_value)
		for game in range(3):
			_result(season, [])
		var build: SeasonBuild = season.build
		build.commit(_command(build, "open"))
		var offer: String = _offer(build, "E07")
		if offer.is_empty():
			continue
		_check(not build._rain_earned, "starts locked")
		var command: Dictionary = _command(build, "sponsor_buy", {"offer": offer, "replace": ""})
		_check(build.preview(command).ok and not build._rain_earned, "preview cannot earn access")
		_check(build.commit(command).ok and build._rain_earned, "18 actual Cash earns access")
		_check(build.commit(command).replayed, "exact purchase retry")
		_result(season, [])
		build.commit(_command(build, "open"))
		for roll in range(4):
			if not _offer(build, "G01").is_empty():
				build.commit(
					_command(build, "sponsor_buy", {"offer": _offer(build, "G01"), "replace": ""})
				)
				if not _reservable(build).is_empty():
					print("RAINCHECK_FIXTURE seed=", seed_value, " cash=", build.cash())
					return season
				break
			build.commit(_command(build, "reroll"))
	_check(false, "Raincheck generated, paid and accompanied by reservable offer")
	return null


func _reservable(build: SeasonBuild) -> String:
	for offer: String in build._visit.offers:
		if not SeasonRaincheck.quote(build, build._visit.offers[offer]).is_empty():
			return offer
	return ""


func _next_shop(build: SeasonBuild) -> void:
	var game: int = build._visit.number
	_check(
		build.commit(_command(build, "reward", {"game": game, "win": true, "performance": {}})).ok,
		"next reward"
	)
	_check(build.commit(_command(build, "open")).ok, "next shop")


func _rain_contracts(season: SeasonState) -> void:
	var original: SeasonBuild = season.build
	var build: SeasonBuild = original._fork()
	var offer: String = _reservable(build)
	var id: String = build._visit.offers[offer]
	var quote: Dictionary = SeasonRaincheck.quote(build, id)
	var command: Dictionary = _command(build, "reserve_offer", {"offer": offer})
	var before: Dictionary = build.view()
	_check(build.preview(command).ok and build.view() == before, "reserve preview pure")
	_check(
		build.commit(command).ok and build.cash() == before.wallet.cash,
		"reservation is not ownership"
	)
	_check(build.commit(command).replayed, "repeat reserve cannot duplicate")
	_check(
		not build.commit(_command(build, "reserve_offer", {"offer": offer})).ok, "only one pending"
	)
	var pending: SeasonBuild = build._fork()
	var source_roll: SeasonBuild = pending._fork()
	_check(source_roll.commit(_command(source_roll, "reroll")).ok, "source reroll remains legal")
	_check(source_roll._reservation.is_empty(), "rerolled source cannot carry a stale offer")
	var source_release: SeasonBuild = pending._fork()
	var source_stock: Dictionary = source_release._visit.offers.duplicate()
	_check(
		source_release.commit(_command(source_release, "release_reservation")).ok, "release pending"
	)
	_check(source_release._visit.offers == source_stock, "pending release never draws new stock")
	# Isolated acquisition classifier: each excluded action spends 18, never ordinary purchase proof.
	for op: String in ["wholesale", "lesson_pair", "pack_open", "reroll", "focused_reroll", "sign"]:
		var paid_before: SeasonBuild = original._fork()
		paid_before._rain_earned = false
		var paid_after: SeasonBuild = paid_before._fork()
		_check(paid_after._charge(18).is_empty(), "controlled excluded spend")
		SeasonRaincheck.after(paid_before, paid_after, {"op": op})
		_check(not paid_after._rain_earned, "aggregate/reroll/recruit spending cannot unlock")

	_next_shop(build)
	var protected: Dictionary = SeasonRaincheck.protected_offer(build)
	_check(
		protected.values() == [id] and build._visit.offers.size() == 4,
		"one of four slots carries exact identity"
	)
	_check(build._visit.rain_price == quote.price, "base quote retained")
	var carried: String = protected.keys()[0]
	_check(
		not build.commit(_command(build, "reserve_offer", {"offer": carried})).ok,
		"cannot carry twice"
	)
	var pack: Array = build._visit.cards.duplicate()
	_check(build.commit(_command(build, "reroll")).ok, "ordinary reroll")
	_check(
		SeasonRaincheck.protected_offer(build) == protected and build._visit.cards == pack,
		"reroll protects offer and pack"
	)
	var restored: SeasonBuild = SeasonBuild.from_data(
		build.to_data(), build._seed, build._initial_roster, build._pool, build._blocked
	)
	_check(
		restored != null and restored.view() == build.view(),
		"carried stock and reroll replay exactly"
	)
	var sold: SeasonBuild = pending._fork()
	var receipt: String = SeasonSchoolSponsors.active(sold, "G01").id
	_check(
		sold.commit(_command(sold, "sponsor_sell", {"receipt": receipt})).ok,
		"sale before generation"
	)
	_check(sold._reservation.is_empty(), "sale cancels pending")
	var released: SeasonBuild = build._fork()
	_check(released.commit(_command(released, "release_reservation")).ok, "release carried offer")
	_check(
		released._visit.offers.size() == 3 and SeasonRaincheck.protected_offer(released).is_empty(),
		"release grants no free replacement"
	)
	_check(
		build.commit(_command(build, "sponsor_sell", {"receipt": receipt})).ok,
		"sale after generation"
	)
	_check(
		SeasonRaincheck.protected_offer(build) == protected, "generated carry remains after sale"
	)
	var purchase: Dictionary = {}
	if not SeasonGearCatalog.item(id).is_empty():
		var slot: String = SeasonGearCatalog.item(id).slot
		purchase = {
			"op": "equip", "offer": carried, "replace": build.view().wallet.gear[slot].get("id", "")
		}
	elif not SeasonSponsorCatalog.item(id).is_empty():
		purchase = {"op": "sponsor_buy", "offer": carried, "replace": ""}
	elif SeasonTacticalCatalog.catalog().has(id):
		purchase = {"op": "tactical_buy", "offer": carried}
	else:
		purchase = {"op": "buy", "offer": carried, "mode": "use"}
		purchase.merge(build.targets(id)[0])
	var buying: Dictionary = _command(build, purchase.op, purchase)
	var cash: int = build.cash()
	_check(
		build.commit(buying).ok and build.cash() == cash - quote.price,
		"carried purchase charges base once"
	)
	_check(
		build.commit(buying).replayed and SeasonRaincheck.protected_offer(build).is_empty(),
		"purchased carry cannot regenerate"
	)
	_check(
		build.commit(_command(build, "reroll")).ok and build._visit.offers.size() == 4,
		"sold position refreshes normally"
	)
	# Controlled integration fixture grants only the second sponsor; production carry is real.
	var focused: SeasonBuild = restored._fork()
	focused._bank.commit(
		{
			"id": "focus-stock",
			"rev": focused._bank.revision(),
			"op": "stock",
			"offers": {"focus": "J01"}
		}
	)
	focused._bank.commit(
		{
			"id": "focus-buy",
			"rev": focused._bank.revision(),
			"op": "buy",
			"offer": "focus",
			"replace": "",
			"discard": []
		}
	)
	_check(not SeasonSchoolSponsors.active(focused, "J01").is_empty(), "controlled focus copy paid")
	_check(
		focused.commit(_command(focused, "focused_reroll", {"category": "tactical"})).ok,
		"focused reroll with carry"
	)
	_check(
		SeasonRaincheck.protected_offer(focused) == protected and focused._visit.offers.size() == 4,
		"focus retains protected slot"
	)
	var seen: Dictionary = {}
	for value: String in focused._visit.offers.values():
		_check(not seen.has(value), "focused identities unique including carry")
		seen[value] = true
	_next_shop(restored)
	_check(
		SeasonRaincheck.protected_offer(restored).is_empty(),
		"unbought carry expires after destination"
	)
	var invalid: SeasonBuild = pending._fork()
	invalid._reservation.item = "development.unknown"
	_next_shop(invalid)
	_check(
		invalid._visit.offers.size() == 4 and SeasonRaincheck.protected_offer(invalid).is_empty(),
		"invalid carry leaves exactly normal four slots"
	)
	var late: SeasonBuild = original._fork()
	late._visit.number = 10
	_check(
		not late.commit(_command(late, "reserve_offer", {"offer": offer})).ok,
		"no postseason source reservation"
	)
	_check(
		SeasonRaincheck.quote(original, "development.contact").price == 6,
		"Working loose-development extension uses its fixed base price"
	)


func _rain_persistence(season: SeasonState) -> void:
	_check(SeasonSave.save(season), "save earned Raincheck")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.career.rain_access(), "career access reloads")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	for field: String in ["start", "earned", "type"]:
		var bad: Dictionary = data.duplicate(true)
		if field == "start":
			bad.build.rain_start = true
		elif field == "earned":
			bad.career.runs[-1].rain_earned = false
		else:
			bad.career.runs[-1].rain_earned = 1
		_check(SeasonSave._decode(bad) == null, "reject inconsistent Raincheck proof")
	_check(restored.career.close(restored), "abandon with access")
	var fresh: SeasonState = _new_club(929, restored.career)
	_check(
		fresh.build._rain_start == true and fresh.build.view().wallet.sponsors.is_empty(),
		"future season inherits access without copy"
	)
	_check(SeasonSave.save(fresh) and SeasonSave.restore() != null, "new season replay")
	var legacy: SeasonState = _new_club(931)
	legacy.build._format = 23
	legacy.build._rain_start = null
	legacy.build._transfer_start = null
	legacy.build._supply_start = null
	legacy.build._checkout_start = null
	legacy.build._association_start = null
	legacy.build._freezer_start = null
	legacy.build._sides_start = null
	legacy.build._jump_start = null
	legacy.build._batch_start = null
	legacy.build._sure_start = null
	legacy.build._field_start = null
	legacy.build._copy.start = null
	legacy.build._abilities.start = null
	legacy.build._major.start = null
	legacy.career.runs[-1].rain_earned = null
	legacy.career.runs[-1].transfer_earned = null
	legacy.career.runs[-1].supplies_used = null
	legacy.career.runs[-1].checkout_earned = null
	legacy.career.runs[-1].association_earned = null
	legacy.career.runs[-1].freezer_earned = null
	legacy.career.runs[-1].sides_earned = null
	legacy.career.runs[-1].jump_earned = null
	legacy.career.runs[-1].batch_used = null
	legacy.career.runs[-1].sure_earned = null
	legacy.career.runs[-1].field_outs = null
	legacy.career.runs[-1].copy_earned = null
	legacy.career.runs[-1].sky_outs = null
	legacy.career.runs[-1].major_earned = null
	_check(SeasonSave.save(legacy), "legacy build23 save")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	old.career.version = 4
	old.career.runs[-1].erase("rain_earned")
	old.career.runs[-1].erase("transfer_earned")
	old.career.runs[-1].erase("supplies_used")
	old.career.runs[-1].erase("checkout_earned")
	old.career.runs[-1].erase("association_earned")
	old.career.runs[-1].erase("freezer_earned")
	old.career.runs[-1].erase("sides_earned")
	old.career.runs[-1].erase("jump_earned")
	old.career.runs[-1].erase("batch_used")
	old.career.runs[-1].erase("sure_earned")
	old.career.runs[-1].erase("field_outs")
	old.career.runs[-1].erase("copy_earned")
	old.career.runs[-1].erase("sky_outs")
	old.career.runs[-1].erase("major_earned")
	var migrated: SeasonState = SeasonSave._decode(old)
	_check(
		migrated != null and migrated.build._rain_start == null,
		"legacy tracking disabled prospectively"
	)
	_check(
		SeasonSave.save(migrated) and SeasonSave.restore() != null, "career5 migration roundtrip"
	)


func _rain_ui(season: SeasonState) -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	_check(SeasonSave.save(season), "save paid UI fixture")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _click(_button(window, "RAINCHECK • RESERVE & LEAVE"))
	await _shop_bounds(window, "raincheck-select")
	var offer: String = _reservable(app.season.build)
	var choice: Button
	for node: Node in window._body.find_children("*", "Button", true, false):
		if node.get_meta("rain_offer", "") == offer:
			choice = node
	var before: Dictionary = app.season.build.to_data()
	await _click(choice)
	await _click(window._confirm.get_cancel_button())
	_check(app.season.build.to_data() == before, "UI cancel no mutation")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(choice)
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		app.season.build.to_data() == before and FileAccess.get_file_as_string(path) == bytes,
		"failed save rolls back reservation"
	)
	await _click(_button(window, "RAINCHECK • RESERVE & LEAVE"))
	for node: Node in window._body.find_children("*", "Button", true, false):
		if node.get_meta("rain_offer", "") == offer:
			choice = node
	await _click(choice)
	await _click(window._confirm.get_ok_button())
	_check(not app.season.build._reservation.is_empty(), "click commits carry and leaves")
	_check(not SeasonSave.restore().build._reservation.is_empty(), "pending carry saved")
	app.open_shop()
	await _frames()
	window = _shop(app)
	await _shop_bounds(window, "raincheck-pending")
	await _click(_button(window, "RELEASE RESERVATION"))
	await _click(window._confirm.get_ok_button())
	_check(app.season.build._reservation.is_empty(), "click releases pending")
	await _click(window._back)
	# A real scheduled result carries the saved offer into the actual next shop.
	var build: SeasonBuild = app.season.build
	_check(
		app.commit_shop(_command(build, "reserve_offer", {"offer": _reservable(build)})),
		"save second reservation for scheduled destination"
	)
	_result(app.season, [])
	_check(SeasonSave.save(app.season), "save scheduled result before destination")
	app.open_shop()
	await _frames()
	window = _shop(app)
	window.size = Vector2i(700, 400)
	_check(
		not SeasonRaincheck.protected_offer(app.season.build).is_empty(),
		"real scheduled destination exposes carry"
	)
	await _shop_bounds(window, "raincheck-destination")
	_check(
		SeasonSave.restore().build.view() == app.season.build.view(),
		"actual destination save reloads without replacement draw"
	)
	await _click(_button(window, "RELEASE RESERVATION"))
	await _click(window._confirm.get_ok_button())
	_check(
		app.season.build._visit.offers.size() == 3, "actual destination release leaves empty slot"
	)
	await _click(window._back)
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "raincheck-progress")
	app.queue_free()
	await _frames()
