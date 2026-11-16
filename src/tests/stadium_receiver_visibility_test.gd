extends Node
## Real lab transitions must reveal a receiver before the first batted-ball physics advance.

var _failures: int = 0


func _ready() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	_check(StadiumPropertyRuntime.install_lab(lab, layout, StadiumStock.new_club()),
		"actual lab installs owned chair")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var chair: Node3D = property.objects["starter-v1:ST-079"]
	lab._camera_mode = 0
	PitchBatLabPresentation.apply_camera_mode(lab)
	PitchBatLabPresentation.refresh_markers(lab)
	_check(not chair.get_node("Visual").visible, "batting pitch view hides the receiver")
	lab._camera_mode = 2
	PitchBatLabPresentation.apply_camera_mode(lab)
	_check(chair.get_node("Visual").visible, "side inspection reveals receiver independently of role")
	lab._camera_mode = 0
	PitchBatLabPresentation.apply_camera_mode(lab)
	lab._match_state.begin_pitch()
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 1.0, 0.2)
	launch.velocity = Vector3(0, 0, -6)
	launch.is_foul = true
	lab._start_ball_in_play(launch)
	_check(chair.get_node("Visual").visible,
		"real ball-in-play transition reveals receiver before any physics frame")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro receiver visibility checks passed: camera and pre-physics reveal transitions.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
