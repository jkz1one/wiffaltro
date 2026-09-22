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
			"batting camera must remain stable during a pitch"
		)
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
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro camera audit passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _test_ball_tracking() -> void:
	var blocked: int = 0
	var outside: int = 0
	var samples: int = 0
	for field_id in [PitchBatLab.FIELD_ID, SeasonState.AWAY_FIELD_ID]:
		var lab: PitchBatLab = PitchBatLab.new()
		lab._field_id = field_id
		add_child(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		var geometry: Node = lab.get_node("StarterFieldGeometry")
		for defense in [false, true]:
			for endpoint in [Vector3(0, 0.08, 23.30), Vector3(-17, 0.08, 23.30),
				Vector3(17, 0.08, 23.30), Vector3(7, 0.08, 11.75),
				Vector3(-25, 1.8, 18), Vector3(0, 7, 28)]:
				var director: MatchCameraDirector = lab._camera_director
				director.clear_presentation_motion()
				director.set_shot(MatchCameraDirector.Shot.PITCHING if defense
					else MatchCameraDirector.Shot.BATTING)
				director.snap(lab._camera)
				director.prepare_ball_in_play(defense, Vector3(0, 1, 0))
				director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
				for frame in range(240):
					var ball: Vector3 = Vector3(0, 1, 0).lerp(endpoint,
						minf(1.0, float(frame) / 150.0))
					director.update(lab._camera, 1.0 / 60.0, true, ball)
					blocked += int(_occluded(geometry.get_node("BackWall"),
						lab._camera.global_position, ball))
					blocked += int(_occluded(geometry.get_node("LiveObjectPole"),
						lab._camera.global_position, ball))
					var scenery: Node = geometry.get_node_or_null("CommonsParkScenery")
					if scenery != null:
						blocked += int(_occluded(scenery, lab._camera.global_position, ball))
					var bounds: Rect2 = Rect2(Vector2(24, 24), Vector2(1232, 672))
					outside += int(lab._camera.is_position_behind(ball) or not
						bounds.has_point(lab._camera.unproject_position(ball)))
					samples += 1
		lab.queue_free()
		await get_tree().process_frame
	print("BALL TRACKING samples=", samples, " blocked=", blocked, " outside=", outside)
	_check(blocked == 0, "moving/settled ball tracking must clear walls, poles and away scenery")
	_check(outside == 0, "physical ball must stay visible through the tracking transition")


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
