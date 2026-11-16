extends Node3D
## Actual named-surface sweeps and post-call presentation; never synthetic gameplay credit.

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var stock: StadiumStock = StadiumStock.new_club()
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", layout, stock), "owned receiver geometry")
	var receiver: StadiumPitchReceiver = StadiumPitchReceiver.new()
	property.add_child(receiver)
	receiver.configure(property.objects["starter-v1:ST-079"])
	await get_tree().physics_frame
	await get_tree().physics_frame
	for sample: Array in [[Vector3(0, 0.65, 0), "ST079_BACK"],
		[Vector3(0, 0.47, 0), "ST079_SEAT"], [Vector3(0.27, 0.60, 0), "ST079_ARM"],
		[Vector3(0.22, 0.22, 0), "ST079_FRONT_LEG"]]:
		var path: Dictionary = receiver.trace(sample[0], Vector3(0, 0, -10), 0.0365)
		_check(not path.hit.is_empty() and String(path.hit.get("surface", "")).begins_with(sample[1]),
			"sweep identifies first actual " + sample[1])
		_check(path.times[-1] <= 0.24 and path.hit.get("copy") == "starter-v1:ST-079",
			"one bounded presentation contact belongs to the installed copy")
	for start: Vector3 in [Vector3(0, 1.3, 0), Vector3(0.7, 0.7, 0)]:
		var path: Dictionary = receiver.trace(start, Vector3(0, 0, -10), 0.0365)
		_check(path.hit.is_empty() and path.reason == "receiver_cleanup"
			and is_equal_approx(path.points[-1].z, -1.4), "miss cleans up without a phantom surface")
	var slow: Dictionary = receiver.trace(Vector3(0, 1.3, 0), Vector3(0, 0, -0.5), 0.0365)
	_check(slow.hit.is_empty() and slow.reason == "receiver_presentation_timeout"
		and is_equal_approx(slow.times[-1], 0.24), "slow miss is a silent bounded timeout")
	await _capture_visual(property, receiver)
	property.queue_free()
	await get_tree().process_frame
	for height: float in [0.65, 1.3, 0.47]:
		for left: bool in [false, true]:
			await _called_pitch(height, left)
	await _default_receiver()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro receiver checks passed: real sweeps, unchanged calls, one contact and recovery.")
	get_tree().quit(0 if _failures == 0 else 1)


func _called_pitch(height: float, left: bool) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
		else PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	_check(lab._batter_avatar.bats_left == left, "actual receiver view uses the chosen batter hand")
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	_check(StadiumPropertyRuntime.install_lab(lab, layout, StadiumStock.new_club()),
		"real lab installs chair presentation")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var receiver: StadiumPitchReceiver = property.get_node("PitchReceiverPresentation")
	var actor: PitchFlightActor = lab._pitch_actor
	actor.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._match_state.begin_pitch()
	actor.start_pitch(_parameters(height))
	actor._physics_process(0.2) # One large update crosses the logical call and receiver distance.
	var calls: Vector2i = Vector2i(lab._match_state.balls, lab._match_state.strikes)
	_check(calls == (Vector2i(1, 0) if height < 0.55 else Vector2i(0, 1)),
		"logical call is decided at z=0 before any chair presentation")
	var paused_position: Vector3 = actor.global_position
	get_tree().paused = true
	for frame in range(4):
		await get_tree().process_frame
	_check(actor.global_position == paused_position and receiver.contacts.is_empty(),
		"pause cannot advance the receiver path or emit a hidden contact")
	get_tree().paused = false
	var expected: int = 0 if height > 1 else 1
	var chair: Node3D = property.objects["starter-v1:ST-079"]
	var collider: Transform3D = chair.get_node("Collision/ST079_BACK").transform
	var largest_rock: float = 0
	for frame in range(40):
		await get_tree().process_frame
		_check(chair.get_node("Collision/ST079_BACK").transform == collider,
			"visual rocking never changes the actual collider")
		largest_rock = maxf(largest_rock, absf(chair.get_node("Visual").rotation.z))
		_check(largest_rock <= deg_to_rad(6.001), "rock stays bounded")
	_check(receiver.contacts.size() == expected and not actor.visible,
		"called pitch emits at most one real chair contact and disappears")
	_check(Vector2i(lab._match_state.balls, lab._match_state.strikes) == calls,
		"chair hit or miss cannot revise the earlier call")
	_check(is_zero_approx(chair.get_node("Visual").rotation.z), "chair recovers its rest pose")
	_check(largest_rock > deg_to_rad(0.2) if expected == 1 else is_zero_approx(largest_rock),
		"only a real impact visibly rocks the chair")
	if expected == 1:
		_check(lab._sounds.last_cue == (&"chair_seat" if height < 0.55 else &"chair_back"),
			"actual hit chooses its named plastic cue")
	var before: int = receiver.contacts.size()
	actor.visible = true
	actor._begin_plate_follow_through(Vector3(0, 0.65, 0), Vector3(0, 0, -10))
	actor.reset_pitch()
	for frame in range(20):
		await get_tree().process_frame
	_check(receiver.contacts.size() == before and not actor.visible,
		"cancelled follow-through cannot emit a delayed phantom impact")
	var batted: BattedBallBody = BattedBallBody.new()
	lab.add_child(batted)
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(lab._field_definition)
	property.bind_ball(batted, resolver)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 0.75, 0.2)
	launch.velocity = Vector3(0, 0, -6)
	batted.launch(launch)
	for frame in range(60):
		await get_tree().physics_frame
		if resolver.state.dead:
			break
	_check(resolver.state.dead and receiver.contacts.size() == before + 1
		and receiver.contacts[-1].kind == "batted",
		"actual batted receiver collision emits one matching physical presentation")
	batted.queue_free()
	lab.queue_free()
	await get_tree().process_frame


func _default_receiver() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(StadiumPropertyRuntime.install_lab(lab, StadiumStarterLayout.empty(),
		StadiumStock.new_club())
		and not lab._pitch_actor.receiver_router.is_valid(), "default template installs no phantom chair")
	# Native sky uploads are deferred; complete startup before testing scene disposal.
	for frame in range(3):
		await get_tree().process_frame
	lab.queue_free()
	await get_tree().process_frame


func _capture_visual(property: StadiumPropertyGeometry, receiver: StadiumPitchReceiver) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "receiver image requires native rendering")
	if DisplayServer.get_name() == "headless":
		return
	get_window().size = Vector2i(1280, 720)
	var camera: Camera3D = Camera3D.new()
	property.add_child(camera)
	camera.position = Vector3(-1.6, 1.2, 1.1)
	camera.look_at(Vector3(0, 0.5, -1.05))
	camera.fov = 40
	camera.make_current()
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 0.8
	property.add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("142520")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.4
	property.add_child(environment)
	var label: Label = Label.new()
	label.text = "ST-079 • Impact"
	label.position = Vector2(36, 28)
	label.add_theme_font_size_override("font_size", 30)
	property.add_child(label)
	var actor: PitchFlightActor = PitchFlightActor.new()
	property.add_child(actor)
	actor.set_physics_process(false)
	actor.receiver_router = receiver.route
	actor.global_position = Vector3(0, 0.65, 0)
	actor.visible = true
	actor._begin_plate_follow_through(actor.global_position, Vector3(0, 0, -10))
	for frame in range(20):
		await get_tree().process_frame
		if not receiver.contacts.is_empty():
			break
	for frame in range(4):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join("receiver-impact.png")) == OK, "actual impact pose saved")
	for frame in range(30):
		await get_tree().process_frame
	label.text = "ST-079 • Settled"
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join("receiver-settled.png")) == OK, "actual settled pose saved")


func _parameters(height: float) -> PitchLaunchParameters:
	var value: PitchLaunchParameters = PitchLaunchParameters.new()
	value.pitch_id = &"pitch.overhand_four_seam"
	value.position = Vector3(0, height, 0.4)
	value.velocity = Vector3(0, 0, -10)
	value.drag_coefficient = 0
	value.magnus_scale = 0
	value.perforation_force_scale = 0
	value.seed = 51
	return value


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
