extends "res://src/tests/stadium_infield_night_test.gd"
## Fast regression for the low sinker over pale sand that exposed the night contrast boundary.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	_ground = "ST-063j"
	for left: bool in [false, true]:
		await _probe(left)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro sand contrast checks passed: sinker fixture; native mode checks pixels.")
	get_tree().quit(0 if _failures == 0 else 1)


func _probe(left: bool) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._status_label.visible = false
	var lamps: Array[Node3D] = _install_tracking(lab)
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
		else PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	lab._camera_director.set_batter_handedness(left)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
	lab._camera_director.snap(lab._camera)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	var actor: PitchFlightActor = PitchFlightActor.new()
	lab.add_child(actor)
	actor.set_physics_process(false)
	var pitch: PitchDefinition = MatchLabSupport.rated_pitch(
		ContentDB.get_pitch(&"pitch.overhand_sinker"),
		ContentDB.get_player(&"player.debug_pitcher"), 1.0)
	var launch: PitchLaunchParameters = PitchAimSolver.solve(pitch,
		ContentDB.get_ball_setup(&"ball_setup.fresh"), PitchBatLab.MOUND_ORIGIN,
		Vector3(0, 1.05, 0), left, 41)
	_check(launch != null, "known sinker fixture solves")
	if launch != null:
		actor.start_pitch(launch)
		while actor.running and actor.global_position.z > 1.0:
			actor._physics_process(1.0 / 240)
		_check(actor.running and actor.global_position.z > 0, "actual approach sample reached")
		if DisplayServer.get_name() != "headless":
			var day: float = await _contrast(lab._camera, actor)
			_night_scene(lab)
			StadiumNightBallStyle.apply(actor)
			for lamp: Node3D in lamps:
				StadiumYardLightModels.night(lamp, true)
			var dark: float = await _contrast(lab._camera, actor)
			print("SAND_SINKER_CONTRAST hand=", left, " day=", day, " night=", dark)
			_check(dark >= maxf(0.03, day * 0.65), "low night sinker stays distinguishable over sand")
			await _shot("sand-sinker-" + str(left))
	actor.reset_pitch()
	lab.queue_free()
	await get_tree().process_frame
