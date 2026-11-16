extends "res://src/tests/stadium_purchase_ui_test.gd"
## Synthetic funding, actual workshop input and versioned in-game/save installation.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://seating-ui-%d.json" % OS.get_process_id()
	var season: SeasonState = _fund_seating()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	season = app.season
	StadiumEditorUI.show(app.menu)
	await _click(_buy_button(app, "ST-080"))
	await _click(_buy_button(app, "ST-080"))
	await _click(_buy_button(app, "ST-027"))
	_check(season.career.balance() == 175, "actual shop charges blueprint once and exact copy prices")
	var first: String = "purchase:stadium-buy:4:0"
	var second: String = "purchase:stadium-buy:5:0"
	var bench: String = "purchase:stadium-buy:6:0"
	await _pick_copy(app, first, 1)
	await _pick_copy(app, second, 2)
	await _click(_button(app.menu, "SAVE DRAFT"))
	var saved: Dictionary = SeasonSave.snapshot(season)
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/file.json"
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(ClubCareer.same(saved, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes,
		"failed seating Apply preserves field and journal")
	SeasonSave.path = path
	await _click(_button(app.menu, "APPLY LAYOUT"))
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(ledger.view().stadium_active.version == 2
		and ledger.view().stadium_active.seating.size() == 2, "chairs apply through version-two grammar")
	await _pick_copy(app, bench, 1)
	_check(_paid_choice(app, first).selected == 0 and _paid_choice(app, second).selected == 0,
		"choosing a left bleacher stores both exact left chairs in the draft")
	_check(_paid_choice(app, first).is_item_disabled(1)
		and not _paid_choice(app, first).is_item_disabled(3),
		"only the occupied side's chair sites lock")
	await _pick_copy(app, first, 3)
	var preview: StadiumDraftPreview = _preview(app)
	_check(preview.positions.size() == 2 and preview.positions.has(first)
		and preview.positions.has(bench),
		"actual preview shows left bleacher and independent right chair")
	(app.menu._body.get_parent() as ScrollContainer).scroll_vertical = 0
	await _bounds(app, "seating-storage-preview")
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "seating-applied-property")
	await _pick_copy(app, bench, 0)
	_check(_paid_choice(app, second).selected == 0 and _paid_choice(app, first).selected == 3,
		"removing bleacher never restores old chairs or changes the opposite side")
	await _click(_button(app.menu, "RELOAD SAVED"))
	_check(_paid_choice(app, bench).selected == 1, "reload discards an unsaved seating removal")
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _bounds(app, "seating-small-window")
	get_window().size = Vector2i(1280, 720)
	app.begin_season(73, true)
	season = app.season
	var snapshot: Dictionary = season.home_property.duplicate(true)
	_check(snapshot.version == 3 and snapshot.layout.version == 2
		and snapshot.has("boundary"), "new season freezes versioned seating with complete boundaries")
	_check(snapshot.geometry != StadiumProperty.signature("backyard"),
		"new models cannot impersonate the legacy geometry signature")
	_tamper_layout(season)
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.save_draft(season, StadiumStarterLayout.empty(),
		ClubPlayers.assets(season.career).revision()).ok, "first draft pick locks seating too")
	var fixture: Dictionary = {}
	for candidate: Dictionary in season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
	_check(app.lab != null, "real human home game accepts the frozen seating")
	if app.lab != null:
		var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
		_check(property.objects.has(first) and property.objects.has(bench)
			and property.route_obstacles().is_empty(), "outside-play seating adds no live route obstacles")
		_check(app.lab._camera_director.tracking_visibility._uprights.is_empty(),
			"spectators and bleacher posts do not trigger the live-pole camera sidestep")
		_check(property.objects[bench].position == Vector3(-24, 0, 12.5),
			"workshop and actual game share the same measured placement")
		await _frames(4)
		app._close_match()
	_check(SeasonSave.restore() != null and StadiumLayoutSnapshot.key(
		SeasonSave.restore().home_property) == StadiumLayoutSnapshot.key(snapshot),
		"seating ownership and full field survive restart unchanged")
	app.queue_free()
	await _frames()
	await _legacy_seating()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro seating UI checks passed: shared shop, storage, applied geometry and restart.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fund_seating() -> SeasonState:
	var season: SeasonState = _new(71)
	for index in range(4):
		_finish(season, "champion")
		_check(SeasonSave.save(season), "synthetic completed history validates real seating access")
		if index < 3:
			var club: ClubCareer = season.career.fork()
			_check(club.close(season), "preserve completed proof")
			season = _new(72 + index, club)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(ledger.revision() == 4 and ledger.to_data().events.all(
		func(event: Dictionary) -> bool: return event.op == "stadium_pennant"),
		"four completed championships create four earned pennants before any paid seating")
	_check(ledger.construction().copies.size() == 7 and season.career.balance() == 805,
		"funding retains three starter copies, four earned pennants and exact ordinary rewards")
	return season


func _tamper_layout(season: SeasonState) -> void:
	var source: Dictionary = SeasonSave.snapshot(season)
	for bad_version: Variant in [true, "2", 2.5, null, 99]:
		var bad: Dictionary = source.duplicate(true)
		bad.home_property.layout.version = bad_version
		_check(SeasonSave._decode(bad) == null, "malformed seating layout version rejects cleanly")
	var bad: Dictionary = source.duplicate(true)
	bad.home_property.geometry = StadiumProperty.signature("backyard")
	_check(SeasonSave._decode(bad) == null, "seating cannot claim legacy model geometry")
	bad = source.duplicate(true)
	bad.home_property.layout.seating[0].site = "SC-R3"
	_check(SeasonSave._decode(bad) == null, "higher-tier chair socket stays locked")
	bad = source.duplicate(true)
	bad.home_property.version = 2
	bad.home_property.erase("boundary")
	_check(SeasonSave._decode(bad) == null, "seating cannot remove its protective boundary")


func _pick_copy(app: SeasonApp, copy: String, index: int) -> void:
	await _frames()
	var choice: OptionButton = _paid_choice(app, copy)
	_check(choice != null and not choice.disabled and not choice.is_item_disabled(index),
		"requested exact seating site is available")
	if choice == null or choice.disabled or choice.is_item_disabled(index):
		return
	var allowed: Array[int] = []
	for option in range(choice.item_count):
		if not choice.is_item_disabled(option):
			allowed.append(option)
	var previous: int = allowed.find(choice.selected)
	var target: int = allowed.find(index)
	choice.grab_focus()
	await _frames()
	await _key(KEY_ENTER)
	for step in range(absi(target - previous)):
		await _key(KEY_DOWN if target > previous else KEY_UP)
	await _key(KEY_ENTER)
	await _frames()
	_check(_paid_choice(app, copy).selected == index, "keyboard chooses the requested seating socket")


func _legacy_seating() -> void:
	_fund_seating()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(99, true, true, true, false)
	var season: SeasonState = app.season
	_check(not season.home_property.has("boundary"),
		"explicit legacy field remains the old template")
	_check(ClubConstruction.buy_copy(season, "ST-080", 4).ok,
		"old field may buy a stored seating copy")
	var layout: Dictionary = StadiumHomeLayout.upgrade(StadiumStarterLayout.empty())
	layout.seating = [{"copy": "purchase:stadium-buy:4:0", "site": "SC-L1"}]
	_check(ClubConstruction.save_draft(season, layout, 5).ok,
		"old field may stage next-season seating")
	var before: Dictionary = SeasonSave.snapshot(season)
	_check(not ClubConstruction.apply_draft(season, layout, 6).ok
		and ClubCareer.same(before, SeasonSave.snapshot(season)),
		"legacy season cannot activate scenery without the complete protective boundary")
	StadiumEditorUI.show(app.menu)
	_check(_button(app.menu, "APPLY LAYOUT").disabled,
		"legacy workshop explains and disables unsafe current-season seating activation")
	_check(SeasonSave.restore() != null, "staged future seating does not invalidate the old save")
	app.queue_free()
	await _frames()
