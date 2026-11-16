class_name StadiumGrandIIIFieldVisibility
extends StadiumClubFieldVisibility
# gdlint: disable=max-returns
## GrandIII-only hierarchy adapter. Inherited opaque grouping and camera margins stay unchanged.

const VISUAL_ITEMS: Array[String] = [
	"ST-021",
	"ST-074",
	"ST-029",
	"ST-031",
	"ST-030",
	"ST-053",
	"ST-081",
	"ST-083",
	"ST-082",
	"ST-084",
	"ST-085",
	"ST-088",
	"ST-086",
	"ST-089",
	"ST-040",
	"ST-076"
]
const RECEIVER_WALL_ITEMS: Array[String] = ["ST-026", "ST-073", "ST-065", "ST-022", "ST-023"]
const MESH_COUNTS: Dictionary = {
	"ST-031": 15,
	"ST-030": 117,
	"ST-053": 9,
	"ST-083": 15,
	"ST-082": 126,
	"ST-084": 9,
	"ST-086": 62,
	"ST-089": 62,
	"ST-040": 33,
	"ST-076": 90,
	"ST-046": 21
}
var ready: bool = false
var last_error: String = ""
var model_meshes: Dictionary = {}


func configure(geometry: Node) -> void:
	var property: StadiumGrandIIIProperty = (
		geometry.get_node_or_null("HomeProperty") as StadiumGrandIIIProperty
		if geometry != null
		else null
	)
	configure_candidate(property)


func configure_candidate(property: StadiumGrandIIIProperty) -> bool:
	_reset()
	if (
		property == null
		or not is_instance_valid(property.boundary)
		or property.boundary.graph == null
	):
		return _reject("missing complete GrandIII property/boundary")
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
		if item == "ST-046":
			# The qualified waterfall deliberately has21 direct opaque MeshInstance children.
			# Do not wrap it, change its materials, or omit it from camera/triangle evidence.
			if not StadiumWaterfallModels.valid(model):
				return _reject("invalid direct-mesh ST046 hierarchy at " + str(model.get_path()))
			visual = model
		elif item in VISUAL_ITEMS:
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
		if members.is_empty() or (MESH_COUNTS.has(item) and members.size() != MESH_COUNTS[item]):
			return _reject(
				(
					"incomplete required visual group for "
					+ item
					+ ":"
					+ identity
					+ " actual="
					+ str(members.size())
					+ " expected="
					+ str(MESH_COUNTS.get(item, "nonempty"))
				)
			)
		_groups.append({"identity": identity, "item": item, "bounds": broad, "members": members})
		model_meshes[identity] = mesh_ids
		if item == "ST-021":
			_collect(visual)
	_obstacles.clear()
	if not ClubCareer.same(counts, StadiumGrandIIIVenueStudy.COUNTS) or _groups.size() != 50:
		return _reject("incomplete107-copy/50-opaque-group visibility enrollment")
	ready = true
	return true


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


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	return not ready or super._blocked(camera, ball)


func actual_blocked(camera: Vector3, ball: Vector3) -> bool:
	return not ready or super.actual_blocked(camera, ball)
