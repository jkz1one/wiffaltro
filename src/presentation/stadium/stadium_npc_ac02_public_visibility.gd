class_name StadiumNpcAc02PublicVisibility
extends StadiumNpcRetainedVisibility
## AC-02 retained 15-group visibility: four dormant Club towers and exact lower stands/canopies.
## Retains member-level cup, open-dugout and inherited Club clearance algorithms.


const RECEIVER_WALL_ITEMS: Array[String] = [
	"ST-026", "ST-073", "ST-065", "ST-065-L", "ST-022", "ST-023"
]
# Exact occupied retained factory mesh counts, including each crowd body/head/two hands.
const MESH_COUNTS: Dictionary = {
	"ST-021": 2, "ST-074": 12, "ST-029": 420, "ST-053": 6, "ST-039": 14, "ST-038": 64
}
var coverage_live: bool = false
var step_enrolled: bool = false
var step_segment: String = ""
var step_neighbor: String = ""
var step_plane: Plane
var _boundary_ref: WeakRef
var _graph_ref: WeakRef



func configure_property(value: StadiumNpcRetainedProperty) -> void:
	if not StadiumNpcAc02IssuedWritersV1.preissue_only(property, "visibility-reconfigure") \
		or not StadiumNpcAc02IssuedWritersV1.preissue_only(value, "visibility-owner-reconfigure"):
		return
	property = value
	_groups.clear()
	_rails.clear()
	_wall_bounds.clear()
	_obstacles.clear()
	_uprights.clear()
	_recipe = null
	_wall_prisms = null
	if property == null or property.venue_id != "AC-02":
		return
	if not property.boundary is StadiumNpcAc02PublicBoundary:
		return
	_recipe = property.boundary.graph
	_boundary_ref = weakref(property.boundary)
	_graph_ref = weakref(_recipe)
	# The retained Club prism algorithm leaves the two dugout openings visually open.
	_wall_prisms = StadiumNpcRetainedVisibility.prisms(_recipe, "AC-01")
	field_wall_z = 0
	for point: Vector2 in _recipe.polygon():
		field_wall_z = maxf(field_wall_z, point.y)
	if not _configure_mogul_two():
		_groups.clear()


func _configure_mogul_two() -> bool:
	if not StadiumNpcAc02IssuedWritersV1.preissue_only(property, "visibility-rebuild"):
		return false
	# Reuse retained Club member-level occlusion with local poses, including detached audits.
	for row: Dictionary in _recipe.segments():
		if row.role.begins_with("DUGOUT"):
			_rails.append({"a": row.a, "normal": _recipe.inward(row)})
	var counts: Dictionary = {}
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		if not is_instance_valid(model) or model.get_meta("npc_instance", "") != identity:
			return false
		var item: String = model.get_meta("stadium_item", "")
		counts[item] = int(counts.get(item, 0)) + 1
		if item in RECEIVER_WALL_ITEMS:
			continue
		var visual: Node3D = model.get_node_or_null("Visual") as Node3D
		if not MESH_COUNTS.has(item) or visual == null or not visual.visible:
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
		if members.size() != MESH_COUNTS[item]:
			return false
		_groups.append({"identity": identity, "item": item, "bounds": broad, "members": members})
	return counts == StadiumNpcAc02PublicConstruction.COUNTS and _groups.size() == 15


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	if _groups.size() != 15:
		return true
	if property == null or property.venue_id != "AC-02" or _recipe == null:
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
	if _groups.size() != 15:
		return true
	if property == null or property.venue_id != "AC-02":
		return _blocked(camera, ball)
	if _wall_prisms.blocked(camera, ball, 0):
		return true
	for group: Dictionary in _groups:
		if group.bounds.intersects_segment(camera, ball) != null \
			and _member_blocked(group.members, camera, ball, 0):
			return true
	return false


func clear_position(desired: Vector3, ball: Vector3) -> Vector3:
	if coverage_active():
		var gap: float = step_plane.distance_to(desired)
		if gap < WALL_CAMERA_CLEARANCE:
			desired += step_plane.normal * (WALL_CAMERA_CLEARANCE - gap)
	if property != null and property.venue_id == "AC-02" \
		and _recipe != null and desired.z < 0 and desired.z < ball.z:
		# Behind-home coverage must stay on the field side of both dugout rail lines.
		# Otherwise it changes from above-roof to below-roof sight through an opaque band.
		for row: Dictionary in _rails:
			var normal: Vector2 = row.normal
			var gap: float = normal.dot(Vector2(desired.x, desired.z) - row.a)
			if gap < WALL_CAMERA_CLEARANCE and absf(normal.x) > 0.01:
				desired.x += (WALL_CAMERA_CLEARANCE - gap) / normal.x
	return super.clear_position(desired, ball)


func defense_depth(x: float, desired: float, ball: Vector3 = Vector3.ZERO) -> float:
	if _groups.size() != 15:
		return super.defense_depth(x, desired, ball)
	var path: Vector3 = Vector3(ball.x, 0, ball.z)
	if path.length_squared() > 0.0001:
		var exit: Dictionary = _recipe.crossing(Vector3.ZERO, path * 1000)
		var role: String = exit.get("role", "")
		if role in ["SIDE_RETURN_LIVE", "REAR_PERIMETER_DEAD"] or role.begins_with("DUGOUT"):
			return _side_depth(x, desired)
	var backs: Array[Dictionary] = []
	var depth: float = field_wall_z
	var nearest: float = INF
	for row: Dictionary in _recipe.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		backs.append(row)
		var at: float = clampf(x, minf(row.a.x, row.b.x), maxf(row.a.x, row.b.x))
		var distance: float = absf(x - at)
		var normal: Vector2 = _recipe.inward(row)
		var local_depth: float = lerpf(row.a.y, row.b.y, inverse_lerp(row.a.x, row.b.x, at)) \
			- WALL_CAMERA_CLEARANCE / maxf(0.01, absf(normal.y))
		if distance < nearest - StadiumRecipeBoundary.EPS:
			nearest = distance
			depth = local_depth
		elif absf(distance - nearest) <= StadiumRecipeBoundary.EPS:
			depth = minf(depth, local_depth)
	# Select interior BACK faces, never raw polygon indices shifted by dugout subdivisions.
	for index in range(1, backs.size() - 1):
		var row: Dictionary = backs[index]
		var normal: Vector2 = _recipe.inward(row)
		if normal.y < -StadiumRecipeBoundary.EPS:
			depth = minf(depth, row.a.y - (
				(x - row.a.x) * normal.x - WALL_CAMERA_CLEARANCE) / normal.y)
	return minf(depth, desired)


func prepare_coverage(defense: bool, ball: Vector3, launch: Vector3) -> void:
	# Observe only this launch and the admitted geometry, never a future contact/result.
	coverage_live = false
	step_enrolled = false
	step_segment = ""
	step_neighbor = ""
	if not defense or not _coverage_geometry_intact() or not ball.is_finite() \
		or not launch.is_finite():
		return
	var horizontal: Vector3 = Vector3(launch.x, 0, launch.z)
	if horizontal.length_squared() <= StadiumRecipeBoundary.EPS:
		return
	var start: Vector3 = Vector3(ball.x, 0, ball.z)
	var reach: float = WALL_CAMERA_CLEARANCE
	for point: Vector2 in _recipe.polygon():
		reach = maxf(reach, Vector2(start.x, start.z).distance_to(point) + WALL_CAMERA_CLEARANCE)
	var crossing: Dictionary = _recipe.crossing(start, start + horizontal.normalized() * reach)
	var rows: Array[Dictionary] = _recipe.segments()
	for index in range(rows.size()):
		var low: Dictionary = rows[index]
		if low.id != crossing.get("segment", "") or low.role != "BACK_WALL_TERMINAL":
			continue
		for offset: int in [-1, 1]:
			var tall: Dictionary = rows[(index + offset + rows.size()) % rows.size()]
			if tall.role != "BACK_WALL_TERMINAL" or tall.height <= low.height:
				continue
			var vertex: int = index if offset == -1 else (index + 1) % rows.size()
			var join: Vector2 = low.a if offset == -1 else low.b
			var at: Vector3 = crossing.position
			if Vector2(at.x, at.z).distance_to(join) > WALL_CAMERA_CLEARANCE:
				continue
			var cap: Vector2 = _recipe.outer_vertex(vertex) - join
			var normal: Vector2 = Vector2(-cap.y, cap.x).normalized()
			if normal.dot((low.a + low.b) * 0.5 - join) < 0:
				normal = -normal
			step_plane = Plane(Vector3(normal.x, 0, normal.y), normal.dot(join))
			step_segment = low.id
			step_neighbor = tall.id
			step_enrolled = true
			return



func _coverage_geometry_intact() -> bool:
	return _groups.size() == 15 and is_instance_valid(property) and property.is_inside_tree() \
		and property.get_script() == StadiumNpcPublicProperty \
		and property.venue_id == "AC-02" and property.global_transform == Transform3D.IDENTITY \
		and property.boundary is StadiumNpcAc02PublicBoundary \
		and property.boundary.get_parent() == property \
		and _boundary_ref != null and _boundary_ref.get_ref() == property.boundary \
		and property.boundary.source is StadiumNpcAc02PublicBoundarySource \
		and property.boundary.source.get_parent() == property.construction \
		and property.boundary.source.transform == Transform3D.IDENTITY \
		and property.boundary.graph == _recipe and _recipe != null \
		and _graph_ref != null and _graph_ref.get_ref() == _recipe \
		and _recipe.get_script() == StadiumNpcAc02PublicGraph


func coverage_active() -> bool:
	if not coverage_live or not step_enrolled or not _coverage_geometry_intact():
		return false
	var lab: PitchBatLab = property.lab_ref.get_ref() as PitchBatLab \
		if property.lab_ref != null else null
	return lab != null and lab._camera_director is StadiumNpcAc02PublicCamera \
		and lab._camera_director.tracking_visibility == self \
		and (lab._camera_director as StadiumNpcAc02PublicCamera)._step_live(lab._camera, true)


func _configure_startup(attempt: RefCounted, value: StadiumNpcPublicProperty) -> bool:
	# Startup-only copy preserves literal historical/custom virtual dispatch above.
	if attempt == null or not is_instance_valid(value) or property != null \
		or attempt != value._ac02_startup_attempt or not attempt.owns(value) \
		or attempt.state != attempt.State.PREPARING \
		or not attempt.executing or attempt.setup_complete \
		or attempt.lab._camera_director.tracking_visibility != self:
		return false
	property = value
	_groups.clear()
	_rails.clear()
	_wall_bounds.clear()
	_obstacles.clear()
	_uprights.clear()
	_recipe = null
	_wall_prisms = null
	if property == null or property.venue_id != "AC-02":
		return false
	if not property.boundary is StadiumNpcAc02PublicBoundary:
		return false
	_recipe = property.boundary.graph
	_boundary_ref = weakref(property.boundary)
	_graph_ref = weakref(_recipe)
	# The retained Club prism algorithm leaves the two dugout openings visually open.
	_wall_prisms = StadiumNpcRetainedVisibility.prisms(_recipe, "AC-01")
	field_wall_z = 0
	for point: Vector2 in _recipe.polygon():
		field_wall_z = maxf(field_wall_z, point.y)
	if not _configure_startup_geometry():
		_groups.clear()
		return false
	return attempt.owns(value) and attempt.state == attempt.State.PREPARING


func _configure_startup_geometry() -> bool:
	# Reuse retained Club member-level occlusion with local poses, including detached audits.
	for row: Dictionary in _recipe.segments():
		if row.role.begins_with("DUGOUT"):
			_rails.append({"a": row.a, "normal": _recipe.inward(row)})
	var counts: Dictionary = {}
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		if not is_instance_valid(model) or model.get_meta("npc_instance", "") != identity:
			return false
		var item: String = model.get_meta("stadium_item", "")
		counts[item] = int(counts.get(item, 0)) + 1
		if item in RECEIVER_WALL_ITEMS:
			continue
		var visual: Node3D = model.get_node_or_null("Visual") as Node3D
		if not MESH_COUNTS.has(item) or visual == null or not visual.visible:
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
		if members.size() != MESH_COUNTS[item]:
			return false
		_groups.append({"identity": identity, "item": item, "bounds": broad, "members": members})
	return counts == StadiumNpcAc02PublicConstruction.COUNTS and _groups.size() == 15
