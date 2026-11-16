extends "res://src/tests/stadium_infield_night_test.gd"
## A ground-level ball remains visible through cosmetic raised bases in day and night views.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	for ground: String in StadiumInfieldModels.IDS:
		_ground = ground
		await _rolls()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro base visibility checks passed: rolling ball, soft fade and unchanged geometry.")
	get_tree().quit(0 if _failures == 0 else 1)


func _rolls() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._status_label.visible = false
	var lamps: Array[Node3D] = _install_tracking(lab)
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var markers: Node3D = property.get_node("BaseMarkerSet")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	var contrasts: Dictionary = {}
	var samples: int = 0
	for dark: bool in [false, true]:
		if dark:
			_night_scene(lab)
		for lamp: Node3D in lamps:
			StadiumYardLightModels.night(lamp, dark)
		for defense: bool in [false, true]:
			for marker: MeshInstance3D in markers.get_children():
				var original: Transform3D = marker.transform
				var bounds: AABB = marker.get_aabb()
				var point: Vector3 = Vector3(marker.position.x, ball.radius_m, marker.position.z)
				var director: MatchCameraDirector = lab._camera_director
				director.set_shot(MatchCameraDirector.Shot.PITCHING if defense \
					else MatchCameraDirector.Shot.BATTING)
				director.snap(lab._camera)
				director.prepare_ball_in_play(defense, point, Vector3(1, 0, 0))
				director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
				for frame in range(121):
					ball.position = point
					director.update(lab._camera, 1.0 / 60, true, point)
					StadiumPropertyRuntime.refresh_receiver_visibility(lab, true)
					_check(marker.get_meta("base_render_state") == "faded",
						"actual ground-height ball fades the raised visual bag")
					samples += 1
				_check(marker.transform == original and marker.get_aabb() == bounds,
					"fade does not move, shrink or remove the marker")
				if DisplayServer.get_name() != "headless":
					var contrast: float = await _contrast(lab._camera, ball)
					var key: String = str(defense) + str(marker.name)
					if dark:
						print("BASE_BALL_CONTRAST ", _ground, " ", key,
							" day=", contrasts[key], " night=", contrast)
						_check(contrast >= maxf(0.03, contrasts[key] * 0.65),
							"night rolling ball remains distinguishable at every base")
					else:
						contrasts[key] = contrast
					await _shot("base-" + key + "-" + str(dark))
	lab._batted_ball = null
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	for marker: MeshInstance3D in markers.get_children():
		_check(marker.get_meta("base_render_state") == "visible", "all bags restore after ball cleanup")
	_check(samples == 1452, "all three bases, both camera roles and both environments exercised")
	lab.queue_free()
	await get_tree().process_frame
