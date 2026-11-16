extends "res://src/tests/stadium_net_ui_test.gd"
## Paid light placement, storage, atomic failure and real day/night home installation.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://lights-ui-%d.json" % OS.get_process_id()
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
	_check(ClubPlayers.assets(season.career).revision() == 4,
		"four earned pennants precede the paid pole journal")
	_check(not ClubConstruction.buy_copy(season,"ST-037",0).ok
		and ClubCareer.same(before,SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes,
		"pre-award stale revision cannot acquire a pole or mutate saved funds")
	SeasonSave.path = path + "/missing/file.json"
	await _click(_buy_button(app, "ST-037"))
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes, "failed pole payment changes nothing")
	SeasonSave.path = path
	for index in range(5):
		await _click(_buy_button(app, "ST-037"))
	_check(season.career.balance() == starting - 625, "blueprint and five exact paid copies")
	for index in range(4):
		await _pick_copy(app, "purchase:stadium-buy:%d:0" % (4 + index), index + 1)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(season.home_property.layout.version == 9
		and season.home_property.layout.lights.size() == 4, "four paid poles applied")
	await _click(_button(app.menu, "DAY / NIGHT PREVIEW"))
	_check(_preview(app).night_preview, "qualified draft night preview activates")
	await _click(_button(app.menu, "DAY / NIGHT PREVIEW"))
	_check(not _preview(app).night_preview, "day preview restores")
	await _click(_focus_button(app, "purchase:stadium-buy:4:0"))
	await _bounds(app, "owned-yard-light-focus")
	await _pick_copy(app, "purchase:stadium-buy:8:0", 1)
	_check(_paid_choice(app, "purchase:stadium-buy:4:0").selected == 0,
		"occupied socket replacement stores original copy")
	await _click(_button(app.menu, "RELOAD SAVED"))
	await _pick_copy(app, "purchase:stadium-buy:4:0", 0)
	await _bounds(app, "yard-lost-night-eligibility")
	await _click(_button(app.menu, "RELOAD SAVED"))
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _click(_button(app.menu, "FIELD VIEW"))
	await _bounds(app, "yard-small-window")
	get_window().size = Vector2i(1280, 720)
	var forged: Dictionary = SeasonSave.snapshot(season)
	forged.home_property.version = 5
	forged.home_property["environment"] = StadiumFixtureEnvironment.capture(
		forged.home_property, 96, 0)
	_check(SeasonSave._decode(forged) == null, "fixture environment cannot replace season entry")
	var key: String = StadiumLayoutSnapshot.key(season.home_property)
	for pick in range(4):
		app.choose_player(season.offers()[0])
	_check(not ClubConstruction.buy_copy(season, "ST-037",
		ClubPlayers.assets(season.career).revision()).ok, "pole purchases lock during season")
	var modes: Array[String] = []
	for fixture: Dictionary in season.schedule:
		if fixture.home != 0:
			continue
		var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
		var mode: String = state.stadium.environment.mode
		if modes.has(mode):
			continue
		modes.append(mode)
		app._open_match(state, true, true)
		_check(app.lab != null, "actual owned-light home opens")
		if app.lab != null:
			_check(app.lab.get_meta("stadium_environment") == mode, "frozen mode installed")
			var mesh: MeshInstance3D = app.lab._pitch_actor.get_node("DebugBall")
			_check((mesh.material_override is ShaderMaterial) == (mode == "night")
				and _original_ball_shell(mesh),
				"night rim preserves authored pitch shell and exact radius; daylight material stays original")
			var property: StadiumPropertyGeometry = app.lab.get_meta("stadium_property")
			_check(property.objects.size() == 4 and property.route_obstacles().is_empty(),
				"four installed poles, no stored spare or tactical obstacle")
			for model: Node3D in property.objects.values():
				_check(model.get_node("FieldLight").visible == (mode == "night"),
					"spotlights only activate for frozen night games")
			await _frames(4)
			await _capture(get_viewport(), "owned-yard-" + mode)
			app._close_match()
	_check(modes.has("day") and modes.has("night"), "schedule retains day and night starts")
	_check(SeasonSave.restore() != null
		and StadiumLayoutSnapshot.key(SeasonSave.restore().home_property) == key,
		"fixture environments do not mutate saved season ownership")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro lights UI checks passed: paid sockets, storage and frozen day/night homes.")
	get_tree().quit(0 if _failures == 0 else 1)


func _original_ball_shell(mesh: MeshInstance3D) -> bool:
	if not mesh is WiffleBallVisual or not mesh.authored_mesh() or mesh.scale != Vector3.ONE:
		return false
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return false
	var outer: float = 0.0
	var inner: float = INF
	for vertex: Vector3 in vertices:
		var radius: float = vertex.length()
		if not is_finite(radius):
			return false
		outer = maxf(outer,radius)
		inner = minf(inner,radius)
	return is_equal_approx(outer,0.075) and is_equal_approx(inner,0.0725)
