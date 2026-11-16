extends Node3D
## One complete candidate in the actual lab, with explicit isolated access and physical outcomes.

const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")

var _native: NativeCapture
var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(
		not StadiumClubOffsetLab.install(lab),
		"complete candidate requires explicit isolated opt-in"
	)
	lab.set_meta("stadium_club_offset_lab_only", true)
	lab._camera_mode = 1
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var previous_shot: int = lab._camera_director.shot
	lab._managed_match = true
	_check(not StadiumClubOffsetLab.install(lab), "candidate cannot enter a managed fixture")
	lab._managed_match = false
	_check(
		StadiumClubOffsetLab.install(lab) and not StadiumClubOffsetLab.install(lab),
		"one complete assembly"
	)
	if _failures > 0:
		get_tree().quit(1)
		return
	_check(
		lab._camera_director.shot == previous_shot,
		"install preserves the current paused inspection shot"
	)
	lab._camera_director.restore_after_pause()
	_check(
		lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING and lab._camera_mode == 1,
		"closing paused inspection restores the pre-install role camera"
	)
	var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
	_check(
		PhysicalMatchReport.capture(lab).is_empty(),
		"candidate cannot produce a misleading ordinary-field production report"
	)
	_check(
		(
			property.get_meta("candidate_venue").items.size() == 72
			and not lab.has_meta("stadium_snapshot")
		),
		"complete NPC candidate grants no saved eligibility"
	)
	_check(
		(
			lab.get_node("StarterFieldGeometry").get_node_or_null("BackWall") == null
			and not property.has_node("TemplateBackWall")
		),
		"old infinite back collisions are absent"
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not property.configure_candidate(lab), "complete adapter cannot duplicate its receivers")
	_receiver_routes(property)
	lab._start_new_match()
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	lab._match_state.inning = 3
	lab._match_state.home_team.runs = 7
	property.display._process(0)
	_check(
		(
			property.display._match == lab._match_state
			and property.display.shown.inning == 3
			and property.display.shown.home == 7
		),
		"manual board follows the replacement match after restart"
	)
	_routes(lab, property)
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._status_label.visible = false
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		for shot in range(MatchCameraDirector.Shot.size()):
			lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
			lab._camera_director.snap(lab._camera, Vector3(0, 1, 5))
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			_check(
				_clear_camera(lab._camera), "all fixed views clear complete physical infrastructure"
			)
			if shot == MatchCameraDirector.Shot.BATTING:
				await _readout_views(lab, property)
			if shot in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
				await _capture(
					lab,
					(
						"club-offset-field-%s-%s"
						% [
							"left" if left else "right",
							"batting" if shot == MatchCameraDirector.Shot.BATTING else "pitching"
						]
					)
				)
	if DisplayServer.get_name() != "headless" and not _capture_dir.is_empty():
		_check(
			await _native.resize(Vector2i(1280, 720)),
			"normal native window restores before remaining physical probes"
		)
	_check(_native._failures == 0, "native capture handshake failures propagate to this scene")
	for sample: Array in [
		[Vector3(0, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(1.5, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(0, 4, 27.3), Vector3(0, 0, 36), false, BallPlayOutcome.Result.HOME_RUN]
	]:
		await _flight(lab, property, sample)
	for left in [false, true]:
		var inward: Vector3 = Vector3(-1 if left else 1, 0, 0)
		var from: Vector3 = StadiumDugoutRecipe.rail_point(13, -0.5, left) + Vector3.UP * 0.6
		for foul in [false, true]:
			await _flight(
				lab,
				property,
				[
					from,
					inward * 8,
					foul,
					BallPlayOutcome.Result.FOUL if foul else BallPlayOutcome.Result.SINGLE
				]
			)
	lab.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro complete offset club lab passed: "
				+ "explicit assembly, contained routes and real outcomes."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _routes(lab: PitchBatLab, property: StadiumClubPropertyGeometry) -> void:
	var fielder: FielderController = lab._primary_fielder
	var original: Vector3 = fielder.global_position
	fielder.set_physics_process(false)
	for target: Vector3 in [
		Vector3(100, 0, 13),
		Vector3(-100, 0, 13),
		Vector3(0, 0, 100),
		Vector3(0, 0, -100),
		Vector3(1.5, 0, -4.5)
	]:
		fielder.set_anchor(Vector3(0, 0, 10))
		fielder.begin_play()
		fielder.target_position = target
		for step in range(120):
			var before: Vector3 = fielder.global_position
			fielder._physics_process(1.0 / 30)
			var current: Vector3 = fielder.global_position
			_check(
				property.boundary.graph.contains(Vector2(current.x, current.z)),
				"defender never shortcuts through dead dugout space"
			)
			_check(
				StadiumDefenderRoutes.clear(before, current, property.route_obstacles()),
				"defender body path clears receiver footprint"
			)
		fielder.end_play()
	fielder.set_anchor(original)
	lab._pitcher_marker.global_position = Vector3(0, 0, 14)
	var clipped: Vector3 = StadiumPropertyRuntime.pitcher_step(
		lab, Vector3(100, 0, 14), 100, Vector3(100, 0, 14)
	)
	_check(
		property.boundary.graph.contains(Vector2(clipped.x, clipped.z)),
		"actual pitcher adapter also respects complete graph"
	)


func _flight(lab: PitchBatLab, property: StadiumClubPropertyGeometry, sample: Array) -> void:
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	property.receiver.contacts.clear()
	_check(lab._match_state.begin_pitch(), "real candidate play begins from a pitch")
	var outcomes: Array[BallPlayOutcome] = []
	var callback: Callable = func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome)
	lab._ball_play_resolver.play_resolved.connect(callback)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = sample[0]
	launch.velocity = sample[1]
	launch.is_foul = sample[2]
	lab._start_ball_in_play(launch)
	_check(
		lab._batted_ball.physics_contact_router.is_valid(), "real game ball uses candidate physics"
	)
	for frame in range(120):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.dead:
			break
	_check(
		outcomes.size() == 1 and outcomes[0].result == sample[3],
		"one actual candidate terminal outcome at " + str(sample[0])
	)
	if sample[0].z < 1:
		_check(
			property.receiver.contacts.size() == 1,
			"physical target and net containment each produce exactly one response"
		)
	lab._ball_play_resolver.play_resolved.disconnect(callback)
	lab._cleanup_batted_ball()


func _clear_camera(camera: Camera3D) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = camera.near * 2
	query.collision_mask = StadiumClubPropertyGeometry.CAMERA_LAYER
	query.transform.origin = camera.global_position
	return camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _receiver_routes(property: StadiumClubPropertyGeometry) -> void:
	var from: Vector3 = Vector3(-1, 0, -2.02)
	var to: Vector3 = Vector3(1, 0, -2.02)
	_check(
		(
			_physical_receiver_hit(from, to)
			and not StadiumDefenderRoutes.clear(from, to, property.route_obstacles())
		),
		"route rejects a real rear target crossbar collision, independent of route approximation"
	)
	for side: float in [-1, 1]:
		var point: Vector3 = Vector3(side * 5.12, 0, -3.375)
		_check(
			(
				_physical_receiver_hit(point, point)
				and not StadiumDefenderRoutes.clear(point, point, property.route_obstacles())
			),
			"route includes physical outer anchor corners on both net sides"
		)


func _physical_receiver_hit(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = CylinderShape3D.new()
	query.shape.radius = StadiumDefenderRoutes.BODY_RADIUS
	query.shape.height = 1.8
	query.margin = 0
	query.transform.origin = from + Vector3.UP * 0.9
	query.collision_mask = StadiumPitchReceiver.LAYER
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return true
	query.motion = to - from
	return space.cast_motion(query)[0] < 1


func _capture(lab: PitchBatLab, name_value: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(extent), "requested whole-field native extent is acknowledged")
		lab._camera_director.snap(lab._camera, Vector3(0, 1, 5))
		StadiumPropertyRuntime.refresh_receiver_visibility(lab)
		_check(_clear_camera(lab._camera), "both capture sizes retain physical camera clearance")
		if lab._camera_director.shot == MatchCameraDirector.Shot.BATTING:
			var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
			var board: Node3D = property.display.get_parent().get_parent()
			var visibility: Dictionary = _readout_visibility(
				lab, lab._camera, board, board.global_transform
			)
			_check(
				(
					visibility.blocked == 0
					and visibility.outside == 0
					and visibility.back_facing == 0
					and visibility.samples > 100
				),
				"actual native batting readout cards and labels remain unoccluded and inside frustum"
			)
		_check(
			await _native.capture(_capture_dir, name_value),
			"whole-field capture verifies actual window and readback dimensions"
		)


func _readout_views(lab: PitchBatLab, property: StadiumClubPropertyGeometry) -> void:
	var display: StadiumScoreboardDisplay = property.display
	var board: Node3D = display.get_parent().get_parent()
	var state: MatchState = display._match
	display.bind_match(null)
	_check(
		display.present({"inning": 9999, "home": 9999, "away": 9999}, false),
		"visibility checks use actual maximum-width manual number labels"
	)
	await get_tree().process_frame
	await get_tree().process_frame
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 393)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = extent
		viewport.world_3d = lab.get_world_3d()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var camera: Camera3D = Camera3D.new()
		viewport.add_child(camera)
		for key: String in [
			"projection",
			"keep_aspect",
			"fov",
			"size",
			"frustum_offset",
			"h_offset",
			"v_offset",
			"near",
			"far",
			"cull_mask"
		]:
			camera.set(key, lab._camera.get(key))
		camera.global_transform = lab._camera.global_transform
		camera.make_current()
		# The actual camera/viewport registration must settle before querying its frustum.
		for frame in range(3):
			await get_tree().process_frame
		await get_tree().physics_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		var center: Vector3 = camera.get_camera_transform() * Vector3(0, 0, -10)
		_check(
			(
				camera.is_current()
				and viewport.get_camera_3d() == camera
				and Vector2i(viewport.get_visible_rect().size) == extent
				and camera.is_position_in_frustum(center)
			),
			"registered current camera has the requested extent and a valid center frustum point"
		)
		print(
			"CLUB_READOUT_CAMERA extent=",
			extent,
			" actual=",
			viewport.get_visible_rect(),
			" transform=",
			camera.get_camera_transform(),
			" projection=",
			camera.get_camera_projection()
		)
		var visible: Dictionary = _readout_visibility(lab, camera, board, board.global_transform)
		_check(
			(
				visible.samples > 100
				and visible.blocked == 0
				and visible.outside == 0
				and visible.back_facing == 0
			),
			(
				"both-hand batting card/label geometry is visible at content extent "
				+ str(extent)
				+ ": "
				+ str(visible)
			)
		)
		var old_pose: Transform3D = Transform3D(Basis(Vector3.UP, PI), Vector3(-20, 0, 30))
		var old_visibility: Dictionary = _readout_visibility(lab, camera, board, old_pose)
		_check(
			old_visibility.first_sample.distance_to(Vector3(-18.04, 3.56, 29.869)) < 0.00001,
			"old card lower corner independently matches its known authored world point"
		)
		print(
			"CLUB_READOUT_VISIBILITY extent=",
			extent,
			" candidate=",
			visible,
			" old_pose=",
			old_visibility
		)
		# The original readout is geometrically clear despite its visually thin presentation.
		# A separate deliberately lowered point set verifies that real backwall occlusion rejects.
		# Neither diagnostic pose moves the installed board or changes the captured venue record.
		var occluded_pose: Transform3D = old_pose
		occluded_pose.origin.y -= 1.0
		var occluded: Dictionary = _readout_visibility(lab, camera, board, occluded_pose)
		print("CLUB_READOUT_OCCLUSION_CONTROL extent=", extent, " lowered_old_pose=", occluded)
		_check(
			(
				occluded.samples == visible.samples
				and occluded.back_wall_blocked > 0
				and occluded.graph_back_wall_blocked > 0
			),
			"deliberately lowered readout is blocked by physical and exact-prism backwall geometry"
		)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.queue_free()
		await get_tree().process_frame
	display.bind_match(state)
	display._process(0)
	_check(
		(
			display._match == lab._match_state
			and (
				display.shown
				== {
					"inning": state.inning,
					"home": state.home_team.runs,
					"away": state.away_team.runs
				}
			)
		),
		"stress labels restore the actual match before captures and physical probes"
	)


func _readout_visibility(
	lab: PitchBatLab, camera: Camera3D, board: Node3D, pose: Transform3D
) -> Dictionary:
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var to_local: Transform3D = board.global_transform.affine_inverse()
	# Sample full physical number-card faces, not just the decorative top/header or label centers.
	for index in range(3):
		var card: MeshInstance3D = board.get_node("Visual/NumberCard%d" % index)
		var box: AABB = card.get_aabb()
		for x in range(5):
			for y in range(3):
				var local: Vector3 = Vector3(
					lerpf(box.position.x, box.end.x, x / 4.0),
					lerpf(box.position.y, box.end.y, y / 2.0),
					box.end.z + 0.001
				)
				points.append(pose * to_local * card.global_transform * local)
				normals.append((pose.basis * to_local.basis * card.global_basis.z).normalized())
	var display: StadiumScoreboardDisplay = board.get_node("Visual/ScoreDisplay")
	for label: Label3D in display.get_children():
		var box: AABB = label.get_aabb()
		_check(box.size.x > 0 and box.size.y > 0, "readout label has real nonempty glyph bounds")
		for x in range(5):
			for y in range(3):
				var local: Vector3 = Vector3(
					lerpf(box.position.x, box.end.x, x / 4.0),
					lerpf(box.position.y, box.end.y, y / 2.0),
					box.end.z + 0.001
				)
				points.append(pose * to_local * label.global_transform * local)
				normals.append((pose.basis * to_local.basis * label.global_basis.z).normalized())
	var result: Dictionary = {
		"samples": points.size(),
		"blocked": 0,
		"outside": 0,
		"back_facing": 0,
		"back_wall_blocked": 0,
		"graph_back_wall_blocked": 0,
		"first_sample": points[0],
		"first_camera_space": camera.get_camera_transform().affine_inverse() * points[0],
		"first_screen": camera.unproject_position(points[0])
	}
	var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
	var prisms: StadiumWallViewPrisms = StadiumWallViewPrisms.new(property.boundary.graph)
	var segments: Array[Dictionary] = property.boundary.graph.segments()
	for index in range(segments.size() - 1, -1, -1):
		if segments[index].role != "BACK_WALL_TERMINAL":
			prisms.walls.remove_at(index)
	for index in range(points.size()):
		var point: Vector3 = points[index]
		if normals[index].dot((camera.get_camera_transform().origin - point).normalized()) <= 0.5:
			result.back_facing += 1
		if not camera.is_position_in_frustum(point):
			result.outside += 1
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			camera.get_camera_transform().origin, point, StadiumClubPropertyGeometry.CAMERA_LAYER
		)
		if prisms.blocked(camera.get_camera_transform().origin, point, 0):
			result.graph_back_wall_blocked += 1
		var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			result.blocked += 1
			if hit.collider.get_meta("surface_role", "") == "BACK_WALL_TERMINAL":
				result.back_wall_blocked += 1
	return result
