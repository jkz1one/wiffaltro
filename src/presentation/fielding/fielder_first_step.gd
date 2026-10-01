class_name FielderFirstStep
extends RefCounted
## Forced direction never consults the ball or chooses an obstacle-avoiding heading.

const BODY_RADIUS: float = 0.25


static func advance(fielder: FielderController, direction: Vector3, seconds: float) -> void:
	var previous: Vector3 = fielder.global_position
	var motion: Vector3 = direction * fielder.move_speed_mps * maxf(seconds, 0.0)
	if motion.is_zero_approx():
		return
	var fraction: float = 1.0
	if fielder.pitcher_lane_z != INF:
		var obstacle: Vector3 = (
			fielder.pitcher_defender.global_position
			if is_instance_valid(fielder.pitcher_defender)
			else Vector3(0, 0, fielder.pitcher_lane_z)
		)
		# Clip at the first body-separation boundary; do not steer the guess around it.
		if (
			DefenderSpacing.segment_distance_xz(obstacle, previous, previous + motion)
			< (DefenderSpacing.MOUND_CLEARANCE_M)
		):
			var low: float = 0.0
			var high: float = 1.0
			for iteration in range(24):
				var middle: float = (low + high) * 0.5
				if (
					DefenderSpacing.segment_distance_xz(
						obstacle, previous, previous + motion * middle
					)
					< DefenderSpacing.MOUND_CLEARANCE_M
				):
					high = middle
				else:
					low = middle
			fraction = low
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = BODY_RADIUS
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, previous + Vector3.UP * 0.5)
	query.motion = motion * fraction
	query.collision_mask = 1  # Authored field walls/objects, never the ball (layer 2).
	query.exclude = [fielder.get_rid()]
	var safe: PackedFloat32Array = fielder.get_world_3d().direct_space_state.cast_motion(query)
	if safe.size() == 2:
		fraction *= safe[0]
	fielder.global_position = previous + motion * fraction
	fielder.velocity = (fielder.global_position - previous) / maxf(seconds, 0.000001)


static func unobstructed(fielder: FielderController, ball: Vector3) -> bool:
	var start: Vector3 = fielder.global_position + Vector3.UP * maxf(0.3, ball.y)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, ball, 1)
	query.exclude = [fielder.get_rid()]
	return fielder.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
