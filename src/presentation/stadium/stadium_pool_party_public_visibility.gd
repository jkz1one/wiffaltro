class_name StadiumPoolPartyPublicVisibility
extends StadiumNpcRetainedVisibility
## POOL-PARTY exact18-group visibility: four sightline-v2 lowers, three bowls and six towers.
## Retains member-level cup, open-dugout and inherited Club clearance algorithms.


const RECEIVER_WALL_ITEMS: Array[String] = [
	"ST-026", "ST-025", "ST-024", "ST-022", "ST-023"
]
# Exact occupied retained factory mesh counts, including each crowd body/head/two hands.



func configure_property(value: StadiumNpcRetainedProperty) -> void:
	property = value
	_groups.clear()
	_rails.clear()
	_wall_bounds.clear()
	_obstacles.clear()
	_uprights.clear()
	_recipe = null
	_wall_prisms = null
	if property == null or property.venue_id != "POOL-PARTY":
		return
	if not property.boundary is StadiumPoolPartyPublicBoundary:
		return
	_recipe = property.boundary.graph
	# The retained Club prism algorithm leaves the two dugout openings visually open.
	_wall_prisms = StadiumNpcRetainedVisibility.prisms(_recipe, "AC-01")
	field_wall_z = 0
	for point: Vector2 in _recipe.polygon():
		field_wall_z = maxf(field_wall_z, point.y)
	if not _configure_grand_i():
		_groups.clear()


func _configure_grand_i() -> bool:
	# Reuse retained Club member-level occlusion with local poses, including detached audits.
	for row: Dictionary in _recipe.segments():
		if row.role.begins_with("DUGOUT"):
			_rails.append({"a": row.a, "normal": _recipe.inward(row)})
	var counts: Dictionary = {}
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		if not is_instance_valid(model) or (model.get_meta("npc_instance", "") != identity
			and identity != StadiumPoolPartyRuntime.COPY):
			return false
		var item: String = "ST-006" if identity == StadiumPoolPartyRuntime.COPY else (
			model.get_meta("stadium_item", ""))
		counts[item] = int(counts.get(item, 0)) + 1
		if item in RECEIVER_WALL_ITEMS:
			continue
		var visual: Node3D = model.get_node_or_null("Visual") as Node3D
		if visual == null or not visual.visible:
			return false
		var members: Array[Dictionary] = []
		var broad: AABB
		for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			var pose: Transform3D = _local_pose(mesh)
			if mesh.mesh == null or not mesh.visible or not pose.is_finite() \
				or absf(pose.basis.determinant()) < 0.00000001:
				return false
			var bounds: AABB = pose * mesh.get_aabb()
			broad = bounds if members.is_empty() else broad.merge(bounds)
			members.append({"inverse": pose.affine_inverse(), "bounds": mesh.get_aabb()})
			if item == "ST-021" and bounds.size.x < 1.5 \
				and bounds.size.z < 1.5 and bounds.size.y > 0.5:
				_uprights.append(bounds)
		if members.is_empty():
			return false
		_groups.append({"identity": identity, "item": item, "bounds": broad, "members": members})
	return counts == StadiumPoolPartyPublicConstruction.COUNTS and _groups.size() == 8


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	if _groups.size() != 8:
		return true
	if property == null or property.venue_id != "POOL-PARTY" or _recipe == null:
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
	if _groups.size() != 8:
		return true
	if property == null or property.venue_id != "POOL-PARTY":
		return _blocked(camera, ball)
	if _wall_prisms.blocked(camera, ball, 0):
		return true
	for group: Dictionary in _groups:
		if group.bounds.intersects_segment(camera, ball) != null \
			and _member_blocked(group.members, camera, ball, 0):
			return true
	return false


func clear_position(desired: Vector3, ball: Vector3) -> Vector3:
	if property != null and property.venue_id == "POOL-PARTY" \
		and _recipe != null and desired.z < 0 and desired.z < ball.z:
		# Behind-home coverage must stay on the field side of both dugout rail lines.
		# Otherwise it changes from above-roof to below-roof sight through an opaque band.
		for row: Dictionary in _rails:
			var normal: Vector2 = row.normal
			var gap: float = normal.dot(Vector2(desired.x, desired.z) - row.a)
			if gap < WALL_CAMERA_CLEARANCE and absf(normal.x) > 0.01:
				desired.x += (WALL_CAMERA_CLEARANCE - gap) / normal.x
	return super.clear_position(desired, ball)
