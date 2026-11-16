extends "res://src/tests/stadium_offset_tracking_test.gd"
## Dense complete-field camera paths; separate from saved-game and interactive acceptance.


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for fps: int in [30, 60, 120]:
		_sample_fps = fps
		await _walls("club-complete", "candidate")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro complete offset club tracking passed: whole-field paths at three frame rates."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _install_walls(lab: PitchBatLab, _shape_name: String, _item: String) -> void:
	lab.set_meta("stadium_club_offset_lab_only", true)
	_check(
		StadiumClubOffsetLab.install(lab),
		"explicit complete field installs for camera qualification"
	)


func _endpoints(_depth: float) -> Array[Vector3]:
	var result: Array[Vector3] = [
		Vector3(0, 0.15, 27.9),
		Vector3(-8, 0.15, 22.4),
		Vector3(13, 0.15, 22.9),
		Vector3(7, 0.15, 11.75),
		Vector3(-25, 1.8, 18),
		Vector3(25, 1.8, 18),
		Vector3(0, 7, 30),
		Vector3(0, 35, 25),
		Vector3(-1.5, 1, -4.45),
		Vector3(1.5, 1, -4.45)
	]
	for left in [false, true]:
		for distance: float in [11, 13, 15]:
			result.append(StadiumDugoutRecipe.rail_point(distance, -0.15, left) + Vector3.UP * 0.7)
	return result


func _walls(_shape_name: String, _item: String) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_club_offset_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(StadiumClubOffsetLab.install(lab), "complete candidate camera fixture")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	# Static-body transforms must reach physics before testing the swept camera's real queries.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
	var director: MatchCameraDirector = lab._camera_director
	var camera: Camera3D = lab._camera
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = camera.near * 2
	query.collision_mask = StadiumClubPropertyGeometry.CAMERA_LAYER
	var samples: int = 0
	var outside: int = 0
	var blocked: int = 0
	var overlaps: int = 0
	var max_step: float = 0
	var max_turn: float = 0
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		for defense in [false, true]:
			for requested: Vector3 in _endpoints(0):
				var start: Vector3 = Vector3(requested.x if requested.z < 0 else 0, 1, 0)
				var contact: Dictionary = StadiumClubBoundarySweep.event(
					property.boundary, start, requested
				)
				var endpoint: Vector3 = contact.get("position", requested)
				# Do not continue a camera probe through a dead wall into solid stands outside play.
				var prior: Vector3i = Vector3i(outside, blocked, overlaps)
				director.set_shot(
					(
						MatchCameraDirector.Shot.PITCHING
						if defense
						else MatchCameraDirector.Shot.BATTING
					)
				)
				director.snap(camera)
				director.prepare_ball_in_play(defense, start, endpoint - start)
				director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
				for frame in range(_sample_fps * 4):
					ball.position = start.lerp(endpoint, minf(1, frame / (_sample_fps * 2.5)))
					var before: Transform3D = camera.global_transform
					director.update(camera, 1.0 / _sample_fps, true, ball.position)
					StadiumPropertyRuntime.refresh_receiver_visibility(lab)
					max_step = maxf(max_step, before.origin.distance_to(camera.global_position))
					max_turn = maxf(
						max_turn,
						before.basis.get_rotation_quaternion().angle_to(
							camera.global_basis.get_rotation_quaternion()
						)
					)
					outside += int(
						(
							camera.is_position_behind(ball.position)
							or not (Rect2(24, 24, 1232, 672).has_point(
								camera.unproject_position(ball.position)
							))
						)
					)
					blocked += int(
						(director.tracking_visibility as StadiumClubFieldVisibility).actual_blocked(
							camera.global_position, ball.position
						)
					)
					query.transform.origin = camera.global_position
					overlaps += int(
						not (
							camera
							. get_world_3d()
							. direct_space_state
							. intersect_shape(query, 1)
							. is_empty()
						)
					)
					samples += 1
				if Vector3i(outside, blocked, overlaps) != prior:
					print(
						"CLUB_TRACKING_FAILURE left=",
						left,
						" defense=",
						defense,
						" endpoint=",
						endpoint,
						" counts=",
						Vector3i(outside, blocked, overlaps) - prior
					)
	print(
		"CLUB_TRACKING fps=",
		_sample_fps,
		" samples=",
		samples,
		" outside=",
		outside,
		" blocked=",
		blocked,
		" overlaps=",
		overlaps,
		" max_step=",
		max_step,
		" max_turn=",
		max_turn
	)
	_check(
		outside == 0 and blocked == 0 and overlaps == 0,
		"real complete-field camera volume stays clear and the ball remains framed"
	)
	_check(
		max_step < 32.1 / _sample_fps and max_turn < 1.7 / _sample_fps,
		"complete-field camera retains bounded movement and turning"
	)
	lab._cleanup_batted_ball()
	lab.queue_free()
	await get_tree().process_frame
