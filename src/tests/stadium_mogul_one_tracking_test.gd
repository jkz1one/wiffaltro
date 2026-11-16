extends "res://src/tests/stadium_grand_i_tracking_test.gd"

const Evidence = preload("res://src/tests/stadium_mogul_one_evidence.gd")
const EvidenceInventory = preload("res://src/tests/stadium_mogul_one_evidence_inventory.gd")
const EvidenceProof = preload("res://src/tests/stadium_mogul_one_evidence_proof.gd")
## Recorded launched-ball physics histories and separately named synthetic geometric controls.
## Frozen near-plane, LOS, movement, all-actor and native0.03 thresholds stay intact.

const HistoryProof = preload("res://src/tests/stadium_mogul_one_history_proof.gd")
const EntryProof = preload("res://src/tests/stadium_mogul_one_entry_proof.gd")
const CaptureFreeze = preload("res://src/tests/stadium_mogul_one_capture_freeze.gd")
const ContrastProof = preload("res://src/tests/stadium_mogul_one_contrast_proof.gd")
const ActorProof = preload("res://src/tests/stadium_mogul_one_actor_proof.gd")

var _native_evidence: EvidenceInventory = EvidenceInventory.new()


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
	await EvidenceProof.run(self)
	EvidenceInventory.guards(self)
	await EntryProof.run(self)
	await HistoryProof.run(self)
	for fps: int in [30, 60, 120]:
		_sample_fps = fps
		if _failures > 0:
			break
		await _walls("synthetic-geometric-controls", "candidate")
		if _failures > 0:
			break
	_check(
		_native_evidence.finish(self), "complete dynamic native evidence inventory and all hashes"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro AM-01 tracking passed: recorded physics and separate synthetic controls.")
	get_tree().quit(0 if _failures == 0 else 1)


func _install_walls(lab: PitchBatLab, _shape_name: String, _item: String) -> void:
	lab.set_meta("stadium_mogul_one_lab_only", true)
	_check(
		StadiumMogulOneLab.install(lab), "explicit complete field installs for camera qualification"
	)


func _walls(_shape_name: String, _item: String) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_mogul_one_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_hide_overlay(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var installed: bool = StadiumMogulOneLab.install(lab)
	_check(installed, "complete candidate camera fixture")
	if not installed:
		await _dispose_tracking_lab(lab)
		return
	var actors_present: bool = ActorProof.actors(lab).size() == 4
	_check(actors_present, "all four authentic actor sources are present before tracking setup")
	if not actors_present:
		await _dispose_tracking_lab(lab)
		return
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
	var venue: Dictionary = property.get_meta("candidate_venue")
	_check(
		(
			venue.id == "AM-01"
			and venue.version == 1
			and venue.items.size() == 72
			and property.objects.size() == 72
			and venue.crowd.total == 208
		),
		"dense physical tracking uses every exact AM-01 purchase and audience layer"
	)
	var director: MatchCameraDirector = lab._camera_director
	var camera: Camera3D = lab._camera
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3.ZERO, Vector3.ONE, StadiumClubPropertyGeometry.CAMERA_LAYER
	)
	await _physical_controls(lab, property, ball)
	var decorative: Array[Dictionary] = _decorative_cache(_decorative_roots(property))
	_decorative_controls(lab, decorative)
	var decorative_samples: int = 0
	var decorative_hits: int = 0
	var raw_hits: int = 0
	var faded_hits: int = 0
	var opaque_hits: int = 0
	var farther_opaque_hits: int = 0
	var blockers: Dictionary = {}
	var captures: Dictionary = {}
	var contrast_min: float = INF
	var actor_faces: Dictionary = {}
	var all_actor_samples: int = 0
	var all_actor_opaque: int = 0
	var role_hits: Dictionary = {"batter": 0, "bat": 0, "pitcher": 0, "fielder": 0}
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
						(property as StadiumMogulOneProperty).actor_cutaway
					)
					var audit: Dictionary = ActorProof.audit(lab, actor_faces)
					all_actor_samples += int(
						audit.actors == 4 and audit.meshes > 0 and audit.hidden == 0
					)
					all_actor_opaque += audit.opaque
					for role: String in role_hits:
						role_hits[role] += int(audit.roles.get(role, 0) > 0)
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
							"MOGUL_ONE_SYNTHETIC_EXACT_FAILURE_RECHECK fps=",
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
								"mogul-one-synthetic-live-faded-%d-" % _sample_fps + key,
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
					decorative_hits += int(
						not _decorative_clear(
							camera.global_position, ball.global_position, decorative
						)
					)
					decorative_samples += 1
					samples += 1
				if Vector3i(outside, blocked, overlaps) != prior:
					print(
						"MOGUL_ONE_SYNTHETIC_TRACKING_FAILURE left=",
						left,
						" defense=",
						defense,
						" endpoint=",
						endpoint,
						" counts=",
						Vector3i(outside, blocked, overlaps) - prior
					)
	_native_evidence.note_surfaces(_sample_fps, blockers.keys())
	var control_lock: Dictionary = CaptureFreeze.lock(lab)
	_check(
		CaptureFreeze.intact(lab, control_lock),
		"all-actor controls retain native physics membership"
	)
	contrast_min = minf(contrast_min, await ActorProof.controls(self, lab, _sample_fps))
	_check(CaptureFreeze.unlock(lab, control_lock), "all-actor controls restore callback state")
	print(
		"MOGUL_ONE_SYNTHETIC_TRACKING fps=",
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
		"MOGUL_ONE_SYNTHETIC_PHYSICAL_LOS fps=",
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
	print(
		"MOGUL_ONE_SYNTHETIC_ALL_ACTOR_LOS fps=",
		_sample_fps,
		" samples=",
		all_actor_samples,
		" expected=",
		samples,
		" opaque_meshes=",
		all_actor_opaque,
		" role_hit_samples=",
		role_hits
	)
	_check(
		all_actor_samples == samples and all_actor_opaque == 0,
		"every unchanged dense path audits real batter bat pitcher and fielder triangles and actual fades"
	)
	_check(overlaps == 0, "actual projected near-plane enclosure clears all physical geometry")
	if DisplayServer.get_name() != "headless":
		_check(
			contrast_min >= 0.03 and not captures.is_empty(),
			"representative physical foreground hits have actual native contrast proof"
		)
		await RenderingServer.frame_post_draw
	print(
		"MOGUL_ONE_SYNTHETIC_DECORATIVE_LOS fps=",
		_sample_fps,
		" samples=",
		decorative_samples,
		" opaque_triangle_hits=",
		decorative_hits,
		" assemblies=",
		decorative.size()
	)
	_check(
		decorative_samples == samples and decorative_hits == 0,
		"every same genuine camera-to-ball sample clears all actual opaque exterior presentation meshes"
	)
	_decorative_unchanged(decorative)
	_check(_native._failures == 0, "native readback failures propagate")
	await _paused_lifecycle(lab)
	lab._cleanup_batted_ball()
	await _dispose_tracking_lab(lab)


func _dispose_tracking_lab(lab: PitchBatLab) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	_check(not is_instance_valid(lab), "tracking lab releases after full native lifetime drain")


func _contrast_probe(
	camera: Camera3D, ball: BattedBallBody, label: String, context: Dictionary
) -> float:
	return await ContrastProof.contrast(self, camera, ball, label, context)


func _representative_contrast(
	camera: Camera3D, ball: BattedBallBody, label: String, context: Dictionary
) -> float:
	_native_evidence.expect(label, context)
	var lab: PitchBatLab = ball.get_parent() as PitchBatLab
	var lock: Dictionary = CaptureFreeze.lock(lab)
	_check(
		CaptureFreeze.intact(lab, lock),
		"native resize lock retains real bodies and query witnesses"
	)
	var before: Dictionary = CaptureFreeze.snapshot(lab, ball)
	var contrast: float = await super._representative_contrast(camera, ball, label, context)
	_check(CaptureFreeze.intact(lab, lock), "both native extents preserve whole-lab lock")
	_check(
		CaptureFreeze.unlock(lab, lock), "native extents restore exact callback and physics state"
	)
	_check(
		CaptureFreeze.snapshot(lab, ball) == before,
		"native extent round trip restores exact whole-lab rendered state"
	)
	return contrast


func _paused_lifecycle(lab: PitchBatLab) -> void:
	var property: StadiumMogulOneProperty = lab.get_meta("stadium_property")
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
		_batter_entries_absent(lab, study) and originals == _presentation_snapshot(lab),
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
		if mesh == null or not _is_presentation_actor_mesh(lab, mesh):
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
	var property: StadiumMogulOneProperty = lab.get_meta("stadium_property")
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
		# Same ball/time and unchanged equality tolerance, now bound to the authored entry.
		# Measured in source2495fe66 run20261009T142313469485Z; no camera mutation here.
		# Legacy origin(0.27426,2.213413,-3.468808) remains in the preserved failed source.
		var authored_origin: Vector3 = Vector3(0.27426, 2.213413, -6.528835)
		_check(
			property.get_meta("candidate_venue").camera_profile.id == StadiumMogulOneCamera.PROFILE,
			"explicit sampled-camera witness binds the current AM01 authored-entry profile"
		)
		_check(
			historical_camera.origin.is_equal_approx(authored_origin),
			"explicit authored-entry camera is the measured30fps pose, not a reframed inspection"
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
				"MOGUL_ONE_SYNTHETIC_EXPLICIT_ACTOR_CONTROL type=",
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
				var label: String = "mogul-one-synthetic-%s-%d-%s" % [control, _sample_fps, phase]
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
		"MOGUL_ONE_SYNTHETIC_EXPLICIT_RESTORE_DIAGNOSTIC fps=",
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


func _decorative_roots(property: StadiumClubPropertyGeometry) -> Array[Node3D]:
	var roots: Array[Node3D] = []
	var counts: Dictionary = {}
	for model: Node3D in property.objects.values():
		var item: String = model.get_meta("stadium_item", "")
		if item not in ["ST-039", "ST-038"]:
			continue
		roots.append(model)
		counts[item] = counts.get(item, 0) + 1
	_check(
		ClubCareer.same(counts, {"ST-039": 1, "ST-038": 6}),
		"all actual manual board and standard tower presentation assemblies enter visibility audit"
	)
	return roots


func _decorative_cache(roots: Array[Node3D]) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for root: Node3D in roots:
		var meshes: Array[MeshInstance3D] = []
		var bounds: AABB
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			_check(
				mesh.mesh != null and mesh.is_visible_in_tree() and mesh.transparency == 0,
				"decorative audit includes authentic visible complete meshes without a hiding exemption"
			)
			if mesh.mesh == null:
				continue
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if meshes.is_empty() else bounds.merge(box)
			meshes.append(mesh)
		_check(
			not meshes.is_empty(), "each actual presentation assembly contributes visible geometry"
		)
		groups.append(
			{
				"root": root,
				"meshes": meshes,
				"bounds": bounds,
				"signature": _decorative_signature(root)
			}
		)
	return groups


func _decorative_signature(root: Node3D) -> String:
	var state: Array = [root.get_instance_id(), root.global_transform, root.get_child_count()]
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		state.append(
			[
				mesh.get_instance_id(),
				mesh.global_transform,
				mesh.is_visible_in_tree(),
				mesh.transparency,
				mesh.layers,
				mesh.get_child_count(),
				mesh.mesh,
				mesh.mesh.get_faces() if mesh.mesh != null else PackedVector3Array(),
				mesh.material_override,
				mesh.material_overlay,
				_material_semantics(mesh.material_override as StandardMaterial3D)
			]
		)
	return var_to_bytes(state).hex_encode().sha256_text()


func _decorative_unchanged(groups: Array[Dictionary]) -> void:
	for group: Dictionary in groups:
		_check(
			_decorative_signature(group.root) == group.signature,
			"cached broad-phase bounds remain tied to unchanged actual mesh triangles poses and rendering"
		)


func _decorative_clear(from: Vector3, to: Vector3, groups: Array[Dictionary]) -> bool:
	for group: Dictionary in groups:
		var bounds: AABB = group.bounds
		if (
			not bounds.has_point(from)
			and not bounds.has_point(to)
			and bounds.intersects_segment(from, to) == null
		):
			continue
		for mesh: MeshInstance3D in group.meshes:
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			var start: Vector3 = inverse * from
			var end: Vector3 = inverse * to
			var box: AABB = mesh.get_aabb()
			if (
				not box.has_point(start)
				and not box.has_point(end)
				and box.intersects_segment(start, end) == null
			):
				continue
			var faces: PackedVector3Array = mesh.mesh.get_faces()
			for index in range(0, faces.size(), 3):
				if (
					Geometry3D.segment_intersects_triangle(
						start, end, faces[index], faces[index + 1], faces[index + 2]
					)
					!= null
				):
					return false
	return true


func _decorative_controls(lab: PitchBatLab, groups: Array[Dictionary]) -> void:
	var from: Vector3 = Vector3(0, 6, -3)
	var to: Vector3 = Vector3(0, 1, 14)
	_check(
		_decorative_clear(from, to, groups),
		"actual manual board and standard tower negative control"
	)
	var fixture: Node3D = Node3D.new()
	lab.add_child(fixture)
	var slab: MeshInstance3D = MeshInstance3D.new()
	slab.mesh = BoxMesh.new()
	slab.mesh.size = Vector3.ONE * 0.3
	slab.material_override = StandardMaterial3D.new()
	slab.material_override.albedo_color = Color.RED
	fixture.add_child(slab)
	slab.global_position = from.lerp(to, 0.6)
	var original: Transform3D = slab.global_transform
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, StadiumClubPropertyGeometry.CAMERA_LAYER
	)
	_check(
		(
			fixture.find_children("*", "CollisionObject3D", true, false).is_empty()
			and lab.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		),
		"opaque triangle control is genuinely noncolliding and invisible to ordinary physical rays"
	)
	var controls: Array[Dictionary] = _decorative_cache([fixture])
	_check(
		not _decorative_clear(from, to, controls),
		"independent actual-triangle visibility detects the otherwise noncolliding opaque slab"
	)
	slab.global_position.x += 4
	_check(
		_decorative_clear(from, to, _decorative_cache([fixture])),
		"moving real noncolliding opaque geometry away restores full-segment visibility"
	)
	slab.global_transform = original
	_check(
		not _decorative_clear(from, to, controls),
		"restoring exact genuine opaque slab restores obstruction without any label-based exception"
	)
	fixture.free()
	_check(
		_decorative_clear(from, to, groups), "removing visual control restores actual full field"
	)
	_decorative_unchanged(groups)


func _presentation_snapshot(lab: PitchBatLab) -> Array[Dictionary]:
	var result: Array[Dictionary] = super._presentation_snapshot(lab)
	for actor: Node3D in [lab._pitcher_avatar, lab._primary_fielder._avatar]:
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
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


func _is_presentation_actor_mesh(lab: PitchBatLab, mesh: MeshInstance3D) -> bool:
	for actor: Node3D in [
		lab._batter_avatar, lab._bat_actor, lab._pitcher_avatar, lab._primary_fielder._avatar
	]:
		if actor.is_ancestor_of(mesh):
			return true
	return false


func _batter_entries_absent(lab: PitchBatLab, study: StadiumActorCutawayStudy) -> bool:
	for actor: Node3D in [lab._batter_avatar, lab._bat_actor]:
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			if study.entries.has(mesh.get_instance_id()):
				return false
	return true


func _endpoints(_depth: float) -> Array[Vector3]:
	var result: Array[Vector3] = super._endpoints(_depth)
	# Historical near-actor path remains intact; add the actual deeper-center shoulders/cap.
	result.append_array(
		[Vector3(0, 0.15, 25.9), Vector3(-10, 1.5, 26), Vector3(10, 1.5, 26), Vector3(0, 7, 29)]
	)
	return result


func _physical_controls(
	lab: PitchBatLab, property: StadiumClubPropertyGeometry, ball: BattedBallBody
) -> void:
	var space: PhysicsDirectSpaceState3D = property.get_world_3d().direct_space_state
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 1.3, 24.5), Vector3(0, 1.3, 28), StadiumClubPropertyGeometry.CAMERA_LAYER
	)
	var hit: Dictionary = space.intersect_ray(ray)
	_check(
		not hit.is_empty() and hit.collider.has_meta("club_surface"),
		"actual deeper-center boundary slab is an independent opaque positive control"
	)
	ray.from = Vector3(0, 6, -3)
	ray.to = Vector3(0, 1, 14)
	_check(space.intersect_ray(ray).is_empty(), "real unoccluded corridor negative control")
	var saved: Transform3D = lab._camera.global_transform
	lab._camera.global_position = Vector3(0, 1, 26.2)
	_check(not _near_clear(lab._camera), "near enclosure detects actual opaque slab penetration")
	lab._camera.global_position = Vector3(0, 1.3, -5.2)
	ball.position = Vector3(0, 1.3, 28)
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


func _shot(_name_value: String) -> void:
	# Paired contrast retains representative full-size native images at each extent.
	# Avoid redundant copies of every dense synthetic frame within bounded scratch.
	pass
