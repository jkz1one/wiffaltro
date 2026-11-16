class_name StadiumExpandedCameraDirector
extends StadiumClubCameraDirector
## Candidate camera clearance encloses the actual near plane at the current FOV and aspect.


static func near_enclosure(camera: Camera3D) -> float:
	var extent: Vector2 = camera.get_viewport().get_visible_rect().size
	# Retain the earlier conservative sphere even when the actual corner enclosure is smaller.
	var radius: float = camera.near * 2
	for corner: Vector2 in [Vector2.ZERO, Vector2(extent.x, 0), extent, Vector2(0, extent.y)]:
		var world: Vector3 = camera.project_position(corner, camera.near)
		radius = maxf(radius, camera.global_position.distance_to(world))
	return radius


func _query(camera: Camera3D) -> PhysicsShapeQueryParameters3D:
	var query: PhysicsShapeQueryParameters3D = super._query(camera)
	query.shape.radius = near_enclosure(camera) + SKIN
	return query
