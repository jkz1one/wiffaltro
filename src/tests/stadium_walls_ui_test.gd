extends "res://src/tests/stadium_infield_ui_test.gd"
## Whole-run purchase and replacement confirmations, failure atomicity and actual home installation.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://walls-ui-%d.json" % OS.get_process_id()
	var completed: SeasonState = _fund_infield()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = completed
	app.begin_season(96, true)
	var season: SeasonState = app.season
	StadiumEditorUI.show(app.menu)
	var assets: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(assets.revision() == 20 and assets.construction().copies.size() == 23
		and season.career.balance() == 3925,
		"twenty championship pennants precede whole-wall purchases")
	for event: Dictionary in assets.to_data().events:
		_check(event.op == "stadium_pennant", "funding journal contains only earned pennant grants")
	var before: Dictionary = SeasonSave.snapshot(season)
	var initial_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	_check(not ClubConstruction.buy_walls(season, "ST-024", 23, 0).ok
		and ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(SeasonSave.path) == initial_bytes,
		"stale whole-wall receipt cannot mutate funded profile or durable bytes")
	await _click(_wall_buy(app, "ST-024", 23))
	_check(app._dialog.visible and app._dialog.dialog_text.contains("1050"),
		"whole-run confirmation shows exact blueprint plus twenty-three copies")
	await _click(app._dialog.get_cancel_button())
	_check(ClubCareer.same(before, SeasonSave.snapshot(season)), "cancelled purchase changes no data")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/file.json"
	await _click(_wall_buy(app, "ST-024", 23))
	await _click(app._dialog.get_ok_button())
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes, "failed purchase preserves profile and file")
	SeasonSave.path = path
	var starting: int = season.career.balance()
	for row: Array in [["ST-024", 23], ["ST-022", 19], ["ST-023", 19]]:
		await _click(_wall_buy(app, row[0], row[1]))
		await _click(app._dialog.get_ok_button())
	_check(season.career.balance() == starting - 2560
		and ClubConstruction.buy_walls(season, "ST-024", 23, 20).replayed,
		"three complete sets pay exact prices and retry is idempotent")
	for id: String in ["ST-063b", "ST-063g"]:
		await _click(_style_buy(app, id))
	for index in range(4):
		await _click(_buy_button(app, "ST-037"))
	var stock: StadiumStock = ClubPlayers.assets(season.career).construction()
	var poles: Array[String] = []
	for copy: String in stock.copies:
		if stock.copies[copy].item == "ST-037":
			poles.append(copy)
	poles.sort()
	for index in range(poles.size()):
		await _pick_copy(app, poles[index], index + 1)
	await _pick_style(app, "grass", 1)
	await _pick_style(app, "ground", 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(StadiumHomeLayout.validate(season.home_property.layout, stock).night_qualified,
		"old straight-yard layout remains night-qualified with unused wall copies stored")
	var old_key: String = StadiumLayoutSnapshot.key(season.home_property)
	await _pick_wall(app, "back", 2)
	await _pick_wall(app, "left", 1)
	await _pick_wall(app, "right", 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(app._dialog.visible and app._dialog.dialog_text.contains("daylight-only")
		and app._dialog.dialog_text.contains("60 panels"),
		"complete replacement previews exact active panels and lost night eligibility")
	await _click(app._dialog.get_cancel_button())
	_check(StadiumLayoutSnapshot.key(season.home_property) == old_key,
		"cancelled replacement preserves exact active field")
	before = SeasonSave.snapshot(season)
	bytes = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/file.json"
	await _click(_button(app.menu, "APPLY LAYOUT"))
	await _click(app._dialog.get_ok_button())
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes,
		"failed replacement preserves active world and file")
	SeasonSave.path = path
	var apply_revision: int = ClubPlayers.assets(season.career).revision()
	await _click(_button(app.menu, "APPLY LAYOUT"))
	await _click(app._dialog.get_ok_button())
	_check(ClubConstruction.apply_draft(season, season.home_property.layout, apply_revision).replayed,
		"replacement retry cannot apply or charge twice")
	before = SeasonSave.snapshot(season)
	_check(not ClubConstruction.apply_draft(season, season.home_property.layout, 0).ok
		and ClubCareer.same(before, SeasonSave.snapshot(season)), "stale replacement is atomic")
	_check(season.home_property.version == 6
		and season.home_property.layout.walls.back.shape == "deeper_center",
		"confirmed paid recipe becomes a distinct season-entry snapshot")
	_check(not _preview(app).night_eligible,
		"new walls do not silently inherit lighting certification")
	for copy: String in stock.copies:
		if not StadiumWallItems.PRICES.has(stock.copies[copy].item):
			continue
		for choice: OptionButton in app.menu._body.find_children("*", "OptionButton", true, false):
			_check(choice.get_meta("stadium_copy", "") != copy,
				"wall panels never leak into individual live-obstacle controls")
	for index: int in [1, 2]:
		var balance: int = season.career.balance()
		await _pick_wall(app, "back", index)
		await _click(_button(app.menu, "SAVE DRAFT"))
		await _click(_button(app.menu, "APPLY LAYOUT"))
		await _click(app._dialog.get_ok_button())
		_check(season.career.balance() == balance
			and season.home_property.layout.walls.back.copies.size() == (23 if index == 1 else 22),
			"free shape swap installs or stores the exact surplus copy")
	var active_key: String = StadiumLayoutSnapshot.key(season.home_property)
	await _pick_wall(app, "back", 0)
	await _click(_button(app.menu, "RELOAD SAVED"))
	_check(StadiumLayoutSnapshot.key(season.home_property) == active_key,
		"discarding a template-fallback preview preserves active paid walls")
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "owned-deeper-walls")
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _bounds(app, "wall-workshop-small")
	get_window().size = Vector2i(1280, 720)
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	_check(SeasonSave.restore() != null
		and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"wall manifest and geometry survive save/reload")
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.buy_walls(season, "ST-024", 1,
		ClubPlayers.assets(season.career).revision()).ok, "wall construction locks after drafting")
	for fixture: Dictionary in season.schedule:
		if fixture.home != 0:
			continue
		var snapshot: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
		_check(snapshot.version == 7 and snapshot.environment.mode == "day",
			"new wall fixture freezes its own daylight environment")
		app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
		_check(app.lab != null, "actual home opens with paid wall recipe")
		if app.lab != null:
			var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
			_check(property.get_node("BoundaryGraph") is StadiumRecipeBoundaryBody,
				"actual lab consumes new graph rather than old scalar wall")
			_check(StadiumBoundaryRuntime.installed(app.lab, snapshot), "installed manifest matches fixture")
			await _frames(4)
			await _capture(get_viewport(), "owned-wall-home")
			app._close_match()
		break
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro wall UI checks passed: whole-run confirmations, atomic saves and actual home.")
	get_tree().quit(0 if _failures == 0 else 1)


func _wall_buy(app: SeasonApp, item: String, count: int) -> Button:
	for button: Button in app.menu._body.find_children("*", "Button", true, false):
		if button.get_meta("wall_buy", "") == item + ":" + str(count):
			return button
	_check(false, "whole-run purchase button exists")
	return null


func _pick_wall(app: SeasonApp, slot: String, index: int) -> void:
	for choice: OptionButton in app.menu._body.find_children("*", "OptionButton", true, false):
		if choice.get_meta("wall_slot", "") == slot:
			_check(not choice.disabled and not choice.is_item_disabled(index),
				"complete owned recipe enabled")
			choice.select(index)
			choice.item_selected.emit(index)
			await _frames()
			return
	_check(false, "whole-wall selector exists")
