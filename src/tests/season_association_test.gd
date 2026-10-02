extends "res://src/tests/season_earned_sponsor_test.gd"

const COMMONS: Array[String] = ["D01", "F02", "F03", "J02", "F04"]
var _unlock_fixture: SeasonState
var _unlock_offer: String
var _purchase_fixture: SeasonState
var _association_offer: String


func _ready() -> void:
	SeasonSave.path = "user://association-%d.json" % OS.get_process_id()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_contract()
	_wholesale_contract()
	_rain_group_contract()
	var season: SeasonState = _paid_association()
	if season != null:
		await _unlock_ui()
		await _paid_purchase_ui()
		_persist_access(season)
		await _association_ui(season)
	await _wholesale_resolution_ui()
	_migrate_association()
	_migrate_paid_association()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Association checks passed: paid unlock, final loadout, groups, replay and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _unit_association() -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(112, ROSTER)
	build._association_start = false
	for game in range(6):
		_check(
			build.commit(_command(build, "reward", {"game": game, "win": true})).ok, "unit funding"
		)
	_check(build.commit(_command(build, "open")).ok, "unit shop")
	return build


func _unit_buy(
	build: SeasonBuild, item: String, replace: String = "", sales: Array = []
) -> Dictionary:
	var offer: String = "fixture:%d" % build.revision()
	build._visit.offers[offer] = item
	var fields: Dictionary = {"offer": offer, "replace": replace, "sales": sales}
	if item == "J10":
		fields["student"] = build.roster()[0]
	return _command(build, "sponsor_buy", fields)


func _active_id(build: SeasonBuild, item: String) -> String:
	return SeasonSchoolSponsors.active(build, item).get("id", "")


func _reject_build(build: SeasonBuild, command: Dictionary, label: String) -> void:
	var before: Dictionary = build.view()
	var data: Dictionary = build.to_data()
	_check(
		not build.commit(command).ok and build.view() == before and build.to_data() == data, label
	)


func _contract() -> void:
	var build: SeasonBuild = _unit_association()
	_reject_build(build, _unit_buy(build, "J05"), "cannot purchase locked Association")
	for id: String in COMMONS:
		var command: Dictionary = _unit_buy(build, id)
		_check(
			build.preview(command).ok and not build._association_earned, "preview earns no access"
		)
		_check(build.commit(command).ok, "paid Common " + id)
	_check(
		build._association_earned and SeasonEarnedSponsors.eligible(build).has("J05"),
		"five distinct Commons earn paid access"
	)
	_check(build.commit(_unit_buy(build, "J05")).ok, "add Association to full base five")
	_check(build.commit(_unit_buy(build, "G04")).ok, "sixth Common")
	_check(
		build.view().wallet.sponsors.size() == 7 and build.view().wallet.capacity.sponsors == 7,
		"seven total including Association"
	)
	_reject_build(
		build,
		_unit_buy(build, "A07", _active_id(build, "D01")),
		"Common replacement with Uncommon invalid"
	)
	_reject_build(
		build,
		_command(build, "sponsor_sell", {"receipt": _active_id(build, "J05")}),
		"removal must resolve extra slot"
	)
	var command: Dictionary = _unit_buy(
		build, "A07", _active_id(build, "J05"), [_active_id(build, "F02"), _active_id(build, "F03")]
	)
	var before: int = build.cash()
	_check(build.preview(command).ok, "combined replacement preview")
	_check(
		build.commit(command).ok and build.view().wallet.sponsors.size() == 5,
		"explicit two extra sales resolve replacement"
	)
	_check(build.cash() == before + 7 + 4 + 5 - 14, "exact three refunds fund purchase")
	_check(build.commit(command).replayed, "group build retry once")
	_check(build._association_earned, "removal keeps access")
	build = _unit_association()
	for id: String in ["D01", "F02", "F03", "J02", "A07"]:
		_check(build.commit(_unit_buy(build, id)).ok, "mixed rarity loadout")
	_check(not build._association_earned, "five sponsors with four Commons do not qualify")
	_reject_build(build, _unit_buy(build, "F04"), "illegal sixth cannot earn access")
	_check(not build._association_earned, "failed transaction earns no feat")
	_check(
		build.commit(_unit_buy(build, "J10", _active_id(build, "A07"))).ok,
		"zero resale Common qualifies fifth"
	)
	_check(build._association_earned, "five distinct Common identities includes Summer School")
	var student: String = _active_id(build, "J10")
	_check(build.commit(_unit_buy(build, "J05")).ok, "capacity with nominated student")
	before = build.cash()
	_check(
		(
			build
			. commit(
				_command(
					build, "sponsor_sell", {"receipt": _active_id(build, "J05"), "sales": [student]}
				)
			)
			. ok
		),
		"explicit Summer removal"
	)
	_check(
		build.cash() == before + 7 and not build._scholarships.has(student),
		"zero refund and no orphan scholarship"
	)


func _wholesale_contract() -> void:
	var build: SeasonBuild = _unit_association()
	for id: String in COMMONS:
		_check(build.commit(_unit_buy(build, id)).ok, "pair starting Commons")
	build._visit.offers = {"association": "J05", "common": "G04"}
	var command: Dictionary = _command(
		build,
		"wholesale",
		{
			"first": {"offer": "common", "replace": ""},
			"second": {"offer": "association", "replace": ""},
			"discounted": "common"
		}
	)
	var before: int = build.cash()
	_check(
		build.commit(command).ok and build.view().wallet.sponsors.size() == 7,
		"Wholesale Common first then Association uses final capacity"
	)
	_check(
		build.cash() == before - 20 and SeasonSchoolSponsors.active(build, "G04").paid == 6,
		"exact discounted receipt"
	)
	build._visit.wholesale_used = false
	build._visit.offers = {"a": "A07", "b": "B02"}
	command = _command(
		build,
		"wholesale",
		{
			"first": {"offer": "a", "replace": _active_id(build, "J05")},
			"second": {"offer": "b", "replace": _active_id(build, "F02")},
			"discounted": "b"
		}
	)
	_reject_build(build, command, "two incoming sponsors require whole final removal plan")
	command["sales"] = [_active_id(build, "F03"), _active_id(build, "F04")]
	_check(
		build.commit(command).ok and build.view().wallet.sponsors.size() == 5,
		"Wholesale explicitly removes four before two purchases"
	)
	_check(
		SeasonSchoolSponsors.active(build, "B02").paid == 9,
		"pair retains selected discounted price"
	)


func _paid_association() -> SeasonState:
	# Actual generated offers and paid transactions, funded by controlled completed results.
	for seed_value in range(100):
		var season: SeasonState = _new_club(seed_value)
		for game in range(10):
			_result(season, [])
			var build: SeasonBuild = season.build
			_check(build.commit(_command(build, "open")).ok, "open generated shop")
			for roll in range(2):
				for offer: String in build._visit.offers.keys():
					var id: String = build._visit.offers[offer]
					var item: Dictionary = SeasonSponsorCatalog.item(id)
					if item.is_empty() or id in ["J08", "J10"]:
						continue
					if id != "J05" and item.rarity != "Common":
						continue
					var request: Dictionary = _command(
						build, "sponsor_buy", {"offer": offer, "replace": ""}
					)
					if build.preview(request).ok:
						if (
							_unlock_fixture == null
							and SeasonAssociation.commons(build) == 4
							and id != "J05"
						):
							_check(SeasonSave.save(season), "capture pre-unlock paid checkpoint")
							_unlock_fixture = SeasonSave.restore()
							_unlock_offer = offer
						if _purchase_fixture == null and id == "J05":
							_check(SeasonSave.save(season), "capture earned paid offer")
							_purchase_fixture = SeasonSave.restore()
							_association_offer = offer
						_check(build.commit(request).ok, "generated paid " + id)
				if (
					build.view().wallet.sponsors.size() == 7
					and not _active_id(build, "F03").is_empty()
				):
					print(
						"ASSOCIATION_FIXTURE seed=",
						seed_value,
						" game=",
						game + 1,
						" cash=",
						build.cash()
					)
					return season
				if roll == 0 and build.cash() >= 18:
					_check(build.commit(_command(build, "reroll")).ok, "paid ordinary reroll")
				else:
					break
	_check(false, "reachable paid seven-sponsor loadout with Optics")
	return null


func _persist_access(season: SeasonState) -> void:
	var build: SeasonBuild = season.build
	_check(build._association_earned, "real generated five-Common feat")
	var offers: Dictionary = build.view().shop.offers
	_check(SeasonSave.save(season), "save paid loadout and access")
	_check(build.view().shop.offers == offers, "save never regenerates displayed stock")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == build.view(), "whole loadout replays")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var bad: Dictionary = data.duplicate(true)
	bad.career.runs[-1].association_earned = false
	_check(SeasonSave._decode(bad) == null, "current-run feat must match journal")
	bad = data.duplicate(true)
	bad.build.association_start = true
	_check(SeasonSave._decode(bad) == null, "inherited feat cannot be forged")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season) and SeasonAssociation.access(club), "abandon keeps access")
	var next: SeasonState = _new_club(501, club)
	_check(
		next.build._association_start == true and next.build.view().wallet.sponsors.is_empty(),
		"next season inherits eligibility without free copies"
	)


func _resolution(parent: Node) -> SeasonSponsorResolution:
	for child: Node in parent.get_children():
		if child is SeasonSponsorResolution:
			return child
	return null


func _sale_choice(dialog: SeasonSponsorResolution, receipt: String) -> CheckBox:
	for child: Node in dialog._choices.get_children():
		if child is CheckBox and child.get_meta("sponsor_sale", "") == receipt:
			return child
	return null


func _association_ui(season: SeasonState) -> void:
	var live_copy: SeasonState = SeasonSave.restore()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	var association: String = _active_id(season.build, "J05")
	var optics: String = _active_id(season.build, "F03")
	var before: Dictionary = season.build.to_data()
	var cash_before: int = season.cash()
	window._preview(window._request("sponsor_sell", {"receipt": association}), "Sell Association")
	await _frames()
	var dialog: SeasonSponsorResolution = _resolution(window)
	_check(dialog != null, "invalid lone sale opens explicit selector")
	if dialog == null:
		app.queue_free()
		return
	_check(dialog.get_ok_button().disabled, "cannot confirm unresolved capacity")
	_check(
		dialog.size.x <= 700 and dialog.size.y <= 400,
		"selector within small shop: %s" % dialog.size
	)
	_check(
		dialog.get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
		"selector starts on Cancel"
	)
	await _click(dialog.get_cancel_button())
	_check(season.build.to_data() == before, "selector cancel retains all sponsors")
	for attempt in range(2):
		window._preview(
			window._request("sponsor_sell", {"receipt": association}), "Sell Association"
		)
		await _frames()
		dialog = _resolution(window)
		await _click(_sale_choice(dialog, optics))
		_check(
			not dialog.get_ok_button().disabled and _sale_choice(dialog, optics).size.y >= 44,
			"explicit extra sale resolves capacity"
		)
		await _click(dialog.get_ok_button())
		_check(
			window._confirm.visible and window._review_text.text.contains("Split Decision Optics"),
			"final review names all removals"
		)
		await _shop_bounds(window, "association-sale")
		var path: String = SeasonSave.path
		var bytes: String = FileAccess.get_file_as_string(path)
		if attempt == 0:
			SeasonSave.path = path + "/missing/save.json"
		await _click(window._confirm.get_ok_button())
		SeasonSave.path = path
		if attempt == 0:
			_check(
				season.build.to_data() == before and FileAccess.get_file_as_string(path) == bytes,
				"failed group save rolls back cash ownership and feat"
			)
	_check(
		season.build.view().wallet.sponsors.size() == 5 and season.cash() == cash_before + 12,
		"shop saves exactly both sales"
	)
	_check(SeasonSave.restore() != null, "group sale reload")
	window.queue_free()
	await _frames()
	ClubSponsorProgressUI.show(app.menu)
	await _menu_bounds(app, "association-access")
	await _live_sale_ui(app, live_copy)
	app.queue_free()
	await _frames()


func _migrate_association() -> void:
	var season: SeasonState = _new_club(543)
	season.build._format = 27
	season.build._association_start = null
	season.build._freezer_start = null
	season.build._sides_start = null
	season.build._jump_start = null
	season.build._batch_start = null
	season.build._sure_start = null
	season.build._field_start = null
	season.build._copy.start = null
	season.build._abilities.start = null
	season.build._major.start = null
	season.career.runs[-1].association_earned = null
	season.career.runs[-1].freezer_earned = null
	season.career.runs[-1].sides_earned = null
	season.career.runs[-1].jump_earned = null
	season.career.runs[-1].batch_used = null
	season.career.runs[-1].sure_earned = null
	season.career.runs[-1].field_outs = null
	season.career.runs[-1].copy_earned = null
	season.career.runs[-1].sky_outs = null
	season.career.runs[-1].major_earned = null
	_check(SeasonSave.save(season), "previous build27 saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 8
	data.career.runs[-1].erase("association_earned")
	data.career.runs[-1].erase("freezer_earned")
	data.career.runs[-1].erase("sides_earned")
	data.career.runs[-1].erase("jump_earned")
	data.career.runs[-1].erase("batch_used")
	data.career.runs[-1].erase("sure_earned")
	data.career.runs[-1].erase("field_outs")
	data.career.runs[-1].erase("copy_earned")
	data.career.runs[-1].erase("sky_outs")
	data.career.runs[-1].erase("major_earned")
	var loaded: SeasonState = SeasonSave._decode(data)
	_check(loaded != null and loaded.build._association_start == null, "old run starts prospective")
	_check(
		loaded != null and SeasonSave.save(loaded) and SeasonSave.restore() != null,
		"legacy roundtrip"
	)


func _unlock_ui() -> void:
	_check(_unlock_fixture != null, "captured real fifth-Common offer")
	if _unlock_fixture == null:
		return
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _unlock_fixture
	_check(SeasonSave.save(app.season), "pre-unlock checkpoint")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	var before: Dictionary = app.season.build.to_data()
	var club: Dictionary = app.season.career.to_data()
	await _click(_sponsor_button(window, _unlock_offer))
	await _click(window._confirm.get_cancel_button())
	_check(
		app.season.build.to_data() == before and not SeasonAssociation.access(app.season.career),
		"fifth-Common cancel earns nothing"
	)
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_sponsor_button(window, _unlock_offer))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		(
			app.season.build.to_data() == before
			and app.season.career.to_data() == club
			and FileAccess.get_file_as_string(path) == bytes
		),
		"failed fifth-Common save cannot award persistent feat"
	)
	await _click(_sponsor_button(window, _unlock_offer))
	await _click(window._confirm.get_ok_button())
	_check(
		app.season.build._association_earned and SeasonAssociation.access(app.season.career),
		"successful fifth Common unlocks immediately"
	)
	_check(_offer(app.season.build, "J05").is_empty(), "unlock does not replace displayed stock")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and SeasonAssociation.access(restored.career), "fifth-Common feat reloads"
	)
	app.queue_free()
	await _frames()


func _paid_purchase_ui() -> void:
	_check(_purchase_fixture != null, "captured paid Association offer")
	if _purchase_fixture == null:
		return
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _purchase_fixture
	_check(SeasonSave.save(app.season), "earned offer checkpoint")
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	var before: int = app.season.cash()
	await _click(_sponsor_button(window, _association_offer))
	await _shop_bounds(window, "association-purchase")
	await _click(window._confirm.get_ok_button())
	_check(
		(
			SeasonSchoolSponsors.active(app.season.build, "J05").paid == 14
			and app.season.cash() == before - 14
		),
		"full base-five UI purchase pays 14 with no replacement"
	)
	_check(app.season.build.view().wallet.capacity.sponsors == 7, "purchased capacity visible")
	_check(SeasonSave.restore() != null, "paid capacity reloads")
	app.queue_free()
	await _frames()


func _live_sale_ui(app: SeasonApp, season: SeasonState) -> void:
	_check(
		season != null and season.build.view().wallet.sponsors.size() == 7,
		"live UI starts with seven paid sponsors"
	)
	if season == null:
		return
	app.season = season
	app.show_season()
	app.play_season_game()
	await _frames()
	_check(app.lab != null, "paid seven-sponsor match launches")
	if app.lab == null:
		return
	PitchBatLabFeelSupport.skip_match_presentation(app.lab)
	app.lab._debug_paused = true
	var state: MatchState = app.lab._match_state
	state.between_batters = false
	var association: String = _active_id(season.build, "J05")
	var optics: String = _active_id(season.build, "F03")
	await _click(app.loadout.entry)
	await _click(app.loadout._tab_buttons[1])
	var before: Dictionary = season.build.to_data()
	app.loadout.sale.review(association, "Neighborhood Association")
	await _frames()
	var dialog: SeasonSponsorResolution = _resolution(app.loadout)
	_check(dialog != null and dialog.get_ok_button().disabled, "live sale uses explicit resolver")
	if dialog == null:
		app.leave_game()
		return
	await _click(_sale_choice(dialog, optics))
	await _click(dialog.get_ok_button())
	var sale: SeasonLoadoutSale = app.loadout.sale
	_check(
		sale.visible and sale._review.text.contains("Split Decision Optics"),
		"live final review shows both copies"
	)
	_check(sale.size.y <= 400, "live group review scrolls within bounded dialog")
	await _click(sale.get_cancel_button())
	_check(season.build.to_data() == before, "live final cancel preserves whole group")
	app.loadout.sale.review(association, "Neighborhood Association")
	await _frames()
	dialog = _resolution(app.loadout)
	await _click(_sale_choice(dialog, optics))
	await _click(dialog.get_ok_button())
	await _click(sale.get_ok_button())
	_check(
		season.build.view().wallet.sponsors.size() == 5 and app.sales.pending.size() == 2,
		"UI saves both sales and queues effects"
	)
	_check(_labels(app.loadout.body).contains("SOLD"), "Equipped marks pending sold effects")
	app.loadout.close()
	app.leave_game()
	await _frames()
	app.play_season_game()
	await _frames()
	_check(
		app.lab != null and app.loadout.match_snapshot.sponsors.size() == 5,
		"restart retains legal saved five"
	)
	app.leave_game()
	await _frames()


func _labels(parent: Node) -> String:
	var result: String = parent.text if parent is Label else ""
	for child: Node in parent.get_children():
		result += "\n" + _labels(child)
	return result


func _migrate_paid_association() -> void:
	var season: SeasonState = _new_club(67)
	# Generate the paid journal with the historical pool, never relabel new stock.
	season.build._format = 27
	season.build._association_start = null
	season.build._freezer_start = null
	season.build._sides_start = null
	season.build._jump_start = null
	season.build._batch_start = null
	season.build._sure_start = null
	season.build._field_start = null
	season.build._copy.start = null
	season.build._abilities.start = null
	season.build._major.start = null
	season.build._association_earned = false
	season.career.runs[-1].association_earned = null
	season.career.runs[-1].freezer_earned = null
	season.career.runs[-1].sides_earned = null
	season.career.runs[-1].jump_earned = null
	season.career.runs[-1].batch_used = null
	season.career.runs[-1].sure_earned = null
	season.career.runs[-1].field_outs = null
	season.career.runs[-1].copy_earned = null
	season.career.runs[-1].sky_outs = null
	season.career.runs[-1].major_earned = null
	for game in range(6):
		_result(season, [])
		season.build.commit(_command(season.build, "open"))
		for offer: String in season.build._visit.offers:
			var id: String = season.build._visit.offers[offer]
			if id == "J10" or SeasonSponsorCatalog.item(id).is_empty():
				continue
			var request: Dictionary = _command(
				season.build, "sponsor_buy", {"offer": offer, "replace": ""}
			)
			if season.build.preview(request).ok:
				season.build.commit(request)
				break
		if not season.build.view().wallet.sponsors.is_empty():
			break
	_check(not season.build.view().wallet.sponsors.is_empty(), "generated historical paid sponsor")
	if season.build.view().wallet.sponsors.is_empty():
		return
	var copy: Dictionary = season.build.view().wallet.sponsors[0]
	_check(
		copy.id.begins_with("sponsor-purchase:"),
		"ordinary receipt identity stays legacy-compatible"
	)
	_check(
		season.build.commit(_command(season.build, "sponsor_sell", {"receipt": copy.id})).ok,
		"prior-format paid sale journal"
	)
	_check(SeasonSave.save(season), "save prior paid history")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 8
	data.career.runs[-1].erase("association_earned")
	data.career.runs[-1].erase("freezer_earned")
	data.career.runs[-1].erase("sides_earned")
	data.career.runs[-1].erase("jump_earned")
	data.career.runs[-1].erase("batch_used")
	data.career.runs[-1].erase("sure_earned")
	data.career.runs[-1].erase("field_outs")
	data.career.runs[-1].erase("copy_earned")
	data.career.runs[-1].erase("sky_outs")
	data.career.runs[-1].erase("major_earned")
	var restored: SeasonState = SeasonSave._decode(data)
	_check(
		restored != null and restored.build._format == SeasonBuild.VERSION,
		"paid prior-format journal migrates"
	)
	if restored != null:
		_check(
			SeasonSave.save(restored) and SeasonSave.restore() != null,
			"migrated paid receipt references replay again"
		)


func _rain_group_contract() -> void:
	var build: SeasonBuild = _unit_association()
	build._rain_start = false
	for id: String in COMMONS + ["J05", "G04"]:
		_check(build.commit(_unit_buy(build, id)).ok, "group funding fixture")
	var before: int = build.cash()
	var request: Dictionary = _unit_buy(
		build, "E07", _active_id(build, "J05"), [_active_id(build, "F02"), _active_id(build, "F03")]
	)
	_check(build.commit(request).ok, "paid eighteen replaces capacity with explicit extra sales")
	_check(
		build._rain_earned and before - build.cash() == 2,
		"Raincheck uses new paid eighteen, not net two after refunds"
	)


func _wholesale_resolution_ui() -> void:
	var build: SeasonBuild = _unit_association()
	for id: String in COMMONS + ["J05", "G04"]:
		_check(build.commit(_unit_buy(build, id)).ok, "Wholesale resolver fixture")
	build._visit.offers = {"a": "A07", "b": "B02"}
	var request: Dictionary = _command(
		build,
		"wholesale",
		{
			"first": {"offer": "a", "replace": _active_id(build, "J05")},
			"second": {"offer": "b", "replace": _active_id(build, "F02")},
			"discounted": "b"
		}
	)
	var before: Dictionary = build.to_data()
	var quote: Dictionary = build.preview(request)
	_check(
		not quote.ok and SeasonSponsorResolution.needed(build, request, quote.error),
		"Wholesale routes unresolved capacity to selector"
	)
	var captured: Dictionary = {"request": {}}
	var dialog: SeasonSponsorResolution = SeasonSponsorResolution.open(
		self, build, request, func(chosen: Dictionary) -> void: captured.request = chosen
	)
	await _frames()
	await _click(_sale_choice(dialog, _active_id(build, "F03")))
	_check(dialog.get_ok_button().disabled, "one extra sale remains insufficient for pair")
	_sale_choice(dialog, _active_id(build, "F04")).grab_focus()
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = pressed
		get_viewport().push_input(key)
		await _frames(1)
	_check(not dialog.get_ok_button().disabled, "keyboard chooses second explicit sale")
	await _click(dialog.get_ok_button())
	_check(
		not captured.request.is_empty() and build.preview(captured.request).ok,
		"pair retains both destinations and extra sales for final review"
	)
	_check(build.to_data() == before, "targeting alone changes no money or inventory")
