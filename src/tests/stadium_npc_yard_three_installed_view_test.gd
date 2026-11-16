extends "res://src/tests/stadium_yard_three_camera_test.gd"
## Current installed static daylight views only; historical tracking/game evidence stays separate.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(DisplayServer.get_name() != "headless" and not _capture_dir.is_empty(),
		"rendered daylight views require an actual display and fresh capture directory")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native startup handshake has no hidden failure")
	if _failures == 0:
		await _setup_views()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro AY03 installed static daylight views passed: "
			+ "two sizes, both hands, three roles.")
	get_tree().quit(0 if _failures == 0 else 1)


func _setup_views() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
	lab.set_meta("stadium_npc_retained_lab_only", true)
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
	if not StadiumNpcYardThreeRuntimeV1.install(lab):
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
	_check(StadiumNpcYardThreeRuntimeV1.installed(lab), "current installed binding survives views")
	# Draw transient native views before freeing, preserving the existing startup-lifecycle fix.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame



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
				"overview frames the full installed model at " + str(model.name))
	await _shot("ay03-complete-property-eight-copies")
	camera.projection = projection as Camera3D.ProjectionType
	camera.size = size
	camera.fov = fov
	camera.global_transform = before

