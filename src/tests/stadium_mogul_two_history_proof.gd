extends RefCounted
## Genuine60Hz physics source histories and explicitly interpolated presentation-only replay.

const Archive = preload("res://src/tests/stadium_mogul_two_history_archive.gd")
const ActorProof = preload("res://src/tests/stadium_mogul_two_actor_proof.gd")
const Presentation = preload("res://src/tests/stadium_mogul_two_source_presentation.gd")
const Freeze = preload("res://src/tests/stadium_mogul_two_capture_freeze.gd")
const SurfaceLifecycle = preload("res://src/tests/stadium_mogul_two_surface_lifecycle_proof.gd")
const LockDiagnostic = preload("res://src/tests/stadium_mogul_two_lock_diagnostic.gd")
const TweenCaptureProof = preload("res://src/tests/stadium_mogul_two_tween_capture_proof.gd")


static func run(owner: Node, controller_only: bool = false, lock_diagnostic: bool = false) -> void:
	var report_dir: String = Archive.directory()
	var packet: Dictionary = {
		"kind": "UNQUALIFIED_AM02_FULL_PHYSICS_HISTORY",
		"version": 1,
		"source_physics_hz": 60,
		"camera_rates": [30, 60, 120],
		"serialization": "full-precision numeric vectors and column-major transforms",
		"authority": "authoring camera evidence only; no production or gameplay report",
		"sources": [],
		"replays": []
	}
	var camera_rates: Array[int] = [30, 60, 120]
	if controller_only:
		packet.kind = "BOUNDED_AM02_REAR_FOUL_CONTROLLER_REPRODUCTION"
		camera_rates.clear()
		packet.camera_rates = []
	if lock_diagnostic:
		packet["capture_lock_diagnostic_only"] = true
		packet["native_readbacks"] = false
	if DisplayServer.get_name() != "headless" and not lock_diagnostic:
		await SurfaceLifecycle.run(owner)
	owner._check(
		Engine.physics_ticks_per_second == 60,
		"source launch physics remains ordinary60Hz, independent of camera replay rate"
	)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_mogul_two_lab_only", true)
	owner.add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	owner._hide_overlay(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var installed: bool = StadiumMogulTwoLab.install(lab)
	owner._check(installed, "real recorded-history lab installs exact complete AM-02")
	if not installed:
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		lab.queue_free()
		await owner.get_tree().process_frame
		await owner.get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		return
	var property: StadiumMogulTwoProperty = lab.get_meta("stadium_property")
	var director: StadiumMogulTwoCamera = lab._camera_director as StadiumMogulTwoCamera
	var camera: Camera3D = lab._camera
	lab._batter_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	var cases: Array[Dictionary] = [
		{
			"id": "left-loft-line",
			"position": Vector3(0, 1.1, 0.2),
			"velocity": Vector3(0, 10, 35),
			"foul": false
		},
		{
			"id": "left-shoulder",
			"position": Vector3(0, 1.1, 0.2),
			"velocity": Vector3(-14, 10, 33),
			"foul": false
		},
		{
			"id": "right-shoulder",
			"position": Vector3(0, 1.1, 0.2),
			"velocity": Vector3(14, 10, 33),
			"foul": false
		},
		{
			"id": "high-center",
			"position": Vector3(0, 1.1, 0.2),
			"velocity": Vector3(0, 23, 28),
			"foul": false
		},
		{
			"id": "rear-net-foul",
			"position": Vector3(1.5, 1.1, 0.2),
			"velocity": Vector3(0, 0, -20),
			"foul": true
		}
	]
	if controller_only:
		# Dedicated diagnostic selection, never a substitute for the complete20/60 gate.
		cases = [cases[-1]]
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	await TweenCaptureProof.run(owner, lab)
	var source_count: int = 0
	var total: int = 0
	var histories: int = 0
	for left in [false, true]:
		for defense in [false, true]:
			for row: Dictionary in cases:
				lab._start_new_match()
				PitchBatLabFeelSupport.skip_match_presentation(lab)
				lab._match_state.batter().definition = (
					lab._match_state.batter().definition.duplicate(true)
				)
				lab._match_state.batter().definition.bats = (
					PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
				)
				lab._player_home = defense
				PitchBatLabPresentation.sync_players(lab)
				PitchBatLabPresentation.apply_role_camera(lab)
				director.snap(camera)
				owner._check(
					lab._player_is_pitching() == defense and lab._player_is_batting() != defense,
					"genuine source launch role matches its offense or defense label"
				)
				var entry: Transform3D = camera.global_transform
				var entry_fov: float = camera.fov
				owner._hide_overlay(lab)
				owner._check(
					lab._match_state.begin_pitch(), "source launch begins from genuine pitch state"
				)
				var launch: BattedBallLaunch = BattedBallLaunch.new()
				launch.position = row.position
				launch.velocity = row.velocity
				launch.is_foul = row.foul
				lab._primary_fielder.set_physics_process(true)
				# Every trial launches in the same pre-physics phase. Do not drop or relabel
				# a stalled first sample after a process-frame-created RigidBody registration.
				await owner.get_tree().physics_frame
				var launch_tick: int = Engine.get_physics_frames()
				lab._start_ball_in_play(launch)
				(
					owner
					. _check(
						(
							camera.global_transform == entry
							and camera.fov == entry_fov
							and director._live_coverage._defense == defense
						),
						"ordinary controller launch retains acquired pre-contact view without a contact cut"
					)
				)
				var ball: BattedBallBody = lab._batted_ball
				owner._check(
					not ball.freeze and ball._started and ball.physics_contact_router.is_valid(),
					"ordinary source launch owns actual active physical body and boundary router"
				)
				var swing: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
				PitchBatLabPresentation.play_batter_swing(lab, swing)
				lab._batter_avatar._process(swing.sweet_spot_seconds)
				lab._bat_actor._process(swing.sweet_spot_seconds)
				lab._process(0)
				(
					owner
					. _check(
						camera.global_transform == entry and camera.fov == entry_fov,
						"zero-elapsed ordinary presentation acquires fades without moving the contact view"
					)
				)
				var source: Array[Dictionary] = [_history_sample(lab, 0)]
				var captured_presentation: Dictionary = {}
				if row.id == "rear-net-foul":
					captured_presentation[0] = Presentation.capture(lab)
					source[0]["presentation_proof"] = Presentation.proof(captured_presentation[0])
					source[0]["scoreboard_visual"] = _scoreboard_visual(lab)
				var source_identities: Dictionary = _identity_table(lab)
				var source_faces: Dictionary = {}
				_source_camera_check(owner, lab, entry, 0, source_faces)
				for frame in range(720):
					await owner.get_tree().physics_frame
					owner._check(
						(
							Engine.physics_ticks_per_second == 60
							and Engine.get_physics_frames() == launch_tick + frame + 1
						),
						"recorded launch retains every consecutive ordinary60Hz physics tick"
					)
					if not is_instance_valid(ball):
						owner._check(false, "source history never substitutes a replacement ball")
						break
					var before_camera: Transform3D = camera.global_transform
					lab._physics_process(1.0 / 60.0)
					lab._batter_avatar._process(1.0 / 60.0)
					lab._bat_actor._process(1.0 / 60.0)
					# Exercise the actual complete lab presentation/controller callback before replay.
					# No manual prepare, camera snap or fit-to-ball occurs during the source flight.
					lab._process(1.0 / 60.0)
					owner._hide_overlay(lab)
					_source_camera_check(owner, lab, before_camera, 1.0 / 60.0, source_faces)
					source.append(_history_sample(lab, float(frame + 1) / 60.0))
					if (
						row.id == "rear-net-foul"
						and (frame == 0 or lab._ball_play_resolver.state.dead)
					):
						var index: int = source.size() - 1
						captured_presentation[index] = Presentation.capture(lab)
						source[index]["presentation_proof"] = Presentation.proof(
							captured_presentation[index]
						)
						source[index]["scoreboard_visual"] = _scoreboard_visual(lab)
					if lab._ball_play_resolver.state.dead:
						break
				owner._check(
					source.size() > 2 and source[1].ball != source[0].ball,
					"recorded source has genuine nonteleported physical advancement"
				)
				owner._check(
					lab._ball_play_resolver.state.dead,
					"source physical launch ends with genuine terminal outcome"
				)
				var source_digest: String = var_to_bytes(source).hex_encode().sha256_text()
				var terminal_contacts: Array = (
					lab._ball_play_resolver.state.stadium_contacts.duplicate(true)
				)
				print(
					"MOGUL_TWO_SOURCE_PHYSICS hz=60 left=",
					left,
					" defense=",
					defense,
					" launch=",
					row.id,
					" samples=",
					source.size(),
					" terminal=",
					lab._ball_play_resolver.state.dead,
					" contacts=",
					terminal_contacts,
					" source_sha256=",
					source_digest
				)
				_verify_identities(owner, source, source_identities)
				(
					owner
					. _check(
						source_identities == _identity_table(lab),
						"source actor identity paths and parent roles remain stable throughout recording"
					)
				)
				var archive_index: int = packet.sources.size()
				if not report_dir.is_empty():
					packet.sources.append(
						{
							"index": archive_index,
							"left": left,
							"defense": defense,
							"launch": row.duplicate(true),
							"source_sha256": source_digest,
							"source_digest_encoding":
							"sha256 of Godot var_to_bytes hexadecimal text",
							"terminal_contacts": terminal_contacts.duplicate(true),
							"identity_table": source_identities.duplicate(true),
							"launch_physics_tick": launch_tick,
							"pre_contact_camera": entry,
							"pre_contact_fov": entry_fov,
							"camera_profile":
							property.get_meta("candidate_venue").camera_profile.duplicate(true),
							"controller_camera": "real-lab-process-before-presentation-replay",
							"samples": source.duplicate(true)
						}
					)
				if row.id == "rear-net-foul" and lock_diagnostic:
					await LockDiagnostic.run(owner, lab, left, defense)
				elif row.id == "rear-net-foul" and DisplayServer.get_name() != "headless":
					await _source_controller_readbacks(
						owner, lab, source, captured_presentation, left, defense
					)
				source_count += 1
				for camera_fps: int in camera_rates:
					owner._sample_fps = camera_fps
					# Explicit presentation-only replay. Source sphere centers and events are held unchanged;
					# no interpolated sample enters gameplay resolution or masquerades as another launch.
					ball.freeze = true
					lab._primary_fielder.set_physics_process(false)
					lab._ball_play_resolver.start_play(lab._field_definition, launch.is_foul)
					director.set_shot(
						(
							MatchCameraDirector.Shot.PITCHING
							if defense
							else MatchCameraDirector.Shot.BATTING
						)
					)
					director.snap(camera)
					director.prepare_ball_in_play(defense, launch.position, launch.velocity)
					director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
					var faces: Dictionary = {}
					var replay: Array[Dictionary] = []
					var maximum_step: float = 0
					var maximum_turn: float = 0
					var critical: Dictionary = {}
					var ticks: Array[int] = []
					var last_tick: int = (source.size() - 1) * 2
					for tick in range(0, last_tick + 1, 120 / owner._sample_fps):
						ticks.append(tick)
					for source_index in range(1, source.size()):
						if (
							source_index == source.size() - 1
							or source[source_index].contacts != source[source_index - 1].contacts
						):
							var event_tick: int = source_index * 2
							critical[event_tick] = source_index
							if not ticks.has(event_tick):
								ticks.append(event_tick)
					owner._native_evidence.note_events(
						source_count - 1, camera_fps, critical.keys(), row.id, left, defense
					)
					ticks.sort()
					var previous_tick: int = 0
					var covered: Dictionary = {}
					for tick: int in ticks:
						var time: float = float(tick) / 120.0
						var delta: float = float(tick - previous_tick) / 120.0
						var lower: int = tick / 2
						var upper: int = mini(lower + 1, source.size() - 1)
						var weight: float = float(tick % 2) / 2.0
						var point: Vector3 = (source[lower].ball as Vector3).lerp(
							source[upper].ball, weight
						)
						if critical.has(tick):
							covered[tick] = true
							(
								owner
								. _check(
									weight == 0 and point == source[critical[tick]].ball,
									"every event tick and terminal center is replayed exactly, including odd60Hz ticks at30fps"
								)
							)
						ball.global_position = point
						_restore_poses(owner, source[lower].parent_poses)
						_restore_poses(owner, source[lower].actor_poses)
						(
							owner
							. _check(
								(
									_parent_poses(lab) == source[lower].parent_poses
									and ActorProof.poses(lab) == source[lower].actor_poses
								),
								"source parent roots and every descendant local/global actor pose restore byte-exactly"
							)
						)
						var before: Transform3D = camera.global_transform
						director.update(camera, delta, true, point)
						StadiumPropertyRuntime.refresh_receiver_visibility(lab)
						var actor: Dictionary = ActorProof.audit(lab, faces)
						owner._check(
							(
								not camera.is_position_behind(point)
								and Rect2(24, 24, 1232, 672).has_point(
									camera.unproject_position(point)
								)
							),
							"source-bound camera replay retains unchanged24px framing margin"
						)
						owner._check(
							owner._near_clear(camera),
							"source-bound replay retains full projected near-plane sphere clearance"
						)
						owner._check(
							(
								not director.tracking_visibility.actual_blocked(
									camera.global_position, point
								)
								and owner._clear_after_fades(
									property, camera.global_position, point
								)
							),
							"source-bound replay full segment rejects opaque and farther blockers"
						)
						(
							owner
							. _check(
								actor.actors == 4 and actor.hidden == 0 and actor.opaque == 0,
								"recorded actor poses retain independent all-four triangle and fade audit"
							)
						)
						var step: float = before.origin.distance_to(camera.global_position)
						var turn: float = before.basis.get_rotation_quaternion().angle_to(
							camera.global_basis.get_rotation_quaternion()
						)
						if delta > 0:
							maximum_step = maxf(maximum_step, step / delta)
							maximum_turn = maxf(maximum_turn, turn / delta)
							owner._check(
								step < 32.1 * delta and turn < 1.7 * delta,
								"exact event delta preserves original movement and turn rates"
							)
						previous_tick = tick
						replay.append(
							{
								"time": time,
								"source_lower": lower,
								"source_upper": upper,
								"weight": weight,
								"sphere_center": point,
								"camera": camera.global_transform,
								"camera_fov_degrees": camera.fov
							}
						)
						if critical.has(tick) and DisplayServer.get_name() != "headless":
							var contrast: float = await owner._representative_contrast(
								camera,
								ball,
								(
									"mogul-two-history-%s-%d-%s-%s-%d"
									% [
										row.id,
										owner._sample_fps,
										"left" if left else "right",
										"defense" if defense else "offense",
										tick
									]
								),
								{
									"kind": "recorded60Hz-physics-camera-replay",
									"fps": owner._sample_fps,
									"source_tick120": tick,
									"terminal": tick == last_tick,
									"source_contacts": source[lower].contacts,
									"source_sha256": source_digest,
									"lower": lower,
									"upper": upper,
									"weight": weight
								}
							)
							(
								owner
								. _check(
									contrast >= 0.03,
									"source-bound native contrast retains unchanged0.03 threshold at both extents"
								)
							)
					owner._check(
						maximum_step < 32.1 and maximum_turn < 1.7,
						"recorded-path camera replay preserves original movement and turn bounds"
					)
					(
						owner
						. _check(
							(
								covered.size() == critical.size()
								and not replay.is_empty()
								and replay[-1].sphere_center == source[-1].ball
							),
							"every contact tick and final source endpoint is included at each replay rate"
						)
					)
					(
						owner
						. _check(
							var_to_bytes(source).hex_encode().sha256_text() == source_digest,
							"source sphere centers, actor poses and events stay byte-exact through replay"
						)
					)
					print(
						"MOGUL_TWO_PHYSICS_HISTORY_REPLAY camera_fps=",
						owner._sample_fps,
						" physics_hz=60 left=",
						left,
						" defense=",
						defense,
						" launch=",
						row.id,
						" samples=",
						replay.size(),
						" source_sha256=",
						source_digest,
						" replay_sha256=",
						var_to_bytes(replay).hex_encode().sha256_text(),
						" max_step=",
						maximum_step,
						" max_turn=",
						maximum_turn
					)
					if not report_dir.is_empty():
						packet.replays.append(
							{
								"source_index": archive_index,
								"source_sha256": source_digest,
								"camera_fps": camera_fps,
								"camera_projection":
								{
									"projection": camera.projection,
									"near": camera.near,
									"far": camera.far,
									"keep_aspect": camera.keep_aspect,
									"logical_viewport_size":
									camera.get_viewport().get_visible_rect().size
								},
								"critical_tick120_to_source_index": critical.duplicate(true),
								"covered_critical_ticks": covered.keys(),
								"maximum_speed_mps": maximum_step,
								"maximum_turn_rps": maximum_turn,
								"samples": replay.duplicate(true)
							}
						)
					total += replay.size()
					histories += 1
				lab._cleanup_batted_ball()
				await owner.get_tree().process_frame
	if controller_only:
		(
			owner
			. _check(
				source_count == 4 and histories == 0 and total == 0,
				"bounded reproduction covers both hands and roles at controller0/1/terminal, no replay claim"
			)
		)
	else:
		owner._check(
			source_count == 20 and histories == 60 and total > 120,
			"twenty common60Hz source histories replay byte-exactly across all three camera rates"
		)
	if not report_dir.is_empty():
		var saved: Dictionary = (
			Archive.save_controller(report_dir, packet)
			if controller_only
			else Archive.save(report_dir, packet)
		)
		print("MOGUL_TWO_RAW_HISTORY_ARCHIVE ", saved)
		owner._check(
			saved.get("ok", false),
			"requested complete source/replay archive saves and roundtrips within2MiB gzip limit"
		)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await owner.get_tree().process_frame
	await owner.get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	owner._check(
		not is_instance_valid(lab), "history lab releases after full native lifetime drain"
	)


static func _history_sample(lab: PitchBatLab, time: float) -> Dictionary:
	return {
		"time": time,
		"physics_tick": Engine.get_physics_frames(),
		"ball": lab._batted_ball.global_position,
		"ball_transform": lab._batted_ball.global_transform,
		"velocity": lab._batted_ball.linear_velocity,
		"controller_camera": lab._camera.global_transform,
		"controller_fov": lab._camera.fov,
		"controller_shot": int(lab._camera_director.shot),
		"controller_defense": lab._player_is_pitching(),
		"match_phase": int(lab._match_state.phase),
		"actor_poses": ActorProof.poses(lab),
		"parent_poses": _parent_poses(lab),
		"contacts": lab._ball_play_resolver.state.stadium_contacts.duplicate(true),
		"dead": lab._ball_play_resolver.state.dead
	}


static func _parent_poses(lab: PitchBatLab) -> Array:
	var result: Array = []
	for node: Node3D in [lab._pitcher_marker, lab._primary_fielder]:
		result.append(
			[
				node.get_instance_id(),
				node.get_parent().get_instance_id(),
				node.transform,
				node.global_transform
			]
		)
	return result


static func _restore_poses(owner: Node, poses: Array) -> void:
	for row: Array in poses:
		var node: Node3D = instance_from_id(row[0]) as Node3D
		owner._check(
			node != null and node.get_parent().get_instance_id() == row[1],
			"recorded pose keeps authentic source node and exact parent"
		)
		if node == null:
			continue
		node.transform = row[2]
		node.force_update_transform()
		owner._check(
			node.transform == row[2] and node.global_transform == row[3],
			"restored node has exact source local and world transform"
		)


static func _identity_table(lab: PitchBatLab) -> Dictionary:
	var result: Dictionary = {
		str(lab.get_instance_id()):
		_identity_row(lab, lab, "lab-reference-frame", lab.get_instance_id())
	}
	var actors: Dictionary = ActorProof.actors(lab)
	for role: String in actors:
		var actor: Node3D = actors[role]
		var nodes: Array[Node] = [actor]
		nodes.append_array(actor.find_children("*", "Node3D", true, false))
		for member: Node in nodes:
			result[str(member.get_instance_id())] = _identity_row(
				lab, member, role, actor.get_instance_id()
			)
	for pair: Array in [
		[lab._pitcher_marker, "pitcher-parent", lab._pitcher_avatar.get_instance_id()],
		[lab._primary_fielder, "fielder-parent", lab._primary_fielder._avatar.get_instance_id()]
	]:
		var member: Node = pair[0]
		result[str(member.get_instance_id())] = _identity_row(lab, member, pair[1], pair[2])
	return result


static func _identity_row(
	lab: PitchBatLab, node: Node, role: String, actor_root: int
) -> Dictionary:
	return {
		"instance_id": node.get_instance_id(),
		"lab_path": String(lab.get_path_to(node)),
		"role": role,
		"actor_root_instance_id": actor_root,
		"class": node.get_class(),
		"script_path": node.get_script().resource_path if node.get_script() != null else "",
		"parent_instance_id": node.get_parent().get_instance_id(),
		"parent_lab_path": String(lab.get_path_to(node.get_parent()))
	}


static func _verify_identities(
	owner: Node, source: Array[Dictionary], identities: Dictionary
) -> void:
	for sample: Dictionary in source:
		for kind: String in ["parent_poses", "actor_poses"]:
			for pose: Array in sample[kind]:
				var key: String = str(pose[0])
				owner._check(
					(
						identities.has(key)
						and identities.has(str(pose[1]))
						and identities[key].parent_instance_id == pose[1]
					),
					"every recorded pose and parent ID has a stable lab-relative identity and role"
				)


static func _source_camera_check(
	owner: Node, lab: PitchBatLab, previous: Transform3D, delta: float, faces: Dictionary
) -> void:
	var camera: Camera3D = lab._camera
	var point: Vector3 = lab._batted_ball.global_position
	var director: StadiumMogulTwoCamera = lab._camera_director
	var property: StadiumMogulTwoProperty = lab.get_meta("stadium_property")
	owner._check(
		(
			not camera.is_position_behind(point)
			and Rect2(24, 24, 1232, 672).has_point(camera.unproject_position(point))
		),
		"real controller camera acquires launch through terminal with unchanged24px margin"
	)
	owner._check(
		owner._near_clear(camera), "real controller camera retains physical near-volume clearance"
	)
	owner._check(
		(
			not director.tracking_visibility.actual_blocked(camera.global_position, point)
			and owner._clear_after_fades(property, camera.global_position, point)
		),
		"real controller camera retains independent whole-scene physical line of sight"
	)
	if delta > 0:
		owner._check(
			(
				previous.origin.distance_to(camera.global_position) < 32.1 * delta
				and (
					previous.basis.get_rotation_quaternion().angle_to(
						camera.global_basis.get_rotation_quaternion()
					)
					< 1.7 * delta
				)
			),
			"ordinary controller acquisition retains original motion and turn bounds"
		)
	var actor: Dictionary = ActorProof.audit(lab, faces)
	owner._check(
		actor.actors == 4 and actor.hidden == 0 and actor.opaque == 0,
		"real controller source retains all authentic actor visibility checks"
	)


static func _source_controller_readbacks(
	owner: Node,
	lab: PitchBatLab,
	source: Array[Dictionary],
	captured: Dictionary,
	left: bool,
	defense: bool
) -> void:
	# Read back recorded controller poses and captured dynamic presentation only after
	# genuine physics ends. These are archived render-state restorations, never launches.
	var ball: BattedBallBody = lab._batted_ball
	var current: Dictionary = Presentation.capture(lab)
	var current_parents: Array = _parent_poses(lab)
	var current_actors: Array = ActorProof.poses(lab)
	var original_camera: Transform3D = lab._camera.global_transform
	var original_fov: float = lab._camera.fov
	var original_ball: Transform3D = ball.global_transform
	var original_dead: bool = lab._ball_play_resolver.state.dead
	var original_phase: int = lab._match_state.phase
	var director: StadiumMogulTwoCamera = lab._camera_director
	var original_shot: int = director.shot
	var held: Dictionary = Freeze.lock(lab)
	owner._check(
		Freeze.intact(lab, held), "archived controller state restores under physical capture lock"
	)
	ball.freeze = true
	owner._native_evidence.note_controller(left, defense, [0, 1, source.size() - 1])
	for index: int in [0, 1, source.size() - 1]:
		var sample: Dictionary = source[index]
		owner._check(
			captured.has(index),
			"every required controller readback has captured source presentation"
		)
		if not captured.has(index):
			continue
		ball.global_transform = sample.ball_transform
		_restore_poses(owner, sample.parent_poses)
		_restore_poses(owner, sample.actor_poses)
		lab._camera.global_transform = sample.controller_camera
		lab._camera.fov = sample.controller_fov
		director.shot = sample.controller_shot
		lab._ball_play_resolver.state.dead = sample.dead
		lab._match_state.phase = sample.match_phase
		# Restore actual sampled fades/receiver flex/trail/shadow, including dead terminal
		# presentation. Never restart a live resolver or recompute a more helpful fade.
		Presentation.restore(owner, lab, captured[index])
		owner._check(
			_scoreboard_visual(lab) == sample.scoreboard_visual,
			"held-score receiver-foul readback preserves every actual board label and shown value"
		)
		owner._check(
			Presentation.proof(captured[index]) == sample.presentation_proof,
			"archived controller presentation keeps source-bound numerical identity"
		)
		var contrast: float = await owner._representative_contrast(
			lab._camera,
			ball,
			(
				"mogul-two-controller-source-%s-%s-%d"
				% ["left" if left else "right", "defense" if defense else "offense", index]
			),
			{
				"kind": "captured-real-controller-presentation-readback-not-new-physics",
				"source_index": index,
				"terminal": sample.dead,
				"source_time": sample.time,
				"source_presentation_sha256":
				var_to_bytes(sample.presentation_proof).hex_encode().sha256_text(),
				"camera_profile": StadiumMogulTwoCamera.PROFILE
			}
		)
		owner._check(
			contrast >= 0.03, "captured real-controller early/terminal native contrast retains0.03"
		)
		owner._check(
			Freeze.intact(lab, held), "native controller readback preserves outer capture lock"
		)
	_restore_poses(owner, current_parents)
	_restore_poses(owner, current_actors)
	Presentation.release(owner, lab, current)
	ball.global_transform = original_ball
	lab._camera.global_transform = original_camera
	lab._camera.fov = original_fov
	director.shot = original_shot
	lab._ball_play_resolver.state.dead = original_dead
	lab._match_state.phase = original_phase
	owner._check(
		Freeze.unlock(lab, held),
		"archived controller readback restores all callback and tween modes"
	)


static func _scoreboard_visual(lab: PitchBatLab) -> Dictionary:
	var property: StadiumMogulTwoProperty = lab.get_meta("stadium_property")
	var display: StadiumScoreboardDisplay = property.display
	var result: Dictionary = {
		"id": display.get_instance_id(), "shown": display.shown.duplicate(true), "labels": []
	}
	for child: Node in display.get_children():
		if not child is Label3D:
			continue
		var label: Label3D = child as Label3D
		var color: Color = label.modulate
		result.labels.append(
			{
				"id": label.get_instance_id(),
				"parent": display.get_instance_id(),
				"text": label.text,
				"pose": label.global_transform,
				"visible": label.is_visible_in_tree(),
				"font_size": label.font_size,
				"pixel_size": label.pixel_size,
				"modulate": [color.r, color.g, color.b, color.a]
			}
		)
	return result
