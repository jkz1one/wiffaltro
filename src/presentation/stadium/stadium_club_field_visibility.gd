class_name StadiumClubFieldVisibility
extends BallTrackingVisibility
## Whole candidate assembly; dugout openings stay visually open and receiver foreground fades.

var _groups: Array[Dictionary] = []
var _rails: Array[Dictionary] = []


func configure(geometry: Node) -> void:
	var property: StadiumClubPropertyGeometry = geometry.get_node_or_null("HomeProperty") \
		as StadiumClubPropertyGeometry
	if property == null:
		super.configure(geometry)
		return
	_groups.clear()
	_rails.clear()
	_wall_bounds.clear()
	_obstacles.clear()
	_uprights.clear()
	_recipe = property.boundary.graph
	_wall_prisms = StadiumWallViewPrisms.new(_recipe)
	var rows: Array[Dictionary] = _recipe.segments()
	for row: Dictionary in rows:
		if row.role.begins_with("DUGOUT"):
			_rails.append({"a": row.a, "normal": _recipe.inward(row)})
	for index in range(rows.size() - 1, -1, -1):
		if rows[index].role.begins_with("DUGOUT"):
			_wall_prisms.walls.remove_at(index)
	field_wall_z = 0
	for point: Vector2 in _recipe.polygon():
		field_wall_z = maxf(field_wall_z, point.y)
	for model: Node3D in property.find_children("*", "Node3D", true, false):
		if not model.has_meta("candidate_instance"):
			continue
		if model.get_meta("stadium_item") in ["ST-026", "ST-073", "ST-065", "ST-022", "ST-023"]:
			continue
		var visual: Node = model.get_node("Visual")
		var members: Array[Dictionary] = []
		var broad: AABB
		for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			broad = bounds if members.is_empty() else broad.merge(bounds)
			members.append({"inverse": mesh.global_transform.affine_inverse(), "bounds": mesh.get_aabb()})
		_groups.append({"bounds": broad, "members": members})
		if model.get_meta("stadium_item") == "ST-021":
			_collect(visual)
	_obstacles.clear()


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	if _recipe == null:
		return super._blocked(camera, ball)
	if _wall_blocked(camera, ball):
		return true
	for group: Dictionary in _groups:
		if group.bounds.grow(0.4).intersects_segment(camera, ball) == null:
			continue
		if _member_blocked(group.members, camera, ball):
			return true
	return false


func _member_blocked(members: Array, camera: Vector3, ball: Vector3,
	maximum: float = 0.4) -> bool:
	for member: Dictionary in members:
		var local_ball: Vector3 = member.inverse * ball
		var bounds: AABB = member.bounds
		var nearest: Vector3 = Vector3(clampf(local_ball.x, bounds.position.x, bounds.end.x),
			clampf(local_ball.y, bounds.position.y, bounds.end.y),
			clampf(local_ball.z, bounds.position.z, bounds.end.z))
		var padding: float = minf(maximum, local_ball.distance_to(nearest) * 0.5)
		if bounds.grow(padding).intersects_segment(member.inverse * camera, local_ball) != null:
			return true
	return false


func actual_blocked(camera: Vector3, ball: Vector3) -> bool:
	if _wall_prisms.blocked(camera, ball, 0):
		return true
	for group: Dictionary in _groups:
		if group.bounds.intersects_segment(camera, ball) != null \
			and _member_blocked(group.members, camera, ball, 0):
			return true
	return false


func clear_position(desired: Vector3, ball: Vector3) -> Vector3:
	if _recipe != null and desired.z < 0 and desired.z < ball.z:
		# Behind-home coverage must stay on the field side of both dugout rail lines.
		# Otherwise it changes from above-roof to below-roof sight through an opaque band.
		for row: Dictionary in _rails:
			var normal: Vector2 = row.normal
			var gap: float = normal.dot(Vector2(desired.x, desired.z) - row.a)
			if gap < WALL_CAMERA_CLEARANCE and absf(normal.x) > 0.01:
				desired.x += (WALL_CAMERA_CLEARANCE - gap) / normal.x
	return super.clear_position(desired, ball)
