extends Node3D
## Native evidence only: untouched retained factories, authentic actors, no certification.

const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
const Proof = preload("res://src/tests/stadium_npc_retained_daylight_support.gd")
const Freeze = preload("res://src/tests/stadium_npc_retained_daylight_freeze.gd")
const ActorChecks = preload("res://src/tests/stadium_actor_cutaway_test_support.gd")
# Keep-aspect native window700x400 produces the requested700x393 content.
const EXTENTS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(700, 400)]
const IDS: Array[String] = ["AY-01", "AE-01", "AC-01"]
const FPS: int = 60
@export var candidate_v2: bool = false
var _runtime: Script = StadiumNpcRetainedRuntime
var _revision: int = 1
var _failures: int = 0
var _capture_dir: String = ""
var _selected_venue: String = ""
var _native: Node
var _actor_meshes: Array[MeshInstance3D] = []
var _actor_faces: Dictionary = {}
var _capture_context: Dictionary = {}


func _ready() -> void:
	if candidate_v2:
		_runtime = StadiumNpcCandidateRuntimeV2
		_revision = 2
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	if candidate_v2 and not _capture_dir.is_empty():
		_capture_dir = _capture_dir.path_join("npc-candidate-r2")
	if DisplayServer.get_name() == "headless" or _capture_dir.is_empty():
		_check(false, "daylight qualification requires native renderer and --ui-capture-dir")
		get_tree().quit(1)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--npc-retained-venue="):
			_selected_venue = argument.trim_prefix("--npc-retained-venue=")
	if not _selected_venue.is_empty() and _selected_venue not in IDS:
		_check(false, "venue selector must name an exact retained identity")
		get_tree().quit(1)
		return
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native startup handshake")
	for id: String in IDS:
		if _selected_venue.is_empty() or id == _selected_venue:
			await _venue(id)
	_check(_native._failures == 0, "no hidden handshake failure")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		if _selected_venue.is_empty():
			print(
				(
					"Wiffaltro candidate NPC r2 daylight passed: AY/AE/AC native physical visibility."
					if candidate_v2
					else "Wiffaltro retained NPC daylight passed: AY/AE/AC native physical visibility."
				)
			)
		else:
			print(
				(
					(
						"Wiffaltro candidate NPC r2 daylight selected venue passed: "
						if candidate_v2
						else "Wiffaltro retained NPC daylight selected venue passed: "
					)
					+ _selected_venue
					+ "."
				)
			)
	get_tree().quit(0 if _failures == 0 else 1)


func _venue(id: String) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._batter_avatar.set_process(false)
	lab._pitcher_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	lab.set_meta("stadium_npc_retained_lab_only", true)
	var installed: bool = _runtime.install(lab, id, _revision)
	_check(installed, id + " actual retained installation")
	if not installed:
		lab.queue_free()
		await get_tree().process_frame
		return
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	_check(_runtime.installed(lab, id, _revision), id + " independent installation proof")
	var bodies: Array[Node] = property.find_children("*", "StaticBody3D", true, false)
	var layers: Array[int] = []
	for body: StaticBody3D in bodies:
		layers.append(body.collision_layer)
		body.collision_layer |= Proof.MASK
	await get_tree().physics_frame
	await get_tree().physics_frame
	var collision_snapshot: Array = Proof.colliders(property)
	for extent: Vector2i in EXTENTS:
		_check(await _native.resize(extent), "native extent acknowledged")
		var content: Vector2i = _native._expected_content_size(extent)
		_check(
			content == (Vector2i(1280, 720) if extent.x == 1280 else Vector2i(700, 393)),
			"requested daylight content resolution"
		)
		await _setup(lab, id, extent)
		await _controls(lab, id, extent)
		await _tracking(lab, id, extent)
	_check(
		Proof.colliders(property) == collision_snapshot, "camera policy preserves every collider"
	)
	for index in range(bodies.size()):
		bodies[index].collision_layer = layers[index]
	_check(_runtime.installed(lab, id, _revision), "evidence restores exact retained geometry")
	_check(_runtime.teardown(lab), "idle retained teardown")
	await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame


func _hand(lab: PitchBatLab, left: bool) -> void:
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = (
		PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
	)
	PitchBatLabPresentation.sync_players(lab)
	lab._camera_director.set_batter_handedness(left)
	_actor_meshes.clear()
	_actor_faces.clear()
	for actor: Node3D in [
		lab._batter_avatar, lab._pitcher_avatar, lab._bat_actor, lab._primary_fielder._avatar
	]:
		_actor_meshes.append_array(ActorChecks._meshes(actor))


func _setup(lab: PitchBatLab, id: String, extent: Vector2i) -> void:
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	for left: bool in [false, true]:
		_hand(lab, left)
		for shot: int in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
			lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
			lab._camera_director.snap(lab._camera)
			_refresh(lab)
			_check(_near_clear(lab._camera), "fixed view clears actual physical near enclosure")
			_check(not lab._camera.is_position_behind(Vector3(0, 1, 0)), "plate in front")
			if property.receiver != null:
				for model: Node3D in [property.receiver.chair, property.receiver.net]:
					var state: String = (
						"hidden" if shot == MatchCameraDirector.Shot.BATTING else "visible"
					)
					for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
						_check(
							Proof.verified_receiver(property, body, state),
							"authentic fixed receiver state"
						)
			await _shot("%s-%dx%d-hand%d-shot%d" % [id, extent.x, extent.y, int(left), shot])


func _controls(lab: PitchBatLab, id: String, extent: Vector2i) -> void:
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	var prior_state: BallPlayState = lab._ball_play_resolver.state
	var prior_field: FieldDefinition = lab._ball_play_resolver.field
	lab._ball_play_resolver.start_play(lab._field_definition, false)
	_check(lab._ball_in_play_is_live(), "controlled live probe uses actual resolver.start_play")
	ball.position = Vector3(0, 1.3, 40)
	lab._camera.position = Vector3(0, 1.3, -7)
	lab._camera.look_at(ball.position)
	_refresh(lab, true)
	var proof: Dictionary = Proof.trace(property, lab._camera.position, ball.position)
	_check(
		not proof.clear and proof.get("boundary", false), "actual far slab blocks negative control"
	)
	if property.receiver != null:
		_check(not proof.foreground.is_empty(), "negative traverses genuine faded foreground first")
	print("RETAINED_DAYLIGHT_NEGATIVE id=", id, " extent=", extent, " proof=", proof)
	await _shot("%s-%dx%d-opaque-behind-foreground-negative" % [id, extent.x, extent.y])
	var clear: Dictionary = Proof.trace(property, Vector3(0, 6, -3), Vector3(0, 1, 14))
	_check(clear.clear, "actual clear corridor control")
	lab._ball_play_resolver.state = prior_state
	lab._ball_play_resolver.field = prior_field
	lab._batted_ball = null
	_refresh(lab)
	ball.queue_free()
	await get_tree().process_frame


func _endpoints(id: String) -> Array[Vector3]:
	var depth: float = 23.3 if id == "AY-01" else 25.9 if id == "AE-01" else 27.9
	return [
		Vector3(0, 0.15, depth),
		Vector3(-8, 0.15, 22.4),
		Vector3(13, 0.15, 22.9),
		Vector3(7, 0.15, 11.75),
		Vector3(-17, 0.7, 12),
		Vector3(17, 0.7, 12),
		Vector3(0, 7, 26),
		Vector3(0, 35, 25)
	]


func _tracking(lab: PitchBatLab, id: String, extent: Vector2i) -> void:
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	var prior_state: BallPlayState = lab._ball_play_resolver.state
	var prior_field: FieldDefinition = lab._ball_play_resolver.field
	lab._ball_play_resolver.start_play(lab._field_definition, false)
	_check(lab._ball_in_play_is_live(), "controlled live probe uses actual resolver.start_play")
	var director: MatchCameraDirector = lab._camera_director
	var counts: Dictionary = {
		"samples": 0, "opaque": 0, "foreground": 0, "near": 0, "outside": 0, "footprint_outside": 0
	}
	var captures: Dictionary = {}
	var actor_captures: Dictionary = {}
	var actor_counts: Dictionary = {}
	var contrast_min: float = INF
	for left: bool in [false, true]:
		_hand(lab, left)
		for defense: bool in [false, true]:
			var role_lock: Dictionary = Freeze.lock(lab)
			_check(
				Freeze.intact(lab, role_lock),
				"role lock preserves actual physics membership and opaque ray/sphere controls"
			)
			var strongest: Dictionary = {}
			var actor_key: String = "%d-%d" % [int(left), int(defense)]
			actor_counts[actor_key] = {
				"midpath_samples": 0, "actor_hit_samples": 0, "actor_only_samples": 0
			}
			for requested: Vector3 in _endpoints(id):
				var start: Vector3 = Vector3(0, 1, 0)
				var stop: Dictionary = Proof.tracking_stop(property, start, requested)
				var endpoint: Vector3 = stop.get("position", requested)
				print(
					"RETAINED_DAYLIGHT_PATH id=",
					id,
					" extent=",
					extent,
					" hand=",
					left,
					" defense=",
					defense,
					" requested=",
					requested,
					" endpoint=",
					endpoint,
					" first_boundary_event=",
					stop
				)
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
				for frame in range(FPS * 4):
					ball.position = Vector3(0, 1, 0).lerp(endpoint, minf(1, frame / (FPS * 2.5)))
					_capture_context = {
						"requested": requested,
						"endpoint": endpoint,
						"stop": stop.duplicate(true),
						"frame": frame,
						"fps": FPS,
						"endpoint_reached": frame >= FPS * 2.5,
						"physical_contact_stop":
						(
							stop.get("swept_contact", false)
							or stop.get("kind", "") == "actual-boundary-sphere-contact"
						)
					}
					director.update(lab._camera, 1.0 / FPS, true, ball.position)
					_refresh(lab, true)
					var proof: Dictionary = Proof.trace(
						property, lab._camera.position, ball.position
					)
					counts.samples += 1
					counts.opaque += int(not proof.clear)
					counts.foreground += int(not proof.foreground.is_empty())
					counts.near += int(not _near_clear(lab._camera))
					counts.footprint_outside += int(not _footprint(lab, ball).framed)
					var screen: Vector2 = lab._camera.unproject_position(ball.position)
					counts.outside += int(
						(
							lab._camera.is_position_behind(ball.position)
							or not (
								lab
								. _camera
								. get_viewport()
								. get_visible_rect()
								. grow(-24)
								. has_point(screen)
							)
						)
					)
					# Read actual actor triangles on every moving midpath sample, not only captures.
					if frame > 0 and frame < FPS * 2.5:
						var span: Dictionary = _actor_span(lab, ball)
						var actor_hits: int = span.hits
						actor_counts[actor_key].midpath_samples += 1
						actor_counts[actor_key].actor_hit_samples += int(actor_hits > 0)
						if actor_hits > 0 and proof.clear and proof.foreground.is_empty():
							actor_counts[actor_key].actor_only_samples += 1
							if span.depth > strongest.get("depth", 0.0):
								strongest = _sample(lab, ball)
								strongest.merge(
									{
										"depth": span.depth,
										"span": span,
										"frame": frame,
										"requested": requested
									}
								)
							if not actor_captures.has(actor_key):
								actor_captures[actor_key] = true
								var actor_label: String = (
									"%s-%dx%d-h%d-role%d-actor-only-midpath"
									% [id, extent.x, extent.y, int(left), int(defense)]
								)
								print(
									"RETAINED_DAYLIGHT_ACTOR_ONLY label=",
									actor_label,
									" frame=",
									frame,
									" requested=",
									requested,
									" endpoint=",
									endpoint,
									" triangles=",
									actor_hits,
									" physical_proof=",
									proof
								)
								contrast_min = minf(
									contrast_min, await _contrast(lab, ball, actor_label)
								)
					# Grand I's documented low-ball sample is frame8 at60Hz on this exact path.
					if (
						not left
						and not defense
						and requested == Vector3(13, 0.15, 22.9)
						and frame == 8
					):
						_check(
							ball.position.is_equal_approx(Vector3(0.693333, 0.954667, 1.221333)),
							"historical low-ball sample retains its actual60Hz path position"
						)
						var historical_label: String = (
							"%s-%dx%d-historical-low-ball-frame8" % [id, extent.x, extent.y]
						)
						print(
							"RETAINED_DAYLIGHT_HISTORICAL label=",
							historical_label,
							" actual_camera=",
							lab._camera.global_transform,
							" ball=",
							ball.position,
							" actor_span=",
							_actor_span(lab, ball),
							" physical_proof=",
							proof
						)
						contrast_min = minf(
							contrast_min, await _contrast(lab, ball, historical_label)
						)
					if not proof.foreground.is_empty():
						var key: String = (
							"%d-%d-%s" % [int(left), int(defense), str(proof.foreground)]
						)
						if not captures.has(key):
							captures[key] = true
							var label: String = (
								"%s-%dx%d-h%d-role%d-foreground%d"
								% [id, extent.x, extent.y, int(left), int(defense), captures.size()]
							)
							contrast_min = minf(contrast_min, await _contrast(lab, ball, label))
							print(
								"RETAINED_DAYLIGHT_FOREGROUND id=",
								id,
								" label=",
								label,
								" endpoint=",
								endpoint,
								" frame=",
								frame,
								" proof=",
								proof
							)
				var label: String = (
					"%s-%dx%d-h%d-role%d-end%s"
					% [id, extent.x, extent.y, int(left), int(defense), str(requested)]
				)
				if id == "AE-01" and extent.x == 700 and requested.y >= 7:
					contrast_min = minf(contrast_min, await _scale_diagnostic(lab, ball, label))
				else:
					contrast_min = minf(contrast_min, await _contrast(lab, ball, label))
			var strongest_label: String = (
				"%s-%dx%d-h%d-role%d-actor-only-strongest"
				% [id, extent.x, extent.y, int(left), int(defense)]
			)
			if strongest.is_empty():
				print(
					"RETAINED_DAYLIGHT_STRONGEST label=",
					strongest_label,
					" positive_span_found=false"
				)
			else:
				contrast_min = minf(
					contrast_min, await _replay_sample(lab, ball, strongest, strongest_label)
				)
			_check(
				Freeze.unlock(lab, role_lock),
				"role unlock restores flags and tweens with real physics membership and ray/sphere controls"
			)
	print(
		"RETAINED_DAYLIGHT_ACTOR_COVERAGE id=",
		id,
		" extent=",
		extent,
		" counts_by_hand_role=",
		actor_counts,
		" captured_groups=",
		actor_captures.keys()
	)
	print(
		"RETAINED_DAYLIGHT_TRACKING id=",
		id,
		" extent=",
		extent,
		" fps=",
		FPS,
		" counts=",
		counts,
		" contrast_min=",
		contrast_min,
		" foreground_pairs=",
		captures.size()
	)
	_check(
		(
			counts.samples == 7680
			and counts.opaque == 0
			and counts.near == 0
			and counts.outside == 0
			and counts.footprint_outside == 0
		),
		"all physical live rays clear after authentic receiver policy, with safe framing"
	)
	if property.receiver != null:
		_check(
			counts.foreground > 0 and not captures.is_empty(),
			"real receiver foreground contrast covered"
		)
	lab._ball_play_resolver.state = prior_state
	lab._ball_play_resolver.field = prior_field
	lab._batted_ball = null
	_refresh(lab)
	ball.queue_free()
	await get_tree().process_frame


func _contrast(
	lab: PitchBatLab, ball: BattedBallBody, label: String, qualifying: bool = true
) -> float:
	var actor_triangles: int = _actor_hits(lab, ball)
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	var old_cutaway_frozen: bool = property.actor_cutaway.frozen
	property.actor_cutaway.frozen = true
	var rim: Dictionary = _rim_proof(lab, ball)
	if rim.review_required:
		push_warning(
			(
				"RETAINED_DAYLIGHT sampled footprint needs review: "
				+ label
				+ " unexcepted="
				+ str(rim.unexcepted_opaque)
			)
		)
		print("RETAINED_DAYLIGHT_FOOTPRINT_REVIEW_REQUIRED label=", label, " proof=", rim)
	var original_visible: bool = ball.visible
	var state: Dictionary = Freeze.lock(lab)
	_check(
		Freeze.intact(lab, state),
		"nested lock preserves actual physics membership and opaque ray/sphere controls"
	)
	var before: Dictionary = Freeze.snapshot(lab, ball)
	_check(
		before.unsupported.is_empty(),
		"whole-lab capture supports every rendered source: " + str(before.unsupported)
	)
	if not before.unsupported.is_empty():
		_check(Freeze.unlock(lab, state), "unsupported capture restores processing state")
		property.actor_cutaway.frozen = old_cutaway_frozen
		return 0
	ball.visible = true
	await RenderingServer.frame_post_draw
	var shown: Image = get_viewport().get_texture().get_image()
	if shown != null and not shown.is_empty():
		var pixel_proof: Dictionary = Proof.native_pixel_proof(lab, shown.get_size())
		var verified: bool = (
			pixel_proof.helper_extent_matches_image
			and pixel_proof.helper_logical_matches_viewport
			and pixel_proof.helper_diameter_matches_measured
			and pixel_proof.actual_three_pixel_floor
		)
		if qualifying:
			_check(
				verified,
				"runtime native pixel units and strict3px floor independently match actual Image readback"
			)
		print(
			"RETAINED_DAYLIGHT_NATIVE_PIXEL_PROOF label=",
			label,
			" qualifying=",
			qualifying,
			" verified=",
			verified,
			" proof=",
			pixel_proof
		)
	else:
		_check(false, "first actual native readback exists before any pixel-size claim")
	print(
		"RETAINED_DAYLIGHT_PRESENTATION label=",
		label,
		" qualifying=",
		qualifying,
		" readability=",
		property.ball_readability.diagnostics(),
		" footprint=",
		_footprint(lab, ball),
		" rim_queries=",
		rim,
		" actual_actor_hits=",
		property.actor_cutaway.last_hits
	)
	_check(
		Freeze.intact(lab, state), "visible readback freezes all subtree processes and all tweens"
	)
	_check(
		Freeze.snapshot(lab, ball) == before,
		"visible readback preserves complete rendered lab snapshot"
	)
	ball.visible = false
	await RenderingServer.frame_post_draw
	var hidden: Image = get_viewport().get_texture().get_image()
	_check(
		Freeze.intact(lab, state), "hidden readback freezes all subtree processes and all tweens"
	)
	_check(
		Freeze.snapshot(lab, ball) == before,
		"hidden readback preserves complete rendered lab snapshot"
	)
	await RenderingServer.frame_post_draw
	var hidden_control: Image = get_viewport().get_texture().get_image()
	_check(Freeze.intact(lab, state), "hidden-control readback retains whole-lab capture lock")
	_check(
		Freeze.snapshot(lab, ball) == before, "hidden-control preserves complete rendered snapshot"
	)
	ball.visible = original_visible
	property.actor_cutaway.frozen = old_cutaway_frozen
	_check(
		Freeze.unlock(lab, state),
		"readback restores callback flags, tweens, tree pause and real physics membership"
	)
	_check(
		Freeze.snapshot(lab, ball) == before,
		"restoring process modes does not change rendered state"
	)
	if (
		shown == null
		or hidden == null
		or hidden_control == null
		or shown.is_empty()
		or hidden.is_empty()
		or hidden_control.is_empty()
	):
		_check(false, "native contrast images exist")
		return 0
	var stationary: bool = hidden.get_data() == hidden_control.get_data()
	_check(stationary, "hidden/hidden full-frame negative excludes untracked renderer motion")
	print(
		"RETAINED_DAYLIGHT_STATIONARY label=",
		label,
		" hidden_frames_identical=",
		stationary,
		" snapshot_bytes=",
		before.bytes.size(),
		" rendered_nodes=",
		before.nodes
	)
	var expected: Vector2i = _native._expected_content_size(get_window().size)
	_check(
		(
			shown.get_size() == expected
			and hidden.get_size() == expected
			and hidden_control.get_size() == expected
		),
		"all three contrast Images match acknowledged content extent"
	)
	if qualifying:
		_check(
			(
				(
					property.ball_readability.diagnostics().get("native_size", Vector2.ZERO)
					== Vector2(hidden.get_size())
				)
				and (
					property.ball_readability.diagnostics().get("native_size", Vector2.ZERO)
					== Vector2(hidden_control.get_size())
				)
			),
			"runtime native extent also equals both actual hidden readbacks"
		)
	var logical: Vector2 = lab._camera.unproject_position(ball.global_position)
	var screen: Vector2i = Vector2i(
		logical * Vector2(shown.get_size()) / get_viewport().get_visible_rect().size
	)
	var difference: float = 0
	for x in range(maxi(0, screen.x - 5), mini(shown.get_width(), screen.x + 6)):
		for y in range(maxi(0, screen.y - 5), mini(shown.get_height(), screen.y + 6)):
			var a: Color = shown.get_pixel(x, y)
			var b: Color = hidden.get_pixel(x, y)
			difference = maxf(difference, Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length())
	print(
		"RETAINED_DAYLIGHT_CONTRAST label=",
		label,
		" value=",
		difference,
		" actor_triangle_hits=",
		actor_triangles,
		" camera=",
		lab._camera.global_transform,
		" ball=",
		ball.global_position
	)
	if qualifying:
		_check(difference >= 0.03, "authentic rendered ball contrast, including actor occlusion")
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	_check(
		shown.save_png(_capture_dir.path_join(label + "-visible.png")) == OK,
		"visible evidence saved"
	)
	_check(
		hidden.save_png(_capture_dir.path_join(label + "-hidden.png")) == OK,
		"hidden evidence saved"
	)
	_check(
		hidden_control.save_png(_capture_dir.path_join(label + "-hidden-control.png")) == OK,
		"stationary hidden-control evidence saved"
	)
	return difference


func _actor_hits(lab: PitchBatLab, ball: BattedBallBody) -> int:
	return _actor_span(lab, ball).hits


func _actor_span(lab: PitchBatLab, ball: BattedBallBody) -> Dictionary:
	var count: int = 0
	var intervals: Array[Vector2] = []
	var unpaired: int = 0
	var mesh_paths: Array[String] = []
	for mesh: MeshInstance3D in _actor_meshes:
		if not is_instance_valid(mesh) or mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var inverse: Transform3D = mesh.global_transform.affine_inverse()
		var from: Vector3 = inverse * lab._camera.global_position
		var to: Vector3 = inverse * ball.global_position
		if mesh.get_aabb().intersects_segment(from, to) == null:
			continue
		var identity: int = mesh.mesh.get_instance_id()
		if not _actor_faces.has(identity):
			_actor_faces[identity] = mesh.mesh.get_faces()
		var faces: PackedVector3Array = _actor_faces[identity]
		var distances: Array[float] = []
		for index in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(
				from, to, faces[index], faces[index + 1], faces[index + 2]
			)
			if hit != null:
				count += 1
				distances.append(
					lab._camera.global_position.distance_to(mesh.global_transform * hit)
				)
		if not distances.is_empty():
			mesh_paths.append(str(mesh.get_path()))
		distances.sort()
		var unique: Array[float] = []
		for distance: float in distances:
			if unique.is_empty() or distance - unique.back() > 0.000001:
				unique.append(distance)
		# Closed entry/exit pairs establish occupied depth. Tangencies/unpaired hits
		# remain logged but never manufacture a positive occlusion interval.
		if unique.size() % 2 != 0:
			unpaired += 1
			continue
		for index in range(0, unique.size(), 2):
			intervals.append(Vector2(unique[index], unique[index + 1]))
	intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var merged: Array[Vector2] = []
	for interval: Vector2 in intervals:
		if merged.is_empty() or interval.x > merged.back().y:
			merged.append(interval)
		else:
			merged[-1].y = maxf(merged.back().y, interval.y)
	var depth: float = 0
	for interval: Vector2 in merged:
		depth += interval.y - interval.x
	return {
		"hits": count,
		"depth": depth,
		"intervals_m": merged,
		"unpaired_meshes": unpaired,
		"mesh_paths": mesh_paths
	}


func _sample(lab: PitchBatLab, ball: BattedBallBody) -> Dictionary:
	return {
		"camera_local": lab._camera.transform,
		"camera_global": lab._camera.global_transform,
		"parent_global": lab._camera.get_parent_node_3d().global_transform,
		"fov": lab._camera.fov,
		"ball_local": ball.transform,
		"snapshot": Freeze.snapshot(lab, ball),
		"readability":
		(
			(lab.get_meta("stadium_property") as StadiumNpcRetainedProperty)
			. ball_readability
			. diagnostics()
		),
		"capture_context": _capture_context.duplicate(true),
		"cutaway_hits":
		(
			(lab.get_meta("stadium_property") as StadiumNpcRetainedProperty)
			. actor_cutaway
			. last_hits
			. duplicate(true)
		)
	}


func _restore_sample(lab: PitchBatLab, ball: BattedBallBody, saved: Dictionary) -> bool:
	if lab._camera.get_parent_node_3d().global_transform != saved.parent_global:
		return false
	_capture_context = saved.capture_context.duplicate(true)
	lab._camera.transform = saved.camera_local
	lab._camera.fov = saved.fov
	ball.transform = saved.ball_local
	lab._camera.force_update_transform()
	ball.force_update_transform()
	_refresh(lab, true)
	return (
		lab._camera.transform == saved.camera_local
		and lab._camera.global_transform == saved.camera_global
		and ball.transform == saved.ball_local
		and _capture_context == saved.capture_context
		and Freeze.snapshot(lab, ball) == saved.snapshot
		and (
			(
				(lab.get_meta("stadium_property") as StadiumNpcRetainedProperty)
				. ball_readability
				. diagnostics()
			)
			== saved.readability
		)
		and (
			(lab.get_meta("stadium_property") as StadiumNpcRetainedProperty).actor_cutaway.last_hits
			== saved.cutaway_hits
		)
	)


func _replay_sample(
	lab: PitchBatLab, ball: BattedBallBody, saved: Dictionary, label: String
) -> float:
	var original: Dictionary = _sample(lab, ball)
	var exact: bool = _restore_sample(lab, ball, saved)
	_check(exact, "strongest replay exactly reproduces recorded entire rendered presentation")
	var contrast: float = 0
	if exact:
		_check(
			_actor_span(lab, ball) == saved.span, "strongest replay retains measured triangle depth"
		)
		print(
			"RETAINED_DAYLIGHT_STRONGEST label=",
			label,
			" frame=",
			saved.frame,
			" requested=",
			saved.requested,
			" span=",
			saved.span,
			" exact_snapshot=",
			exact
		)
		contrast = await _contrast(lab, ball, label)
	_check(
		_restore_sample(lab, ball, original),
		"strongest replay restores exact original local/global view and presentation"
	)
	return contrast


func _refresh(lab: PitchBatLab, force_visible: bool = false) -> void:
	var before: Dictionary = Proof.mechanics(lab)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab, force_visible)
	_check(
		Proof.mechanics(lab) == before,
		"runtime readability/cutaway preserves exact body, shape, radius, velocity and resolver state"
	)


func _footprint(lab: PitchBatLab, ball: BattedBallBody) -> Dictionary:
	var mesh: MeshInstance3D = Proof.ball_visual(ball)
	var sphere: SphereMesh = mesh.mesh
	var radius: float = (
		maxf(sphere.radius, sphere.height * 0.5)
		* maxf(
			mesh.global_basis.x.length(),
			maxf(mesh.global_basis.y.length(), mesh.global_basis.z.length())
		)
	)
	var center: Vector3 = mesh.global_position
	var camera: Camera3D = lab._camera
	var distance: float = camera.global_position.distance_to(center)
	var points: Array[Vector3] = []
	if distance <= radius:
		return {"framed": false, "effective_radius": radius, "rim_points": points}
	var axis: Vector3 = (center - camera.global_position) / distance
	var right: Vector3 = axis.cross(camera.global_basis.y).normalized()
	var up: Vector3 = right.cross(axis).normalized()
	var rim_center: Vector3 = center - axis * radius * radius / distance
	var rim_radius: float = radius * sqrt(1.0 - radius * radius / (distance * distance))
	var viewport: Rect2 = camera.get_viewport().get_visible_rect()
	var frame: Rect2 = viewport.grow(-24)
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	var depth: float = -camera.to_local(center).z
	var framed: bool = depth - radius > camera.near and depth + radius < camera.far
	for index in range(16):
		var angle: float = TAU * index / 16.0
		var point: Vector3 = rim_center + rim_radius * (right * cos(angle) + up * sin(angle))
		points.append(point)
		var screen: Vector2 = camera.unproject_position(point)
		minimum = minimum.min(screen)
		maximum = maximum.max(screen)
		framed = framed and not camera.is_position_behind(point) and frame.has_point(screen)
	var native: Vector2 = Vector2(_native._expected_content_size(get_window().size))
	return {
		"framed": framed,
		"effective_radius": radius,
		"projected_diameter_px": (maximum - minimum) * native / viewport.size,
		"fov": camera.fov,
		"near": camera.near,
		"far": camera.far,
		"rim_points": points
	}


func _rim_proof(lab: PitchBatLab, ball: BattedBallBody) -> Dictionary:
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	var footprint: Dictionary = _footprint(lab, ball)
	var endpoint_reached: bool = _capture_context.get("endpoint_reached", false)
	var physical_stop: bool = _capture_context.get("physical_contact_stop", false)
	var contact_bodies: Array[String] = []
	if endpoint_reached and physical_stop:
		# Match the opaque body against a real overlap of the UNCHANGED ball collider.
		# A stop event alone cannot excuse some other stand, pole, roof or receiver.
		for shape: CollisionShape3D in ball.find_children("*", "CollisionShape3D", true, false):
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = shape.shape
			query.transform = shape.global_transform
			query.margin = 0
			query.collision_mask = Proof.MASK
			for hit: Dictionary in lab.get_world_3d().direct_space_state.intersect_shape(query, 64):
				if property.is_ancestor_of(hit.collider):
					contact_bodies.append(String(property.get_path_to(hit.collider)))
	var opaque: Array = []
	var foreground: int = 0
	var clear: int = 0
	var unexcepted: int = 0
	for index in range(footprint.rim_points.size()):
		var ray: Dictionary = Proof.trace(
			property, lab._camera.global_position, footprint.rim_points[index]
		)
		clear += int(ray.clear)
		foreground += int(not ray.foreground.is_empty())
		if not ray.clear:
			var classification: String = "precontact-opaque-footprint"
			if endpoint_reached:
				classification = "endpoint-unmatched-opaque-footprint"
				if physical_stop and contact_bodies.has(ray.opaque):
					classification = "contact-endpoint-same-physical-body-overlap"
			unexcepted += int(classification != "contact-endpoint-same-physical-body-overlap")
			opaque.append(
				{
					"index": index,
					"opaque": ray.opaque,
					"point": footprint.rim_points[index],
					"classification": classification
				}
			)
	# These sampled silhouette rays are diagnostic, never blanket terminal allowances.
	# Centre LOS and native contrast remain hard gates. Unmatched/precontact hits
	# are actionable findings for root's review, including float-uncertain contact.
	return {
		"sampled": footprint.rim_points.size(),
		"clear": clear,
		"receiver_foreground": foreground,
		"opaque": opaque,
		"unexcepted_opaque": unexcepted,
		"review_required": unexcepted > 0,
		"context": _capture_context.duplicate(true),
		"actual_collider_overlap_bodies": contact_bodies
	}


func _scale_diagnostic(lab: PitchBatLab, ball: BattedBallBody, label: String) -> float:
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	var saved: Dictionary = _sample(lab, ball)
	var mechanics: Dictionary = Proof.mechanics(lab)
	var actors: Array = Proof.presentation(lab)
	var visual: MeshInstance3D = Proof.ball_visual(ball)
	var floor_transform: Transform3D = visual.transform
	property.ball_readability.restore_all()
	var baseline_transform: Transform3D = visual.transform
	_check(
		Proof.mechanics(lab) == mechanics and Proof.presentation(lab) == actors,
		"scale-only baseline preserves mechanics and every actor/receiver presentation"
	)
	var baseline: float = await _contrast(lab, ball, label + "-scale-baseline-diagnostic", false)
	property.ball_readability.update(ball, lab._camera, lab._ball_in_play_is_live())
	_check(
		visual.transform == floor_transform and Freeze.snapshot(lab, ball) == saved.snapshot,
		"genuine runtime floor exactly restores prediagnostic mesh/render state"
	)
	_check(
		property.ball_readability.diagnostics() == saved.readability,
		"genuine runtime floor restores original readability derivation"
	)
	_check(
		Proof.mechanics(lab) == mechanics and Proof.presentation(lab) == actors,
		"scale-only runtime floor preserves exact mechanics and actor policy"
	)
	var qualifying: float = await _contrast(lab, ball, label + "-runtime-floor-qualifying")
	print(
		"RETAINED_DAYLIGHT_SCALE_AB label=",
		label,
		" baseline_transform=",
		baseline_transform,
		" runtime_transform=",
		floor_transform,
		" diagnostic_baseline_contrast=",
		baseline,
		" qualifying_runtime_contrast=",
		qualifying,
		" policy=",
		property.ball_readability.diagnostics()
	)
	return qualifying


func _near_clear(camera: Camera3D) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = StadiumExpandedCameraDirector.near_enclosure(camera)
	query.collision_mask = Proof.MASK
	query.transform.origin = camera.global_position
	return camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _shot(label: String) -> void:
	_check(await _native.capture(_capture_dir, label), "native capture handshake and saved PNG")


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error("RETAINED_DAYLIGHT: " + description)
