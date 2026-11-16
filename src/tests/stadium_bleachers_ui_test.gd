extends "res://src/tests/stadium_displays_ui_test.gd"
## Paid larger seating, independent sides, storage and real Club-ground match.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://bleachers-ui-%d.json" % OS.get_process_id()
	_fund_bleachers()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(95, true)
	var season: SeasonState = app.season
	var starting: int = season.career.balance()
	var funded: Dictionary = SeasonSave.snapshot(season)
	var funded_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	_check(not ClubConstruction.buy_land(season, "expanded", 0).ok
		and ClubCareer.same(funded, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(SeasonSave.path) == funded_bytes,
		"earned pennant revisions reject stale land purchase without mutation")
	_check(ClubConstruction.buy_land(season, "expanded", 20).ok, "actual Expanded prerequisite")
	_check(ClubConstruction.buy_land(season, "club", 21).ok, "actual Club prerequisite")
	_check(ClubConstruction.buy_copy(season, "ST-080", 22).ok, "one separately owned spectator chair")
	StadiumEditorUI.show(app.menu)
	var path: String = SeasonSave.path
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/file.json"
	await _click(_buy_button(app, "ST-028"))
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes, "failed larger seating payment is atomic")
	SeasonSave.path = path
	await _click(_buy_button(app, "ST-028"))
	await _click(_buy_button(app, "ST-075"))
	_check(season.career.balance() == starting - 3640
		and ClubConstruction.buy_copy(season, "ST-075", 24).replayed, "exact charges and safe retry")
	var chair: String = "purchase:stadium-buy:22:0"
	var aluminum: String = "purchase:stadium-buy:23:0"
	var roof: String = "purchase:stadium-buy:24:0"
	await _pick_copy(app, chair, 1)
	await _pick_copy(app, aluminum, 1)
	_check(_paid_choice(app, chair).selected == 0
		and _paid_choice(app, chair).is_item_disabled(1), "aluminum stores and excludes same-side chairs")
	await _pick_copy(app, roof, 2)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(season.home_property.layout.version == 6
		and season.home_property.layout.bleachers.size() == 2, "two independent complete assemblies")
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "owned-larger-seating-property")
	await _click(_focus_button(app, roof))
	await _bounds(app, "owned-roofed-bleacher-focus")
	_bleacher_focus_fits(app, roof, "ST-075")
	await _pick_copy(app, roof, 1)
	_check(_paid_choice(app, aluminum).selected == 0, "moving a roofed assembly stores old occupant")
	await _click(_button(app.menu, "RELOAD SAVED"))
	_check(_paid_choice(app, aluminum).selected == 1 and _paid_choice(app, roof).selected == 2,
		"reload discards unsaved replacement")
	await _pick_copy(app, aluminum, 0)
	_check(_paid_choice(app, chair).selected == 0 and not _paid_choice(app, chair).is_item_disabled(1),
		"removal reopens chairs without placing one automatically")
	await _click(_button(app.menu, "RELOAD SAVED"))
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "larger-seating-small-window")
	get_window().size = Vector2i(1280, 720)
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.buy_copy(season, "ST-028",
		ClubPlayers.assets(season.career).revision()).ok, "purchase locks with drafting")
	var fixture: Dictionary = {}
	for candidate: Dictionary in season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	app._open_match(SeasonPhysicalFixtures.match_for(season, fixture), true, true)
	_check(app.lab != null, "actual home match accepts Club ground and larger seating")
	if app.lab != null:
		var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
		_check(property.objects.size() == 2 and property.route_obstacles().is_empty(),
			"larger seating is not a live route obstacle")
		_check(app.lab._camera_director.tracking_visibility._uprights.is_empty(),
			"bleacher roof supports are not live-pole camera targets")
		await _frames(4)
		app._close_match()
	_check(SeasonSave.restore() != null
		and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"restart preserves exact copy identities and active arrangement")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro bleacher UI checks passed: paid assemblies, safe storage and actual field.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fund_bleachers() -> SeasonState:
	var season: SeasonState = _new(151)
	for index in range(20):
		_finish(season, "champion")
		_check(SeasonSave.save(season), "synthetic complete history validates advanced-seat access")
		if index < 19:
			var club: ClubCareer = season.career.fork()
			_check(club.close(season), "preserve synthetic completed proof")
			season = _new(152 + index, club)
	var assets: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(assets.revision() == 20 and assets.construction().copies.size() == 23
		and season.career.balance() == 3925,
		"twenty synthetic championships retain twenty pennants and exact funded wallet")
	for event: Dictionary in assets.to_data().events:
		_check(event.op == "stadium_pennant", "only earned pennant events precede purchases")
	return season


func _bleacher_focus_fits(app: SeasonApp, copy: String, item: String) -> void:
	var preview: StadiumDraftPreview = _preview(app)
	var camera: Camera3D = preview.camera
	var viewport: Rect2 = camera.get_viewport().get_visible_rect()
	var pose: Transform3D = Transform3D(Basis(Vector3.UP, PI * 1.5), preview.positions[copy])
	for index in range(8):
		var point: Vector3 = pose * StadiumBleacherModels.envelope(item).get_endpoint(index)
		_check(not camera.is_position_behind(point)
			and viewport.has_point(camera.unproject_position(point)), "focus fits the full roof and feet")
