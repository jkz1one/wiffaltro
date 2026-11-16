extends Node3D
## Corrected BZ net geometry, immutable catching plane and target-pair spacing.

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"full-size property builds")
	_check(StadiumBoundaryRuntime.assemble(property) != null, "complete perimeter retained")
	var net: Node3D = StadiumNetModels.create()
	net.position = StadiumNetModels.POSITION
	property.add_child(net)
	var target: Node3D = StadiumTargetModels.create()
	target.position = StadiumTargetModels.POSITION
	property.add_child(target)
	var helper: Node = load("res://src/tests/stadium_seating_test.gd").new()
	var bounds: AABB = helper._bounds(net, net)
	helper.free()
	for visual: MeshInstance3D in net.get_node("Visual").get_children():
		_check(visual.mesh.get_surface_count() > 0, "every named visual has rendered geometry")
	print("NET_BOUNDS ", bounds)
	_check(StadiumNetModels.ENVELOPE.grow(0.0001).encloses(bounds),
		"corrected v2 envelope encloses all real mesh parts")
	var net_front: float = StadiumNetModels.POSITION.z + StadiumNetModels.ENVELOPE.end.z
	var target_back: float = StadiumTargetModels.POSITION.z + StadiumTargetModels.ENVELOPE.position.z
	_check(is_equal_approx(target_back - net_front, 0.435), "pair keeps 0.435m complete-bound gap")
	var transforms: Array[Transform3D] = []
	var shapes: Array[RID] = []
	for body: StaticBody3D in net.get_node("Collision").get_children():
		_check(StadiumNetModels.surfaces().has(String(body.name)), "named net collision part")
		_check(body.get_meta("surface_role") == "RECEIVER_CONTAINMENT_FOUL",
			"net cannot award an Out or strike")
		transforms.append(body.transform)
		shapes.append(body.get_child(0).shape.get_rid())
	for step in range(25):
		StadiumNetModels.pocket(net, step * 0.01)
		var index: int = 0
		for body: StaticBody3D in net.get_node("Collision").get_children():
			_check(body.transform == transforms[index]
				and body.get_child(0).shape.get_rid() == shapes[index],
				"visual pocket leaves every physical part fixed")
			index += 1
		var vertices: PackedVector3Array = net.get_node("Visual/ST025_NET_STRANDS").mesh \
			.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var minimum: float = 0
		for vertex: Vector3 in vertices:
			minimum = minf(minimum, vertex.z)
			_check(vertex.z >= -0.160001 and vertex.z <= 0.000001, "bounded visual pocket")
		if step == 12:
			_check(minimum < -0.159, "center visibly pockets at peak")
		if step == 24:
			_check(absf(minimum) < 0.000001, "net returns to flat rest plane")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(1, 1.3, -1.8), Vector3(1, 1.3, -2.5), 1))
	_check(not hit.is_empty() and hit.collider.get_meta("surface_id", "") == "ST025_NET",
		"target-width miss physically reaches the catching plane")
	await _actor_clearance()
	await _capture(property, net)
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro net model checks passed: bounds, pair gap, fixed colliders and actor sweeps.")
	get_tree().quit(0 if _failures == 0 else 1)


func _actor_clearance() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._bat_actor.set_process(false)
	lab._batter_avatar.set_process(false)
	var target: AABB = StadiumNetModels.ENVELOPE
	target.position += StadiumNetModels.POSITION
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
										print("NET_ACTOR_OVERLAP ", left, " ", id, " ", Vector2(x, y),
											" t=", time, " ", mesh.name, " ", box)
						samples += 1
	print("NET_ACTOR_SAMPLES ", samples, " overlap_count=", collisions)
	_check(samples == 4716 and collisions == 0, "both hands, profiles and nine aim poses clear net")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame


func _capture(property: Node3D, net: Node3D) -> void:
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
	camera.position = net.position + Vector3(4.6, 3.4, 4.8)
	camera.look_at(net.position + Vector3(0, 1.1, 0))
	camera.make_current()
	var label: Label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 25)
	label.text = "TARGET + NET BLOCKOUT • ST-025 / ST-026 • Fixed owned-copy positions"
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(
		_capture_dir.path_join("target-net-blockout.png")) == OK, "paired net detail captured")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
