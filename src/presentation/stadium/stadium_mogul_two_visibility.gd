class_name StadiumMogulTwoVisibility
extends StadiumClubFieldVisibility
# gdlint: disable=max-returns
## AM02-only hierarchy adapter. Inherited opaque grouping and camera margins stay unchanged.

const VISUAL_ITEMS: Array[String] = [
	"ST-021",
	"ST-074",
	"ST-029",
	"ST-081",
	"ST-039",
	"ST-076",
	"ST-031",
	"ST-030",
	"ST-053",
	"ST-085",
	"ST-088"
]
const RECEIVER_WALL_ITEMS: Array[String] = [
	"ST-026", "ST-073", "ST-065", "ST-065-T", "ST-022", "ST-023"
]
var ready: bool = false
var last_error: String = ""
var model_meshes: Dictionary = {}


func configure(geometry: Node) -> void:
	var property: StadiumMogulTwoProperty = (
		geometry.get_node_or_null("HomeProperty") as StadiumMogulTwoProperty
		if geometry != null
		else null
	)
	configure_candidate(property)


func configure_candidate(property: StadiumMogulTwoProperty) -> bool:
	_reset()
	if (
		property == null
		or not is_instance_valid(property.boundary)
		or property.boundary.graph == null
	):
		return _reject("missing complete AM02 property/boundary")
	_recipe = property.boundary.graph
	_wall_prisms = StadiumWallViewPrisms.new(_recipe)
	var rows: Array[Dictionary] = _recipe.segments()
	for row: Dictionary in rows:
		if row.role.begins_with("DUGOUT"):
			_rails.append({"a": row.a, "normal": _recipe.inward(row)})
	for index in range(rows.size() - 1, -1, -1):
		if rows[index].role.begins_with("DUGOUT"):
			_wall_prisms.walls.remove_at(index)
	field_wall_z = 0
	for point: Vector2 in _recipe.polygon():
		field_wall_z = maxf(field_wall_z, point.y)
	var counts: Dictionary = {}
	for model: Node3D in property.find_children("*", "Node3D", true, false):
		if not model.has_meta("candidate_instance"):
			continue
		var item: Variant = model.get_meta("stadium_item", "")
		var identity: Variant = model.get_meta("candidate_instance")
		if not item is String or not identity is String or property.objects.get(identity) != model:
			return _reject("invalid registered visual identity at " + str(model.get_path()))
		counts[item] = counts.get(item, 0) + 1
		if item in RECEIVER_WALL_ITEMS:
			continue
		var visual: Node

		if item in VISUAL_ITEMS:
			visual = model.get_node_or_null("Visual")
			if not visual is Node3D:
				return _reject("missing required Visual branch for " + item + ":" + identity)
		else:
			return _reject("unsupported visual item " + item + ":" + identity)
		var members: Array[Dictionary] = []
		var mesh_ids: Array[int] = []
		var broad: AABB
		for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			if (
				mesh.mesh == null
				or not mesh.is_visible_in_tree()
				or not mesh.global_transform.is_finite()
				or absf(mesh.global_basis.determinant()) < 0.00000001
			):
				return _reject(
					(
						"invalid required mesh at "
						+ str(mesh.get_path())
						+ " resource="
						+ str(mesh.mesh != null)
						+ " visible="
						+ str(mesh.is_visible_in_tree())
						+ " finite="
						+ str(mesh.global_transform.is_finite())
						+ " determinant="
						+ str(mesh.global_basis.determinant())
					)
				)
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			broad = bounds if members.is_empty() else broad.merge(bounds)
			members.append(
				{"inverse": mesh.global_transform.affine_inverse(), "bounds": mesh.get_aabb()}
			)
			mesh_ids.append(mesh.get_instance_id())
		var expected_meshes: int = _expected_mesh_count(item)
		if members.is_empty() or members.size() != expected_meshes:
			return _reject(
				(
					"incomplete required visual group for "
					+ item
					+ ":"
					+ identity
					+ " actual="
					+ str(members.size())
					+ " expected="
					+ str(expected_meshes)
				)
			)
		_groups.append({"identity": identity, "item": item, "bounds": broad, "members": members})
		model_meshes[identity] = mesh_ids
		if item == "ST-021":
			_collect(visual)
	_obstacles.clear()
	if not ClubCareer.same(counts, StadiumMogulTwoStudy.COUNTS) or _groups.size() != 32:
		return _reject("incomplete91-copy/32-opaque-group visibility enrollment")
	ready = true
	return true


static func _expected_mesh_count(item: String) -> int:
	# Count the genuine occupied factory hierarchy, not whatever remains on the candidate.
	var reference: Node3D
	match item:
		"ST-021":
			reference = StadiumFoulPoleModels.create(3.25)
		"ST-074":
			reference = StadiumConcreteDugoutModels.create()
		"ST-029":
			reference = StadiumBaselineSightlineModels.lower()
		"ST-031":
			reference = StadiumGrandThreeStackModels._concourse()
		"ST-030":
			reference = StadiumGrandThreeStackModels._upper()
		"ST-053":
			reference = StadiumGrandThreeStackModels._roof()
		"ST-081":
			reference = StadiumCurvedLowerModels.create()
		"ST-085":
			reference = StadiumLowerTransitionModels.create_right()
		"ST-088":
			reference = StadiumLowerTransitionModels.create_left()
		"ST-039":
			reference = StadiumClubModels.create("ST-039")
		"ST-076":
			reference = StadiumPremiumLightTowerModels.create()
	if reference == null:
		return 0
	var count: int = (
		reference.get_node("Visual").find_children("*", "MeshInstance3D", true, false).size()
	)
	reference.free()
	return count


func _reset() -> void:
	ready = false
	last_error = ""
	_groups.clear()
	_rails.clear()
	_wall_bounds.clear()
	_obstacles.clear()
	_uprights.clear()
	model_meshes.clear()
	_recipe = null
	_wall_prisms = null


func _reject(reason: String) -> bool:
	_reset()
	last_error = reason
	return false


func defense_depth(x: float, desired: float, ball: Vector3 = Vector3.ZERO) -> float:
	if not ready:
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


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	return not ready or super._blocked(camera, ball)


func actual_blocked(camera: Vector3, ball: Vector3) -> bool:
	return not ready or super.actual_blocked(camera, ball)
