extends "res://src/tests/stadium_offset_tracking_test.gd"
## Reuses qualified tracking probes for the full AY-03, both hands/roles and three sample rates.


const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
var _native: Node


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native startup handshake has no hidden failure")
	if _failures > 0:
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	await _setup_views()
	if _failures > 0:
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	_check(await _native.resize(Vector2i(1280, 720)), "tracking extent acknowledged")
	for fps: int in [30, 60, 120]:
		_sample_fps = fps
		await _walls("yard-complete", "eight-copies")
		if _failures > 0:
			break
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro yard-three camera passed: full AY-03 tracking, both hands and roles.")
	get_tree().quit(0 if _failures == 0 else 1)


func _install_walls(lab: PitchBatLab, _shape_name: String, _item: String) -> void:
	lab.set_meta("stadium_yard_three_lab_only", true)
	_check(StadiumYardThreeLab.install(lab), "complete AY-03 installs without paid history")
	_check(lab._camera_director.tracking_visibility is StadiumYardFieldVisibility,
		"candidate uses exact template prism visibility")
	_check(is_equal_approx(lab._camera_director.tracking_visibility.field_wall_z, 23.4),
		"camera uses the exact straight template depth")


func _endpoints(_depth: float) -> Array[Vector3]:
	return [Vector3(0, 0.15, 23.3), Vector3(-8, 0.15, 22.4), Vector3(13, 0.15, 22.9),
		Vector3(7, 0.15, 11.75), Vector3(-17, 0.7, 12), Vector3(17, 0.7, 12),
		Vector3(-22, 0.7, 22), Vector3(22, 0.7, 22), Vector3(0, 7, 26), Vector3(0, 35, 25)]


func _setup_views() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_yard_three_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	# Skipping intro intentionally posts the at-bat readiness prompt. Only hide that test
	# overlay; do not confirm an at-bat, alter the match, or hide scorebug/ordinary HUD.
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	_check(not lab._presentation_backdrop.visible and not lab._status_label.visible,
		"setup capture has no intro/readiness overlay")
	lab.set_process(false)
	lab.set_physics_process(false)
	if not StadiumYardThreeLab.install(lab):
		_check(false, "complete yard setup camera fixture")
		lab.queue_free()
		await get_tree().process_frame
		return
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(size), "native setup window extent acknowledged")
		for left: bool in [false, true]:
			lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
			lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
				else PlayerDefinition.Handedness.RIGHT
			PitchBatLabPresentation.sync_players(lab)
			for shot: int in [MatchCameraDirector.Shot.ESTABLISHING,
				MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
				lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
				lab._camera_director.snap(lab._camera)
				var target: Vector3 = Vector3(0, 1, 0)
				_check(not lab._camera.is_position_behind(target), "plate corridor remains in front")
				await _shot("ay03-%dx%d-hand%d-shot%d" % [size.x, size.y, int(left), shot])
	await _overview(lab)
	await _physical_visibility(lab)
	# Draw transient native views before freeing, preserving the existing startup-lifecycle fix.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame


func _shot(name_value: String) -> void:
	if DisplayServer.get_name() == "headless" or _capture_dir.is_empty():
		return
	var captured: bool = await _native.capture(_capture_dir, name_value)
	_check(captured, "native capture/readback handshake succeeds")
	if captured:
		var expected: Vector2i = _native._expected_content_size(get_window().size)
		var path: String = _capture_dir.path_join("%s-%dx%d.png" % [name_value, expected.x, expected.y])
		var saved: Image = Image.load_from_file(path)
		_check(saved != null and saved.get_size() == expected,
			"saved PNG dimensions match the acknowledged native content extent")


func _physical_visibility(lab: PitchBatLab) -> void:
	# Query the real installed slabs/chairs on a test-only layer; keep all original layers intact.
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var mask: int = 1 << 25
	var bodies: Array[Node] = property.find_children("*", "StaticBody3D", true, false)
	var layers: Array[int] = []
	for body: StaticBody3D in bodies:
		layers.append(body.collision_layer)
		body.collision_layer |= mask
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = lab.get_world_3d().direct_space_state
	var control: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 2, 22), Vector3(0, 2, 25), mask)
	var hit: Dictionary = space.intersect_ray(control)
	_check(not hit.is_empty() and hit.collider.has_meta("boundary_segment"),
		"physical LOS positive control detects actual template back slab")
	control.from = Vector3(0, 6, -3)
	control.to = Vector3(0, 1, 14)
	_check(space.intersect_ray(control).is_empty(), "physical LOS clear-corridor negative control")
	for site: String in ["YLIGHT-FL", "YLIGHT-FR", "YLIGHT-RL", "YLIGHT-RR"]:
		var model: Node3D = property.objects["npc-candidate:AY-03:" + site]
		control.from = model.position + Vector3(0, 2, -1)
		control.to = model.position + Vector3(0, 2, 1)
		hit = space.intersect_ray(control)
		_check(not hit.is_empty() and hit.collider.get_meta("stadium_item", "") == "ST-037",
			"physical LOS positive control detects the actual pole " + site)
	var blocked: int = 0
	var samples: int = 0
	var director: MatchCameraDirector = lab._camera_director
	for fps: int in [30, 60, 120]:
		for left: bool in [false, true]:
			director.set_batter_handedness(left)
			for defense: bool in [false, true]:
				for endpoint: Vector3 in _endpoints(0):
					director.clear_presentation_motion()
					director.set_shot(MatchCameraDirector.Shot.PITCHING if defense \
						else MatchCameraDirector.Shot.BATTING)
					director.snap(lab._camera)
					director.prepare_ball_in_play(defense, Vector3(0, 1, 0), endpoint - Vector3(0, 1, 0))
					director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
					for frame in range(fps * 4):
						var ball: Vector3 = Vector3(0, 1, 0).lerp(endpoint, minf(1, frame / (fps * 2.5)))
						director.update(lab._camera, 1.0 / fps, true, ball)
						control.from = lab._camera.global_position
						control.to = ball
						blocked += int(not space.intersect_ray(control).is_empty())
						samples += 1
	for index in range(bodies.size()):
		bodies[index].collision_layer = layers[index]
	print("YARD_THREE_PHYSICAL_LOS samples=", samples, " blocked=", blocked)
	_check(samples == 33600 and blocked == 0,
		"all sampled actual camera rays clear installed physical slabs, chair bodies and dormant poles")


func _overview(lab: PitchBatLab) -> void:
	_check(await _native.resize(Vector2i(1280, 720)), "complete-property overview extent acknowledged")
	var camera: Camera3D = lab._camera
	var before: Transform3D = camera.global_transform
	var projection: int = camera.projection
	var size: float = camera.size
	var fov: float = camera.fov
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 50
	camera.global_position = Vector3(0, 50, -34)
	camera.look_at(Vector3(0, 0, 11))
	var framing: Rect2 = get_viewport().get_visible_rect().grow(-24)
	var ground: AABB = StadiumProperty.ground_bounds("backyard")
	for corner in range(8):
		_check(not camera.is_position_behind(ground.get_endpoint(corner))
			and framing.has_point(camera.unproject_position(ground.get_endpoint(corner))),
			"overview frames the complete actual default Backyard surface")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	for model: Node3D in property.objects.values():
		var envelope: AABB = StadiumYardLightModels.ENVELOPE if model.get_meta("stadium_item") \
			== "ST-037" else StadiumSeatingLayout.envelope("ST-080")
		var bounds: AABB = model.global_transform * envelope
		for corner in range(8):
			_check(framing.has_point(camera.unproject_position(bounds.get_endpoint(corner))),
				"overview frames the full installed model at " + str(model.get_meta("candidate_site")))
	await _shot("ay03-complete-property-eight-copies")
	camera.projection = projection as Camera3D.ProjectionType
	camera.size = size
	camera.fov = fov
	camera.global_transform = before


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
	if not lab.has_meta("stadium_property") or _failures > 0:
		lab.queue_free()
		await get_tree().process_frame
		return
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
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	_check(int(get_viewport().msaa_3d) == original,
		"closing tracked wall field restores viewport quality")
