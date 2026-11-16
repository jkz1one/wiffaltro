extends "res://src/tests/stadium_yard_tracking_test.gd"
## Actual scoped rendering, both camera roles/hands, all back materials and both wall shapes.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	_visibility_contract()
	for shape: String in StadiumWallRecipes.SHAPES:
		for item: String in StadiumWallRecipes.BACK_IDS:
			await _walls(shape, item)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro wall tracking checks passed: both hands/roles, all materials and both shapes.")
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
	var depth: float = 26 if shape == "deeper_center" else 23.4
	var endpoints: Array[Vector3] = [Vector3(0, 0.15, depth - 0.1),
		Vector3(-17, 0.15, 23.3), Vector3(17, 0.15, 23.3), Vector3(7, 0.15, 11.75),
		Vector3(-25, 1.8, 18), Vector3(25, 1.8, 18), Vector3(0, 7, depth + 3),
		Vector3(0, 35, depth + 1.6)]
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
				director.clear_presentation_motion()
				director.set_shot(MatchCameraDirector.Shot.PITCHING if defense \
					else MatchCameraDirector.Shot.BATTING)
				director.snap(lab._camera)
				director.prepare_ball_in_play(defense, Vector3(0, 1, 0), endpoint - Vector3(0, 1, 0))
				director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
				for frame in range(240):
					ball.position = Vector3(0, 1, 0).lerp(endpoint, minf(1, frame / 150.0))
					var before: Transform3D = lab._camera.global_transform
					director.update(lab._camera, 1.0 / 60, true, ball.position)
					max_step = maxf(max_step, before.origin.distance_to(lab._camera.global_position))
					max_turn = maxf(max_turn, before.basis.get_rotation_quaternion().angle_to(
						lab._camera.global_basis.get_rotation_quaternion()))
					var screen: Vector2 = lab._camera.unproject_position(ball.position)
					outside += int(lab._camera.is_position_behind(ball.position)
						or not Rect2(24, 24, 1232, 672).has_point(screen))
					blocked += int(director.tracking_visibility._blocked(
						lab._camera.global_position, ball.position))
					samples += 1
				if DisplayServer.get_name() != "headless":
					var contrast: float = await _contrast(lab._camera, ball)
					contrast_min = minf(contrast_min, contrast)
					_check(contrast >= 0.03, "actual antialiased ball remains distinguishable")
					if endpoint == endpoints[3] and not left and not defense:
						await _shot("wall-tracking-" + item + "-" + shape)
	print("WALL_TRACKING ", shape, " ", item, " samples=", samples, " outside=", outside,
		" blocked=", blocked, " contrast_min=", contrast_min,
		" max_step=", max_step, " max_turn=", max_turn)
	_check(samples == 7680 and outside == 0 and blocked == 0,
		"dense paths keep actual ball in frame without a wall blocking the camera")
	_check(max_step < 32.1 / 60 and max_turn < 1.7 / 60,
		"wall avoidance preserves bounded movement and rotation without camera cuts")
	lab.queue_free()
	await get_tree().process_frame
	_check(int(get_viewport().msaa_3d) == original,
		"closing tracked wall field restores viewport quality")


func _install_walls(lab: PitchBatLab, shape: String, item: String) -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var layout: Dictionary = StadiumWallItems.upgrade(StadiumStarterLayout.empty())
	for row: Array in [[item, 23, "back"], ["ST-022", 19, "left"], ["ST-023", 19, "right"]]:
		var quote: Dictionary = stock.quote(row[0], row[1], {"seasons": 30, "wins": 100}, row[0])
		_check(quote.ok, "exact synthetic authoring inventory")
		stock = StadiumStock.from_data(quote.state)
		layout.walls = StadiumWallLayout.propose(layout.walls, stock, row[2], row[0], shape).walls
	_check(StadiumPropertyRuntime._install(lab, layout, stock)
		and StadiumBoundaryRuntime._install(lab), "same bound wall installer used by real fixtures")
	_check(absf(lab._camera_director.tracking_visibility.field_wall_z
		- (26 if shape == "deeper_center" else 23.4)) < 0.0001, "tracking uses real wall depth")


func _visibility_contract() -> void:
	var visibility: BallTrackingVisibility = BallTrackingVisibility.new()
	for x: int in range(-22, 22):
		visibility._wall_bounds.append(AABB(Vector3(x, 0, 23.4), Vector3(1, 3.25, 0.35)))
	_check(not visibility._blocked(Vector3(-10, 7.3, 22.6), Vector3(0, 0.15, 23.3)),
		"adjacent wall pieces do not invent an occluder inside the field")
	_check(visibility._blocked(Vector3(0, 1, 26), Vector3(0, 0.15, 23.3)),
		"real wall crossing remains blocked even beside the wall")
	_check(visibility._blocked(Vector3(-10, 1, 26), Vector3(0, 0.15, 20)),
		"distant wall crossing retains conservative inflation")
	_check(is_equal_approx(visibility.defense_depth(17, 30), 23.35),
		"original stadium camera depth remains unchanged")
