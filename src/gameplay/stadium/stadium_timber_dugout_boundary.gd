class_name StadiumTimberDugoutBoundary
extends StadiumDugoutBoundary
## Narrow roofless ST032 graph and real sphere adapter for the Pool Party recipe.
## The cold construction validator owns model identity. No collider is invented here.
## Same sweep primitive and event order as StadiumNpcRetainedClubSweep. Actual bodies
## alone supply NPC provenance; an opening/exterior graph crossing cannot invent it.

const QUERY_MASK: int = StadiumClubBoundaryStudy.QUERY_MASK
const CONTACT_EPS_M: float = StadiumHeightSweep.CONTACT_EPS_M


static func candidate(shape: String) -> StadiumTimberDugoutBoundary:
	if shape != "straight":
		return null
	var result: StadiumTimberDugoutBoundary = StadiumTimberDugoutBoundary.new()
	result._shape = shape
	return result


func identity() -> String:
	return "PERIM-POOL-PARTY-TIMBER-STRAIGHT-v1"


func segments() -> Array[Dictionary]:
	var rows: Array[Dictionary] = super.segments()
	for row: Dictionary in rows:
		if row.role == "DUGOUT_OPENING_DEAD":
			row.height = StadiumTimberDugoutContract.ENTRY_HEIGHT
	return rows


static func ball_radius(ball: BattedBallBody) -> float:
	# Use the actual collision sphere, rejecting a stale aero radius or scaled ball.
	if not is_instance_valid(ball) or not ball.is_inside_tree() \
		or not StadiumPoolPartyAssetIntegrity.rigid(ball.global_transform):
		return 0
	var shapes: Array[Node] = ball.find_children("*", "CollisionShape3D", true, false)
	if shapes.size() != 1:
		return 0
	var collider: CollisionShape3D = shapes[0] as CollisionShape3D
	if collider == null or collider.disabled or collider.get_parent() != ball \
		or collider.transform != Transform3D.IDENTITY or not collider.shape is SphereShape3D:
		return 0
	var radius: float = collider.shape.radius
	if not is_finite(radius) or radius <= 0 or not is_equal_approx(radius, ball.radius_m):
		return 0
	return radius


static func event(boundary: Node3D, graph: StadiumTimberDugoutBoundary,
	bodies: Array[StaticBody3D], previous: Vector3, current: Vector3,
	radius: float) -> Dictionary:
	if not is_instance_valid(boundary) or not boundary.is_inside_tree() or graph == null \
		or graph.get_script() != StadiumTimberDugoutBoundary or graph._shape != "straight" \
		or boundary.global_transform != Transform3D.IDENTITY or bodies.is_empty() \
		or not previous.is_finite() or not current.is_finite() \
		or not is_finite(radius) or radius <= 0:
		return {}
	var candidates: Array[Dictionary] = []
	for body: StaticBody3D in bodies:
		if not is_instance_valid(body) or not boundary.is_ancestor_of(body) \
			or not body.is_inside_tree() or (body.collision_layer & QUERY_MASK) == 0 \
			or not _tagged(body):
			return {}
	var crossing: Dictionary = graph.crossing(previous, current)
	if not crossing.is_empty():
		crossing["kind"] = "boundary"
		candidates.append(crossing)
	for body: StaticBody3D in bodies:
		var hit: Dictionary = _contact(boundary, body, bodies, previous, current, radius)
		if not hit.is_empty():
			candidates.append(hit)
	var distance: float = previous.distance_to(current)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return precedes(a, b, distance))
	return {} if candidates.is_empty() else candidates[0]


static func precedes(a: Dictionary, b: Dictionary, distance: float) -> bool:
	# Closed solids own coincident aperture edges. No roof participates for ST032.
	if absf(a.fraction - b.fraction) * maxf(distance, 1.0) <= CONTACT_EPS_M:
		if a.get("swept_contact", false) != b.get("swept_contact", false):
			return a.get("swept_contact", false)
		return a.priority > b.priority if a.priority != b.priority else a.segment < b.segment
	return a.fraction < b.fraction


static func _contact(boundary: Node3D, body: StaticBody3D,
	bodies: Array[StaticBody3D], previous: Vector3, current: Vector3,
	radius: float) -> Dictionary:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.shape.margin = 0
	query.margin = 0
	query.collision_mask = QUERY_MASK
	query.transform.origin = previous
	var excluded: Array[RID] = []
	for other: StaticBody3D in bodies:
		if other != body:
			excluded.append(other.get_rid())
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = boundary.get_world_3d().direct_space_state
	if body.get_meta("surface_role") == "DUGOUT_FACE_LIVE":
		return _front_contact(space, query, body, previous, current, radius)
	var fraction: float = 0
	if space.intersect_shape(query, 1).is_empty():
		query.motion = current - previous
		var motion: PackedFloat32Array = space.cast_motion(query)
		if motion.size() != 2 or motion[0] >= 1:
			return {}
		fraction = motion[1]
	return contact_event(body, previous.lerp(current, fraction), fraction)


static func _front_contact(space: PhysicsDirectSpaceState3D,
	query: PhysicsShapeQueryParameters3D, body: StaticBody3D,
	previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	var collider: CollisionShape3D = body.get_node_or_null("Shape") as CollisionShape3D
	if collider == null or collider.disabled or not collider.shape is BoxShape3D:
		return {}
	# Broad phase only: never install this sphere-expanded box as a collider.
	# Long edge-aligned cast_motion queries can report contacts metres beyond the
	# thin timber. Rebase the unchanged native sphere query to its actual box span.
	var inverse: Transform3D = collider.global_transform.affine_inverse()
	var from: Vector3 = inverse * previous
	var to: Vector3 = inverse * current
	var bounds: AABB = AABB(-collider.shape.size / 2, collider.shape.size).grow(radius)
	var first: Variant = bounds.intersects_segment(from, to)
	var last: Variant = bounds.intersects_segment(to, from)
	if first == null or last == null:
		return {}
	var motion_local: Vector3 = to - from
	var length_squared: float = motion_local.length_squared()
	var begin: float = 0
	var end: float = 1
	if length_squared > 0:
		begin = 0 if bounds.has_point(from) else clampf((first - from).dot(motion_local)
			/ length_squared, 0, 1)
		end = 1 if bounds.has_point(to) else clampf((last - from).dot(motion_local)
			/ length_squared, 0, 1)
		var tolerance: float = CONTACT_EPS_M / sqrt(length_squared)
		begin = maxf(0, begin - tolerance)
		end = minf(1, end + tolerance)
	if begin > end:
		return {}
	var start: Vector3 = previous.lerp(current, begin)
	var finish: Vector3 = previous.lerp(current, end)
	query.transform.origin = start
	query.motion = Vector3.ZERO
	if _witness(space, query, body):
		return contact_event(body, start, begin)
	query.motion = finish - start
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() != 2 or fractions[0] >= 1:
		return {}
	var fraction: float = lerpf(begin, end, fractions[1])
	# Verify the body at the unsafe endpoint, using the existing metre tolerance
	# only to enter the contact. Never trust a cast fraction with no real owner.
	var advance: float = CONTACT_EPS_M / maxf(previous.distance_to(current), CONTACT_EPS_M)
	query.transform.origin = previous.lerp(current, minf(end, fraction + advance))
	query.motion = Vector3.ZERO
	if not _witness(space, query, body):
		return {}
	return contact_event(body, previous.lerp(current, fraction), fraction)


static func _witness(space: PhysicsDirectSpaceState3D,
	query: PhysicsShapeQueryParameters3D, body: StaticBody3D) -> bool:
	var hit: Dictionary = space.get_rest_info(query)
	return not hit.is_empty() and int(hit.get("collider_id", 0)) == body.get_instance_id()


static func contact_event(body: StaticBody3D, position: Vector3,
	fraction: float) -> Dictionary:
	if not is_instance_valid(body) or not _tagged(body) or not position.is_finite() \
		or not is_finite(fraction) or fraction < 0 or fraction > 1:
		return {}
	var role: String = body.get_meta("surface_role")
	if body.get_meta("surface_kind") == "pole":
		if not body.has_meta("wall_cap_height"):
			return {}
		role = StadiumFoulPoleModels.role_at(clampf(position.y, 0, StadiumFoulPoleSites.HEIGHT),
			body.get_meta("wall_cap_height"))
	var result: Dictionary = {"segment": body.get_meta("club_surface"), "role": role,
		"position": position, "fraction": fraction, "priority": body.get_meta("surface_priority"),
		"kind": body.get_meta("surface_kind"), "swept_contact": true}
	if body.has_meta("npc_instance"):
		result["npc_instance"] = body.get_meta("npc_instance")
		result["surface"] = body.get_meta("surface_id", "")
	return result


static func _tagged(body: StaticBody3D) -> bool:
	return body.get_meta("club_surface", null) is String \
		and not String(body.get_meta("club_surface", "")).is_empty() \
		and body.get_meta("surface_role", null) is String \
		and body.get_meta("surface_priority", null) is int \
		and body.get_meta("surface_kind", null) in ["boundary", "dugout", "pole", "receiver"] \
		and body.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL"
