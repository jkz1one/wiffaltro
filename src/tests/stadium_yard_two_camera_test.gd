extends "res://src/tests/stadium_yard_two_legacy_camera_test.gd"
## Nonidentical reconstruction: new physical histories and explicit independent rendered evidence.

const Histories = preload("res://src/tests/stadium_yard_two_physics_histories.gd")
const Audit = preload("res://src/tests/stadium_yard_two_visibility_audit.gd")
const Freeze = preload("res://src/tests/stadium_yard_two_capture_freeze.gd")
const Contrast = preload("res://src/tests/stadium_yard_two_contrast_proof.gd")
const Coverage = preload("res://src/tests/stadium_yard_two_coverage_controls.gd")
const Actors = preload("res://src/tests/stadium_yard_two_actor_proof.gd")
var _bounded: bool = false
var _pixels: int = 0
var _histories: Array[Dictionary] = []
var _completed_rates: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
		if argument == "--yard-two-visibility-diagnostic":
			_bounded = true
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native readback initialization has no hidden failure")
	_check(await _native.resize(Vector2i(1280, 720)), "tracking content extent acknowledged")
	if not _bounded:
		await _setup_views()
	await _qualify()
	_check(_native._failures == 0, "native readback failures propagate")
	if DisplayServer.get_name() != "headless" and not _bounded:
		_check(_pixels >= 936, "full regenerated evidence has at least936 actual pixel comparisons")
	print(
		"AY02_RECONSTRUCTION_COVERAGE histories=",
		_histories.size(),
		" requested_rates=",
		[30] if _bounded else [30, 60, 120],
		" completed_rates=",
		_completed_rates,
		" native_pixel_samples=",
		_pixels
	)
	await TestAudioDrain.finish(get_tree())
	if _bounded:
		print("AY02_RECONSTRUCTED_VISIBILITY_DIAGNOSTIC failures=", _failures)
	elif _failures == 0:
		print("Wiffaltro yard-two camera passed: full AY-02 tracking, both hands and roles.")
	get_tree().quit(0 if _failures == 0 else 1)


func _qualify() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_yard_two_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	if not StadiumYardTwoLab.install(lab):
		_check(false, "isolated complete AY-02 install")
		await _ay02_dispose_camera_lab(lab, "tracking-install-failure")
		return
	lab._batter_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var selected: Array[String] = []
	if _bounded:
		selected.assign(
			[
				"center-low",
				"cone-corridor-low",
				"cone-ricochet-control",
				"back-foul",
				"chair-foul",
				"left-side",
				"right-side"
			]
		)
	await _entry_controls(lab)
	_histories = await Histories.record(self, lab, selected)
	_check(_histories.size() == (7 if _bounded else 13), "exact complete physical history count")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	lab._ball_play_resolver.start_play(lab._field_definition)
	await _synthetic_controls(lab)
	_motion_controls(lab)
	Coverage.boundary_controls(self, lab)
	Coverage.target_controls(self, lab, _histories)
	Audit.controls(self, lab)
	_legacy_foul_entry_control(lab)
	Coverage.prior_side_coverage_control(self, lab, _histories)
	Coverage.prior_overtaking_control(self, lab, _histories)
	for fps: int in [30] if _bounded else [30, 60, 120]:
		_sample_fps = fps
		await _replay(lab)
		_completed_rates.append(fps)
		if _failures > 0:
			break
	var lock: Dictionary = Freeze.lock(lab)
	_check(Freeze.intact(lab, lock), "actor control lock retains physical membership")
	await Actors.controls(self, lab, _sample_fps)
	_check(Freeze.unlock(lab, lock), "actor controls restore original callback state")
	await _finish_qualified_camera_lab(lab)


func _finish_qualified_camera_lab(lab: PitchBatLab) -> void:
	await _lifecycle(lab)
	lab._cleanup_batted_ball()
	await _ay02_dispose_camera_lab(lab, "qualified-tracking")


func _replay(lab: PitchBatLab) -> void:
	var camera: Camera3D = lab._camera
	var ball: BattedBallBody = lab._batted_ball
	var director: StadiumYardTwoCameraDirector = lab._camera_director
	var samples: int = 0
	var outside: int = 0
	var blocked: int = 0
	var actor_opaque: int = 0
	var near_hits: int = 0
	var fades: int = 0
	var max_step: float = 0
	var max_turn: float = 0
	var max_fov_delta: float = 0
	var cache: Dictionary = {}
	var actor_cache: Dictionary = {}
	for left: bool in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		director.set_batter_handedness(left)
		for defense: bool in [false, true]:
			for history: Dictionary in _histories:
				director.clear_presentation_motion()
				director.set_shot(
					(
						MatchCameraDirector.Shot.PITCHING
						if defense
						else MatchCameraDirector.Shot.BATTING
					)
				)
				director.snap(camera)
				ball.position = history.start
				var roles: Vector2i = Vector2i(
					int(lab._player_is_batting()), int(lab._player_is_pitching())
				)
				director.prepare_ball_in_play(defense, history.start, history.launch)
				_check(
					(
						roles
						== Vector2i(int(lab._player_is_batting()), int(lab._player_is_pitching()))
					),
					"camera coverage selection does not change actual gameplay role"
				)
				print(
					"AY02_CAMERA_SELECTION id=",
					history.id,
					" requested_defense_view=",
					defense,
					" selected_defensive_coverage=",
					director._live_coverage._defense,
					" clearance=",
					director._live_coverage._clearance_offset,
					" side=",
					director._live_coverage._side,
					" coverage_reason=",
					director._live_coverage.coverage_reason,
					" boundary=",
					director._live_coverage.coverage_boundary,
					" unchanged_gameplay_roles=",
					roles
				)
				director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
				# The positioned cone-contact control begins away from home: settle the same
				# bounded camera at that genuine start before replay, no cut or changed integrator.
				if history.controlled_start:
					for warmup in range(_sample_fps * 2):
						director.update(camera, 1.0 / _sample_fps, true, ball.position)
				var swing: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
				PitchBatLabPresentation.play_batter_swing(lab, swing)
				lab._batter_avatar._process(swing.sweet_spot_seconds)
				lab._bat_actor._process(swing.sweet_spot_seconds)
				var frames: int = maxi(6, int(ceil(history.duration * _sample_fps)))
				var checkpoints: Array[int] = []
				for index in range(6):
					checkpoints.append(roundi(index * float(frames) / 5))
				for frame in range(frames + 1):
					var time: float = minf(history.duration, float(frame) / _sample_fps)
					ball.position = Histories.sample(history, time)
					var before: Transform3D = camera.global_transform
					var before_fov: float = camera.fov
					director.update(camera, 1.0 / _sample_fps, true, ball.position)
					StadiumPropertyRuntime.refresh_receiver_visibility(lab)
					var audit: Dictionary = Audit.audit(lab, cache)
					var actor: Dictionary = Actors.audit(lab, actor_cache)
					_check(
						actor.actors == 4 and actor.hidden == 0,
						"all four authentic actors stay present at every physical-history sample"
					)
					actor_opaque += actor.opaque
					near_hits += int(not _near_clear(camera))
					fades += int(not director.actor_cutaway.last_hits.is_empty())
					blocked += audit.blocked + audit.invalid
					var in_frame: bool = (
						not camera.is_position_behind(ball.position)
						and (get_viewport().get_visible_rect().grow(-24).has_point(
							camera.unproject_position(ball.position)
						))
					)
					outside += int(not in_frame)
					max_step = maxf(max_step, before.origin.distance_to(camera.global_position))
					max_turn = maxf(
						max_turn,
						before.basis.get_rotation_quaternion().angle_to(
							camera.global_basis.get_rotation_quaternion()
						)
					)
					max_fov_delta = maxf(max_fov_delta, absf(camera.fov - before_fov))
					var context: Dictionary = {
						"id": history.id,
						"fps": _sample_fps,
						"left": left,
						"defense": defense,
						"frame": frame,
						"time": time,
						"ball": ball.position,
						"camera": camera.global_position
					}
					if audit.blocked > 0 or not in_frame or actor.opaque > 0:
						print(
							"AY02_TRUE_HISTORY_FAILURE ",
							context,
							" audit=",
							audit,
							" actor=",
							actor
						)
					if DisplayServer.get_name() != "headless" and checkpoints.has(frame):
						var label: String = (
							"ay02-new-%s-%d-%d-%d-%d"
							% [history.id, _sample_fps, int(left), int(defense), frame]
						)
						var value: float = await _contrast_probe(camera, ball, label, context)
						_check(value >= 0.03, "unchanged11x11 native ball contrast")
					samples += 1
					lab._batter_avatar._process(1.0 / _sample_fps)
					lab._bat_actor._process(1.0 / _sample_fps)
	print(
		"AY02_TRUE_HISTORY_TRACKING fps=",
		_sample_fps,
		" samples=",
		samples,
		" outside=",
		outside,
		" opaque_geometry=",
		blocked,
		" opaque_actors=",
		actor_opaque,
		" near_hits=",
		near_hits,
		" actor_fade_samples=",
		fades,
		" max_step=",
		max_step,
		" max_turn=",
		max_turn,
		" max_fov_delta=",
		max_fov_delta
	)
	_check(
		samples > 0 and outside == 0 and blocked == 0 and actor_opaque == 0 and near_hits == 0,
		"all new actual physical-history samples have rendered visibility and framing"
	)
	_check(
		max_step < 32.1 / _sample_fps and max_turn < 1.7 / _sample_fps,
		"unchanged bounded camera movement and turn"
	)


func _contrast_probe(
	camera: Camera3D, ball: BattedBallBody, label: String, context: Dictionary
) -> float:
	if DisplayServer.get_name() == "headless":
		return INF
	var lab: PitchBatLab = ball.get_parent() as PitchBatLab
	var lock: Dictionary = Freeze.lock(lab)
	_check(Freeze.intact(lab, lock), "native extent change preserves attached physics")
	var extent: Vector2i = Vector2i(1280, 720) if _pixels % 2 == 0 else Vector2i(700, 400)
	_check(await _native.resize(extent), "paired capture extent acknowledged")
	_pixels += 1
	var value: float = await Contrast.contrast(self, camera, ball, label, context)
	_check(
		await _native.resize(Vector2i(1280, 720)), "tracking extent restored after paired capture"
	)
	_check(Freeze.intact(lab, lock), "both extents retain complete physics and callback lock")
	_check(Freeze.unlock(lab, lock), "extent roundtrip restores callback and pause state")
	return value


func _representative_contrast(
	camera: Camera3D, ball: BattedBallBody, label: String, context: Dictionary
) -> float:
	return await _contrast_probe(camera, ball, label, context)


func _presentation_snapshot(lab: PitchBatLab) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mesh: MeshInstance3D in lab.find_children("*", "MeshInstance3D", true, false):
		if lab._batted_ball.is_ancestor_of(mesh):
			continue
		var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		result.append(
			{
				"id": mesh.get_instance_id(),
				"pose": mesh.global_transform,
				"visible": mesh.is_visible_in_tree(),
				"instance_alpha": mesh.transparency,
				"shadow": mesh.cast_shadow,
				"material": material.get_instance_id() if material else 0,
				"alpha": material.albedo_color.a if material else -1
			}
		)
	return result


func _motion_controls(lab: PitchBatLab) -> void:
	var motion: StadiumYardTwoCameraMotion = lab._camera_director._live_coverage
	var original: BallInPlayCamera = BallInPlayCamera.new()
	for defense: bool in [false, true]:
		for launch: Vector3 in [
			Vector3(8, -0.85, 13.4),
			Vector3(-8, 3, 20),
			Vector3.ZERO,
			Vector3(-22, 3, 10),
			Vector3(22, 3, 10)
		]:
			motion.prepare(defense, Vector3(0, 1, 0), launch)
			original.prepare(defense, Vector3(0, 1, 0), launch)
			for field: String in [
				"_air_coverage",
				"_ground_coverage",
				"_carry",
				"_age",
				"_velocity",
				"_turn_speed",
				"_height"
			]:
				_check(
					motion.get(field) == original.get(field),
					"physical launch-derived framing and shared motion state stay unchanged"
				)
			_check(
				motion.position_filter.is_null() and motion.framing_lead_degrees == 0,
				"no candidate motion filter or FOV lead"
			)
			_check(motion._side == original._side, "authentic launch side is retained")
			if launch == Vector3(8, -0.85, 13.4):
				_check(
					motion._defense and motion._clearance_offset == 14.0,
					"authentic cone corridor selects existing defensive clearance early"
				)
			elif absf(launch.x) == 22:
				_check(
					(
						motion._defense == defense
						and motion._clearance_offset == 0
						and (
							motion.coverage_reason
							== (
								"shared-launch-coverage"
								if defense
								else "authentic-side-wall-offense-target"
							)
						)
						and (
							motion.coverage_boundary
							== ("" if defense else ("SIDE-L-01" if launch.x < 0 else "SIDE-R-01"))
						)
					),
					"side targets retain original branch and only offense acquires geometric constraint"
				)
			else:
				_check(
					(
						motion._defense == original._defense
						and motion._clearance_offset == original._clearance_offset
					),
					"unrelated camera coverage stays unchanged"
				)


func _synthetic_controls(lab: PitchBatLab) -> void:
	var ball: BattedBallBody = lab._batted_ball
	ball.position = Vector3(7.973333, 0.478667, 14.045333)
	var sphere: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	sphere.shape = SphereShape3D.new()
	sphere.shape.radius = ball.radius_m
	sphere.collision_mask = 1
	sphere.transform.origin = ball.position
	var cone_overlap: bool = false
	for hit: Dictionary in lab.get_world_3d().direct_space_state.intersect_shape(sphere, 32):
		cone_overlap = cone_overlap or hit.collider.get_meta("stadium_item", "") == "ST-001"
	_check(cone_overlap, "preserved old synthetic failure physically intersects authentic cone")
	print(
		"AY02_INVALID_SYNTHETIC_CONTROL ball=",
		ball.position,
		" physical_cone_overlap=",
		cone_overlap,
		" excluded_from_valid_history_counts=true"
	)
	lab._batted_ball = null
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
	var legacy: MatchCameraDirector = MatchCameraDirector.new()
	legacy.set_shot(MatchCameraDirector.Shot.BATTING)
	legacy.snap(lab._camera)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	var visibility: BallTrackingVisibility = lab._camera_director.tracking_visibility
	var padded: bool = visibility._blocked(lab._camera.global_position, Vector3(0, 1, 0))
	var chair: Node3D = (lab.get_meta("stadium_property") as StadiumYardTwoProperty).objects[
		StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY"
	]
	_check(
		padded and chair.get_meta("receiver_render_state", "") == "hidden",
		"preserved padded hidden-chair diagnostic is not an opaque visibility failure"
	)
	print(
		"AY02_PADDED_HIDDEN_CHAIR_CONTROL padded=",
		padded,
		" archived_camera_entry_z=-3.38 receiver_state=",
		chair.get_meta("receiver_render_state", "")
	)
	lab._batted_ball = ball
	ball.position = Vector3(0, 1, 0)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)


func _lifecycle(lab: PitchBatLab) -> void:
	var director: StadiumYardTwoCameraDirector = lab._camera_director
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property")
	var study: StadiumNpcRetainedActorCutaway = property.actor_cutaway
	var elapsed: float = lab._match_state.elapsed_seconds
	var ball_position: Vector3 = lab._batted_ball.position
	get_tree().paused = true
	director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	await get_tree().process_frame
	director.cycle_paused_view()
	await get_tree().process_frame
	_check(study.entries.is_empty(), "paused inspection restores original actor materials")
	director.restore_after_pause()
	await get_tree().process_frame
	_check(
		lab._match_state.elapsed_seconds == elapsed and lab._batted_ball.position == ball_position,
		"always-processing presentation never advances gameplay"
	)
	property.get_parent().remove_child(property)
	_check(
		study.entries.is_empty() and director.actor_cutaway == null,
		"private adapter teardown restores actor state and detaches cutaway"
	)
	_check(not director._entry_owned(), "removed property cannot retain authored camera authority")
	director.shot = MatchCameraDirector.Shot.BATTING
	var original: MatchCameraDirector = _canonical_director(lab, director)
	_check(
		(
			director._desired_transform(Vector3.ZERO, 1.0)
			== original._desired_transform(Vector3.ZERO, 1.0)
		),
		"property removal restores exact shared camera fallback without modifying shared source"
	)
	get_tree().paused = false
	property.queue_free()
	lab.remove_meta("stadium_property")


func _clear_after_fades(property: StadiumYardTwoProperty, from: Vector3, to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = property.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
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


func _verified_fade(property: StadiumYardTwoProperty, body: Node) -> bool:
	var model: Node3D = property.objects.get(StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY")
	if (
		model == null
		or not model.is_ancestor_of(body)
		or property.contact_identity(body).is_empty()
	):
		return false
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
	query.collision_mask = 1
	query.transform.origin = camera.global_position
	return camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _physical_visibility(lab: PitchBatLab) -> void:
	# Query the real installed slabs/chairs on a test-only layer; keep all original layers intact.
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var mask: int = 1 << 25
	var bodies: Array[Node] = property.find_children("*", "StaticBody3D", true, false)
	var layers: Array[int] = []
	for body: StaticBody3D in bodies:
		layers.append(body.collision_layer)
		body.collision_layer |= mask
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = lab.get_world_3d().direct_space_state
	var control: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 2, 22), Vector3(0, 2, 25), mask
	)
	var hit: Dictionary = space.intersect_ray(control)
	_check(
		not hit.is_empty() and hit.collider.has_meta("boundary_segment"),
		"physical LOS positive control detects actual template back slab"
	)
	control.from = Vector3(0, 6, -3)
	control.to = Vector3(0, 1, 14)
	_check(space.intersect_ray(control).is_empty(), "physical LOS clear-corridor negative control")
	for sample: Array in [
		[Vector3(8, 0.27, 13), Vector3(8, 0.27, 15), "ST-001"],
		[Vector3(0, 0.65, 0), Vector3(0, 0.65, -2), "ST-079"],
		[Vector3(-22, 0.55, 12.5), Vector3(-26, 0.55, 12.5), "ST-027"],
		[Vector3(22, 0.55, 12.5), Vector3(26, 0.55, 12.5), "ST-027"]
	]:
		control.from = sample[0]
		control.to = sample[1]
		hit = space.intersect_ray(control)
		_check(
			not hit.is_empty() and hit.collider.get_meta("stadium_item", "") == sample[2],
			"physical LOS positive control detects actual candidate object " + sample[2]
		)
	for index in range(bodies.size()):
		bodies[index].collision_layer = layers[index]
	print("AY02_REAL_PHYSICAL_QUERY_CONTROLS five_positive_surfaces=5 clear_corridor=1")


func _entry_controls(lab: PitchBatLab) -> void:
	var director: StadiumYardTwoCameraDirector = lab._camera_director
	var camera: Camera3D = lab._camera
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property")
	var pose: Transform3D = camera.global_transform
	var fov: float = camera.fov
	var projection: int = camera.projection
	var size: float = camera.size
	var shot: MatchCameraDirector.Shot = director.shot
	var hand: int = lab._match_state.batter().definition.bats
	var phase: MatchState.Phase = lab._match_state.phase
	var roles: Vector2i = Vector2i(int(lab._player_is_batting()), int(lab._player_is_pitching()))
	_check(
		(
			phase == MatchState.Phase.PRE_PITCH
			and not is_instance_valid(lab._batted_ball)
			and not lab._pitch_actor.running
		),
		"authored entry is tested genuinely before pitch/contact"
	)
	for left: bool in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		director.clear_presentation_motion()
		director.set_shot(MatchCameraDirector.Shot.BATTING)
		_check(director.acquire_precontact_entry(), "actual owned PRE_PITCH entry can be acquired")
		var expected: Vector3 = Vector3(-0.18 if left else 0.18, 2.10, -6.5)
		_check(
			(
				camera.global_position.is_equal_approx(expected)
				and (-camera.global_basis.z).is_equal_approx(
					(Vector3(0, 1.10, 7.1) - expected).normalized()
				)
				and camera.fov == fov
				and camera.projection == Camera3D.PROJECTION_PERSPECTIVE
			),
			"authored handed entry retains original x/y/focus/FOV with explicit z revision"
		)
		_check(_near_clear(camera), "authored entry near enclosure clears actual Yard bodies")
		StadiumPropertyRuntime.refresh_receiver_visibility(lab)
		for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
			_check(await _native.resize(extent), "entry native content extent acknowledged")
			var framing: Rect2 = get_viewport().get_visible_rect().grow(-24)
			var minimum: Vector2 = Vector2(INF, INF)
			var maximum: Vector2 = Vector2(-INF, -INF)
			for label: String in ["ZoneLeft", "ZoneRight", "ZoneBottom", "ZoneTop"]:
				var mesh: MeshInstance3D = lab.get_node("StarterFieldGeometry/" + label)
				_check(mesh.is_visible_in_tree(), "actual strike-zone guide remains visible")
				for corner in range(8):
					var at: Vector3 = mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
					var screen: Vector2 = camera.unproject_position(at)
					minimum = minimum.min(screen)
					maximum = maximum.max(screen)
					_check(
						not camera.is_position_behind(at) and framing.has_point(screen),
						"each actual strike-zone guide corner retains24px framing"
					)
			for actor: Node3D in [lab._batter_avatar, lab._bat_actor, lab._pitcher_avatar]:
				for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
					_check(mesh.is_visible_in_tree(), "actual entry actors remain visible")
					for corner in range(8):
						var at: Vector3 = (
							mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
						)
						_check(
							(
								not camera.is_position_behind(at)
								and framing.has_point(camera.unproject_position(at))
							),
							"entry frames real batter bat and pitcher geometry"
						)
			print(
				"AY02_AUTHORED_ENTRY left=",
				left,
				" extent=",
				extent,
				" zone_rect=",
				Rect2(minimum, maximum - minimum),
				" camera=",
				camera.global_transform,
				" fov=",
				camera.fov,
				" readability_minimum=UNSPECIFIED visual_review_required=true"
			)
			await _shot("ay02-authored-entry-%d-%dx%d" % [int(left), extent.x, extent.y])
		_check(await _native.resize(Vector2i(1280, 720)), "entry content extent restored")
		var reference_camera: Camera3D = Camera3D.new()
		lab.add_child(reference_camera)
		for other: int in MatchCameraDirector.Shot.values():
			if other == MatchCameraDirector.Shot.BATTING:
				continue
			director.set_shot(other as MatchCameraDirector.Shot)
			var original: MatchCameraDirector = _canonical_director(lab, director)
			_check(
				(
					director._desired_transform(Vector3.ZERO, 1.0)
					== original._desired_transform(Vector3.ZERO, 1.0)
				),
				"all nonbatting desired transforms match independent same-state shared reference"
			)
			reference_camera.global_transform = camera.global_transform
			reference_camera.fov = camera.fov
			reference_camera.projection = camera.projection
			reference_camera.size = camera.size
			original.snap(reference_camera)
			director.snap(camera)
			_check(
				(
					camera.global_transform == reference_camera.global_transform
					and camera.fov == reference_camera.fov
					and camera.projection == reference_camera.projection
					and camera.size == reference_camera.size
				),
				"nonbatting camera readback matches independently snapped same-state reference"
			)
			print(
				"AY02_SHARED_FALLBACK_REFERENCE left=",
				left,
				" shot=",
				other,
				" same_state=true transform_exact=",
				camera.global_transform == reference_camera.global_transform,
				" pitch_focus=",
				original._pitch_focus
			)
		reference_camera.free()
		director.set_shot(MatchCameraDirector.Shot.BATTING)
		_check(
			director.acquire_precontact_entry(), "role transition returns to authored idle entry"
		)
	camera.global_position += Vector3(0.17, 0.23, 0.31)
	var sentinel: Transform3D = camera.global_transform
	lab._pitch_actor.running = true
	_check(
		not director.acquire_precontact_entry() and camera.global_transform == sentinel,
		"active pitch forbids entry snap"
	)
	lab._pitch_actor.running = false
	for other_phase: int in MatchState.Phase.values():
		if other_phase == MatchState.Phase.PRE_PITCH:
			continue
		lab._match_state.phase = other_phase as MatchState.Phase
		_check(
			not director.acquire_precontact_entry() and camera.global_transform == sentinel,
			"every non-PRE_PITCH phase rejects entry without a camera cut"
		)
	lab._match_state.phase = phase
	director._shot_before_inspection = int(MatchCameraDirector.Shot.BATTING)
	_check(
		not director.acquire_precontact_entry() and camera.global_transform == sentinel,
		"paused inspection blocks automatic entry"
	)
	director._shot_before_inspection = -1
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	_check(
		not director.acquire_precontact_entry() and camera.global_transform == sentinel,
		"live or terminal retained ball forbids entry snap"
	)
	lab._batted_ball = null
	ball.free()
	var old_name: StringName = camera.name
	camera.name = "ForeignCamera"
	_check(
		(
			not director._entry_owned()
			and not director.acquire_precontact_entry()
			and camera.global_transform == sentinel
		),
		"foreign camera identity rejects authored entry"
	)
	camera.name = old_name
	var profile: Dictionary = property.get_meta("candidate_venue")
	var changed: Dictionary = profile.duplicate(true)
	changed.camera_profile.id = "foreign"
	property.set_meta("candidate_venue", changed)
	_check(
		(
			not director._entry_owned()
			and not director.acquire_precontact_entry()
			and camera.global_transform == sentinel
		),
		"foreign profile rejects entry"
	)
	property.set_meta("candidate_venue", profile)
	_check(
		roles == Vector2i(int(lab._player_is_batting()), int(lab._player_is_pitching())),
		"entry controls never change actual gameplay ownership"
	)
	lab._match_state.batter().definition.bats = hand as PlayerDefinition.Handedness
	PitchBatLabPresentation.sync_players(lab)
	director.set_shot(shot)
	camera.global_transform = pose
	camera.fov = fov
	camera.projection = projection as Camera3D.ProjectionType
	camera.size = size
	_check(
		director._entry_owned() and lab._match_state.phase == phase,
		"entry controls restore actual candidate ownership and original phase"
	)


func _legacy_foul_entry_control(lab: PitchBatLab) -> void:
	var camera: Camera3D = lab._camera
	var saved: Transform3D = camera.global_transform
	var fov: float = camera.fov
	var legacy: MatchCameraDirector = MatchCameraDirector.new()
	legacy.tracking_visibility = lab._camera_director.tracking_visibility
	var outside: int = 0
	var samples: int = 0
	for history: Dictionary in _histories:
		if history.id not in ["back-foul", "chair-foul"]:
			continue
		for left: bool in [false, true]:
			legacy.set_batter_handedness(left)
			legacy.set_shot(MatchCameraDirector.Shot.BATTING)
			legacy.snap(camera)
			legacy.prepare_ball_in_play(false, history.start, history.launch)
			legacy.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
			for frame in range(int(ceil(history.duration * 30)) + 1):
				var point: Vector3 = Histories.sample(history, minf(history.duration, frame / 30.0))
				legacy.update(camera, 1.0 / 30.0, true, point)
				var failed: bool = (
					camera.is_position_behind(point)
					or not (get_viewport().get_visible_rect().grow(-24).has_point(
						camera.unproject_position(point)
					))
				)
				outside += int(failed)
				samples += 1
				if failed:
					print(
						"AY02_LEGACY_ENTRY_NEGATIVE id=",
						history.id,
						" left=",
						left,
						" frame=",
						frame,
						" ball=",
						point,
						" camera=",
						camera.global_transform,
						" fov=",
						camera.fov,
						" new_recorded_history_same_inputs=true"
					)
	_check(samples > 0 and outside > 0, "unchanged legacy entry still rejects backward live frames")
	print(
		"AY02_LEGACY_ENTRY_NEGATIVE_TOTAL samples=",
		samples,
		" outside=",
		outside,
		" accepted_camera_samples=0"
	)
	camera.global_transform = saved
	camera.fov = fov


func _canonical_director(lab: PitchBatLab, actual: MatchCameraDirector) -> MatchCameraDirector:
	var reference: MatchCameraDirector = MatchCameraDirector.new()
	for key: String in [
		"shot",
		"_field_focus",
		"_batter_side",
		"_presentation_motion",
		"_presentation_progress",
		"_presentation_transition_speed",
		"_pitch_focus",
		"_standard_fov",
		"_tracking_height",
		"_shot_before_inspection"
	]:
		reference.set(key, actual.get(key))
	reference.tracking_visibility = StadiumYardFieldVisibility.new()
	reference.tracking_visibility.configure(lab.get_node("StarterFieldGeometry"))
	return reference
