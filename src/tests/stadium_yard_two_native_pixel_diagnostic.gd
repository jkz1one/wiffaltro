extends "res://src/tests/stadium_yard_two_camera_test.gd"
## Shared exact source-pose pairs; each subclass declares the authentic installed render profile.

const FIXTURE: String = "res://src/tests/fixtures/yard_two_native_pixel_failures.json"
var _diagnostic_pairs: int = 0
var _reproduced_failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(
		DisplayServer.get_name() != "headless", "pixel diagnostic requires actual native renderer"
	)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(await _native.resize(Vector2i(1280, 720)), "initial diagnostic native extent")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_check(source.cases.size() == 3, "exact three preserved failed native sources")
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_yard_two_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	_pixel_before_install(lab)
	_check(StadiumYardTwoLab.install(lab), "unchanged candidate runtime installs")
	lab._batter_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	lab._ball_play_resolver.start_play(lab._field_definition)
	_pixel_profile_begin(lab)
	for row: Dictionary in source.cases:
		await _saved_pose(lab, row)
	await _pixel_after_samples(lab)
	lab._cleanup_batted_ball()
	await _pixel_dispose_lab(lab)
	_pixel_after_cleanup()
	await TestAudioDrain.finish(get_tree())
	_pixel_emit_result()
	get_tree().quit(0 if _failures == 0 else 1)


func _saved_pose(lab: PitchBatLab, row: Dictionary) -> void:
	var history: Dictionary = row.history.duplicate(true)
	history.start = _source_vector(history.start)
	history.launch = _source_vector(history.launch)
	var positions: Array[Vector3] = []
	for point: Array in history.positions:
		positions.append(_source_vector(point))
	history.positions = positions
	var director: StadiumYardTwoCameraDirector = lab._camera_director
	var camera: Camera3D = lab._camera
	var ball: BattedBallBody = lab._batted_ball
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	director.set_batter_handedness(false)
	director.clear_presentation_motion()
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	director.snap(camera)
	ball.position = history.start
	director.prepare_ball_in_play(false, history.start, history.launch)
	director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	var swing: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	PitchBatLabPresentation.play_batter_swing(lab, swing)
	lab._batter_avatar._process(swing.sweet_spot_seconds)
	lab._bat_actor._process(swing.sweet_spot_seconds)
	for frame in range(int(row.frame) + 1):
		# Exact original camera replay: ceil(duration*fps) can yield a last frame
		# beyond the live source duration. Retain the terminal point, never sample it as live.
		var source_time: float = minf(float(history.duration), frame / 30.0)
		ball.position = Histories.sample(history, source_time)
		director.update(camera, 1.0 / 30.0, true, ball.position)
		StadiumPropertyRuntime.refresh_receiver_visibility(lab)
		if frame < int(row.frame):
			lab._batter_avatar._process(1.0 / 30.0)
			lab._bat_actor._process(1.0 / 30.0)
	var requested_time: float = int(row.frame) / 30.0
	var sampled_time: float = minf(float(history.duration), requested_time)
	if history.dead:
		_check(
			(
				float(history.duration) == float(history.times[-2])
				and float(history.terminal_sample.time) > sampled_time
			),
			"terminal source remains retained and strictly later than the sampled live endpoint"
		)
	_check(
		ball.position == Histories.sample(history, sampled_time),
		"diagnostic exactly follows original live-duration clamp"
	)
	print(
		"AY02_SOURCE_SAMPLING id=",
		row.id,
		" frame=",
		row.frame,
		" requested_time=",
		requested_time,
		" sampled_live_time=",
		sampled_time,
		" source_index=",
		sampled_time * 60.0,
		" preserved_terminal=",
		history.terminal_sample
	)
	var reference: Transform3D = Transform3D(
		Basis(
			_source_vector(row.camera_basis_logged_rounded[0]),
			_source_vector(row.camera_basis_logged_rounded[1]),
			_source_vector(row.camera_basis_logged_rounded[2])
		),
		_source_vector(row.camera_origin_logged_rounded)
	)
	_check(
		(
			camera.global_position.distance_to(reference.origin) < 0.00002
			and camera.global_basis.is_equal_approx(reference.basis)
			and absf(camera.fov - row.fov) < 0.0001
			and ball.global_position.distance_to(_source_vector(row.ball_logged_rounded)) < 0.00002
		),
		"unchanged runtime replays source pose/FOV within original log rounding"
	)
	_check(
		(
			camera.get_viewport() == get_viewport()
			and get_viewport().get_camera_3d() == camera
			and camera.is_current()
		),
		"readback uses exact logged current camera and viewport"
	)
	var visual: MeshInstance3D = ball.get_child(1)
	var material: StandardMaterial3D = visual.material_override
	var original_mesh: SphereMesh = SphereMesh.new()
	original_mesh.radius = 0.075
	original_mesh.height = 0.15
	var original_material: StandardMaterial3D = StandardMaterial3D.new()
	original_material.albedo_color = Color(0.98, 0.96, 0.84)
	original_material.roughness = 0.78
	_check(
		(
			visual.mesh is SphereMesh
			and visual.mesh.radius == original_mesh.radius
			and visual.mesh.height == original_mesh.height
			and ball.radius_m == 0.0365
			and material.albedo_color == original_material.albedo_color
			and material.roughness == original_material.roughness
		),
		"physical radius and exposed visual sphere/material are exactly original"
	)
	var audit: Dictionary = Audit.audit(lab, {})
	_check(
		audit.blocked == 0 and audit.invalid == 0, "saved source center ray remains genuinely clear"
	)
	for extent: Vector2i in [Vector2i(700, 400), Vector2i(1280, 720)]:
		var lock: Dictionary = Freeze.lock(lab)
		_check(await _native.resize(extent), "diagnostic content extent acknowledged")
		var content: Vector2i = _native._expected_content_size(get_window().size)
		var label: String = "ay02-pixel-source-%s-%dx%d" % [row.id, extent.x, extent.y]
		_pixel_rays(lab, row.id, content)
		var context: Dictionary = {
			"id": row.id,
			"source_frame": row.frame,
			"fps": 30,
			"hand": "right",
			"camera_role": "offense",
			"diagnostic_only": true
		}
		var contrast: float = await Contrast.contrast(self, camera, ball, label, context)
		_diagnostic_pairs += 1
		_pixel_expect_sample(contrast, extent)
		if not _capture_dir.is_empty():
			_full_frame_difference(label, content)
		_check(
			Freeze.intact(lab, lock) and Freeze.unlock(lab, lock),
			"diagnostic restores physical membership callbacks and viewport pause state"
		)
		print(
			"AY02_PIXEL_SOURCE_RESULT id=",
			row.id,
			" extent=",
			content,
			" contrast=",
			contrast,
			" expected_negative=",
			_pixel_expected_negative(extent),
			" threshold=0.03 msaa=",
			get_viewport().msaa_3d
		)


func _pixel_rays(lab: PitchBatLab, identity: String, content: Vector2i) -> void:
	var camera: Camera3D = lab._camera
	var ball: BattedBallBody = lab._batted_ball
	var logical: Vector2 = camera.unproject_position(ball.global_position)
	var logical_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var pixel: Vector2 = logical * Vector2(content) / logical_size
	var witnesses: Array[Dictionary] = []
	for x in range(int(floor(pixel.x)) - 2, int(floor(pixel.x)) + 3):
		for y in range(int(floor(pixel.y)) - 2, int(floor(pixel.y)) + 3):
			var center: Vector2 = (
				(Vector2(x, y) + Vector2(0.5, 0.5)) * logical_size / Vector2(content)
			)
			var origin: Vector3 = camera.project_ray_origin(center)
			var direction: Vector3 = camera.project_ray_normal(center)
			var offset: Vector3 = origin - ball.global_position
			var along: float = offset.dot(direction)
			var discriminant: float = along * along - (offset.length_squared() - 0.075 * 0.075)
			if discriminant < 0:
				continue
			var distance: float = -along - sqrt(discriminant)
			var at: Vector3 = origin + direction * distance
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				origin, origin + direction * (distance + 0.001), 1
			)
			var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(query)
			witnesses.append(
				{
					"pixel": Vector2i(x, y),
					"ideal_sphere_hit": at,
					"sphere_distance": distance,
					"physical_foreground": not hit.is_empty(),
					"collider": String(hit.collider.get_path()) if not hit.is_empty() else "",
					"foreground_hit": hit.get("position", Vector3.ZERO)
				}
			)
	print(
		"AY02_NATIVE_PIXEL_RAYS id=",
		identity,
		" content=",
		content,
		" logical=",
		logical,
		" fractional_pixel=",
		pixel,
		" center_y=",
		ball.position.y,
		" physical_radius=",
		ball.radius_m,
		" visible_radius=0.075 geometric_probe=single_center_not_MSAA_pattern actual_msaa=",
		get_viewport().msaa_3d,
		" taa=",
		get_viewport().use_taa,
		" screen_aa=",
		get_viewport().screen_space_aa,
		" scale_3d=",
		get_viewport().scaling_3d_scale,
		" witnesses=",
		witnesses
	)


func _full_frame_difference(label: String, content: Vector2i) -> void:
	var prefix: String = _capture_dir.path_join("%s-%dx%d" % [label, content.x, content.y])
	var shown: Image = Image.load_from_file(prefix + "-visible.png")
	var hidden: Image = Image.load_from_file(prefix + "-hidden.png")
	var changed: int = 0
	var bounds: Rect2i
	var maximum: float = 0
	for y in range(content.y):
		for x in range(content.x):
			var a: Color = shown.get_pixel(x, y)
			var b: Color = hidden.get_pixel(x, y)
			var delta: float = Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			if delta > 0:
				bounds = (
					Rect2i(Vector2i(x, y), Vector2i.ONE)
					if changed == 0
					else bounds.expand(Vector2i(x, y))
				)
				changed += 1
				maximum = maxf(maximum, delta)
	print(
		"AY02_FULL_FRAME_DIFFERENCE label=",
		label,
		" changed_pixels=",
		changed,
		" bounds=",
		bounds,
		" maximum=",
		maximum
	)


static func _source_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _pixel_before_install(_lab: PitchBatLab) -> void:
	pass


func _pixel_profile_begin(_lab: PitchBatLab) -> void:
	_check(
		get_viewport().msaa_3d == Viewport.MSAA_DISABLED,
		"authentic failed-source baseline has no acquired MSAA lease"
	)


func _pixel_expect_sample(contrast: float, extent: Vector2i) -> void:
	if extent.x == 700:
		_check(contrast < 0.03, "original low-resolution failure remains explicit rejected control")
		_reproduced_failures += int(contrast < 0.03)
	else:
		_check(contrast >= 0.03, "same unchanged pose passes original metric at full native extent")


func _pixel_expected_negative(extent: Vector2i) -> bool:
	return extent.x == 700


func _pixel_after_samples(_lab: PitchBatLab) -> void:
	_check(
		_diagnostic_pairs == 6 and _reproduced_failures == 3,
		"three known low-resolution failures and three full-size controls are complete"
	)


func _pixel_after_cleanup() -> void:
	pass


func _pixel_emit_result() -> void:
	print(
		"AY02_NATIVE_PIXEL_DIAGNOSTIC reproduced_failures=",
		_reproduced_failures,
		" pairs=",
		_diagnostic_pairs,
		" candidate_qualification=false failures=",
		_failures
	)


func _pixel_dispose_lab(lab: PitchBatLab) -> void:
	var native: bool = DisplayServer.get_name() != "headless"
	# Keep only scalar/RID witnesses, never a strong Environment/Sky reference across free.
	var owner_ids: Dictionary = {
		"lab": lab.get_instance_id(),
		"environment_node": lab._world_environment.get_instance_id(),
		"environment_resource": lab._world_environment.environment.get_instance_id(),
		"sky_resource": lab._world_environment.environment.sky.get_instance_id(),
		"sky_rid": lab._world_environment.environment.sky.get_rid()
	}
	var before_frames: int = Engine.get_frames_drawn()
	var before_bytes: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED
	)
	if native:
		# Native lab construction queues procedural-sky work even with the backdrop hidden.
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(lab), "diagnostic lab deletion actually completed")
	if native:
		await RenderingServer.frame_post_draw
		_check(
			Engine.get_frames_drawn() > before_frames,
			"native cleanup includes completed pre-release and post-release rendering"
		)
	print(
		"AY02_DIAGNOSTIC_RENDER_DRAIN owners=",
		owner_ids,
		" frames_before=",
		before_frames,
		" frames_after=",
		Engine.get_frames_drawn(),
		" texture_bytes_before=",
		before_bytes,
		" texture_bytes_after=",
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		" actual_node_deleted=",
		not is_instance_valid(lab)
	)
