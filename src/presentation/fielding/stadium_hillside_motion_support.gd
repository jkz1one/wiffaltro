extends RefCounted
## Private inherited terrain support, pose recovery, and tracking state.

# Retained anchor provider's physical-ray allowance, not a movement clearance.
const _SUPPORT_SUPPORT_RAY_ERROR_M: float = 0.0002
# Working cost bounds, not claims of exact per-tick arrival. Reuse the retained
# terrain model for advisory support; actual commits still ray-check every point.
const _SUPPORT_WORKING_COARSE_SUPPORT_POINTS: int = 8
const _SUPPORT_WORKING_MAX_FORECAST_SECONDS: float = 3.0
const _SUPPORT_WORKING_REPLAN_SECONDS: float = 0.10

var blocked: bool = true
var last_error: String = "A successful explicit binding is required."
var last_path: Dictionary = {}
# Written by ordinary automatic callers only, never by a read-only provider/step.
var last_tracking_plan: FielderPlan
var tracking_plan_count: int = 0
var last_tracking_usec: int = 0
var tracking_total_usec: int = 0
var profile: String = "hill"
var anchor_index: int = -1

# A separate adapter instance owns the actual non-colliding pitcher marker.
var presentation_active: bool = false
var _tracking_elapsed_seconds: float = 0.0
var _field: FieldDefinition
var _bound_fielder: FielderController
var _terrain: Node3D
var _body: StaticBody3D
var _shape_node: CollisionShape3D
var _shape: ConcavePolygonShape3D
var _signature: String = ""
var _public_owner: StadiumNpcPublicProperty
var _boundary: StadiumRecipeBoundary
var _boundary_polygon: PackedVector2Array
var _boundary_clip: Callable
var _last_valid_position: Vector3
var _has_valid_position: bool = false
var _pitcher_actor: Node3D
var _pitcher_basis: Basis = Basis.IDENTITY
var _pitcher_context: FielderController
var _pitcher_context_motion: StadiumHillsideDefenderMotion



func accept_position(at: Vector3) -> void:
	_last_valid_position = at
	_has_valid_position = true


func fail(fielder: FielderController, message: String) -> bool:
	blocked = true
	last_error = message
	fielder.velocity = Vector3.ZERO
	if _has_valid_position:
		fielder.global_position = _last_valid_position
	return false


func _anchor_support(requested: Vector3) -> Dictionary:
	if _field == null or not requested.is_finite() or not _legal_origin(requested):
		return {}
	var record: Dictionary = StadiumHillsideAnchorContract.support(
		Vector2(requested.x, requested.z), profile
	)
	if record.is_empty():
		return {}
	record["index"] = -1
	for index in range(StadiumHillsideAnchorContract.SLOT_COUNT):
		var source: Vector3 = _field.fielder_anchor(index)
		if source.x == requested.x and source.z == requested.z:
			if not _field.is_fielder_anchor_available(index):
				return {}
			record["index"] = index
	return record


func _legal_origin(at: Vector3) -> bool:
	if _boundary == null or not at.is_finite():
		return false
	var xz: Vector2 = Vector2(at.x, at.z)
	if not _boundary.contains(xz):
		return false
	for row: Dictionary in _boundary.segments():
		if (
			xz.distance_to(Geometry2D.get_closest_point_to_segment(xz, row.a, row.b))
			< StadiumRecipeBoundary.DEFENDER_RADIUS - StadiumRecipeBoundary.EPS
		):
			return false
	return true


func _structure_valid(fielder: FielderController) -> bool:
	if (
		_public_owner != null
		and (
			not is_instance_valid(_public_owner)
			or not _public_owner.hillside_owner_intact()
			or _public_owner.boundary.graph != _boundary
			or _public_owner.construction.terrain != _terrain
		)
	):
		return false
	if (
		not fielder.is_inside_tree()
		or fielder.global_basis != Basis.IDENTITY
		or not is_instance_valid(_terrain)
		or _terrain.is_queued_for_deletion()
		or not _terrain.is_inside_tree()
		or _terrain.global_transform != Transform3D.IDENTITY
		or _terrain.get_world_3d() != fielder.get_world_3d()
		or _terrain.get_meta("terrain_profile", "") != profile
		or _terrain.get_meta("terrain_signature", "") != _signature
		or fielder.stadium_boundary_clip != _boundary_clip
		or _boundary == null
		or _boundary.polygon() != _boundary_polygon
	):
		return false
	if (
		not is_instance_valid(_body)
		or _body.is_queued_for_deletion()
		or _terrain.get_node_or_null("TerrainCollision") != _body
		or _body.transform != Transform3D.IDENTITY
		or _body.get_meta("ball_surface", "") != StadiumHillsideTerrainModels.SURFACE
		or _body.get_meta("terrain_profile", "") != profile
	):
		return false
	var required_layer: int = 1 | StadiumHillsideTerrainModels.QUERY_LAYER
	if (
		(_body.collision_layer & required_layer) != required_layer
		or not is_instance_valid(_shape_node)
		or _shape_node.is_queued_for_deletion()
		or _body.get_node_or_null("ClosedTerrainShape") != _shape_node
		or _shape_node.disabled
		or _shape_node.transform != Transform3D.IDENTITY
		or _shape == null
		or _shape_node.shape != _shape
		or _shape.margin != 0.0
		or _shape.backface_collision
	):
		return false
	for row: Dictionary in fielder.stadium_obstacles:
		if (
			row.get("owned_pool", false) == true
			or not row.get("center") is Vector3
			or not row["center"].is_finite()
			or not (row.get("radius") is float or row.get("radius") is int)
			or not is_finite(float(row["radius"]))
			or float(row["radius"]) < 0
		):
			return false
	return true


func _physical_support(fielder: FielderController, at: Vector3) -> bool:
	if not _structure_valid(fielder) or not at.is_finite():
		return false
	var record: Dictionary = StadiumHillsideAnchorContract.support(Vector2(at.x, at.z), profile)
	if (
		record.is_empty()
		or absf(at.y - float(record["support_height"])) > StadiumHillsideTerrain.EPS
	):
		return false
	var sample: Vector3 = record["position"]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		sample + Vector3.UP * 3.0,
		sample - Vector3.UP * 3.0,
		StadiumHillsideTerrainModels.QUERY_LAYER
	)
	var hit: Dictionary = fielder.get_world_3d().direct_space_state.intersect_ray(query)
	return (
		not hit.is_empty()
		and hit.get("collider") == _body
		and (hit["position"] as Vector3).distance_to(sample) <= _SUPPORT_SUPPORT_RAY_ERROR_M
	)


func set_pitcher_rotation(angle: float) -> void:
	# Called only by the already-guarded ordinary delivery/lunge presentation.
	_pitcher_actor.rotation.z = angle
	_pitcher_basis = _pitcher_actor.global_basis


func fail_pitcher(message: String) -> bool:
	blocked = true
	last_error = message
	if _has_valid_position and is_instance_valid(_pitcher_actor):
		_pitcher_actor.global_position = _last_valid_position
	return false


func _primary_other(fielder: FielderController) -> Vector3:
	if fielder.pitcher_lane_z == INF:
		return Vector3.INF
	return (
		fielder.pitcher_defender.global_position
		if is_instance_valid(fielder.pitcher_defender)
		else Vector3(0.0, 0.0, fielder.pitcher_lane_z)
	)


func _valid_obstacles(obstacles: Array[Dictionary]) -> bool:
	for row: Dictionary in obstacles:
		if (
			row.get("owned_pool", false) == true
			or not row.get("center") is Vector3
			or not row["center"].is_finite()
			or not (row.get("radius") is float or row.get("radius") is int)
			or not is_finite(float(row["radius"]))
			or float(row["radius"]) < 0
		):
			return false
	return true


func _support_coordinate(at: Vector3) -> bool:
	if not at.is_finite():
		return false
	var height: float = StadiumHillsideTerrain.support_height(Vector2(at.x, at.z), profile)
	return is_finite(height) and absf(at.y - height) <= StadiumHillsideTerrain.EPS


func _candidate_path(from: Vector3, proposed: Vector3, travel: float) -> Array[Vector3]:
	var path: Array[Vector3] = [from]
	if not proposed.is_finite():
		return []
	if profile == "flat-control":
		path.append(proposed)
		return path
	var heading: Vector2 = Vector2(proposed.x - from.x, proposed.z - from.z)
	var result: Dictionary = StadiumHillsideLocomotion.step(from, heading, travel, profile)
	if result.is_empty():
		return []
	for index in range(1, result.path.size()):
		var at: Vector3 = result.path[index]
		if Vector2(at.x - from.x, at.z - from.z).length() >= heading.length():
			var record: Dictionary = StadiumHillsideAnchorContract.support(
				Vector2(proposed.x, proposed.z), profile
			)
			if record.is_empty():
				return []
			path.append(record["position"])
			break
		path.append(at)
	return path


func _read_only_path(
	context: FielderController,
	path: Array[Vector3],
	budget: float,
	rows: Array[Dictionary],
	coarse_support_points: int = 0
) -> Dictionary:
	if (
		path.is_empty()
		or coarse_support_points < 0
		or coarse_support_points > _SUPPORT_WORKING_COARSE_SUPPORT_POINTS
		or coarse_support_points == 1
	):
		return {}
	var travel: float = 0.0
	# Geometry/obstacle validation uses the retained arc in both modes. Advisory
	# support samples use its immutable model; only actual commits ray-check it.
	for index in range(path.size()):
		var at: Vector3 = path[index]
		if not _legal_origin(at) or (coarse_support_points == 0 and not _support_coordinate(at)):
			return {}
		if index > 0:
			var before: Vector3 = path[index - 1]
			if at != before and not StadiumDefenderRoutes.clear(before, at, rows):
				return {}
			travel += before.distance_to(at)
	# Preserve the retained arc algorithm's original budget behavior. The raw
	# float32 path remeasurement residual is diagnostic, never a new cutoff.
	var checks: int = (
		path.size() if coarse_support_points == 0 else mini(coarse_support_points, path.size())
	)
	for index in range(checks):
		var path_index: int = (
			index
			if coarse_support_points == 0
			else int(round(float(index) * float(path.size() - 1) / float(maxi(checks - 1, 1))))
		)
		var supported: bool = (
			_physical_support(context, path[path_index])
			if coarse_support_points == 0
			else _support_coordinate(path[path_index])
		)
		if not supported:
			return (
				{"valid": false, "support_checks": index + 1, "support_segments": index}
				if coarse_support_points > 0
				else {}
			)
	return {
		"valid": true,
		"position": path[-1],
		"path": path,
		"travel": travel,
		"budget": budget,
		"budget_remeasurement_delta": travel - budget,
		"support_checks": checks,
		"support_segments": maxi(0, checks - 1),
		"advisory": coarse_support_points > 0
	}


func tracking_due(delta: float) -> bool:
	# Actual automatic callers only. The first eligible plan is immediate.
	if not is_finite(delta) or delta <= 0.0:
		return false
	if last_tracking_plan == null:
		return true
	_tracking_elapsed_seconds += delta
	if _tracking_elapsed_seconds < _SUPPORT_WORKING_REPLAN_SECONDS:
		return false
	var intervals: int = maxi(
		1, int(floor(_tracking_elapsed_seconds / _SUPPORT_WORKING_REPLAN_SECONDS))
	)
	_tracking_elapsed_seconds = maxf(
		0.0, _tracking_elapsed_seconds - float(intervals) * _SUPPORT_WORKING_REPLAN_SECONDS
	)
	return true


func record_tracking_plan(plan: FielderPlan, elapsed_usec: int) -> void:
	last_tracking_plan = plan
	tracking_plan_count += 1
	last_tracking_usec = maxi(0, elapsed_usec)
	tracking_total_usec += last_tracking_usec


func reset_tracking() -> void:
	last_tracking_plan = null
	tracking_plan_count = 0
	last_tracking_usec = 0
	tracking_total_usec = 0
	_tracking_elapsed_seconds = 0.0


func _forecast_support(xz: Vector2, context: FielderController, snapshot: Dictionary) -> Dictionary:
	# One counter per forecast sample, confined to this plan's private snapshot.
	snapshot.support_checks = 0
	return _planning_support(xz, context, snapshot)


func _planning_support(
	xz: Vector2, _context: FielderController, snapshot: Dictionary
) -> Dictionary:
	# Cache only within this synchronous plan; never persist across live frames.
	# The actual origin was physically checked once when the snapshot was made.
	var cache: Dictionary = snapshot.support_cache
	if not cache.has(xz):
		if int(snapshot.support_checks) >= _SUPPORT_WORKING_COARSE_SUPPORT_POINTS:
			return {}
		# Retained model, not a physics prediction. Actual movement/control still
		# require exact bound-body support and can refuse this advisory route.
		var record: Dictionary = StadiumHillsideAnchorContract.support(xz, profile)
		snapshot.support_checks = int(snapshot.support_checks) + 1
		cache[xz] = record
	return cache[xz]


func _within_forecast_envelope(
	at: Vector3, ball: Vector3, ball_feet: Vector3, reach: float, allowed_height: float
) -> bool:
	return (
		at.is_finite()
		and Vector2(ball.x - at.x, ball.z - at.z).length() <= reach
		and ball.y >= ball_feet.y
		and ball.y - at.y <= allowed_height
	)
