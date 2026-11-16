class_name FielderFirstStep
extends RefCounted
## Forced direction never consults the ball or chooses an obstacle-avoiding heading.

const BODY_RADIUS: float = 0.25


static func advance(fielder: FielderController, direction: Vector3, seconds: float) -> void:
	if not StadiumSurfaceTerrainRuntime.actor_allowed(fielder):
		return
	if (
		fielder.terrain_motion != null
		and (
			not fielder.terrain_motion.guard_actor(fielder)
			or not direction.is_finite()
			or direction.y != 0.0
			or not is_finite(seconds)
			or not is_finite(fielder.move_speed_mps)
			or fielder.move_speed_mps < 0
		)
	):
		return
	if fielder.hillside_motion != null:
		if not fielder.hillside_motion.guard(fielder):
			return
		if (
			not direction.is_finite()
			or direction.y != 0.0
			or not is_finite(seconds)
			or not is_finite(fielder.move_speed_mps)
			or fielder.move_speed_mps < 0
		):
			fielder.hillside_motion.fail(
				fielder, "Forced movement needs a finite horizontal heading and speed."
			)
			return
		if fielder.hillside_motion.profile != "flat-control":
			_advance_hillside(fielder, direction, seconds)
			return
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
	var next: Vector3 = StadiumDefenderRoutes.clip(
		previous, previous + motion * fraction, fielder.stadium_obstacles
	)
	if fielder.stadium_waterfall_clip.is_valid():
		next = fielder.stadium_waterfall_clip.call(previous, next)
	if fielder.stadium_boundary_clip.is_valid():
		next = fielder.stadium_boundary_clip.call(previous, next)
	if fielder.hillside_motion != null:
		var supported: Dictionary = fielder.hillside_motion.finish_path(
			fielder, [previous, next], motion.length()
		)
		if supported.is_empty():
			return
		fielder.hillside_motion.accept_position(next)
	if fielder.terrain_motion != null:
		next = fielder.terrain_motion.finish_step(fielder, previous, next, motion.length())
		if not fielder.terrain_motion.guard_actor(fielder):
			return
	fielder.global_position = next
	fielder.velocity = (fielder.global_position - previous) / maxf(seconds, 0.000001)


static func _advance_hillside(
	fielder: FielderController, direction: Vector3, seconds: float
) -> void:
	var previous: Vector3 = fielder.global_position
	var heading: Vector2 = Vector2(direction.x, direction.z)
	var budget: float = heading.length() * fielder.move_speed_mps * maxf(seconds, 0.0)
	var motion: StadiumHillsideDefenderMotion = fielder.hillside_motion
	var generated: Dictionary = motion.surface_path(fielder, previous, heading, budget)
	if generated.is_empty():
		return
	var path: Array[Vector3] = [previous]
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = BODY_RADIUS
	for index in range(1, generated.path.size()):
		var start: Vector3 = path[-1]
		var endpoint: Vector3 = generated.path[index]
		var segment: Vector3 = endpoint - start
		var fraction: float = 1.0
		if fielder.pitcher_lane_z != INF:
			var other: Vector3 = (
				fielder.pitcher_defender.global_position
				if is_instance_valid(fielder.pitcher_defender)
				else Vector3(0, 0, fielder.pitcher_lane_z)
			)
			if (
				DefenderSpacing.segment_distance_xz(other, start, endpoint)
				< DefenderSpacing.MOUND_CLEARANCE_M
			):
				var low: float = 0.0
				var high: float = 1.0
				for iteration in range(24):
					var middle: float = (low + high) * 0.5
					if (
						DefenderSpacing.segment_distance_xz(other, start, start + segment * middle)
						< DefenderSpacing.MOUND_CLEARANCE_M
					):
						high = middle
					else:
						low = middle
				fraction = low
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, start + Vector3.UP * 0.5)
		query.motion = segment * fraction
		query.collision_mask = 1
		query.exclude = [fielder.get_rid()]
		var safe: PackedFloat32Array = fielder.get_world_3d().direct_space_state.cast_motion(query)
		if safe.size() == 2:
			fraction *= safe[0]
		var next: Vector3 = endpoint if fraction == 1.0 else start + segment * fraction
		next = StadiumDefenderRoutes.clip(start, next, fielder.stadium_obstacles)
		next = fielder.stadium_boundary_clip.call(start, next)
		if next != endpoint:
			next = motion.supported_point(fielder, next)
			if not next.is_finite():
				return
			path.append(next)
			break
		path.append(endpoint)
	var result: Dictionary = motion.finish_path(fielder, path, budget)
	if result.is_empty():
		return
	fielder.global_position = result["position"]
	fielder.velocity = (fielder.global_position - previous) / maxf(seconds, 0.000001)
	motion.accept_position(fielder.global_position)


static func unobstructed(fielder: FielderController, ball: Vector3) -> bool:
	if not StadiumSurfaceTerrainRuntime.actor_allowed(fielder):
		return false
	if fielder.terrain_motion != null:
		var frame: Dictionary = fielder.terrain_motion.control_frame(fielder, ball)
		if frame.is_empty():
			return false
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			fielder.global_position + Vector3.UP * maxf(0.3, float(frame.height_m)), ball, 1
		)
		query.exclude = [fielder.get_rid()]
		return fielder.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	if fielder.hillside_motion != null:
		var bound_query: PhysicsRayQueryParameters3D = control_ray(fielder, ball)
		return (
			bound_query != null
			and fielder.get_world_3d().direct_space_state.intersect_ray(bound_query).is_empty()
		)
	var start: Vector3 = fielder.global_position + Vector3.UP * maxf(0.3, ball.y)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, ball, 1)
	query.exclude = [fielder.get_rid()]
	return fielder.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func control_ray(fielder: FielderController, ball: Vector3) -> PhysicsRayQueryParameters3D:
	if not is_instance_valid(fielder) or fielder.hillside_motion == null or not ball.is_finite():
		return null
	var record: Dictionary = fielder.hillside_motion.support_record(
		fielder, Vector2(ball.x, ball.z)
	)
	if record.is_empty():
		return null
	var height_m: float = ball.y - fielder.global_position.y
	if not is_finite(height_m):
		return null
	var start: Vector3 = fielder.global_position + Vector3.UP * maxf(0.3, height_m)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, ball, 1)
	query.exclude = [fielder.get_rid()]
	return query
