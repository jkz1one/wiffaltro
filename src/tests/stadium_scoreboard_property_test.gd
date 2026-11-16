extends "res://src/tests/stadium_scoreboard_layout_test.gd"
## Complete isolated assembly, including recovery and actual match-bound display lifecycle.

var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_fund()
	var original: Array = [_stock.to_data(), _pieces.to_data(), _boards.to_data()]
	for shape: String in ["straight", "deeper_center", "offset_gables", "left_loft", "right_shelf"]:
		for item: String in StadiumScoreboardCatalog.IDS:
			await _assembly(shape, item)
	_check(ClubCareer.same(original, [_stock.to_data(), _pieces.to_data(), _boards.to_data()]),
		"all complete assemblies preserve caller ownership")
	_recovery()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro owned scoreboard properties passed: complete assembly, bindings and recovery.")
	get_tree().quit(0 if _failures == 0 else 1)


func _layout(shape: String, item: String) -> Dictionary:
	var layout: Dictionary = _base()
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}]
	if shape in ["straight", "deeper_center"]:
		layout.walls = StadiumWallLayout.propose(layout.walls, _stock, "back", "ST-024", shape).walls
	else:
		layout.advanced_back = StadiumAdvancedWallManifest.suggest(
			shape, "ST-024", _stock, _pieces.stock).manifest
	layout = StadiumScoreboardLayout.upgrade(layout)
	layout.scoreboards = [_row(item, "BOARD-LARGE-v2" if item == "ST-040" else "BOARD-RIGHT-v2")]
	return layout


func _assembly(shape: String, item: String) -> void:
	var layout: Dictionary = _layout(shape, item)
	var property: StadiumScoreboardPropertyGeometry = StadiumScoreboardPropertyGeometry.new()
	add_child(property)
	_check(property.build_scoreboards("mogul", layout, _stock, _pieces, _boards, ACCESS),
		"complete exact property assembles: " + shape + item)
	var row: Dictionary = layout.scoreboards[0]
	var model: Node3D = property.board_objects[row.copy]
	_check(property.objects[row.copy] == model and model.get_meta("owned_copy") == row.copy
		and model.get_meta("site") == row.site and model.get_meta("scoreboard_owned_model") == row.model,
		"complete object map binds exact ownership/model/site")
	_check(model.transform.is_equal_approx(StadiumScoreboardSites.pose(row.site))
		and model.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"new decorative board has exact transform and no live collision budget")
	var checked: Dictionary = _validate(layout)
	_check(property.objects.size() == checked.placements.size() + checked.board_placements.size(),
		"no duplicated base/board objects")
	var baseline: StadiumAdvancedPropertyGeometry = StadiumAdvancedPropertyGeometry.new()
	add_child(baseline)
	_check(baseline.build_owned("mogul", StadiumScoreboardLayout.base(layout),
		_stock, _pieces, ACCESS), "matching populated inherited field assembles")
	_check(property.route_obstacles().size() == 3
		and ClubCareer.same(property.route_obstacles(), baseline.route_obstacles()),
		"new board filtering preserves every live obstacle copy, center and radius")
	baseline.free()
	_check(property.get_meta("property_signature") == StadiumScoreboardLayout.geometry("mogul")
		and property.get_meta("scoreboard_models") == StadiumScoreboardModels.signature(),
		"assembly binds the new geometry without impersonating old models")
	_bindings(property, row.copy)
	var record: Dictionary = {"layout": property.get_meta("scoreboard_layout"),
		"stock": property.get_meta("advanced_stock"), "pieces": property.get_meta("advanced_pieces"),
		"boards": property.get_meta("scoreboard_inventory"),
		"access": property.get_meta("advanced_surface_access")}
	record = JSON.parse_string(JSON.stringify(record))
	var restored: StadiumScoreboardPropertyGeometry = StadiumScoreboardPropertyGeometry.new()
	add_child(restored)
	var access: Array[String] = []
	access.assign(record.access)
	_check(restored.build_scoreboards("mogul", record.layout,
		StadiumStock.from_data(record.stock), StadiumWallPieceOwnership.from_data(record.pieces),
		StadiumScoreboardOwnership.from_data(record.boards), access),
		"full JSON ownership/layout/access record reconstructs the exact assembly")
	_check(restored.board_objects[row.copy].transform.is_equal_approx(model.transform)
		and ClubCareer.same(restored.boundary.get_meta("advanced_manifest", {}),
			property.boundary.get_meta("advanced_manifest", {}))
		and ClubCareer.same(restored.route_obstacles(), property.route_obstacles()),
		"restored board, boundary manifest and live obstacle routes remain exact")
	restored.free()
	_check(not property.build_scoreboards("mogul", layout, _stock, _pieces, _boards, ACCESS),
		"repeat build cannot append another board or boundary")
	await _capture_property(property, shape, item)
	property.free()
	await get_tree().process_frame


func _bindings(property: StadiumScoreboardPropertyGeometry, copy: String) -> void:
	var state: MatchState = MatchLabSupport.create_match(PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD")
	state.inning = 4
	state.home_team.runs = 5
	state.away_team.runs = 3
	state.balls = 2
	state.strikes = 1
	state.outs = 2
	state.last_event = "A double brings home two"
	property.rebind_displays(state)
	var display: StadiumScoreboardTierDisplay = (
		property.board_objects[copy].get_node("Visual/ScoreDisplay"))
	_check(display.shown.home == 5 and display.details.balls == "2", "every board receives live data")
	state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	state.home_team.runs = 6
	state.balls = 3
	display._process(0)
	_check(display.shown.home == 5 and display.details.balls == "2", "all readouts hold during flight")
	state.phase = MatchState.Phase.PRE_PITCH
	display._process(0)
	_check(display.shown.home == 6 and display.details.balls == "3", "safe phase releases held data")
	property.rebind_displays(null)
	_check(display.shown.is_empty() and display._labels.home.text == "—", "unbind clears old match")
	var next: MatchState = MatchLabSupport.create_match(PitchBatLab.DEBUG_PLAYER_ID, "NEW", "CLUB")
	next.phase = MatchState.Phase.BALL_IN_PLAY
	property.rebind_displays(next)
	_check(display._match == next and display.shown.home == 0, "restart never leaks prior-match score")
	property.rebind_displays(state)


class InterruptedBoard extends StadiumScoreboardPropertyGeometry:
	var builds: int = 0

	func _make_board(row: Dictionary) -> Node3D:
		builds += 1
		return null if builds == 2 else super._make_board(row)


class InterruptedSurface extends StadiumScoreboardPropertyGeometry:
	var interrupted: bool = true

	func _surface(graph: StadiumRecipeBoundary, layout: Dictionary, stock: StadiumStock) -> bool:
		if interrupted:
			interrupted = false
			return false
		return super._surface(graph, layout, stock)


func _recovery() -> void:
	var layout: Dictionary = _layout("left_loft", "ST-040")
	layout.scoreboards.append(_row("ST-090", "BOARD-RIGHT-v2"))
	var original_quality: Dictionary = _quality()
	var keeper: StadiumAdvancedPropertyGeometry = StadiumAdvancedPropertyGeometry.new()
	add_child(keeper)
	_check(keeper.build_owned("mogul", StadiumScoreboardLayout.base(layout),
		_stock, _pieces, ACCESS), "independent quality owner remains alive during recovery")
	var retained_quality: Dictionary = _quality()
	if DisplayServer.get_name() != "headless":
		_check(not retained_quality.owners.is_empty(), "native quality lease is actually present")
	var property: InterruptedBoard = InterruptedBoard.new()
	add_child(property)
	property.set_meta("caller_tag", "preserved")
	var msaa: int = get_viewport().msaa_3d
	_check(not property.build_scoreboards("mogul", layout, _stock, _pieces, _boards, ACCESS),
		"second-board failure occurs after a whole field and first board were allocated")
	_check(property.get_child_count() == 0 and property.objects.is_empty()
		and property.board_objects.is_empty() and property.boundary == null and property.field == null
		and property.tier.is_empty() and property.get_meta("caller_tag") == "preserved"
		and get_viewport().msaa_3d == msaa
		and ClubCareer.same(retained_quality, _quality()),
		"late failure clears scene/state and releases only its render-quality owner")
	for key: StringName in [&"property_signature", &"advanced_layout", &"advanced_stock",
		&"advanced_pieces", &"advanced_surface_access", &"scoreboard_layout", &"scoreboard_inventory"]:
		_check(not property.has_meta(key), "failed assembly leaves no misleading owned metadata")
	_check(property.build_scoreboards("mogul", layout, _stock, _pieces, _boards, ACCESS)
		and property.board_objects.size() == 2, "same object can retry cleanly after late failure")
	property.free()
	_check(get_viewport().msaa_3d == msaa and ClubCareer.same(retained_quality, _quality()),
		"successful retry releases its lease while preserving the independent owner")
	property = InterruptedBoard.new()
	_check(not property.build_scoreboards("mogul", {}, _stock, _pieces, _boards, ACCESS)
		and property.get_child_count() == 0, "invalid declarations allocate no partial scene")
	property.free()

	var surface: InterruptedSurface = InterruptedSurface.new()
	add_child(surface)
	_check(not surface.build_scoreboards("mogul", layout, _stock, _pieces, _boards, ACCESS)
		and surface.get_child_count() == 0 and surface.objects.is_empty()
		and get_viewport().msaa_3d == msaa and ClubCareer.same(retained_quality, _quality()),
		"base-stage rollback is not applied twice and preserves the independent owner")
	_check(surface.build_scoreboards("mogul", layout, _stock, _pieces, _boards, ACCESS),
		"same object retries after an inherited surface failure")
	surface.free()
	_check(ClubCareer.same(retained_quality, _quality()), "surface retry releases its own lease")
	keeper.free()
	_check(ClubCareer.same(original_quality, _quality()),
		"last owner restores exact initial quality state")


func _quality() -> Dictionary:
	return {"msaa": get_viewport().msaa_3d,
		"owners": get_viewport().get_meta(StadiumWallRenderQuality.META, {}).duplicate(true)}


func _capture_property(property: Node3D, shape: String, item: String) -> void:
	if _capture_dir.is_empty() or shape not in StadiumAdvancedWallManifest.SHAPES:
		return
	_check(DisplayServer.get_name() != "headless", "requested captures need native rendering")
	if DisplayServer.get_name() == "headless":
		return
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("263b37")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.7
	property.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	property.add_child(light)
	var camera: Camera3D = Camera3D.new()
	property.add_child(camera)
	camera.position = Vector3(-28, 38, -22)
	camera.look_at(Vector3(8 if item == "ST-040" else 0, 5, 16))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 66
	camera.current = true
	for frame in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(
		"scoreboard-owned-%s-%s.png" % [shape, item])) == OK, "native complete-field capture saved")
