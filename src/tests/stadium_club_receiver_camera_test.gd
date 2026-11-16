extends "res://src/tests/stadium_paired_camera_test.gd"
## Corrected stadium net cup: real camera clearance, both hands and per-member foreground fading.

func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	for left: bool in [false, true]:
		await _matrix(left)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro club receiver camera passed: fixed views, foreground fade and stable colliders.")
	get_tree().quit(0 if _failures == 0 else 1)


func _matrix(left: bool) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(StadiumPropertyRuntime.install_lab(lab, StadiumStarterLayout.empty(),
		StadiumStock.new_club()), "actual default lab geometry")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var helper: Node = load("res://src/tests/stadium_club_pitch_receiver_test.gd").new()
	var receiver: StadiumClubPitchReceiver = helper._install_target(lab, property)
	_check(helper._failures == 0, "explicit target authoring fixture")
	helper.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var target: Node3D = receiver.chair
	var net: Node3D = (receiver as StadiumClubPitchReceiver).net
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
		else PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	var before: Dictionary = {"target": _colliders(target), "net": _colliders(net)}
	var camera: Camera3D = lab._camera
	lab._camera_director = StadiumClubCameraDirector.new()
	var director: MatchCameraDirector = lab._camera_director
	director.set_batter_handedness(left)
	director.tracking_visibility.configure(lab.get_node("StarterFieldGeometry"))
	for shot in range(MatchCameraDirector.Shot.size()):
		director.set_shot(shot as MatchCameraDirector.Shot)
		director.snap(camera, Vector3(0, 1.05, 0))
		StadiumClubReceiverVisibility.refresh(lab, receiver)
		_check(net.get_node("Visual").visible == (shot != MatchCameraDirector.Shot.BATTING),
			"net shares hide and reveal rules across both hands and every fixed view")
		_check(target.get_node("Visual").visible == (shot != MatchCameraDirector.Shot.BATTING),
			"each fixed view follows receiver visibility rather than batting role")
		_check(_camera_clear(camera),
			"fixed camera near volume clears actual net/target members, including the empty cup")
		if shot in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
			_check(not camera.is_position_behind(Vector3(0, 1.05, 0))
				and camera.get_viewport().get_visible_rect().has_point(
					camera.unproject_position(Vector3(0, 1.05, 0))), "plate target remains in frame")
			await _shot("stadium-net-%s-%s" % ["left" if left else "right",
				"batting" if shot == MatchCameraDirector.Shot.BATTING else "pitching"])
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	for progress: float in [0.25, 0.5, 0.75, 1.0]:
		director.set_presentation_motion(MatchCameraDirector.PresentationMotion.ZOOM_OUT, progress)
		director.snap(camera)
		_check(_camera_clear(camera), "zoomed snap recovers any initial panel overlap")
	director.clear_presentation_motion()
	_sweep_corners(camera, director as StadiumClubCameraDirector)
	camera.global_position = Vector3(0, 2.2, -4.5)
	var recovered: Vector3 = (director as StadiumClubCameraDirector)._slide(
		camera, camera.global_position, camera.global_position)
	camera.global_position = recovered
	_check(_camera_clear(camera), "stationary overlapping camera has explicit recovery")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	ball.position = Vector3(0, 1.05, 0.1)
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	director.snap(camera)
	StadiumClubReceiverVisibility.refresh(lab, receiver)
	_check(target.get_meta("receiver_render_state") == "faded",
		"receiver reveals with a foreground fade when it lies between the camera and live ball")
	_check(net.get_meta("receiver_render_state") == "visible",
		"net stays visible when the camera occupies its empty cup without a member occluding the ball")
	await _shot("stadium-net-%s-foreground" % ["left" if left else "right"])
	var faded: int = 0
	for defense: bool in [false, true]:
		director.set_shot(MatchCameraDirector.Shot.PITCHING if defense \
			else MatchCameraDirector.Shot.BATTING)
		director.snap(camera)
		director.prepare_ball_in_play(defense, Vector3(0, 1.05, 0.1), Vector3(0, 0, -8))
		director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
		for frame in range(9):
			ball.position = Vector3(0, 1.05 - frame * 0.008, 0.1 - frame * 0.13)
			director.update(camera, 1.0 / 60, true, ball.position)
			StadiumClubReceiverVisibility.refresh(lab, receiver)
			_check(target.get_node("Visual").visible, "tracking never hides the receiver altogether")
			_check(_camera_clear(camera),
				"sampled tracking camera does not enter the target")
			var projected: Vector2 = camera.unproject_position(ball.position)
			if camera.is_position_behind(ball.position) or not (
				camera.get_viewport().get_visible_rect().has_point(projected)):
				print("TARGET_FRAME_FAILURE left=", left, " defense=", defense, " frame=", frame,
					" ball=", ball.position, " camera=", camera.global_position,
					" screen=", camera.unproject_position(ball.position), " fov=", camera.fov)
			_check(not camera.is_position_behind(ball.position)
				and camera.get_viewport().get_visible_rect().has_point(
					camera.unproject_position(ball.position)), "sampled backward ball stays in frame")
			faded += 1 if target.get_meta("receiver_render_state") == "faded" else 0
	_check(faded > 0, "sampled foreground path actually exercises transparency")
	# A target-width miss reaches the deeper corrected net, so qualify the longer backward path.
	for defense: bool in [false, true]:
		director.set_shot(MatchCameraDirector.Shot.PITCHING if defense \
			else MatchCameraDirector.Shot.BATTING)
		director.snap(camera)
		director.prepare_ball_in_play(defense, Vector3(1.5, 1.05, 0.1), Vector3(0, 0, -8))
		director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
		for frame in range(36):
			var old_fov: float = camera.fov
			ball.position = Vector3(1.5, 1.05 - frame * 0.008, 0.1 - frame * 0.13)
			director.update(camera, 1.0 / 60, true, ball.position)
			StadiumClubReceiverVisibility.refresh(lab, receiver)
			_check(absf(camera.fov - old_fov) < 1.0, "close-foul framing widens without an abrupt zoom")
			_check(not director._live_coverage.position_filter.is_valid(),
				"temporary collision callback cannot retain a director reference cycle")
			if not _camera_clear(camera):
				print("NET_CAMERA_BLOCK left=", left, " defense=", defense, " frame=", frame,
					" camera=", camera.global_position, " ball=", ball.position)
			_check(_camera_clear(camera), "deeper net path keeps camera clear of actual receiver members")
			var in_frame: bool = not camera.is_position_behind(ball.position) and (
				camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(ball.position)))
			if not in_frame:
				print("NET_FRAME left=", left, " defense=", defense, " frame=", frame,
					" camera=", camera.global_position, " local_ball=", camera.to_local(ball.position),
					" screen=", camera.unproject_position(ball.position), " fov=", camera.fov)
			_check(in_frame, "deeper stadium-net foul stays in frame")
	camera.position = Vector3(0, 2, -5)
	camera.look_at(ball.global_position)
	StadiumClubReceiverVisibility.refresh(lab, receiver)
	_check(net.get_meta("receiver_render_state") == "faded",
		"behind-net contact view fades the actual obstructing panel")
	await _shot("stadium-net-%s-behind-contact" % ["left" if left else "right"])
	# A field-side contact/review view sees the panel fully opaque; it is not hidden with collision.
	camera.position = Vector3(2, 1.8, 2)
	camera.look_at(target.position + Vector3(0, 1.05, 0))
	StadiumClubReceiverVisibility.refresh(lab, receiver)
	_check(target.get_meta("receiver_render_state") == "visible",
		"clear contact view restores opacity")
	_check(ClubCareer.same(before, {"target": _colliders(target), "net": _colliders(net)}),
		"all visibility changes leave colliders intact")
	lab._cleanup_batted_ball()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame


func _camera_clear(camera: Camera3D) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = camera.near * 2
	query.shape.margin = 0
	query.margin = 0
	query.collision_mask = StadiumPitchReceiver.LAYER
	query.transform.origin = camera.global_position
	return camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _sweep_corners(camera: Camera3D, director: StadiumClubCameraDirector) -> void:
	var origin: Vector3 = Vector3(0, 2, -3.4)
	for x: float in [-2.5, 0, 2.5]:
		var result: Vector3 = director._slide(camera, origin, Vector3(x, 2, -5.2))
		camera.global_position = result
		_check(result.is_finite() and _camera_clear(camera),
			"finite near-volume sweep clears center and both panel seams")
		var along: Vector3 = director._slide(camera, result, result + Vector3(0, 1, -0.1))
		camera.global_position = along
		_check(_camera_clear(camera) and along.y > result.y + 0.8,
			"panel contact retains upward tangential progress")


func _shot(name_value: String) -> void:
	# Allow the newly configured handed stance to reach the renderer before capture.
	await get_tree().process_frame
	await super._shot(name_value)
