class_name StadiumDefenderRoutes
extends RefCounted
## Deterministic Working routes around the short starter models.
## Avatar torso radius0.28 +0.04 margin; hands begin above their0.95m maximum height.

const BODY_RADIUS: float = 0.32
const POOL_RING_MARGIN: float = 0.02


static func clear(start: Vector3, finish: Vector3, obstacles: Array[Dictionary]) -> bool:
	for obstacle: Dictionary in obstacles:
		if DefenderSpacing.segment_distance_xz(obstacle.center, start, finish) < obstacle.radius:
			return false
	return true


static func step(current: Vector3, target: Vector3, travel: float,
	obstacles: Array[Dictionary]) -> Vector3:
	var goal: Vector3 = target
	goal.y = current.y
	for obstacle: Dictionary in obstacles:
		var center: Vector3 = Vector3(obstacle.center.x, current.y, obstacle.center.z)
		var radial: Vector3 = goal - center
		if radial.length() < obstacle.radius + 0.02:
			if radial.length_squared() < 0.000001:
				radial = current - center
			if radial.length_squared() < 0.000001:
				radial = Vector3.RIGHT
			goal = center + radial.normalized() * (obstacle.radius + 0.02)
	var motion: Vector3 = goal - current
	var distance: float = minf(maxf(travel, 0), motion.length())
	if distance <= 0.000001:
		return current
	motion = motion.normalized() * distance
	if clear(current, current + motion, obstacles):
		return current + motion
	var best: Vector3 = current
	var best_distance: float = INF
	for index in range(72):
		var candidate: Vector3 = current + motion.rotated(Vector3.UP, index * TAU / 72.0)
		if not clear(current, candidate, obstacles):
			continue
		var remaining: float = candidate.distance_squared_to(goal)
		if remaining < best_distance:
			best = candidate
			best_distance = remaining
	return best


static func clip(current: Vector3, proposed: Vector3, obstacles: Array[Dictionary]) -> Vector3:
	if clear(current, proposed, obstacles):
		return proposed
	var low: float = 0
	var high: float = 1
	for iteration in range(24):
		var middle: float = (low + high) * 0.5
		if clear(current, current.lerp(proposed, middle), obstacles):
			low = middle
		else:
			high = middle
	return current.lerp(proposed, low)


## Opt-in only for the paid owned-Pool property. The ordinary route stays byte-identical.
## State is one transient waypoint, never a path cache or authority to bypass clear/clip.
static func owned_pool_step(current: Vector3, target: Vector3, travel: float,
	obstacles: Array[Dictionary], state: Dictionary) -> Vector3:
	var pool: Dictionary = {}
	for obstacle: Dictionary in obstacles:
		if obstacle.get("owned_pool") is bool and obstacle.get("owned_pool") == true:
			if not pool.is_empty():
				state.clear()
				return current
			pool = obstacle
	if pool.is_empty():
		state.clear()
		return step(current, target, travel, obstacles)
	if not current.is_finite() or not target.is_finite() or not is_finite(travel) \
		or not _owned_pool_inside(current):
		state.clear()
		return current
	var goal: Vector3 = _owned_pool_goal(current, target, obstacles)
	# A target outside the fence is approached only as far as its legal segment.
	goal = StadiumBoundaryGraph.clip(current, goal)
	if not _owned_pool_state_valid(state) or state.get("obstacles", []) != obstacles:
		state.clear()
	if not state.is_empty() and (goal.distance_to(state.target) >= 0.5 \
		and (goal - current).dot(state.direction) <= 0):
		state.clear()
	if clear(current, goal, obstacles):
		state.clear()
		return current.move_toward(goal, maxf(travel, 0))
	if not state.is_empty() and (not _owned_pool_inside(state.waypoint) \
		or not clear(state.waypoint, state.waypoint, obstacles) \
		or current.distance_to(state.waypoint) <= maxf(travel, 0.05)):
		state.clear()
	if not state.is_empty():
		return _owned_pool_legal_step(current, state.waypoint, travel, obstacles)
	var next: Vector3 = _owned_pool_legal_step(current, goal, travel, obstacles)
	# A moving second defender invalidates the old commitment every frame. Rebuild
	# the same inward choice from CURRENT geometry while the Pool's ring is cut by
	# the fence and the actors lie on opposite boundary-tangent sides of the Pool.
	# Once across the inward point, the tangent test prevents pulling back to it.
	var waypoint: Vector3 = _owned_pool_inward_waypoint(pool, current.y)
	var center: Vector3 = Vector3(pool.center.x, current.y, pool.center.z)
	var inward: Vector3 = (waypoint - center).normalized()
	var target_side: Vector3 = goal - center
	target_side -= inward * target_side.dot(inward)
	var near_boundary: bool = false
	var ring_clipped: bool = false
	for row: Dictionary in StadiumBoundaryGraph.segments():
		var normal: Vector2 = StadiumBoundaryGraph.inward(row)
		if (Vector2(current.x, current.z) - row.a).dot(normal) \
			<= StadiumBoundaryGraph.DEFENDER_RADIUS + maxf(travel, 0) + POOL_RING_MARGIN:
			near_boundary = true
		if (Vector2(center.x, center.z) - row.a).dot(normal) \
			< StadiumBoundaryGraph.DEFENDER_RADIUS + pool.radius + POOL_RING_MARGIN:
			ring_clipped = true
	var fresh_detour: bool = ring_clipped and (current - center).dot(target_side) < -0.000001 \
		and current.distance_to(waypoint) > maxf(travel, 0.05)
	var stalled: bool = near_boundary and next.distance_squared_to(goal) \
		>= current.distance_squared_to(goal) - 0.000001
	# A second defender overlapping the Pool makes a concave pocket even with a
	# complete boundary ring. Choose one legal ring shoulder from CURRENT geometry.
	var overlap_waypoint: Vector3 = _owned_pool_overlap_waypoint(
		pool, current, goal, travel, obstacles)
	if overlap_waypoint.is_finite():
		waypoint = overlap_waypoint
	if (fresh_detour or stalled or overlap_waypoint.is_finite()) and travel > 0 \
		and DefenderSpacing.segment_distance_xz(pool.center, current, goal) < pool.radius:
		if _owned_pool_inside(waypoint) \
			and clear(waypoint, waypoint, obstacles):
			state["waypoint"] = waypoint
			state["target"] = goal
			state["direction"] = (goal - current).normalized()
			state["obstacles"] = obstacles.duplicate(true)
			return _owned_pool_legal_step(current, waypoint, travel, obstacles)
	return next


static func _owned_pool_goal(current: Vector3, target: Vector3,
	obstacles: Array[Dictionary]) -> Vector3:
	var goal: Vector3 = Vector3(target.x, current.y, target.z)
	for obstacle: Dictionary in obstacles:
		var center: Vector3 = Vector3(obstacle.center.x, current.y, obstacle.center.z)
		var radial: Vector3 = goal - center
		if radial.length() < obstacle.radius + POOL_RING_MARGIN:
			if radial.length_squared() < 0.000001:
				radial = current - center
			if radial.length_squared() < 0.000001:
				radial = Vector3.RIGHT
			goal = center + radial.normalized() * (obstacle.radius + POOL_RING_MARGIN)
	return goal


static func _owned_pool_legal_step(current: Vector3, goal: Vector3, travel: float,
	obstacles: Array[Dictionary]) -> Vector3:
	var motion: Vector3 = goal - current
	motion.y = 0
	var distance: float = minf(maxf(travel, 0), motion.length())
	if distance <= 0.000001:
		return current
	motion = motion.normalized() * distance
	var best: Vector3 = current
	var best_distance: float = INF
	for index in range(72):
		var candidate: Vector3 = StadiumBoundaryGraph.clip(current,
			current + motion.rotated(Vector3.UP, index * TAU / 72.0))
		if not clear(current, candidate, obstacles):
			continue
		var remaining: float = candidate.distance_squared_to(goal)
		if remaining < best_distance:
			best = candidate
			best_distance = remaining
	return best


static func _owned_pool_inward_waypoint(pool: Dictionary, height: float) -> Vector3:
	var center: Vector2 = Vector2(pool.center.x, pool.center.z)
	var nearest: float = INF
	var inward: Vector2 = Vector2.ZERO
	for row: Dictionary in StadiumBoundaryGraph.segments():
		var normal: Vector2 = StadiumBoundaryGraph.inward(row)
		var distance: float = (center - row.a).dot(normal)
		if distance < nearest:
			nearest = distance
			inward = normal
	var point: Vector2 = center + inward * (pool.radius + POOL_RING_MARGIN)
	return Vector3(point.x, height, point.y)


## At most two shoulders per overlapping circle, with no route graph or extra state.
## The pair-axis crossing test releases fresh selections once past the shoulder.
static func _owned_pool_overlap_waypoint(pool: Dictionary, current: Vector3,
	goal: Vector3, travel: float, obstacles: Array[Dictionary]) -> Vector3:
	var center: Vector3 = Vector3(pool.center.x, current.y, pool.center.z)
	var best: Vector3 = Vector3.INF
	var best_distance: float = INF
	for obstacle: Dictionary in obstacles:
		var axis: Vector3 = Vector3(obstacle.center.x, current.y, obstacle.center.z) - center
		if axis.length_squared() <= 0.000001 \
			or axis.length() >= pool.radius + obstacle.radius + POOL_RING_MARGIN:
			continue
		if (current - center).dot(axis) * (goal - center).dot(axis) >= -0.000001:
			continue
		var side: Vector3 = Vector3(-axis.z, 0, axis.x).normalized()
		var near_side: Vector3 = side if (current - center).dot(side) >= 0 else -side
		if current.distance_to(center + near_side * (pool.radius + POOL_RING_MARGIN)) \
			<= maxf(travel, 0.05):
			continue # Reached shoulders release; never substitute the far shoulder here.
		for sign_value: float in [-1.0, 1.0]:
			var point: Vector3 = center + side * sign_value * (pool.radius + POOL_RING_MARGIN)
			var distance: float = current.distance_squared_to(point)
			if distance <= pow(maxf(travel, 0.05), 2) or distance >= best_distance \
				or not _owned_pool_inside(point) or not clear(point, point, obstacles):
				continue
			best = point
			best_distance = distance
	return best


static func _owned_pool_inside(point: Vector3) -> bool:
	if not point.is_finite():
		return false
	for row: Dictionary in StadiumBoundaryGraph.segments():
		if (Vector2(point.x, point.z) - row.a).dot(StadiumBoundaryGraph.inward(row)) \
			< StadiumBoundaryGraph.DEFENDER_RADIUS - StadiumBoundaryGraph.EPS:
			return false
	return true


static func _owned_pool_state_valid(state: Dictionary) -> bool:
	return state.size() == 4 and state.get("waypoint") is Vector3 \
		and state.get("target") is Vector3 and state.get("direction") is Vector3 \
		and state.get("obstacles") is Array and state.waypoint.is_finite() \
		and state.target.is_finite() and state.direction.is_finite()
