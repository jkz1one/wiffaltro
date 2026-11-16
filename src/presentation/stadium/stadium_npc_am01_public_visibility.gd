class_name StadiumNpcAm01PublicVisibility
extends StadiumNpcRetainedVisibility
## AM-01 retained 16-group visibility enrollment. Includes the six dormant tower meshes.
## Retains member-level cup, open-dugout and inherited Club clearance algorithms.


func configure_property(value: StadiumNpcRetainedProperty) -> void:
	property = value
	_groups.clear()
	_rails.clear()
	_wall_bounds.clear()
	_obstacles.clear()
	_uprights.clear()
	_recipe = null
	_wall_prisms = null
	if property == null or property.venue_id != "AM-01":
		return
	_recipe = property.view_graph()
	# The retained Club prism algorithm leaves the two dugout openings visually open.
	_wall_prisms = StadiumNpcRetainedVisibility.prisms(_recipe, "AC-01")
	field_wall_z = 0
	for point: Vector2 in _recipe.polygon():
		field_wall_z = maxf(field_wall_z, point.y)
	_configure_club()


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	if property == null or property.venue_id != "AM-01" or _recipe == null:
		return super._blocked(camera, ball)
	if _wall_blocked(camera, ball):
		return true
	for group: Dictionary in _groups:
		if group.bounds.grow(0.4).intersects_segment(camera, ball) == null:
			continue
		if _member_blocked(group.members, camera, ball):
			return true
	return false


func actual_blocked(camera: Vector3, ball: Vector3) -> bool:
	if property == null or property.venue_id != "AM-01":
		return _blocked(camera, ball)
	if _wall_prisms.blocked(camera, ball, 0):
		return true
	for group: Dictionary in _groups:
		if group.bounds.intersects_segment(camera, ball) != null \
			and _member_blocked(group.members, camera, ball, 0):
			return true
	return false


func clear_position(desired: Vector3, ball: Vector3) -> Vector3:
	if property != null and property.venue_id == "AM-01" \
		and _recipe != null and desired.z < 0 and desired.z < ball.z:
		# Behind-home coverage must stay on the field side of both dugout rail lines.
		# Otherwise it changes from above-roof to below-roof sight through an opaque band.
		for row: Dictionary in _rails:
			var normal: Vector2 = row.normal
			var gap: float = normal.dot(Vector2(desired.x, desired.z) - row.a)
			if gap < WALL_CAMERA_CLEARANCE and absf(normal.x) > 0.01:
				desired.x += (WALL_CAMERA_CLEARANCE - gap) / normal.x
	return super.clear_position(desired, ball)
