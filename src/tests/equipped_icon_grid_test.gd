extends "res://src/tests/league_equipment_ui_test.gd"
## Isolated prototype QA. Synthetic paid shop preparation; never normal player progress.
## No actual sale commit: existing receipt/save suites must also run before integration.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	await _grid_checks()
	await TestAudioDrain.finish(get_tree())
	print("Equipped icon grid checks: %d, failures: %d" % [checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _grid_checks() -> void:
	var app: SeasonApp = SeasonApp.new()
	app.season = _fixture()
	check(app.season != null, "controlled paid fixture available")
	if app.season == null:
		app.free()
		return
	var window: SeasonShopWindow = SeasonShopWindow.new()
	window.app = app
	add_child(window)
	window.popup_centered()
	# Test provenance stays outside the player-facing loadout, never in item copy.
	var evidence: CanvasLayer = CanvasLayer.new()
	evidence.layer = 120
	window.add_child(evidence)
	var evidence_label: Label = Label.new()
	evidence_label.text = "CONTROLLED UI PREVIEW • synthetic inventory"
	evidence_label.position = Vector2(12, 1)
	evidence_label.add_theme_font_size_override("font_size", 11)
	evidence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	evidence.add_child(evidence_label)
	await _frames()
	var ui: SeasonLoadoutUI
	for child: Node in window.get_children():
		if child is SeasonLoadoutUI:
			ui = child
	app.loadout = ui
	var build: SeasonBuild = app.season.build
	check(
		(
			build
			. commit(
				window._request("equip", {"offer": _offer(build, "BAT-CON-01"), "replace": ""})
			)
			. ok
		),
		"real active paid receipt created in synthetic fixture"
	)
	check(
		build.commit(window._request("spare_buy", {"offer": _offer(build, "BAT-POW-01")})).ok,
		"real inactive paid receipt created in synthetic fixture"
	)
	window._refresh()
	await _frames()
	var before: Dictionary = build.to_data()
	ui.open()
	ui._select("gear")
	await _frames()
	check(
		(
			not _text(ui.shade).contains("One fewer")
			and not _text(ui.shade).contains("can be sold during games")
			and not _text(ui.shade).contains("No inning swaps")
		),
		"player UI omits explanatory disclaimers"
	)
	check(
		not _text(ui.shade).contains("BAT-CON-01"),
		"player tile uses category rather than catalog code"
	)
	check(ui._item_buttons.size() == 4, "three active icons and separate inactive spare icon")
	check(ui._sale_buttons.size() == 1, "only highlighted owned item offers a sale")
	var active: String = build.view().wallet.gear.bat.id
	var spare: String = build.view().wallet.spare.id
	check(ui._selected_identity == "gear:" + active, "initial selected paid identity is exact")
	ui._item_buttons[3].mouse_entered.emit()
	await _frames()
	check(
		(
			ui._selected_identity == "gear:" + spare
			and _text(ui._detail).contains("When active:")
			and _text(ui._detail).contains("INACTIVE SPARE")
		),
		"pointer highlight exposes inactive spare detail"
	)
	check(
		_text(ui._item_buttons[3]).contains("INACTIVE SPARE"),
		"spare marked inactive without relying on color"
	)
	ui._item_buttons[0].grab_focus()
	await _frames()
	check(ui._selected_identity == "gear:" + active, "keyboard focus reveals active paid copy")
	ui._sale_buttons[0].pressed.emit()
	await _frames()
	check(
		ui.sale.visible and ui.sale.request.get("receipt", "") == active,
		"legal sale opens existing exact receipt confirmation"
	)
	check(ui.sale.gui_get_focus_owner() == ui.sale.get_cancel_button(), "sale defaults to Cancel")
	ui._item_buttons[3].mouse_entered.emit()
	check(ui._selected_identity == "gear:" + active, "highlight cannot retarget pending sale")
	ui.sale.canceled.emit()
	ui.sale.hide()
	check(build.to_data() == before, "sale cancellation leaves wallet and paid receipts unchanged")
	ui._item_buttons[3].pressed.emit()
	await _frames()
	check(
		ui._selected_identity == "gear:" + spare and ui._sale_buttons.size() == 1,
		"click/tap selects spare without selling"
	)
	ui._select("gear")
	check(ui._selected_identity == "gear:" + spare, "refresh retains same paid-copy selection")
	# Controller uses the same established modal focus cycle, including every icon and action.
	ui.close_button.grab_focus()
	var reached: Dictionary = {}
	for step in range(6 + ui._item_buttons.size() + 2):
		ui._cycle_focus(false)
		var focused: Control = ui.get_viewport().gui_get_focus_owner()
		if focused != null and focused.has_meta("loadout_identity"):
			reached[focused.get_meta("loadout_identity")] = true
	check(reached.size() == 4, "modal focus cycle reaches all four item identities")
	for extent: Vector2i in [Vector2i(1000, 650), Vector2i(700, 400)]:
		window.size = extent
		ui._item_buttons[3].pressed.emit()
		await _frames(6)
		check(ui.panel.get_global_rect().size.x <= window.size.x, "panel fits width %d" % extent.x)
		for tile: Button in ui._item_buttons:
			check(tile.size.x <= 130 and tile.size.y <= 115, "tiles stay compact at %d" % extent.x)
		check(ui._detail.size.x <= ui.scroll.size.x, "detail does not overflow horizontally")
		ui._sale_buttons[0].grab_focus()
		ui.scroll.ensure_control_visible(ui._sale_buttons[0])
		await _frames()
		check(
			ui.scroll.get_global_rect().encloses(ui._sale_buttons[0].get_global_rect()),
			"legal action can be fully exposed at %d" % extent.x
		)
		await _capture(window, "equipped-grid-spare-%d" % extent.x)
		ui.scroll.scroll_vertical = 0
		await _frames()
		await _capture(window, "equipped-grid-icons-%d" % extent.x)
	# Catalog-backed presentation-only sponsor rows, not a claim of paid ownership.
	ui._rows.sponsors = []
	for code: String in ["D01", "A08", "A09", "A07", "B02"]:
		var item: Dictionary = SeasonSponsorCatalog.item(code)
		ui._rows.sponsors.append(
			{
				"name": item.name,
				"icon_code": code,
				"label": "Owned this season",
				"effect": item.effect,
				"status": "Working"
			}
		)
	ui._select("sponsors")
	ui._item_buttons[3].pressed.emit()
	await _frames(6)
	check(
		_text(ui._detail).contains("Neighborhood Deli"),
		"same-category sponsor names identify highlighted item"
	)
	await _capture(window, "equipped-grid-sponsor-detail-700")
	window.size = Vector2i(1000, 650)
	ui.scroll.scroll_vertical = 0
	await _frames(6)
	await _capture(window, "equipped-grid-sponsors-1000")
	# Duplicate remaining supplies are distinguished by receipt, not array position.
	# This standalone read-only display fixture uses a three-slot capacity, not
	# the earlier Equipment wallet's one-slot limit. Never modify the real wallet.
	ui._rows.capacity = ui._rows.capacity.duplicate(true)
	ui._rows.capacity.held = 3
	ui._rows.supplies = []
	for id: String in ["copy-a", "copy-b"]:
		ui._rows.supplies.append(
			{
				"name": "Grip Tape",
				"receipt": id,
				"icon_code": "A10",
				"label": "Held • use at the first-pitch prompt",
				"effect": SeasonTacticalCatalog.item("A10").effect,
				"status": "Working"
			}
		)
	check(
		ui._rows.supplies.size() <= ui._rows.capacity.held,
		"synthetic remaining display respects its stated capacity"
	)
	ui._rows.used = [{"name": "Spent sentinel"}]
	ui._select("supplies")
	ui._item_buttons[1].pressed.emit()
	check(
		ui._selected_identity == "supplies:copy-b" and ui._sale_buttons.is_empty(),
		"supplies expose exact copy identity but no illegal sale action"
	)
	await _frames(6)
	await _capture(window, "equipped-grid-remaining-1000")
	window.size = Vector2i(700, 400)
	ui._item_buttons[1].pressed.emit()
	await _frames(6)
	await _capture(window, "equipped-grid-remaining-700")
	ui._rows.supplies.reverse()
	ui._select("supplies")
	check(
		ui._selected_identity == "supplies:copy-b",
		"reordered remaining copies do not drift selection"
	)
	ui._rows.supplies.remove_at(0)
	ui._select("supplies")
	check(
		ui._selected_identity == "supplies:copy-a",
		"removed selected copy falls back to extant copy"
	)
	check(not _text(ui.body).contains("Spent sentinel"), "no spent section reintroduced")
	ui._rows.supplies.clear()
	ui._select("supplies")
	check(
		(
			ui._item_buttons.is_empty()
			and not ui._detail.visible
			and _text(ui.body).contains("No supplies remaining.")
		),
		"empty remaining inventory is explicit"
	)
	check(build.to_data() == before, "all selection and layout checks are read-only")
	ui.close()
	check(not ui.shade.visible and not ui.sale.visible, "close dismisses modal and detail")
	window.free()
	app.free()
	await _frames()
