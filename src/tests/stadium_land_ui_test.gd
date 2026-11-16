extends "res://src/tests/stadium_seating_ui_test.gd"
## Real land confirmation/save transaction; synthetic completed scores fund the club.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://land-ui-%d.json" % OS.get_process_id()
	_fund_seating()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(88, true)
	var season: SeasonState = app.season
	var old: Dictionary = season.home_property.duplicate(true)
	var stock: Dictionary = ClubPlayers.assets(season.career).construction().to_data()
	StadiumEditorUI.show(app.menu)
	var path: String = SeasonSave.path
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(ClubPlayers.assets(season.career).revision() == 4,
		"four earned awards precede paid land confirmation")
	_check(not ClubConstruction.buy_land(season, "expanded", 0).ok
		and ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes,
		"obsolete pre-award revision cannot expand or change saved funds")
	await _click(_land_button(app, "expanded"))
	await _click(app._dialog.get_cancel_button())
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes, "cancel preserves money, land and save bytes")
	await _click(_land_button(app, "expanded"))
	SeasonSave.path = path + "/missing/file.json"
	await _click(app._dialog.get_ok_button())
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes, "failed expansion is fully atomic")
	SeasonSave.path = path
	await _click(_land_button(app, "expanded"))
	await _click(app._dialog.get_ok_button())
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(ledger.view().land == "expanded" and ledger.balance() == 205,
		"actual confirmation spends exactly 600 CB")
	_check(ledger.construction().to_data() == stock, "land does not grant or remove objects")
	_check(ClubConstruction.buy_land(season, "expanded", 4).replayed
		and season.career.balance() == 205, "repeated confirmation does not double charge")
	_check(season.home_property.version == 4 and season.home_property.tier == "expanded",
		"predraft expansion atomically updates the current home snapshot")
	_check(StadiumLayoutSnapshot.matches(old, ledger),
		"previous field remains valid at its old prefix")
	await _click(_buy_button(app, "ST-080"))
	var copy: String = "purchase:stadium-buy:5:0"
	_check(season.career.balance() == 15, "remaining common funds pay for the exact spectator chair")
	await _pick_copy(app, copy, 3)
	_check(_paid_choice(app, copy).get_item_text(3) == "SC-L3",
		"newly available third socket appears only after land is owned")
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "expanded-property-seating")
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _bounds(app, "expanded-small-window")
	get_window().size = Vector2i(1280, 720)
	var saved: Dictionary = SeasonSave.snapshot(season)
	var forged: Dictionary = saved.duplicate(true)
	forged.home_property.tier = "club"
	forged.home_property.geometry = StadiumHomeLayout.geometry("club", forged.home_property.layout)
	_check(SeasonSave._decode(forged) == null, "unpaid property tier cannot replace the frozen field")
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.buy_land(season, "club",
		ClubPlayers.assets(season.career).revision()).ok, "drafting locks property transactions")
	var fixture: Dictionary = {}
	for candidate: Dictionary in season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
	_check(app.lab != null, "actual home game installs the purchased property")
	if app.lab != null:
		var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
		_check(property.tier == "expanded" and property.objects[copy].position == Vector3(-24, 0, 14),
			"real game uses exact expanded land and unchanged third-socket coordinates")
		_check(property.field.back_wall_z_m == 23.4 and property.objects.size() == 1,
			"expanded land neither stretches play nor places free items")
		await _frames(4)
		app._close_match()
	_check(SeasonSave.restore() != null
		and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"restart preserves exact expanded ownership and field")
	app.queue_free()
	await _frames()
	_completed_expansion()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro land UI checks passed: confirmation, atomic expansion, third site and restart.")
	get_tree().quit(0 if _failures == 0 else 1)


func _land_button(app: SeasonApp, tier: String) -> Button:
	for button: Button in app.menu._body.find_children("*", "Button", true, false):
		if button.get_meta("stadium_land", "") == tier:
			return button
	return null


func _completed_expansion() -> void:
	var season: SeasonState = _fund_seating()
	var previous: Dictionary = season.home_property.duplicate(true)
	_check(ClubConstruction.buy_land(season, "expanded", 4).ok,
		"completed season may buy next season's property")
	_check(season.home_property == previous and SeasonSave.restore() != null,
		"completed season's historical field is never retroactively expanded")
