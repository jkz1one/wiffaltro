extends Node3D
## One complete candidate in the actual lab, with explicit isolated access and physical outcomes.

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(not StadiumClubLab.install(lab), "complete candidate requires explicit isolated opt-in")
	lab.set_meta("stadium_club_lab_only", true)
	lab._camera_mode = 1
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var previous_shot: int = lab._camera_director.shot
	lab._managed_match = true
	_check(not StadiumClubLab.install(lab), "candidate cannot enter a managed fixture")
	lab._managed_match = false
	_check(StadiumClubLab.install(lab) and not StadiumClubLab.install(lab), "one complete assembly")
	if _failures > 0:
		get_tree().quit(1)
		return
	_check(lab._camera_director.shot == previous_shot,
		"install preserves the current paused inspection shot")
	lab._camera_director.restore_after_pause()
	_check(lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING and lab._camera_mode == 1,
		"closing paused inspection restores the pre-install role camera")
	var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
	_check(PhysicalMatchReport.capture(lab).is_empty(),
		"candidate cannot produce a misleading ordinary-field production report")
	_check(property.get_meta("candidate_venue").items.size() == 68
		and not lab.has_meta("stadium_snapshot"), "complete NPC candidate grants no saved eligibility")
	_check(lab.get_node("StarterFieldGeometry").get_node_or_null("BackWall") == null
		and not property.has_node("TemplateBackWall"), "old infinite back collisions are absent")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not property.configure_candidate(lab), "complete adapter cannot duplicate its receivers")
	_receiver_routes(property)
	lab._start_new_match()
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	lab._match_state.inning = 3
	lab._match_state.home_team.runs = 7
	property.display._process(0)
	_check(property.display._match == lab._match_state and property.display.shown.inning == 3
		and property.display.shown.home == 7, "manual board follows the replacement match after restart")
	_routes(lab, property)
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._status_label.visible = false
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
			else PlayerDefinition.Handedness.RIGHT
		PitchBatLabPresentation.sync_players(lab)
		for shot in range(MatchCameraDirector.Shot.size()):
			lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
			lab._camera_director.snap(lab._camera, Vector3(0, 1, 5))
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			_check(_clear_camera(lab._camera), "all fixed views clear complete physical infrastructure")
			if shot in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
				await _capture("club-field-%s-%s" % ["left" if left else "right",
					"batting" if shot == MatchCameraDirector.Shot.BATTING else "pitching"])
	for sample: Array in [
		[Vector3(0, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(1.5, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(0, 4, 22.7), Vector3(0, 0, 36), false, BallPlayOutcome.Result.HOME_RUN]]:
		await _flight(lab, property, sample)
	for left in [false, true]:
		var inward: Vector3 = Vector3(-1 if left else 1, 0, 0)
		var from: Vector3 = StadiumDugoutRecipe.rail_point(13, -0.5, left) + Vector3.UP * 0.6
		for foul in [false, true]:
			await _flight(lab, property, [from, inward * 8, foul,
				BallPlayOutcome.Result.FOUL if foul else BallPlayOutcome.Result.SINGLE])
	lab.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro complete club lab passed: "
			+ "explicit assembly, contained routes and real outcomes.")
	get_tree().quit(0 if _failures == 0 else 1)


func _routes(lab: PitchBatLab, property: StadiumClubPropertyGeometry) -> void:
	var fielder: FielderController = lab._primary_fielder
	var original: Vector3 = fielder.global_position
	fielder.set_physics_process(false)
	for target: Vector3 in [Vector3(100, 0, 13), Vector3(-100, 0, 13),
		Vector3(0, 0, 100), Vector3(0, 0, -100), Vector3(1.5, 0, -4.5)]:
		fielder.set_anchor(Vector3(0, 0, 10))
		fielder.begin_play()
		fielder.target_position = target
		for step in range(120):
			var before: Vector3 = fielder.global_position
			fielder._physics_process(1.0 / 30)
			var current: Vector3 = fielder.global_position
			_check(property.boundary.graph.contains(Vector2(current.x, current.z)),
				"defender never shortcuts through dead dugout space")
			_check(StadiumDefenderRoutes.clear(before, current, property.route_obstacles()),
				"defender body path clears receiver footprint")
		fielder.end_play()
	fielder.set_anchor(original)
	lab._pitcher_marker.global_position = Vector3(0, 0, 14)
	var clipped: Vector3 = StadiumPropertyRuntime.pitcher_step(lab, Vector3(100, 0, 14),
		100, Vector3(100, 0, 14))
	_check(property.boundary.graph.contains(Vector2(clipped.x, clipped.z)),
		"actual pitcher adapter also respects complete graph")


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
	_check(lab._batted_ball.physics_contact_router.is_valid(), "real game ball uses candidate physics")
	for frame in range(120):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.dead:
			break
	_check(outcomes.size() == 1 and outcomes[0].result == sample[3],
		"one actual candidate terminal outcome at " + str(sample[0]))
	if sample[0].z < 1:
		_check(property.receiver.contacts.size() == 1,
			"physical target and net containment each produce exactly one response")
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
	_check(_physical_receiver_hit(from, to)
		and not StadiumDefenderRoutes.clear(from, to, property.route_obstacles()),
		"route rejects a real rear target crossbar collision, independent of route approximation")
	for side: float in [-1, 1]:
		var point: Vector3 = Vector3(side * 5.12, 0, -3.375)
		_check(_physical_receiver_hit(point, point)
			and not StadiumDefenderRoutes.clear(point, point, property.route_obstacles()),
			"route includes physical outer anchor corners on both net sides")


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


func _capture(name_value: String) -> void:
	if _capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join(name_value + ".png")) == OK, "actual whole-field view captured")
