class_name FrozenRopeCandidate
extends RefCounted
## Test-only, unapproved specification in docs/FROZEN_ROPE_CANDIDATE.md.

const SCORE_EPS: float = 0.000001
const ANGLE_EPS: float = 0.000001


static func snapshot(
	field: FieldDefinition,
	origin: Vector3,
	defenders: Array[Vector3],
	obstacles: Array[Rect2] = [],
	geometry_known: bool = true
) -> Dictionary:
	var data: Dictionary = {
		"valid": false,
		"origin": Vector2(origin.x, origin.z),
		"defenders": [],
		"obstacles": obstacles.duplicate()
	}
	if field == null or not geometry_known or not origin.is_finite() or defenders.is_empty():
		return data
	var near_z: float = INF
	var far_z: float = -INF
	for index in range(9):
		if not field.is_fielder_anchor_available(index):
			continue
		var anchor: Vector3 = field.fielder_anchor(index)
		if not anchor.is_finite():
			return data
		near_z = minf(near_z, anchor.z)
		far_z = maxf(far_z, anchor.z)
	if (
		not is_finite(field.fair_half_angle_degrees)
		or field.fair_half_angle_degrees <= 0.0
		or field.fair_half_angle_degrees >= 90.0
		or not is_finite(field.back_wall_z_m)
		or near_z <= maxf(0.0, origin.z)
		or far_z <= near_z
		or far_z >= field.back_wall_z_m
	):
		return data
	for defender: Vector3 in defenders:
		if not defender.is_finite():
			return data
		data.defenders.append(Vector2(defender.x, defender.z))
	for obstacle: Rect2 in obstacles:
		if (
			not obstacle.position.is_finite()
			or not obstacle.size.is_finite()
			or obstacle.size.x <= 0.0
			or obstacle.size.y <= 0.0
		):
			return data
	data.merge(
		{"valid": true, "near": near_z, "far": far_z, "half": field.fair_half_angle_degrees}, true
	)
	return data


static func choose(
	data: Dictionary, contact: ContactResult, profile: StringName, tier: int = 3, left: bool = false
) -> Dictionary:
	var original: float = contact.spray_degrees
	var result: Dictionary = {
		"original": original,
		"selected": original,
		"cap": 0.0,
		"before": -1.0,
		"after": -1.0,
		"reason": "ineligible",
		"candidates": [],
		"velocity": [contact.exit_velocity.x, contact.exit_velocity.y, contact.exit_velocity.z]
	}
	if (
		tier != 3
		or profile != &"swing.contact"
		or not data.valid
		or not is_finite(contact.quality)
		or contact.quality <= 0.8
		or contact.quality > 1.0
		or not is_finite(original)
		or not contact.exit_velocity.is_finite()
		or contact.exit_velocity.length_squared() == 0.0
		or contact.outcome not in [ContactResult.Outcome.CONTACT, ContactResult.Outcome.PERFECT]
	):
		return result
	var bounds: Array[float] = sector_bounds(original, data.half)
	if bounds.is_empty():
		return result
	result.sector = sector_name(original, data.half, left)
	result.cap = 4.0 * smoothstep(0.8, 1.0, contact.quality)
	result.before = _score(data, original)
	result.after = result.before
	result.reason = "unsafe_original" if result.before < 0.0 else "no_improvement"
	if result.before < 0.0:
		return result
	var candidates: Array[float] = [original]
	for index in range(1, 9):
		for side: float in [-1.0, 1.0]:
			var angle: float = clampf(
				original + side * minf(index * 0.5, result.cap), bounds[0], bounds[1]
			)
			if sector_name(angle, data.half, left) != result.sector:
				continue
			if not candidates.has(angle):
				candidates.append(angle)
	var best: float = result.before
	for angle: float in candidates:
		var score: float = _score(data, angle)
		result.candidates.append({"angle": angle, "score": score})
		best = maxf(best, score)
	if best <= result.before + SCORE_EPS:
		return result
	# Find all score ties before comparing distances; enumeration cannot pick a side.
	var smallest: float = INF
	var tied: Array[float] = []
	for candidate: Dictionary in result.candidates:
		if best - candidate.score > SCORE_EPS or candidate.score <= result.before + SCORE_EPS:
			continue
		var change: float = absf(candidate.angle - original)
		if change < smallest - ANGLE_EPS:
			smallest = change
			tied = [candidate.angle]
		elif absf(change - smallest) <= ANGLE_EPS:
			tied.append(candidate.angle)
	var selected: float = tied[0]
	for angle: float in tied:
		if signf(angle - original) != signf(selected - original):
			result.reason = "symmetric_tie"
			return result
		if absf(angle - original) < absf(selected - original):
			selected = angle
	if selected == original:
		result.reason = "symmetric_tie"
		return result
	result.selected = selected
	result.after = _score(data, selected)
	result.reason = "improved"
	var velocity: Vector3 = contact.exit_velocity.rotated(
		Vector3.UP, deg_to_rad(selected - original)
	)
	result.velocity = [velocity.x, velocity.y, velocity.z]
	return result


static func sector_bounds(angle: float, half: float) -> Array[float]:
	if absf(angle) > half:
		return []
	var third: float = half / 3.0
	if absf(angle) <= third:
		return [-third, third]
	# Inner boundaries belong to center; choose() rejects crossing into that sector.
	if angle < 0.0:
		return [-half, -third]
	return [third, half]


static func sector_name(angle: float, half: float, left: bool) -> String:
	if absf(angle) <= half / 3.0:
		return "center"
	return "pull" if (angle > 0.0) == left else "opposite"


static func _score(data: Dictionary, angle: float) -> float:
	var origin: Vector2 = data.origin
	var slope: float = tan(deg_to_rad(angle))
	var start: Vector2 = Vector2(origin.x + (data.near - origin.y) * slope, data.near)
	var end: Vector2 = Vector2(origin.x + (data.far - origin.y) * slope, data.far)
	var fair_slope: float = tan(deg_to_rad(data.half))
	if absf(start.x) > start.y * fair_slope + 0.45 or absf(end.x) > end.y * fair_slope + 0.45:
		return -1.0
	for obstacle: Rect2 in data.obstacles:
		if _intersects(origin, end, obstacle):
			return -1.0
	var score: float = INF
	var segment: Vector2 = end - start
	for defender: Vector2 in data.defenders:
		var alpha: float = clampf((defender - start).dot(segment) / segment.length_squared(), 0, 1)
		score = minf(score, defender.distance_to(start + alpha * segment))
	return score / (data.far - data.near)


static func _intersects(start: Vector2, end: Vector2, box: Rect2) -> bool:
	var lower: float = 0.0
	var upper: float = 1.0
	for axis in range(2):
		var delta: float = end[axis] - start[axis]
		if absf(delta) < 0.0000001:
			if start[axis] < box.position[axis] or start[axis] > box.end[axis]:
				return false
			continue
		var first: float = (box.position[axis] - start[axis]) / delta
		var last: float = (box.end[axis] - start[axis]) / delta
		lower = maxf(lower, minf(first, last))
		upper = minf(upper, maxf(first, last))
		if lower > upper:
			return false
	return true
