class_name StadiumHillsidePublicVisibility
extends StadiumNpcRetainedVisibility
## Actual elevated convex wall slices and all eight retained assets, ordinary role cameras.
## The existing receiver fade policy still owns foreground target/net presentation.

var _wall_slices: Array[Dictionary] = []


func configure_property(value: StadiumNpcRetainedProperty) -> void:
	property = value
	_groups.clear()
	_rails.clear()
	_wall_bounds.clear()
	_obstacles.clear()
	_uprights.clear()
	_wall_slices.clear()
	_recipe = null
	_wall_prisms = null
	if property == null or property.venue_id != "HILLSIDE" \
		or not property.construction is StadiumHillsidePublicConstruction \
		or not property.boundary is StadiumHillsidePublicContactAdapter:
		return
	_recipe = property.boundary.graph
	_wall_prisms = StadiumWallViewPrisms.new(_recipe)
	_wall_prisms.walls.clear()
	var source: StadiumHillsidePublicBoundarySource = property.construction.boundary
	for body: StaticBody3D in source.bodies:
		for child: Node in body.get_children():
			if not child is CollisionShape3D:
				continue
			if not child.shape is ConvexPolygonShape3D or child.transform != Transform3D.IDENTITY:
				_wall_prisms.walls.clear()
				return
			var slice: Dictionary = _slice(child.shape.points)
			if slice.is_empty():
				_wall_prisms.walls.clear()
				return
			_wall_slices.append(slice)
			_wall_prisms.walls.append(slice)
	_configure_property_remaining_checks()


func _configure_property_remaining_checks() -> void:
	field_wall_z = 0
	for point: Vector2 in _recipe.polygon():
		field_wall_z = maxf(field_wall_z, point.y)
	for row: Dictionary in _recipe.segments():
		if row.role.begins_with("DUGOUT"):
			_rails.append({"a": row.a, "normal": _recipe.inward(row)})
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		if model == null or model.get_meta("npc_instance", "") != identity:
			_groups.clear()
			return
		var visual: Node3D = model.get_node_or_null("Visual") as Node3D
		if visual == null:
			_groups.clear()
			return
		var members: Array[Dictionary] = []
		var broad: AABB
		var item: String = model.get_meta("stadium_item", "")
		for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			var pose: Transform3D = _local_pose(mesh)
			if mesh.mesh == null or not pose.is_finite() or absf(pose.basis.determinant()) < 0.00000001:
				_groups.clear()
				return
			var bounds: AABB = pose * mesh.get_aabb()
			broad = bounds if members.is_empty() else broad.merge(bounds)
			members.append({"inverse": pose.affine_inverse(), "bounds": mesh.get_aabb()})
			if item == "ST-021" and bounds.size.x < 1.5 \
				and bounds.size.z < 1.5 and bounds.size.y > 0.5:
				_uprights.append(bounds)
		if members.is_empty():
			_groups.clear()
			return
		_groups.append({"identity": identity, "item": item, "bounds": broad, "members": members})


static func _slice(points: PackedVector3Array) -> Dictionary:
	# These are the actual collision vertices, not flat graph-height approximations.
	var count: int = int(points.size() / 2)
	if count < 3 or points.size() != count * 2:
		return {}
	var center: Vector3 = Vector3.ZERO
	var polygon: PackedVector2Array = []
	for point: Vector3 in points:
		if not point.is_finite():
			return {}
		center += point
	center /= points.size()
	for index in range(count):
		polygon.append(Vector2(points[index].x, points[index].z))
	var planes: Array[Plane] = []
	for offset: int in [0, count]:
		var normal: Vector3 = Vector3.ZERO
		for index in range(1, count - 1):
			normal = (points[offset + index] - points[offset]).cross(
				points[offset + index + 1] - points[offset])
			if normal.length_squared() > 0.000000000001:
				break
		if normal.length_squared() <= 0.000000000001:
			return {}
		var plane: Plane = Plane(normal.normalized(), normal.normalized().dot(points[offset]))
		planes.append(Plane(-plane.normal, -plane.d) if plane.distance_to(center) > 0 else plane)
	for index in range(count):
		var next: int = (index + 1) % count
		var plane: Plane = Plane(points[index], points[next], points[count + index])
		planes.append(Plane(-plane.normal, -plane.d) if plane.distance_to(center) > 0 else plane)
	return {"polygon": polygon, "planes": planes, "height": points[count].y - points[0].y,
		"points": points}


func cold_valid(expected: StadiumHillsidePublicVisibility) -> bool:
	return expected != null and _groups.size() == 8 and not _wall_slices.is_empty() \
		and _wall_prisms != null and expected._wall_prisms != null \
		and _wall_prisms.walls == _wall_slices and expected._wall_prisms.walls == expected._wall_slices \
		and var_to_bytes(_wall_slices) == var_to_bytes(expected._wall_slices) \
		and var_to_bytes(_groups) == var_to_bytes(expected._groups) \
		and _uprights == expected._uprights and _rails == expected._rails \
		and field_wall_z == expected.field_wall_z


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	if _groups.size() != 8 or _wall_slices.is_empty() or _wall_prisms == null:
		return true
	if _wall_blocked(camera, ball):
		return true
	for group: Dictionary in _groups:
		# Match existing normal-camera behavior: receiver conflicts fade in place.
		if group.item in ["ST-026", "ST-025"]:
			continue
		if group.bounds.grow(0.4).intersects_segment(camera, ball) != null \
			and _member_blocked(group.members, camera, ball):
			return true
	return false


func actual_blocked(camera: Vector3, ball: Vector3) -> bool:
	if _groups.size() != 8 or _wall_slices.is_empty() or _wall_prisms == null:
		return true
	if _wall_prisms.blocked(camera, ball, 0):
		return true
	for group: Dictionary in _groups:
		var model: Node3D = property.objects[group.identity]
		if not model.get_node("Visual").visible:
			continue
		if group.bounds.intersects_segment(camera, ball) != null \
			and _member_blocked(group.members, camera, ball, 0):
			return true
	return false


func clear_position(desired: Vector3, ball: Vector3) -> Vector3:
	if property != null and property.venue_id == "HILLSIDE" \
		and _recipe != null and desired.z < 0 and desired.z < ball.z:
		for row: Dictionary in _rails:
			var normal: Vector2 = row.normal
			var gap: float = normal.dot(Vector2(desired.x, desired.z) - row.a)
			if gap < WALL_CAMERA_CLEARANCE and absf(normal.x) > 0.01:
				desired.x += (WALL_CAMERA_CLEARANCE - gap) / normal.x
	return super.clear_position(desired, ball)
