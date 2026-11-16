extends Node3D
## Measured target-only authoring: real model, immutable colliders and actual swing poses.

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"actual full-scale property")
	_check(StadiumBoundaryRuntime.assemble(property) != null, "complete perimeter remains unchanged")
	var target: Node3D = StadiumTargetModels.create()
	target.position = StadiumTargetModels.POSITION
	target.set_meta("owned_copy", "authoring-target-only")
	property.add_child(target)
	var helper: Node = load("res://src/tests/stadium_seating_test.gd").new()
	var bounds: AABB = helper._bounds(target, target)
	helper.free()
	print("TARGET_BOUNDS ", bounds)
	_check(StadiumTargetModels.ENVELOPE.grow(0.0001).encloses(bounds),
		"all visible target parts fit the exact BY blockout")
	for body: StaticBody3D in target.get_node("Collision").get_children():
		body.set_meta("owned_copy", "authoring-target-only")
		_check(body.get_meta("surface_role") == "RECEIVER_CONTAINMENT_FOUL",
			"each named physical part is a receiver, not an Out or strike trigger")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for sample: Array in [[Vector3(0, 1.05, 0), "ST026_PANEL"],
		[Vector3(0.5, 1.05, 0), "ST026_FRAME_SIDE"],
		[Vector3(0.5, 0.25, 0), "ST026_LEGS"], [Vector3(0.5, 0.03, 0), "ST026_BASE"]]:
		var hit: Dictionary = _ray(sample[0], sample[0] + Vector3(0, 0, -2))
		_check(not hit.is_empty() and String(hit.collider.get_meta("surface_id", "")).begins_with(
			sample[1]), "actual ray reaches named " + sample[1])
	StadiumTargetModels.pitch_view(target, true)
	_check(not target.get_node("Visual").visible and not _ray(
		Vector3(0, 1.05, 0), Vector3(0, 1.05, -2)).is_empty(),
		"hidden target retains its physical panel")
	for mesh: MeshInstance3D in target.get_node("Visual").get_children():
		_check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"batting-view target cannot leave a ghost shadow")
	var collider: Transform3D = target.get_node("Collision/ST026_PANEL").transform
	for index in range(19):
		StadiumTargetModels.flex(target, index * 0.01)
		_check(target.get_node("Collision/ST026_PANEL").transform == collider,
			"panel flex never moves the physical contact surface")
	_check(is_equal_approx(target.get_node("Visual/ST026_PANEL").position.z, -0.0125),
		"panel returns to its exact rest pose")
	StadiumTargetModels.pitch_view(target, false)
	await _actor_clearance()
	await _capture(property, target)
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro target model checks passed: "
			+ "exact bounds, named parts, visibility and actor sweeps.")
	get_tree().quit(0 if _failures == 0 else 1)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, 1))


func _actor_clearance() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._bat_actor.set_process(false)
	lab._batter_avatar.set_process(false)
	var target: AABB = StadiumTargetModels.ENVELOPE
	target.position += StadiumTargetModels.POSITION
	var samples: int = 0
	var collisions: int = 0
	for left: bool in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
			else PlayerDefinition.Handedness.RIGHT
		PitchBatLabPresentation.sync_players(lab)
		_check(lab._batter_avatar.bats_left == left, "actual chosen batter hand")
		for id: StringName in [PitchBatLab.CONTACT_SWING_ID, PitchBatLab.POWER_SWING_ID]:
			var profile: SwingProfileDefinition = ContentDB.get_swing(id)
			for x in [-1, 0, 1]:
				for y in [-1, 0, 1]:
					lab._bat_actor.reset_swing()
					lab._batter_avatar.reset_pose()
					lab._bat_actor.set_aim_pose(Vector2(x, y))
					lab._batter_avatar.set_batting_aim_pose(Vector2(x, y))
					lab._bat_actor.play_swing(profile)
					lab._batter_avatar.play_batting_swing(profile)
					for step in range(131):
						var time: float = step * profile.swing_duration_seconds / 130
						lab._bat_actor._apply_swing_pose(time)
						lab._batter_avatar._apply_batting_swing_pose(time)
						for root: Node3D in [lab._bat_actor, lab._batter_avatar]:
							for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
								var box: AABB = mesh.global_transform * mesh.get_aabb()
								if target.intersects(box):
									collisions += 1
									if collisions < 5:
										print("TARGET_ACTOR_OVERLAP ", left, " ", id, " ", Vector2(x, y),
											" t=", time, " ", mesh.name, " ", box)
						samples += 1
	print("TARGET_ACTOR_SAMPLES ", samples, " overlap_count=", collisions)
	_check(samples == 4716 and collisions == 0, "both hands, profiles and nine aim poses clear target")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame


func _capture(property: Node3D, target: Node3D) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "target review requires native rendering")
	if DisplayServer.get_name() == "headless":
		return
	get_window().size = Vector2i(1280, 720)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("142520")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.55
	property.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_energy = 0.7
	light.shadow_enabled = true
	property.add_child(light)
	var camera: Camera3D = Camera3D.new()
	property.add_child(camera)
	camera.position = target.position + Vector3(2.4, 2, 2.8)
	camera.look_at(target.position + Vector3(0, 0.8, 0))
	camera.make_current()
	var label: Label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 25)
	label.text = "TARGET BLOCKOUT • ST-026 • Target only, no catching net"
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join("target-only-blockout.png")) == OK, "target detail captured")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
