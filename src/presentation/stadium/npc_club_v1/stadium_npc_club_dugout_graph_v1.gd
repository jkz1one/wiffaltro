class_name StadiumNpcClubDugoutGraphV1
extends StadiumNpcClubGraphBaseV1
## Retained AC-01/r1 correspondence copy; never a current authoring dependency.
## Original: src/gameplay/stadium/stadium_dugout_boundary.gd
## CI candidate graph. Openings stay outside defender navigation; old saved graphs are frozen.


static func candidate(shape: String) -> StadiumNpcClubDugoutGraphV1:
	if shape not in StadiumNpcClubWallRecipesV1.SHAPES:
		return null
	var result: StadiumNpcClubDugoutGraphV1 = StadiumNpcClubDugoutGraphV1.new()
	result._shape = shape
	return result


func identity() -> String:
	return "PROTOTYPE-CLUB-DUGOUT-" + _shape.to_upper().replace("_", "-") + "-v1"


func polygon() -> PackedVector2Array:
	var result: PackedVector2Array = []
	var original: StadiumNpcClubGraphBaseV1 = StadiumNpcClubGraphBaseV1.create(_shape)
	for row: Dictionary in original.segments():
		result.append(row.a)
		if row.id in ["SIDE-R-01", "SIDE-L-01"]:
			var left: bool = row.id == "SIDE-L-01"
			var distances: Array = [16, 14, 12, 10] if left else [10, 12, 14, 16]
			for distance: float in distances:
				var point: Vector3 = StadiumNpcClubDugoutRecipeV1.rail_point(distance, 0, left)
				result.append(Vector2(point.x, point.z))
	return result


func segments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var points: PackedVector2Array = polygon()
	var original: StadiumNpcClubGraphBaseV1 = StadiumNpcClubGraphBaseV1.create(_shape)
	for index in range(points.size()):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		for row: Dictionary in original.segments():
			if a.distance_to(Geometry2D.get_closest_point_to_segment(a, row.a, row.b)) > EPS \
				or b.distance_to(Geometry2D.get_closest_point_to_segment(b, row.a, row.b)) > EPS:
				continue
			var next: Dictionary = row.duplicate(true)
			next.a = a
			next.b = b
			if row.id in ["SIDE-R-01", "SIDE-L-01"]:
				_side(next, row.id == "SIDE-L-01")
			result.append(next)
			break
	return result


static func _side(row: Dictionary, left: bool) -> void:
	var center: Vector2 = (row.a + row.b) / 2
	var s: float = (Vector2(absf(center.x), center.y) - Vector2(8, -6)).dot(
		Vector2(16, 29.4).normalized())
	var prefix: String = "DUGOUT-L" if left else "DUGOUT-R"
	if s > 10 and s < 16:
		var opening: bool = s > 12 and s < 14
		row.id = prefix + ("-OPEN" if opening else "-FACE-IN" if s < 12 else "-FACE-OUT")
		row.role = "DUGOUT_OPENING_DEAD" if opening else "DUGOUT_FACE_LIVE"
		row.height = 2.4 if opening else 1.2
		row.priority = 250 if opening else 350
	else:
		row.id += "-IN" if s < 10 else "-OUT"


func crossing(previous: Vector3, current: Vector3) -> Dictionary:
	var event: Dictionary = super.crossing(previous, current)
	if event.is_empty():
		return event
	var row: Dictionary = segment(event.segment)
	if row.role == "DUGOUT_FACE_LIVE" and event.position.y > row.height + EPS:
		event.role = "SIDE_EXIT_DEAD"
	if row.role == "DUGOUT_OPENING_DEAD" and event.position.y > row.height + EPS:
		event.role = "DUGOUT_EXTERIOR_DEAD"
	return event


func apply(resolver: BallPlayResolver, event: Dictionary) -> bool:
	var row: Dictionary = segment(event.get("segment", ""))
	if not row.get("role", "").begins_with("DUGOUT"):
		return super.apply(resolver, event)
	if resolver == null or resolver.state == null or resolver.state.dead \
		or not event.get("position") is Vector3 or not event.position.is_finite():
		return false
	var role: String = event.get("role", "")
	if role != row.role and not (row.role == "DUGOUT_FACE_LIVE" and role == "SIDE_EXIT_DEAD"
		and event.position.y > row.height) and not (row.role == "DUGOUT_OPENING_DEAD"
		and role == "DUGOUT_EXTERIOR_DEAD" and event.position.y > row.height):
		return false
	resolver.state.record_stadium_contact("boundary", identity(), row.id, role, event.position,
		"contact" if event.get("swept_contact", false) else "crossing")
	if role == "DUGOUT_FACE_LIVE":
		resolver.record_live_object_contact(StringName(row.id))
	else:
		dead_area(resolver, event.position, StringName(role.to_lower()))
	return true


static func dead_area(resolver: BallPlayResolver, point: Vector3, reason: StringName) -> void:
	if resolver.state.is_foul_play:
		resolver._resolve_foul(reason, point)
	else:
		resolver.state.raise_result_floor(BallPlayState.ResultFloor.SINGLE)
		resolver._resolve_floor(reason, point)
