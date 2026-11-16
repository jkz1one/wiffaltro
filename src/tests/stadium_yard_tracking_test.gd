extends "res://src/tests/stadium_target_camera_test.gd"
## Sampled actual tracking and paired native ball-present/absent contrast, day versus night.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	for left: bool in [false, true]:
		await _track(left)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro yard tracking checks passed: "
			+ "sampled paths; native mode additionally checks ball contrast.")
	get_tree().quit(0 if _failures == 0 else 1)


func _track(left: bool) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	var lamps: Array[Node3D] = _install_tracking(lab)
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
		else PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	var director: MatchCameraDirector = lab._camera_director
	director.set_batter_handedness(left)
	director.tracking_visibility.configure(lab.get_node("StarterFieldGeometry"))
	for lamp: Node3D in lamps:
		# Prototype scenery participates in ordinary occlusion, not a live-pole tactical cue.
		director.tracking_visibility._collect(lamp.get_node("Visual"), false)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	var contrasts: Dictionary = {}
	var samples: int = 0
	var blocked: int = 0
	var outside: int = 0
	var endpoints: Array[Vector3] = _tracking_endpoints()
	for dark: bool in [false, true]:
		if dark:
			_night_scene(lab)
		for lamp: Node3D in lamps:
			StadiumYardLightModels.night(lamp, dark)
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
					director.update(lab._camera, 1.0 / 60, true, ball.position)
					var screen: Vector2 = lab._camera.unproject_position(ball.position)
					outside += int(lab._camera.is_position_behind(ball.position)
						or not Rect2(24, 24, 1232, 672).has_point(screen))
					for lamp: Node3D in lamps:
						for mesh: MeshInstance3D in lamp.get_node("Visual").get_children():
							var box: AABB = mesh.global_transform * mesh.get_aabb()
							blocked += int(box.intersects_segment(lab._camera.global_position,
								ball.position) != null)
					samples += 1
				if DisplayServer.get_name() != "headless":
					var contrast: float = await _contrast(lab._camera, ball)
					var id: String = str(defense) + str(endpoint)
					if dark:
						print("YARD_BALL_CONTRAST ", left, " ", id, " day=", contrasts[id],
							" night=", contrast)
						_check(contrast >= maxf(0.03, contrasts[id] * 0.65),
							"sampled night ball remains distinguishable relative to daylight")
					else:
						contrasts[id] = contrast
					if endpoint == endpoints[3]:
						await _shot("yard-ball-%s-%s-%s" % [str(left), str(defense), str(dark)])
	print("YARD_TRACKING samples=", samples, " blocked=", blocked, " outside=", outside)
	_check(samples == 7680 and blocked == 0 and outside == 0,
		"both camera roles and eight paths avoid lights and keep the ball in frame")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame


func _contrast(camera: Camera3D, ball: Node3D) -> float:
	ball.visible = true
	await RenderingServer.frame_post_draw
	var visible: Image = get_viewport().get_texture().get_image()
	ball.visible = false
	await RenderingServer.frame_post_draw
	var hidden: Image = get_viewport().get_texture().get_image()
	ball.visible = true
	var logical: Vector2 = camera.unproject_position(ball.global_position)
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var screen: Vector2i = Vector2i(logical * Vector2(visible.get_size()) / viewport_size)
	var difference: float = 0
	for x in range(maxi(0, screen.x - 5), mini(visible.get_width(), screen.x + 6)):
		for y in range(maxi(0, screen.y - 5), mini(visible.get_height(), screen.y + 6)):
			var a: Color = visible.get_pixel(x, y)
			var b: Color = hidden.get_pixel(x, y)
			difference = maxf(difference, Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length())
	return difference


func _install_tracking(lab: PitchBatLab) -> Array[Node3D]:
	_check(StadiumPropertyRuntime.install_lab(lab, StadiumStarterLayout.empty(),
		StadiumStock.new_club()), "reference geometry")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	StadiumBoundaryRuntime.assemble(property)
	var lamps: Array[Node3D] = []
	for site: String in StadiumYardLightModels.SITES:
		var lamp: Node3D = StadiumYardLightModels.create()
		property.add_child(lamp)
		StadiumYardLightModels.place(lamp, site)
		lamps.append(lamp)
	return lamps


func _night_scene(lab: PitchBatLab) -> void:
	StadiumYardNightPrototype.apply(lab)


func _tracking_endpoints() -> Array[Vector3]:
	return [Vector3(0, 0.15, 23.3), Vector3(-17, 0.15, 23.3),
		Vector3(17, 0.15, 23.3), Vector3(7, 0.15, 11.75), Vector3(-25, 1.8, 18),
		Vector3(25, 1.8, 18), Vector3(0, 7, 28), Vector3(0, 35, 25)]
