extends Node3D

var _failures: int = 0
var _flights: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	for shape: String in StadiumAdvancedWallManifest.SHAPES:
		await _shape(shape)
	_check(_flights == 32, "all authored back face and clearance flights executed")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro advanced lab passed: exact owned gameplay, camera, receiver and contacts.")
	print("ADVANCED_LAB_FLIGHTS ", _flights)
	get_tree().quit(0 if _failures == 0 else 1)


func _shape(shape: String) -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var progress: Dictionary = {"seasons": 50, "wins": 200, "strikeouts": 200}
	for row: Array in [["ST-024", 27], ["ST-022", 19], ["ST-025", 1], ["ST-026", 1], ["ST-039", 1]]:
		var quote: Dictionary = stock.quote(row[0], row[1], progress, row[0])
		_check(quote.ok, "synthetic authoring entitlement: " + row[0])
		if not quote.ok:
			return
		stock = StadiumStock.from_data(quote.state)
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	for height: String in ["low", "tall"]:
		pieces = StadiumWallPieceOwnership.from_data(
			(
				pieces
				. quote(
					StadiumWallPieceCatalog.identity("ST-024", height),
					12,
					height,
					progress,
					stock.copies.size()
				)
				. state
			),
			stock.copies.size()
		)
	var access: Array[String] = StadiumSurfaceProgression.INITIAL_LEGACY.duplicate()
	var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), access, true)
	)
	layout.advanced_back = (
		StadiumAdvancedWallManifest.suggest(shape, "ST-024", stock, pieces.stock).manifest
	)
	layout.walls = StadiumWallLayout.propose(layout.walls, stock, "left", "ST-022").walls
	layout.target = "purchase:ST-026:0"
	layout.net = "purchase:ST-025:0"
	layout.displays = [{"copy": "purchase:ST-039:0", "site": "SCORE-SMALL"}]
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(
		not StadiumAdvancedLab.install(lab, layout, stock, pieces, access),
		"explicit opt-in required"
	)
	lab.set_meta("stadium_advanced_lab_only", true)
	lab._managed_match = true
	_check(
		not StadiumAdvancedLab.install(lab, layout, stock, pieces, access),
		"managed fixture rejects"
	)
	lab._managed_match = false
	_guard_failures(lab, layout, stock, pieces, access)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var shot: int = lab._camera_director.shot
	_check(
		StadiumAdvancedLab.install(lab, layout, stock, pieces, access),
		"exact advanced field installs"
	)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	_check(
		not StadiumAdvancedLab.install(lab, layout, stock, pieces, access),
		"duplicate installation rejects"
	)
	_check(lab._camera_director.shot == shot, "paused camera shot retained")
	lab._camera_director.restore_after_pause()
	_check(lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING, "paused role restores")
	_check(
		PhysicalMatchReport.capture(lab).is_empty(), "candidate never emits production reward proof"
	)
	var property: StadiumAdvancedPropertyGeometry = lab.get_meta("stadium_property")
	var boundary: StadiumRecipeBoundaryBody = property.boundary
	_check(
		(
			lab._ball_play_resolver.segment_observer.is_valid()
			and lab._pitch_actor.receiver_router.is_valid()
		),
		"actual ball and called pitch routing installed"
	)
	_check(
		lab.get_node("StarterFieldGeometry").get_node_or_null("BackWall") == null,
		"old back collision removed only after complete successful build"
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._start_new_match()
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	var display: StadiumScoreboardDisplay = property.objects["purchase:ST-039:0"].get_node(
		"Visual/ScoreDisplay"
	)
	lab._match_state.home_team.runs = 4
	display._process(0)
	_check(
		display._match == lab._match_state and display.shown.home == 4,
		"restart rebinds held scoreboard"
	)
	_check(
		lab._camera_director.tracking_visibility._recipe == boundary.graph,
		"camera visibility uses the installed graph"
	)
	await _called_pitches(lab, property)
	await _views(lab, shape)
	_routes(lab, boundary.graph)
	for row: Dictionary in boundary.graph.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		var normal: Vector2 = boundary.graph.inward(row)
		var center: Vector2 = (row.a + row.b) / 2 + normal * 0.7
		for clear: bool in [false, true]:
			await _flight(
				lab,
				boundary.graph,
				Vector3(center.x, row.height + 0.6 if clear else row.height - 0.2, center.y),
				Vector3(-normal.x, 0, -normal.y) * 36,
				"BACK_CLEAR" if clear else "BACK_WALL_TERMINAL"
			)
	lab.free()
	await get_tree().process_frame


func _routes(lab: PitchBatLab, graph: StadiumRecipeBoundary) -> void:
	var fielder: FielderController = lab._primary_fielder
	fielder.set_physics_process(false)
	for target: Vector3 in [Vector3(-100, 0, 20), Vector3(100, 0, 20), Vector3(0, 0, 100)]:
		fielder.set_anchor(Vector3(0, 0, 10))
		fielder.begin_play()
		fielder.target_position = target
		for step in range(100):
			fielder._physics_process(1.0 / 30)
			var point: Vector3 = fielder.global_position
			_check(
				graph.contains(Vector2(point.x, point.z)),
				"defender route clips to exact concave field"
			)
		fielder.end_play()


func _flight(
	lab: PitchBatLab, graph: StadiumRecipeBoundary, from: Vector3, velocity: Vector3, role: String
) -> void:
	_flights += 1
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(lab._match_state.begin_pitch(), "actual candidate pitch begins")
	var outcomes: Array[BallPlayOutcome] = []
	var callback: Callable = func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome)
	lab._ball_play_resolver.play_resolved.connect(callback)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = from
	launch.velocity = velocity
	lab._start_ball_in_play(launch)
	lab.set_physics_process(true)
	for frame in range(120):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.dead:
			break
	lab.set_physics_process(false)
	var contacts: Array[Dictionary] = lab._ball_play_resolver.state.stadium_contacts
	_check(
		outcomes.size() == 1 and not contacts.is_empty() and contacts[-1].role == role,
		"terminal role %s at %s; got %s and %d outcomes" % [role, from, contacts, outcomes.size()]
	)
	for event: Dictionary in contacts:
		_check(
			PhysicalStadiumContacts._event(event, {}, graph),
			"physical contact fits frozen report envelope"
		)
	lab._ball_play_resolver.play_resolved.disconnect(callback)
	lab._cleanup_batted_ball()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _guard_failures(
	lab: PitchBatLab,
	layout: Dictionary,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	access: Array[String]
) -> void:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var count: int = host.get_child_count()
	host.position.x = 1
	_check(
		not StadiumAdvancedLab.install(lab, layout, stock, pieces, access),
		"transformed host rejects"
	)
	host.position.x = 0
	var automation: MatchAutomation = MatchAutomation.new()
	lab._automation = automation
	_check(not StadiumAdvancedLab.install(lab, layout, stock, pieces, access), "automation rejects")
	lab._automation = null
	automation = null
	var ball: BattedBallBody = BattedBallBody.new()
	lab._batted_ball = ball
	_check(not StadiumAdvancedLab.install(lab, layout, stock, pieces, access), "live ball rejects")
	lab._batted_ball = null
	ball.free()
	var bad: Dictionary = layout.duplicate(true)
	bad.advanced_back.copies.clear()
	_check(not StadiumAdvancedLab.install(lab, bad, stock, pieces, access), "failed build rejects")
	_check(
		(
			host.get_child_count() == count
			and host.has_node("BackWall")
			and not lab.has_meta("stadium_property")
		),
		"every rejection preserves the previous complete field"
	)


func _called_pitches(lab: PitchBatLab, property: StadiumAdvancedPropertyGeometry) -> void:
	var receiver: StadiumPairedReceiver = property.get_node("PitchReceiverPresentation")
	for left: bool in [false, true]:
		lab._start_new_match()
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		var actor: PitchFlightActor = lab._pitch_actor
		actor.set_physics_process(false)
		receiver.contacts.clear()
		var parameters: PitchLaunchParameters = PitchLaunchParameters.new()
		parameters.pitch_id = &"pitch.overhand_four_seam"
		parameters.position = Vector3(0, 1.05 + 4.903325 * 0.04 * 0.04, 0.4)
		parameters.velocity = Vector3(0, 0, -10)
		parameters.drag_coefficient = 0
		parameters.magnus_scale = 0
		parameters.perforation_force_scale = 0
		parameters.seed = 51
		_check(lab._match_state.begin_pitch(), "actual called pitch begins")
		actor.start_pitch(parameters)
		actor._physics_process(0.2)
		var call: Vector2i = Vector2i(lab._match_state.balls, lab._match_state.strikes)
		for frame in range(40):
			await get_tree().process_frame
		_check(
			(
				call == Vector2i(0, 1)
				and call == Vector2i(lab._match_state.balls, lab._match_state.strikes)
				and receiver.contacts.size() == 1
				and receiver.contacts[0].surface == "ST026_PANEL"
				and not actor.visible
			),
			"owned receiver catches called strike without changing its count"
		)


func _views(lab: PitchBatLab, shape: String) -> void:
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._status_label.visible = false
	for left: bool in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		lab._scorebug.refresh(lab._match_state, not lab._player_is_pitching())
		for shot: int in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
			lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
			lab._camera_director.snap(lab._camera, Vector3(0, 1, 5))
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = SphereShape3D.new()
			query.shape.radius = lab._camera.near * 2
			query.collision_mask = 16
			query.transform.origin = lab._camera.global_position
			_check(
				lab.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(),
				"installed fixed camera clears advanced walls"
			)
			if _capture_dir.is_empty():
				continue
			_check(
				DisplayServer.get_name() != "headless",
				"actual gameplay views require native rendering"
			)
			if DisplayServer.get_name() == "headless":
				continue
			get_window().size = Vector2i(1280, 720)
			DirAccess.make_dir_recursive_absolute(_capture_dir)
			for frame in range(4):
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_check(
				(
					get_viewport().get_texture().get_image().save_png(
						_capture_dir.path_join(
							(
								"advanced-lab-%s-%s-%s.png"
								% [
									shape,
									"left" if left else "right",
									(
										"batting"
										if shot == MatchCameraDirector.Shot.BATTING
										else "pitching"
									)
								]
							)
						)
					)
					== OK
				),
				"actual advanced gameplay view saved"
			)
