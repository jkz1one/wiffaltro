extends "res://src/tests/stadium_target_ui_test.gd"
## Paid paired receiver, independent storage, save failure and real bound home installation.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://net-ui-%d.json" % OS.get_process_id()
	_fund_net()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(96, true)
	var season: SeasonState = app.season
	var starting: int = season.career.balance()
	StadiumEditorUI.show(app.menu)
	var path: String = SeasonSave.path
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(not ClubConstruction.buy_copy(season,"ST-025",0).ok
		and ClubCareer.same(before,SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes,
		"stale pre-award revision cannot acquire net or mutate saved funds")
	SeasonSave.path = path + "/missing/file.json"
	await _click(_buy_button(app, "ST-025"))
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes, "failed net payment changes nothing")
	SeasonSave.path = path
	await _click(_buy_button(app, "ST-025"))
	_check(season.career.balance() == starting - 390
		and ClubConstruction.buy_copy(season, "ST-025", 4).replayed, "first net pays 390 once")
	var net: String = "purchase:stadium-buy:4:0"
	_check(_paid_choice(app, net).is_item_disabled(1), "net-only installation disabled")
	await _click(_buy_button(app, "ST-026"))
	var target: String = "purchase:stadium-buy:5:0"
	await _click(_buy_button(app, "ST-025"))
	var spare: String = "purchase:stadium-buy:6:0"
	_check(season.career.balance() == starting - 780, "target independent and spare net copy-only")
	await _pick_copy(app, target, 1)
	await _pick_copy(app, net, 1)
	await _pick_copy(app, spare, 0)
	_check(_paid_choice(app, net).selected == 1, "stored spare reselect leaves active net intact")
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(season.home_property.layout.version == 8 and season.home_property.layout.net == net
		and season.home_property.layout.target == target, "exact separately paid pair is applied")
	await _click(_focus_button(app, net))
	await _net_focus(app, net)
	await _bounds(app, "owned-net-focus")
	await _pick_copy(app, net, 0)
	_check(_paid_choice(app, target).selected == 1, "net removal preserves installed target")
	await _click(_button(app.menu, "RELOAD SAVED"))
	await _pick_copy(app, target, 0)
	_check(_paid_choice(app, net).selected == 0, "target removal stores dependent net")
	await _click(_button(app.menu, "RELOAD SAVED"))
	await _pick_copy(app, "starter-v1:ST-079", 1)
	_check(_paid_choice(app, target).selected == 0 and _paid_choice(app, net).selected == 0,
		"chair replacement stores both receiver copies")
	await _click(_button(app.menu, "RELOAD SAVED"))
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "net-small-window")
	get_window().size = Vector2i(1280, 720)
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.buy_copy(season, "ST-025",
		ClubPlayers.assets(season.career).revision()).ok, "net purchase locks when drafting starts")
	var fixture: Dictionary = {}
	for candidate: Dictionary in season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
	_check(app.lab != null, "actual home game opens paired layout")
	if app.lab != null:
		var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
		var receiver: Node = property.get_node("PitchReceiverPresentation")
		_check(receiver is StadiumPairedReceiver and receiver.net == property.objects[net]
			and receiver.chair == property.objects[target], "real game uses both exact owned roots")
		_check(property.objects.size() == 2 and property.route_obstacles().size() == 2,
			"pair has two physical receiver obstacles and no hidden chair or spare")
		await _frames(4)
		app._close_match()
	_check(SeasonSave.restore() != null
		and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"save/restart binds exact paid pair geometry")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro net UI checks passed: separate purchases, safe removal and actual paired home.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fund_net() -> SeasonState:
	var helper: Node = load("res://src/tests/stadium_career_stats_test.gd").new()
	var season: SeasonState = _new(191)
	for index in range(4):
		while season.phase != SeasonState.Phase.COMPLETE:
			helper._record_stats(season)
		_check(SeasonSave.save(season), "synthetic closed pair funding and stats validate")
		if index < 3:
			var club: ClubCareer = season.career.fork()
			_check(club.close(season), "close synthetic funding season")
			season = _new(192 + index, club)
	_check(helper._failures == 0, "synthetic stat fixture checks pass")
	helper.free()
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(ledger.revision() == 4 and ledger.to_data().events.all(
		func(event: Dictionary) -> bool: return event.op == "stadium_pennant"),
		"four validated stat seasons journal four earned pennants before paired purchases")
	_check(ledger.construction().copies.size() == 7 and season.career.balance() == 805,
		"synthetic stat funding retains seven legitimate copies and exact805CB")
	return season


func _net_focus(app: SeasonApp, copy: String) -> void:
	var preview: StadiumDraftPreview = _preview(app)
	_check(preview != null, "workshop preview exists")
	if preview == null:
		return
	var box: AABB = StadiumNetModels.ENVELOPE
	box.position += StadiumNetModels.POSITION
	for corner in range(8):
		var point: Vector3 = box.get_endpoint(corner)
		_check(not preview.camera.is_position_behind(point)
			and preview.camera.get_viewport().get_visible_rect().has_point(
				preview.camera.unproject_position(point)), "every full-net corner fits focus view")
	_check(preview.positions.has(copy), "preview includes exact net copy")
