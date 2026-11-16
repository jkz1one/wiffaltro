extends "res://src/tests/stadium_transition_concourse_geometry_test_support.gd"
## Candidate-local witness: frozen inherited helpers are not changed or weakened.

var _net_witness: Node3D
var _sparse_panels: Dictionary = {}


func _init_net_witness() -> bool:
	_net_witness = StadiumReceiverNetModels.create()
	if _net_witness == null:
		_check(false, "canonical actual receiver witness must construct")
		return false
	for id: String in StadiumReceiverNetModels.PANELS:
		var panel: MeshInstance3D = _net_witness.get_node("Visual/" + id)
		if not StadiumReceiverNetModels.flex(_net_witness, id, 0.275,
			panel.transform * Vector3(0, 3.375, 0)):
			_check(false, "canonical receiver witness must reach exact peak-flex state")
			return false
		_sparse_panels[id] = _sparse_strand_area(panel)
		_check(_sparse_panels[id], "canonical full strand triangles leave genuine visible holes")
	return not _sparse_panels.values().has(false)


func _exit_tree() -> void:
	if is_instance_valid(_net_witness):
		_net_witness.free()


func _verified_panel(hit: Dictionary, net: Node3D) -> bool:
	var body: StaticBody3D = hit.get("collider") as StaticBody3D
	if not is_instance_valid(_net_witness) or not is_instance_valid(net) \
		or body == null or hit.get("shape", -1) != 0:
		return false
	var id: String = str(body.get_meta("surface_id", ""))
	if id not in StadiumReceiverNetModels.PANELS or not _sparse_panels.get(id, false):
		return false
	if body != net.get_node_or_null("Collision/" + id) or body.get_child_count() != 1 \
		or not CS.meta_matches(body, "surface_role", "RECEIVER_CONTAINMENT_FOUL") \
		or not net.global_transform.is_equal_approx(Transform3D.IDENTITY) \
		or not body.can_process() or not net.is_visible_in_tree():
		return false
	var reference: StaticBody3D = _net_witness.get_node("Collision/" + id)
	var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
	var ref_shape: CollisionShape3D = reference.get_child(0)
	if shape == null or not shape.shape is BoxShape3D:
		return false
	if body.transform != reference.transform or body.global_transform != reference.transform \
		or body.top_level or shape.transform != ref_shape.transform or shape.top_level \
		or shape.shape.size != ref_shape.shape.size or shape.disabled or shape.shape.margin != 0 \
		or body.collision_layer != reference.collision_layer \
		or body.collision_mask != reference.collision_mask \
		or body.disable_mode != reference.disable_mode \
		or body.process_mode != reference.process_mode \
		or shape.process_mode != ref_shape.process_mode \
		or body.get_script() != null or shape.get_script() != null:
		return false
	var actual: MeshInstance3D = net.get_node_or_null("Visual/" + id) as MeshInstance3D
	return actual != null and _strand_visual(actual, _net_witness.get_node("Visual/" + id))


func _strand_visual(actual: MeshInstance3D, reference: MeshInstance3D) -> bool:
	# Full equality to the independently checked sparse grid binds actual topology
	# and peak-flex vertices. Width/rest metadata alone never proves visible holes.
	if not actual.mesh is ArrayMesh or actual.mesh.get_surface_count() != 1 \
		or actual.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES \
		or not actual.is_visible_in_tree() or not actual.can_process() \
		or actual.transform != reference.transform or actual.global_transform != reference.transform \
		or actual.top_level or actual.get_child_count() != 0 or actual.get_script() != null \
		or actual.mesh.get_script() != null or actual.process_mode != reference.process_mode \
		or not CS._render_state(actual, reference):
		return false
	for key: String in ["rest_vertices", "panel_width"]:
		if not CS.meta_matches(actual, key, reference.get_meta(key)):
			return false
	return actual.mesh.surface_get_arrays(0) == reference.mesh.surface_get_arrays(0)


func _sparse_strand_area(panel: MeshInstance3D) -> bool:
	var arrays: Array = panel.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if points.size() % 3 != 0:
		return false
	var area: float = 0
	for index in range(0, points.size(), 3):
		if not points[index].is_finite() or not points[index + 1].is_finite() \
			or not points[index + 2].is_finite():
			return false
		var a: Vector2 = Vector2(points[index].x, points[index].y)
		var b: Vector2 = Vector2(points[index + 1].x, points[index + 1].y)
		var c: Vector2 = Vector2(points[index + 2].x, points[index + 2].y)
		area += absf((b - a).cross(c - a)) * 0.5
	var extent: AABB = panel.mesh.get_aabb()
	return area < extent.size.x * extent.size.y * 0.15


func _net_visual_controls(net: Node3D) -> bool:
	var failures_before: int = _failures
	var panel: MeshInstance3D = net.get_node("Visual/ST073_CENTER_NET")
	var body: StaticBody3D = net.get_node("Collision/ST073_CENTER_NET")
	var from: Vector3 = Vector3(0, 3, -6)
	var to: Vector3 = Vector3(0, 3, 0)
	var before: Array[RID] = _opaque_path(from, to, net)
	_check(before.is_empty(), "genuine full strand grid is the only transparent panel witness")
	var original: Mesh = panel.mesh
	_check(original is ArrayMesh, "actual net strand control requires original ArrayMesh")
	if not before.is_empty() or not original is ArrayMesh:
		return false
	panel.visible = false
	_check(body.get_rid() in _opaque_path(from, to, net), "hidden visual is not a transparent witness")
	panel.visible = true
	panel.transparency = 0.5
	_check(body.get_rid() in _opaque_path(from, to, net), "changed instance alpha rejects witness")
	panel.transparency = 0
	var filled: QuadMesh = QuadMesh.new()
	filled.size = Vector2(4, 6.25)
	panel.mesh = filled
	_check(body.get_rid() in _opaque_path(from, to, net),
		"opaque filled replacement rejects despite authentic body and retained metadata")
	var strip: ArrayMesh = _rebuild_array_mesh(original as ArrayMesh, true)
	if strip == null:
		panel.mesh = original
		return false
	panel.mesh = strip
	_check(body.get_rid() in _opaque_path(from, to, net),
		"same strand arrays with hole-bridging triangle-strip topology reject")
	panel.mesh = original
	var material: StandardMaterial3D = panel.material_override
	material.next_pass = StandardMaterial3D.new()
	_check(body.get_rid() in _opaque_path(from, to, net), "changed material pass rejects witness")
	material.next_pass = null
	panel.material_overlay = StandardMaterial3D.new()
	_check(body.get_rid() in _opaque_path(from, to, net), "additional opaque overlay rejects witness")
	panel.material_overlay = null
	_check(_opaque_path(from, to, net) == before and _sightline_clear(from, to, net),
		"full authentic sparse-grid and opaque traversal restore after all mutations")
	return _failures == failures_before
