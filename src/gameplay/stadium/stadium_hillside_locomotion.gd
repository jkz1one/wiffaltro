class_name StadiumHillsideLocomotion
extends RefCounted
## Exact arc-length steps over the sampled ground; no gravity/speed/stat modification.


static func step(start: Vector3, direction: Vector2, distance: float,
	profile: String = "hill") -> Dictionary:
	if not start.is_finite() or not direction.is_finite() or not is_finite(distance) \
		or distance < 0 or not StadiumHillsideTerrain.PROFILES.has(profile):
		return {}
	var origin: Vector2 = Vector2(start.x, start.z)
	var support: float = StadiumHillsideTerrain.support_height(origin, profile)
	if not is_finite(support) or absf(start.y - support) > StadiumHillsideTerrain.EPS:
		return {}
	var result: Dictionary = {"position": start, "travel": 0.0, "remaining": distance,
		"edge_limited": false, "path": [start]}
	if direction.is_zero_approx() or distance == 0:
		return result
	var heading: Vector2 = direction.normalized()
	var limit: float = INF
	for axis in range(2):
		if absf(heading[axis]) <= 0.00000001:
			continue
		var edge: float = StadiumHillsideTerrain.BOUNDS.end[axis] if heading[axis] > 0 \
			else StadiumHillsideTerrain.BOUNDS.position[axis]
		limit = minf(limit, maxf(0.0, (edge - origin[axis]) / heading[axis]))
	var cuts: Array[float] = [0.0, limit]
	if absf(heading.y) > 0.00000001:
		for z: float in StadiumHillsideTerrain.knots():
			var at: float = (z - origin.y) / heading.y
			if at > 0 and at < limit:
				cuts.append(at)
	cuts.sort()
	var remaining: float = distance
	var last: Vector3 = start
	for index in range(1, cuts.size()):
		var xz: Vector2 = origin + heading * cuts[index]
		xz.x = clampf(xz.x, StadiumHillsideTerrain.BOUNDS.position.x,
			StadiumHillsideTerrain.BOUNDS.end.x)
		xz.y = clampf(xz.y, StadiumHillsideTerrain.BOUNDS.position.y,
			StadiumHillsideTerrain.BOUNDS.end.y)
		var endpoint: Vector3 = StadiumHillsideTerrain.point(xz.x, xz.y, profile)
		var length: float = last.distance_to(endpoint)
		if length <= 0.000000001:
			continue
		if remaining < length:
			endpoint = last.lerp(endpoint, remaining / length)
			length = remaining
		result.path.append(endpoint)
		result.travel += length
		remaining = maxf(0.0, remaining - length)
		last = endpoint
		if remaining <= 0.000000001:
			break
	result.position = last
	result.remaining = remaining
	result.edge_limited = remaining > 0.000000001
	return result
