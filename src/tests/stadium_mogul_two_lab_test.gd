extends Node3D

const Evidence = preload("res://src/tests/stadium_mogul_two_evidence.gd")
## One complete candidate in the actual lab, with explicit isolated access and physical outcomes.

const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")

var _native: NativeCapture
var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	await _render_lifecycle()
	var initial_msaa: int = int(get_viewport().msaa_3d)
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(
		not StadiumMogulTwoLab.install(lab), "complete candidate requires explicit isolated opt-in"
	)
	lab.set_meta("stadium_grand_i_lab_only", true)
	_check(not StadiumMogulTwoLab.install(lab), "legacy Grand opt-in never authorizes AM-02")
	lab.remove_meta("stadium_grand_i_lab_only")
	lab.set_meta("stadium_mogul_two_lab_only", true)
	lab._camera_mode = 1
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var previous_shot: int = lab._camera_director.shot
	lab._managed_match = true
	_check(not StadiumMogulTwoLab.install(lab), "candidate cannot enter a managed fixture")
	lab._managed_match = false
	_check(
		StadiumMogulTwoLab.install(lab) and not StadiumMogulTwoLab.install(lab),
		"one complete assembly"
	)
	if _failures > 0:
		await _dispose_lab(lab)
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	_check(
		lab._camera_director.shot == previous_shot,
		"install preserves the current paused inspection shot"
	)
	lab._camera_director.restore_after_pause()
	_check(
		lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING and lab._camera_mode == 1,
		"closing paused inspection restores the pre-install role camera"
	)
	var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
	_render_contract(property as StadiumMogulTwoProperty, initial_msaa)
	_check(
		(
			property is StadiumMogulTwoProperty
			and lab._camera_director is StadiumMogulTwoCamera
			and lab.has_meta("stadium_mogul_two_candidate")
			and not lab.has_meta("stadium_grand_i_candidate")
		),
		"actual isolated AM-02 property camera and candidate identity"
	)
	_check(
		PhysicalMatchReport.capture(lab).is_empty(),
		"candidate cannot produce a misleading ordinary-field production report"
	)
	_check(
		(
			property.get_meta("candidate_venue").items.size() == 91
			and not lab.has_meta("stadium_snapshot")
		),
		"complete NPC candidate grants no saved eligibility"
	)
	_check(
		(
			lab.get_node("StarterFieldGeometry").get_node_or_null("BackWall") == null
			and not property.has_node("TemplateBackWall")
		),
		"old infinite back collisions are absent"
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not property.configure_candidate(lab), "complete adapter cannot duplicate its receivers")
	_camera_entry_controls(lab, property as StadiumMogulTwoProperty)
	_visibility_contract(lab, property as StadiumMogulTwoProperty)
	_receiver_identity_controls(lab, property as StadiumMogulTwoProperty)
	_actor_identity_controls(lab)
	_receiver_routes(property)
	lab._start_new_match()
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	lab._match_state.inning = 3
	lab._match_state.home_team.runs = 7
	property.display._process(0)
	_check(
		(
			property.display._match == lab._match_state
			and property.display.shown.inning == 3
			and property.display.shown.home == 7
		),
		"manual board follows the replacement match after restart"
	)
	_routes(lab, property)
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._status_label.visible = false
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		for shot in range(MatchCameraDirector.Shot.size()):
			lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
			lab._camera_director.snap(lab._camera, Vector3(0, 1, 5))
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			_check(
				_clear_camera(lab._camera), "all fixed views clear complete physical infrastructure"
			)
			if shot in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
				await _capture(
					(
						"mogul-two-field-%s-%s"
						% [
							"left" if left else "right",
							"batting" if shot == MatchCameraDirector.Shot.BATTING else "pitching"
						]
					)
				)
	for sample: Array in [
		[Vector3(0, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(1.5, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(0, 4, 25.3), Vector3(0, 0, 36), false, BallPlayOutcome.Result.HOME_RUN]
	]:
		await _flight(lab, property, sample)
	for left in [false, true]:
		var inward: Vector3 = Vector3(-1 if left else 1, 0, 0)
		var from: Vector3 = StadiumDugoutRecipe.rail_point(13, -0.5, left) + Vector3.UP * 0.6
		for foul in [false, true]:
			await _flight(
				lab,
				property,
				[
					from,
					inward * 8,
					foul,
					BallPlayOutcome.Result.FOUL if foul else BallPlayOutcome.Result.SINGLE
				]
			)
	_teardown(lab, property as StadiumMogulTwoProperty)
	await _dispose_lab(lab)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro complete AM-02 lab passed: "
				+ "explicit assembly, contained routes and real outcomes."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _routes(lab: PitchBatLab, property: StadiumClubPropertyGeometry) -> void:
	var fielder: FielderController = lab._primary_fielder
	var original: Vector3 = fielder.global_position
	var processing: bool = fielder.is_physics_processing()
	fielder.set_physics_process(false)
	for target: Vector3 in [
		Vector3(100, 0, 13),
		Vector3(-100, 0, 13),
		Vector3(0, 0, 100),
		Vector3(0, 0, -100),
		Vector3(1.5, 0, -4.5)
	]:
		fielder.set_anchor(Vector3(0, 0, 10))
		fielder.begin_play()
		fielder.target_position = target
		for step in range(120):
			var before: Vector3 = fielder.global_position
			fielder._physics_process(1.0 / 30)
			var current: Vector3 = fielder.global_position
			_check(
				property.boundary.graph.contains(Vector2(current.x, current.z)),
				"defender never shortcuts through dead dugout space"
			)
			_check(
				StadiumDefenderRoutes.clear(before, current, property.route_obstacles()),
				"defender body path clears receiver footprint"
			)
		fielder.end_play()
	fielder.set_anchor(original)
	fielder.set_physics_process(processing)
	lab._pitcher_marker.global_position = Vector3(0, 0, 14)
	var clipped: Vector3 = StadiumPropertyRuntime.pitcher_step(
		lab, Vector3(100, 0, 14), 100, Vector3(100, 0, 14)
	)
	_check(
		property.boundary.graph.contains(Vector2(clipped.x, clipped.z)),
		"actual pitcher adapter also respects complete graph"
	)


func _flight(lab: PitchBatLab, property: StadiumClubPropertyGeometry, sample: Array) -> void:
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	property.receiver.contacts.clear()
	_check(lab._match_state.begin_pitch(), "real candidate play begins from a pitch")
	var outcomes: Array[BallPlayOutcome] = []
	var callback: Callable = func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome)
	lab._ball_play_resolver.play_resolved.connect(callback)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = sample[0]
	launch.velocity = sample[1]
	launch.is_foul = sample[2]
	lab._start_ball_in_play(launch)
	_live_entry_control(lab)
	_check(
		lab._batted_ball.physics_contact_router.is_valid(), "real game ball uses candidate physics"
	)
	for frame in range(120):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.dead:
			break
	_check(
		outcomes.size() == 1 and outcomes[0].result == sample[3],
		"one actual candidate terminal outcome at " + str(sample[0])
	)
	if sample[0].z < 1:
		_check(
			property.receiver.contacts.size() == 1,
			"physical target and net containment each produce exactly one response"
		)
	lab._ball_play_resolver.play_resolved.disconnect(callback)
	lab._cleanup_batted_ball()


func _clear_camera(camera: Camera3D) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = camera.near * 2
	query.collision_mask = StadiumClubPropertyGeometry.CAMERA_LAYER
	query.transform.origin = camera.global_position
	return camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _receiver_routes(property: StadiumClubPropertyGeometry) -> void:
	var from: Vector3 = Vector3(-1, 0, -2.02)
	var to: Vector3 = Vector3(1, 0, -2.02)
	_check(
		(
			_physical_receiver_hit(from, to)
			and not StadiumDefenderRoutes.clear(from, to, property.route_obstacles())
		),
		"route rejects a real rear target crossbar collision, independent of route approximation"
	)
	for side: float in [-1, 1]:
		var point: Vector3 = Vector3(side * 5.12, 0, -3.375)
		_check(
			(
				_physical_receiver_hit(point, point)
				and not StadiumDefenderRoutes.clear(point, point, property.route_obstacles())
			),
			"route includes physical outer anchor corners on both net sides"
		)


func _physical_receiver_hit(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = CylinderShape3D.new()
	query.shape.radius = StadiumDefenderRoutes.BODY_RADIUS
	query.shape.height = 1.8
	query.margin = 0
	query.transform.origin = from + Vector3.UP * 0.9
	query.collision_mask = StadiumPitchReceiver.LAYER
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return true
	query.motion = to - from
	return space.cast_motion(query)[0] < 1


func _capture(name_value: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(extent), "actual native window resize acknowledged")
		_check(
			await Evidence.capture(self, _native, _capture_dir, name_value),
			"normal/small actual whole-field camera readback verified"
		)
	_check(_native._failures == 0, "native helper failures propagate")


func _visibility_contract(lab: PitchBatLab, property: StadiumMogulTwoProperty) -> void:
	var visibility: StadiumMogulTwoVisibility = (
		lab._camera_director.tracking_visibility as StadiumMogulTwoVisibility
	)
	_check(
		visibility != null and visibility.ready,
		"AM-02 installs its exact complete visibility adapter"
	)
	if visibility == null or not visibility.ready:
		return
	var groups: int = 0
	for value: Variant in property.objects.values():
		_check(value is Node3D, "indexed component has actual Node3D identity")
		if not value is Node3D:
			continue
		var model: Node3D = value as Node3D
		var item: String = model.get_meta("stadium_item", "")
		if item in ["ST-026", "ST-073", "ST-065", "ST-065-T", "ST-022", "ST-023"]:
			continue
		groups += 1
		var root: Node = model.get_node_or_null("Visual")
		_check(root != null, "every actual opaque item has its required Visual hierarchy")
		if root == null:
			continue
		var members: Array[Dictionary] = []
		var ids: Array[int] = []
		var bounds: AABB
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if ids.is_empty() else bounds.merge(box)
			ids.append(mesh.get_instance_id())
			members.append(
				{"inverse": mesh.global_transform.affine_inverse(), "bounds": mesh.get_aabb()}
			)
		var key: String = model.get_meta("candidate_instance")
		_check(
			visibility.model_meshes.get(key) == ids,
			"camera enrollment contains every actual opaque mesh of " + item
		)
		var matches: int = 0
		for group: Dictionary in visibility._groups:
			if group.identity == key:
				matches += 1
				_check(
					group.item == item and group.members == members and group.bounds == bounds,
					"opaque group binds actual full hierarchy inverse transforms and bounds"
				)
		_check(matches == 1, "one distinct camera group per purchased opaque component")
	_check(
		groups == 32 and visibility._groups.size() == 32, "all thirty-two AM-02 opaque groups enrolled"
	)
	_check(
		(
			visibility._rails.size() == 6
			and visibility._uprights.size() == 4
			and visibility._obstacles.is_empty()
		),
		"six actual dugout rails and four genuine foul-pole bounds preserve original policy"
	)
	var board: Node3D = property.objects[StadiumMogulTwoStudy.PREFIX + "SCORE-SMALL"]
	var visual: Node = board.get_node("Visual")
	var rejected: StadiumMogulTwoVisibility = StadiumMogulTwoVisibility.new()
	visual.name = "MissingVisualControl"
	_check(
		(
			not rejected.configure_candidate(property)
			and not rejected.ready
			and rejected._groups.is_empty()
			and rejected.model_meshes.is_empty()
			and rejected._recipe == null
			and rejected._wall_prisms == null
		),
		"missing historical board visual fails atomically without partial usable groups"
	)
	visual.name = "Visual"
	_check(rejected.configure_candidate(property), "restored actual board recovers exact preflight")
	var mesh: MeshInstance3D = visual.find_children("*", "MeshInstance3D", true, false)[0]
	var parent: Node = mesh.get_parent()
	var index: int = mesh.get_index()
	parent.remove_child(mesh)
	_check(
		not rejected.configure_candidate(property) and rejected._groups.is_empty(),
		"one missing opaque board member cannot silently disappear from enrollment"
	)
	parent.add_child(mesh)
	parent.move_child(mesh, index)
	var pose: Transform3D = mesh.transform
	mesh.scale = Vector3.ZERO
	_check(
		not rejected.configure_candidate(property) and not rejected.ready,
		"singular actual member rejects before affine inverse"
	)
	mesh.transform = pose
	mesh.visible = false
	_check(
		not rejected.configure_candidate(property) and not rejected.ready,
		"hidden required opaque member fails closed"
	)
	mesh.visible = true
	_check(
		(
			rejected.configure_candidate(property)
			and rejected.model_meshes == visibility.model_meshes
			and lab._camera_director.tracking_visibility == visibility
		),
		"all negative controls restore every member and keep installed camera unchanged"
	)


func _teardown(lab: PitchBatLab, property: StadiumMogulTwoProperty) -> void:
	property.actor_cutaway.restore_all()
	var receiver: StadiumClubPitchReceiver = property.receiver
	var director: StadiumMogulTwoCamera = lab._camera_director as StadiumMogulTwoCamera
	var actor_materials: Array = []
	for root: Node3D in [
		lab._batter_avatar, lab._bat_actor, lab._pitcher_avatar, lab._primary_fielder._avatar
	]:
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			actor_materials.append(
				[mesh, mesh.material_override, mesh.transparency, mesh.cast_shadow]
			)
	property.get_parent().remove_child(property)
	_check(
		(
			not lab.has_meta("stadium_property")
			and not lab._pitch_actor.receiver_router.is_valid()
			and not lab._ball_play_resolver.segment_observer.is_valid()
			and not lab._primary_fielder.stadium_boundary_clip.is_valid()
			and lab._primary_fielder.stadium_obstacles.is_empty()
		),
		"actual property teardown clears only its own live receiver observer and route wiring"
	)
	_check(
		(
			property.actor_cutaway.entries.is_empty()
			and director.actor_cutaway == null
			and receiver._active_tween == null
		),
		"teardown restores actors and cancels receiver work"
	)
	property._exit_tree()
	_check(
		property.actor_cutaway.entries.is_empty() and not lab.has_meta("stadium_property"),
		"repeat teardown is metadata-safe and idempotent"
	)
	for row: Array in actor_materials:
		var mesh: MeshInstance3D = row[0]
		_check(
			(
				mesh.material_override == row[1]
				and mesh.transparency == row[2]
				and mesh.cast_shadow == row[3]
			),
			"safe fixed-camera teardown retains exact actor render resources"
		)
	property.queue_free()


func _receiver_identity_controls(lab: PitchBatLab, property: StadiumMogulTwoProperty) -> void:
	var receiver: StadiumMogulTwoReceiver = property.receiver as StadiumMogulTwoReceiver
	_check(
		receiver != null and receiver.intact(), "installed pair uses genuine AM-02 guarded receiver"
	)
	if receiver == null:
		return
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 3, -6), Vector3(0, 3, 0), StadiumPitchReceiver.LAYER
	)
	var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		hit = hit.duplicate(true)
		hit.point = hit.position
	_check(
		not hit.is_empty() and not receiver._owned_hit(hit, 0.5).is_empty(),
		"real mounted net has a positive owned physical-hit control"
	)
	if hit.is_empty():
		return
	var body: StaticBody3D = hit.collider as StaticBody3D
	var original: Variant = body.get_meta("owned_copy")
	body.set_meta("owned_copy", "foreign-owner")
	_check(
		receiver._owned_hit(hit, 0.5).is_empty(),
		"real collider with wrong ownership cannot be routed"
	)
	body.set_meta("owned_copy", original)
	_check(
		not receiver._owned_hit(hit, 0.5).is_empty(),
		"exact owned metadata restoration recovers genuine hit"
	)
	var foreign: StaticBody3D = StaticBody3D.new()
	foreign.set_meta("owned_copy", original)
	foreign.set_meta("surface_id", body.get_meta("surface_id"))
	add_child(foreign)
	var spoofed: Dictionary = hit.duplicate()
	spoofed.collider = foreign
	spoofed.collider_id = foreign.get_instance_id()
	_check(
		receiver._owned_hit(spoofed, 0.5).is_empty(),
		"foreign actual body with copied labels cannot impersonate owned net"
	)
	foreign.queue_free()
	var actor: PitchFlightActor = PitchFlightActor.new()
	add_child(actor)
	_check(
		not receiver.route(actor, Vector3(0, 1.2, 0), Vector3(0, 0, -30)),
		"foreign pitch actor cannot replace genuine installed actor"
	)
	actor.queue_free()
	_check(
		(
			receiver.intact()
			and not receiver._owned_hit(hit, 0.5).is_empty()
			and lab._pitch_actor.receiver_router == receiver.route
		),
		"every negative receiver control restores original pair body actor and callback"
	)


func _actor_identity_controls(lab: PitchBatLab) -> void:
	var exact: Array[Node3D] = StadiumMogulTwoCamera.presentation_actors(lab)
	_check(exact.size() == 4, "all four actual installed actors participate")
	var role: PlayerAvatar.Role = lab._pitcher_avatar.role
	lab._pitcher_avatar.role = PlayerAvatar.Role.FIELDER
	_check(
		not StadiumMogulTwoCamera.presentation_actors(lab).has(lab._pitcher_avatar),
		"role mismatch cannot obtain pitcher cutaway authority"
	)
	lab._pitcher_avatar.role = role
	var parent: Node = lab._pitcher_avatar.get_parent()
	var index: int = lab._pitcher_avatar.get_index()
	var local: Transform3D = lab._pitcher_avatar.transform
	parent.remove_child(lab._pitcher_avatar)
	add_child(lab._pitcher_avatar)
	_check(
		not StadiumMogulTwoCamera.presentation_actors(lab).has(lab._pitcher_avatar),
		"correct actor under wrong actual parent cannot receive cutaway authority"
	)
	remove_child(lab._pitcher_avatar)
	parent.add_child(lab._pitcher_avatar)
	parent.move_child(lab._pitcher_avatar, index)
	lab._pitcher_avatar.transform = local
	_check(
		StadiumMogulTwoCamera.presentation_actors(lab) == exact,
		"original actor identities roles parentage order and pose restore after controls"
	)


func _camera_entry_controls(lab: PitchBatLab, property: StadiumMogulTwoProperty) -> void:
	var director: StadiumMogulTwoCamera = lab._camera_director as StadiumMogulTwoCamera
	var camera: Camera3D = lab._camera
	var pose: Transform3D = camera.global_transform
	var optics: Array = [camera.fov, camera.projection, camera.size]
	var saved: Dictionary = {}
	for key: String in [
		"shot",
		"_shot_before_inspection",
		"_presentation_motion",
		"_presentation_progress",
		"_presentation_transition_speed",
		"_standard_fov"
	]:
		saved[key] = director.get(key)
	var phase: MatchState.Phase = lab._match_state.phase
	var running: bool = lab._pitch_actor.running
	director.shot = MatchCameraDirector.Shot.BATTING
	director._shot_before_inspection = -1
	director.clear_presentation_motion()
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	lab._pitch_actor.running = false
	_check(
		director._entry_owned() and director.acquire_precontact_entry(),
		"genuine idle installed batting camera acquires its authored entry"
	)
	# A sentinel pose/optic makes any forbidden reacquisition observable.
	camera.global_position += Vector3(0.17, 0.23, 0.31)
	camera.fov -= 7.0
	_camera_owner_controls(lab, property)
	lab._pitch_actor.running = true
	_entry_rejected(director, camera, "running pitch", true)
	lab._pitch_actor.running = false
	for wrong_phase: int in MatchState.Phase.values():
		if wrong_phase == MatchState.Phase.PRE_PITCH:
			continue
		lab._match_state.phase = wrong_phase as MatchState.Phase
		_entry_rejected(director, camera, "non-pre-pitch phase %d" % wrong_phase, true)
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	for wrong_shot: int in [
		MatchCameraDirector.Shot.PITCHING,
		MatchCameraDirector.Shot.FIELD_SETUP,
		MatchCameraDirector.Shot.BALL_IN_PLAY
	]:
		director.shot = wrong_shot as MatchCameraDirector.Shot
		_entry_rejected(director, camera, "non-batting shot %d" % wrong_shot, true)
	director.shot = MatchCameraDirector.Shot.BATTING
	director._shot_before_inspection = MatchCameraDirector.Shot.BATTING
	_entry_rejected(director, camera, "paused inspection", true)
	director._shot_before_inspection = -1
	_check(director.acquire_precontact_entry(), "restored exact ownership recovers idle entry")
	for key: String in saved:
		director.set(key, saved[key])
		_check(director.get(key) == saved[key], "exact director entry state restores: " + key)
	lab._match_state.phase = phase
	lab._pitch_actor.running = running
	camera.global_transform = pose
	camera.fov = optics[0]
	camera.projection = optics[1]
	camera.size = optics[2]
	_check(
		(
			camera.global_transform == pose
			and camera.fov == optics[0]
			and camera.projection == optics[1]
			and camera.size == optics[2]
			and lab._match_state.phase == phase
			and lab._pitch_actor.running == running
			and director._entry_owned()
		),
		"entry controls restore the original camera pose optics and installed ownership"
	)


func _camera_owner_controls(lab: PitchBatLab, property: StadiumMogulTwoProperty) -> void:
	var director: StadiumMogulTwoCamera = lab._camera_director as StadiumMogulTwoCamera
	var camera: Camera3D = lab._camera
	var actor: PitchFlightActor = lab._pitch_actor
	var receiver: StadiumMogulTwoReceiver = property.receiver as StadiumMogulTwoReceiver
	lab._camera = null
	_entry_rejected(director, camera, "missing actual camera")
	var foreign_camera: Camera3D = Camera3D.new()
	add_child(foreign_camera)
	lab._camera = foreign_camera
	_entry_rejected(director, camera, "foreign camera pointer")
	_entry_rejected(director, foreign_camera, "foreign camera remains untouched")
	lab._camera = camera
	foreign_camera.free()
	var camera_name: StringName = camera.name
	camera.name = "AM02ForeignCameraPath"
	_entry_rejected(director, camera, "camera outside exact LabCamera path")
	camera.name = camera_name
	lab._pitch_actor = null
	_entry_rejected(director, camera, "missing actual pitch actor")
	var foreign_actor: PitchFlightActor = PitchFlightActor.new()
	lab._pitch_actor = foreign_actor
	_entry_rejected(director, camera, "foreign pitch actor pointer")
	lab._pitch_actor = actor
	foreign_actor.free()
	var actor_name: StringName = actor.name
	actor.name = "AM02ForeignActorPath"
	_entry_rejected(director, camera, "actor outside exact PitchFlightActor path")
	actor.name = actor_name
	# Rename tests exact parent/path authority without destructive property tree exit.
	var property_name: StringName = property.name
	property.name = "AM02ForeignPropertyPath"
	_entry_rejected(director, camera, "property outside exact HomeProperty path")
	property.name = property_name
	lab.remove_meta("stadium_property")
	_entry_rejected(director, camera, "missing property metadata")
	lab.set_meta("stadium_property", self)
	_entry_rejected(director, camera, "foreign property metadata")
	lab.set_meta("stadium_property", property)
	property.receiver = null
	_entry_rejected(director, camera, "missing property receiver")
	property.receiver = receiver
	for row: Array in [
		[director, "lab_ref"],
		[property, "lab_ref"],
		[receiver, "property_ref"],
		[receiver, "lab_ref"],
		[receiver, "actor_ref"]
	]:
		var link_owner: Object = row[0]
		var key: String = row[1]
		var reference: WeakRef = link_owner.get(key)
		for invalid: WeakRef in [null, weakref(self)]:
			link_owner.set(key, invalid)
			_entry_rejected(director, camera, "missing or foreign " + key)
		link_owner.set(key, reference)
		_check(link_owner.get(key) == reference, "exact weak ownership link restores: " + key)
	var venue: Dictionary = property.get_meta("candidate_venue")
	property.remove_meta("candidate_venue")
	_entry_rejected(director, camera, "missing camera profile record")
	for invalid: Variant in [
		false,
		{},
		{"camera_profile": false},
		{"camera_profile": {}},
		{"camera_profile": {"id": "foreign-profile"}}
	]:
		property.set_meta("candidate_venue", invalid)
		_entry_rejected(director, camera, "malformed or foreign camera profile")
	property.set_meta("candidate_venue", venue)
	_check(
		director._entry_owned() and receiver.intact(),
		"all ownership negatives restore the exact genuine installed camera and receiver"
	)


func _entry_rejected(
	director: StadiumMogulTwoCamera, camera: Camera3D, label: String, owned: bool = false
) -> void:
	var pose: Transform3D = camera.global_transform
	var fov: float = camera.fov
	_check(director._entry_owned() == owned, label + " has the expected ownership result")
	_check(not director.acquire_precontact_entry(), label + " cannot acquire a pre-contact entry")
	_check(
		camera.global_transform == pose and camera.fov == fov,
		label + " preserves exact camera pose and FOV"
	)


func _live_entry_control(lab: PitchBatLab) -> void:
	var director: StadiumMogulTwoCamera = lab._camera_director as StadiumMogulTwoCamera
	var shot: MatchCameraDirector.Shot = director.shot
	var phase: MatchState.Phase = lab._match_state.phase
	var running: bool = lab._pitch_actor.running
	_check(
		is_instance_valid(lab._batted_ball) and lab._batted_ball._started,
		"no-cut body control uses the actual launched physical ball"
	)
	# Isolate the genuine live body's guard, then restore without advancing any frame.
	director.shot = MatchCameraDirector.Shot.BATTING
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	lab._pitch_actor.running = false
	_entry_rejected(director, lab._camera, "actual live physical body", true)
	director.shot = shot
	lab._match_state.phase = phase
	lab._pitch_actor.running = running
	_check(
		(
			director.shot == shot
			and lab._match_state.phase == phase
			and lab._pitch_actor.running == running
		),
		"actual live-body entry control restores exact role phase and pitch-running state"
	)


func _render_contract(property: StadiumMogulTwoProperty, initial_msaa: int) -> void:
	var profile: Dictionary = property.get_meta("candidate_venue").render_profile
	_check(
		(
			profile
			== {
				"id": "STADIUM-WALL-MSAA4X-v1",
				"native_minimum_msaa_3d": "4x",
				"helper": "res://src/presentation/stadium/stadium_wall_render_quality.gd",
				"helper_sha256":
				FileAccess.get_sha256(
					"res://src/presentation/stadium/stadium_wall_render_quality.gd"
				),
				"ownership": "installed-property-viewport-lifetime",
				"headless": "no-op",
				"higher_quality": "preserve",
				"restore": "last-owner-if-unchanged"
			}
		),
		"canonical AM-02 fixture binds the exact unchanged scoped render-quality contract"
	)
	var viewport: Viewport = property.get_viewport()
	if DisplayServer.get_name() == "headless":
		_check(
			(
				int(viewport.msaa_3d) == initial_msaa
				and not viewport.has_meta(StadiumWallRenderQuality.META)
				and not StadiumWallRenderQuality.attach(property)
			),
			"genuine installed headless AM-02 is an AA no-op without fabricated native ownership"
		)
		return
	var state: Dictionary = viewport.get_meta(StadiumWallRenderQuality.META, {})
	_check(
		(
			not state.is_empty()
			and state.get("owners", {}).has(property.get_instance_id())
			and int(viewport.msaa_3d) >= Viewport.MSAA_4X
		),
		"native AA lease belongs to actual installed AM-02 property and meets unchanged4X minimum"
	)
	var saved: Dictionary = state.duplicate(true)
	_check(
		(
			not StadiumWallRenderQuality.attach(property)
			and viewport.get_meta(StadiumWallRenderQuality.META, {}) == saved
		),
		"reattaching the same installed property is idempotent without duplicate ownership"
	)


func _render_lifecycle() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var original: int = int(viewport.msaa_3d)
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	var first: PitchBatLab = _render_lab(viewport)
	if not first.has_meta("stadium_property"):
		await _dispose_lab(first, viewport)
		viewport.set("msaa_3d", original)
		await _dispose_viewport(viewport)
		return
	var first_property: StadiumMogulTwoProperty = first.get_meta("stadium_property")
	_render_contract(first_property, Viewport.MSAA_DISABLED)
	if DisplayServer.get_name() == "headless":
		await _dispose_lab(first, viewport)
		_check(
			(
				viewport.msaa_3d == Viewport.MSAA_DISABLED
				and not viewport.has_meta(StadiumWallRenderQuality.META)
			),
			"headless property exit does not invent an AA lease or alter quality"
		)
	else:
		var first_id: int = first_property.get_instance_id()
		var second: PitchBatLab = _render_lab(viewport)
		if not second.has_meta("stadium_property"):
			await _dispose_lab(first, viewport)
			await _dispose_lab(second, viewport)
			viewport.set("msaa_3d", original)
			await _dispose_viewport(viewport)
			return
		var second_property: StadiumMogulTwoProperty = second.get_meta("stadium_property")
		_render_contract(second_property, Viewport.MSAA_4X)
		var second_id: int = second_property.get_instance_id()
		var state: Dictionary = viewport.get_meta(StadiumWallRenderQuality.META, {})
		_check(
			(
				state.get("owners", {}).size() == 2
				and state.get("owners", {}).has(first_id)
				and state.get("owners", {}).has(second_id)
			),
			"two genuine AM-02 properties own separate viewport leases"
		)
		await _dispose_lab(first, viewport)
		state = viewport.get_meta(StadiumWallRenderQuality.META, {})
		_check(
			(
				viewport.msaa_3d == Viewport.MSAA_4X
				and state.get("owners", {}).size() == 1
				and state.get("owners", {}).has(second_id)
				and not state.get("owners", {}).has(first_id)
			),
			"old AM-02 property exit cannot remove overlapping replacement quality"
		)
		await _dispose_lab(second, viewport)
		_check(
			(
				viewport.msaa_3d == Viewport.MSAA_DISABLED
				and not viewport.has_meta(StadiumWallRenderQuality.META)
			),
			"last genuine property restores exact pre-lease viewport quality and removes ownership"
		)
		viewport.msaa_3d = Viewport.MSAA_8X
		var higher: PitchBatLab = _render_lab(viewport)
		_check(
			higher.has_meta("stadium_property") and viewport.msaa_3d == Viewport.MSAA_8X,
			"installed AM-02 never lowers pre-existing higher8X quality"
		)
		if higher.has_meta("stadium_property"):
			_render_contract(higher.get_meta("stadium_property"), Viewport.MSAA_8X)
		await _dispose_lab(higher, viewport)
		_check(
			(
				viewport.msaa_3d == Viewport.MSAA_8X
				and not viewport.has_meta(StadiumWallRenderQuality.META)
			),
			"higher pre-existing quality survives actual AM-02 property exit"
		)
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		var external: PitchBatLab = _render_lab(viewport)
		_check(
			external.has_meta("stadium_property") and viewport.msaa_3d == Viewport.MSAA_4X,
			"external-change control first establishes the actual4X installed lease"
		)
		if external.has_meta("stadium_property"):
			_render_contract(external.get_meta("stadium_property"), Viewport.MSAA_DISABLED)
		viewport.msaa_3d = Viewport.MSAA_2X
		await _dispose_lab(external, viewport)
		_check(
			(
				viewport.msaa_3d == Viewport.MSAA_2X
				and not viewport.has_meta(StadiumWallRenderQuality.META)
			),
			"later external viewport setting survives last-owner teardown unchanged"
		)
	viewport.set("msaa_3d", original)
	await _dispose_viewport(viewport)


func _dispose_lab(lab: PitchBatLab, viewport: SubViewport = null) -> void:
	if DisplayServer.get_name() != "headless":
		if viewport != null:
			# A root post-draw cannot prove that this disabled isolated viewport rendered.
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if viewport != null:
			var rendered: Image = viewport.get_texture().get_image()
			_check(
				(
					rendered != null
					and not rendered.is_empty()
					and rendered.get_size() == viewport.size
				),
				"native isolated lab renders a nonempty exact-size image before disposal"
			)
	# Keep each genuine lab (and its Sky) alive through its initial native upload.
	lab.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(lab), "genuine lab is freed after two process frames")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _dispose_viewport(viewport: SubViewport) -> void:
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	_check(not is_instance_valid(viewport), "isolated viewport is freed after render drain")


func _render_lab(viewport: SubViewport) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_mogul_two_lab_only", true)
	lab._sky_backdrop_enabled = false
	viewport.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(StadiumMogulTwoLab.install(lab), "AA control uses a genuinely installed complete AM-02")
	return lab
