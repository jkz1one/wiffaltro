extends Node

var _failures: int = 0


func _ready() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var bounds: Rect2 = Rect2(Vector2(24, 24), Vector2(1232, 672))
	var zone_height: float = 0.0
	for left in [false, true]:
		var definition: PlayerDefinition = lab._match_state.batter().definition.duplicate()
		definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		lab._match_state.batter().definition = definition
		PitchBatLabPresentation.sync_players(lab)
		lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
		lab._camera_director.snap(lab._camera)
		var original: Transform3D = lab._camera.global_transform
		var body_screen: float = lab._camera.unproject_position(lab._batter_avatar.position).x
		var plate_screen: float = lab._camera.unproject_position(Vector3.ZERO).x
		_check(
			(body_screen > plate_screen) == left,
			"catcher view must show right-handed batters left of plate and left-handers right"
		)
		for point in [
			Vector3(-0.75, 0.30, 0),
			Vector3(0.75, 1.85, 0),
			Vector3(0, 1.7, 13.716),
			Vector3(0, 0, 0)
		]:
			_check(
				(
					not lab._camera.is_position_behind(point)
					and bounds.has_point(lab._camera.unproject_position(point))
				),
				"plate, aim extremes and mound must fit batting view"
			)
		var center: Vector2 = lab._camera.unproject_position(
			Vector3(0, 1.05, ContactResolver.CONTACT_PLANE_Z)
		)
		PitchBatLabFeelSupport.set_batting_aim_from_screen(lab, center)
		_check(
			lab._batting_aim.distance_to(Vector2(0, 1.05)) < 0.001,
			"camera aim must round-trip through the actual contact plane"
		)
		zone_height = absf(
			(
				lab._camera.unproject_position(Vector3(0, 0.55, 0)).y
				- lab._camera.unproject_position(Vector3(0, 1.55, 0)).y
			)
		)
		_check(zone_height > 100 and zone_height < 220, "zone must retain a useful apparent size")
		for depth in [1.0, 2.0, 4.0, 8.0, 12.0]:
			for x in [-0.35, 0.0, 0.35]:
				for y in [0.7, 1.05, 1.4]:
					var target: Vector3 = Vector3(x, y, depth)
					_check(
						not _occluded(lab._bat_actor, lab._camera.global_position, target),
						"loaded bat must clear the incoming strike corridor"
					)
					_check(
						not _occluded(lab._batter_avatar, lab._camera.global_position, target),
						"batter body must clear the incoming strike corridor"
					)
		for frame in range(60):
			lab._camera_director.update(lab._camera, 1.0 / 60.0, false, Vector3(5, 6, 8))
		_check(
			lab._camera.global_transform.is_equal_approx(original),
			"default batting coverage stays settled without a requested camera move"
		)
		var saved_aim: Vector2 = lab._batting_aim
		lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
		lab._camera_director.snap(lab._camera)
		var release_view: Transform3D = lab._camera.global_transform
		for frame in range(90):
			var pitch_position: Vector3 = Vector3(0.3, 1.2, lerpf(13.0, 0.0, frame / 90.0))
			lab._camera_director.track_released_pitch(true, pitch_position)
			lab._camera_director.update(lab._camera, 1.0 / 60.0, false, pitch_position)
			_check(
				bounds.has_point(lab._camera.unproject_position(pitch_position)),
				"released pitch must stay framed during the tracking pan"
			)
		_check(
			not release_view.is_equal_approx(lab._camera.global_transform),
			"released pitch coverage may move"
		)
		_check(
			saved_aim.is_equal_approx(lab._batting_aim),
			"camera motion cannot modify stored world-space batting aim"
		)
		lab._camera_director.track_released_pitch(false, Vector3.ZERO)
		var side: float = signf(lab._batter_avatar.position.x)
		_check(
			PitchFeedback.plate_message(lab, Vector3(side * 0.6, 1, 0)) == "TOOK INSIDE",
			"inside must point toward the visible batter"
		)
	print(
		"CAMERA AUDIT height=2.10m back=3.38m tilt=5.45deg fov=",
		lab._camera.fov,
		" zone_height_px=",
		zone_height,
		" corridor_rays=90 per actor"
	)
	lab.queue_free()
	await get_tree().process_frame
	await _test_ball_tracking()
	await _test_contact_flights()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro camera audit passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _test_ball_tracking() -> void:
	var blocked: int = 0
	var outside: int = 0
	var samples: int = 0
	var max_turn: float = 0.0
	var max_step: float = 0.0
	for field_id in [PitchBatLab.FIELD_ID, SeasonState.AWAY_FIELD_ID]:
		var lab: PitchBatLab = PitchBatLab.new()
		lab._field_id = field_id
		add_child(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		var geometry: Node = lab.get_node("StarterFieldGeometry")
		for defense in [false, true]:
			for endpoint in [
				Vector3(0, 0.08, 23.30),
				Vector3(-17, 0.08, 23.30),
				Vector3(17, 0.08, 23.30),
				Vector3(7, 0.08, 11.75),
				Vector3(-25, 1.8, 18),
				Vector3(25, 1.8, 18),
				Vector3(0, 7, 28),
				Vector3(0, 35, 25)
			]:
				var director: MatchCameraDirector = lab._camera_director
				director.clear_presentation_motion()
				director.set_shot(
					(
						MatchCameraDirector.Shot.PITCHING
						if defense
						else MatchCameraDirector.Shot.BATTING
					)
				)
				director.snap(lab._camera)
				director.prepare_ball_in_play(
					defense, Vector3(0, 1, 0), endpoint - Vector3(0, 1, 0)
				)
				director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
				var last_transform: Transform3D = lab._camera.global_transform
				for frame in range(240):
					var ball: Vector3 = Vector3(0, 1, 0).lerp(
						endpoint, minf(1.0, float(frame) / 150.0)
					)
					director.update(lab._camera, 1.0 / 60.0, true, ball)
					blocked += int(
						_occluded(geometry.get_node("BackWall"), lab._camera.global_position, ball)
					)
					var pole: Node = geometry.get_node_or_null("LiveObjectPole")
					if pole != null:
						blocked += int(_occluded(pole, lab._camera.global_position, ball))
					var scenery: Node = geometry.get_node_or_null("CommonsParkScenery")
					if scenery != null:
						blocked += int(_occluded(scenery, lab._camera.global_position, ball))
					var bounds: Rect2 = Rect2(Vector2(24, 24), Vector2(1232, 672))
					outside += int(
						(
							lab._camera.is_position_behind(ball)
							or not bounds.has_point(lab._camera.unproject_position(ball))
						)
					)
					max_step = maxf(
						max_step, last_transform.origin.distance_to(lab._camera.global_position)
					)
					max_turn = maxf(
						max_turn,
						last_transform.basis.get_rotation_quaternion().angle_to(
							lab._camera.global_basis.get_rotation_quaternion()
						)
					)
					last_transform = lab._camera.global_transform
					samples += 1

		lab.queue_free()
		await get_tree().process_frame
	print("BALL TRACKING samples=", samples, " blocked=", blocked, " outside=", outside)
	print("TRACKING CONTINUITY max_step_m=", max_step, " max_turn_degrees=", rad_to_deg(max_turn))
	_check(
		max_step < 0.75 and max_turn < deg_to_rad(8),
		"live tracking must not jump, including the first contact frame"
	)
	_check(blocked == 0, "moving/settled ball tracking must clear walls, poles and away scenery")
	_check(outside == 0, "physical ball must stay visible through the tracking transition")


func _test_contact_flights() -> void:
	var rows: Array = []
	for field_id in [PitchBatLab.FIELD_ID, SeasonState.AWAY_FIELD_ID]:
		var lab: PitchBatLab = PitchBatLab.new()
		lab._field_id = field_id
		add_child(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		for defense in [false, true]:
			for fps in [30, 60, 120]:
				for launch in [
					Vector3(0, -2, 8),
					Vector3(5, -1, 22),
					Vector3(-5, -1, 22),
					Vector3(0, 2, 33),
					Vector3(12, 5, 30),
					Vector3(-12, 5, 30),
					Vector3(0, 18, 26),
					Vector3(0, 22, 5)
				]:
					var director: MatchCameraDirector = lab._camera_director
					director.clear_presentation_motion()
					director.set_shot(
						(
							MatchCameraDirector.Shot.PITCHING
							if defense
							else MatchCameraDirector.Shot.BATTING
						)
					)
					director.snap(lab._camera)
					var ball: Vector3 = Vector3(0, 1, 0.28)
					var velocity: Vector3 = launch
					director.prepare_ball_in_play(defense, ball, velocity)
					director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
					var outside: int = 0
					var blocked: int = 0
					var max_turn: float = 0.0
					var max_step: float = 0.0
					var reverse: int = 0
					for frame in range(fps * 3):
						var before: Transform3D = lab._camera.global_transform
						# Same aerodynamic acceleration as the physical batted ball, with
						# a deterministic ground bounce for camera-only fixture replay.
						for substep in range(120 / fps):
							velocity += (
								(
									Vector3(0, -9.81, 0)
									+ BattedBallAerodynamics.acceleration(
										velocity,
										Quaternion.IDENTITY,
										Vector3.ZERO,
										0.020,
										0.0365,
										0.22,
										1.0,
										1.0,
										Vector3.RIGHT
									)
								)
								/ 120.0
							)
							ball += velocity / 120.0
							if ball.y < 0.08:
								ball.y = 0.08
								velocity.y = absf(velocity.y) * 0.52
						director.update(lab._camera, 1.0 / fps, true, ball)
						max_step = maxf(
							max_step, before.origin.distance_to(lab._camera.global_position)
						)
						max_turn = maxf(
							max_turn,
							before.basis.get_rotation_quaternion().angle_to(
								lab._camera.global_basis.get_rotation_quaternion()
							)
						)
						outside += int(
							(
								lab._camera.is_position_behind(ball)
								or not Rect2(24, 24, 1232, 672).has_point(
									lab._camera.unproject_position(ball)
								)
							)
						)
						blocked += int(
							_environment_occluded(lab, ball)
						)
						if defense and launch.y < 0:
							reverse += int((-lab._camera.global_basis.z).z > 0)
						if ball.z > 23.0 or (launch.z == 8 and frame > fps / 2):
							break
					rows.append(
						{
							"field": field_id,
							"defense": defense,
							"fps": fps,
							"launch": str(launch),
							"outside": outside,
							"blocked": blocked,
							"reverse": reverse,
							"max_turn": rad_to_deg(max_turn),
							"max_step": max_step
						}
					)
					_check(outside == 0, "real flight remains framed: " + str(rows.back()))
					_check(blocked == 0, "real flight remains unobscured: " + str(rows.back()))
					_check(reverse == 0, "ground contact must not reverse the defensive view")
					_check(
						max_turn < 1.7 / fps and max_step < 32.1 / fps,
						"contact transition respects motion limits from its first frame"
					)
		lab.queue_free()
		await get_tree().process_frame
	print("CONTACT_CAMERA_JSON=", JSON.stringify(rows))


func _environment_occluded(lab: PitchBatLab, ball: Vector3) -> bool:
	var geometry: Node = lab.get_node("StarterFieldGeometry")
	for part in ["BackWall", "LiveObjectPole", "CommonsParkScenery"]:
		var node: Node = geometry.get_node_or_null(part)
		if node != null and _occluded(node, lab._camera.global_position, ball):
			return true
	return false


func _occluded(node: Node, from: Vector3, to: Vector3) -> bool:
	if node is MeshInstance3D and node.visible and node.mesh != null:
		var inverse: Transform3D = node.global_transform.affine_inverse()
		if node.get_aabb().intersects_segment(inverse * from, inverse * to) != null:
			return true
	for child in node.get_children():
		if _occluded(child, from, to):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
