extends "res://src/tests/stadium_advanced_lab_test.gd"
## Actual isolated lab: all three displays, both hands, held updates and original field behavior.

var _bound_displays: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	for shape: String in StadiumAdvancedWallManifest.SHAPES:
		await _scoreboard_shape(shape)
	_check(_flights == 32 and _bound_displays == 8,
		"all authored contacts and installed board bindings were exercised")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro scoreboard lab passed: real receivers, contacts, views and display rebinding.")
	get_tree().quit(0 if _failures == 0 else 1)


func _scoreboard_shape(shape: String) -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var progress: Dictionary = {"seasons": 50, "wins": 200, "strikeouts": 200}
	for row: Array in [["ST-024", 27], ["ST-022", 19], ["ST-025", 1], ["ST-026", 1],
		["ST-039", 1], ["ST-040", 1]]:
		stock = StadiumStock.from_data(stock.quote(row[0], row[1], progress, row[0]).state)
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	for id: String in ["ST-024-L", "ST-024-T"]:
		pieces = StadiumWallPieceOwnership.from_data(
			pieces.quote(id, 12, id, progress, stock.copies.size()).state, stock.copies.size())
	var boards: StadiumScoreboardOwnership = StadiumScoreboardOwnership.new()
	boards = StadiumScoreboardOwnership.from_data(boards.quote(1, "electronic", progress,
		stock.copies.size() + pieces.stock.copies.size()).state)
	var access: Array[String] = StadiumSurfaceProgression.INITIAL_LEGACY.duplicate()
	var layout: Dictionary = StadiumScoreboardLayout.upgrade(StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), access, true)))
	layout.advanced_back = StadiumAdvancedWallManifest.suggest(
		shape, "ST-024", stock, pieces.stock).manifest
	layout.walls = StadiumWallLayout.propose(layout.walls, stock, "left", "ST-022").walls
	layout.target = "purchase:ST-026:0"
	layout.net = "purchase:ST-025:0"
	layout.scoreboards = [{"copy": "purchase:ST-040:0", "item": "ST-040", "model": "video-v2",
		"site": "BOARD-LARGE-v2"}]
	if shape != "left_loft":
		layout.scoreboards.append({"copy": "purchase:ST-039:0", "item": "ST-039", "model": "manual-v2",
			"site": "BOARD-LEFT-v2"})
	layout.scoreboards.append({"copy": "purchase:ST-039:0" if shape == "left_loft" else
		"scoreboard:electronic:0", "item": "ST-039" if shape == "left_loft" else "ST-090",
		"model": "manual-v2" if shape == "left_loft" else "electronic-v2", "site": "BOARD-RIGHT-v2"})
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"explicit scoreboard-lab opt-in is required")
	lab.set_meta("stadium_scoreboard_lab_only", true)
	_guards(lab, layout, stock, pieces, boards, access)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var shot: int = lab._camera_director.shot
	_check(StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"complete exact scoreboard property installs in real lab")
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"duplicate installation cannot replace or duplicate field")
	_check(lab._camera_director.shot == shot, "installation retains paused camera selection")
	lab._camera_director.restore_after_pause()
	_check(lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING, "paused role restores")
	_check(PhysicalMatchReport.capture(lab).is_empty(), "authoring property cannot issue reward proof")
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var boundary: StadiumRecipeBoundaryBody = property.boundary
	_check(lab._ball_play_resolver.segment_observer.is_valid()
		and lab._pitch_actor.receiver_router.is_valid(),
		"ordinary ball and called-pitch routes installed")
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._start_new_match()
	_display_restart(lab, property)
	await _called_pitches(lab, property)
	await _views(lab, "scoreboards-" + shape)
	_routes(lab, boundary.graph)
	for row: Dictionary in boundary.graph.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		var normal: Vector2 = boundary.graph.inward(row)
		var center: Vector2 = (row.a + row.b) / 2 + normal * 0.7
		for clear: bool in [false, true]:
			await _flight(lab, boundary.graph,
				Vector3(center.x, row.height + 0.6 if clear else row.height - 0.2, center.y),
				Vector3(-normal.x, 0, -normal.y) * 36,
				"BACK_CLEAR" if clear else "BACK_WALL_TERMINAL")
	_check(lab.get_meta("stadium_candidate_only", false)
		and PhysicalMatchReport.capture(lab).is_empty(),
		"restarts and actual play retain explicit candidate-only report suppression")
	lab.free()
	await get_tree().process_frame


func _display_restart(lab: PitchBatLab, property: StadiumScoreboardPropertyGeometry) -> void:
	lab._match_state.home_team.runs = 4
	lab._match_state.balls = 2
	for model: Node3D in property.board_objects.values():
		_bound_displays += 1
		var display: StadiumScoreboardTierDisplay = model.get_node("Visual/ScoreDisplay")
		display._process(0)
		_check(display._match == lab._match_state and display.shown.home == 4
			and display.details.balls == "2", "restart binds every physical scoreboard to the new match")
	lab._match_state.phase = MatchState.Phase.BALL_IN_PLAY
	lab._match_state.home_team.runs = 5
	lab._match_state.balls = 3
	for model: Node3D in property.board_objects.values():
		var display: StadiumScoreboardTierDisplay = model.get_node("Visual/ScoreDisplay")
		display._process(0)
		_check(display.shown.home == 4 and display.details.balls == "2", "whole board holds during play")
	lab._match_state.phase = MatchState.Phase.PLAY_DEAD
	for model: Node3D in property.board_objects.values():
		var display: StadiumScoreboardTierDisplay = model.get_node("Visual/ScoreDisplay")
		display._process(0)
		_check(display.shown.home == 5 and display.details.balls == "3", "safe boundary refreshes board")


func _guards(lab: PitchBatLab, layout: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership,
	access: Array[String]) -> void:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var count: int = host.get_child_count()
	lab._managed_match = true
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"managed match cannot take an authoring board field")
	lab._managed_match = false
	host.position.x = 1
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"transformed field host rejects")
	host.position.x = 0
	lab._automation = MatchAutomation.new()
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"automation cannot replace its field")
	lab._automation = null
	for phase: int in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY,
		MatchState.Phase.PLAY_DEAD, MatchState.Phase.INNING_TRANSITION, MatchState.Phase.GAME_END]:
		lab._match_state.phase = phase
		_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
			"installation is confined to pre-pitch authoring setup")
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	var ball: BattedBallBody = BattedBallBody.new()
	lab._batted_ball = ball
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"live physical ball rejects even if the phase is inconsistent")
	lab._batted_ball = null
	ball.free()
	var field: StringName = lab._field_id
	lab._field_id = &"unknown.field"
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"wrong field family rejects")
	lab._field_id = field
	lab._release_controller.begin()
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"active release gesture rejects before a pitch becomes airborne")
	lab._release_controller.cancel()
	lab._at_bat_cadence.begin_delivery(19)
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"active automatic delivery cannot have its field replaced")
	lab._at_bat_cadence.stop()
	lab._match_mode = false
	lab._throw_pitch()
	_check(lab._pitch_actor.running and lab._match_state.phase == MatchState.Phase.PRE_PITCH,
		"actual mechanics pitch preserves a suspended pre-pitch match state")
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"mechanics pitch cannot bypass the physical delivery guard")
	lab._match_mode = true
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"airborne actor rejects even with inconsistent match-mode/phase data")
	lab._pitch_actor.reset_pitch()
	lab._match_mode = false
	_check(not StadiumScoreboardLab.install(lab, layout, stock, pieces, boards, access),
		"gameplay authoring adapter does not activate in mechanics mode")
	lab._match_mode = true
	var bad: Dictionary = layout.duplicate(true)
	bad.scoreboards[0].copy = "missing"
	_check(not StadiumScoreboardLab.install(lab, bad, stock, pieces, boards, access),
		"invalid board ownership rejects before field replacement")
	_check(host.get_child_count() == count and host.has_node("BackWall")
		and not lab.has_meta("stadium_property"), "every refusal preserves the prior complete field")
