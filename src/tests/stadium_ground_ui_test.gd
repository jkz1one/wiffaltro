extends "res://src/tests/stadium_styles_ui_test.gd"
## Actual ground unlocks, exclusive selection, failed save and real-game activation.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://ground-ui-%d.json" % OS.get_process_id()
	_fund_seating()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(94, true)
	var season: SeasonState = app.season
	var copies: Dictionary = ClubPlayers.assets(season.career).construction().copies.duplicate(true)
	_check(ClubPlayers.assets(season.career).revision() == 4 and copies.size() == 7,
		"four earned pennants precede the paid ground unlock")
	StadiumEditorUI.show(app.menu)
	await _click(_style_buy(app, "ST-063e"))
	_check(season.career.balance() == 645
		and ClubConstruction.buy_style(season, "ST-063e", 4).replayed,
		"real worn-ground button charges 160 once")
	var path: String = SeasonSave.path
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/file.json"
	await _click(_style_buy(app, "ST-063f"))
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes, "failed payment keeps exact profile and file")
	SeasonSave.path = path
	await _click(_style_buy(app, "ST-063f"))
	await _click(_style_buy(app, "ST-063a"))
	_check(season.career.balance() == 175, "clay and grass use the same earned wallet")
	_check(ClubCareer.same(copies,ClubPlayers.assets(season.career).construction().copies),
		"ground unlocks preserve every exact starter and earned copy")
	await _pick_style(app, "ground", 1)
	await _pick_style(app, "grass", 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(season.home_property.layout.version == 5
		and season.home_property.layout.ground == "ST-063e", "exact worn ground applied")
	await _pick_style(app, "ground", 2)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(season.home_property.layout.ground == "ST-063f"
		and season.career.balance() == 175, "clay replaces worn ground without another payment")
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "owned-ground-property")
	await _pick_style(app, "ground", 0)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(season.home_property.layout.ground.is_empty()
		and ClubPlayers.assets(season.career).construction().styles.has("ST-063f"),
		"clearing a treatment does not consume its permanent unlock")
	await _pick_style(app, "ground", 2)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "owned-ground-small-window")
	get_window().size = Vector2i(1280, 720)
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.buy_style(season, "ST-063i",
		ClubPlayers.assets(season.career).revision()).ok, "ground purchases lock after drafting")
	var fixture: Dictionary = {}
	for candidate: Dictionary in season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
	_check(app.lab != null, "real home match accepts exact ground snapshot")
	if app.lab != null:
		var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
		var ground: Node = property.get_node("GroundTreatment")
		_check(ground.get_meta("ground_style") == "ST-063f"
			and ground.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"real match renders selected surface with no new physics")
		_check(property.get_node("Safe").visible and property.get_node("Deep").visible,
			"real match keeps required scoring guides")
		await _frames(4)
		app._close_match()
	_check(SeasonSave.restore() != null
		and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"restart retains exact ground ownership and selection")
	app.queue_free()
	await _frames()
	await _legacy_ground()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro ground UI checks passed: purchases, swaps, save safety and actual field.")
	get_tree().quit(0 if _failures == 0 else 1)


func _legacy_ground() -> void:
	_fund_seating()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(99, true, true, true, false)
	var season: SeasonState = app.season
	_check(not season.home_property.has("boundary"), "old season retains its original boundary")
	_check(ClubConstruction.buy_style(season, "ST-063e", 4).ok, "old season can store a ground unlock")
	var layout: Dictionary = StadiumGroundStyles.upgrade(StadiumStarterLayout.empty())
	layout.ground = "ST-063e"
	_check(ClubConstruction.save_draft(season, layout, 5).ok, "next-season ground can be staged")
	var before: Dictionary = SeasonSave.snapshot(season)
	_check(not ClubConstruction.apply_draft(season, layout, 6).ok
		and ClubCareer.same(before, SeasonSave.snapshot(season)),
		"ground upgrade cannot silently add a new boundary to an older season")
	StadiumEditorUI.show(app.menu)
	_check(_button(app.menu, "APPLY LAYOUT").disabled, "old field clearly disables incompatible Apply")
	_check(SeasonSave.restore() != null, "future ground draft preserves old save validity")
	app.queue_free()
	await _frames()
