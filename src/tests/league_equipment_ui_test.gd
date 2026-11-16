extends "res://src/tests/paid_shop_ui_test.gd"
## Controlled UI fixture only: synthetic rewards, no game completion or saved progress claim.
## Parent owns engine execution. Optional native captures use --ui-capture-dir.

var checks: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	_check(ok, label)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	await _equipment_controls()
	await TestAudioDrain.finish(get_tree())
	print("Equipment UI controlled checks: %d, failures: %d" % [checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture() -> SeasonState:
	var roster: Array[String] = []
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	for seed_value: int in range(800):
		var build: SeasonBuild = SeasonBuild.new(seed_value, roster)
		if not build.enable_league_rules(LeagueRules.capture("equipment")):
			return null
		for game: int in range(2):
			if not (
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": game, "win": true}))
				. ok
			):
				return null
		if not build.commit(SeasonOpponentPolicy.command(build, "open")).ok:
			return null
		var offers: Array = build.view().shop.offers.values()
		if not offers.has("BAT-CON-01") or not offers.has("BAT-POW-01"):
			continue
		var season: SeasonState = SeasonState.create(seed_value, false, true, false)
		for index in range(4):
			season.choose_player(season.offers()[0])
		season.teams[0].roster = roster.duplicate()
		season.build = build
		season.league_rules = LeagueRules.capture("equipment")
		# Presentation gate only. Never save this intentionally synthetic season wrapper.
		season.player_results.append({"synthetic_ui_gate": true})
		return season
	return null


func _equipment_controls() -> void:
	var app: SeasonApp = SeasonApp.new()
	app.season = _fixture()
	check(app.season != null, "synthetic paired Bat shop available")
	if app.season == null:
		app.free()
		return
	var window: SeasonShopWindow = SeasonShopWindow.new()
	window.app = app
	add_child(window)
	window.popup_centered()
	await _frames()
	var ui: SeasonLoadoutUI
	for child: Node in window.get_children():
		if child is SeasonLoadoutUI:
			ui = child
	app.loadout = ui
	var build: SeasonBuild = app.season.build
	check(window.spare_actions_available(), "spare controls are between games")
	check(
		_text(window).contains("Spare 0 / 1") and _text(window).contains("No free spare"),
		"empty spare and ordinary paid purchase disclosed"
	)
	check(_text(window).contains("Held 0 / 1"), "one fewer held slot displayed")
	var first: String = _offer(build, "BAT-CON-01")
	var second: String = _offer(build, "BAT-POW-01")
	var spare_buy: Button = _meta(window, "gear_spare_offer", second)
	check(spare_buy != null and not spare_buy.disabled, "paid spare button enabled")
	if spare_buy == null:
		window.free()
		app.free()
		return
	var before: Dictionary = build.to_data()
	var buy_command: Dictionary = spare_buy.get_meta("shop_command")
	spare_buy.pressed.emit()
	await _frames()
	check(
		(
			window._confirm.visible
			and window._review_text.text.contains("inactive spare")
			and window._review_text.text.contains("Cash: 36 → 26")
		),
		"spare review discloses normal debit and inactivity"
	)
	check(
		window._confirm.gui_get_focus_owner() == window._confirm.get_cancel_button(),
		"spare confirmation defaults to cancel"
	)
	window._confirm.canceled.emit()
	window._confirm.hide()
	check(
		window._pending.is_empty() and build.to_data() == before,
		"cancel does not buy or change stock"
	)
	check(
		build.commit(window._request("equip", {"offer": first, "replace": ""})).ok,
		"controlled paid active Bat"
	)
	buy_command = window._request("spare_buy", {"offer": second})
	var active_effect: Dictionary = build.definition(build.roster()[0]).season_gear.duplicate(true)
	check(build.commit(buy_command).ok, "controlled paid inactive Bat")
	check(
		build.definition(build.roster()[0]).season_gear == active_effect,
		"stored spare adds no player effect"
	)
	window._refresh()
	await _frames()
	var spare: Dictionary = build.view().wallet.spare
	var active: Dictionary = build.view().wallet.gear.bat
	var rows: Dictionary = SeasonLoadoutData.pages(app)
	check(
		rows.gear.size() == 3 and rows.spare.receipt == spare.id and rows.spare.inactive_spare,
		"three active loadout rows plus separate exact inactive receipt"
	)
	check(
		(
			rows.spare.effect.begins_with("When active:")
			and rows.spare.status.contains("Paid 10 Cash")
		),
		"inactive card distinguishes hypothetical effect and paid identity"
	)
	check(
		_text(window).contains("Spare 1 / 1") and not _text(window).contains("no spares"),
		"Equipment inventory does not claim equipped-only ownership"
	)
	var swap: Button = _meta(window, "gear_spare_swap", spare.id)
	check(swap != null and not swap.disabled, "matching-category swap visible")
	if swap != null:
		var swap_command: Dictionary = swap.get_meta("shop_command")
		check(
			swap_command.spare == spare.id and swap_command.active == active.id,
			"swap binds both exact receipt identities"
		)
		before = build.to_data()
		swap.pressed.emit()
		await _frames()
		check(
			(
				window._review_text.text.contains("Already paid: 0 Cash")
				and window._review_text.text.contains("Cash: 16 → 16")
			),
			"swap review is not a purchase or refund"
		)
		window._confirm.canceled.emit()
		window._confirm.hide()
		check(build.to_data() == before, "cancel swap preserves active/spare identities")
		check(build.commit(swap_command).ok, "controlled exact swap")
		window._refresh()
		await _frames()
		check(
			build.view().wallet.gear.bat == spare and build.view().wallet.spare == active,
			"swap UI command preserves paid receipts"
		)
		ui._review_spare_sale(spare.id, SeasonGearCatalog.item(spare.item).name, 5)
		check(
			not window._confirm.visible and ui.context.text.contains("spare changed"),
			"stale spare-sale control cannot sell a now-active receipt"
		)
	# Controlled duplicate stock only: verify disabled presentation, never persist it.
	build._visit.offers["duplicate-active"] = spare.item
	build._visit.offers["duplicate-spare"] = active.item
	window._refresh()
	await _frames()
	for offer: String in ["duplicate-active", "duplicate-spare"]:
		check(
			(
				_meta(window, "gear_offer", offer).disabled
				and _meta(window, "gear_spare_offer", offer).disabled
			),
			"owned active or spare disables both purchase paths: " + offer
		)
	build._visit.offers.erase("duplicate-active")
	build._visit.offers.erase("duplicate-spare")
	window._refresh()
	await _frames()
	window.size = Vector2i(1000, 650)
	await _frames()
	ui.open()
	ui._select("gear")
	check(
		_text(ui.body).contains("INACTIVE SPARE") and ui._rows.gear.size() == 3,
		"shipped loadout visibly separates spare from active slots"
	)
	await _select_loadout_receipt(ui, "gear", build.view().wallet.gear.bat.id)
	check(ui._sale_buttons.size() == 1, "selected active paid copy offers its sale")
	await _select_loadout_receipt(ui, "gear", build.view().wallet.spare.id)
	check(ui._sale_buttons.size() == 1, "selected inactive paid copy offers its shop sale")
	await _capture(window, "equipment-loadout")
	await _frames()
	var spare_card: Control = ui._detail
	ui.scroll.ensure_control_visible(spare_card)
	await _frames()
	print(
		"SPARE_CAPTURE_BOUNDS scroll=",
		ui.scroll.get_global_rect(),
		" card=",
		spare_card.get_global_rect(),
		" value=",
		ui.scroll.scroll_vertical
	)
	check(
		ui.scroll.get_global_rect().encloses(spare_card.get_global_rect()),
		"inactive spare card is actually visible after ordinary scrolling"
	)
	await _capture(window, "equipment-loadout-spare")
	ui.close()
	await _remaining_supplies(window, ui)
	for extent: Vector2i in [Vector2i(1000, 650), Vector2i(700, 400)]:
		window.size = extent
		await _shop_bounds(window, "equipment-shop-%d" % extent.x)
		var visible_swap: Button = _meta(window, "gear_spare_swap", build.view().wallet.spare.id)
		visible_swap.grab_focus()
		window._scroll.ensure_control_visible(visible_swap)
		await _frames()
		check(
			window._scroll.get_global_rect().encloses(visible_swap.get_global_rect()),
			"matching-category spare swap visible at width " + str(extent.x)
		)
		await _capture(window, "equipment-shop-spare-%d" % extent.x)
		if extent.x == 1000:
			before = build.to_data()
			visible_swap.pressed.emit()
			await _frames()
			check(window._confirm.visible, "visible spare swap opens ordinary review")
			await _capture(window, "equipment-spare-swap-review")
			window._confirm.canceled.emit()
			window._confirm.hide()
			check(
				build.to_data() == before,
				"visible swap review cancellation preserves paid receipts"
			)
	# No scene launch: unattached lab supplies only the live-sale availability state.
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_state = MatchState.new()
	app.lab = lab
	app._season_game = true
	ui._rows = rows
	var holder: HBoxContainer = HBoxContainer.new()
	add_child(holder)
	var spare_row: Dictionary = rows.spare
	ui._sale_action(holder, spare_row)
	check(holder.get_child_count() == 0, "inactive spare has no in-match sale button")
	var active_row: Dictionary = rows.gear[0]
	active_row.receipt = build.view().wallet.gear.bat.id
	ui._sale_action(holder, active_row)
	check(holder.get_child_count() == 1, "existing active Gear in-match sale remains available")
	check(not window.spare_actions_available(), "live app blocks all spare shop actions")
	app.lab = null
	lab.free()
	holder.free()
	# Prepared next-game commitments must also hide spare operations before a lab exists.
	build._pregames["999"] = {}
	check(not window.spare_actions_available(), "unresolved pregame blocks spare actions")
	build._pregames.erase("999")
	window.free()
	app.free()
	await _frames()


func _remaining_supplies(window: SeasonShopWindow, ui: SeasonLoadoutUI) -> void:
	var original: Dictionary = ui._rows.duplicate(true)
	var history: Array = [
		{
			"name": "Historical spent receipt",
			"label": "Used this game",
			"effect": "Already spent",
			"status": "Working"
		}
	]
	for remaining: int in range(4):
		ui._rows = original.duplicate(true)
		ui._rows.capacity.held = 3
		ui._rows.used = history.duplicate(true)
		ui._rows.supplies = []
		for index: int in range(remaining):
			ui._rows.supplies.append(
				{
					"name": "Usable copy %d" % index,
					"label": "Held",
					"effect": "Available at the legal supply prompt",
					"status": "Working"
				}
			)
		ui.shade.show()
		ui._select("supplies")
		await _frames()
		var text: String = _text(ui.body)
		check(text.contains("%d / 3 supplies" % remaining), "remaining supply count %d" % remaining)
		check(
			(
				not text.contains("Historical spent receipt")
				and not text.contains("USED THIS GAME")
				and not text.contains("Already spent")
				and not text.contains("Used this game")
			),
			"spent supply display omitted with %d remaining" % remaining
		)
		check(
			text.contains("No supplies remaining.") == (remaining == 0),
			"clear empty state only at zero remaining"
		)
		check(ui._rows.used == history, "display does not erase consumed receipt projection")
		check(
			ui._tab_buttons[2].text == "Supplies  " + str(remaining),
			"tab counts only remaining copies"
		)
		if remaining in [0, 1, 3]:
			await _capture(window, "equipment-remaining-%d" % remaining)
	ui.shade.hide()
	ui._rows = original
	ui._select("gear")


func _offer(build: SeasonBuild, item: String) -> String:
	for offer: String in build.view().shop.offers:
		if build.view().shop.offers[offer] == item:
			return offer
	return ""


func _meta(window: SeasonShopWindow, key: String, value: String) -> Button:
	for node: Node in window._body.find_children("*", "Button", true, false):
		if node.get_meta(key, "") == value:
			return node
	return null


func _text(node: Node) -> String:
	var result: String = ""
	if node is Label or node is Button:
		result += node.text + "\n"
	for child: Node in node.get_children():
		result += _text(child)
	return result


func _select_loadout_receipt(ui: SeasonLoadoutUI, tab: String, receipt: String) -> void:
	if ui._tab != tab:
		for button: Button in ui._tab_buttons:
			if button.get_meta("loadout_tab") == tab:
				await _click(button)
				break
	var target: Button
	for button: Button in ui._item_buttons:
		if button.get_meta("loadout_identity") == tab + ":" + receipt:
			target = button
			break
	_check(target != null, "exact paid-copy tile exists: " + receipt)
	if target == null:
		return
	await _click(target)
	await _frames()
	_check(ui._selected_identity == tab + ":" + receipt, "selection binds exact paid copy")
	for action: Button in ui._sale_buttons:
		_check(action.get_meta("sale_receipt") == receipt, "visible sale binds selected receipt")


func _select_loadout_code(ui: SeasonLoadoutUI, tab: String, code: String) -> void:
	for row: Dictionary in ui._rows[tab]:
		if row.get("icon_code") == code:
			await _select_loadout_receipt(ui, tab, row.receipt)
			return
	_check(false, "catalog item has an owned display receipt: " + code)
