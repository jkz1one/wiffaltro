class_name BallTrackingVisibility
extends RefCounted

# Presentation-only bounds include scenery without gameplay collision shapes.
var field_wall_z: float = 23.4
var _obstacles: Array[AABB] = []


func configure(geometry: Node) -> void:
	_obstacles.clear()
	var wall: Node3D = geometry.get_node_or_null("BackWall")
	if wall != null:
		field_wall_z = wall.global_position.z - 0.25
	for node_name in ["BackWall", "LiveObjectPole", "CommonsParkScenery"]:
		var node: Node = geometry.get_node_or_null(node_name)
		if node != null:
			_collect(node)


func clear_position(desired: Vector3, ball: Vector3) -> Vector3:
	if not _blocked(desired, ball):
		return desired
	# Pull toward an overhead view on the same side of play. This continuously
	# shortens the horizontal offset instead of cutting to the opposite end.
	var overhead: Vector3 = ball + Vector3(0, maxf(6.0, desired.y - ball.y), 0)
	var clear_fraction: float = 0.0
	var blocked_fraction: float = 1.0
	for step in range(10):
		var fraction: float = (clear_fraction + blocked_fraction) * 0.5
		if _blocked(overhead.lerp(desired, fraction), ball):
			blocked_fraction = fraction
		else:
			clear_fraction = fraction
	return overhead.lerp(desired, maxf(0.0, clear_fraction - 0.05))


func lateral_clearance(ball: Vector3) -> float:
	# A nearby narrow upright needs a side route before the ball reaches its
	# silhouette. Keep walls out of this rule; they use the field-side limit.
	for bounds in _obstacles:
		if bounds.size.x < 1.5 and bounds.size.z < 1.5 and bounds.size.y > 0.5:
			if bounds.get_center().distance_to(ball) < 6.75:
				return 14.0
	return 0.0


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	for bounds in _obstacles:
		# A small margin starts the adjustment before the ball clips the wall.
		# Don't engulf a ball that is itself immediately next to that wall.
		var nearest: Vector3 = Vector3(
			clampf(ball.x, bounds.position.x, bounds.end.x),
			clampf(ball.y, bounds.position.y, bounds.end.y),
			clampf(ball.z, bounds.position.z, bounds.end.z)
		)
		var padded: AABB = bounds.grow(minf(0.4, ball.distance_to(nearest) * 0.5))
		if padded.intersects_segment(camera, ball) != null:
			return true
	return false


func _collect(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null and node.visible:
		var bounds: AABB = node.global_transform * node.get_aabb()
		# Turf stripes are surface decals, not occluders. Inflating their
		# millimeter thickness made rolling balls trigger huge false recoveries.
		if bounds.size.y > 0.025:
			_obstacles.append(bounds)
	for child in node.get_children():
		_collect(child)
