extends "res://src/tests/stadium_displays_ui_test.gd"
## Actual closed-stat target shop, primary replacement, save safety and real home-game install.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://target-ui-%d.json" % OS.get_process_id()
	_fund_target()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(96, true)
	var season: SeasonState = app.season
	StadiumEditorUI.show(app.menu)
	var path: String = SeasonSave.path
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(not ClubConstruction.buy_copy(season,"ST-026",0).ok
		and ClubCareer.same(before,SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes,
		"stale pre-award revision cannot acquire a target or mutate saved funds")
	SeasonSave.path = path + "/missing/file.json"
	await _click(_buy_button(app, "ST-026"))
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes, "failed target payment preserves exact profile")
	SeasonSave.path = path
	await _click(_buy_button(app, "ST-026"))
	_check(season.career.balance() == 115
		and ClubConstruction.buy_copy(season, "ST-026", 2).replayed, "actual target charges 300 once")
	await _click(_buy_button(app, "ST-026"))
	_check(season.career.balance() == 45, "second target pays copy-only seventy CB")
	var first: String = "purchase:stadium-buy:2:0"
	var spare: String = "purchase:stadium-buy:3:0"
	await _pick_copy(app, "starter-v1:ST-079", 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	await _pick_copy(app, first, 1)
	_check(_paid_choice(app, "starter-v1:ST-079").selected == 0,
		"target selection puts the old chair in storage")
	await _pick_copy(app, spare, 0)
	_check(_paid_choice(app, first).selected == 1,
		"reselecting stored spare does not remove active target")
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(season.home_property.layout.version == 7 and season.home_property.layout.target == first,
		"exact paid target-only snapshot applies")
	await _click(_focus_button(app, first))
	await _bounds(app, "owned-target-focus")
	await _pick_copy(app, "starter-v1:ST-079", 1)
	_check(_paid_choice(app, first).selected == 0, "chair replacement safely stores the target")
	await _click(_button(app.menu, "RELOAD SAVED"))
	_check(_paid_choice(app, first).selected == 1, "reload restores saved exact receiver identity")
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "target-small-window")
	get_window().size = Vector2i(1280, 720)
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.buy_copy(season, "ST-026",
		ClubPlayers.assets(season.career).revision()).ok, "target purchase locks with drafting")
	var fixture: Dictionary = {}
	for candidate: Dictionary in season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
	_check(app.lab != null, "real bound home game installs exact paid target")
	if app.lab != null:
		var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
		var receiver: Node = property.get_node("PitchReceiverPresentation")
		_check(receiver is StadiumTargetReceiver and receiver.chair == property.objects[first],
			"target uses its own post-call router and exact copy")
		_check(property.objects.size() == 1 and property.route_obstacles().size() == 1,
			"one physical receiver, no hidden catching net or old chair")
		_check(app.lab._camera_director.tracking_visibility._uprights.is_empty(),
			"target posts do not become live-pole camera triggers")
		await _frames(4)
		app._close_match()
	_check(SeasonSave.restore() != null
		and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"restart retains target price, ownership and frozen geometry")
	app.queue_free()
	await _frames()
	await _legacy_target()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro target UI checks passed: earned K gate, safe swaps and actual home field.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fund_target() -> SeasonState:
	var helper: Node = load("res://src/tests/stadium_career_stats_test.gd").new()
	var season: SeasonState = _new(191)
	for index in range(2):
		while season.phase != SeasonState.Phase.COMPLETE:
			helper._record_stats(season)
		_check(SeasonSave.save(season), "synthetic closed stats validate actual target eligibility")
		if index == 0:
			var club: ClubCareer = season.career.fork()
			_check(club.close(season), "close first synthetic stat season")
			season = _new(192, club)
	_check(helper._failures == 0, "synthetic stat fixtures remain valid")
	helper.free()
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(ledger.revision() == 2 and ledger.to_data().events.all(
		func(event: Dictionary) -> bool: return event.op == "stadium_pennant"),
		"two actual validated championships journal two pennants before paid targets")
	_check(ledger.construction().copies.size() == 5 and season.career.balance() == 415,
		"synthetic stat funding preserves five legitimate copies and exact415CB")
	return season


func _legacy_target() -> void:
	_fund_target()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(99, true, true, true, false)
	var season: SeasonState = app.season
	_check(ClubConstruction.buy_copy(season, "ST-026", 2).ok, "older field can store a paid target")
	var layout: Dictionary = StadiumTargetItems.upgrade(StadiumStarterLayout.empty())
	layout.target = "purchase:stadium-buy:2:0"
	_check(ClubConstruction.save_draft(season, layout, 3).ok, "next-season target can be staged")
	var before: Dictionary = SeasonSave.snapshot(season)
	_check(not ClubConstruction.apply_draft(season, layout, 4).ok
		and ClubCareer.same(before, SeasonSave.snapshot(season)),
		"target cannot silently add a new boundary to an older season")
	StadiumEditorUI.show(app.menu)
	_check(_button(app.menu, "APPLY LAYOUT").disabled, "old field explains incompatible Apply")
	_check(SeasonSave.restore() != null, "staged target does not invalidate old season")
	app.queue_free()
	await _frames()
