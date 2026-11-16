class_name StadiumPoolPartyPublicSweep
extends RefCounted
## Genuine ball-sphere geometry plus existing owned-Pool top-entry arithmetic.
## Solid and terminal graph events are ordered before water; model ownership is external.


static func event(boundary: StadiumPoolPartyPublicBoundary, previous: Vector3,
	current: Vector3, radius: float) -> Dictionary:
	if boundary == null or radius <= 0 or not boundary.is_inside_tree() \
		or not is_instance_valid(boundary.pool_model) \
		or boundary.pool_model.global_transform != StadiumPoolContract.placement():
		return {}
	var selected: Dictionary = StadiumTimberDugoutBoundary.event(
		boundary.source, boundary.graph, boundary.bodies, previous, current, radius)
	var distance: float = maxf(previous.distance_to(current), 1)
	var near_pool: bool = maxf(previous.x, current.x) + radius >= 9.5 \
		and minf(previous.x, current.x) - radius <= 14.5 \
		and maxf(previous.z, current.z) + radius >= 15.5 \
		and minf(previous.z, current.z) - radius <= 20.5
	for body: StaticBody3D in boundary.pool_bodies if near_pool else []:
		var hit: Dictionary = _pool_contact(boundary, body, previous, current, radius)
		if not boundary.get_parent().callback_intact():
			return {}
		if not hit.is_empty() and (selected.is_empty() \
			or StadiumTimberDugoutBoundary.precedes(hit, selected, distance)):
			selected = hit
	var entry: Dictionary = StadiumPoolOwnedFreeflight.evaluate(
		StadiumPoolContract.placement(), previous, current, radius)
	if entry.get("status") == "ENTRY":
		var water: Dictionary = {"segment": StadiumPoolInteriorV2.VOLUME_ID,
			"role": "POOL_WATER", "position": entry.position, "fraction": entry.fraction,
			"priority": -1, "kind": "water", "swept_contact": false}
		if selected.is_empty() or StadiumTimberDugoutBoundary.precedes(water, selected, distance):
			selected = water
	return selected


static func _pool_contact(boundary: StadiumPoolPartyPublicBoundary, body: StaticBody3D,
	previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.shape.margin = 0
	query.margin = 0
	query.collision_mask = body.collision_layer
	query.transform.origin = previous
	if not previous.is_finite() or not current.is_finite():
		return {}
	if not boundary.pool_query_exclusions.has(body.get_instance_id()) \
		or boundary.pool_query_exclusions[body.get_instance_id()].has(body.get_rid()):
		boundary.get_parent().retire_installation("pool query body exclusion mismatch")
		return {}
	query.exclude = boundary.pool_query_exclusions[body.get_instance_id()]
	var space: PhysicsDirectSpaceState3D = boundary.get_world_3d().direct_space_state
	var overlaps: Array[Dictionary] = space.intersect_shape(query, 1)
	if not overlaps.is_empty():
		if overlaps[0].get("collider") != body or overlaps[0].get("rid") != body.get_rid():
			boundary.get_parent().retire_installation("pool overlap collider witness mismatch")
			return {}
		return pool_contact_event(body, previous, 0)
	query.motion = current - previous
	var motion: PackedFloat32Array = space.cast_motion(query)
	if motion.size() != 2 or motion[0] >= 1:
		return {}
	# Match the retained receiver query: an unsafe-fraction native rest witness names the body.
	query.transform.origin = previous.lerp(current, minf(1, motion[1] + 0.0001))
	query.motion = Vector3.ZERO
	var witness: Dictionary = space.get_rest_info(query)
	if witness.is_empty() or witness.get("collider_id", 0) != body.get_instance_id() \
		or witness.get("rid") != body.get_rid() or not witness.get("point") is Vector3:
		boundary.get_parent().retire_installation("pool swept collider witness mismatch")
		return {}
	return pool_contact_event(body, witness.point, motion[0])


static func pool_contact_event(body: StaticBody3D, position: Vector3,
	fraction: float) -> Dictionary:
	return {"segment": String(body.name), "surface": String(body.name),
		"role": "LIVE_RICOCHET", "position": position, "fraction": fraction,
		"priority": 400, "kind": "pool", "swept_contact": true,
		"npc_instance": StadiumPoolPartyRuntime.COPY}


static func observe(boundary: StadiumPoolPartyPublicBoundary, resolver: BallPlayResolver,
	previous: Vector3, current: Vector3) -> Dictionary:
	if boundary == null or resolver == null or resolver.state == null or resolver.state.dead:
		return {}
	var ball: BattedBallBody = boundary.actual_ball(resolver)
	var radius: float = StadiumTimberDugoutBoundary.ball_radius(ball)
	var property: StadiumNpcPublicProperty = boundary.get_parent() as StadiumNpcPublicProperty
	if radius <= 0 or property == null or not property._contact_dispatch \
		or current != ball.global_position:
		return {}
	var selected: Dictionary = event(boundary, previous, current, radius)
	if not property.callback_intact():
		return {}
	if not resolver.state.is_foul_play:
		StadiumBoundaryObserver._bands(resolver, previous,
			current if selected.is_empty() else selected.position)
	if selected.is_empty():
		boundary.last_live.erase(resolver.get_instance_id())
		return selected
	if selected.kind == "water":
		boundary._water_witness = selected.duplicate(true)
	apply(boundary, resolver, selected)
	boundary._water_witness.clear()
	return selected


static func apply(boundary: StadiumPoolPartyPublicBoundary, resolver: BallPlayResolver,
	selected: Dictionary) -> void:
	if resolver.state == null or resolver.state.dead:
		return
	var id: int = resolver.get_instance_id()
	if selected.kind == "water":
		boundary.resolve_water(resolver, selected)
		return
	# A swept solid blocks any later same-step water dispatch too.
	boundary._solid_frame = Engine.get_physics_frames()
	if selected.kind == "pool":
		if boundary.last_live.get(id, "") == selected.segment:
			return
		boundary.last_live[id] = selected.segment
		boundary.contact_applied.emit(selected, resolver)
		resolver.state.record_stadium_contact("item", StadiumPoolPartyRuntime.COPY,
			selected.surface, "LIVE_RICOCHET", selected.position, "contact")
		return
	if selected.role in ["DUGOUT_FACE_LIVE", "SIDE_RETURN_LIVE"]:
		if boundary.last_live.get(id, "") == selected.segment:
			return
		boundary.last_live[id] = selected.segment
	else:
		boundary.last_live.erase(id)
	boundary.contact_applied.emit(selected, resolver)
	if selected.kind == "boundary" or selected.role == "DUGOUT_FACE_LIVE":
		boundary.graph.apply(resolver, selected)
	else:
		resolver.state.record_stadium_contact("boundary", boundary.graph.identity(), selected.segment,
			selected.role, selected.position, "contact")
		if selected.kind == "pole":
			resolver.state.is_foul_play = false
			resolver.state.is_fair = true
			if selected.role == "FOUL_POLE_UPPER" and not resolver.state.has_grounded \
				and not resolver.state.defender_touched:
				resolver.state.raise_result_floor(BallPlayState.ResultFloor.HOME_RUN)
				resolver._resolve_floor(&"foul_pole_upper", selected.position)
			else:
				resolver.record_back_wall_contact(selected.position)
		elif selected.kind == "receiver":
			resolver._resolve_foul(&"stadium_receiver", selected.position)
		else:
			StadiumDugoutBoundary.dead_area(resolver, selected.position, &"dugout_terminal")
