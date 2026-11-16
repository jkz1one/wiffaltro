extends Node3D
## Private ordinary-engine contact proof. Supplied launch velocity is diagnostic input.
## Routing units are explicitly separate; no manufactured contact counts as physical proof.
# gdlint: disable=max-file-lines,max-line-length,max-returns

const FIELD: FieldDefinition = preload("res://src/content/fields/npc_venue_field.tres")
const LAB: Script = preload("res://src/labs/pitch_bat_lab/pitch_bat_lab.gd")
const BALL: Script = preload("res://src/presentation/ball/batted_ball_body.gd")
const RESOLVER: Script = preload("res://src/gameplay/ball_in_play/ball_play_resolver.gd")
const EXPECTED_CASES: int = 14
const EXPECTED_NATIVE_CHECKS: int = 99
const EXPECTED_RENDER_CHECKS: int = 25
const CAPTURE_TICKS: Array[int] = [1, 150, 300]
const PNG_CAP: int = 4 * 1024 * 1024
var _checks: int = 0
var _failures: int = 0
var _cases: int = 0
var _render_dir: String = ""
var _samples: int = 0
var _camera: Camera3D
var _draw_ticks: Array[int] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		if args.size() != 1 or not args[0].begins_with("--hillside-ground-render-dir="):
			push_error("Use no selector or exactly one --hillside-ground-render-dir selector.")
			get_tree().quit(2)
			return
		_render_dir = args[0].trim_prefix("--hillside-ground-render-dir=")
		await _run_rendered()
		return
	for profile: String in ["flat-control", "hill"]:
		var start: Vector3 = StadiumHillsideTerrain.point(0, 20, profile) + Vector3.UP
		var off: Dictionary = await _flight(profile + ":drop:off", profile, start, Vector3(0, 0, 2), 120, false)
		var on: Dictionary = await _flight(profile + ":drop:on", profile, start, Vector3(0, 0, 2), 120, true)
		_check(off.history == on.history, profile + " adapter leaves every sampled physical pose/velocity/depth exactly unchanged")
	await _flight("hill:uphill_grounder", "hill", Vector3(0, 0.10, 15), Vector3(0, 0, 5), 300, true)
	await _flight("hill:airborne", "hill", Vector3(0, 5, 20), Vector3(0, 6, 2), 30, true, false, false)
	await _flight("hill:foul-ground", "hill", Vector3(0, 1.2, 16), Vector3.ZERO, 90, true, true)
	for reversed: bool in [false, true]:
		await _batch_order(reversed)
	await _deep_batch()
	await _identity_unit()
	await _stale_unit()
	await _router_unit()
	await _terrain_context_unit()
	_check(_cases == EXPECTED_CASES, "exact seven physical and seven routing-unit cases")
	_check(_checks + 1 == EXPECTED_NATIVE_CHECKS, "exact headless assertion inventory")
	print("HILLSIDE_GROUND_CONTACT checks=%d failures=%d" % [_checks, _failures])
	print("HILLSIDE_GROUND_CASE_COUNT %d" % _cases)
	get_tree().quit(0 if _failures == 0 else 1)


func _context(profile: String, enabled: bool, boundary_enabled: bool = false) -> Dictionary:
	var terrain: Node3D = StadiumHillsideTerrainModels.create(profile)
	add_child(terrain)
	# Exact production script is attached after ready, omitting broad application startup.
	# No production method is overridden and the ordinary contact callback/resolver run.
	var host: Node3D = Node3D.new()
	add_child(host)
	host.set_script(LAB)
	var lab: PitchBatLab = host as PitchBatLab
	lab.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.set_process_input(false)
	lab.set_process_unhandled_input(false)
	lab._match_mode = false
	lab._managed_match = false
	lab._field_definition = FIELD.duplicate(true) as FieldDefinition
	PitchBatLabPresentation.build_pitch_actor(lab)
	lab._pitch_actor.set_physics_process(false)
	lab._sounds = PlaySounds.new()
	lab._sounds.muted = true
	lab.add_child(lab._sounds)
	lab._pitch_feedback = PitchFeedback.new()
	lab.add_child(lab._pitch_feedback)
	lab._ball_play_resolver = BallPlayResolver.new()
	lab._active_play_record = PlayRecord.new()
	await _barrier()
	var ctx: Dictionary = {"lab": lab, "terrain": terrain, "profile": profile,
		"body": terrain.get_node("TerrainCollision"), "engine": [], "ground": [],
		"outcomes": [], "physical": false, "adapter": null, "boundary": null}
	if boundary_enabled:
		var boundary: StadiumRecipeBoundaryBody = StadiumRecipeBoundaryBody.new()
		lab.add_child(boundary)
		boundary.build("deeper_center")
		ctx.boundary = boundary
	if enabled:
		var adapter: StadiumHillsideGroundContact = StadiumHillsideGroundContact.new()
		ctx.adapter = adapter
		_check(adapter.install(lab, terrain, profile), "private exact terrain installation: " + profile)
	lab._ball_play_resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
		ctx.outcomes.append({"reason": String(outcome.reason), "result": int(outcome.result)}))
	return ctx


func _launch(ctx: Dictionary, start: Vector3, velocity: Vector3, foul: bool = false) -> BattedBallBody:
	var lab: PitchBatLab = ctx.lab
	lab._ball_play_resolver.start_play(lab._field_definition, foul)
	var ball: BattedBallBody = BattedBallBody.new()
	lab._batted_ball = ball
	ball.surface_contact.connect(lab._on_batted_surface_contact)
	lab.add_child(ball)
	ctx.ball = ball
	ctx.state = lab._ball_play_resolver.state
	ball.body_entered.connect(func(body: Node) -> void:
		ctx.engine.append({"frame": Engine.get_physics_frames(), "body": body.get_instance_id(),
			"ball": ball.get_instance_id(), "state": ctx.state.get_instance_id(),
			"position": _v(ball.global_position), "physical": ctx.physical}))
	ball.surface_contact.connect(func(surface: StringName, at: Vector3) -> void:
		if surface == &"ground":
			ctx.ground.append({"frame": Engine.get_physics_frames(), "position": _v(at),
				"ball": ball.get_instance_id(), "state": ctx.state.get_instance_id(),
				"grounded_after_ordinary_callback": ctx.state.has_grounded,
				"physical": ctx.physical}))
	if ctx.boundary != null:
		ctx.boundary.bind_ball(ball, lab._ball_play_resolver)
	StadiumPropertyRuntime.bind_ball(lab, ball, lab._ball_play_resolver)
	if ctx.adapter != null and not _check(ctx.adapter.bind_ball(lab, ball, lab._ball_play_resolver)
		and ctx.adapter._ball == ball and ctx.adapter._state == ctx.state,
		"requested ground binding succeeds before diagnostic launch"):
		return null # Failed binding is never allowed to launch a groundless candidate.
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = start
	launch.velocity = velocity
	launch.angular_velocity = Vector3.ZERO
	launch.is_foul = foul
	ball.launch(launch)
	return ball


func _flight(id: String, profile: String, start: Vector3, velocity: Vector3, ticks: int,
	enabled: bool, foul: bool = false, expect_contact: bool = true) -> Dictionary:
	var ctx: Dictionary = await _context(profile, enabled)
	ctx.physical = true
	var ball: BattedBallBody = _launch(ctx, start, velocity, foul)
	if ball == null:
		await _dispose(ctx)
		return {"history": []}
	var lab: PitchBatLab = ctx.lab
	var state: BallPlayState = ctx.state
	var shape: CollisionShape3D = ball.get_child(0) as CollisionShape3D
	var visual: MeshInstance3D = ball.get_child(1) as MeshInstance3D
	var sphere: SphereShape3D = shape.shape as SphereShape3D
	var display: SphereMesh = visual.mesh as SphereMesh
	_check(lab.get_script() == LAB and ball.get_script() == BALL
		and lab._ball_play_resolver.get_script() == RESOLVER and lab._batted_ball == ball
		and lab._ball_play_resolver.state == state and ball._started and not ball.freeze
		and ball.get_parent() == lab and ball.get_world_3d() == ctx.body.get_world_3d(),
		id + " real same-world ordinary lab/body/state provenance")
	var expected_sphere: SphereShape3D = SphereShape3D.new()
	expected_sphere.radius = 0.0365
	var expected_display: SphereMesh = SphereMesh.new()
	expected_display.radius = 0.075
	var expected_material: PhysicsMaterial = PhysicsMaterial.new()
	expected_material.bounce = 0.52
	expected_material.friction = 0.42
	_check(ball.radius_m == 0.0365 and sphere != null and display != null
		and sphere.radius == expected_sphere.radius
		and display.radius == expected_display.radius and visual.position == Vector3.ZERO
		and ball.physics_material_override.bounce == expected_material.bounce
		and ball.physics_material_override.friction == expected_material.friction
		and ctx.body.get_meta("ball_surface") == StadiumHillsideTerrainModels.SURFACE,
		id + " physical radius, display radius, material and retained terrain label unchanged")
	var history: Array[Dictionary] = []
	var first: Vector3 = Vector3.INF
	var first_tick: int = -1
	var stable_first: bool = true
	var rebound: bool = false
	var max_z: float = start.z
	for tick in range(ticks):
		await get_tree().physics_frame
		lab._ball_play_resolver.advance_time(1.0 / 60.0)
		var position: Vector3 = ball.global_position
		var moving: Vector3 = ball.linear_velocity
		var depth: Dictionary = _closed_depth(position, ball.radius_m, profile)
		history.append({"tick": tick, "position": _v(position), "velocity": _v(moving),
			"angular_velocity": _v(ball.angular_velocity), "depth_m": depth.depth,
			"center_inside": depth.inside, "speed_mps": moving.length()})
		max_z = maxf(max_z, position.z)
		if not ctx.engine.is_empty() and moving.y > 0.15:
			rebound = true
		if state.has_grounded:
			if first_tick < 0:
				first = state.first_ground_position
				first_tick = tick
			stable_first = stable_first and state.first_ground_position == first \
				and lab._active_play_record.first_ground_position == first
		if not _render_dir.is_empty() and CAPTURE_TICKS.has(tick + 1):
			await _capture(ctx, tick + 1, history[-1])
	_check((not ctx.engine.is_empty()) == expect_contact
		and ctx.engine.all(func(row: Dictionary) -> bool:
			return row.body == ctx.body.get_instance_id() and row.ball == ball.get_instance_id() \
				and row.state == state.get_instance_id() and row.physical),
		id + " genuine engine body-entered evidence identifies only exact terrain")
	_check(state.has_grounded == (enabled and expect_contact)
		and lab._active_play_record.has_first_ground == state.has_grounded
		and (not ctx.ground.is_empty()) == state.has_grounded,
		id + " ordinary lab callback and resolver agree on physical ground admission")
	_check(stable_first and (not state.has_grounded or ctx.ground.any(func(row: Dictionary) -> bool:
		return row.position == _v(first) and row.grounded_after_ordinary_callback and row.physical)),
		id + " first real world contact position stays idempotent across later contacts")
	_check(state.dead == foul and (ctx.outcomes.size() == 1
		and ctx.outcomes[0].reason == "foul_grounded" if foul else ctx.outcomes.is_empty()),
		id + " ordinary foul contact resolves once, fair nonterminal contact does not resolve")
	if id.contains(":drop:"):
		_check(rebound, id + " real landing produces observed upward bounce")
	if id == "hill:uphill_grounder":
		_check(history.size() == 300 and max_z > start.z + 1.0
			and ball.global_position.z < max_z - 0.5 and ball.linear_velocity.z < 0,
			"original 5 m/s witness genuinely climbs and rolls back in 300 ticks")
	for sample: Dictionary in history:
		_print_bounded("HILLSIDE_GROUND_TRAJECTORY ", {"id": id, "sample": sample})
	_print_bounded("HILLSIDE_GROUND_CASE ", {"id": id, "kind": "physical", "profile": profile,
		"physical_collision_proof": expect_contact,
		"adapter": enabled, "supplied_diagnostic_launch": {"position": _v(start), "velocity": _v(velocity)},
		"ball_id": ball.get_instance_id(), "terrain_body_id": ctx.body.get_instance_id(),
		"state_id": state.get_instance_id(), "ticks": ticks, "engine_contacts": ctx.engine,
		"ordinary_ground_events": ctx.ground, "first_ground_tick": first_tick,
		"has_grounded": state.has_grounded,
		"first_ground_position": _v(state.first_ground_position) if state.has_grounded else null,
		"outcomes": ctx.outcomes,
		"history_sample_count": history.size(), "h3_requalification": false})
	_cases += 1
	await _dispose(ctx)
	return {"history": history}


func _batch_order(reversed: bool) -> void:
	var ctx: Dictionary = await _context("hill", true, true)
	var ball: BattedBallBody = _launch(ctx, Vector3(0, 4, 20), Vector3.ZERO)
	if ball == null:
		await _dispose(ctx)
		return
	var wall: Node = _back_wall(ctx.boundary)
	var at: Vector3 = StadiumHillsideTerrain.point(0, 20)
	var batch: Array[Dictionary] = [{"body": wall, "position": Vector3(0, 1, 23.4)},
		{"body": ctx.body, "position": at}]
	if reversed:
		batch.reverse()
	var original: Array[Dictionary] = batch.duplicate(true)
	ball.physics_contact_router.call(ball, batch)
	_check(batch == original and ctx.boundary.contacts.size() == 1,
		"routing-unit full batch reaches real ordinary boundary unchanged in either array order")
	_check(ctx.state.has_grounded and ctx.state.first_ground_position == at
		and ctx.state.result_floor == BallPlayState.ResultFloor.DOUBLE and ctx.state.dead
		and ctx.outcomes.size() == 1 and ctx.outcomes[0].reason == "bounce_to_back_wall",
		"routing-unit terrain ground pre-pass precedes actual terminal wall classification")
	ball.physics_contact_router.call(ball, batch)
	ball.body_entered.emit(ctx.body)
	_check(ctx.outcomes.size() == 1 and ctx.state.first_ground_position == at,
		"routing-unit duplicate batch/callback cannot create post-dead resolution")
	_unit("ground-wall:" + str(reversed), ctx)
	await _dispose(ctx)


func _deep_batch() -> void:
	var ctx: Dictionary = await _context("hill", true, true)
	var ball: BattedBallBody = _launch(ctx, Vector3(0, 4, 20), Vector3.ZERO)
	if ball == null:
		await _dispose(ctx)
		return
	var batch: Array[Dictionary] = [{"body": ctx.body, "position": Vector3(0, 0, 16)}]
	ball.physics_contact_router.call(ball, batch)
	ctx.lab._ball_play_resolver.observe_segment(Vector3(0, 1, 10), Vector3(0, 1, 18))
	_check(ctx.state.has_grounded and ctx.state.result_floor == BallPlayState.ResultFloor.SINGLE
		and not ctx.state.dead and ctx.outcomes.is_empty(),
		"routing-unit existing ground-first policy suppresses deep-air Double without fictional TOI")
	_unit("ground-deep", ctx)
	await _dispose(ctx)


func _identity_unit() -> void:
	var ctx: Dictionary = await _context("hill", true)
	var ball: BattedBallBody = _launch(ctx, Vector3(0, 4, 20), Vector3.ZERO)
	if ball == null:
		await _dispose(ctx)
		return
	var foreign: StaticBody3D = StaticBody3D.new()
	foreign.set_meta("ball_surface", StadiumHillsideTerrainModels.SURFACE)
	add_child(foreign)
	ball.body_entered.emit(foreign)
	_check(not ctx.state.has_grounded and ctx.ground.is_empty(),
		"routing-unit same-label foreign body is not terrain authority")
	ball.body_entered.emit(ctx.body)
	var first: Vector3 = ctx.state.first_ground_position
	ball.body_entered.emit(ctx.body)
	_check(ctx.state.has_grounded and first == ball.global_position
		and ctx.state.first_ground_position == first and ctx.lab._active_play_record.first_ground_position == first,
		"routing-unit exact body callback uses actual center and first record is idempotent")
	foreign.queue_free()
	_unit("exact-body-and-duplicate", ctx)
	await _dispose(ctx)


func _stale_unit() -> void:
	var ctx: Dictionary = await _context("hill", true)
	var ball: BattedBallBody = _launch(ctx, Vector3(0, 4, 20), Vector3.ZERO)
	if ball == null:
		await _dispose(ctx)
		return
	var old: BallPlayState = ctx.state
	var old_callback: Callable = ctx.adapter._body_callback
	ctx.lab._ball_play_resolver.start_play(ctx.lab._field_definition)
	ball.body_entered.emit(ctx.body)
	_check(not old.has_grounded and not ctx.lab._ball_play_resolver.state.has_grounded,
		"routing-unit stale state callback cannot mutate replacement play")
	_check(ctx.adapter.bind_ball(ctx.lab, ball, ctx.lab._ball_play_resolver),
		"routing-unit explicit current-state rebind is required and succeeds")
	var current: BallPlayState = ctx.lab._ball_play_resolver.state
	old_callback.call(ctx.body)
	_check(not old.has_grounded and not current.has_grounded,
		"routing-unit delayed old closure remains stale after same-ball current-state rebind")
	current.dead = true
	ball.body_entered.emit(ctx.body)
	_check(not current.has_grounded, "routing-unit dead state remains unmodified")
	ctx.adapter.clear_binding()
	current.dead = false
	ctx.adapter.bind_ball(ctx.lab, ball, ctx.lab._ball_play_resolver)
	var current_callback: Callable = ctx.adapter._body_callback
	var replacement: BattedBallBody = BattedBallBody.new()
	ctx.lab.add_child(replacement)
	ctx.lab._batted_ball = replacement
	ball.body_entered.emit(ctx.body)
	_check(not current.has_grounded, "routing-unit superseded ball cannot mutate current state")
	ctx.adapter.clear_binding()
	_check(not ball.body_entered.is_connected(current_callback)
		and ball.body_entered.is_connected(ball._on_body_entered)
		and ball.surface_contact.is_connected(ctx.lab._on_batted_surface_contact),
		"routing-unit cleanup removes only adapter callback and preserves ordinary listeners")
	_unit("stale-state-ball-and-cleanup", ctx)
	await _dispose(ctx)


func _router_unit() -> void:
	var ctx: Dictionary = await _context("hill", true, true)
	var ball: BattedBallBody = _launch(ctx, Vector3(0, 4, 20), Vector3.ZERO)
	if ball == null:
		await _dispose(ctx)
		return
	var saved: Callable = ctx.boundary._contact_batch.bind(ctx.lab._ball_play_resolver)
	var wrapped: Callable = ball.physics_contact_router
	_check(wrapped != saved and ctx.adapter.bind_ball(ctx.lab, ball, ctx.lab._ball_play_resolver)
		and ball.physics_contact_router == wrapped, "routing-unit rebinding is idempotent without nested wrapper")
	ctx.adapter.clear_binding()
	_check(ball.physics_contact_router == saved, "routing-unit cleanup restores exact previous ordinary router")
	ctx.adapter.bind_ball(ctx.lab, ball, ctx.lab._ball_play_resolver)
	var newer: Callable = _newer_router
	ball.physics_contact_router = newer
	ctx.adapter.clear_binding()
	_check(ball.physics_contact_router == newer, "routing-unit cleanup never overwrites newer router owner")
	_check(not ctx.adapter.bind_ball(ctx.lab, ball, ctx.lab._ball_play_resolver)
		and ball.physics_contact_router == newer, "routing-unit unknown router is refused without replacement")
	_unit("router-ownership", ctx)
	await _dispose(ctx)


func _terrain_context_unit() -> void:
	var ctx: Dictionary = await _context("hill", false)
	var adapter: StadiumHillsideGroundContact = StadiumHillsideGroundContact.new()
	_check(not adapter.install(ctx.lab, ctx.terrain, "flat-control"), "routing-unit mismatched profile is refused")
	adapter.free()
	ctx.lab._managed_match = true
	adapter = StadiumHillsideGroundContact.new()
	_check(not adapter.install(ctx.lab, ctx.terrain, "hill"), "routing-unit managed/public-capable context is refused")
	adapter.free()
	ctx.lab._managed_match = false
	ctx.lab.set_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND, true)
	adapter = StadiumHillsideGroundContact.new()
	_check(not adapter.install(ctx.lab, ctx.terrain, "hill"), "routing-unit public-bound context is refused")
	adapter.free()
	ctx.lab.remove_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND)
	adapter = StadiumHillsideGroundContact.new()
	_check(adapter.install(ctx.lab, ctx.terrain, "hill"), "routing-unit exact private context remains eligible")
	ctx.adapter = adapter
	var ball: BattedBallBody = _launch(ctx, Vector3(0, 4, 20), Vector3.ZERO)
	if ball == null:
		await _dispose(ctx)
		return
	var shape: CollisionShape3D = ctx.body.get_node("ClosedTerrainShape")
	shape.disabled = true
	ball.body_entered.emit(ctx.body)
	_check(not ctx.state.has_grounded, "routing-unit disabled terrain cannot manufacture contact")
	shape.disabled = false
	adapter.bind_ball(ctx.lab, ball, ctx.lab._ball_play_resolver)
	ctx.terrain.remove_child(ctx.body)
	ball.body_entered.emit(ctx.body)
	_check(adapter.blocked and not ctx.state.has_grounded and ctx.ground.is_empty(), "routing-unit removed exact terrain invalidates authority")
	ctx.body.free()
	_unit("terrain-profile-context-and-removal", ctx)
	await _dispose(ctx)


func _newer_router(_ball: BattedBallBody, _batch: Array[Dictionary]) -> void:
	pass


func _back_wall(boundary: StadiumRecipeBoundaryBody) -> Node:
	for row: Dictionary in boundary.graph.segments():
		if row.role == "BACK_WALL_TERMINAL":
			return boundary.get_node(NodePath(row.id))
	return null


func _unit(id: String, ctx: Dictionary) -> void:
	_cases += 1
	_print_bounded("HILLSIDE_GROUND_CASE ", {"id": id, "kind": "routing-unit",
		"physical_collision_proof": false, "has_grounded": ctx.get("state") != null and ctx.state.has_grounded,
		"outcomes": ctx.outcomes})


func _run_rendered() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check(_render_dir.is_absolute_path() and _render_dir == _render_dir.simplify_path()
		and DirAccess.dir_exists_absolute(_render_dir) and DirAccess.get_files_at(_render_dir).is_empty()
		and DirAccess.get_directories_at(_render_dir).is_empty(), "fresh existing canonical render directory")
	_check(DisplayServer.get_name() != "headless" and get_viewport() == get_tree().root,
		"rendered witness uses actual root display")
	if _failures != 0:
		print("HILLSIDE_GROUND_RENDER checks=%d failures=%d" % [_checks, _failures])
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_window().content_scale_factor = 1.0
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("9cb7c6")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.55
	add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	add_child(light)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 5.5
	add_child(_camera)
	_camera.global_position = Vector3(9, 4, 18)
	_camera.look_at(Vector3(0, 0.7, 17))
	_camera.current = true
	await _flight("hill:uphill_grounder", "hill", Vector3(0, 0.10, 15), Vector3(0, 0, 5), 300, true)
	_check(_cases == 1 and _samples == 3, "exact one original uphill run and three fixed captures")
	_check(_checks + 1 == EXPECTED_RENDER_CHECKS, "exact rendered assertion inventory")
	print("HILLSIDE_GROUND_RENDER checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _capture(ctx: Dictionary, tick: int, sample: Dictionary) -> void:
	# Pause only the SceneTree during bounded draw waits; the ball is never frozen,
	# moved or reconfigured. This retains exactly 300 active physics samples.
	var pose: Transform3D = ctx.ball.global_transform
	var velocity: Vector3 = ctx.ball.linear_velocity
	var angular: Vector3 = ctx.ball.angular_velocity
	var physics_before: int = Engine.get_physics_frames()
	get_tree().paused = true
	_draw_ticks.clear()
	_observe_draw.call_deferred()
	var started: int = Time.get_ticks_msec()
	for _frame in range(120):
		await get_tree().process_frame
		if _draw_ticks.size() == 3 or Time.get_ticks_msec() - started > 10000:
			break
	var picture: Image = get_viewport().get_texture().get_image()
	_check(_draw_ticks.size() == 3 and _draw_ticks[0] < _draw_ticks[1] and _draw_ticks[1] < _draw_ticks[2]
		and Time.get_ticks_msec() - started <= 10000
		and get_viewport().get_camera_3d() == _camera and ctx.ball.visible
		and picture != null and not picture.is_empty() and picture.get_size() == Vector2i(1280, 720),
		"fixed-tick real root draw and exact 1280x720 raster")
	var unchanged: bool = pose == ctx.ball.global_transform and velocity == ctx.ball.linear_velocity \
		and angular == ctx.ball.angular_velocity
	_check(unchanged and not ctx.ball.freeze and can_process()
		and ctx.lab.process_mode == Node.PROCESS_MODE_PAUSABLE,
		"three paused completed draws preserve exact ball pose and linear/angular velocity")
	var bytes: PackedByteArray = picture.save_png_to_buffer() if picture != null else PackedByteArray()
	var file_name: String = "hillside-uphill-%03d.png" % tick
	var path: String = _render_dir.path_join(file_name)
	var admitted: bool = not bytes.is_empty() and bytes.size() <= PNG_CAP and not FileAccess.file_exists(path)
	_check(admitted, "fresh fixed-name PNG within 4 MiB cap")
	var saved: bool = false
	if admitted:
		var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if handle != null:
			handle.store_buffer(bytes)
			handle.flush()
			saved = handle.get_error() == OK
			handle.close()
	_check(saved and FileAccess.get_file_as_bytes(path) == bytes,
		"actual PNG written and exactly read back")
	if saved:
		_samples += 1
		_print_bounded("HILLSIDE_GROUND_SAMPLE ", {"tick": tick, "file": file_name,
			"bytes": bytes.size(), "sha256": FileAccess.get_sha256(path), "width": 1280, "height": 720,
			"ball_id": ctx.ball.get_instance_id(), "terrain_body_id": ctx.body.get_instance_id(),
			"state_id": ctx.state.get_instance_id(), "physics_sample": sample,
			"physical_radius_m": ctx.ball.radius_m, "visual_radius_m": 0.075,
			"visual_offset": [0, 0, 0], "has_grounded": ctx.state.has_grounded,
			"camera_position": _v(_camera.global_position), "camera_size": _camera.size,
			"pause_begin_physics_frame": physics_before, "pause_end_physics_frame": Engine.get_physics_frames(),
			"completed_draw_frames": _draw_ticks.duplicate(), "pre_post_ball_identical": unchanged,
			"pre_position": _v(pose.origin), "post_position": _v(ctx.ball.global_position),
			"pre_orientation": _q(pose.basis.get_rotation_quaternion()),
			"post_orientation": _q(ctx.ball.global_transform.basis.get_rotation_quaternion()),
			"pre_velocity": _v(velocity), "post_velocity": _v(ctx.ball.linear_velocity),
			"pre_angular_velocity": _v(angular), "post_angular_velocity": _v(ctx.ball.angular_velocity),
			"visual_acceptance": "REQUIRES_ROOT_IMAGE_REVIEW"})
	# All ordinary failure paths reach this common cleanup; no early return while paused.
	get_tree().paused = false


func _observe_draw() -> void:
	for _frame in range(3):
		await RenderingServer.frame_post_draw
		_draw_ticks.append(Engine.get_frames_drawn())


func _print_bounded(prefix: String, record: Dictionary) -> void:
	var line: String = prefix + JSON.stringify(record, "", true, true)
	if line.to_utf8_buffer().size() + 1 > 4096:
		_failures += 1
		push_error("Ground evidence exceeds the unchanged 4096-byte native line cap.")
		return
	print(line)


func _closed_depth(center: Vector3, radius: float, profile: String) -> Dictionary:
	# Exact closed-solid distance for this finite-X extrusion. At top knots, endcaps,
	# bottom and side edges this measures the nearest finite face, not vertical h+r.
	var bounds: Rect2 = StadiumHillsideTerrain.BOUNDS
	var samples: PackedFloat64Array = StadiumHillsideTerrain.knots()
	var p: Vector2 = Vector2(center.z, center.y)
	var distance: float = INF
	for index in range(samples.size() - 1):
		var a: Vector2 = Vector2(samples[index], StadiumHillsideTerrain.design_height(samples[index], profile))
		var b: Vector2 = Vector2(samples[index + 1], StadiumHillsideTerrain.design_height(samples[index + 1], profile))
		distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	var low: Vector2 = Vector2(bounds.position.y, StadiumHillsideTerrain.BOTTOM)
	var high: Vector2 = Vector2(bounds.end.y, StadiumHillsideTerrain.BOTTOM)
	for segment: Array in [[low, high], [low, Vector2(low.x, StadiumHillsideTerrain.design_height(low.x, profile))],
		[high, Vector2(high.x, StadiumHillsideTerrain.design_height(high.x, profile))]]:
		distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, segment[0], segment[1])))
	var inside_yz: bool = center.z >= low.x and center.z <= high.x \
		and center.y >= low.y and center.y <= StadiumHillsideTerrain.support_height(Vector2(0, center.z), profile)
	var outside_x: float = maxf(maxf(bounds.position.x - center.x, center.x - bounds.end.x), 0)
	var inside: bool = inside_yz and outside_x == 0
	var signed_distance: float
	if inside:
		signed_distance = -minf(distance, minf(center.x - bounds.position.x, bounds.end.x - center.x))
	else:
		signed_distance = Vector2(outside_x, 0.0 if inside_yz else distance).length()
	return {"depth": maxf(radius - signed_distance, 0), "inside": inside}


func _dispose(ctx: Dictionary) -> void:
	if is_instance_valid(ctx.adapter):
		ctx.adapter.clear_binding()
	ctx.lab.queue_free()
	ctx.terrain.queue_free()
	await _barrier()


func _barrier() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _v(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _q(value: Quaternion) -> Array[float]:
	return [value.x, value.y, value.z, value.w]


func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
	return ok
