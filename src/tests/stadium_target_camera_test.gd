extends Node3D
## Actual camera transforms plus finite foreground samples, without altering physical contacts.

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	for left: bool in [false, true]:
		await _matrix(left)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro target camera checks passed: fixed views, foreground fade and stable colliders.")
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
	var helper: Node = load("res://src/tests/stadium_target_receiver_test.gd").new()
	var receiver: StadiumTargetReceiver = helper._install_target(lab, property)
	_check(helper._failures == 0, "explicit target authoring fixture")
	helper.free()
	var target: Node3D = receiver.chair
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
		else PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	var before: Dictionary = _colliders(target)
	var camera: Camera3D = lab._camera
	var director: MatchCameraDirector = lab._camera_director
	director.set_batter_handedness(left)
	director.tracking_visibility.configure(lab.get_node("StarterFieldGeometry"))
	var target_bounds: AABB = target.global_transform * StadiumTargetModels.ENVELOPE
	for shot in range(MatchCameraDirector.Shot.size()):
		director.set_shot(shot as MatchCameraDirector.Shot)
		director.snap(camera, Vector3(0, 1.05, 0))
		StadiumPropertyRuntime.refresh_receiver_visibility(lab)
		_check(target.get_node("Visual").visible == (shot != MatchCameraDirector.Shot.BATTING),
			"each fixed view follows receiver visibility rather than batting role")
		_check(not target_bounds.grow(camera.near * 2).has_point(camera.global_position),
			"fixed camera and near plane remain outside complete target envelope")
		if shot in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
			_check(not camera.is_position_behind(Vector3(0, 1.05, 0))
				and camera.get_viewport().get_visible_rect().has_point(
					camera.unproject_position(Vector3(0, 1.05, 0))), "plate target remains in frame")
			await _shot("target-%s-%s" % ["left" if left else "right",
				"batting" if shot == MatchCameraDirector.Shot.BATTING else "pitching"])
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	ball.position = Vector3(0, 1.05, 0.1)
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	director.snap(camera)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	_check(target.get_meta("receiver_render_state") == "faded",
		"receiver reveals with a foreground fade when it lies between the camera and live ball")
	await _shot("target-%s-foreground" % ["left" if left else "right"])
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
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			_check(target.get_node("Visual").visible, "tracking never hides the receiver altogether")
			_check(not target_bounds.grow(camera.near).has_point(camera.global_position),
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
	# A field-side contact/review view sees the panel fully opaque; it is not hidden with collision.
	camera.position = Vector3(2, 1.8, 2)
	camera.look_at(target.position + Vector3(0, 1.05, 0))
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	_check(target.get_meta("receiver_render_state") == "visible",
		"clear contact view restores opacity")
	_check(ClubCareer.same(before, _colliders(target)),
		"all visibility changes leave colliders intact")
	lab._cleanup_batted_ball()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame


func _colliders(target: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for body: StaticBody3D in target.get_node("Collision").get_children():
		result[body.name] = {"transform": str(body.transform), "layer": body.collision_layer,
			"mask": body.collision_mask, "surface": body.get_meta("surface_id")}
	return result


func _shot(name_value: String) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "camera captures need native rendering")
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join(name_value + ".png")) == OK, "actual camera frame captured")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
