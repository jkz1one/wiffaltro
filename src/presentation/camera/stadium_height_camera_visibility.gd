class_name StadiumHeightCameraVisibility
extends BallTrackingVisibility
## Finite-face camera envelope; no distant face extrapolation across the yard.


func defense_depth(x: float, desired: float, ball: Vector3 = Vector3.ZERO) -> float:
	if not _recipe is StadiumHeightBoundary:
		return super.defense_depth(x, desired, ball)
	var path: Vector3 = Vector3(ball.x, 0, ball.z)
	if path.length_squared() > 0.0001:
		var exit: Dictionary = _recipe.crossing(Vector3.ZERO, path * 1000)
		if exit.get("role", "") in ["SIDE_RETURN_LIVE", "REAR_PERIMETER_DEAD"]:
			return _side_depth(x, desired)
	var depth: float = field_wall_z
	var nearest: float = INF
	for row: Dictionary in _recipe.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		var at: float = clampf(x, minf(row.a.x, row.b.x), maxf(row.a.x, row.b.x))
		var distance: float = absf(x - at)
		var normal: Vector2 = _recipe.inward(row)
		var local_depth: float = lerpf(row.a.y, row.b.y, inverse_lerp(row.a.x, row.b.x, at)) \
			- WALL_CAMERA_CLEARANCE / maxf(0.01, absf(normal.y))
		if distance < nearest - StadiumRecipeBoundary.EPS:
			nearest = distance
			depth = local_depth
		elif absf(distance - nearest) <= StadiumRecipeBoundary.EPS:
			depth = minf(depth, local_depth)
	# Interior shoulders need a common viewing kernel around their concave joins.
	# End returns stay finite; extrapolating one across the opposite field causes bad framing.
	var rows: Array[Dictionary] = _recipe.segments()
	for index in range(4, rows.size() - 3):
		var row: Dictionary = rows[index]
		var normal: Vector2 = _recipe.inward(row)
		if normal.y < -StadiumRecipeBoundary.EPS:
			depth = minf(depth, row.a.y - (
				(x - row.a.x) * normal.x - WALL_CAMERA_CLEARANCE) / normal.y)
	# Actual joined-prism line-of-sight still resolves corners in clear_position().
	return minf(depth, desired)
