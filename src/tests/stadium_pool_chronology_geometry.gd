class_name StadiumPoolChronologyGeometry
extends RefCounted
## Measure unchanged annular facets and real sphere queries. No rule-volume or model edits.


static func measure(host: Node3D, model: Node3D, ground: StaticBody3D, radius: float) -> Dictionary:
	var faces: PackedVector3Array = (
		model.get_node("Collision/POOL_INNER_WALL/Shape").shape.get_faces()
	)
	var visual: PackedVector3Array = (
		model.get_node("Visual/POOL_INNER_WALL").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	var inner: StaticBody3D = model.get_node("Collision/POOL_INNER_WALL")
	var excluded: Array[RID] = [ground.get_rid()]
	var exclusions: Array[Dictionary] = [
		{
			"label": "RIG_GROUND",
			"instance": ground.get_instance_id(),
			"rid": ground.get_rid().get_id()
		}
	]
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if body != inner:
			excluded.append(body.get_rid())
			exclusions.append(
				{
					"label": String(body.name),
					"instance": body.get_instance_id(),
					"rid": body.get_rid().get_id()
				}
			)
	var rows: Array[Dictionary] = []
	var errors: Array[String] = []
	if faces != visual or faces.size() != StadiumPoolContract.SEGMENTS * 6:
		errors.append("Frozen inner mesh and actual collider faces differ")
		return {"rows": rows, "errors": errors}
	var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
	for sector: int in range(StadiumPoolContract.SEGMENTS):
		# Clockwise inner quad: bottom vertices occur at offsets 0 and 4.
		var middle: Vector3 = (faces[sector * 6] + faces[sector * 6 + 4]) / 2
		var apothem: float = Vector2(middle.x, middle.z).length()
		var overlap: float = StadiumPoolContract.INNER_RADIUS - apothem
		if absf(overlap - 0.000587304) > 0.000002 or overlap <= StadiumRecipeBoundary.EPS:
			errors.append("Unexpected measured facet/carrier overlap at sector %d" % sector)
		for position_kind: String in ["midpoint", "vertex"]:
			var direction: Vector3 = (
				middle.normalized()
				if position_kind == "midpoint"
				else (Vector3(faces[sector * 6].x, 0, faces[sector * 6].z).normalized())
			)
			var expected_center_radius: float = (
				apothem - radius
				if position_kind == "midpoint"
				else (
					StadiumPoolContract.INNER_RADIUS
					- radius / cos(PI / StadiumPoolContract.SEGMENTS)
				)
			)
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = SphereShape3D.new()
			query.shape.radius = radius
			query.shape.margin = 0
			query.margin = 0
			query.collision_mask = 1
			query.exclude = excluded
			var local_from: Vector3 = direction * 1.80 + Vector3.UP * 1.025
			var local_to: Vector3 = direction * 2.05 + Vector3.UP * 1.025
			query.transform.origin = model.global_transform * local_from
			query.motion = model.global_basis * (local_to - local_from)
			var world_from: Vector3 = query.transform.origin
			var world_motion: Vector3 = query.motion
			var fractions: PackedFloat32Array = space.cast_motion(query)
			var hit: bool = fractions.size() == 2 and fractions[0] < 1
			if not hit:
				errors.append(
					"Actual sphere cast missed inner facet %d %s" % [sector, position_kind]
				)
			var contact_centers: Array[Vector3] = []
			for fraction: float in fractions:
				contact_centers.append(local_from.lerp(local_to, fraction))
			query.motion = Vector3.ZERO
			query.transform.origin = (
				model.global_transform
				* (direction * (expected_center_radius - 0.002) + Vector3.UP * 1.025)
			)
			var clear_origin: Vector3 = query.transform.origin
			var clear_probe: Array[Dictionary] = space.intersect_shape(query, 8)
			query.transform.origin = (
				model.global_transform
				* (direction * (expected_center_radius + 0.002) + Vector3.UP * 1.025)
			)
			var solid_probe: Array[Dictionary] = space.intersect_shape(query, 8)
			if not clear_probe.is_empty() or solid_probe.is_empty():
				errors.append(
					"Actual sphere clear/solid probes disagree at %d %s" % [sector, position_kind]
				)
			var all_bound: bool = true
			for result: Dictionary in solid_probe:
				all_bound = all_bound and result.collider == inner
			if not all_bound:
				errors.append("Sphere query was attributed to a foreign body")
			rows.append(
				{
					"sector": sector,
					"local_direction": direction,
					"local_from": local_from,
					"local_to": local_to,
					"world_from": world_from,
					"world_motion": world_motion,
					"world_to": world_from + world_motion,
					"clear_probe_world_origin": clear_origin,
					"solid_probe_world_origin": query.transform.origin,
					"query_collision_mask": query.collision_mask,
					"query_margin": query.margin,
					"sphere_margin": query.shape.margin,
					"excluded_bodies": exclusions.duplicate(true),
					"actual_clear_hits": hit_rows(clear_probe),
					"actual_solid_hits": hit_rows(solid_probe),
					"sample": position_kind,
					"measured_apothem": apothem,
					"measured_radial_overlap": overlap,
					"physical_ball_radius": radius,
					"ideal_offset_face_center_radius": expected_center_radius,
					"engine_safe_unsafe_fractions": fractions,
					"engine_safe_unsafe_local_centers": contact_centers,
					"clear_probe_count": clear_probe.size(),
					"solid_probe_count": solid_probe.size(),
					"all_solid_hits_bind_actual_inner_body": all_bound,
					"water_comparison_is_analytic_only": true,
					"solid_probe_geometry":
					StadiumPoolChronologyObserver.geometry_sample(query.transform.origin, radius),
					"event_order_qualified": false
				}
			)
	return {
		"schema": "POOL-FACET-SPHERE-OBSERVATION-v1",
		"rows": rows,
		"errors": errors,
		"model_instance": model.get_instance_id(),
		"model_global_transform": model.global_transform,
		"inner_body_global_transform": inner.global_transform,
		"observation_physics_frame": Engine.get_physics_frames(),
		"inner_body_instance": inner.get_instance_id(),
		"collision_faces_match_visual": faces == visual,
		"water_area_enabled": false,
		"shared_world_tolerance": StadiumRecipeBoundary.EPS,
		"runtime_entry_or_priority_qualified": false
	}


static func hit_rows(hits: Array[Dictionary]) -> Array[Dictionary]:
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
