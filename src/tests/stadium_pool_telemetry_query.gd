class_name StadiumPoolTelemetryQuery
extends RefCounted
## Diagnostic straight-motion query from a retained state, never an actual reflected path.


static func measure(
	ball: BattedBallBody,
	prior: Dictionary,
	current: Dictionary,
	source_kind: String,
	query: PhysicsShapeQueryParameters3D,
	geometry_sampler: Callable
) -> Dictionary:
	var collision: CollisionShape3D
	for child: Node in ball.get_children():
		if child is CollisionShape3D:
			collision = child
	var errors: Array[String] = []
	if collision == null or not collision.shape is SphereShape3D:
		return {"errors": ["Actual physical sphere unavailable"]}
	var step: float = current.step
	query.shape = collision.shape
	query.transform = prior.transform * collision.transform
	query.motion = (prior.linear_velocity + prior.total_gravity * step) * step
	query.margin = 0
	query.collision_mask = ball.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [ball.get_rid()]
	var from: Vector3 = query.transform.origin
	var motion: Vector3 = query.motion
	var space: PhysicsDirectSpaceState3D = ball.get_world_3d().direct_space_state
	var initial: Array[Dictionary] = space.intersect_shape(query, 32)
	var fractions: PackedFloat32Array = space.cast_motion(query)
	var probes: Array[Dictionary] = []
	for fraction: float in fractions:
		query.motion = Vector3.ZERO
		query.transform.origin = from + motion * fraction
		var hits: Array[Dictionary] = space.intersect_shape(query, 32)
		probes.append(
			{
				"fraction": fraction,
				"center": query.transform.origin,
				"hits": _hit_rows(hits),
				"hit_capacity": 32,
				"hit_capacity_reached": hits.size() >= 32,
				"diagnostic_water": geometry_sampler.call(query.transform.origin, ball.radius_m)
			}
		)
	if fractions.size() != 2:
		errors.append("Unexpected cast_motion fraction count")
	return {
		"errors": errors,
		"prior_source_kind": source_kind,
		"prior": prior,
		"current_before_super": current,
		"query_physics_frame": Engine.get_physics_frames(),
		"from_transform": prior.transform * collision.transform,
		"motion": motion,
		"motion_kind": "PRIOR_VELOCITY_PLUS_PRIOR_GRAVITY_ONE_STEP_STRAIGHT_PREDICTOR",
		"actual_current_center": current.transform.origin,
		"shape_radius": collision.shape.radius,
		"shape_margin": collision.shape.margin,
		"query_margin": query.margin,
		"collision_mask": query.collision_mask,
		"excluded_ball_rid": ball.get_rid().get_id(),
		"initial_hits": _hit_rows(initial),
		"initial_hit_capacity": 32,
		"initial_hit_capacity_reached": initial.size() >= 32,
		"safe_unsafe_fractions": fractions,
		"bracket_width_m":
		absf(fractions[1] - fractions[0]) * motion.length() if fractions.size() == 2 else -1,
		"fraction_probes": probes,
		"initial_diagnostic_water": geometry_sampler.call(from, ball.radius_m),
		"actual_reflected_path_is_not_reconstructed": true,
		"initial_overlap_can_invalidate_cast_first_hit_interpretation": not initial.is_empty(),
		"gravity_predictor_is_not_a_contact_toi_or_proven_actual_path": true
	}


static func _hit_rows(hits: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hit: Dictionary in hits:
		result.append(
			{
				"collider_instance": hit.collider.get_instance_id(),
				"collider_id": hit.collider_id,
				"rid": hit.rid.get_id(),
				"shape_index": hit.shape
			}
		)
	return result
