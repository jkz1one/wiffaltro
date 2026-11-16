extends "res://src/tests/stadium_offset_tracking_test.gd"
## Dense complete-field paths plus independent physical receiver/farther-opaque visibility proof.

const CutawayControls = preload("res://src/tests/stadium_actor_cutaway_test_support.gd")
const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
var _native: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native handshake has no hidden failure")
	_check(await _native.resize(Vector2i(1280, 720)), "actual tracking extent acknowledged")
	for fps: int in [30, 60, 120]:
		_sample_fps = fps
		await _walls("club-complete", "candidate")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro complete Grand I tracking passed: whole-field paths at three frame rates.")
	get_tree().quit(0 if _failures == 0 else 1)


func _install_walls(lab: PitchBatLab, _shape_name: String, _item: String) -> void:
	lab.set_meta("stadium_grand_i_lab_only", true)
	_check(
		StadiumGrandILab.install(lab), "explicit complete field installs for camera qualification"
	)


func _endpoints(_depth: float) -> Array[Vector3]:
	var result: Array[Vector3] = [
		Vector3(0, 0.15, 23.3),
		Vector3(-8, 0.15, 22.4),
		Vector3(13, 0.15, 22.9),
		Vector3(7, 0.15, 11.75),
		Vector3(-25, 1.8, 18),
		Vector3(25, 1.8, 18),
		Vector3(0, 7, 26),
		Vector3(0, 35, 25),
		Vector3(-1.5, 1, -4.45),
		Vector3(1.5, 1, -4.45)
	]
	for left in [false, true]:
		for distance: float in [11, 13, 15]:
			result.append(StadiumDugoutRecipe.rail_point(distance, -0.15, left) + Vector3.UP * 0.7)
	return result


func _walls(_shape_name: String, _item: String) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_grand_i_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_hide_overlay(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(StadiumGrandILab.install(lab), "complete candidate camera fixture")
	lab._batter_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	await CutawayControls.run(self, lab)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	lab._ball_play_resolver.start_play(lab._field_definition, false)
	# Static-body transforms must reach physics before testing the swept camera's real queries.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
	var director: MatchCameraDirector = lab._camera_director
	var camera: Camera3D = lab._camera
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3.ZERO, Vector3.ONE, StadiumClubPropertyGeometry.CAMERA_LAYER
	)
	await _physical_controls(lab, property, ball)
	var raw_hits: int = 0
	var faded_hits: int = 0
	var opaque_hits: int = 0
	var farther_opaque_hits: int = 0
	var blockers: Dictionary = {}
	var captures: Dictionary = {}
	var contrast_min: float = INF
	var samples: int = 0
	var outside: int = 0
	var blocked: int = 0
	var overlaps: int = 0
	var actor_hits: int = 0
	var actor_faded: int = 0
	var fixed_sample_seen: bool = false
	var max_step: float = 0
	var max_turn: float = 0
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		for defense in [false, true]:
			for requested: Vector3 in _endpoints(0):
				var start: Vector3 = Vector3(requested.x if requested.z < 0 else 0, 1, 0)
				var contact: Dictionary = StadiumClubBoundarySweep.event(
					property.boundary, start, requested
				)
				var endpoint: Vector3 = contact.get("position", requested)
				# Do not continue a camera probe through a dead wall into solid stands outside play.
				var prior: Vector3i = Vector3i(outside, blocked, overlaps)
				director.set_shot(
					(
						MatchCameraDirector.Shot.PITCHING
						if defense
						else MatchCameraDirector.Shot.BATTING
					)
				)
				director.snap(camera)
				director.prepare_ball_in_play(defense, start, endpoint - start)
				director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
				var swing: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
				PitchBatLabPresentation.play_batter_swing(lab, swing)
				lab._batter_avatar._process(swing.sweet_spot_seconds)
				lab._bat_actor._process(swing.sweet_spot_seconds)
				_check(
					lab._batter_avatar._batting_swinging and lab._bat_actor._swinging,
					"tracking starts at authentic contact pose after real sweet-spot advance"
				)
				for frame in range(_sample_fps * 4):
					if frame > 0:
						lab._batter_avatar._process(1.0 / _sample_fps)
						lab._bat_actor._process(1.0 / _sample_fps)
					ball.position = start.lerp(endpoint, minf(1, frame / (_sample_fps * 2.5)))
					var before: Transform3D = camera.global_transform
					director.update(camera, 1.0 / _sample_fps, true, ball.position)
					StadiumPropertyRuntime.refresh_receiver_visibility(lab)
					var study: StadiumActorCutawayStudy = (
						(property as StadiumGrandIProperty).actor_cutaway
					)
					actor_hits += int(not study.last_hits.is_empty())
					actor_faded += int(_verified_actor_fades(study))
					if (
						not left
						and not defense
						and requested == Vector3(13, 0.15, 22.9)
						and frame == roundi(_sample_fps * (2.0 / 15.0))
					):
						fixed_sample_seen = true
						_check(
							ball.position.is_equal_approx(Vector3(0.693333, 0.954667, 1.221333)),
							"measured failed physical path sample is retained unchanged"
						)
						_check(
							not study.last_hits.is_empty() and _verified_actor_fades(study),
							"exact old failure now has authentic triangle blocker and live actor cutaway"
						)
						print(
							"GRAND_I_EXACT_FAILURE_RECHECK fps=",
							_sample_fps,
							" frame=",
							frame,
							" ball=",
							ball.position,
							" camera=",
							camera.global_transform,
							" swing_elapsed=",
							lab._bat_actor._swing_elapsed,
							" actual_actor_hits=",
							study.last_hits
						)
						contrast_min = minf(contrast_min, await _explicit_actor_contrasts(lab))
					max_step = maxf(max_step, before.origin.distance_to(camera.global_position))
					max_turn = maxf(
						max_turn,
						before.basis.get_rotation_quaternion().angle_to(
							camera.global_basis.get_rotation_quaternion()
						)
					)
					outside += int(
						(
							camera.is_position_behind(ball.position)
							or not (Rect2(24, 24, 1232, 672).has_point(
								camera.unproject_position(ball.position)
							))
						)
					)
					blocked += int(
						(director.tracking_visibility as StadiumClubFieldVisibility).actual_blocked(
							camera.global_position, ball.position
						)
					)
					overlaps += int(not _near_clear(camera))
					ray.from = camera.global_position
					ray.to = ball.global_position
					var obstruction: Dictionary = space.intersect_ray(ray)
					if not obstruction.is_empty():
						raw_hits += 1
						var faded: bool = _verified_fade(property, obstruction.collider)
						faded_hits += int(faded)
						opaque_hits += int(not faded)
						if faded:
							farther_opaque_hits += int(
								not _clear_after_fades(property, ray.from, ray.to)
							)
						var key: String = String(obstruction.collider.name)
						blockers[key] = blockers.get(key, 0) + 1
						if DisplayServer.get_name() != "headless" and not captures.has(key):
							captures[key] = true
							var contrast: float = await _representative_contrast(
								camera,
								ball,
								"grand-i-live-faded-%d-" % _sample_fps + key,
								{
									"fps": _sample_fps,
									"left": left,
									"defense": defense,
									"requested": requested,
									"endpoint": endpoint,
									"frame": frame,
									"sample": samples,
									"surface": key
								}
							)
							contrast_min = minf(contrast_min, contrast)
							_check(
								contrast >= 0.03,
								"actual live ball remains distinguishable through faded receiver"
							)
					samples += 1
				if Vector3i(outside, blocked, overlaps) != prior:
					print(
						"GRAND_I_TRACKING_FAILURE left=",
						left,
						" defense=",
						defense,
						" endpoint=",
						endpoint,
						" counts=",
						Vector3i(outside, blocked, overlaps) - prior
					)
	print(
		"GRAND_I_TRACKING fps=",
		_sample_fps,
		" samples=",
		samples,
		" outside=",
		outside,
		" blocked=",
		blocked,
		" overlaps=",
		overlaps,
		" max_step=",
		max_step,
		" max_turn=",
		max_turn
	)
	_check(
		outside == 0 and blocked == 0 and overlaps == 0,
		"real complete-field camera volume stays clear and the ball remains framed"
	)
	_check(
		max_step < 32.1 / _sample_fps and max_turn < 1.7 / _sample_fps,
		"complete-field camera retains bounded movement and turning"
	)
	print(
		"GRAND_I_PHYSICAL_LOS fps=",
		_sample_fps,
		" samples=",
		samples,
		" raw_hits=",
		raw_hits,
		" verified_faded=",
		faded_hits,
		" opaque_hits=",
		opaque_hits,
		" farther_opaque_hits=",
		farther_opaque_hits,
		" near_hits=",
		overlaps,
		" actor_hit_samples=",
		actor_hits,
		" verified_actor_fade_samples=",
		actor_faded,
		" contrast_min=",
		contrast_min,
		" surfaces=",
		blockers
	)
	_check(
		(
			samples == _endpoints(0).size() * 16 * _sample_fps
			and raw_hits > 0
			and faded_hits == raw_hits
			and opaque_hits == 0
		),
		"every physical obstruction uses actual verified original receiver fade"
	)
	_check(
		farther_opaque_hits == 0,
		"independent complete rays reject opaque geometry beyond any faded receiver"
	)
	_check(
		fixed_sample_seen and actor_hits > 0 and actor_faded == actor_hits,
		"actual original actor mesh blockers retain exact failed sample and verified fades"
	)
	_check(overlaps == 0, "actual projected near-plane enclosure clears all physical geometry")
	if DisplayServer.get_name() != "headless":
		_check(
			contrast_min >= 0.03 and not captures.is_empty(),
			"representative physical foreground hits have actual native contrast proof"
		)
		await RenderingServer.frame_post_draw
	_check(_native._failures == 0, "native readback failures propagate")
	await _paused_lifecycle(lab)
	lab._cleanup_batted_ball()
	lab.queue_free()
	await get_tree().process_frame


func _shot(name_value: String) -> void:
	if DisplayServer.get_name() == "headless" or _capture_dir.is_empty():
		return
	var captured: bool = await _native.capture(_capture_dir, name_value)
	_check(captured, "native capture/readback handshake succeeds")
	if captured:
		var expected: Vector2i = _native._expected_content_size(get_window().size)
		var path: String = _capture_dir.path_join(
			"%s-%dx%d.png" % [name_value, expected.x, expected.y]
		)
		var saved: Image = Image.load_from_file(path)
		_check(
			saved != null and saved.get_size() == expected,
			"saved PNG dimensions match the acknowledged native content extent"
		)


func _clear_after_fades(property: StadiumClubPropertyGeometry, from: Vector3, to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = property.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, StadiumClubPropertyGeometry.CAMERA_LAYER
	)
	var ignored: Array[RID] = []
	var maximum: int = property.find_children("*", "StaticBody3D", true, false).size()
	for index in range(maximum + 1):
		query.exclude = ignored
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return true
		if not _verified_fade(property, hit.collider) or ignored.has(hit.rid):
			return false
		ignored.append(hit.rid)
	return false


func _verified_fade(property: StadiumClubPropertyGeometry, body: Node) -> bool:
	var model: Node3D = (
		property.receiver.net
		if property.receiver.net.is_ancestor_of(body)
		else (property.receiver.chair if property.receiver.chair.is_ancestor_of(body) else null)
	)
	if (
		model == null
		or model.get_meta("receiver_render_state", "") != "faded"
		or not model.get_node("Visual").visible
		or not model.get_node("Collision").get_children().has(body)
		or (body as StaticBody3D).collision_layer & 1 == 0
	):
		return false
	for mesh: MeshInstance3D in model.get_node("Visual").find_children(
		"*", "MeshInstance3D", true, false
	):
		if not mesh.is_visible_in_tree():
			return false
		var material: StandardMaterial3D = mesh.material_override
		if (
			material == null
			or material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA
			or not is_equal_approx(material.albedo_color.a, StadiumReceiverVisibility.FADED_ALPHA)
		):
			return false
	return true


func _near_clear(camera: Camera3D) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	var extent: Vector2 = camera.get_viewport().get_visible_rect().size
	var radius: float = camera.near * 2
	for corner: Vector2 in [Vector2.ZERO, Vector2(extent.x, 0), extent, Vector2(0, extent.y)]:
		radius = maxf(
			radius, camera.global_position.distance_to(camera.project_position(corner, camera.near))
		)
	query.shape.radius = radius
	query.collision_mask = StadiumClubPropertyGeometry.CAMERA_LAYER
	query.transform.origin = camera.global_position
	return camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _hide_overlay(lab: PitchBatLab) -> void:
	# Test inspection captures the field itself after ending intro, keeping normal camera optics.
	for control: Control in lab.find_children("*", "Control", true, false):
		control.visible = false


func _physical_controls(
	lab: PitchBatLab, property: StadiumClubPropertyGeometry, ball: BattedBallBody
) -> void:
	var space: PhysicsDirectSpaceState3D = property.get_world_3d().direct_space_state
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 1.3, 22), Vector3(0, 1.3, 25), StadiumClubPropertyGeometry.CAMERA_LAYER
	)
	var hit: Dictionary = space.intersect_ray(ray)
	_check(
		not hit.is_empty() and hit.collider.has_meta("club_surface"),
		"actual straight boundary slab is an independent opaque positive control"
	)
	ray.from = Vector3(0, 6, -3)
	ray.to = Vector3(0, 1, 14)
	_check(space.intersect_ray(ray).is_empty(), "real unoccluded corridor negative control")
	var saved: Transform3D = lab._camera.global_transform
	lab._camera.global_position = Vector3(0, 1, 23.6)
	_check(not _near_clear(lab._camera), "near enclosure detects actual opaque slab penetration")
	lab._camera.global_position = Vector3(0, 1.3, -5.2)
	ball.position = Vector3(0, 1.3, 25)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	ray.from = lab._camera.global_position
	ray.to = ball.global_position
	hit = space.intersect_ray(ray)
	_check(
		not hit.is_empty() and _verified_fade(property, hit.collider),
		"farther-blocker control encounters a truly faded original receiver first"
	)
	_check(
		not _clear_after_fades(property, ray.from, ray.to),
		"faded receiver cannot hide a farther opaque boundary slab"
	)
	ball.position = Vector3(0, 1.3, 10)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	_check(
		_clear_after_fades(property, lab._camera.global_position, ball.global_position),
		"ending before the farther slab restores the authentic faded-receiver-only corridor"
	)
	lab._camera.global_transform = saved


func _representative_contrast(
	camera: Camera3D, ball: BattedBallBody, label: String, context: Dictionary
) -> float:
	var minimum: float = INF
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(extent), "live fade contrast native extent acknowledged")
		for frame in range(8):
			await get_tree().process_frame
		minimum = minf(minimum, await _contrast_probe(camera, ball, label, context))
		await _shot(label)
	_check(await _native.resize(Vector2i(1280, 720)), "dense tracking native extent restored")
	return minimum


func _contrast_probe(
	camera: Camera3D, ball: BattedBallBody, label: String, context: Dictionary
) -> float:
	# Unchanged11x11 contrast metric; save failing inputs and freeze paired presentation.
	var lab: PitchBatLab = ball.get_parent() as PitchBatLab
	var study: StadiumActorCutawayStudy = (
		(lab.get_meta("stadium_property") as StadiumGrandIProperty).actor_cutaway
	)
	var frozen_before: bool = study.frozen
	study.frozen = true
	var state_before: Array[Dictionary] = _presentation_snapshot(lab)
	var before: Vector3 = ball.global_position
	ball.visible = true
	await RenderingServer.frame_post_draw
	var shown: Image = get_viewport().get_texture().get_image()
	_check(
		state_before == _presentation_snapshot(lab),
		"visible contrast frame preserves exact actor receiver materials alpha shadows and poses"
	)
	ball.visible = false
	await RenderingServer.frame_post_draw
	var hidden: Image = get_viewport().get_texture().get_image()
	_check(
		state_before == _presentation_snapshot(lab),
		"hidden contrast frame cannot change actor or receiver alpha pose or rendering state"
	)
	ball.visible = true
	study.frozen = frozen_before
	var logical: Vector2 = camera.unproject_position(ball.global_position)
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var screen: Vector2i = Vector2i(logical * Vector2(shown.get_size()) / viewport_size)
	var difference: float = 0
	var peak: Vector2i = screen
	for x in range(maxi(0, screen.x - 5), mini(shown.get_width(), screen.x + 6)):
		for y in range(maxi(0, screen.y - 5), mini(shown.get_height(), screen.y + 6)):
			var a: Color = shown.get_pixel(x, y)
			var b: Color = hidden.get_pixel(x, y)
			var delta: float = Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			if delta > difference:
				difference = delta
				peak = Vector2i(x, y)
	print(
		"GRAND_I_CONTRAST_SAMPLE context=",
		context,
		" window=",
		get_window().size,
		" image=",
		shown.get_size(),
		" logical_extent=",
		viewport_size,
		" projected=",
		logical,
		" content_pixel=",
		screen,
		" peak=",
		peak,
		" camera=",
		camera.global_transform,
		" fov=",
		camera.fov,
		" ball_before=",
		before,
		" ball_after=",
		ball.global_position,
		" visible_in_tree=",
		ball.is_visible_in_tree(),
		" contrast=",
		difference
	)
	if difference < 0.03:
		if not _capture_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(_capture_dir)
			var suffix: String = "%s-%dx%d" % [label, shown.get_width(), shown.get_height()]
			_check(
				shown.save_png(_capture_dir.path_join(suffix + "-contrast-visible.png")) == OK,
				"failing contrast visible input saved"
			)
			_check(
				hidden.save_png(_capture_dir.path_join(suffix + "-contrast-hidden.png")) == OK,
				"failing contrast hidden input saved"
			)
		var visuals: Array[Dictionary] = []
		for mesh: MeshInstance3D in ball.get_parent().find_children(
			"*", "MeshInstance3D", true, false
		):
			if ball.is_ancestor_of(mesh) or not mesh.is_visible_in_tree():
				continue
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			var point: Variant = mesh.get_aabb().intersects_segment(
				inverse * camera.global_position, inverse * ball.global_position
			)
			if point == null:
				continue
			var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
			visuals.append(
				{
					"mesh": String(mesh.get_path()),
					"local_hit": point,
					"world_hit": mesh.global_transform * point,
					"alpha": material.albedo_color.a if material != null else -1,
					"bounds": mesh.get_aabb()
				}
			)
		print(
			"GRAND_I_CONTRAST_VISUAL_CANDIDATES context=",
			context,
			" window=",
			get_window().size,
			" intersections=",
			visuals
		)
	return difference


func _verified_actor_fades(study: StadiumActorCutawayStudy) -> bool:
	if study.last_hits.is_empty():
		return false
	for hit: Dictionary in study.last_hits:
		if not study.entries.has(hit.mesh):
			return false
		var entry: Dictionary = study.entries[hit.mesh]
		var mesh: MeshInstance3D = entry.mesh.get_ref() as MeshInstance3D
		if (
			mesh == null
			or not mesh.is_visible_in_tree()
			or mesh.material_override != entry.fade_material
		):
			return false
		var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		if (
			material == null
			or not is_equal_approx(material.albedo_color.a, 0.20)
			or material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA
			or mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		):
			return false
	return true


func _presentation_snapshot(lab: PitchBatLab) -> Array[Dictionary]:
	var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
	var result: Array[Dictionary] = []
	for root: Node3D in [
		lab._batter_avatar, lab._bat_actor, property.receiver.chair, property.receiver.net
	]:
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
			result.append(
				{
					"id": mesh.get_instance_id(),
					"pose": mesh.global_transform,
					"visible": mesh.is_visible_in_tree(),
					"instance_alpha": mesh.transparency,
					"shadow": mesh.cast_shadow,
					"material": material.get_instance_id() if material else 0,
					"alpha": material.albedo_color.a if material else -1,
					"mode": material.transparency if material else -1,
					"material_semantics": _material_semantics(material)
				}
			)
	return result


func _paused_lifecycle(lab: PitchBatLab) -> void:
	var property: StadiumGrandIProperty = lab.get_meta("stadium_property")
	var director: StadiumGrandICameraDirector = lab._camera_director as StadiumGrandICameraDirector
	var study: StadiumActorCutawayStudy = property.actor_cutaway
	study.restore_all()
	lab._batter_avatar.configure(PlayerAvatar.Role.BATTER, false, false, Color(0.94, 0.78, 0.18))
	lab._batter_avatar.position = Vector3(0.82, 0, 0.34)
	lab._bat_actor.configure(false, lab._batter_avatar.position)
	var originals: Array[Dictionary] = _presentation_snapshot(lab)
	lab._camera.global_position = Vector3(0.27426, 2.213413, -3.468808)
	lab._batted_ball.position = Vector3(0.693333, 0.954667, 1.221333)
	director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	var elapsed: float = lab._match_state.elapsed_seconds
	var ball_position: Vector3 = lab._batted_ball.position
	var physics_state: BallPlayState = lab._ball_play_resolver.state
	var physics_elapsed: float = physics_state.elapsed_seconds
	get_tree().paused = true
	for frame in range(3):
		await get_tree().process_frame
	_check(
		_verified_actor_fades(study),
		"always-processing presentation fades a real paused live blocker"
	)
	director.cycle_paused_view()
	for frame in range(3):
		await get_tree().process_frame
	_check(
		study.entries.is_empty() and originals == _presentation_snapshot(lab),
		"paused inspection restores original actor rendering without a game tick"
	)
	director.restore_after_pause()
	for frame in range(3):
		await get_tree().process_frame
	_check(
		_verified_actor_fades(study),
		"returning to paused live view reapplies only actual obstruction"
	)
	lab._batter_avatar.role = PlayerAvatar.Role.FIELDER
	for frame in range(3):
		await get_tree().process_frame
	_check(
		study.entries.is_empty() and originals == _presentation_snapshot(lab),
		"paused role change restores all actor materials shadows and transparency"
	)
	lab._batter_avatar.role = PlayerAvatar.Role.BATTER
	for frame in range(3):
		await get_tree().process_frame
	_check(
		_verified_actor_fades(study),
		"paused authentic batter role can reenter the reversible policy"
	)
	_check(
		(
			lab._match_state.elapsed_seconds == elapsed
			and lab._batted_ball.position == ball_position
			and lab._ball_play_resolver.state == physics_state
			and physics_state.elapsed_seconds == physics_elapsed
		),
		"always-processing cutaway never advances match clock ball motion or physics state"
	)
	# Real installed adapter teardown while paused, not just direct helper restoration.
	property.get_parent().remove_child(property)
	_check(
		study.entries.is_empty() and director.actor_cutaway == null,
		"paused property teardown restores actors and removes live camera wiring"
	)
	var actor_count: int = 0
	for old: Dictionary in originals:
		var mesh: MeshInstance3D = instance_from_id(old.id) as MeshInstance3D
		if (
			mesh == null
			or not (lab._batter_avatar.is_ancestor_of(mesh) or lab._bat_actor.is_ancestor_of(mesh))
		):
			continue
		actor_count += 1
		var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		_check(
			(
				mesh.global_transform == old.pose
				and material.get_instance_id() == old.material
				and material.albedo_color.a == old.alpha
				and mesh.cast_shadow == old.shadow
				and mesh.transparency == old.instance_alpha
			),
			"paused teardown preserves each original actor material identity and physical pose"
		)
	_check(actor_count > 0, "teardown comparison actually covers the real lab actors")
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	property.queue_free()
	await get_tree().process_frame


func _explicit_actor_contrasts(lab: PitchBatLab) -> float:
	var camera: Camera3D = lab._camera
	var ball: BattedBallBody = lab._batted_ball
	var director: StadiumGrandICameraDirector = lab._camera_director as StadiumGrandICameraDirector
	var historical_camera: Transform3D = camera.global_transform
	var historical_local: Transform3D = camera.transform
	var historical_parent: Node3D = camera.get_parent_node_3d()
	var parent_transform: Transform3D = historical_parent.global_transform
	var historical_fov: float = camera.fov
	var historical_ball: Vector3 = ball.global_position
	var historical_elapsed: float = lab._bat_actor._swing_elapsed
	var historical_avatar_elapsed: float = lab._batter_avatar._batting_swing_elapsed
	var snapshot: Array[Dictionary] = _presentation_snapshot(lab)
	var property: StadiumGrandIProperty = lab.get_meta("stadium_property")
	var swing: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	var phases: Dictionary = {
		"contact": swing.sweet_spot_seconds,
		"follow-through": swing.sweet_spot_seconds + 2.0 / 15.0,
		"settled": swing.swing_duration_seconds + BatActor.FOLLOW_THROUGH_HOLD_SECONDS + 0.05
	}
	var minimum: float = INF
	_check(
		historical_ball.is_equal_approx(Vector3(0.693333, 0.954667, 1.221333)),
		"explicit native control uses the exact original failing ball sample"
	)
	if _sample_fps == 30:
		_check(
			historical_camera.origin.is_equal_approx(Vector3(0.27426, 2.213413, -3.468808)),
			"explicit historical camera is the measured30fps pose, not a reframed inspection"
		)
	for control: String in ["historical-actor", "actor-only"]:
		camera.transform = historical_local
		camera.force_update_transform()
		_check(
			(
				historical_parent.global_transform == parent_transform
				and camera.global_transform == historical_camera
			),
			"each explicit control starts from the exact original local/global sampled pose"
		)
		camera.fov = historical_fov
		if control == "actor-only":
			camera.global_position = Vector3(0.5, 1.4, -0.4)
			camera.look_at(ball.global_position)
		for phase: String in phases:
			PitchBatLabPresentation.play_batter_swing(lab, swing)
			lab._bat_actor._process(phases[phase])
			lab._batter_avatar._process(phases[phase])
			director.refresh_actor_cutaway(camera, true)
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			_check(
				_near_clear(camera),
				"explicit actor contrast camera clears actual near-plane volume"
			)
			_check(
				(
					not property.actor_cutaway.last_hits.is_empty()
					and _verified_actor_fades(property.actor_cutaway)
				),
				(
					control
					+ " "
					+ phase
					+ " has an authentic actor triangle obstruction and actual fade"
				)
			)
			_check(
				(
					lab._bat_actor._swinging == (phase != "settled")
					and lab._batter_avatar._batting_swinging == (phase != "settled")
				),
				"explicit actor contrast advances the genuine contact/follow-through/settled state"
			)
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				camera.global_position,
				ball.global_position,
				StadiumClubPropertyGeometry.CAMERA_LAYER
			)
			var physical: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(ray)
			if control == "actor-only":
				_check(
					physical.is_empty(),
					"actor-only contrast contains no receiver or other physical surface in the entire segment"
				)
			else:
				if _sample_fps == 30:
					_check(
						not physical.is_empty() and _verified_fade(property, physical.collider),
						"exact30fps historical contrast retains its measured faded receiver foreground"
					)
				else:
					_check(
						physical.is_empty() or _verified_fade(property, physical.collider),
						"actual higher-rate sample is physically clear or hits an authentic faded receiver"
					)
				_check(
					_clear_after_fades(property, ray.from, ray.to),
					"every historical-rate sample rejects any farther opaque body on its full segment"
				)
			print(
				"GRAND_I_EXPLICIT_ACTOR_CONTROL type=",
				control,
				" phase=",
				phase,
				" fps=",
				_sample_fps,
				" camera=",
				camera.global_transform,
				" ball=",
				ball.global_position,
				" actor_hits=",
				property.actor_cutaway.last_hits,
				" physical_surface=",
				String(physical.collider.name) if not physical.is_empty() else "none"
			)
			if DisplayServer.get_name() != "headless":
				var label: String = "grand-i-%s-%d-%s" % [control, _sample_fps, phase]
				var contrast: float = await _representative_contrast(
					camera,
					ball,
					label,
					{
						"control": control,
						"phase": phase,
						"fps": _sample_fps,
						"sample": "exact-former-failure",
						"ball": ball.global_position
					}
				)
				minimum = minf(minimum, contrast)
				_check(
					contrast >= 0.03,
					(
						"explicit "
						+ control
						+ " "
						+ phase
						+ " meets unchanged0.03 at both native sizes"
					)
				)
	camera.global_transform = historical_camera
	var global_roundtrip: Transform3D = camera.global_transform
	_camera_restore_diagnostic("global-set-immediate", historical_camera, global_roundtrip)
	camera.transform = historical_local
	camera.force_update_transform()
	_camera_restore_diagnostic("local-set-immediate", historical_camera, camera.global_transform)
	_check(
		(
			historical_parent.global_transform == parent_transform
			and camera.transform == historical_local
			and camera.global_transform == historical_camera
		),
		"original local transform restores exact sampled global pose with an unchanged parent"
	)
	# Restore genuine process elapsed states before dense paths resume; no pose epsilon is used.
	camera.fov = historical_fov
	PitchBatLabPresentation.play_batter_swing(lab, swing)
	lab._bat_actor._process(historical_elapsed)
	lab._batter_avatar._process(historical_avatar_elapsed)
	director.refresh_actor_cutaway(camera, true)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	var restored: Array[Dictionary] = _presentation_snapshot(lab)
	var differences: Array[Dictionary] = []
	for index in range(mini(snapshot.size(), restored.size())):
		for key: String in snapshot[index]:
			if snapshot[index][key] != restored[index].get(key):
				var mesh: MeshInstance3D = instance_from_id(snapshot[index].id) as MeshInstance3D
				differences.append(
					{
						"mesh": String(mesh.get_path()) if mesh != null else "freed",
						"key": key,
						"before": snapshot[index][key],
						"after": restored[index].get(key)
					}
				)
	print(
		"GRAND_I_EXPLICIT_RESTORE_DIAGNOSTIC fps=",
		_sample_fps,
		" differences=",
		differences,
		" snapshot_sizes=",
		Vector2i(snapshot.size(), restored.size()),
		" ball_equal=",
		ball.global_position == historical_ball,
		" camera_equal=",
		camera.global_transform == historical_camera,
		" fov_equal=",
		camera.fov == historical_fov,
		" bat_elapsed_before=",
		historical_elapsed,
		" bat_elapsed_after=",
		lab._bat_actor._swing_elapsed,
		" avatar_elapsed_before=",
		historical_avatar_elapsed,
		" avatar_elapsed_after=",
		lab._batter_avatar._batting_swing_elapsed
	)
	_check(
		(
			ball.global_position == historical_ball
			and camera.global_transform == historical_camera
			and camera.fov == historical_fov
			and _phase_replay_equal(lab, snapshot, _presentation_snapshot(lab))
		),
		"explicit capture controls restore exact sampled camera ball actor poses and render states"
	)
	return minimum


func _material_semantics(material: StandardMaterial3D) -> Dictionary:
	var result: Dictionary = {}
	if material == null:
		return result
	# Stored rendering properties; referenced textures/passes retain identity.
	for property: Dictionary in material.get_property_list():
		var key: String = property.name
		if (
			int(property.usage) & PROPERTY_USAGE_STORAGE == 0
			or key.begins_with("resource_")
			or key == "script"
			or key.begins_with("metadata/")
		):
			continue
		var value: Variant = material.get(key)
		result[key] = value.get_instance_id() if value is Resource else value
	return result


func _phase_replay_equal(
	lab: PitchBatLab, before: Array[Dictionary], after: Array[Dictionary]
) -> bool:
	if before.size() != after.size():
		return false
	var hands: Array[int] = [
		lab._batter_avatar._throw_hand.get_instance_id(),
		lab._batter_avatar._glove_hand.get_instance_id()
	]
	var replacements: int = 0
	for index in range(before.size()):
		var original: Dictionary = before[index]
		var replayed: Dictionary = after[index].duplicate(true)
		if original.id in hands and original.material != replayed.material:
			if original.material_semantics != replayed.material_semantics:
				return false
			replacements += 1
			# Only these two actor-authored replacement resources may differ in object identity.
			replayed.material = original.material
		if original != replayed:
			return false
	print("GRAND_I_KNOWN_HAND_REPLACEMENTS fps=", _sample_fps, " count=", replacements)
	return true


func _camera_restore_diagnostic(label: String, expected: Transform3D, actual: Transform3D) -> void:
	var a: Array[float] = []
	var b: Array[float] = []
	for vector: Vector3 in [expected.basis.x, expected.basis.y, expected.basis.z, expected.origin]:
		a.append_array([vector.x, vector.y, vector.z])
	for vector: Vector3 in [actual.basis.x, actual.basis.y, actual.basis.z, actual.origin]:
		b.append_array([vector.x, vector.y, vector.z])
	var differences: Array[Dictionary] = []
	for index in range(a.size()):
		if a[index] != b[index]:
			differences.append(
				{
					"component": index,
					"before": "%.17f" % a[index],
					"after": "%.17f" % b[index],
					"delta": "%.17f" % (b[index] - a[index])
				}
			)
	print(
		"GRAND_I_CAMERA_EXACT_RESTORE fps=",
		_sample_fps,
		" step=",
		label,
		" exact=",
		expected == actual,
		" component_differences=",
		differences
	)
