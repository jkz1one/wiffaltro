extends "res://src/tests/stadium_ground_ui_test.gd"
## Real paid base/ground selectors, independent patterns, failure atomicity and bound home scenes.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://infield-ui-%d.json" % OS.get_process_id()
	var completed: SeasonState = _fund_infield()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = completed
	app.begin_season(96, true)
	var season: SeasonState = app.season
	var starting: int = season.career.balance()
	StadiumEditorUI.show(app.menu)
	var path: String = SeasonSave.path
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/file.json"
	await _click(_style_buy(app, "ST-062c"))
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes, "failed base payment changes nothing")
	SeasonSave.path = path
	for id: String in StadiumInfieldStyles.PRICES:
		await _click(_style_buy(app, id))
	_check(ClubConstruction.buy_style(season, "ST-062c", 20).replayed,
		"base style retry cannot charge again")
	for id: String in ["ST-063a", "ST-063b", "ST-062b"]:
		await _click(_style_buy(app, id))
	for index in range(4):
		await _click(_buy_button(app, "ST-037"))
	_check(season.career.balance() == starting - 3520, "all styles and four poles pay exact prices")
	for index in range(4):
		await _pick_copy(app, "purchase:stadium-buy:%d:0" % (28 + index), index + 1)
	await _pick_style(app, "bases", 2)
	await _pick_style(app, "grass", 2)
	await _pick_style(app, "line", 1)
	for index in range(1, 4):
		await _pick_style(app, "ground", index)
		await _click(_button(app.menu, "SAVE DRAFT"))
		await _click(_button(app.menu, "APPLY LAYOUT"))
		_check(season.home_property.layout.version == 10
			and season.home_property.layout.ground == StadiumInfieldModels.IDS[index - 1]
			and season.home_property.layout.styles.grass == "ST-063b"
			and season.home_property.layout.bases == "ST-062d",
			"each footprint preserves independently selected grass and bases")
		await _click(_button(app.menu, "FIELD VIEW"))
		await _bounds(app, "owned-infield-" + StadiumInfieldModels.IDS[index - 1])
		if StadiumInfieldStyles.NIGHT_VERIFIED:
			await _click(_button(app.menu, "DAY / NIGHT PREVIEW"))
			_check(_preview(app).night_preview, "qualified footprint night preview activates")
			await _bounds(app, "owned-infield-night-" + StadiumInfieldModels.IDS[index - 1])
			await _click(_button(app.menu, "DAY / NIGHT PREVIEW"))
			var surface: MeshInstance3D = _preview(app).preview_property.get_node(
				"InfieldTreatment/SurfaceVisual")
			_check(not _preview(app).night_preview and surface.material_override.albedo_color == Color.WHITE,
				"day preview restores the original footprint palette")
	await _pick_style(app, "bases", 0)
	await _click(_button(app.menu, "RELOAD SAVED"))
	_check(season.home_property.layout.bases == "ST-062d", "unsaved removal cannot change applied set")
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "infield-small-window")
	get_window().size = Vector2i(1280, 720)
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.buy_style(season, "ST-063g",
		ClubPlayers.assets(season.career).revision()).ok, "infield construction locks after drafting")
	var fixture: Dictionary = {}
	for candidate: Dictionary in season.schedule:
		if candidate.home == 0 and StadiumFixtureEnvironment.is_night_seed(
			SeasonPhysicalFixtures.seed_for(season, candidate)):
			fixture = candidate
			break
	_check(not fixture.is_empty(), "fixture with a qualifying night draw exists")
	if not fixture.is_empty():
		app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
		_check(app.lab != null, "real game installs the exact paid infield")
		if app.lab != null:
			var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
			_check(property.get_node("InfieldTreatment").get_meta("ground_style") == "ST-063j"
				and property.get_node("BaseMarkerSet").get_child_count() == 3,
				"saved sand and complete marker set render in actual home")
			_check((app.lab.get_meta("stadium_environment") == "night")
				== StadiumInfieldStyles.NIGHT_VERIFIED, "only validated footprints enter night starts")
			await _frames(4)
			await _capture(get_viewport(), "owned-infield-home")
			app._close_match()
	_check(SeasonSave.restore() != null
		and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"save/reload retains the exact independently selected appearance")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro infield UI checks passed: paid channels, atomic storage and real home install.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fund_infield() -> SeasonState:
	var helper: Node = load("res://src/tests/stadium_bleachers_ui_test.gd").new()
	var completed: SeasonState = helper._fund_bleachers()
	_check(helper._failures == 0, "synthetic long closed career validates exact style gates")
	helper.free()
	var ledger: ClubAssetLedger = ClubPlayers.assets(completed.career)
	_check(ledger.revision() == 20 and ledger.to_data().events.all(
		func(event: Dictionary) -> bool: return event.op == "stadium_pennant"),
		"twenty completed synthetic championships retain twenty earned pennants")
	_check(ledger.construction().copies.size() == 23 and completed.career.balance() == 3925,
		"long funding retains exact ordinary3925CB and all23starter/earned copies")
	return completed
