extends Node3D
## Focused private integration gate. Real entry/ready/process, ordinary launch seam.
## Supplied launch is diagnostic input, not a genuine pitch/contact or rendered-play proof.
## Retained component gates: control 172; pitcher 158; primary 156; ground 99.
# gdlint: disable=max-line-length,max-file-lines,max-returns

const ENTRY: PackedScene = preload("res://src/labs/pitch_bat_lab/hillside_private_lab.tscn")
const LAB: Script = preload("res://src/labs/pitch_bat_lab/pitch_bat_lab.gd")
const FIELD: FieldDefinition = preload("res://src/content/fields/npc_venue_field.tres")
const EXPECTED_CASES: int = 10
const EXPECTED_CHECKS: int = 82
const LIVE_TICKS: int = 30
# Working physical ray comparison only; same retained allowance as bound support.
# Geometry/identity, provider mutation and launch ordering checks use exact equality.
const WORKING_SUPPORT_RAY_ERROR_M: float = 0.0002
var _checks: int = 0
var _failures: int = 0
var _cases: int = 0
var _provider_support_calls: int = 0
var _provider_arrival_calls: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		push_error("The private headless integration gate accepts no selectors.")
		get_tree().quit(2)
		return
	_flat_and_bounded_planner()
	var ctx: Dictionary = await _open("ordinary-ready")
	if ctx.is_empty():
		_finish()
		return
	_startup_and_perimeter(ctx)
	_read_only_providers(ctx)
	await _automatic_launch_and_reset(ctx)
	await _dispose(ctx)
	for mode: String in ["changed-ground", "missing-ground", "changed-router", "changed-ball", "missing-owner"]:
		await _held_launch(mode)
	await _freed_owner_launch()
	_finish()


func _finish() -> void:
	_check(_cases == EXPECTED_CASES, "exact focused integration case inventory")
	_check(_checks + 1 == EXPECTED_CHECKS, "exact focused integration assertion inventory")
	print("HILLSIDE_PRIVATE_PLAY checks=%d failures=%d" % [_checks, _failures])
	print("HILLSIDE_PRIVATE_PLAY_CASE_COUNT %d" % _cases)
	get_tree().quit(0 if _failures == 0 else 1)


func _open(id: String) -> Dictionary:
	var entry: Node3D = ENTRY.instantiate() as Node3D
	add_child(entry) # Actual production _ready builds all ordinary actors, HUD and camera.
	for _frame in range(180):
		await get_tree().physics_frame
		await get_tree().process_frame
		var current_owner: StadiumHillsidePrivateRuntime = entry.get("owner_runtime")
		if current_owner != null and not current_owner._installing:
			break
	var lab: PitchBatLab = entry.get("lab")
	var owner: StadiumHillsidePrivateRuntime = entry.get("owner_runtime")
	if not _check(is_instance_valid(lab) and is_instance_valid(owner) and not owner.blocked
		and lab.hillside_private_runtime == owner and owner.get_parent() == lab,
		id + " real ordinary ready and asynchronous owner install succeed"):
		_emit("startup-failed", {"requested": id, "error": owner.last_error if is_instance_valid(owner) else "no owner"})
		entry.queue_free()
		await get_tree().process_frame
		return {}
	var ctx: Dictionary = {"entry": entry, "lab": lab, "owner": owner, "mode": "",
		"outcomes": [], "candidates": [], "launches": [], "detached": [], "mutated": false}
	lab._ball_play_resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
		ctx.outcomes.append({"reason": String(outcome.reason), "result": int(outcome.result)}))
	lab.child_entered_tree.connect(_on_lab_child.bind(ctx))
	return ctx


func _flat_and_bounded_planner() -> void:
	var ball: Vector3 = Vector3(0, 1, 0)
	var airborne: FielderPlan = FielderPlanner.plan(ball, Vector3.ZERO, false,
		Vector3.ZERO, 4.6, 0.66)
	var expected: Vector3 = ball + Vector3.DOWN * 0.5 * FielderPlanner.GRAVITY_MPS2 * 0.1 * 0.1
	_check(airborne.reachable and airborne.intercept_seconds == 0.1
		and airborne.intercept_position == expected and airborne.reaction_margin_seconds == 0.1,
		"ordinary no-provider airborne formula and first-sample decision stay exact")
	var ground: FielderPlan = FielderPlanner.plan(ball, Vector3.ZERO, true, Vector3.ZERO, 4.6, 0.66)
	_check(ground.reachable and ground.intercept_position == Vector3(0, 0.45, 0)
		and not ground.advisory_route and ground.forecast_samples == 0,
		"ordinary no-provider ground fallback and diagnostics remain unchanged")
	var bounded: FielderPlan = FielderPlanner.plan(ball, Vector3.ZERO, false,
		Vector3.ZERO, 4.6, 0.66, false, _count_support, _count_arrival)
	_check(not bounded.reachable and bounded.advisory_route and bounded.forecast_samples == 30
		and bounded.route_queries == 30 and _provider_support_calls == 30 and _provider_arrival_calls == 30,
		"advisory provider loop has exactly thirty bounded forecast samples")
	var rejected: FielderPlan = FielderPlanner.plan(ball, Vector3.ZERO, false,
		Vector3.ZERO, 4.6, 0.66, false, _count_support, Callable())
	_check(not rejected.reachable and rejected.route_reason == "invalid_provider"
		and rejected.forecast_samples == 0 and _provider_support_calls == 30,
		"partial provider binding fails closed without falling into flat prediction")
	var clock: StadiumHillsideDefenderMotion = StadiumHillsideDefenderMotion.new()
	_check(not clock.tracking_due(0.0) and clock.tracking_due(0.03125),
		"automatic cadence requires positive delta and first eligible plan is immediate")
	clock.record_tracking_plan(FielderPlan.new(), 7)
	var waits: bool = true
	for _tick in range(3):
		waits = waits and not clock.tracking_due(0.03125)
	_check(waits and clock.tracking_due(0.03125) and clock.tracking_plan_count == 1,
		"binary-exact cadence inputs wait through 93.75 ms and admit by 125 ms")
	clock.reset_tracking()
	_check(clock.tracking_plan_count == 0 and clock.last_tracking_plan == null
		and clock.last_tracking_usec == 0 and clock.tracking_total_usec == 0
		and clock.tracking_due(0.03125), "explicit reset clears cadence and makes the next plan immediately eligible")
	_case("ordinary-and-bounded-planner", {"forecast_samples": bounded.forecast_samples,
		"ordinary_formula_exact": true, "advisory_only": true})


func _count_support(xz: Vector2) -> Dictionary:
	_provider_support_calls += 1
	return {"position": Vector3(xz.x, 0, xz.y)}


func _count_arrival(_ball: Vector3, feet: Vector3, _seconds: float, _speed: float,
	_reach: float, _stationary: bool, _grounded: bool) -> Dictionary:
	_provider_arrival_calls += 1
	return {"reached": false, "reason": "test_horizon", "feet_target": feet,
		"position": Vector3.ZERO, "elapsed": INF, "support_segments": 0}


func _startup_and_perimeter(ctx: Dictionary) -> void:
	var lab: PitchBatLab = ctx.lab
	var owner: StadiumHillsidePrivateRuntime = ctx.owner
	var primary: FielderController = lab._primary_fielder
	_check(lab.get_script() == LAB and lab.is_node_ready() and lab.is_processing()
		and lab.is_physics_processing() and primary.is_physics_processing()
		and lab._pitch_actor.is_physics_processing() and lab._automation == null,
		"ordinary ready and process paths run without late scripts or disabled-process fixtures")
	_check(lab._field_definition == FIELD and lab._field_id == FIELD.id
		and not FIELD.shallow_center_available and not FIELD.middle_center_available
		and FIELD.is_fielder_anchor_available(7) and lab._fielder_anchor_index == 7,
		"actual immutable NPC field and existing available deep-center slot are used")
	_check(primary.anchor_position == StadiumHillsideTerrain.point(0, FIELD.deep_anchor_z_m)
		and lab._pitcher_marker.global_position == StadiumHillsideTerrain.point(0, lab.MOUND_ORIGIN.z)
		and primary.hillside_motion != lab.hillside_pitcher_motion,
		"actual primary and independent actual pitcher bind terrain-supported feet")
	_check(lab._status_label != null and lab._config_label != null and lab._camera != null
		and lab._camera_director != null and lab.get_viewport().get_camera_3d() != null,
		"ordinary HUD and camera are built by the user-operable private entry")
	_check(owner.automatic_tracking_valid(lab, primary.hillside_motion)
		and owner.automatic_tracking_valid(lab, lab.hillside_pitcher_motion)
		and not owner.automatic_tracking_valid(lab, StadiumHillsideDefenderMotion.new())
		and not owner.launch_binding_valid(null, null), "exact owner admits only its actual actors and a bound ball")
	var boundary: StadiumHillsideBoundaryBody = owner.boundary
	var graph: StadiumHillsideBoundary = boundary.graph as StadiumHillsideBoundary
	var retained: StadiumRecipeBoundary = StadiumRecipeBoundary.create("deeper_center")
	_check(boundary.retained_valid(owner.terrain) and graph.polygon() == retained.polygon()
		and graph.segments() == retained.segments(), "real installed perimeter preserves exact original XZ and segment policy")
	var geometry: Dictionary = _physical_geometry(boundary)
	_check(geometry.valid and geometry.shapes > 0 and geometry.shapes <= boundary.MAX_SLICES
		and geometry.vertices > 0, "real collision prism top is sampled support plus retained relative wall height")
	var top: float = graph.top_height("BACK-02", Vector2(0, 26))
	var low: Dictionary = graph.crossing(Vector3(0, top - 0.125, 25), Vector3(0, top - 0.125, 27))
	var high: Dictionary = graph.crossing(Vector3(0, top + 0.125, 25), Vector3(0, top + 0.125, 27))
	_check(top == 5.25 and low.get("segment") == "BACK-02" and low.get("role") == "BACK_WALL_TERMINAL"
		and high.get("role") == "BACK_CLEAR" and low.fraction == high.fraction,
		"real graph classifies above/below terrain-relative center top with unchanged crossing fraction")
	var terrain_body: StaticBody3D = owner.terrain.get_node("TerrainCollision")
	_check(_ray_support(lab, primary.global_position, owner.terrain, primary.hillside_motion)
		and _ray_support(lab, lab._pitcher_marker.global_position, owner.terrain, lab.hillside_pitcher_motion)
		and owner.terrain.process_mode == Node.PROCESS_MODE_INHERIT
		and boundary.process_mode == Node.PROCESS_MODE_INHERIT
		and terrain_body.can_process()
		and terrain_body.disable_mode == CollisionObject3D.DISABLE_MODE_REMOVE,
		"both actual actors retain physical support after installation processing modes restore")
	_case("ordinary-ready-and-perimeter", {"shapes": geometry.shapes, "vertices": geometry.vertices,
		"xz_exact": true, "center_top_m": top, "support_ray_error_m": WORKING_SUPPORT_RAY_ERROR_M})


func _physical_geometry(boundary: StadiumHillsideBoundaryBody) -> Dictionary:
	var valid: bool = true
	var shapes: int = 0
	var vertices: int = 0
	for body: Node in boundary.get_children():
		var row: Dictionary = boundary.graph.segment(body.get_meta("boundary_segment", ""))
		valid = valid and body is StaticBody3D and not row.is_empty()
		for child: Node in body.get_children():
			if not child is CollisionShape3D:
				continue
			var shape: ConvexPolygonShape3D = child.shape as ConvexPolygonShape3D
			if shape == null:
				valid = false
				continue
			var points: PackedVector3Array = shape.points
			var half: int = points.size() >> 1
			valid = valid and shape.margin == 0.0 and points.size() >= 6 and points.size() % 2 == 0
			for index in range(half):
				var base: Vector3 = points[index]
				var support: float = StadiumHillsideTerrain.support_height(Vector2(base.x, base.z))
				valid = valid and base == Vector3(base.x, support, base.z) \
					and points[index + half] == Vector3(base.x, support + float(row.height), base.z)
			shapes += 1
			vertices += points.size()
	return {"valid": valid, "shapes": shapes, "vertices": vertices}


func _read_only_providers(ctx: Dictionary) -> void:
	var lab: PitchBatLab = ctx.lab
	var primary: FielderController = lab._primary_fielder
	var counts: Array[Dictionary] = []
	var combined_usec: int = 0
	var maximum_usec: int = 0
	for pitcher: bool in [false, true]:
		var motion: StadiumHillsideDefenderMotion = lab.hillside_pitcher_motion if pitcher else primary.hillside_motion
		var before: Dictionary = _snapshot(lab)
		var providers: Dictionary = motion.planning_providers(primary, 1.0 / 60.0, lab if pitcher else null)
		_check(providers.has("support") and providers.has("arrival")
			and motion.planning_providers(primary, 0.0, lab if pitcher else null).is_empty(),
			"actual role providers require valid explicit ordinary physics delta")
		if providers.is_empty():
			continue
		var at: Vector3 = lab._pitcher_marker.global_position if pitcher else primary.global_position
		var goal: Vector3 = StadiumHillsideTerrain.point(at.x + 1.0, at.z)
		var started_usec: int = Time.get_ticks_usec()
		var plan: FielderPlan = FielderPlanner.plan(goal + Vector3.UP * 0.5, Vector3.ZERO, true,
			at, 4.6, 0.66, false, providers.support, providers.arrival)
		var elapsed_usec: int = Time.get_ticks_usec() - started_usec
		combined_usec += elapsed_usec
		maximum_usec = maxi(maximum_usec, elapsed_usec)
		_check(plan.advisory_route and plan.reachable and plan.forecast_samples >= 1
			and plan.forecast_samples <= 30 and plan.route_queries <= 30
			and plan.route_support_segments <= 30 * 7 and plan.reaction_margin_seconds == 0.0,
			"actual role forecast stays bounded and cannot manufacture reaction credit")
		_check(plan.supported_feet_position == goal and plan.intercept_position == Vector3(goal.x, goal.y + 0.45, goal.z)
			and plan.route_endpoint.is_finite(), "forecast ball center, supported feet and route endpoint stay distinct")
		var supported: Dictionary = providers.support.call(Vector2(goal.x, goal.z))
		var route: Dictionary = providers.arrival.call(goal + Vector3.UP * 0.5, supported.position,
			1.0, 4.6, 0.66, false, true)
		_check(route.advisory and route.coarse_steps <= 1 and route.support_checks <= 8
			and route.max_support_checks == 8 and route.max_coarse_steps == 1,
			"actual role arrival query caps one coarse step and eight support samples")
		var unsupported: Dictionary = providers.support.call(Vector2.INF)
		_check(unsupported.is_empty(), "actual role provider rejects nonfinite support without authority")
		_check(_snapshot(lab) == before, "actual role planning queries are exactly read-only across live actors, routes and state")
		counts.append({"role": "pitcher" if pitcher else "primary", "samples": plan.forecast_samples,
			"queries": plan.route_queries, "support_segments": plan.route_support_segments, "elapsed_usec": elapsed_usec})
	_check(ctx.outcomes.is_empty(), "advisory forecast never awards a fielding or scoring outcome")
	_case("read-only-automatic-providers", {"roles": counts, "advisory_only": true,
		"combined_usec": combined_usec, "maximum_role_usec": maximum_usec,
		"walltime_acceptance": "ROOT_REVIEW_REQUIRED_NO_THRESHOLD_ASSERTED"})


func _automatic_launch_and_reset(ctx: Dictionary) -> void:
	var lab: PitchBatLab = ctx.lab
	var owner: StadiumHillsidePrivateRuntime = ctx.owner
	var before_primary: Vector3 = lab._primary_fielder.global_position
	var before_pitcher: Vector3 = lab._pitcher_marker.global_position
	_launch(lab)
	var ball: BattedBallBody = lab._batted_ball
	_check(is_instance_valid(ball) and ball._started and not ball.freeze and ctx.launches.size() == 1,
		"actual ordinary start-ball-in-play creates and launches its original candidate")
	_check(ctx.launches.size() == 1 and ctx.launches[0].bound and ctx.launches[0].ground_before_launch
		and ctx.launches[0].boundary_before_ground, "real launch signal observes exact boundary then ground routing already bound")
	_check(is_instance_valid(ball) and owner.launch_binding_valid(ball, lab._ball_play_resolver.state)
		and ball.physics_contact_router == owner.ground._wrapped_router,
		"postlaunch exact candidate and state retain composed physical router")
	var guard_timings: Dictionary = _measure_guards(ctx)
	var motions: Array[StadiumHillsideDefenderMotion] = [lab._primary_fielder.hillside_motion, lab.hillside_pitcher_motion]
	_check(Engine.physics_ticks_per_second == 60 and motions.all(func(motion: StadiumHillsideDefenderMotion) -> bool:
		return motion.tracking_plan_count == 0 and motion.last_tracking_plan == null),
		"ordinary begin-play clears both 100 ms cadence states before sixty-hertz active ticks")
	var cadence: Array[Dictionary] = []
	for role in range(2):
		cadence.append({"role": "primary" if role == 0 else "pitcher", "plan": null,
			"count": 0, "position": before_primary if role == 0 else before_pitcher,
			"target": lab._primary_fielder.target_position if role == 0 else Vector3.INF,
			"changes": [], "maximum_usec": 0, "between_plan_moves": 0,
			"stable": true, "bounded": true, "spaced": true})
	var maximum_combined_usec: int = 0
	var supported: bool = true
	for tick in range(LIVE_TICKS):
		await get_tree().physics_frame
		var combined_usec: int = 0
		for role in range(2):
			var motion: StadiumHillsideDefenderMotion = motions[role]
			var row: Dictionary = cadence[role]
			var position: Vector3 = lab._primary_fielder.global_position if role == 0 else lab._pitcher_marker.global_position
			var target: Vector3 = lab._primary_fielder.target_position if role == 0 else (
				motion.last_tracking_plan.supported_feet_position if motion.last_tracking_plan != null else Vector3.INF)
			if motion.tracking_plan_count != row.count:
				row.spaced = row.spaced and motion.tracking_plan_count == row.count + 1 \
					and (row.changes.is_empty() or tick - int(row.changes[-1]) >= 6)
				row.changes.append(tick)
				row.maximum_usec = maxi(row.maximum_usec, motion.last_tracking_usec)
				combined_usec += motion.last_tracking_usec
			elif motion.last_tracking_plan != null:
				row.stable = row.stable and motion.last_tracking_plan == row.plan and target == row.target
				if position != row.position:
					row.between_plan_moves += 1
			if motion.last_tracking_plan != null:
				row.bounded = row.bounded and motion.last_tracking_plan.forecast_samples <= 30 \
					and motion.last_tracking_plan.route_queries <= 30
			row.plan = motion.last_tracking_plan
			row.count = motion.tracking_plan_count
			row.position = position
			row.target = target
		maximum_combined_usec = maxi(maximum_combined_usec, combined_usec)
		supported = supported and _ray_support(lab, lab._primary_fielder.global_position, owner.terrain, lab._primary_fielder.hillside_motion) \
			and _ray_support(lab, lab._pitcher_marker.global_position, owner.terrain, lab.hillside_pitcher_motion)
	_check(cadence.all(func(row: Dictionary) -> bool:
		return row.count >= 2 and row.count <= 6 and row.spaced and row.bounded),
		"actual sixty-hertz callers replan at 100 ms cadence within thirty-sample bounds")
	_check(cadence.all(func(row: Dictionary) -> bool:
		return row.stable and row.between_plan_moves > 0),
		"both actual actors continue physics-tick movement while supported targets stay held between plans")
	var timing_rows: Array[Dictionary] = []
	for role in range(2):
		timing_rows.append({"role": cadence[role].role, "count": motions[role].tracking_plan_count,
			"replan_ticks": cadence[role].changes, "total_usec": motions[role].tracking_total_usec,
			"maximum_usec": cadence[role].maximum_usec, "between_plan_moves": cadence[role].between_plan_moves})
	_check(not owner.blocked and not lab._primary_fielder.hillside_motion.blocked
		and not lab.hillside_pitcher_motion.blocked and supported,
		"ordinary active frames preserve both supported actor bindings")
	_check(lab._primary_fielder.global_position != before_primary
		and lab._pitcher_marker.global_position != before_pitcher
		and lab.hillside_pitcher_target == Vector3.INF,
		"real primary and pitcher automatically pursue without an explicit fixture target")
	var primary_plan: FielderPlan = lab._primary_fielder.hillside_motion.last_tracking_plan
	var pitcher_plan: FielderPlan = lab.hillside_pitcher_motion.last_tracking_plan
	_check(primary_plan != null and pitcher_plan != null and primary_plan.advisory_route
		and pitcher_plan.advisory_route and primary_plan.forecast_samples <= 30
		and pitcher_plan.forecast_samples <= 30 and primary_plan.reaction_margin_seconds == 0.0
		and pitcher_plan.reaction_margin_seconds == 0.0,
		"ordinary active ticks actually consume bounded advisory plans for both actors")
	_check(ctx.outcomes.is_empty() and not lab._ball_play_resolver.state.dead,
		"high airborne diagnostic movement creates no fabricated control or score")
	var after_primary: Vector3 = lab._primary_fielder.global_position
	var after_pitcher: Vector3 = lab._pitcher_marker.global_position
	lab._reset_lab()
	_check(lab._batted_ball == null and owner._ball == null and owner.ground._ball == null
		and not lab._primary_fielder.active and lab.hillside_pitcher_target == Vector3.INF,
		"ordinary reset clears candidate, physical binding and automatic movement state")
	_check(motions.all(func(motion: StadiumHillsideDefenderMotion) -> bool:
		return motion.tracking_plan_count == 0 and motion.last_tracking_plan == null \
			and motion.last_tracking_usec == 0 and motion.tracking_total_usec == 0),
		"ordinary reset clears both automatic plan references, timing counters and cadence")
	_check(owner.admits_action() and lab._field_definition == FIELD
		and _ray_support(lab, lab._primary_fielder.global_position, owner.terrain, lab._primary_fielder.hillside_motion)
		and _ray_support(lab, lab._pitcher_marker.global_position, owner.terrain, lab.hillside_pitcher_motion),
		"ordinary reset keeps immutable field and valid supported private installation")
	_case("automatic-launch-movement-reset", {"ticks": LIVE_TICKS,
		"supplied_launch": {"position": [2, 4, 16], "velocity": [0, 1, 1]},
		"primary_before": _v(before_primary), "primary_after": _v(after_primary),
		"pitcher_before": _v(before_pitcher), "pitcher_after": _v(after_pitcher),
		"real_pitch_contact_proof": false, "outcomes": ctx.outcomes, "owner_guard_timings": guard_timings,
		"automatic_plan_timings": timing_rows, "maximum_combined_plan_usec": maximum_combined_usec,
		"combined_plan_total_usec": int(timing_rows[0].total_usec) + int(timing_rows[1].total_usec),
		"walltime_acceptance": "ROOT_REVIEW_REQUIRED_NO_THRESHOLD_ASSERTED"})


func _held_launch(mode: String) -> void:
	var ctx: Dictionary = await _open(mode)
	if ctx.is_empty():
		return
	ctx.mode = mode
	var lab: PitchBatLab = ctx.lab
	var owner: StadiumHillsidePrivateRuntime = ctx.owner
	if mode == "missing-owner":
		lab.remove_child(owner)
		ctx.detached.append(owner)
	elif mode == "missing-ground":
		lab.remove_child(owner.ground)
		ctx.detached.append(owner.ground)
	_launch(lab)
	var launched: int = 0
	var all_stopped: bool = true
	for candidate: BattedBallBody in ctx.candidates:
		if is_instance_valid(candidate):
			launched += 1 if candidate._started else 0
			all_stopped = all_stopped and (candidate.freeze or not candidate._started)
	_check(owner.blocked and lab.process_mode == Node.PROCESS_MODE_DISABLED,
		mode + " changed or missing authority holds ordinary lab")
	_check(launched == (1 if mode == "changed-router" else 0) and all_stopped,
		mode + " original candidate cannot escape its bind-before-launch or post-callback hold")
	_check(not owner.admits_action() and not owner.launch_binding_valid(lab._batted_ball,
		lab._ball_play_resolver.state), mode + " exact action and launch seams fail closed")
	_check(lab._primary_fielder.hillside_motion.planning_providers(lab._primary_fielder,
		1.0 / 60.0).is_empty(), mode + " held owner cannot supply automatic tracking providers")
	_check(ctx.outcomes.is_empty() and (lab._ball_play_resolver.state == null
		or not lab._ball_play_resolver.state.dead), mode + " hold manufactures no resolved outcome")
	_case(mode, {"launched_candidates": launched, "held": owner.blocked,
		"candidate_count": ctx.candidates.size(), "outcomes": ctx.outcomes})
	await _dispose(ctx)



func _freed_owner_launch() -> void:
	var ctx: Dictionary = await _open("freed-owner-launch")
	if ctx.is_empty():
		return
	ctx.mode = "freed-owner-launch"
	var lab: PitchBatLab = ctx.lab
	_launch(lab)
	var candidate: BattedBallBody = ctx.candidates[0] if not ctx.candidates.is_empty() else null
	_check(not is_instance_valid(ctx.owner) and ctx.launches.size() == 1,
		"owner is genuinely freed inside the original candidate launch signal")
	_check(is_instance_valid(candidate) and candidate._started and candidate.freeze
		and candidate.is_queued_for_deletion() and lab._batted_ball == null,
		"freed-owner fallback freezes and retires only its captured launched candidate")
	_check(lab.process_mode == Node.PROCESS_MODE_DISABLED and not lab._private_hillside_admits(),
		"freed exact owner identity cannot select ordinary fallback")
	_check(lab._primary_fielder.hillside_motion.planning_providers(lab._primary_fielder,
		1.0 / 60.0).is_empty(), "freed owner cannot authorize further automatic tracking")
	_check(ctx.outcomes.is_empty() and not lab._ball_play_resolver.state.dead,
		"freed-owner launch interruption creates no scoring outcome")
	_case("freed-owner-launch", {"owner_invalid": not is_instance_valid(ctx.owner),
		"captured_candidate_started": is_instance_valid(candidate) and candidate._started,
		"captured_candidate_retired": is_instance_valid(candidate) and candidate.is_queued_for_deletion(),
		"outcomes": ctx.outcomes})
	await _dispose(ctx)


func _measure_guards(ctx: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var before: Dictionary = _snapshot(ctx.lab)
	var valid: bool = true
	for kind: String in ["automatic_tracking_valid", "admits_action", "check_live_owner"]:
		var total_usec: int = 0
		var maximum_usec: int = 0
		for _index in range(8):
			var started_usec: int = Time.get_ticks_usec()
			match kind:
				"automatic_tracking_valid":
					valid = ctx.owner.automatic_tracking_valid(ctx.lab, ctx.lab._primary_fielder.hillside_motion) and valid
				"admits_action":
					valid = ctx.owner.admits_action() and valid
				"check_live_owner":
					ctx.owner._check_live_owner()
			var elapsed_usec: int = Time.get_ticks_usec() - started_usec
			total_usec += elapsed_usec
			maximum_usec = maxi(maximum_usec, elapsed_usec)
		result[kind] = {"calls": 8, "total_usec": total_usec, "maximum_usec": maximum_usec}
	_check(valid and _snapshot(ctx.lab) == before and not ctx.owner.blocked,
		"live owner guards remain read-only during bounded cost measurement")
	result["walltime_acceptance"] = "ROOT_REVIEW_REQUIRED_NO_THRESHOLD_ASSERTED"
	return result


func _on_lab_child(node: Node, ctx: Dictionary) -> void:
	if not node is BattedBallBody:
		return
	var ball: BattedBallBody = node as BattedBallBody
	ctx.candidates.append(ball)
	ball.launch_started.connect(_on_launch_started.bind(ball, ctx))
	if ctx.mutated:
		return
	ctx.mutated = true
	match ctx.mode:
		"changed-ground":
			ctx.owner.terrain.get_node("TerrainCollision/ClosedTerrainShape").disabled = true
		"changed-ball":
			var replacement: BattedBallBody = BattedBallBody.new()
			ctx.lab._batted_ball = replacement
			ctx.detached.append(replacement) # Supersede identity without a reentrant scene-tree edit.


func _on_launch_started(_position: Vector3, ball: BattedBallBody, ctx: Dictionary) -> void:
	var owner: StadiumHillsidePrivateRuntime = ctx.owner
	ctx.launches.append({"bound": owner.launch_binding_valid(ball, ctx.lab._ball_play_resolver.state),
		"ground_before_launch": owner.ground._ball == ball and owner.ground._state == ctx.lab._ball_play_resolver.state,
		"boundary_before_ground": owner.ground._saved_router == Callable(owner.boundary, "_contact_batch").bind(ctx.lab._ball_play_resolver)})
	if ctx.mode == "changed-router":
		ball.physics_contact_router = _foreign_router
	elif ctx.mode == "freed-owner-launch":
		owner.free()


func _foreign_router(_ball: BattedBallBody, _batch: Array[Dictionary]) -> void:
	pass


func _launch(lab: PitchBatLab) -> void:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(2, 4, 16)
	launch.velocity = Vector3(0, 1, 1)
	lab._start_ball_in_play(launch)


func _snapshot(lab: PitchBatLab) -> Dictionary:
	var primary: FielderController = lab._primary_fielder
	var one: StadiumHillsideDefenderMotion = primary.hillside_motion
	var two: StadiumHillsideDefenderMotion = lab.hillside_pitcher_motion
	var state: BallPlayState = lab._ball_play_resolver.state
	var fields: Dictionary = {} if state == null else {"dead": state.dead, "grounded": state.has_grounded,
		"first_ground": state.first_ground_position, "floor": state.result_floor,
		"elapsed": state.elapsed_seconds, "touched": state.defender_touched}
	return {"primary": primary.global_transform, "velocity": primary.velocity,
		"target": primary.target_position, "pitcher": lab._pitcher_marker.global_transform,
		"one_path": one.last_path.duplicate(true), "two_path": two.last_path.duplicate(true),
		"one_blocked": one.blocked, "two_blocked": two.blocked, "one_error": one.last_error,
		"two_error": two.last_error, "one_accepted": one._last_valid_position,
		"two_accepted": two._last_valid_position, "primary_route": primary.stadium_pool_fielder_route.duplicate(true),
		"pitcher_route": primary.stadium_pool_pitcher_route.duplicate(true), "state": state, "state_fields": fields,
		"one_plan": one.last_tracking_plan, "two_plan": two.last_tracking_plan,
		"one_count": one.tracking_plan_count, "two_count": two.tracking_plan_count,
		"one_total_usec": one.tracking_total_usec, "two_total_usec": two.tracking_total_usec,
		"one_cadence": one._tracking_elapsed_seconds, "two_cadence": two._tracking_elapsed_seconds,
		"one_has_valid": one._has_valid_position, "two_has_valid": two._has_valid_position,
		"primary_attempts": lab._primary_attempts, "pitcher_attempted": lab._pitcher_attempted,
		"match_phase": lab._match_state.phase, "outcomes": lab._play_records.size()}


func _ray_support(lab: PitchBatLab, at: Vector3, terrain: Node3D,
	motion: StadiumHillsideDefenderMotion) -> bool:
	var expected: Vector3 = StadiumHillsideTerrain.point(at.x, at.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		expected + Vector3.UP * 3.0, expected - Vector3.UP * 3.0, StadiumHillsideTerrainModels.QUERY_LAYER)
	var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(query)
	# Inactive placement/reset keeps the exact original sampled-point oracle.
	# Active arc prefixes must instead equal their actual committed endpoint.
	if motion == null or motion.blocked or not motion._has_valid_position:
		return false
	var committed: Vector3 = expected
	if lab._primary_fielder.active:
		committed = motion.last_path.get("position", motion._last_valid_position)
	return at == committed and at == motion._last_valid_position \
		and motion._physical_support(lab._primary_fielder, at) \
		and not hit.is_empty() and hit.collider == terrain.get_node("TerrainCollision") \
		and (hit.position as Vector3).distance_to(expected) <= WORKING_SUPPORT_RAY_ERROR_M


func _dispose(ctx: Dictionary) -> void:
	ctx.entry.queue_free()
	await get_tree().process_frame
	for detached: Node in ctx.detached:
		if is_instance_valid(detached):
			detached.free()
	await get_tree().physics_frame


func _v(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _case(id: String, data: Dictionary) -> void:
	_cases += 1
	data["id"] = id
	data["kind"] = "ordinary-private-integration"
	_emit("case", data)


func _emit(kind: String, data: Dictionary) -> void:
	var line: String = "HILLSIDE_PRIVATE_PLAY_RECORD " + JSON.stringify({"kind": kind, "data": data}, "", true, true)
	if line.to_utf8_buffer().size() + 1 > 4096:
		_failures += 1
		push_error("Private integration record exceeded the retained 4096-byte line cap.")
		return
	print(line)


func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
	return ok
