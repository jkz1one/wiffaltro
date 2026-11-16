class_name StadiumNpcAm02PublicSweep
extends RefCounted
## AM-02 public compatibility copy of the retained Club sphere/contact algorithm.
## Uses the exact left-loft graph and unchanged retained bodies; no authoring factory.
## Only actual body contacts carry NPC identity. Graph crossings cannot invent provenance.

static func event(boundary: StadiumNpcAm02PublicBoundary, previous: Vector3,
	current: Vector3, radius: float = 0.0365) -> Dictionary:
	if boundary == null or not boundary.is_inside_tree() or boundary.graph == null \
		or not is_instance_valid(boundary.source) or not boundary.source.is_inside_tree() \
		or not boundary.source.global_transform.is_equal_approx(Transform3D.IDENTITY) \
		or not boundary.global_transform.is_equal_approx(Transform3D.IDENTITY) \
		or not previous.is_finite() or not current.is_finite() or not is_finite(radius) or radius <= 0:
		return {}
	var candidates: Array[Dictionary] = []
	var crossing: Dictionary = boundary.graph.crossing(previous, current)
	if not crossing.is_empty():
		crossing["kind"] = "boundary"
		candidates.append(crossing)
	for body: StaticBody3D in boundary.bodies:
		var hit: Dictionary = _contact(boundary, body, previous, current, radius)
		if not hit.is_empty():
			candidates.append(hit)
	var distance: float = maxf(previous.distance_to(current), 1)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(a.fraction - b.fraction) * distance <= 0.00001:
			if a.get("swept_contact", false) != b.get("swept_contact", false):
				return a.get("swept_contact", false)
			return a.priority > b.priority if a.priority != b.priority else a.segment < b.segment
		return a.fraction < b.fraction)
	return {} if candidates.is_empty() else candidates[0]


static func _contact(boundary: StadiumNpcAm02PublicBoundary, body: StaticBody3D,
	previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.shape.margin = 0
	query.margin = 0
	query.collision_mask = StadiumNpcAm02PublicBoundary.QUERY_MASK
	query.transform.origin = previous
	var excluded: Array[RID] = []
	for other: StaticBody3D in boundary.bodies:
		if other != body:
			excluded.append(other.get_rid())
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = boundary.get_world_3d().direct_space_state
	var fraction: float = 0
	if space.intersect_shape(query, 1).is_empty():
		query.motion = current - previous
		var motion: PackedFloat32Array = space.cast_motion(query)
		if motion.size() != 2 or motion[0] >= 1:
			return {}
		fraction = motion[1]
	var position: Vector3 = previous.lerp(current, fraction)
	return contact_event(body, position, fraction)


static func contact_event(body: StaticBody3D, position: Vector3, fraction: float) -> Dictionary:
	var role: String = body.get_meta("surface_role")
	if body.get_meta("surface_kind") == "pole":
		role = StadiumNpcClubPoleV1.role_at(clampf(position.y, 0, StadiumNpcClubFoulSitesV1.HEIGHT),
			body.get_meta("wall_cap_height"))
	var result: Dictionary = {"segment": body.get_meta("club_surface"), "role": role,
		"position": position, "fraction": fraction, "priority": body.get_meta("surface_priority"),
		"kind": body.get_meta("surface_kind"), "swept_contact": true}
	if body.has_meta("npc_instance"):
		result["npc_instance"] = body.get_meta("npc_instance")
		result["surface"] = body.get_meta("surface_id", "")
	return result


static func observe(boundary: StadiumNpcAm02PublicBoundary, resolver: BallPlayResolver,
	previous: Vector3, current: Vector3) -> Dictionary:
	if boundary == null or resolver == null or resolver.state == null or resolver.state.dead \
		or resolver.field == null:
		return {}
	var selected: Dictionary = event(boundary, previous, current)
	if not resolver.state.is_foul_play:
		StadiumBoundaryObserver._bands(resolver, previous,
			current if selected.is_empty() else selected.position)
	if selected.is_empty():
		boundary.last_live.erase(resolver.get_instance_id())
		return selected
	apply(boundary, resolver, selected)
	return selected


static func apply(boundary: StadiumNpcAm02PublicBoundary, resolver: BallPlayResolver,
	selected: Dictionary) -> void:
	if resolver.state.dead:
		return
	var id: int = resolver.get_instance_id()
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
			StadiumNpcClubDugoutGraphV1.dead_area(resolver, selected.position, &"dugout_terminal")
