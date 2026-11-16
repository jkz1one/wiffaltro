class_name StadiumWaterfallLiveRoutes
extends RefCounted
## Opt-in full-scale candidate. No existing route or collider is modified.
## Small visibility graph around the actual basin footprint, never the authoring reserve.
const VERSION: int = 1
const CENTER: Vector3 = Vector3(-10.2, 0, 19.4)
const HALF: Vector2 = Vector2(4.2, 1.9)
const BODY_RADIUS: float = 0.32
const CLEARANCE: float = 0.02
const EPS: float = 0.00001
const MAX_ACTORS: int = 2


static func footprint() -> Rect2:
	var half: Vector2 = HALF + Vector2.ONE * (BODY_RADIUS + CLEARANCE)
	return Rect2(Vector2(CENTER.x, CENTER.z) - half, half * 2.0)


static func legal(point: Vector3, graph: StadiumRecipeBoundary, actors: Array = []) -> bool:
	if graph == null or not point.is_finite() or not _actors_valid(actors):
		return false
	var flat: Vector2 = Vector2(point.x, point.z)
	if not graph.contains(flat) or _interior(flat):
		return false
	for row: Dictionary in graph.segments():
		if (
			flat.distance_to(Geometry2D.get_closest_point_to_segment(flat, row.a, row.b))
			< StadiumRecipeBoundary.DEFENDER_RADIUS
		):
			return false
	for actor: Dictionary in actors:
		if (
			flat.distance_to(Vector2(actor.center.x, actor.center.z))
			< float(actor.radius) + CLEARANCE
		):
			return false
	return true


static func clear(
	start: Vector3, finish: Vector3, graph: StadiumRecipeBoundary, actors: Array = []
) -> bool:
	if not legal(start, graph, actors) or not legal(finish, graph, actors):
		return false
	var a: Vector2 = Vector2(start.x, start.z)
	var b: Vector2 = Vector2(finish.x, finish.z)
	if _crosses_interior(a, b):
		return false
	for row: Dictionary in graph.segments():
		if (
			StadiumLandscapeOwnedItems._segment_distance(a, b, row.a, row.b)
			< StadiumRecipeBoundary.DEFENDER_RADIUS
		):
			return false
	for actor: Dictionary in actors:
		var center: Vector2 = Vector2(actor.center.x, actor.center.z)
		if (
			center.distance_to(Geometry2D.get_closest_point_to_segment(center, a, b))
			< float(actor.radius) + CLEARANCE
		):
			return false
	return true


static func plan(
	start: Vector3, target: Vector3, graph: StadiumRecipeBoundary, actors: Array = []
) -> Dictionary:
	if not legal(start, graph, actors) or not target.is_finite():
		return _error("Current defender position or actor reservation is not legal.")
	var wanted: Vector3 = Vector3(target.x, start.y, target.z)
	var nodes: Array[Vector3] = [start]
	var box: Rect2 = footprint()
	for flat: Vector2 in [
		box.position - Vector2.ONE * CLEARANCE,
		Vector2(box.end.x + CLEARANCE, box.position.y - CLEARANCE),
		box.end + Vector2.ONE * CLEARANCE,
		Vector2(box.position.x - CLEARANCE, box.end.y + CLEARANCE)
	]:
		var corner: Vector3 = Vector3(flat.x, start.y, flat.y)
		if legal(corner, graph, actors):
			nodes.append(corner)
	for actor: Dictionary in actors:
		# Circumscribed octagon; adjacent edges remain outside the exact actor circle.
		var radius: float = (float(actor.radius) + 2.0 * CLEARANCE) / cos(PI / 8.0)
		for index in range(8):
			var point: Vector3 = (
				actor.center + Vector3(cos(index * TAU / 8.0), 0, sin(index * TAU / 8.0)) * radius
			)
			point.y = start.y
			if legal(point, graph, actors):
				nodes.append(point)
	var goals: Array[int] = []
	var blocked: bool = _interior(Vector2(target.x, target.z))
	if blocked:
		for point: Vector3 in [
			Vector3(
				clampf(target.x, box.position.x, box.end.x), start.y, box.position.y - CLEARANCE
			),
			Vector3(clampf(target.x, box.position.x, box.end.x), start.y, box.end.y + CLEARANCE),
			Vector3(
				box.position.x - CLEARANCE, start.y, clampf(target.z, box.position.y, box.end.y)
			),
			Vector3(box.end.x + CLEARANCE, start.y, clampf(target.z, box.position.y, box.end.y))
		]:
			if legal(point, graph, actors):
				goals.append(nodes.size())
				nodes.append(point)
	elif legal(wanted, graph, actors):
		goals.append(nodes.size())
		nodes.append(wanted)
	if goals.is_empty():
		return _error("No legal approach exists for this target and current actors.")
	var distance: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for index in nodes.size():
		distance.append(INF)
		previous.append(-1)
		visited.append(false)
	distance[0] = 0.0
	for iteration in nodes.size():
		var chosen: int = -1
		for index in nodes.size():
			if not visited[index] and (chosen < 0 or distance[index] < distance[chosen]):
				chosen = index
		if chosen < 0 or not is_finite(distance[chosen]):
			break
		visited[chosen] = true
		for index in nodes.size():
			if visited[index] or not clear(nodes[chosen], nodes[index], graph, actors):
				continue
			var cost: float = distance[chosen] + nodes[chosen].distance_to(nodes[index])
			if cost < distance[index]:
				distance[index] = cost
				previous[index] = chosen
	var best: int = -1
	for goal: int in goals:
		if is_finite(distance[goal]) and (best < 0 or distance[goal] < distance[best]):
			best = goal
	if best < 0:
		return _error("Current full-scale obstacle and actor geometry has no proved route.")
	var route: Array[Vector3] = []
	var cursor: int = best
	while cursor >= 0:
		route.push_front(nodes[cursor])
		cursor = previous[cursor]
	return {
		"ok": true,
		"error": "",
		"path": route,
		"goal": nodes[best],
		"target_blocked": blocked,
		"approach_distance": nodes[best].distance_to(wanted)
	}


static func step(
	start: Vector3, target: Vector3, travel: float, graph: StadiumRecipeBoundary, actors: Array = []
) -> Dictionary:
	if not is_finite(travel) or travel < 0:
		return _error("Travel must be finite and nonnegative.")
	var result: Dictionary = plan(start, target, graph, actors)
	if not result.ok:
		return result
	var position: Vector3 = start
	# One physical frame is one straight segment. Stop at the first nonzero
	# waypoint rather than consuming leftover travel around a corner and cutting
	# the collision footprint with the resulting start-to-finish chord.
	for point: Vector3 in result.path:
		if position.distance_to(point) <= EPS:
			continue
		position = position.move_toward(point, travel)
		break
	result["position"] = position
	return result


static func _interior(point: Vector2) -> bool:
	var box: Rect2 = footprint()
	return (
		point.x > box.position.x + EPS
		and point.x < box.end.x - EPS
		and point.y > box.position.y + EPS
		and point.y < box.end.y - EPS
	)


static func _crosses_interior(a: Vector2, b: Vector2) -> bool:
	var box: Rect2 = footprint().grow(-EPS)
	var low: float = 0.0
	var high: float = 1.0
	for axis in range(2):
		var delta: float = b[axis] - a[axis]
		if absf(delta) < EPS:
			if a[axis] <= box.position[axis] or a[axis] >= box.end[axis]:
				return false
		else:
			var enter: float = (box.position[axis] - a[axis]) / delta
			var leave: float = (box.end[axis] - a[axis]) / delta
			low = maxf(low, minf(enter, leave))
			high = minf(high, maxf(enter, leave))
			if low >= high:
				return false
	return low < high and high > 0.0 and low < 1.0


static func _actors_valid(actors: Array) -> bool:
	if actors.size() > MAX_ACTORS:
		return false
	for actor: Variant in actors:
		if (
			not actor is Dictionary
			or not actor.get("center") is Vector3
			or not actor.center.is_finite()
			or not (actor.get("radius") is float or actor.get("radius") is int)
			or not is_finite(float(actor.radius))
			or actor.radius <= 0
		):
			return false
	return true


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
