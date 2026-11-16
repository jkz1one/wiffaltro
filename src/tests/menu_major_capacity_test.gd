extends "res://src/tests/equipped_icon_grid_test.gd"
## Read-only UI inspection of a copied genuinely earned dual-Fielding save.

func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var raw: String = FileAccess.get_file_as_string(OS.get_environment("MENU_MAJOR_SAVE"))
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(raw))
	check(season != null, "copied earned save cold-decodes without changing origin")
	if season == null:
		get_tree().quit(1)
		return
	var before: String = JSON.stringify(season.build.to_data(), "", true, true)
	var nominee: String = season.build._major.player
	check(not nominee.is_empty() and season.build._abilities.in_slot(nominee, "Fielding").size() == 2,
		"actual paid nominee owns two Fielding abilities")
	var app: SeasonApp = SeasonApp.new()
	app.season = season
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
	ui.open()
	ui._select("abilities")
	await _frames(6)
	var expected: String = season.build.definition(nominee).display_name + ": 2 Fielding"
	check(_text(ui.body).contains(expected),
		"Abilities capacity identifies actual Double Major exception")
	check(ui._item_buttons.size() >= 2, "paid learned icons remain present")
	for extent: Vector2i in [Vector2i(1000, 650), Vector2i(700, 400)]:
		window.size = extent
		ui.scroll.scroll_vertical = 0
		await _frames(6)
		await _capture(window, "major-abilities-%d" % extent.x)
		check(ui.panel.size.x <= window.size.x, "capacity fits narrow panel")
		ui._item_buttons[-1].pressed.emit()
		await _frames(6)
		await _capture(window, "major-detail-%d" % extent.x)
	# Display-only boundaries; do not alter the actual paid source or learned slots.
	ui._rows.erase("major_player")
	ui._select("abilities")
	check(_text(ui.body).contains("1 Hitting + 1 Fielding per player")
		and not _text(ui.body).contains(expected), "old display rows retain ordinary capacity copy")
	ui._rows.major_player = "player.missing"
	ui._select("abilities")
	check(not _text(ui.body).contains("2 Fielding"), "foreign nomination never labels another player")
	ui._rows = SeasonLoadoutData.pages(app)
	ui._select("abilities")
	check(_text(ui.body).contains(expected), "refresh restores the exact current nominee")
	# Read-only live projection boundary: an expired sponsor must not leave its label behind.
	var definitions: Array[PlayerDefinition] = SeasonAbilityLoadout.players(app, null)
	app.lab = PitchBatLab.new()
	app.lab._player_home = true
	app.lab._match_state = MatchState.create(
		TeamMatchState.create("Projection away", definitions),
		TeamMatchState.create("Projection home", definitions))
	ui.match_snapshot = SeasonLoadoutData.capture(season)
	check(SeasonLoadoutData.pages(app).major_player == nominee,
		"live capacity uses the captured paid sponsor and nominee")
	ui.match_snapshot.sponsors.clear()
	check(SeasonLoadoutData.pages(app).major_player == "",
		"retired sponsor cannot leave a stale extra-slot label")
	app.lab.free()
	app.lab = null
	check(JSON.stringify(season.build.to_data(), "", true, true) == before,
		"inspection preserves all paid receipts, ownership and journal")
	window.queue_free()
	app.free()
	await _frames()
	print("MENU_MAJOR_CAPACITY checks=", checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)
