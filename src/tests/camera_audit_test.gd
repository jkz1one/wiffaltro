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
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro camera audit passed.")
	get_tree().quit(0 if _failures == 0 else 1)


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
