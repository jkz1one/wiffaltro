class_name DefenderSpacing
extends RefCounted

# Covers both avatars plus the Pitcher's 0.60 m visual reaction step.
# This is body separation, not an enlarged ball-control envelope.
const MOUND_CLEARANCE_M: float = 1.55
const PITCH_CLEARANCE_M: float = 1.0


static func segment_distance_xz(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var flat_point: Vector2 = Vector2(point.x, point.z)
	var flat_start: Vector2 = Vector2(start.x, start.z)
	var segment: Vector2 = Vector2(finish.x - start.x, finish.z - start.z)
	var fraction: float = 0.0
	if segment.length_squared() > 0.000001:
		fraction = clampf((flat_point - flat_start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return flat_point.distance_to(flat_start + segment * fraction)


static func step_around_mound(
	current: Vector3, target: Vector3, mound: Vector3, travel_m: float
) -> Vector3:
	var goal: Vector3 = target
	goal.y = current.y
	var radial: Vector3 = goal - Vector3(mound.x, current.y, mound.z)
	if radial.length() < MOUND_CLEARANCE_M + 0.02:
		if radial.length_squared() < 0.000001:
			radial = current - Vector3(mound.x, current.y, mound.z)
		if radial.length_squared() < 0.000001:
			radial = Vector3.RIGHT
		goal = Vector3(mound.x, current.y, mound.z) + radial.normalized() * (
			MOUND_CLEARANCE_M + 0.02
		)
	var displacement: Vector3 = goal - current
	var distance: float = minf(maxf(0.0, travel_m), displacement.length())
	if distance <= 0.000001:
		return current
	var desired: Vector3 = displacement.normalized() * distance
	if segment_distance_xz(mound, current, current + desired) >= MOUND_CLEARANCE_M:
		return current + desired
	var best: Vector3 = current
	var best_distance: float = INF
	# Try direct travel first, then deterministic nearby headings. Every full
	# movement segment is checked, including large-delta frames.
	for index in range(72):
		var angle: float = float(index) * TAU / 72.0
		var candidate: Vector3 = current + desired.rotated(Vector3.UP, angle)
		if segment_distance_xz(mound, current, candidate) < MOUND_CLEARANCE_M:
			continue
		var remaining: float = candidate.distance_squared_to(goal)
		if remaining < best_distance:
			best = candidate
			best_distance = remaining
	return best
