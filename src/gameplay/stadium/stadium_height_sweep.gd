class_name StadiumHeightSweep
extends RefCounted
## Candidate-only real sphere sweeps. Query each joined prism so callback order cannot pick a wall.

const BOUNDARY_MASK: int = 16
const CONTACT_EPS_M: float = 0.00001


static func event(boundary: StadiumHeightBoundaryBody, previous: Vector3,
	current: Vector3, radius: float = 0.0365) -> Dictionary:
	if boundary == null or not boundary.is_inside_tree() or not previous.is_finite() \
		or not current.is_finite() or not is_finite(radius) or radius <= 0 \
		or not boundary.graph is StadiumHeightBoundary \
		or not boundary.global_transform.is_equal_approx(Transform3D.IDENTITY):
		return {}
	var graph: StadiumRecipeBoundary = boundary.graph
	var crossing: Dictionary = graph.crossing(previous, current)
	var candidates: Array[Dictionary] = []
	if not crossing.is_empty():
		candidates.append(crossing)
	var bodies: Array[StaticBody3D] = []
	for node: Node in boundary.get_children():
		if node is StaticBody3D and node.has_meta("boundary_segment"):
			bodies.append(node)
	for body: StaticBody3D in bodies:
		var contact: Dictionary = _contact(boundary, body, bodies, previous, current, radius)
		if not contact.is_empty():
			candidates.append(contact)
	var length: float = previous.distance_to(current)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(a.fraction - b.fraction) * maxf(length, 1.0) <= CONTACT_EPS_M:
			var a_contact: bool = a.get("swept_contact", false)
			var b_contact: bool = b.get("swept_contact", false)
			if a_contact != b_contact:
				return a_contact
			return a.priority > b.priority if a.priority != b.priority else a.segment < b.segment
		return a.fraction < b.fraction)
	return {} if candidates.is_empty() else candidates[0]


static func _contact(boundary: StadiumHeightBoundaryBody, body: StaticBody3D,
	bodies: Array[StaticBody3D], previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.shape.margin = 0.0
	query.margin = 0
	query.collision_mask = BOUNDARY_MASK
	query.transform.origin = previous
	var excluded: Array[RID] = []
	for other: StaticBody3D in bodies:
		if other != body:
			excluded.append(other.get_rid())
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = boundary.get_world_3d().direct_space_state
	var overlaps: Array[Dictionary] = space.intersect_shape(query, 1)
	var fraction: float = 0.0
	if overlaps.is_empty():
		query.motion = current - previous
		var motion: PackedFloat32Array = space.cast_motion(query)
		if motion.size() != 2 or motion[0] >= 1.0:
			return {}
		fraction = motion[1]
	var row: Dictionary = boundary.graph.segment(body.get_meta("boundary_segment"))
	return {"segment": row.id, "role": row.role, "position": previous.lerp(current, fraction),
		"fraction": fraction, "priority": row.priority, "swept_contact": true}


static func observe(boundary: StadiumHeightBoundaryBody, resolver: BallPlayResolver,
	previous: Vector3, current: Vector3) -> Dictionary:
	if boundary == null or resolver == null or resolver.state == null \
		or resolver.state.dead or resolver.field == null:
		return {}
	var selected: Dictionary = event(boundary, previous, current)
	var end: Vector3 = current if selected.is_empty() else selected.position
	if not resolver.state.is_foul_play:
		StadiumBoundaryObserver._bands(resolver, previous, end)
	if not selected.is_empty():
		boundary.graph.apply(resolver, selected)
	return selected
