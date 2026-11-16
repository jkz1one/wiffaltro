extends Node3D
## Isolated scoreboard artwork, literal bounds and the existing held-score contract.

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_binding_order()
	_sites()
	_interior_clearance()
	await _lineup_capture()
	for tier: String in StadiumScoreboardTiers.TIERS:
		var board: Node3D = StadiumScoreboardTiers.create(tier)
		add_child(board)
		_validate(board, tier)
		_live_data(board, tier)
		await _capture(board, tier)
		board.queue_free()
		await get_tree().process_frame
		await _field_capture(tier)
	_check(StadiumScoreboardTiers.create("unknown") == null, "unknown tiers fail closed")
	_check(
		StadiumCatalog.ROWS.size() == 101, "candidate art grants no catalog item or starter copy"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro scoreboard tiers passed: larger held readouts and distinct bounded art.")
	get_tree().quit(0 if _failures == 0 else 1)


func _sites() -> void:
	var old: AABB = StadiumClubSites.envelope("ST-039")
	_check(old.size == Vector3(5, 4, 2), "the old manual board reservation is unchanged")
	var left: StadiumHeightBoundary = StadiumHeightBoundary.candidate("left_loft")
	_check(
		not StadiumScoreboardTierSites.inspect("manual", "BOARD-LEFT-v1", "backyard", left).ok,
		"a tall left wall honestly rejects its obscured basic scoreboard"
	)
	_check(
		StadiumScoreboardTierSites.inspect("manual", "BOARD-RIGHT-v1", "backyard", left).ok,
		"an explicit opposite-side site preserves the basic board's authored dimensions"
	)
	for shape: String in ["straight", "deeper_center", "left_loft", "right_shelf"]:
		var graph: StadiumRecipeBoundary = (
			StadiumRecipeBoundary.create(shape)
			if shape in ["straight", "deeper_center"]
			else StadiumHeightBoundary.candidate(shape)
		)
		_check(
			(
				(
					StadiumScoreboardTierSites
					. inspect("electronic", "BOARD-LEFT-v1", "backyard", graph)
					. ok
				)
				== (shape != "left_loft")
			),
			"left-site electronic readout clearance: " + shape
		)
		_check(
			(
				StadiumScoreboardTierSites
				. inspect("electronic", "BOARD-RIGHT-v1", "backyard", graph)
				. ok
			),
			"right-site electronic readout clearance: " + shape
		)
		_check(
			StadiumScoreboardTierSites.inspect("video", "BOARD-LARGE-v1", "mogul", graph).ok,
			"large board fits its original mogul reservation and plate readout rays"
		)
	_check(
		not StadiumScoreboardTierSites.inspect("video", "BOARD-LARGE-v1", "club", left).ok,
		"large-board footprint cannot leak outside smaller property bounds"
	)
	_check(
		not StadiumScoreboardTierSites.inspect("video", "BOARD-LEFT-v1", "mogul", left).ok,
		"a different board cannot be stretched into another tier's site"
	)


func _validate(board: Node3D, tier: String) -> void:
	var bounds: AABB = StadiumScoreboardTiers.envelope(tier).grow(0.0001)
	_check(
		board.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"candidate art is not an unvalidated gameplay obstacle"
	)
	for mesh: MeshInstance3D in board.find_children("*", "MeshInstance3D", true, false):
		for index in range(8):
			_check(
				bounds.has_point(mesh.transform * mesh.get_aabb().get_endpoint(index)),
				"all authored mesh corners fit the explicit new envelope"
			)
	var display: StadiumScoreboardTierDisplay = board.get_node("Visual/ScoreDisplay")
	_check(
		display.present({"inning": 9999, "home": 9999, "away": 8888}, false), "long score accepted"
	)
	for key: String in display._labels:
		var label: Label3D = display._labels[key]
		var width: float = (
			label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
			if label.font != null
			else (
				ThemeDB
				. fallback_font
				. get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
				. x
			)
		)
		_check(
			width * label.pixel_size < StadiumScoreboardTiers.readouts(tier)[key].width,
			"four-digit maximum fits its number well without shrinking text"
		)
	_check(
		display.present({"inning": 100, "home": 1, "away": 2}, true) and display.shown.home == 9999,
		"active pitch holds the old numbers"
	)
	_check(
		(
			display.present({"inning": 100, "home": 1, "away": 2}, false)
			and display.shown.home == 1
			and display._labels.home.text == "1"
		),
		"safe phase releases new score"
	)
	_check(
		(
			not display.present({"inning": 1, "home": -1, "away": 2}, false)
			and not display.present({"inning": 1, "home": 10000, "away": 2}, false)
		),
		"invalid scores cannot reach the physical display"
	)
	display.present({"inning": 7, "home": 12, "away": 9}, false)


func _capture(board: Node3D, tier: String) -> void:
	if _capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	get_window().size = Vector2i(1280, 720)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("263b37")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.7
	board.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	board.add_child(light)
	var camera: Camera3D = Camera3D.new()
	board.add_child(camera)
	camera.position = Vector3(0.6, StadiumScoreboardTiers.spec(tier).height * 0.55, 19)
	camera.look_at(Vector3(0, StadiumScoreboardTiers.spec(tier).height * 0.52, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = StadiumScoreboardTiers.spec(tier).height * 1.15
	camera.current = true
	for frame in range(8):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output: String = _capture_dir.path_join("scoreboard-" + tier + ".png")
		_check(get_viewport().get_texture().get_image().save_png(output) == OK, "preview saved")


func _field_capture(tier: String) -> void:
	if _capture_dir.is_empty():
		return
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	var land: String = "mogul" if tier == "video" else "backyard"
	_check(
		property.build(land, StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"original property substrate for new candidate board study"
	)
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumHeightBoundaryBody = StadiumHeightBoundaryBody.new()
	property.add_child(boundary)
	_check(boundary.build("left_loft", "ST-065"), "full-scale tall-left wall comparison")
	var board: Node3D = StadiumScoreboardTiers.create(tier)
	var site: String = "BOARD-LARGE-v1" if tier == "video" else "BOARD-RIGHT-v1"
	var checked: Dictionary = StadiumScoreboardTierSites.inspect(tier, site, land, boundary.graph)
	_check(checked.ok, "native preview uses a qualified candidate site")
	if not checked.ok:
		property.free()
		return
	property.add_child(board)
	board.transform = checked.pose
	board.get_node("Visual/ScoreDisplay").bind_match(_sample_match())
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
	camera.look_at(Vector3(8 if tier == "video" else 0, 5, 16))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 58 if tier == "video" else 46
	camera.current = true
	var points: Array[Vector3] = []
	for point: Vector2 in boundary.graph.polygon():
		points.append(Vector3(point.x, 0, point.y))
	for corner in range(8):
		points.append(checked.bounds.get_endpoint(corner))
	for attempt in range(20):
		if _fits(camera, points):
			break
		camera.size *= 1.05
	_check(_fits(camera, points), "full field and board envelope fit the overview")
	for frame in range(8):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(
			(
				get_viewport().get_texture().get_image().save_png(
					_capture_dir.path_join("scoreboard-field-" + tier + ".png")
				)
				== OK
			),
			"full-scale field preview saved"
		)
	property.queue_free()
	await get_tree().process_frame


func _fits(camera: Camera3D, points: Array[Vector3]) -> bool:
	var rect: Rect2 = get_viewport().get_visible_rect().grow(-16)
	for point: Vector3 in points:
		if camera.is_position_behind(point) or not rect.has_point(camera.unproject_position(point)):
			return false
	return true


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _sample_match() -> MatchState:
	var state: MatchState = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD CLUB"
	)
	state.inning = 7
	state.home_team.runs = 12
	state.away_team.runs = 9
	state.balls = 2
	state.strikes = 1
	state.outs = 2
	state.last_event = "Rivets score on a double"
	return state


func _live_data(board: Node3D, tier: String) -> void:
	var display: StadiumScoreboardTierDisplay = board.get_node("Visual/ScoreDisplay")
	var state: MatchState = _sample_match()
	display.bind_match(state)
	_check(
		(
			display.shown.home == 12
			and display.details.balls == "2"
			and display.details.away_name == "RIVETS"
		),
		"new match binds actual score, count and names"
	)
	var old: Dictionary = display.details.duplicate(true)
	state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	state.home_team.runs = 13
	state.balls = 3
	state.last_event = "Newest logical event"
	display._process(0)
	_check(
		display.shown.home == 12 and display.details == old,
		"every readout holds during active pitch"
	)
	state.phase = MatchState.Phase.BALL_IN_PLAY
	display._process(0)
	_check(
		display.shown.home == 12 and display.details == old, "every readout holds during live ball"
	)
	state.phase = MatchState.Phase.PLAY_DEAD
	display._process(0)
	_check(
		(
			display.shown.home == 13
			and display.details.balls == "3"
			and display.details.event == state.last_event
		),
		"safe boundary releases one coherent current snapshot"
	)
	state.home_team.display_name = "A VERY LONG HOME TEAM NAME THAT MUST FIT WITHOUT OVERLAPPING"
	state.away_team.display_name = "A VERY LONG AWAY TEAM NAME THAT MUST FIT WITHOUT OVERLAPPING"
	state.last_event = (
		"A long real event with words that must remain " + "within its authored physical panel"
	)
	display._process(0)
	for key: String in display._detail_labels:
		var label: Label3D = display._detail_labels[key]
		var font: Font = label.font if label.font != null else ThemeDB.fallback_font
		_check(
			(
				(
					(
						font
						. get_string_size(
							label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size
						)
						. x
					)
					* label.pixel_size
				)
				<= StadiumScoreboardTiers.detail_slots(tier)[key].width
			),
			"long real names and events stay inside their own panel"
		)
	state.phase = MatchState.Phase.GAME_END
	display._process(0)
	_check(
		(
			display.details.half == "FINAL"
			and display.details.batter.is_empty()
			and display.details.batter_heading == "GAME COMPLETE"
		),
		"final does not advertise another at-bat"
	)
	display.bind_match(null)
	_check(
		display.shown.is_empty() and display.details.is_empty(), "unbinding clears old match data"
	)
	var next: MatchState = _sample_match()
	next.phase = MatchState.Phase.PITCH_IN_FLIGHT
	next.home_team.runs = 1
	display.bind_match(next)
	_check(
		display.shown.home == 1 and display.details.home_name == "YARD CLUB",
		"binding a newer active match cannot retain the prior match's score"
	)
	_check(
		StadiumScoreboardReadout.capture(null).is_empty(), "missing state provides no invented data"
	)
	display.bind_match(_sample_match())


func _lineup_capture() -> void:
	if _capture_dir.is_empty():
		return
	var root: Node3D = Node3D.new()
	add_child(root)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("263b37")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.7
	root.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	root.add_child(light)
	for index in range(StadiumScoreboardTiers.TIERS.size()):
		var tier: String = StadiumScoreboardTiers.TIERS[index]
		var board: Node3D = StadiumScoreboardTiers.create(tier)
		root.add_child(board)
		board.position.x = [-12.0, 0.0, 14.0][index]
		board.get_node("Visual/ScoreDisplay").bind_match(_sample_match())
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(4, 11, 42)
	camera.look_at(Vector3(3, 6, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23
	camera.make_current()
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for frame in range(8):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(
			(
				get_viewport().get_texture().get_image().save_png(
					_capture_dir.path_join("scoreboard-shared-scale.png")
				)
				== OK
			),
			"all three actual models captured at one shared world scale"
		)
	root.queue_free()
	await get_tree().process_frame


func _binding_order() -> void:
	var display: StadiumScoreboardTierDisplay = StadiumScoreboardTierDisplay.new()
	display.tier = "video"
	display.bind_match(null)
	_check(display.shown.is_empty(), "initial null binding does not invent opening scores")
	_check(
		not display.present({"inning": 1, "home": 0, "away": 0}, false),
		"unbuilt display rejects presentation without partial state"
	)
	display.bind_match(_sample_match())
	display.build()
	_check(
		display.shown.home == 12 and display._labels.home.text == "12",
		"a match bound before geometry builds appears once labels exist"
	)
	display.bind_match(null)
	_check(
		display.shown.is_empty() and display._labels.home.text == "—",
		"null binding clears actual labels"
	)
	display.free()
	var board: Node3D = StadiumScoreboardTiers.create("electronic")
	display = board.get_node("Visual/ScoreDisplay")
	_check(
		display.shown.is_empty() and display._labels.home.text == "—",
		"new unbound candidate starts with missing-data dashes"
	)
	board.free()


class NarrowWall extends StadiumRecipeBoundary:
	var tall: float = 4.0

	func polygon() -> PackedVector2Array:
		return [Vector2(-4, -3), Vector2(4, -3), Vector2(4, 5),
			Vector2(0.25, 5), Vector2(-0.25, 5), Vector2(-4, 5)]

	func segments() -> Array[Dictionary]:
		var rows: Array[Dictionary] = super.segments()
		for index in range(rows.size()):
			rows[index].height = tall if index == 3 else 1.2
		return rows


func _interior_clearance() -> void:
	var graph: NarrowWall = NarrowWall.new()
	var eye: Vector3 = Vector3(0, 1.5, -1)
	var left: Vector3 = Vector3(-2, 5, 10)
	var right: Vector3 = Vector3(2, 5, 10)
	for x: float in [-2, 2]:
		for y: float in [5, 7]:
			_check(StadiumScoreboardTierSites._clear(eye, Vector3(x, y, 10), graph),
				"regression fixture passes all four old corner rays")
	_check(not StadiumScoreboardTierSites._region_clear(eye, left, right, graph),
		"a narrow interior obstruction rejects even when four corner rays pass")
	graph.tall = 1.2
	_check(StadiumScoreboardTierSites._region_clear(eye, left, right, graph),
		"a genuinely low wall clears the entire readout")
	graph.tall = 20
	_check(StadiumScoreboardTierSites._region_clear(eye,
		Vector3(2, 5, 10), Vector3(3, 5, 10), graph),
		"a tall wall outside the sight triangle does not block the readout")
	_check(not StadiumScoreboardTierSites._region_clear(eye,
		Vector3(0.25 * 11 / 6, 5, 10), Vector3(2, 5, 10), graph),
		"an obstruction touching the region boundary rejects")
	_check(not StadiumScoreboardTierSites._region_clear(eye, left, left, graph),
		"degenerate edge-on regions fail closed")
