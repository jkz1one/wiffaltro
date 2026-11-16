class_name StadiumNpcYardGraphV1
extends RefCounted
# gdlint: disable=max-returns
## BY5/CH straight template blockout. Not activated in saved seasons until runtime certification.

const ID: String = "PERIM-BACKYARD-STRAIGHT-BX1-v1"
const BACK_HALF: float = 21.519454636569
const BACK_Z: float = 23.4
const THICKNESS: float = 0.20
# Neutral hands reach 0.38m +0.11m radius; include their 0.02m depth and 0.04m clearance.
const DEFENDER_RADIUS: float = 0.54
const EPS: float = 0.00001 # Shared Vector2/Vector3 engine precision, not rounded UI coordinates.
const VERTICES: Array[Vector2] = [Vector2(-8, -6), Vector2(8, -6),
	Vector2(24, BACK_Z), Vector2(BACK_HALF, BACK_Z),
	Vector2(-BACK_HALF, BACK_Z), Vector2(-24, BACK_Z)]
const IDS: Array[String] = ["REAR-DEAD-01", "SIDE-R-01", "RETURN-R-01",
	"BACK-TERMINAL-01", "RETURN-L-01", "SIDE-L-01"]


static func segments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(VERTICES.size()):
		var role: String = "REAR_PERIMETER_DEAD" if index == 0 else (
			"BACK_WALL_TERMINAL" if index == 3 else "SIDE_RETURN_LIVE")
		result.append({"id": IDS[index], "a": VERTICES[index],
			"b": VERTICES[(index + 1) % VERTICES.size()], "role": role,
			"height": 3.25 if index == 3 else 1.20,
			"priority": 300 if index == 0 else 200 if index == 3 else (
				100 if index in [2, 4] else 50)})
	return result


static func segment(id: String) -> Dictionary:
	var index: int = IDS.find(id)
	return {} if index < 0 else segments()[index]


static func inward(row: Dictionary) -> Vector2:
	var direction: Vector2 = (row.b - row.a).normalized()
	return Vector2(-direction.y, direction.x)


static func contains(point: Vector2) -> bool:
	for row: Dictionary in segments():
		if (point - row.a).dot(inward(row)) < -EPS:
			return false
	return true


static func outer_vertex(index: int) -> Vector2:
	var rows: Array[Dictionary] = segments()
	var previous: Dictionary = rows[posmod(index - 1, rows.size())]
	var next: Dictionary = rows[index]
	var first: Vector2 = -inward(previous)
	var second: Vector2 = -inward(next)
	var bisector: Vector2 = first + second
	# Shared miter endpoint makes neighboring slabs meet with no independent end rounding.
	return VERTICES[index] + bisector * THICKNESS / bisector.dot(second)


static func crossing(previous: Vector3, current: Vector3) -> Dictionary:
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
		if role == "SIDE_RETURN_LIVE" and position.y > row.height:
			role = "SIDE_EXIT_DEAD"
		elif role == "BACK_WALL_TERMINAL" and position.y > row.height:
			role = "BACK_CLEAR"
		candidates.append({"segment": row.id, "role": role, "position": position,
			"fraction": fraction, "priority": row.priority})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.priority > b.priority if absf(a.fraction - b.fraction) <= EPS else (
			a.fraction < b.fraction))
	return {} if candidates.is_empty() else candidates[0]


static func apply(resolver: BallPlayResolver, event: Dictionary) -> bool:
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
	if role in ["SIDE_EXIT_DEAD", "BACK_CLEAR"] and event.position.y <= row.height:
		return false
	resolver.state.record_stadium_contact("boundary", ID, row.id, role, event.position,
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


static func clip(current: Vector3, proposed: Vector3) -> Vector3:
	if not current.is_finite() or not proposed.is_finite():
		return current
	var from: Vector2 = Vector2(current.x, current.z)
	var to: Vector2 = Vector2(proposed.x, proposed.z)
	var fraction: float = 1
	for row: Dictionary in segments():
		var normal: Vector2 = inward(row)
		var before: float = (from - row.a).dot(normal)
		var after: float = (to - row.a).dot(normal)
		if before < DEFENDER_RADIUS - EPS:
			return current # Invalid spawn/teleport is not repaired by exceeding this movement budget.
		if after < DEFENDER_RADIUS and before > after:
			fraction = minf(fraction, maxf(0, (before - DEFENDER_RADIUS) / (before - after)))
	return current.lerp(proposed, fraction)


static func signature() -> String:
	var rows: Array = []
	for row: Dictionary in segments():
		rows.append({"id": row.id, "a": [row.a.x, row.a.y], "b": [row.b.x, row.b.y],
			"height": row.height, "role": row.role, "priority": row.priority})
	return JSON.stringify({"id": ID, "rules": 1, "segments": rows, "thickness": THICKNESS,
		"defender_radius": DEFENDER_RADIUS}, "", true, true).sha256_text()
