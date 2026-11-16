extends "res://src/tests/stadium_walls_tracking_test.gd"
## Isolated asymmetric camera coverage, especially the short notched shoulder.

var _sample_fps: int = 60


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	for item: String in StadiumWallRecipes.BACK_IDS:
		await _walls("offset_gables", item)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro offset tracking checks passed: isolated notches, both hands and roles.")
	get_tree().quit(0 if _failures == 0 else 1)


func _walls(shape: String, item: String) -> void:
	var original: int = int(get_viewport().msaa_3d)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	_install_walls(lab, shape, item)
	var director: MatchCameraDirector = lab._camera_director
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	var depth: float = 28.0
	var endpoints: Array[Vector3] = _endpoints(depth)
	var samples: int = 0
	var outside: int = 0
	var blocked: int = 0
	var contrast_min: float = INF
	var max_step: float = 0
	var max_turn: float = 0
	for left: bool in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
			else PlayerDefinition.Handedness.RIGHT
		PitchBatLabPresentation.sync_players(lab)
		director.set_batter_handedness(left)
		for defense: bool in [false, true]:
			for endpoint: Vector3 in endpoints:
				var prior_outside: int = outside
				var prior_blocked: int = blocked
				director.clear_presentation_motion()
				director.set_shot(MatchCameraDirector.Shot.PITCHING if defense \
					else MatchCameraDirector.Shot.BATTING)
				director.snap(lab._camera)
				director.prepare_ball_in_play(defense, Vector3(0, 1, 0), endpoint - Vector3(0, 1, 0))
				director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
				for frame in range(_sample_fps * 4):
					ball.position = Vector3(0, 1, 0).lerp(endpoint, minf(1, frame / (_sample_fps * 2.5)))
					var before: Transform3D = lab._camera.global_transform
					director.update(lab._camera, 1.0 / _sample_fps, true, ball.position)
					max_step = maxf(max_step, before.origin.distance_to(lab._camera.global_position))
					max_turn = maxf(max_turn, before.basis.get_rotation_quaternion().angle_to(
						lab._camera.global_basis.get_rotation_quaternion()))
					var screen: Vector2 = lab._camera.unproject_position(ball.position)
					outside += int(lab._camera.is_position_behind(ball.position)
						or not Rect2(24, 24, 1232, 672).has_point(screen))
					blocked += int(director.tracking_visibility._blocked(
						lab._camera.global_position, ball.position))
					samples += 1
				if blocked > prior_blocked:
					print("TRACKING_BLOCKED ", shape, " left=", left, " defense=", defense,
						" endpoint=", endpoint, " frames=", blocked - prior_blocked)
				if outside > prior_outside:
					print("TRACKING_OUTSIDE ", shape, " left=", left, " defense=", defense,
						" endpoint=", endpoint, " frames=", outside - prior_outside)
				if DisplayServer.get_name() != "headless":
					var contrast: float = await _contrast(lab._camera, ball)
					contrast_min = minf(contrast_min, contrast)
					_check(contrast >= 0.03, "actual antialiased ball remains distinguishable")
					if endpoint == endpoints[3] and not left and not defense:
						await _shot("wall-tracking-" + item + "-" + shape)
	print("WALL_TRACKING ", shape, " ", item, " samples=", samples, " outside=", outside,
		" blocked=", blocked, " contrast_min=", contrast_min,
		" max_step=", max_step, " max_turn=", max_turn, " fps=", _sample_fps)
	_check(samples == endpoints.size() * 16 * _sample_fps and outside == 0 and blocked == 0,
		"dense paths keep actual ball in frame without a wall blocking the camera")
	_check(max_step < 32.1 / _sample_fps and max_turn < 1.7 / _sample_fps,
		"wall avoidance preserves bounded movement and rotation without camera cuts")
	lab.queue_free()
	await get_tree().process_frame
	_check(int(get_viewport().msaa_3d) == original,
		"closing tracked wall field restores viewport quality")


func _install_walls(lab: PitchBatLab, _shape_name: String, item: String) -> void:
	_check(StadiumPropertyRuntime._install(lab, StadiumStarterLayout.empty(),
		StadiumStock.new_club()), "original isolated lab substrate")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumOffsetBoundaryBody = StadiumOffsetBoundaryBody.new()
	boundary.name = "BoundaryGraph"
	property.add_child(boundary)
	_check(boundary.build("offset_gables", item), "explicit authoring-only boundary")
	StadiumWallRenderQuality.attach(boundary)
	lab._camera_director.tracking_visibility.configure(lab.get_node("StarterFieldGeometry"))
	_kernel_check(lab._camera_director.tracking_visibility, boundary.graph)
	_check(is_equal_approx(lab._camera_director.tracking_visibility.field_wall_z, 28),
		"candidate camera uses the actual polygon")
	_check(not StadiumWallRecipes.SHAPES.has("offset_gables"),
		"preview does not activate a paid or saved recipe")


func _endpoints(depth: float) -> Array[Vector3]:
	return [Vector3(0, 0.15, depth - 0.1),
		Vector3(-8, 0.15, 22.4), Vector3(13, 0.15, 22.9), Vector3(7, 0.15, 11.75),
		Vector3(-25, 1.8, 18), Vector3(25, 1.8, 18), Vector3(0, 7, depth + 3),
		Vector3(0, 35, depth + 1.6)]


func _kernel_check(visibility: BallTrackingVisibility, graph: StadiumRecipeBoundary) -> void:
	for x: float in [-20, -12, 0, 12, 20]:
		var at: Vector2 = Vector2(x, visibility.defense_depth(x, 100))
		for row: Dictionary in graph.segments():
			if row.role == "BACK_WALL_TERMINAL":
				_check(graph.inward(row).dot(at - row.a)
					>= BallTrackingVisibility.WALL_CAMERA_CLEARANCE - 0.00001,
					"camera target remains inside every padded back-face viewing half-plane")
