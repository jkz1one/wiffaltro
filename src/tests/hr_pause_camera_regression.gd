extends Node

var _checks: int = 0
var _failures: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for center: bool in [false, true]:
		for terminal: bool in [false, true]:
			await _case(terminal, center)
	await TestAudioDrain.finish(get_tree())
	print("HR_PAUSE_CAMERA checks=", _checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)

func _case(terminal: bool, center: bool) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab._record_export.path = "user://hr-pause-%s.json" % terminal
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	if center:
		lab.set_meta("stadium_center_board_lab_only", true)
		_check(StadiumCenterBoardLab.install(lab), "candidate center board installs while idle")
	lab._match_state.top_half = false
	lab._match_state.inning = 5 if terminal else 1
	lab._awaiting_batter_confirm = false
	lab._active_play_record = PlayRecord.new()
	lab._primary_fielder.set_physics_process(false)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(3, 4.5, 21)
	launch.velocity = Vector3(0, 0, 15)
	lab._start_ball_in_play(launch)
	lab._pitcher_attempted = true
	lab._primary_attempts = 2
	for frame in range(180):
		await get_tree().physics_frame
		if lab._home_run.active and lab._home_run.elapsed >= 0.1:
			break
	_check(lab._home_run.active and not lab._home_run.flight_complete,
		"real scored HR begins physical followthrough before pausing")
	_check(lab._play_records.size() == 1 and lab._play_records[0].result == &"home_run",
		"real wall clearance records exactly one HR")
	lab._display_menu_button.pressed.emit()
	var clock: float = lab._home_run.elapsed
	var body: Transform3D = lab._batted_ball.global_transform
	var camera: Transform3D = lab._camera.global_transform
	var shot: MatchCameraDirector.Shot = lab._camera_director.shot
	var fov: float = lab._camera.fov
	for frame in range(8):
		await get_tree().physics_frame
	_check(lab._debug_paused and get_tree().paused, "ordinary pause is active")
	_check(lab._home_run.elapsed == clock and lab._batted_ball.global_transform == body,
		"pause freezes HR clock and physical body")
	print("HR_PAUSE_DRIFT terminal=", terminal, " center=", center,
		" distance=", camera.origin.distance_to(lab._camera.global_position))
	_check(lab._camera.global_transform == camera and lab._camera.fov == fov,
		"pause without inspection freezes automatic HR camera movement")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_V
	key.pressed = true
	PitchBatLabInput.handle(lab, key)
	for frame in range(8):
		await get_tree().physics_frame
	_check(lab._camera_director.shot != shot and lab._camera.global_transform != camera,
		"explicit paused V inspection still moves the camera")
	_check(lab._home_run.elapsed == clock and lab._batted_ball.global_transform == body,
		"inspection never advances scored flight")
	var inspection: Transform3D = lab._camera.global_transform
	lab._display_menu_button.pressed.emit()
	_check(not lab._debug_paused and not get_tree().paused
		and lab._camera_director.shot == shot and lab._camera.global_transform == inspection,
		"resume restores original view without a camera snap")
	for frame in range(8):
		await get_tree().physics_frame
	_check(lab._home_run.elapsed > clock and lab._batted_ball.global_transform != body,
		"resume advances the same physical HR")
	_check(lab._play_records.size() == 1 and lab._match_state.home_team.runs == 1,
		"pause and resume cannot duplicate scoring")
	lab.queue_free()
	await get_tree().process_frame

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(label)
