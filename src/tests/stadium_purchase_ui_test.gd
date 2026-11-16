extends "res://src/tests/stadium_editor_ui_test.gd"
## Synthetic season income, real saved purchases/editor input and frozen match installation.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://stadium-purchase-ui-%d.json" % OS.get_process_id()
	var path: String = SeasonSave.path
	var season: SeasonState = _new()
	_finish(season, "champion")
	_check(SeasonSave.save(season), "synthetic completed bracket earns its normal validated receipt")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	season = app.season
	StadiumEditorUI.show(app.menu)
	_check(ClubPlayers.assets(season.career).revision() == 1
		and ClubPlayers.assets(season.career).to_data().events[0].op == "stadium_pennant",
		"first championship adds one earned pennant before construction purchases")
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(not ClubConstruction.buy_copy(season, "ST-001", 0).ok
		and ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes,
		"pre-award purchase revision rejects without spending or saved mutation")
	SeasonSave.path = path + "/missing/file.json"
	await _click(_buy_button(app, "ST-001"))
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes,
		"failed copy payment preserves profile and funds")
	SeasonSave.path = path
	await _click(_buy_button(app, "ST-001"))
	_check(season.career.balance() == 180 and ClubPlayers.assets(season.career).revision() == 2,
		"real purchase button saves one 40-CB cone")
	_check(ClubConstruction.buy_copy(season, "ST-001", 1).replayed
		and season.career.balance() == 180, "double-click receipt cannot charge twice")
	await _click(_buy_button(app, "ST-003"))
	await _click(_buy_button(app, "ST-079"))
	_check(season.career.balance() == 100 and
		ClubPlayers.assets(season.career).construction().copies.size() == 7,
		"three paid extras retain all three starter copies and the earned pennant")
	_check(ClubPlayers.transact(season, {"id": "pack", "rev": 4, "op": "player_pack_open",
		"through": 1, "price_version": ClubPlayerCatalog.PRICE_VERSION}).ok,
		"same remaining Club Bucks can pay for a player pack")
	StadiumEditorUI.show(app.menu)
	_check(_buy_button(app, "ST-001").disabled and season.career.balance() == 20,
		"shop shows insufficient funds after shared pack spending")
	await _choose(app, "ST-001", 1)
	await _pick_copy(app, "purchase:stadium-buy:1:0", 2)
	await _choose(app, "ST-003", _live_site_index("ST-003", "O-R1"))
	await _pick_copy(app, "purchase:stadium-buy:2:0", _live_site_index("ST-003", "O-R2"))
	await _pick_copy(app, "purchase:stadium-buy:3:0", 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(ClubCareer.same(ledger.to_data().events[0], before.career.assets.events[0]),
		"paid copies, pack and placement retain original earned-pennant event")
	_check(ledger.view().stadium_active.obstacles.size() == 4
		and ledger.view().stadium_active.receiver == "purchase:stadium-buy:3:0",
		"four exact live copies and the paid receiver apply from actual editor input")
	_check(ledger.view().stadium_active.obstacles == [
		{"copy":"starter-v1:ST-001","site":"O-L1","yaw":0},
		{"copy":"purchase:stadium-buy:1:0","site":"O-L2","yaw":0},
		{"copy":"starter-v1:ST-003","site":"O-R1","yaw":0},
		{"copy":"purchase:stadium-buy:2:0","site":"O-R2","yaw":0}],
		"keyboard preserves all four original exact live sites and zero yaws")
	_check(_preview(app).positions.size() == 5, "preview renders all five exact placed copies")
	await _bounds(app, "stadium-paid-shop")
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "stadium-paid-copies")
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "stadium-paid-small")
	get_window().size = Vector2i(1280, 720)
	app.begin_season(71, true)
	season = app.season
	_check(season.home_property.version == 3 and SeasonSave.restore() != null,
		"next owned Working season freezes exact paid-copy inventory")
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	var bad: Dictionary = SeasonSave.snapshot(season)
	bad.home_property.inventory.copies.erase("purchase:stadium-buy:1:0")
	_check(SeasonSave._decode(bad) == null, "paid ownership tampering rejects whole saved field")
	bad = SeasonSave.snapshot(season)
	_check(bad.career.assets.events[1].op == "stadium_buy", "quantity tamper targets paid event")
	bad.career.assets.events[1].quantity = 2
	_check(SeasonSave._decode(bad) == null, "purchase amount cannot change underneath frozen proof")
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.buy_copy(season, "ST-079", ledger.revision()).ok,
		"purchase route locks with active season editing")
	var fixture: Dictionary = {}
	for candidate: Dictionary in season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	app._open_match(state, true, true)
	_check(app.lab != null and app.lab.has_meta("stadium_snapshot"),
		"actual human match installs the paid-copy frozen property")
	if app.lab != null:
		var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
		_check(property.objects.size() == 5 and property.objects.has("purchase:stadium-buy:1:0")
			and property.objects.has("purchase:stadium-buy:3:0"), "live field uses exact owned instances")
		await _frames(4)
		app._close_match()
	_check(SeasonSave.restore() != null and
		StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"game entry and exit do not alter paid field identity")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro stadium purchase UI checks passed: "
			+ "atomic payment, exact placement and restart.")
	get_tree().quit(0 if _failures == 0 else 1)


func _buy_button(app: SeasonApp, id: String) -> Button:
	for button: Button in app.menu._body.find_children("*", "Button", true, false):
		if button.get_meta("stadium_buy", "") == id:
			return button
	return null


func _paid_choice(app: SeasonApp, copy: String) -> OptionButton:
	for option: OptionButton in app.menu._body.find_children("*", "OptionButton", true, false):
		if option.get_meta("stadium_copy", "") == copy:
			return option
	return null


func _pick_copy(app: SeasonApp, copy: String, index: int) -> void:
	await _frames()
	var option: OptionButton = _paid_choice(app, copy)
	_check(option != null and not option.disabled, "paid copy has its own placement control")
	if option == null or option.disabled:
		return
	_check(index >= 0 and index < option.item_count and not option.is_item_disabled(index),
		"requested exact paid-copy site is enabled")
	if index < 0 or index >= option.item_count or option.is_item_disabled(index):
		return
	var allowed: Array[int] = []
	for item in range(option.item_count):
		if not option.is_item_disabled(item) or item == option.selected:
			allowed.append(item)
	var previous: int = allowed.find(option.selected)
	var target: int = allowed.find(index)
	option.grab_focus()
	await _frames()
	await _key(KEY_ENTER)
	for step in range(absi(target - previous)):
		await _key(KEY_DOWN if target > previous else KEY_UP)
	await _key(KEY_ENTER)
	await _frames()
	_check(_paid_choice(app, copy).selected == index, "keyboard places the requested purchased copy")


func _choose(app: SeasonApp, id: String, index: int, yaw: bool = false) -> void:
	# Occupied sites are disabled and keyboard navigation skips them.
	await _frames()
	var option: OptionButton = _choice(app, id, yaw)
	_check(option != null and not option.disabled, "requested placement control is available")
	if option == null or option.disabled:
		return
	_check(index >= 0 and index < option.item_count and not option.is_item_disabled(index),
		"requested exact starter site is enabled")
	if index < 0 or index >= option.item_count or option.is_item_disabled(index):
		return
	var allowed: Array[int] = []
	for item in range(option.item_count):
		if not option.is_item_disabled(item) or item == option.selected:
			allowed.append(item)
	var previous: int = allowed.find(option.selected)
	var target: int = allowed.find(index)
	option.grab_focus()
	await _frames()
	await _key(KEY_ENTER)
	for step in range(absi(target - previous)):
		await _key(KEY_DOWN if target > previous else KEY_UP)
	await _key(KEY_ENTER)
	await _frames()
	_check(_choice(app, id, yaw).selected == index, "actual keyboard chooses requested placement")
	_check(_choice(app, id, yaw).has_focus(), "keyboard focus follows rebuilt placement control")


func _live_site_index(item: String, site: String) -> int:
	var choices: Array[Dictionary] = StadiumSmallYardSceneryItemsUI.choices(item)
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		if choice.mode == "live" and choice.site == site and choice.yaw == 0:
			return index
	_check(false, "original exact live site and zero yaw still exist")
	return -1
