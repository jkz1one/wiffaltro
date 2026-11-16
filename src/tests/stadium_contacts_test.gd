extends Node3D
## Actual property collisions plus rule invariants; not season/replay acceptance.

var _failures: int = 0
var _outcomes: Array[BallPlayOutcome] = []
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_rules()
	var stock: StadiumStock = StadiumStock.new_club()
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}]
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", layout, stock), "actual property assembly")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _flight(property, Vector3(-8, 0.42, 15.2), Vector3(0, 0, -6), false)
	await _flight(property, Vector3(0, 0.75, 0.2), Vector3(0, 0, -6), true)
	property.queue_free()
	await get_tree().process_frame
	await _adapter(layout, stock)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro stadium contact checks passed: "
			+ "live ricochets, receiver fouls and lab integration.")
	get_tree().quit(0 if _failures == 0 else 1)


func _resolver(foul: bool = false) -> BallPlayResolver:
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
	resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome))
	return resolver


func _rules() -> void:
	for foul: bool in [false, true]:
		for grounded: bool in [false, true]:
			if foul and grounded:
				continue # A foul ground contact is already terminal.
			_outcomes.clear()
			var resolver: BallPlayResolver = _resolver(foul)
			resolver.state.has_grounded = grounded
			resolver.state.raise_result_floor(BallPlayState.ResultFloor.DOUBLE)
			_check(StadiumSurfaceRules.apply(resolver, "LIVE_RICOCHET", "copy:cone", Vector3.ZERO),
				"live named obstacle accepted")
			_check(not resolver.state.dead and resolver.state.has_grounded == grounded
				and resolver.state.is_foul_play == foul and not resolver.state.defender_touched
				and resolver.state.result_floor == BallPlayState.ResultFloor.DOUBLE,
				"ricochet preserves assigned fair/foul, ground, touch and earned floor")
			resolver.record_clean_control(&"fielder", Vector3(0, 1, 16), not grounded)
			_check(_outcomes.size() == 1 and _outcomes[0].result == (
				BallPlayOutcome.Result.DOUBLE if grounded else BallPlayOutcome.Result.OUT),
				"live airborne rebound catch differs from grounded recovery")
			_check(not StadiumSurfaceRules.apply(resolver, "RECEIVER_CONTAINMENT_FOUL",
				"copy:receiver", Vector3.ZERO) and _outcomes.size() == 1,
				"later receiver contact cannot replace an already terminal result")
		_outcomes.clear()
		var receiver: BallPlayResolver = _resolver(foul)
		_check(StadiumSurfaceRules.apply(receiver, "RECEIVER_CONTAINMENT_FOUL",
			"copy:receiver", Vector3(0, 0.5, -1)), "receiver contact is handled")
		receiver.record_clean_control(&"fielder", Vector3.ZERO, true)
		_check(_outcomes.size() == 1 and _outcomes[0].result == BallPlayOutcome.Result.FOUL
			and not _outcomes[0].caught, "receiver is terminal foul with no post-contact catch")
	var unknown: BallPlayResolver = _resolver()
	_check(not StadiumSurfaceRules.apply(unknown, "DECORATION", "copy:tree", Vector3.ZERO)
		and not unknown.state.dead, "unknown/scenery role cannot acquire live rules")


func _flight(property: StadiumPropertyGeometry, from: Vector3, velocity: Vector3,
	receiver: bool) -> void:
	_outcomes.clear()
	var resolver: BallPlayResolver = _resolver()
	var ball: BattedBallBody = BattedBallBody.new()
	add_child(ball)
	property.bind_ball(ball, resolver)
	property.bind_ball(ball, resolver)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = from
	launch.velocity = velocity
	ball.launch(launch)
	for frame in range(45):
		await get_tree().physics_frame
		if resolver.state.dead or not resolver.state.last_obstacle_contact.is_empty():
			break
	if receiver:
		_check(resolver.state.dead and _outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.FOUL,
			"gravity-on batted body collides with actual installed receiver and resolves once")
	else:
		_check(not resolver.state.dead
			and resolver.state.last_obstacle_contact == &"starter-v1:ST-001",
			"gravity-on cone collision uses the actual owned copy, never starter_pole")
	ball.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _adapter(layout: Dictionary, stock: StadiumStock) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	await get_tree().process_frame
	_check(not StadiumPropertyRuntime.install_lab(lab, layout, stock),
		"normal matches cannot opt into an unbound property")
	lab.set_meta("stadium_lab_only", true)
	lab._managed_match = true
	_check(not StadiumPropertyRuntime.install_lab(lab, layout, stock),
		"managed season matches cannot bypass the layout snapshot gate")
	lab._managed_match = false
	_check(StadiumPropertyRuntime.install_lab(lab, layout, stock), "explicit isolated lab installs")
	var geometry: Node = lab.get_node("StarterFieldGeometry")
	_check(geometry.has_node("HomeProperty") and geometry.has_node("ZoneLeft")
		and not geometry.has_node("LiveObjectPole") and not geometry.has_node("Ground"),
		"same authored property replaces old lab geometry while logical strike zone remains")
	_check(not StadiumPropertyRuntime.install_lab(lab, layout, stock), "no duplicate field assembly")
	var property: StadiumPropertyGeometry = geometry.get_node("HomeProperty")
	var receiver: Node3D = property.objects["starter-v1:ST-079"]
	geometry.set_batting_view(true)
	_check(not receiver.get_node("Visual").visible
		and (receiver.get_node("Collision/ST079_BACK").collision_layer & 1) == 1,
		"real lab batting visibility preserves receiver collision")
	_check((receiver.get_node("Collision/ST079_BACK").collision_layer
		& StadiumPitchReceiver.LAYER) != 0, "named receiver also exposes its dedicated pitch-query layer")
	geometry.set_batting_view(false)
	_check(receiver.get_node("Visual").visible, "real lab receiver returns outside batting view")
	_check(lab._camera_director.tracking_visibility.field_wall_z == property.field.back_wall_z_m,
		"camera tracks the authored property boundary")
	await _capture_lab(lab, geometry)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(-8, 0.42, 15.2)
	launch.velocity = Vector3(0, 0, -6)
	lab._start_ball_in_play(launch)
	for frame in range(45):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.last_obstacle_contact == &"starter-v1:ST-001":
			break
	_check(lab._ball_play_resolver.state.last_obstacle_contact == &"starter-v1:ST-001",
		"actual lab launch connects installed surfaces to its own game resolver")
	lab.queue_free()
	await get_tree().process_frame


func _capture_lab(lab: PitchBatLab, geometry: StarterFieldLabGeometry) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "runtime review needs actual rendered frames")
	if DisplayServer.get_name() == "headless":
		return
	get_window().size = Vector2i(1280, 720)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.confirm_batter_ready(lab)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for shot: int in [MatchCameraDirector.Shot.ESTABLISHING, MatchCameraDirector.Shot.BATTING,
		MatchCameraDirector.Shot.PITCHING]:
		lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
		geometry.set_batting_view(shot == MatchCameraDirector.Shot.BATTING)
		lab._camera_director.snap(lab._camera)
		for frame in range(3):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		_check(image.save_png(_capture_dir.path_join("backyard-runtime-%d.png" % shot)) == OK,
			"actual isolated lab frame saved")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
