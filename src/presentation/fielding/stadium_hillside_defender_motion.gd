class_name StadiumHillsideDefenderMotion
extends "res://src/presentation/fielding/stadium_hillside_motion_support.gd"
## Private Working support/path binding for the actual primary controller.
## Read-only advisory tracking shares movement geometry, never ball-control authority.
## No public venue admission lives here.

const SUPPORT_RAY_ERROR_M: float = _SUPPORT_SUPPORT_RAY_ERROR_M
const WORKING_COARSE_SUPPORT_POINTS: int = _SUPPORT_WORKING_COARSE_SUPPORT_POINTS
const WORKING_MAX_FORECAST_SECONDS: float = _SUPPORT_WORKING_MAX_FORECAST_SECONDS
const WORKING_REPLAN_SECONDS: float = _SUPPORT_WORKING_REPLAN_SECONDS


func configure(
	fielder: FielderController,
	field: FieldDefinition,
	terrain: Node3D,
	index: int,
	requested_profile: String,
	public_owner: StadiumNpcPublicProperty = null
) -> bool:
	_public_owner = public_owner
	if (
		public_owner != null
		and (
			not is_instance_valid(public_owner)
			or not public_owner.hillside_owner_intact()
			or public_owner.field != field
			or public_owner.construction.terrain != terrain
			or fielder.stadium_boundary_clip != Callable(public_owner, "clip")
		)
	):
		return fail(fielder, "The captured public Hillside owner does not match.")
	if (
		fielder.active
		or field == null
		or not is_instance_valid(terrain)
		or not StadiumHillsideTerrain.PROFILES.has(requested_profile)
		or not fielder.stadium_boundary_clip.is_valid()
		or fielder.stadium_boundary_clip.get_method() != &"clip"
		or (
			public_owner == null
			and not fielder.stadium_boundary_clip.get_object() is StadiumRecipeBoundary
		)
	):
		return fail(
			fielder, "Idle field, retained terrain/profile and recipe boundary are required."
		)
	_field = field
	_terrain = terrain
	profile = requested_profile
	_signature = StadiumHillsideTerrain.signature(profile)
	_body = terrain.get_node_or_null("TerrainCollision") as StaticBody3D
	_shape_node = (
		terrain.get_node_or_null("TerrainCollision/ClosedTerrainShape") as CollisionShape3D
	)
	_shape = _shape_node.shape as ConcavePolygonShape3D if _shape_node != null else null
	_boundary_clip = fielder.stadium_boundary_clip
	_boundary = (
		public_owner.boundary.graph
		if public_owner != null
		else (_boundary_clip.get_object() as StadiumRecipeBoundary)
	)
	_boundary_polygon = _boundary.polygon()
	var record: Dictionary = StadiumHillsideAnchorContract.anchor(field, index, profile)
	if record.is_empty() or not bool(record.get("available", false)):
		return fail(fielder, "The requested existing anchor slot is unavailable or invalid.")
	var at: Vector3 = record["position"]
	if not _structure_valid(fielder) or not _legal_origin(at) or not _physical_support(fielder, at):
		return fail(fielder, "The selected anchor lacks legal matching retained support.")
	anchor_index = index
	fielder.anchor_position = at
	fielder.target_position = at
	fielder.global_position = at
	fielder.velocity = Vector3.ZERO
	fielder.reset_stadium_pool_routes()
	accept_position(at)
	blocked = false
	last_error = ""
	_bound_fielder = fielder
	reset_tracking()
	return true


func guard(fielder: FielderController) -> bool:
	if blocked:
		return fail(fielder, last_error)
	if last_tracking_plan != null and not tracking_context_valid(fielder):
		return fail(fielder, "The automatic primary lost its exact private owner context.")
	if (
		not _structure_valid(fielder)
		or not _legal_origin(fielder.global_position)
		or not _physical_support(fielder, fielder.global_position)
	):
		return fail(fielder, "Bound terrain, boundary or sampled physical support changed.")
	accept_position(fielder.global_position)
	return true


func set_anchor(fielder: FielderController, requested: Vector3) -> bool:
	if not guard(fielder):
		return false
	var record: Dictionary = _anchor_support(requested)
	if record.is_empty():
		last_error = "The requested anchor is nonfinite, unavailable or outside legal support."
		return false
	var at: Vector3 = record["position"]
	if not _physical_support(fielder, at):
		return fail(fielder, "The requested anchor has no matching bound physical support.")
	fielder.anchor_position = at
	fielder.target_position = at
	anchor_index = int(record["index"])
	if not fielder.active:
		fielder.global_position = at
		accept_position(at)
	last_error = ""
	return true


func reset_anchor(fielder: FielderController) -> bool:
	# Explicit begin/end reset may recover restored support; a tick never can.
	var record: Dictionary = _anchor_support(fielder.anchor_position)
	if record.is_empty() or not _structure_valid(fielder):
		return fail(fielder, "Stored anchor or terrain binding failed explicit reset validation.")
	var at: Vector3 = record["position"]
	if not _physical_support(fielder, at):
		return fail(fielder, "Stored anchor has no matching physical support at reset.")
	fielder.anchor_position = at
	fielder.global_position = at
	fielder.target_position = at
	fielder.velocity = Vector3.ZERO
	anchor_index = int(record["index"])
	accept_position(at)
	blocked = false
	last_error = ""
	reset_tracking()
	return true


func candidate(
	fielder: FielderController, previous: Vector3, proposed: Vector3, budget: float
) -> Dictionary:
	if not proposed.is_finite() or not is_finite(budget) or budget < 0:
		fail(fielder, "Movement requires finite nonnegative budget and endpoint.")
		return {}
	if profile == "flat-control":
		return finish_path(fielder, [previous, proposed], budget)
	var heading: Vector2 = Vector2(proposed.x - previous.x, proposed.z - previous.z)
	var result: Dictionary = surface_path(fielder, previous, heading, budget)
	if result.is_empty():
		return {}
	var path: Array[Vector3] = [previous]
	var limit: float = heading.length()
	for index in range(1, result.path.size()):
		var point_value: Vector3 = result.path[index]
		if Vector2(point_value.x - previous.x, point_value.z - previous.z).length() >= limit:
			var record: Dictionary = StadiumHillsideAnchorContract.support(
				Vector2(proposed.x, proposed.z), profile
			)
			if record.is_empty():
				fail(fielder, "The legal candidate has no sampled support.")
				return {}
			path.append(record["position"])
			break
		path.append(point_value)
	return finish_path(fielder, path, budget)


func surface_path(
	fielder: FielderController, previous: Vector3, heading: Vector2, budget: float
) -> Dictionary:
	var result: Dictionary = StadiumHillsideLocomotion.step(previous, heading, budget, profile)
	if result.is_empty():
		fail(fielder, "The retained surface arc step rejected this movement.")
		return {}
	# Only the ultimately accepted prefix is queried by finish_path. A clipped-away
	# suffix does not become a support requirement for a movement that never uses it.
	return result


func finish_path(fielder: FielderController, path: Array, budget: float) -> Dictionary:
	if path.is_empty():
		fail(fielder, "An empty supported path cannot be committed.")
		return {}
	var travel: float = 0.0
	for index in range(path.size()):
		var at: Vector3 = path[index]
		if not _legal_origin(at) or not _physical_support(fielder, at):
			fail(fielder, "The accepted path left legal matching support.")
			return {}
		if index == 0:
			continue
		var before: Vector3 = path[index - 1]
		if at != before and not StadiumDefenderRoutes.clear(before, at, fielder.stadium_obstacles):
			fail(fielder, "The supported prefix violates an existing obstacle footprint.")
			return {}
		if at != before and fielder.pitcher_lane_z != INF:
			var other: Vector3 = (
				fielder.pitcher_defender.global_position
				if is_instance_valid(fielder.pitcher_defender)
				else Vector3(0, 0, fielder.pitcher_lane_z)
			)
			if (
				DefenderSpacing.segment_distance_xz(other, before, at)
				< DefenderSpacing.MOUND_CLEARANCE_M
			):
				fail(fielder, "The supported prefix violates existing defender separation.")
				return {}
		travel += before.distance_to(at)
	last_path = {"position": path[-1], "path": path.duplicate(), "travel": travel, "budget": budget}
	return last_path


func supported_point(fielder: FielderController, point_value: Vector3) -> Vector3:
	var record: Dictionary = StadiumHillsideAnchorContract.support(
		Vector2(point_value.x, point_value.z), profile
	)
	if record.is_empty() or not _physical_support(fielder, record["position"]):
		fail(fielder, "A clipped endpoint has no matching sampled support.")
		return Vector3.INF
	return record["position"]


func support_record(context: FielderController, xz: Vector2) -> Dictionary:
	# A read-only control query: never guard, fail, accept a pose or change a latch/path.
	if (
		blocked
		or presentation_active
		or not is_instance_valid(context)
		or context.is_queued_for_deletion()
		or not xz.is_finite()
	):
		return {}
	var feet: Vector3
	if _pitcher_context_motion != null:
		if (
			context != _pitcher_context
			or not is_instance_valid(_pitcher_actor)
			or not _pitcher_actor.get_parent() is PitchBatLab
		):
			return {}
		var lab: PitchBatLab = _pitcher_actor.get_parent() as PitchBatLab
		if (
			lab.hillside_pitcher_motion != self
			or not _pitcher_structure_valid(lab)
			or _pitcher_actor.global_basis != Basis.IDENTITY
		):
			return {}
		feet = _pitcher_actor.global_position
	else:
		if (
			context != _bound_fielder
			or context.hillside_motion != self
			or not _structure_valid(context)
		):
			return {}
		feet = context.global_position
	return _support_record_for_feet(context, xz, feet)


func _support_record_for_feet(
	context: FielderController, xz: Vector2, feet: Vector3
) -> Dictionary:
	if not _legal_origin(feet) or not _physical_support(context, feet):
		return {}
	var record: Dictionary = StadiumHillsideAnchorContract.support(xz, profile)
	if record.is_empty() or not _physical_support(context, record["position"]):
		return {}
	return record


func configure_pitcher(lab: PitchBatLab, public_owner: StadiumNpcPublicProperty = null) -> bool:
	_public_owner = public_owner
	if (
		not is_instance_valid(lab)
		or not lab.is_inside_tree()
		or lab.global_transform != Transform3D.IDENTITY
		or not is_instance_valid(lab._pitcher_marker)
		or not is_instance_valid(lab._primary_fielder)
		or lab._primary_fielder.active
		or is_instance_valid(lab._batted_ball)
		or not StadiumPropertyRuntime.authoring_delivery_idle(lab)
		or not _pitcher_context_allowed(lab)
	):
		return fail_pitcher("Pitcher binding requires an idle private lab and its actual actors.")
	var shared: StadiumHillsideDefenderMotion = lab._primary_fielder.hillside_motion
	if (
		shared == null
		or shared == self
		or shared.blocked
		or shared._field != lab._field_definition
		or shared._public_owner != _public_owner
	):
		return fail_pitcher("A separate valid primary Hillside binding is required.")
	_pitcher_actor = lab._pitcher_marker
	_pitcher_context = lab._primary_fielder
	_pitcher_context_motion = shared
	_field = shared._field
	_terrain = shared._terrain
	_body = shared._body
	_shape_node = shared._shape_node
	_shape = shared._shape
	_signature = shared._signature
	profile = shared.profile
	_boundary = shared._boundary
	_boundary_polygon = shared._boundary_polygon.duplicate()
	_boundary_clip = shared._boundary_clip
	return reset_pitcher(lab)


func _pitcher_context_allowed(lab: PitchBatLab) -> bool:
	if _public_owner != null:
		return (
			is_instance_valid(_public_owner)
			and _public_owner.hillside_owner_intact()
			and _public_owner.lab_ref.get_ref() == lab
		)
	# The original private guard remains unchanged for every unbound caller.
	return (
		not lab._managed_match
		and lab._automation == null
		and lab._npc_season == null
		and lab._configured_match == null
		and not lab.has_meta("stadium_property")
		and not lab.has_meta("stadium_snapshot")
		and not lab.has_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND)
		and not lab.has_meta(StadiumNpcYardTwoRuntimeV1.PUBLIC_BOUND)
		and not lab.has_meta(StadiumNpcYardThreeRuntimeV1.PUBLIC_BOUND)
		and lab.pool_active_receipt == null
		and lab.pool_controller_active == null
		and not lab.pool_bound_startup_failed
		and not lab.yard_bound_startup_failed
		and (lab._match_state == null or lab._match_state.stadium.is_empty())
	)


func _pitcher_structure_valid(lab: PitchBatLab) -> bool:
	if (
		not is_instance_valid(lab)
		or not _pitcher_context_allowed(lab)
		or not lab.is_inside_tree()
		or lab.global_transform != Transform3D.IDENTITY
		or not is_instance_valid(_pitcher_actor)
		or _pitcher_actor.is_queued_for_deletion()
		or not _pitcher_actor.is_inside_tree()
		or lab._pitcher_marker != _pitcher_actor
		or _pitcher_actor.get_parent() != lab
		or _pitcher_actor.global_basis != _pitcher_basis
		or not is_instance_valid(_pitcher_context)
		or lab._primary_fielder != _pitcher_context
		or _pitcher_context.pitcher_defender != _pitcher_actor
		or _pitcher_actor.get_world_3d() != _pitcher_context.get_world_3d()
		or _pitcher_context.hillside_motion != _pitcher_context_motion
		or _pitcher_context_motion == null
		or _pitcher_context_motion._terrain != _terrain
		or _pitcher_context_motion._field != _field
		or lab._field_definition != _field
		or _pitcher_context_motion.profile != profile
		or _pitcher_context_motion._signature != _signature
	):
		return false
	return _structure_valid(_pitcher_context)


func guard_pitcher(lab: PitchBatLab) -> bool:
	if blocked:
		return fail_pitcher(last_error)
	if not _pitcher_structure_valid(lab):
		return fail_pitcher("Pitcher identity, context or retained terrain binding changed.")
	# The known delivery lift is presentation, never a supported route origin.
	if presentation_active:
		return false
	if last_tracking_plan != null and not tracking_context_valid(_pitcher_context, lab):
		return fail_pitcher("The automatic pitcher lost its exact private owner context.")
	if (
		not _legal_origin(_pitcher_actor.global_position)
		or not _physical_support(_pitcher_context, _pitcher_actor.global_position)
	):
		return fail_pitcher("Pitcher feet lost matching retained physical support.")
	accept_position(_pitcher_actor.global_position)
	return true


func reset_pitcher(lab: PitchBatLab) -> bool:
	if not _pitcher_structure_valid(lab):
		return fail_pitcher(
			"Pitcher reset requires the unchanged actual actor and retained support."
		)
	var record: Dictionary = StadiumHillsideAnchorContract.support(
		Vector2(lab.MOUND_ORIGIN.x, lab.MOUND_ORIGIN.z), profile
	)
	if (
		record.is_empty()
		or not _legal_origin(record["position"])
		or not _physical_support(_pitcher_context, record["position"])
	):
		return fail_pitcher("The original mound has no legal matching physical support.")
	_pitcher_actor.global_position = record["position"]
	_pitcher_actor.rotation = Vector3.ZERO
	_pitcher_basis = _pitcher_actor.global_basis
	accept_position(record["position"])
	presentation_active = false
	blocked = false
	last_error = ""
	last_path.clear()
	reset_tracking()
	return true


func begin_pitcher_presentation(lab: PitchBatLab) -> bool:
	if blocked or not _pitcher_structure_valid(lab):
		return fail_pitcher("Delivery presentation requires the unchanged bound pitcher context.")
	if not presentation_active and not guard_pitcher(lab):
		return false
	presentation_active = true
	return true


func move_pitcher(lab: PitchBatLab, target: Vector3, travel: float) -> Vector3:
	if not guard_pitcher(lab):
		if is_instance_valid(_pitcher_actor):
			return _pitcher_actor.global_position
		return _last_valid_position if _has_valid_position else PitchBatLab.MOUND_ORIGIN
	var result: Dictionary = pitcher_step_from(
		lab,
		_pitcher_actor.global_position,
		target,
		travel,
		_pitcher_context.global_position,
		_pitcher_context.stadium_obstacles
	)
	if result.is_empty():
		fail_pitcher("The bound pitcher step has no legal supported route.")
		return _pitcher_actor.global_position
	last_path = result
	accept_position(result["position"])
	return result["position"]


func pitcher_step_from(
	lab: PitchBatLab,
	from: Vector3,
	target: Vector3,
	travel: float,
	other: Vector3,
	obstacles: Array[Dictionary],
	coarse_support_points: int = 0
) -> Dictionary:
	# Read-only virtual-origin authority shared by movement and advisory queries.
	# Zero keeps the original exact physical support checks on every path point.
	if (
		blocked
		or presentation_active
		or not _pitcher_structure_valid(lab)
		or not from.is_finite()
		or not target.is_finite()
		or not other.is_finite()
		or not is_finite(travel)
		or travel < 0
		or not _legal_origin(from)
		or not _support_coordinate(from)
		or not _support_coordinate(target)
		or not _valid_obstacles(obstacles)
	):
		return {}
	if (
		coarse_support_points == 0
		and (
			not _physical_support(_pitcher_context, from)
			or not _physical_support(_pitcher_context, target)
		)
	):
		return {}
	var proposed: Vector3 = DefenderSpacing.step_around_mound(from, target, other, travel)
	var rows: Array[Dictionary] = obstacles.duplicate(true)
	rows.append({"center": other, "radius": DefenderSpacing.MOUND_CLEARANCE_M})
	if not obstacles.is_empty():
		proposed = StadiumDefenderRoutes.step(from, target, travel, rows)
	proposed = _boundary_clip.call(from, proposed)
	var path: Array[Vector3] = _candidate_path(from, proposed, travel)
	return _read_only_path(_pitcher_context, path, travel, rows, coarse_support_points)


func preview_pitcher(
	lab: PitchBatLab, target: Vector3, speed: float, delta: float, max_steps: int = 30
) -> Dictionary:
	var result: Dictionary = {
		"reached": false, "reason": "invalid", "path": [], "travel": 0.0, "elapsed": 0.0, "steps": 0
	}
	if (
		blocked
		or presentation_active
		or not _pitcher_structure_valid(lab)
		or not target.is_finite()
		or not is_finite(speed)
		or speed <= 0
		or not is_finite(delta)
		or delta <= 0
		or delta > 3.0
		or max_steps < 1
		or max_steps > 30
		or (
			Vector2(target.x - lab.MOUND_ORIGIN.x, target.z - lab.MOUND_ORIGIN.z).length()
			> PitchBatLabDefenseSupport.CHARGE_RADIUS_M
		)
	):
		return result
	var at: Vector3 = _pitcher_actor.global_position
	var other: Vector3 = _pitcher_context.global_position
	var obstacles: Array[Dictionary] = _pitcher_context.stadium_obstacles.duplicate(true)
	result.path.append(at)
	# Validate even a zero-distance request; no success on unsupported feet.
	if pitcher_step_from(lab, at, target, 0.0, other, obstacles).is_empty():
		return result
	if at == target:
		result.reached = true
		result.reason = "reached"
		return result
	return _preview_pitcher_steps(lab, target, speed, delta, max_steps, at, other, obstacles, result)


func _preview_pitcher_steps(
	lab: PitchBatLab,
	target: Vector3,
	speed: float,
	delta: float,
	max_steps: int,
	at: Vector3,
	other: Vector3,
	obstacles: Array[Dictionary],
	result: Dictionary
) -> Dictionary:
	var visited: Array[Vector3] = [at]
	for index in range(max_steps):
		if float(index + 1) * delta > 3.0:
			break
		var step: Dictionary = pitcher_step_from(lab, at, target, speed * delta, other, obstacles)
		if step.is_empty():
			result.reason = "unsupported"
			return result
		for point_index in range(1, step.path.size()):
			result.path.append(step.path[point_index])
		result.travel += float(step.travel)
		result.steps = index + 1
		result.elapsed = float(index + 1) * delta
		var next: Vector3 = step.position
		if next == target:
			result.reached = true
			result.reason = "reached"
			return result
		if next == at:
			result.reason = "stalled"
			return result
		if visited.has(next):
			result.reason = "cycle"
			return result
		visited.append(next)
		at = next
	result.reason = "horizon"
	return result


func primary_step_from(
	fielder: FielderController,
	from: Vector3,
	target: Vector3,
	travel: float,
	other: Vector3,
	obstacles: Array[Dictionary],
	coarse_support_points: int = 0
) -> Dictionary:
	# Virtual origin, frozen other-defender position and copied obstacle rows only.
	# No guard/fail/accept, actor writes, route-cache writes or resolver access.
	if (
		blocked
		or not is_instance_valid(fielder)
		or fielder != _bound_fielder
		or fielder.hillside_motion != self
		or not _structure_valid(fielder)
		or not from.is_finite()
		or not target.is_finite()
		or not is_finite(travel)
		or travel < 0
		or not _legal_origin(from)
		or not _support_coordinate(from)
		or not _valid_obstacles(obstacles)
		or (other != Vector3.INF and not other.is_finite())
	):
		return {}
	var proposed: Vector3 = from.move_toward(Vector3(target.x, from.y, target.z), travel)
	var rows: Array[Dictionary] = obstacles.duplicate(true)
	if other != Vector3.INF:
		proposed = DefenderSpacing.step_around_mound(from, target, other, travel)
		rows.append({"center": other, "radius": DefenderSpacing.MOUND_CLEARANCE_M})
	if not obstacles.is_empty():
		# Bound Hillside rejects owned-Pool rows. This is exactly the ordinary route
		# selected by owned_pool_step in that case, without its live-state clear.
		proposed = StadiumDefenderRoutes.step(from, target, travel, rows)
	proposed = _boundary_clip.call(from, proposed)
	var path: Array[Vector3] = _candidate_path(from, proposed, travel)
	return _read_only_path(fielder, path, travel, rows, coarse_support_points)


func move_primary(fielder: FielderController, target: Vector3, travel: float) -> Dictionary:
	# Only this actual-movement wrapper may fail/commit the motion binding.
	if not guard(fielder):
		return {}
	var result: Dictionary = primary_step_from(
		fielder,
		fielder.global_position,
		target,
		travel,
		_primary_other(fielder),
		fielder.stadium_obstacles
	)
	if result.is_empty():
		fail(fielder, "The bound primary step has no legal supported route.")
		return {}
	last_path = result
	accept_position(result["position"])
	return result


func tracking_context_valid(context: FielderController, pitcher_lab: PitchBatLab = null) -> bool:
	# Read-only and current even between plans: an old plan is not owner authority.
	if (
		blocked
		or presentation_active
		or not is_instance_valid(context)
		or not context.get_parent() is PitchBatLab
	):
		return false
	var lab: PitchBatLab = context.get_parent() as PitchBatLab
	if _public_owner != null:
		if (
			not is_instance_valid(_public_owner)
			or not _public_owner.hillside_tracking_valid(lab, self)
		):
			return false
	else:
		var owner: StadiumHillsidePrivateRuntime = (
			lab.get_node_or_null("HillsidePrivateRuntime") as StadiumHillsidePrivateRuntime
		)
		if owner == null or owner.get_parent() != lab or not owner.automatic_tracking_valid(lab, self):
			return false
	if pitcher_lab != null:
		return (
			pitcher_lab == lab
			and self == lab.hillside_pitcher_motion
			and _pitcher_structure_valid(lab)
		)
	return (
		context == _bound_fielder and context.hillside_motion == self and _structure_valid(context)
	)


func planning_providers(
	context: FielderController, physics_delta: float, pitcher_lab: PitchBatLab = null
) -> Dictionary:
	# Explicit standalone diagnostics do not opt into automatic pursuit. The owner
	# is validated once here, not once for each sample of this synchronous snapshot.
	if (
		not tracking_context_valid(context, pitcher_lab)
		or not is_finite(physics_delta)
		or physics_delta <= 0.0
		or physics_delta > WORKING_MAX_FORECAST_SECONDS
	):
		return {}
	var from: Vector3 = (
		context.global_position if pitcher_lab == null else _pitcher_actor.global_position
	)
	var other: Vector3 = _primary_other(context) if pitcher_lab == null else context.global_position
	if not _legal_origin(from) or not _physical_support(context, from):
		return {}
	var snapshot: Dictionary = {
		"from": from,
		"other": other,
		"obstacles": context.stadium_obstacles.duplicate(true),
		"delta": physics_delta,
		"pitcher_lab": pitcher_lab,
		"support_cache": {},
		"support_checks": 0
	}
	return {
		"support": _forecast_support.bind(context, snapshot),
		"arrival": _planning_arrival.bind(context, snapshot)
	}


func _planning_arrival(
	ball: Vector3,
	ball_feet: Vector3,
	seconds: float,
	speed: float,
	reach: float,
	stationary: bool,
	has_grounded: bool,
	context: FielderController,
	snapshot: Dictionary
) -> Dictionary:
	var result: Dictionary = {
		"reached": false,
		"reason": "invalid",
		"advisory": true,
		"position": Vector3.INF,
		"feet_target": Vector3.INF,
		"elapsed": INF,
		"coarse_steps": 0,
		"support_checks": 0,
		"support_segments": 0,
		"max_coarse_steps": 1,
		"max_support_checks": WORKING_COARSE_SUPPORT_POINTS
	}
	if (
		not ball.is_finite()
		or not ball_feet.is_finite()
		or not is_finite(seconds)
		or seconds <= 0
		or seconds > WORKING_MAX_FORECAST_SECONDS
		or not is_finite(speed)
		or speed < 0
		or not is_finite(reach)
		or reach < 0
	):
		return result
	result.support_checks = int(snapshot.support_checks)
	var from: Vector3 = snapshot.from
	var lab: PitchBatLab = snapshot.pitcher_lab
	var record: Dictionary = _planning_arrival_target(
		ball, ball_feet, context, snapshot, result, from, lab
	)
	if record.is_empty():
		return result
	var target: Vector3 = record["position"]
	var rows: Array[Dictionary] = snapshot.obstacles.duplicate(true)
	if snapshot.other != Vector3.INF:
		rows.append({"center": snapshot.other, "radius": DefenderSpacing.MOUND_CLEARANCE_M})
	var target_clear: bool = StadiumDefenderRoutes.clear(target, target, rows)
	# An obstacle-interior ball sample is not itself a legal defender feet goal.
	# A successful shared step below may provide a legal redirected endpoint.
	result.feet_target = target if target_clear else from
	result.position = from
	var allowed_height: float = (
		FieldingResolver.MAX_GROUND_CONTROL_HEIGHT_M
		if has_grounded
		else FieldingResolver.MAX_AIR_CONTROL_HEIGHT_M
	)
	if lab != null:
		allowed_height = minf(allowed_height, PitcherDefense.MAX_REACTION_HEIGHT_M)
	if _within_forecast_envelope(from, ball, ball_feet, reach, allowed_height):
		result.reached = true
		result.reason = "advisory_reached"
		result.elapsed = 0.0
		return result
	if stationary or speed == 0.0:
		result.reason = "stationary"
		return result
	var tick: float = float(snapshot.delta)
	# A coarse step consumes only complete supplied-delta intervals, bounded by
	# the existing forecast horizon. This is not a per-physics-tick simulation.
	var budget_seconds: float = floor(seconds / tick) * tick
	var lower_bound: float = maxf(0.0, Vector2(ball.x - from.x, ball.z - from.z).length() - reach)
	if lower_bound > speed * budget_seconds:
		result.reason = "lower_bound"
		return result
	var step: Dictionary = _planning_route_step(
		context, snapshot, target, speed, budget_seconds, result, from, lab
	)
	if not step.is_empty():
		result.position = step.position
		if not target_clear:
			result.feet_target = step.position
		result.elapsed = float(step.travel) / speed
		if _within_forecast_envelope(step.position, ball, ball_feet, reach, allowed_height):
			result.reached = true
			result.reason = "advisory_reached"
		else:
			result.reason = "stalled" if step.position == from else "coarse_horizon"
	return result


func _planning_arrival_target(
	ball: Vector3,
	ball_feet: Vector3,
	context: FielderController,
	snapshot: Dictionary,
	result: Dictionary,
	from: Vector3,
	lab: PitchBatLab
) -> Dictionary:
	# Eligibility belongs to the original ball sample, never a clipped substitute.
	if (
		lab != null
		and (
			Vector2(ball.x - lab.MOUND_ORIGIN.x, ball.z - lab.MOUND_ORIGIN.z).length()
			> PitchBatLabDefenseSupport.CHARGE_RADIUS_M
		)
	):
		result.reason = "charge_radius"
		return {}
	var clipped: Vector3 = _boundary_clip.call(from, ball_feet)
	var record: Dictionary = _planning_support(Vector2(clipped.x, clipped.z), context, snapshot)
	result.support_checks = int(snapshot.support_checks)
	if record.is_empty() or not _legal_origin(record["position"]):
		result.reason = "unsupported_target"
		return {}
	return record


func _planning_route_step(
	context: FielderController,
	snapshot: Dictionary,
	target: Vector3,
	speed: float,
	budget_seconds: float,
	result: Dictionary,
	from: Vector3,
	lab: PitchBatLab
) -> Dictionary:
	var step: Dictionary
	var remaining_checks: int = WORKING_COARSE_SUPPORT_POINTS - int(snapshot.support_checks)
	if remaining_checks < 2:
		result.reason = "support_budget"
		return {}
	if lab == null:
		step = primary_step_from(
			context,
			from,
			target,
			speed * budget_seconds,
			snapshot.other,
			snapshot.obstacles,
			remaining_checks
		)
	else:
		step = pitcher_step_from(
			lab,
			from,
			target,
			speed * budget_seconds,
			snapshot.other,
			snapshot.obstacles,
			remaining_checks
		)
	result.coarse_steps = 1
	if step.is_empty():
		result.reason = "unsupported_route"
		return {}
	result.support_checks = int(snapshot.support_checks) + int(step.support_checks)
	result.support_segments = int(step.support_segments)
	if not bool(step.get("valid", false)):
		result.reason = "unsupported_route"
		return {}
	return step
