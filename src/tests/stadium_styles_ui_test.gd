extends "res://src/tests/stadium_seating_ui_test.gd"
## Actual purchases/selectors and saved rendering, using synthetic valid career funding.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://styles-ui-%d.json" % OS.get_process_id()
	_fund_seating()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(91, true)
	var season: SeasonState = app.season
	var copies: Dictionary = ClubPlayers.assets(season.career).construction().copies.duplicate(true)
	_check(ClubPlayers.assets(season.career).revision() == 4 and copies.size() == 7,
		"four earned pennants and three starter copies precede paid style unlocks")
	StadiumEditorUI.show(app.menu)
	await _click(_style_buy(app, "ST-062a"))
	_check(season.career.balance() == 690
		and ClubConstruction.buy_style(season, "ST-062a", 4).replayed,
		"actual chalk unlock charges 115 once")
	var path: String = SeasonSave.path
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/file.json"
	await _click(_style_buy(app, "ST-063a"))
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes, "failed style payment preserves the profile")
	SeasonSave.path = path
	await _click(_style_buy(app, "ST-063a"))
	_check(season.career.balance() == 490, "grass unlock uses the same Club Bucks")
	await _pick_style(app, "line", 1)
	await _pick_style(app, "grass", 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	var snapshot: Dictionary = season.home_property.duplicate(true)
	_check(snapshot.layout.version == 3 and snapshot.layout.styles.line == "ST-062a"
		and snapshot.layout.styles.grass == "ST-063a", "both exact appearance channels are applied")
	_check(ClubCareer.same(ClubPlayers.assets(season.career).construction().copies, copies),
		"visual unlocks do not fabricate item copies")
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "owned-field-styles")
	await _pick_style(app, "grass", 0)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(season.career.balance() == 490
		and ClubPlayers.assets(season.career).construction().styles.has("ST-063a"),
		"return to template is free and does not consume the unlock")
	await _pick_style(app, "grass", 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	await _click(_button(app.menu, "FIELD VIEW"))
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _bounds(app, "owned-styles-small-window")
	get_window().size = Vector2i(1280, 720)
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.buy_style(season, "ST-062b",
		ClubPlayers.assets(season.career).revision()).ok, "appearance purchases lock with drafting")
	var fixture: Dictionary = {}
	for candidate: Dictionary in season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
	_check(app.lab != null, "actual human game accepts the saved style profile")
	if app.lab != null:
		var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
		var visuals: Node = property.get_node("FieldStylePreview")
		_check(visuals.get_child_count() == 2
			and visuals.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"actual match renders both appearances without new collisions")
		_check(property.get_node("Safe").visible and property.get_node("Deep").visible,
			"actual match preserves the scoring guides")
		await _frames(4)
		app._close_match()
	_check(SeasonSave.restore() != null
		and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"restart retains exact style ownership and active presentation")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro style UI checks passed: "
			+ "purchases, free switching, saved preview and actual game.")
	get_tree().quit(0 if _failures == 0 else 1)


func _style_buy(app: SeasonApp, item: String) -> Button:
	for button: Button in app.menu._body.find_children("*", "Button", true, false):
		if button.get_meta("stadium_style_buy", "") == item:
			return button
	return null


func _style_choice(app: SeasonApp, channel: String) -> OptionButton:
	for choice: OptionButton in app.menu._body.find_children("*", "OptionButton", true, false):
		if choice.get_meta("stadium_style", "") == channel:
			return choice
	return null


func _pick_style(app: SeasonApp, channel: String, index: int) -> void:
	var choice: OptionButton = _style_choice(app, channel)
	_check(choice != null and not choice.disabled, "owned appearance selector is available")
	if choice == null or choice.disabled:
		return
	var previous: int = choice.selected
	choice.grab_focus()
	await _frames()
	await _key(KEY_ENTER)
	for step in range(absi(index - previous)):
		await _key(KEY_DOWN if index > previous else KEY_UP)
	await _key(KEY_ENTER)
	await _frames()
	_check(_style_choice(app, channel).selected == index, "keyboard selects the exact appearance")
