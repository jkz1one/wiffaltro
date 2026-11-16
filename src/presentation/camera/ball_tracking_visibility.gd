class_name BallTrackingVisibility
extends RefCounted

# Presentation-only bounds include scenery without gameplay collision shapes.
const WALL_CAMERA_CLEARANCE: float = 1.2
var field_wall_z: float = 23.4
var _obstacles: Array[AABB] = []
var _uprights: Array[AABB] = []
var _recipe: StadiumRecipeBoundary = null
var _wall_bounds: Array[AABB] = []
var _wall_prisms: StadiumWallViewPrisms = null
# Optional exact installed receiver scope. Ordinary/legacy collection is unchanged.
var _owned_receiver_models: Array[WeakRef] = []
var _owned_receiver_excluded: Callable
var _owned_receiver_bounds: Array[Dictionary] = []


func bind_owned_receivers(models: Array[Node3D], excluded: Callable) -> bool:
	if not excluded.is_valid() or models.is_empty() or _owned_receiver_excluded.is_valid():
		return false
	for model: Node3D in models:
		if not is_instance_valid(model):
			return false
	_owned_receiver_models.clear()
	for model: Node3D in models:
		_owned_receiver_models.append(weakref(model))
	_owned_receiver_excluded = excluded
	return true


func clear_owned_receivers(excluded: Callable) -> void:
	if _owned_receiver_excluded != excluded:
		return
	# Keep already-collected bounds as normal obstacles after retirement. This must
	# never silently grant a foreign/replaced model the old receiver exclusion.
	_owned_receiver_excluded = Callable()
	_owned_receiver_models.clear()


func owns_receiver_scope(models: Array[Node3D], excluded: Callable) -> bool:
	if _owned_receiver_excluded != excluded or models.size() != _owned_receiver_models.size():
		return false
	for index in range(models.size()):
		if _owned_receiver_models[index].get_ref() != models[index]:
			return false
	return true


func _is_owned_receiver(model: Node3D) -> bool:
	for ref: WeakRef in _owned_receiver_models:
		if ref.get_ref() == model:
			return true
	return false


func _receiver_skip_table() -> Dictionary:
	var skipped: Dictionary = {}
	if not _owned_receiver_excluded.is_valid():
		return skipped
	# The authority is checked once per exact owner and query, not once per wire.
	for ref: WeakRef in _owned_receiver_models.duplicate():
		var model: Node3D = ref.get_ref() as Node3D
		if model != null and _owned_receiver_excluded.is_valid():
			skipped[model] = bool(_owned_receiver_excluded.call(model))
	return skipped


func configure(geometry: Node) -> void:
	_wall_prisms = null
	_wall_bounds.clear()
	_recipe = null
	_obstacles.clear()
	_uprights.clear()
	_owned_receiver_bounds.clear()
	var wall: Node3D = geometry.get_node_or_null("BackWall")
	if wall != null:
		field_wall_z = wall.global_position.z - 0.25
	var property: StadiumPropertyGeometry = geometry.get_node_or_null("HomeProperty")
	if property != null:
		field_wall_z = property.field.back_wall_z_m
		var template: Node = property.get_node_or_null("TemplateBackWall")
		if template != null:
			_collect(template)
		var boundary: Node3D = property.get_node_or_null("BoundaryGraph")
		if boundary != null:
			if boundary is StadiumRecipeBoundaryBody:
				_recipe = boundary.graph
				_wall_prisms = StadiumWallViewPrisms.new(_recipe)
				_wall_bounds.assign(boundary.visibility_bounds())
				field_wall_z = 0
				for point: Vector2 in boundary.graph.polygon():
					field_wall_z = maxf(field_wall_z, point.y)
			else:
				_obstacles.append_array(boundary.visibility_bounds())
		for model: Node3D in property.objects.values():
			if model.get_meta("stadium_item", "") in ["ST-046", "ST-112"]:
				_collect(model)  # The frozen waterfall deliberately has direct meshes and no Visual wrapper.
				continue
			if _is_owned_receiver(model):
				_collect_owned_receiver(model.get_node("Visual"), model)
				continue
			# Receiver foreground conflicts fade in place; hard avoidance can push a close foul
			# out of frame before the deliberately bounded camera turn catches up.
			if model.get_meta("stadium_item", "") in ["ST-079", "ST-026", "ST-025"]:
				continue
			_collect(
				model.get_node("Visual"),
				not (
					StadiumPurchases.SEATING.has(model.get_meta("stadium_item", ""))
					or StadiumPurchases.BLEACHERS.has(model.get_meta("stadium_item", ""))
					or StadiumPurchases.DISPLAYS.has(model.get_meta("stadium_item", ""))
					or StadiumPurchases.LIGHTS.has(model.get_meta("stadium_item", ""))
				)
			)
			if model.get_meta("stadium_item", "") == "ST-047":
				_collect_swept_apple(
					model.get_node("RisingAssembly/Visual"),
					model.global_basis * Vector3.UP * StadiumRisingAppleModels.MAX_RISE
				)
	for node_name in ["BackWall", "LiveObjectPole", "CommonsParkScenery"]:
		var node: Node = geometry.get_node_or_null(node_name)
		if node != null:
			_collect(node)


func defense_depth(x: float, desired: float, ball: Vector3 = Vector3.ZERO) -> float:
	if _recipe == null:
		return minf(field_wall_z - 0.05, desired)
	var path: Vector3 = Vector3(ball.x, 0, ball.z)
	if path.length_squared() > 0.0001:
		var exit: Dictionary = _recipe.crossing(Vector3.ZERO, path * 1000)
		if exit.get("role", "") in ["SIDE_RETURN_LIVE", "REAR_PERIMETER_DEAD"]:
			return _side_depth(x, desired)
	# The camera uses the polygon's visibility kernel: staying field-side of
	# every back-face supporting line avoids looking through a re-entrant notch.
	# This restricts presentation only, never the defender's playable polygon.
	var depth: float = field_wall_z - WALL_CAMERA_CLEARANCE
	for row: Dictionary in _recipe.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		var normal: Vector2 = _recipe.inward(row)
		if normal.y < -StadiumRecipeBoundary.EPS:
			depth = minf(
				depth, row.a.y - ((x - row.a.x) * normal.x - WALL_CAMERA_CLEARANCE) / normal.y
			)
	return minf(depth, desired)


func _side_depth(x: float, desired: float) -> float:
	# A lateral foul does not need the back-wall kernel. Keep its established
	# toward-home coverage rather than racing forward and below the ball.
	var depth: float = field_wall_z
	var nearest: float = INF
	for row: Dictionary in _recipe.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		var at: float = clampf(x, minf(row.a.x, row.b.x), maxf(row.a.x, row.b.x))
		var distance: float = absf(x - at)
		if distance < nearest:
			nearest = distance
			depth = lerpf(row.a.y, row.b.y, inverse_lerp(row.a.x, row.b.x, at))
	return minf(depth - WALL_CAMERA_CLEARANCE, desired)


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
	for bounds in _uprights:
		if bounds.get_center().distance_to(ball) < 6.75:
			return 14.0
	var skipped: Dictionary = _receiver_skip_table()
	for row: Dictionary in _owned_receiver_bounds:
		if (
			not skipped.get(row.owner.get_ref(), false)
			and row.upright
			and row.bounds.get_center().distance_to(ball) < 6.75
		):
			return 14.0
	return 0.0


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	if _wall_blocked(camera, ball):
		return true
	var obstacles: Array[AABB] = _obstacles.duplicate()
	var skipped: Dictionary = _receiver_skip_table()
	for row: Dictionary in _owned_receiver_bounds:
		if not skipped.get(row.owner.get_ref(), false):
			obstacles.append(row.bounds)
	for bounds in obstacles:
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


func _wall_blocked(camera: Vector3, ball: Vector3) -> bool:
	if _wall_prisms != null:
		return _wall_prisms.blocked(camera, ball, _wall_prisms.margin(ball))
	# Joined wall pieces are one obstacle. Independent inflation lets a remote
	# piece grow over a ball beside its neighbor, inventing a wall inside the field.
	var margin: float = 0.4
	for bounds: AABB in _wall_bounds:
		var nearest: Vector3 = Vector3(
			clampf(ball.x, bounds.position.x, bounds.end.x),
			clampf(ball.y, bounds.position.y, bounds.end.y),
			clampf(ball.z, bounds.position.z, bounds.end.z)
		)
		margin = minf(margin, ball.distance_to(nearest) * 0.5)
	for bounds: AABB in _wall_bounds:
		if bounds.grow(margin).intersects_segment(camera, ball) != null:
			return true
	return false


func _collect(node: Node, allow_upright: bool = true) -> void:
	if node is MeshInstance3D and node.mesh != null and node.visible:
		var bounds: AABB = node.global_transform * node.get_aabb()
		# Turf stripes are surface decals, not occluders. Inflating their
		# millimeter thickness made rolling balls trigger huge false recoveries.
		if bounds.size.y > 0.025:
			_obstacles.append(bounds)
			if (
				allow_upright
				and bounds.size.x < 1.5
				and bounds.size.z < 1.5
				and bounds.size.y > 0.5
			):
				_uprights.append(bounds)
	for child in node.get_children():
		_collect(child, allow_upright)


func _collect_swept_apple(node: Node, travel: Vector3) -> void:
	# The entire approved vertical travel stays occupied for camera avoidance.
	# This is collected once at the owned down-state installation, with no frame cache.
	if node is MeshInstance3D and node.mesh != null and node.visible:
		var down: AABB = node.global_transform * node.get_aabb()
		var swept: AABB = down.merge(AABB(down.position + travel, down.size))
		_obstacles.append(swept)
		if swept.size.x < 1.5 and swept.size.z < 1.5 and swept.size.y > 0.5:
			_uprights.append(swept)
	for child: Node in node.get_children():
		_collect_swept_apple(child, travel)


func _collect_owned_receiver(node: Node, model: Node3D) -> void:
	# Include hidden members now, so restoration needs no reconfigure gap. Expand
	# MultiMesh instances separately: the empty cup is not a solid aggregate box.
	if node is MeshInstance3D and node.mesh != null:
		_owned_bound(model, node.global_transform * node.get_aabb())
	elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		var multi: MultiMesh = node.multimesh
		var count: int = (
			multi.instance_count
			if multi.visible_instance_count < 0
			else mini(multi.instance_count, multi.visible_instance_count)
		)
		for index in range(count):
			_owned_bound(
				model,
				(
					(node.global_transform * multi.get_instance_transform(index))
					* multi.mesh.get_aabb()
				)
			)
	for child: Node in node.get_children():
		_collect_owned_receiver(child, model)


func _owned_bound(model: Node3D, bounds: AABB) -> void:
	if bounds.size.y <= 0.025:
		return
	_owned_receiver_bounds.append(
		{
			"owner": weakref(model),
			"bounds": bounds,
			"upright": bounds.size.x < 1.5 and bounds.size.z < 1.5 and bounds.size.y > 0.5
		}
	)
