class_name StadiumNpcClubGraphBaseV1
extends RefCounted
## Retained AC-01/r1 correspondence copy; never a current authoring dependency.
## Original: src/gameplay/stadium/stadium_recipe_boundary.gd
# gdlint: disable=max-returns
## Isolated recipe-aware simple-polygon graph. No saved fixture activation yet.

const VERSION: int = 1
const EPS: float = 0.00001
const DEFENDER_RADIUS: float = 0.54
const THICKNESS: float = 0.35
var _shape: String = "straight"


static func create(shape: String) -> StadiumNpcClubGraphBaseV1:
	if not StadiumNpcClubWallRecipesV1.SHAPES.has(shape):
		return null
	var graph: StadiumNpcClubGraphBaseV1 = StadiumNpcClubGraphBaseV1.new()
	graph._shape = shape
	return graph


func identity() -> String:
	return "PERIM-BACKYARD-ANGLED-BX1-v1" if _shape == "deeper_center" else (
		"PERIM-BACKYARD-PAID-STRAIGHT-BX1-v1")


func polygon() -> PackedVector2Array:
	var points: PackedVector2Array = [Vector2(-8, -6), Vector2(8, -6),
		Vector2(24, 23.4), Vector2(StadiumNpcClubWallRecipesV1.BACK_X, 23.4)]
	if _shape == "deeper_center":
		points.append(Vector2(10, 26))
		points.append(Vector2(-10, 26))
	points.append(Vector2(-StadiumNpcClubWallRecipesV1.BACK_X, 23.4))
	points.append(Vector2(-24, 23.4))
	return points


func segments() -> Array[Dictionary]:
	var points: PackedVector2Array = polygon()
	var result: Array[Dictionary] = []
	for index in range(points.size()):
		var back: bool = index >= 3 and index < points.size() - 2
		var role: String = "REAR_PERIMETER_DEAD" if index == 0 else (
			"BACK_WALL_TERMINAL" if back else "SIDE_RETURN_LIVE")
		var id: String = "BACK-%02d" % (index - 2) if back else (
			"REAR-01" if index == 0 else "SIDE-R-01" if index == 1 else (
				"RETURN-R-01" if index == 2 else "SIDE-L-01" if index == points.size() - 1
				else "RETURN-L-01"))
		result.append({"id": id, "a": points[index], "b": points[(index + 1) % points.size()],
			"height": 3.25 if back else 1.2, "role": role,
			"priority": 300 if index == 0 else 200 if back else (
				50 if id.begins_with("SIDE") else 100)})
	return result


func segment(id: String) -> Dictionary:
	for row: Dictionary in segments():
		if row.id == id:
			return row
	return {}


func contains(point: Vector2) -> bool:
	if not point.is_finite():
		return false
	var inside: bool = false
	for row: Dictionary in segments():
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, row.a, row.b)) <= EPS:
			return true
		if (row.a.y > point.y) != (row.b.y > point.y):
			var crossing_x: float = row.a.x + (point.y - row.a.y) * (row.b.x - row.a.x) \
				/ (row.b.y - row.a.y)
			if point.x < crossing_x:
				inside = not inside
	return inside


static func inward(row: Dictionary) -> Vector2:
	var direction: Vector2 = row.a.direction_to(row.b)
	return Vector2(-direction.y, direction.x)


func crossing(previous: Vector3, current: Vector3) -> Dictionary:
	if not previous.is_finite() or not current.is_finite():
		return {}
	var start: Vector2 = Vector2(previous.x, previous.z)
	var end: Vector2 = Vector2(current.x, current.z)
	var candidates: Array[Dictionary] = []
	for row: Dictionary in segments():
		var normal: Vector2 = inward(row)
		var before: float = (start - row.a).dot(normal)
		var after: float = (end - row.a).dot(normal)
		if before < -EPS or after >= -EPS or before - after <= EPS:
			continue
		var fraction: float = clampf(before / (before - after), 0, 1)
		var position: Vector3 = previous.lerp(current, fraction)
		var line: Vector2 = row.b - row.a
		var along: float = (Vector2(position.x, position.z) - row.a).dot(line.normalized())
		if along < -EPS or along > line.length() + EPS:
			continue
		var role: String = row.role
		if role == "SIDE_RETURN_LIVE" and position.y > row.height + EPS:
			role = "SIDE_EXIT_DEAD"
		elif role == "BACK_WALL_TERMINAL" and position.y > row.height + EPS:
			role = "BACK_CLEAR"
		candidates.append({"segment": row.id, "role": role, "position": position,
			"fraction": fraction, "priority": row.priority})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(a.fraction - b.fraction) <= EPS:
			return a.priority > b.priority if a.priority != b.priority else a.segment < b.segment
		return a.fraction < b.fraction)
	return {} if candidates.is_empty() else candidates[0]


func apply(resolver: BallPlayResolver, event: Dictionary) -> bool:
	if resolver == null or resolver.state == null or resolver.state.dead or event.is_empty():
		return false
	if not event.get("segment") is String or not event.get("role") is String:
		return false
	var row: Dictionary = segment(event.segment)
	if row.is_empty() or not event.get("position") is Vector3:
		return false
	if not event.position.is_finite():
		return false
	var role: String = event.get("role", "")
	if role != row.role and not (row.role == "SIDE_RETURN_LIVE" and role == "SIDE_EXIT_DEAD") \
		and not (row.role == "BACK_WALL_TERMINAL" and role == "BACK_CLEAR"):
		return false
	if role in ["SIDE_EXIT_DEAD", "BACK_CLEAR"] and event.position.y <= row.height + EPS:
		return false
	resolver.state.record_stadium_contact("boundary", identity(), row.id, role, event.position,
		"crossing" if event.has("fraction") else "contact")
	match role:
		"REAR_PERIMETER_DEAD":
			resolver._resolve_foul(&"rear_perimeter", event.position)
		"SIDE_RETURN_LIVE":
			resolver.record_live_object_contact(StringName(row.id))
		"SIDE_EXIT_DEAD":
			if resolver.state.is_foul_play:
				resolver._resolve_foul(&"side_exit", event.position)
			else:
				resolver.state.raise_result_floor(BallPlayState.ResultFloor.SINGLE)
				resolver._resolve_floor(&"side_exit", event.position)
		"BACK_CLEAR":
			if not resolver.state.is_foul_play and not resolver.state.has_grounded:
				resolver.state.raise_result_floor(BallPlayState.ResultFloor.HOME_RUN)
				resolver._resolve_floor(&"cleared_hr_boundary", event.position)
			else:
				resolver.record_back_wall_contact(event.position)
		"BACK_WALL_TERMINAL":
			resolver.record_back_wall_contact(event.position)
		_:
			return false
	return true


func clip(current: Vector3, proposed: Vector3) -> Vector3:
	if not current.is_finite() or not proposed.is_finite():
		return current
	var from: Vector2 = Vector2(current.x, current.z)
	var to: Vector2 = Vector2(proposed.x, proposed.z)
	if not contains(from):
		return current
	var fraction: float = 1.0
	for row: Dictionary in segments():
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(from, row.a, row.b)
		if from.distance_to(closest) < DEFENDER_RADIUS - EPS:
			return current
		fraction = minf(fraction, _capsule_fraction(from, to, row.a, row.b))
	return current.lerp(proposed, fraction)


static func _capsule_fraction(from: Vector2, to: Vector2, a: Vector2, b: Vector2) -> float:
	var result: float = minf(_circle_fraction(from, to, a), _circle_fraction(from, to, b))
	var tangent: Vector2 = a.direction_to(b)
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	var before: float = (from - a).dot(normal)
	var after: float = (to - a).dot(normal)
	for side: float in [-1.0, 1.0]:
		if before * side < DEFENDER_RADIUS - EPS or after * side >= DEFENDER_RADIUS:
			continue
		if (before - after) * side <= EPS:
			continue
		var fraction: float = clampf((before * side - DEFENDER_RADIUS)
			/ ((before - after) * side), 0, 1)
		var along: float = (from.lerp(to, fraction) - a).dot(tangent)
		if along >= -EPS and along <= a.distance_to(b) + EPS:
			result = minf(result, fraction)
	return result


static func _circle_fraction(from: Vector2, to: Vector2, center: Vector2) -> float:
	var motion: Vector2 = to - from
	var offset: Vector2 = from - center
	var length_squared: float = motion.length_squared()
	var approach: float = offset.dot(motion)
	if length_squared <= EPS * EPS or approach >= 0:
		return 1.0
	var constant: float = offset.length_squared() - DEFENDER_RADIUS * DEFENDER_RADIUS
	if constant <= 0:
		return 0.0
	var discriminant: float = approach * approach - length_squared * constant
	# Distance-to-tangent tolerance, scaled to the quadratic, absorbs Vector2 float32 error.
	if discriminant <= 2 * DEFENDER_RADIUS * EPS * length_squared:
		return 1.0
	var fraction: float = (-approach - sqrt(maxf(0, discriminant))) / length_squared
	return clampf(fraction, 0, 1) if fraction >= -EPS else 1.0


func observe(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> Dictionary:
	if resolver == null or resolver.state == null or resolver.state.dead or resolver.field == null:
		return {}
	var event: Dictionary = crossing(previous, current)
	var end: Vector3 = current if event.is_empty() else event.position
	if not resolver.state.is_foul_play:
		StadiumBoundaryObserver._bands(resolver, previous, end)
	if not event.is_empty():
		apply(resolver, event)
	elif current.y < -2.0:
		resolver.resolve_settled(current)
	return event


func signature() -> String:
	var rows: Array = []
	for row: Dictionary in segments():
		rows.append({"id": row.id, "a": [row.a.x, row.a.y], "b": [row.b.x, row.b.y],
			"height": row.height, "role": row.role, "priority": row.priority})
	return JSON.stringify({"id": identity(), "version": VERSION, "segments": rows,
		"thickness": THICKNESS, "defender_radius": DEFENDER_RADIUS},
		"", true, true).sha256_text()


func outer_vertex(index: int) -> Vector2:
	var rows: Array[Dictionary] = segments()
	var previous: Dictionary = rows[posmod(index - 1, rows.size())]
	var next: Dictionary = rows[index]
	var first: Vector2 = -inward(previous)
	var second: Vector2 = -inward(next)
	var bisector: Vector2 = first + second
	return polygon()[index] + bisector * THICKNESS / bisector.dot(second)
