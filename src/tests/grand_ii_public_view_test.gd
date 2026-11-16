extends Node3D
## One real neutral-final installation, fourteen primary views, four real launched live samples.
## Fixed artistic19:10 clear only. No private historical tracking or completed-game credit.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const FIXTURE = preload("res://src/tests/grand_ii_public_fixture.gd")
const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
const Freeze = preload("res://src/tests/stadium_long_yard_capture_freeze.gd")
const Archive = preload("res://src/tests/stadium_long_yard_history_archive.gd")
const PREFIX: String = "npc:GRAND-II:r1:"
var _checks: int = 0
var _failures: int = 0
var _captures: int = 0
var _families: int = 0
var _pairs: int = 0
var _launches: int = 0
var _capture_dir: String = ""
var _native: Node
var _first_case: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--grand-ii-first-case":
			_first_case = true
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(DisplayServer.get_name() != "headless" and not _capture_dir.is_empty(),
		"fixed-profile view qualification requires actual display and capture directory")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native startup handshake has no hidden failure")
	if _failures == 0:
		await _views()
	await TestAudioDrain.finish(get_tree())
	var expected_captures: int = 3 if _first_case else 14
	var expected_live: int = 1 if _first_case else 4
	_check(_captures == expected_captures and _pairs == expected_live and _launches == expected_live,
		"exact selected primary views and paired genuine-launch readbacks are present")
	print("GRAND_II_INSTALLED_VIEWS_SCOPE first_case=%s" % _first_case)
	print("GRAND_II_INSTALLED_VIEWS_RESULT checks=%d failures=%d families=%d captures=%d pairs=%d" %
		[_checks, _failures, _families, _captures, _pairs])
	get_tree().quit(0 if _failures == 0 else 1)


func _views() -> void:
	var prepared: SeasonState = FIXTURE.season()
	_check(prepared != null, "real drafted qualification season exists")
	if prepared == null:
		return
	var saved: Dictionary = SeasonSave.snapshot(prepared)
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(
		JSON.stringify(saved, "", true, true)))
	_check(season != null and ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"views start from exact restored save64 before test-only participant fixture")
	if season == null:
		return
	var fixture: Dictionary = FIXTURE.fixture(season)
	var before: Dictionary = SeasonSave.snapshot(season)
	var prior_msaa: int = get_viewport().msaa_3d
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = SeasonPhysicalFixtures.match_for(season, fixture)
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	lab._player_home = fixture.home == 0
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var property: StadiumNpcPublicProperty = R._property(lab)
	_check(not lab.yard_bound_startup_failed and property != null
		and R.installed_bound(lab, lab._match_state.stadium), "actual public fixed neutral startup")
	if property == null or lab.yard_bound_startup_failed:
		lab.queue_free()
		await get_tree().process_frame
		return
	var lease: Dictionary = property.environment_lease
	_check(property.objects.size() == 85 and property.venue_id == "GRAND-II"
		and get_viewport().msaa_3d >= Viewport.MSAA_4X
		and StadiumGrandIIEnvironmentV1.installed(lab, lease)
		and property.find_children("*", "SpotLight3D", true, false).size() == 6
		and lease.active_lighting.heads.size() == 24,
		"all85 copies, all24 authored heads and exact six-emitter artistic dusk renderer")
	_check(lab._match_state.stadium.environment.render_profile == 2
		and is_equal_approx(lease.applied_environment.ambient_light_energy, 0.65)
		and lease.active_lighting.root.get_child_count() == 30,
		"saved render revision2 owns restrained ambient and six lights plus24 luminous faces")
	for row: Dictionary in lease.active_lighting.heads:
		_check(row.lens.material_override == row.lens_material
			and row.lens_material.albedo_color == row.lens_albedo
			and is_instance_valid(row.glow) and row.glow.get_parent() == lease.active_lighting.root
			and row.glow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"owned luminous face preserves original material and adds no caster")
	var shadow_count: int = 0
	for row: Dictionary in lease.active_lighting.lights:
		shadow_count += int(row.node.shadow_enabled)
	_check(shadow_count == 4 and not lease.sun.shadow_enabled,
		"exact four-shadow positional budget and no dusk directional caster")
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab._at_bat_cadence.stop()
	lab._batter_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(700, 400)]
	var hands: Array[bool] = [false, true]
	if _first_case:
		sizes.resize(1)
		hands.resize(1)
	for size: Vector2i in sizes:
		_check(await _native.resize(size), "original normal/small native window acknowledged")
		for left: bool in hands:
			for role: String in ["batting", "pitching"]:
				_role(lab, left, role == "pitching")
				_check(_near_clear(lab._camera), "authored role camera near volume clears actual geometry")
				_check(not lab._camera.is_position_behind(Vector3(0, 1, 0)),
					"actual receiver/plate corridor remains in front")
				await _shot("grand-ii-%dx%d-hand%d-%s" % [size.x, size.y, int(left), role])
			await _live(lab, property, left, size)
		if not _first_case:
			await _overview(lab, property, size)
		_check(StadiumGrandIIEnvironmentV1.installed(lab, lease),
			"native size/role/live captures preserve exact installed rendering profile")
	_check(R.installed_bound(lab, lab._match_state.stadium)
		and ClubCareer.same(before, SeasonSave.snapshot(season))
		and lab._throw_number == 0 and lab._play_records.is_empty()
		and PhysicalMatchReport.capture(lab).is_empty(),
		"bounded views preserve saved state and manufacture no completed report")
	if _failures == 0:
		_families = 1
		print(("GRAND_II_INSTALLED_VIEWS id=%s fixture=%d owner=%s batting_home=%d away=%d "
			+ "objects=%d captures=%d pairs=%d mode=%s profile=%s time=%s weather=%s") % [
			property.venue_id, fixture.id, lab._match_state.stadium.binding.venue_owner,
			fixture.home, fixture.away, property.objects.size(), _captures, _pairs,
			lab._match_state.stadium.environment.mode, lab._match_state.stadium.environment.profile,
			lab._match_state.stadium.environment.time, lab._match_state.stadium.environment.weather])
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	lab._at_bat_cadence.stop()
	var world: WorldEnvironment = lab._world_environment
	var sun: DirectionalLight3D = lease.sun
	# Teardown clears the live lease; retain shallow same-origin restoration preimages.
	var environment_before: Dictionary = lease.duplicate(false)
	var lighting_before: Dictionary = lease.active_lighting.duplicate(false)
	var atlas_before: Dictionary = lighting_before.before.duplicate(true)
	_check(R.teardown(lab), "idle rendered owner releases through actual public teardown")
	_check(lease.is_empty() and world.environment == environment_before.before_environment
		and sun.rotation == environment_before.before_rotation
		and sun.light_color == environment_before.before_color
		and sun.light_energy == environment_before.before_energy
		and sun.shadow_enabled == environment_before.before_shadows,
		"rendered teardown restores exact same-origin prior environment and sun")
	_check(get_viewport().positional_shadow_atlas_size == atlas_before.size
		and get_viewport().positional_shadow_atlas_16_bits == atlas_before.precision
		and lab.find_children("*", "SpotLight3D", true, false).is_empty(),
		"rendered teardown removes six emitters and restores prior shadow allocation")
	for row: Dictionary in lighting_before.heads:
		_check(not is_instance_valid(row.glow)
			and row.lens_material.albedo_color == row.lens_albedo,
			"teardown removes owned luminous face and preserves original material bytes")
	for index in range(4):
		_check(get_viewport().get_positional_shadow_atlas_quadrant_subdiv(index)
			== atlas_before.quadrants[index], "prior shadow quadrant restored")
	await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	_check(get_viewport().msaa_3d == prior_msaa, "last rendered owner restores exact original MSAA")


func _role(lab: PitchBatLab, left: bool, defense: bool) -> void:
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	lab._match_state.top_half = lab._player_home if defense else not lab._player_home
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
		else PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	PitchBatLabPresentation.apply_role_camera(lab)
	lab._camera_director.set_batter_handedness(left)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING if defense \
		else MatchCameraDirector.Shot.BATTING)
	lab._camera_director.snap(lab._camera)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	_check(lab._player_is_pitching() == defense and lab._player_is_batting() != defense,
		"normal role presenter supplies real pitching/batting half")
	if not defense:
		_check(lab._camera.global_position.is_equal_approx(
			Vector3(-0.18 if left else 0.18, 2.10, -3.38))
			and lab._camera.fov == 75.0,
			"original Grand Club batting entry is acquired before contact with original optics")


func _live(lab: PitchBatLab, property: StadiumNpcPublicProperty,
	left: bool, size: Vector2i) -> void:
	_role(lab, left, true)
	var entry: Transform3D = lab._camera.global_transform
	var entry_fov: float = lab._camera.fov
	_check(lab._match_state.begin_pitch(), "real live sample begins from genuine pitch state")
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 1.1, 0.2)
	launch.velocity = Vector3(0, 10, 35)
	# Match the retained source-history recipe: create in the pre-physics phase,
	# through the ordinary controller, with its configured aero and public router.
	await get_tree().physics_frame
	var launch_tick: int = Engine.get_physics_frames()
	lab._start_ball_in_play(launch)
	var ball: BattedBallBody = lab._batted_ball
	_check(is_instance_valid(ball), "ordinary controller created the actual live ball")
	if not is_instance_valid(ball):
		return
	var setup: BallSetupDefinition = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID)
	_check(not ball.freeze and ball._started and ball.physics_contact_router.is_valid()
		and R._ball_wiring(property, ball, lab._ball_play_resolver)
		and lab._match_state.phase == MatchState.Phase.BALL_IN_PLAY
		and lab._camera_director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY
		and lab._camera_director._live_coverage._defense
		and lab._camera.global_transform == entry and lab._camera.fov == entry_fov,
		"real launch owns routed physics and retains acquired defense entry without a contact cut")
	_check(ball.aero_drag_coefficient == setup.aero_profile.drag_coefficient * setup.drag_multiplier
		and ball.aero_magnus_scale == setup.aero_profile.magnus_scale * setup.magnus_multiplier
		and ball.aero_perforation_force_scale
			== setup.aero_profile.perforation_force_scale * setup.perforation_multiplier,
		"live sample keeps exact ordinary fresh-ball aerodynamic configuration")
	_launches += 1
	var swing: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	PitchBatLabPresentation.play_batter_swing(lab, swing)
	lab._batter_avatar._process(swing.sweet_spot_seconds)
	lab._bat_actor._process(swing.sweet_spot_seconds)
	lab._process(0)
	_check(lab._camera.global_transform == entry and lab._camera.fov == entry_fov,
		"zero-elapsed real presentation retains acquired contact view")
	var outside: int = 0
	var blocked: int = 0
	var overlap: int = 0
	var max_step: float = 0
	var max_turn: float = 0
	var sampled: int = 0
	# The prior zero-aero shortcut reached20m in40 ticks. Keep that minimum window,
	# then observe every real tick to the same depth, within the retained720-tick bound.
	for tick: int in range(720):
		await get_tree().physics_frame
		_check(Engine.physics_ticks_per_second == 60
			and Engine.get_physics_frames() == launch_tick + tick + 1,
			"real launched sample retains each consecutive ordinary60Hz physics tick")
		var pose: Transform3D = lab._camera.global_transform
		lab._physics_process(1.0 / 60.0)
		lab._batter_avatar._process(1.0 / 60.0)
		lab._bat_actor._process(1.0 / 60.0)
		lab._process(1.0 / 60.0)
		max_step = maxf(max_step, pose.origin.distance_to(lab._camera.global_position))
		max_turn = maxf(max_turn, pose.basis.get_rotation_quaternion().angle_to(
			lab._camera.global_basis.get_rotation_quaternion()))
		outside += int(lab._camera.is_position_behind(ball.global_position) or not
			get_viewport().get_visible_rect().grow(-24).has_point(
				lab._camera.unproject_position(ball.global_position)))
		blocked += int(lab._camera_director.tracking_visibility.actual_blocked(
			lab._camera.global_position, ball.global_position))
		overlap += int(not _near_clear(lab._camera))
		sampled = tick + 1
		if lab._ball_play_resolver.state.dead or property.suspended:
			break
		if sampled >= 40 and ball.global_position.z > 20:
			break
	print(("GRAND_II_LIVE_CONTROLLER size=%dx%d hand=%d ticks=%d hz=%d "
		+ "aero=%s ball=%s projected=%s dead=%s suspended=%s") % [
		size.x, size.y, int(left), sampled, Engine.physics_ticks_per_second,
		Vector3(ball.aero_drag_coefficient, ball.aero_magnus_scale,
			ball.aero_perforation_force_scale), ball.global_position,
		lab._camera.unproject_position(ball.global_position),
		lab._ball_play_resolver.state.dead, property.suspended])
	print(("GRAND_II_LIVE_TRACKING outside=%d blocked=%d overlap=%d "
		+ "max_step=%.9f max_turn=%.9f") % [outside, blocked, overlap, max_step, max_turn])
	_check(sampled >= 40 and ball.global_position.z > 20
		and not lab._ball_play_resolver.state.dead and not property.suspended
		and outside == 0 and blocked == 0 and overlap == 0
		and max_step < 32.1 / 60.0 and max_turn < 1.7 / 60.0,
		"actual launched straight-field follow retains original framing/LOS/near/motion thresholds")
	# Freeze only the captured genuine physics sample; never seed a frozen contact experiment.
	ball.freeze = true
	await _pair(lab, ball, "grand-ii-%dx%d-hand%d-live-straight-field" %
		[size.x, size.y, int(left)])
	lab._cleanup_batted_ball()
	lab._at_bat_cadence.stop()
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	property.restore_presentations()
	await get_tree().process_frame


func _pair(lab: PitchBatLab, ball: BattedBallBody, label: String) -> void:
	# Reuse the retained generic full-render snapshot and callback/tween primitives.
	# The old private physics_proof cast is intentionally not used by this public fixture.
	var lock: Dictionary = _capture_lock(lab)
	var before: Dictionary = _render_snapshot(lab, ball)
	_check(before.unsupported.is_empty() and _physics_present(lab),
		"paired readback preserves real physics membership and all supported render sources")
	ball.visible = true
	await _pair_settle(lab, ball, "shown")
	var shown: Image = get_viewport().get_texture().get_image()
	_check(_render_snapshot(lab, ball) == before, "shown frame has exact same-origin render state")
	ball.visible = false
	await _pair_settle(lab, ball, "hidden")
	var hidden: Image = get_viewport().get_texture().get_image()
	await RenderingServer.frame_post_draw
	var control: Image = get_viewport().get_texture().get_image()
	_check(_render_snapshot(lab, ball) == before and _physics_present(lab),
		"hidden frames preserve exact render state and attached native bodies")
	ball.visible = true
	_check(_capture_unlock(lab, lock) and _render_snapshot(lab, ball) == before,
		"paired capture restores exact callback/tween/pause state")
	var expected: Vector2i = _native._expected_content_size(get_window().size)
	_check(shown != null and hidden != null and control != null
		and shown.get_size() == expected and hidden.get_size() == expected
		and control.get_size() == expected, "three real readbacks have actual acknowledged content size")
	if shown == null or hidden == null or control == null:
		return
	_check(hidden.get_data() == control.get_data(), "hidden/hidden negative excludes renderer motion")
	var logical: Vector2 = lab._camera.unproject_position(ball.global_position)
	var point: Vector2i = Vector2i(logical * Vector2(expected)
		/ get_viewport().get_visible_rect().size)
	var contrast: float = 0
	for x: int in range(maxi(0, point.x - 5), mini(shown.get_width(), point.x + 6)):
		for y: int in range(maxi(0, point.y - 5), mini(shown.get_height(), point.y + 6)):
			var a: Color = shown.get_pixel(x, y)
			var b: Color = hidden.get_pixel(x, y)
			contrast = maxf(contrast, Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length())
	_check(contrast >= 0.03, "unchanged11x11 native live-ball contrast minimum0.03")
	var paths: Array[String] = []
	for index: int in range(3):
		var suffix: String = ["", "-hidden", "-hidden-control"][index]
		var path: String = _capture_dir.path_join("%s%s-%dx%d.png" %
			[label, suffix, expected.x, expected.y])
		_check([shown, hidden, control][index].save_png(path) == OK, "paired native image saved")
		paths.append(path)
	var receipt: Dictionary = {"schema": "GRAND-II-FIXED-LIVE-PAIR-v1", "label": label,
		"profile": "GRAND-II-1910-CLEAR-v1", "time": "19:10", "weather": "clear",
		"render_profile": lab._match_state.stadium.environment.render_profile,
		"ambient_energy": lab._world_environment.environment.ambient_light_energy,
		"content": [expected.x, expected.y], "projected_pixel": [point.x, point.y],
		"contrast": contrast, "atlas": _atlas_snapshot(),
		"lighting_contract": StadiumGrandIILightingV1.contract(),
		"hidden_identical": hidden.get_data() == control.get_data(),
		"render_sha256": Archive._sha256(before.bytes),
		"images": paths, "image_sha256": paths.map(
			func(path: String) -> String: return FileAccess.get_sha256(path))}
	var file: FileAccess = FileAccess.open(_capture_dir.path_join(label + ".json"), FileAccess.WRITE)
	_check(file != null, "paired fixed-profile receipt opened")
	if file != null:
		file.store_string(JSON.stringify(receipt, "", true, true))
		file.close()
	_captures += 1
	_pairs += 1
	print("GRAND_II_FIXED_CONTRAST label=%s contrast=%s content=%s" % [label, contrast, expected])


func _pair_settle(lab: PitchBatLab, ball: BattedBallBody, state: String) -> void:
	var drawn_start: int = Engine.get_frames_drawn()
	var physics_start: int = Engine.get_physics_frames()
	var started_ms: int = Time.get_ticks_msec()
	for _draw in range(3):
		await RenderingServer.frame_post_draw
	var drawn_end: int = Engine.get_frames_drawn()
	var physics_end: int = Engine.get_physics_frames()
	var elapsed_ms: int = Time.get_ticks_msec() - started_ms
	var render_sha256: String = Archive._sha256(_render_snapshot(lab, ball).bytes)
	print(("GRAND_II_PAIR_SETTLE state=%s completed_draws=3 drawn_start=%d drawn_end=%d "
		+ "physics_start=%d physics_end=%d elapsed_ms=%d paused=%s frozen=%s visible=%s "
		+ "render_sha256=%s") % [state, drawn_start, drawn_end, physics_start, physics_end,
		elapsed_ms, get_tree().paused, ball.freeze, ball.visible, render_sha256])


func _atlas_snapshot() -> Dictionary:
	var viewport: Viewport = get_viewport()
	var quadrants: Array[int] = []
	for index in range(4):
		quadrants.append(viewport.get_positional_shadow_atlas_quadrant_subdiv(index))
	return {"size": viewport.positional_shadow_atlas_size,
		"sixteen_bits": viewport.positional_shadow_atlas_16_bits, "quadrants": quadrants}


func _render_snapshot(lab: PitchBatLab, ball: BattedBallBody) -> Dictionary:
	# Retained scene snapshot is unchanged. Bind the Grand-only viewport allocation too.
	var value: Dictionary = Freeze.snapshot(lab, ball)
	value.bytes = var_to_bytes([value.bytes, _atlas_snapshot()])
	return value


func _capture_lock(lab: PitchBatLab) -> Dictionary:
	var result: Dictionary = {"paused": get_tree().paused, "nodes": [], "tweens": [],
		"tween_breach": false}
	for node: Node in Freeze._nodes(lab):
		result.nodes.append({"node": node, "flags": Freeze._flags(node), "mode": node.process_mode,
			"disable": node.disable_mode if node is CollisionObject3D else -1})
		Freeze._set_flags(node, [false, false, false, false, false, false, false, false])
	for tween: Tween in get_tree().get_processed_tweens():
		result.tweens.append({"tween": tween, "id": tween.get_instance_id(),
			"valid": tween.is_valid(), "running": tween.is_running(),
			"elapsed": tween.get_total_elapsed_time()})
		if tween.is_valid():
			tween.pause()
	get_tree().paused = true
	return result


func _capture_unlock(lab: PitchBatLab, lock: Dictionary) -> bool:
	var valid: bool = Freeze._nodes(lab).size() == lock.nodes.size()
	valid = valid and Freeze._tweens_intact(lab, lock, true)
	for row: Dictionary in lock.nodes:
		valid = valid and is_instance_valid(row.node) and row.node.process_mode == row.mode
		if row.node is CollisionObject3D:
			valid = valid and row.node.disable_mode == row.disable
		Freeze._set_flags(row.node, row.flags)
		valid = valid and Freeze._flags(row.node) == row.flags
	get_tree().paused = lock.paused
	for row: Dictionary in lock.tweens:
		valid = valid and row.tween.is_valid() == row.valid \
			and row.tween.get_total_elapsed_time() == row.elapsed
		if row.valid and row.running:
			row.tween.play()
	return valid and Freeze._tweens_intact(lab, lock, false) and _physics_present(lab)


func _physics_present(lab: PitchBatLab) -> bool:
	var count: int = 0
	for node: Node in Freeze._nodes(lab):
		if node is PhysicsBody3D:
			count += 1
			if PhysicsServer3D.body_get_space(node.get_rid()) != lab.get_world_3d().space:
				return false
	if count == 0:
		return false
	var property: StadiumNpcPublicProperty = R._property(lab)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 1.3, 4), Vector3(0, 1.3, 40), StadiumClubPropertyGeometry.CAMERA_LAYER)
	var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(query)
	if property == null or hit.is_empty() or not property.boundary.bodies.has(hit.collider):
		return false
	var sphere: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	sphere.shape = SphereShape3D.new()
	sphere.shape.radius = 0.10
	sphere.collision_mask = StadiumClubPropertyGeometry.CAMERA_LAYER
	sphere.transform.origin = hit.position
	for overlap: Dictionary in lab.get_world_3d().direct_space_state.intersect_shape(sphere, 32):
		if overlap.collider == hit.collider:
			return true
	return false


func _overview(lab: PitchBatLab, property: StadiumNpcPublicProperty, size: Vector2i) -> void:
	var camera: Camera3D = lab._camera
	var before: Transform3D = camera.global_transform
	var projection: int = camera.projection
	var old_size: float = camera.size
	var ground: AABB = StadiumProperty.ground_bounds("mogul")
	var scale_value: float = ground.size.z / 42.0
	var center: Vector3 = ground.get_center()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 50 * scale_value
	camera.global_position = center + Vector3(0, 50, -45) * scale_value
	camera.look_at(center)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab, true)
	var framing: Rect2 = get_viewport().get_visible_rect().grow(-24)
	for corner: int in range(8):
		_check(framing.has_point(camera.unproject_position(ground.get_endpoint(corner))),
			"overview frames exact complete Mogul footprint")
	for site: String in ["MLIGHT-HL", "MLIGHT-HR", "MLIGHT-ML", "MLIGHT-MR",
		"MLIGHT-OL", "MLIGHT-OR", "SCORE-SMALL"]:
		var model: Node3D = property.objects[PREFIX + site]
		for mesh: MeshInstance3D in model.get_node("Visual").find_children(
			"*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			for corner: int in range(8):
				_check(not camera.is_position_behind(bounds.get_endpoint(corner))
					and framing.has_point(camera.unproject_position(bounds.get_endpoint(corner))),
					"all six authored towers and original board remain framed " + site)
	await _shot("grand-ii-%dx%d-complete-property" % [size.x, size.y])
	camera.projection = projection as Camera3D.ProjectionType
	camera.size = old_size
	camera.global_transform = before
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)


func _near_clear(camera: Camera3D) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	var extent: Vector2 = get_viewport().get_visible_rect().size
	var radius: float = camera.near * 2
	for corner: Vector2 in [Vector2.ZERO, Vector2(extent.x, 0), extent, Vector2(0, extent.y)]:
		radius = maxf(radius, camera.global_position.distance_to(
			camera.project_position(corner, camera.near)))
	query.shape.radius = radius
	query.collision_mask = StadiumClubPropertyGeometry.CAMERA_LAYER
	query.transform.origin = camera.global_position
	return camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _shot(label: String) -> void:
	var captured: bool = await _native.capture(_capture_dir, label)
	_check(captured, "actual native capture/readback handshake succeeds")
	if captured:
		var extent: Vector2i = _native._expected_content_size(get_window().size)
		var image: Image = Image.load_from_file(_capture_dir.path_join("%s-%dx%d.png" %
			[label, extent.x, extent.y]))
		_check(image != null and image.get_size() == extent, "saved primary image has exact content size")
		_captures += 1


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("GRAND_II_INSTALLED_VIEWS " + label)
