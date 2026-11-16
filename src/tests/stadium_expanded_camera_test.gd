extends "res://src/tests/stadium_offset_tracking_test.gd"
## Reuses qualified tracking probes for the full AE-01, both hands/roles and three sample rates.

const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
var _native: Node


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native startup handshake has no hidden failure")
	await _setup_views()
	_check(await _native.resize(Vector2i(1280, 720)), "tracking extent acknowledged")
	for fps: int in [30, 60, 120]:
		_sample_fps = fps
		await _walls("expanded-complete", "27-copies")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro expanded camera passed: full AE-01 tracking, both hands and roles.")
	get_tree().quit(0 if _failures == 0 else 1)


func _install_walls(lab: PitchBatLab, _shape_name: String, _item: String) -> void:
	lab.set_meta("stadium_expanded_lab_only", true)
	_check(StadiumExpandedLab.install(lab), "complete AE-01 installs without paid history")
	_check(
		lab._camera_director.tracking_visibility is BallTrackingVisibility,
		"candidate uses exact template prism visibility"
	)
	_check(
		is_equal_approx(lab._camera_director.tracking_visibility.field_wall_z, 26),
		"camera uses the exact shaped back depth"
	)


func _endpoints(_depth: float) -> Array[Vector3]:
	return [
		Vector3(0, 0.15, 25.9),
		Vector3(-8, 0.15, 22.4),
		Vector3(13, 0.15, 22.9),
		Vector3(7, 0.15, 11.75),
		Vector3(-17, 0.7, 12),
		Vector3(17, 0.7, 12),
		Vector3(-22, 0.7, 22),
		Vector3(22, 0.7, 22),
		Vector3(0, 7, 26),
		Vector3(0, 35, 25)
	]


func _setup_views() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_expanded_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_hide_overlay(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(StadiumExpandedLab.install(lab), "complete expanded setup camera fixture")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(size), "native setup window extent acknowledged")
		await get_tree().process_frame
		await get_tree().physics_frame
		for left: bool in [false, true]:
			lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(
				true
			)
			lab._match_state.batter().definition.bats = (
				PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
			)
			PitchBatLabPresentation.sync_players(lab)
			for shot: int in [
				MatchCameraDirector.Shot.ESTABLISHING,
				MatchCameraDirector.Shot.BATTING,
				MatchCameraDirector.Shot.PITCHING
			]:
				lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
				lab._camera_director.snap(lab._camera)
				StadiumPropertyRuntime.refresh_receiver_visibility(lab)
				var target: Vector3 = Vector3(0, 1, 0)
				_check(
					not lab._camera.is_position_behind(target), "plate corridor remains in front"
				)
				_check(
					_near_clear(lab._camera), "fixed view near-volume clears all candidate bodies"
				)
				await _shot("ae01-%dx%d-hand%d-shot%d" % [size.x, size.y, int(left), shot])
	await _physical_visibility(lab)
	await _board_views(lab)
	# Draw transient native views before freeing, preserving the existing startup-lifecycle fix.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
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


func _physical_visibility(lab: PitchBatLab) -> void:
	var property: StadiumExpandedProperty = lab.get_meta("stadium_property")
	var mask: int = StadiumExpandedProperty.CAMERA_LAYER
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = lab.get_world_3d().direct_space_state
	var control: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 2, 24), Vector3(0, 2, 28), mask
	)
	var hit: Dictionary = space.intersect_ray(control)
	_check(
		not hit.is_empty() and hit.collider.has_meta("boundary_segment"),
		"actual slab is a positive-control occluder"
	)
	control.from = Vector3(0, 6, -3)
	control.to = Vector3(0, 1, 14)
	_check(space.intersect_ray(control).is_empty(), "actual clear corridor negative control")
	var saved_camera: Transform3D = lab._camera.global_transform
	lab._camera.global_position = Vector3(0, 1, 26.1)
	_check(
		not _near_clear(lab._camera), "near-volume positive control detects actual slab penetration"
	)
	lab._camera.global_transform = saved_camera
	var ball_actor: BattedBallBody = BattedBallBody.new()
	ball_actor.freeze = true
	lab.add_child(ball_actor)
	lab._batted_ball = ball_actor
	lab._camera.global_position = Vector3(0, 1.3, -3.4)
	ball_actor.position = Vector3(0, 1.3, 28)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab, true)
	_check(
		not _clear_after_fades(property, lab._camera.global_position, ball_actor.global_position),
		"faded foreground receivers cannot hide an opaque back slab farther along the same ray"
	)
	lab._camera.global_transform = saved_camera
	var raw_hits: int = 0
	var opaque_hits: int = 0
	var farther_opaque_hits: int = 0
	var near_hits: int = 0
	var faded_hits: int = 0
	var samples: int = 0
	var blockers: Dictionary = {}
	var captures: Dictionary = {}
	var director: MatchCameraDirector = lab._camera_director
	for fps: int in [30, 60, 120]:
		for left: bool in [false, true]:
			director.set_batter_handedness(left)
			for defense: bool in [false, true]:
				for endpoint: Vector3 in _endpoints(0):
					director.clear_presentation_motion()
					director.set_shot(
						(
							MatchCameraDirector.Shot.PITCHING
							if defense
							else MatchCameraDirector.Shot.BATTING
						)
					)
					director.snap(lab._camera)
					director.prepare_ball_in_play(
						defense, Vector3(0, 1, 0), endpoint - Vector3(0, 1, 0)
					)
					director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
					for frame in range(fps * 4):
						ball_actor.position = Vector3(0, 1, 0).lerp(
							endpoint, minf(1, frame / (fps * 2.5))
						)
						director.update(lab._camera, 1.0 / fps, true, ball_actor.position)
						StadiumPropertyRuntime.refresh_receiver_visibility(lab, true)
						near_hits += int(not _near_clear(lab._camera))
						control.from = lab._camera.global_position
						control.to = ball_actor.global_position
						var obstruction: Dictionary = space.intersect_ray(control)
						if not obstruction.is_empty():
							raw_hits += 1
							var transparent: bool = _verified_fade(property, obstruction.collider)
							faded_hits += int(transparent)
							opaque_hits += int(not transparent)
							if transparent:
								farther_opaque_hits += int(
									not _clear_after_fades(property, control.from, control.to)
								)
							var key: String = String(obstruction.collider.name)
							blockers[key] = blockers.get(key, 0) + 1
							if DisplayServer.get_name() != "headless" and not captures.has(key):
								captures[key] = true
								_check(
									await _contrast(lab._camera, ball_actor) >= 0.03,
									"actual live ball remains distinguishable through faded receiver"
								)
								await _shot("ae01-live-faded-" + key)
						samples += 1
	print(
		"EXPANDED_PHYSICAL_LOS samples=",
		samples,
		" raw_hits=",
		raw_hits,
		" verified_faded=",
		faded_hits,
		" farther_opaque_hits=",
		farther_opaque_hits,
		" opaque_hits=",
		opaque_hits,
		" near_hits=",
		near_hits,
		" surfaces=",
		blockers
	)
	_check(
		samples == 33600 and raw_hits > 0 and faded_hits == raw_hits and opaque_hits == 0,
		"every physically obstructed live ray uses verified original receiver transparency"
	)
	_check(farther_opaque_hits == 0, "no opaque obstruction is hidden beyond any faded receiver")
	_check(near_hits == 0, "actual projected near-plane enclosures clear full candidate collision")
	lab._batted_ball = null
	ball_actor.queue_free()
	await get_tree().process_frame


func _clear_after_fades(property: StadiumExpandedProperty, from: Vector3, to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = property.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, StadiumExpandedProperty.CAMERA_LAYER
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


func _verified_fade(property: StadiumExpandedProperty, body: Node) -> bool:
	var model: Node3D = (
		property.receiver.net
		if property.receiver.net.is_ancestor_of(body)
		else (property.receiver.chair if property.receiver.chair.is_ancestor_of(body) else null)
	)
	if (
		model == null
		or model.get_meta("receiver_render_state", "") != "faded"
		or not model.get_node("Visual").visible
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
	query.shape.radius = StadiumExpandedCameraDirector.near_enclosure(camera)
	query.collision_mask = StadiumExpandedProperty.CAMERA_LAYER
	query.transform.origin = camera.global_position
	return camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _hide_overlay(lab: PitchBatLab) -> void:
	# Test inspection captures the field itself after ending intro, keeping normal camera optics.
	for control: Control in lab.find_children("*", "Control", true, false):
		control.visible = false


func _board_views(lab: PitchBatLab) -> void:
	var property: StadiumExpandedProperty = lab.get_meta("stadium_property")
	var board: Node3D = property.objects["npc-candidate:AE-01:SCORE-SMALL"]
	var space: PhysicsDirectSpaceState3D = lab.get_world_3d().direct_space_state
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray.collision_mask = StadiumExpandedProperty.CAMERA_LAYER
	var omitted: Array[RID] = []
	for body: StaticBody3D in board.get_node("Collision").get_children():
		omitted.append(body.get_rid())
	ray.exclude = omitted
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(size), "manual board capture extent acknowledged")
		await get_tree().process_frame
		await get_tree().physics_frame
		for shot: int in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.ESTABLISHING]:
			lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
			lab._camera_director.snap(lab._camera)
			# The prior live-ball probe faded the receiver. Reapply the real current setup policy.
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			var blocked: int = 0
			var first_hits: Dictionary = {}
			var farther_hits: Dictionary = {}
			for ix in range(15):
				for iy in range(9):
					ray.from = lab._camera.global_position
					ray.to = board.to_global(
						Vector3(lerpf(-1.96, 1.96, ix / 14.0), lerpf(3.56, 3.93, iy / 8.0), 0.16)
					)
					var proof: Dictionary = _readout_path(property, ray)
					blocked += int(not proof.clear)
					if not proof.first.is_empty():
						first_hits[proof.first] = first_hits.get(proof.first, 0) + 1
					if not proof.opaque.is_empty():
						farther_hits[proof.opaque] = farther_hits.get(proof.opaque, 0) + 1
			var top: Vector2 = lab._camera.unproject_position(
				board.to_global(Vector3(0, 3.85, 0.16))
			)
			var bottom: Vector2 = lab._camera.unproject_position(
				board.to_global(Vector3(0, 3.61, 0.16))
			)
			print(
				"AE01_BOARD_READOUT shot=",
				shot,
				" size=",
				size,
				" blocked=",
				blocked,
				" logical_digit_pixels=",
				top.distance_to(bottom),
				" content_digit_pixels=",
				_content_point(lab._camera, top).distance_to(_content_point(lab._camera, bottom)),
				" first_hits=",
				first_hits,
				" opaque_after_cutaways=",
				farther_hits
			)
			_check(
				blocked == 0,
				"all135 readout rays clear opaque geometry after verified setup receiver cutaways"
			)
			await _shot("ae01-board-context-%dx%d-shot%d" % [size.x, size.y, shot])
		# Dedicated inspection proves cabinet/readout visibility and usable digits without moving it.
		lab._camera.position = Vector3(-20, 6.2, 26)
		lab._camera.look_at(board.to_global(Vector3(0, 3.60, 0.16)))
		_check(_near_clear(lab._camera), "manual detail camera clears physical infrastructure")
		for x: float in [-2.38, 0, 2.38]:
			for y: float in [3.145, 3.6, 4.0]:
				ray.from = lab._camera.global_position
				ray.to = board.to_global(Vector3(x, y, 0.16))
				_check(
					space.intersect_ray(ray).is_empty(),
					"entire board cabinet clears inspection ray"
				)
		var top: Vector2 = lab._camera.unproject_position(board.to_global(Vector3(0, 3.85, 0.16)))
		var bottom: Vector2 = lab._camera.unproject_position(
			board.to_global(Vector3(0, 3.61, 0.16))
		)
		_check(
			_content_point(lab._camera, top).distance_to(_content_point(lab._camera, bottom)) >= 10,
			"inspection digit height is readable at actual extent"
		)
		await _shot("ae01-board-detail-%dx%d" % [size.x, size.y])
		lab._camera.position = Vector3(-25, 18, -15)
		lab._camera.look_at(Vector3(0, 0, 12))
		await _shot("ae01-complete-overview-%dx%d" % [size.x, size.y])


func _content_point(camera: Camera3D, logical: Vector2) -> Vector2:
	# canvas_items keeps a logical1280x720 viewport; compare actual acknowledged content pixels.
	var extent: Vector2 = Vector2(_native._expected_content_size(get_window().size))
	return logical * extent / camera.get_viewport().get_visible_rect().size


func _readout_path(
	property: StadiumExpandedProperty, original: PhysicsRayQueryParameters3D
) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = property.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		original.from, original.to, original.collision_mask
	)
	var ignored: Array[RID] = original.exclude.duplicate()
	var first: String = ""
	var maximum: int = property.find_children("*", "StaticBody3D", true, false).size()
	for index in range(maximum + 1):
		query.exclude = ignored
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return {"clear": true, "first": first, "opaque": ""}
		var id: String = String(hit.collider.name)
		if first.is_empty():
			first = id
		if not _verified_hidden_receiver(property, hit.collider) or ignored.has(hit.rid):
			return {"clear": false, "first": first, "opaque": id}
		ignored.append(hit.rid)
	return {"clear": false, "first": first, "opaque": "bounded-traversal-exhausted"}


func _verified_hidden_receiver(property: StadiumExpandedProperty, body: Node) -> bool:
	var model: Node3D = (
		property.receiver.net
		if property.receiver.net.is_ancestor_of(body)
		else (property.receiver.chair if property.receiver.chair.is_ancestor_of(body) else null)
	)
	if (
		model == null
		or model.get_meta("receiver_render_state", "") != "hidden"
		or model.get_node("Visual").visible
		or (body as StaticBody3D).collision_layer & 1 == 0
	):
		return false
	for mesh: MeshInstance3D in model.get_node("Visual").find_children(
		"*", "MeshInstance3D", true, false
	):
		if mesh.is_visible_in_tree():
			return false
	return true


func _walls(shape: String, item: String) -> void:
	var original: int = int(get_viewport().msaa_3d)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_hide_overlay(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	_install_walls(lab, shape, item)
	var director: MatchCameraDirector = lab._camera_director
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	var depth: float = 28.0
	var endpoints: Array[Vector3] = _endpoints(depth)
	var samples: int = 0
	var outside: int = 0
	var blocked: int = 0
	var contrast_min: float = INF
	var max_step: float = 0
	var max_turn: float = 0
	for left: bool in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		director.set_batter_handedness(left)
		for defense: bool in [false, true]:
			for endpoint: Vector3 in endpoints:
				var prior_outside: int = outside
				var prior_blocked: int = blocked
				director.clear_presentation_motion()
				director.set_shot(
					(
						MatchCameraDirector.Shot.PITCHING
						if defense
						else MatchCameraDirector.Shot.BATTING
					)
				)
				director.snap(lab._camera)
				director.prepare_ball_in_play(
					defense, Vector3(0, 1, 0), endpoint - Vector3(0, 1, 0)
				)
				director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
				for frame in range(_sample_fps * 4):
					ball.position = Vector3(0, 1, 0).lerp(
						endpoint, minf(1, frame / (_sample_fps * 2.5))
					)
					var before: Transform3D = lab._camera.global_transform
					director.update(lab._camera, 1.0 / _sample_fps, true, ball.position)
					StadiumPropertyRuntime.refresh_receiver_visibility(lab, true)
					max_step = maxf(
						max_step, before.origin.distance_to(lab._camera.global_position)
					)
					max_turn = maxf(
						max_turn,
						before.basis.get_rotation_quaternion().angle_to(
							lab._camera.global_basis.get_rotation_quaternion()
						)
					)
					var screen: Vector2 = lab._camera.unproject_position(ball.position)
					outside += int(
						(
							lab._camera.is_position_behind(ball.position)
							or not Rect2(24, 24, 1232, 672).has_point(screen)
						)
					)
					blocked += int(
						director.tracking_visibility._blocked(
							lab._camera.global_position, ball.position
						)
					)
					samples += 1
				if blocked > prior_blocked:
					print(
						"TRACKING_BLOCKED ",
						shape,
						" left=",
						left,
						" defense=",
						defense,
						" endpoint=",
						endpoint,
						" frames=",
						blocked - prior_blocked
					)
				if outside > prior_outside:
					print(
						"TRACKING_OUTSIDE ",
						shape,
						" left=",
						left,
						" defense=",
						defense,
						" endpoint=",
						endpoint,
						" frames=",
						outside - prior_outside
					)
				if DisplayServer.get_name() != "headless":
					var contrast: float = await _contrast(lab._camera, ball)
					contrast_min = minf(contrast_min, contrast)
					_check(contrast >= 0.03, "actual antialiased ball remains distinguishable")
					if endpoint == endpoints[3] and not left and not defense:
						await _shot("wall-tracking-" + item + "-" + shape)
	print(
		"WALL_TRACKING ",
		shape,
		" ",
		item,
		" samples=",
		samples,
		" outside=",
		outside,
		" blocked=",
		blocked,
		" contrast_min=",
		contrast_min,
		" max_step=",
		max_step,
		" max_turn=",
		max_turn,
		" fps=",
		_sample_fps
	)
	_check(
		samples == endpoints.size() * 16 * _sample_fps and outside == 0 and blocked == 0,
		"dense paths keep actual ball in frame without a wall blocking the camera"
	)
	_check(
		max_step < 32.1 / _sample_fps and max_turn < 1.7 / _sample_fps,
		"wall avoidance preserves bounded movement and rotation without camera cuts"
	)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	_check(
		int(get_viewport().msaa_3d) == original,
		"closing tracked wall field restores viewport quality"
	)
