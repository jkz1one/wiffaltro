extends "res://src/tests/stadium_yard_two_camera_test.gd"
## Bounded native disposal proof only. No trajectory or pixel-contrast qualification.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(DisplayServer.get_name() != "headless", "ordinary teardown requires actual native draws")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native teardown readback initialization succeeds")
	var original_quality: int = get_viewport().msaa_3d
	await _setup_views()
	_check(get_viewport().msaa_3d == original_quality, "ordinary setup deletion restores quality")
	await _ordinary_teardown_tracking_fixture()
	_check(
		get_viewport().msaa_3d == original_quality, "ordinary tracking deletion restores quality"
	)
	_check(_ay02_camera_disposals == 2, "exactly two ordinary camera lab owners deleted")
	_check(_native._failures == 0, "all ordinary setup capture failures propagate")
	await TestAudioDrain.finish(get_tree())
	print(
		"AY02_ORDINARY_TEARDOWN_DIAGNOSTIC owners=",
		_ay02_camera_disposals,
		" setup_views=13 trajectories=0 full_qualification=false failures=",
		_failures
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _ordinary_teardown_tracking_fixture() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_yard_two_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	if not StadiumYardTwoLab.install(lab):
		_check(false, "ordinary teardown tracking fixture installs")
		await _ay02_dispose_camera_lab(lab, "diagnostic-install-failure")
		return
	lab._batter_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	lab._ball_play_resolver.start_play(lab._field_definition)
	# Invoke the exact ordinary terminal path: lifecycle, ball cleanup, and verified draws.
	await _finish_qualified_camera_lab(lab)
