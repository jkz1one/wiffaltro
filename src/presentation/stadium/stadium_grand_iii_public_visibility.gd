class_name StadiumGrandIIIPublicVisibility
extends StadiumGrandIPublicVisibility
## All 50 opaque groups retain member-local geometry, including 21 direct waterfall meshes.
## The shared I helper supplies cup/open-dugout clearance, not a broad-AABB substitute.


func _venue_id() -> String:
	return "GRAND-III"


func _mesh_counts() -> Dictionary:
	# Exact occupied historical factories; premium towers have 90 meshes each.
	return {"ST-021": 2, "ST-074": 12, "ST-029": 420, "ST-031": 15,
		"ST-030": 117, "ST-053": 9, "ST-081": 207, "ST-083": 15,
		"ST-082": 126, "ST-084": 9, "ST-085": 117, "ST-088": 117,
		"ST-086": 62, "ST-089": 62, "ST-040": 33, "ST-076": 90, "ST-046": 21}


func _copy_counts() -> Dictionary:
	return StadiumGrandIIIPublicConstruction.COUNTS


func _group_count() -> int:
	return 50


func _configure_grand_i() -> bool:
	# Reuse retained Club member-level occlusion with local poses, including detached audits.
	for row: Dictionary in _recipe.segments():
		if row.role.begins_with("DUGOUT"):
			_rails.append({"a": row.a, "normal": _recipe.inward(row)})
	var counts: Dictionary = {}
	var mesh_counts: Dictionary = _mesh_counts()
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		if not identity.begins_with(StadiumGrandIIIPublicConstruction.INSTANCE_PREFIX) \
			or not is_instance_valid(model) or model.get_meta("npc_instance", "") != identity:
			return false
		var item: String = model.get_meta("stadium_item", "")
		counts[item] = int(counts.get(item, 0)) + 1
		if item in RECEIVER_WALL_ITEMS:
			continue
		# ST046 intentionally has 21 direct opaque meshes and no Visual container.
		var visual: Node3D = model if item == "ST-046" else (
			model.get_node_or_null("Visual") as Node3D)
		if item == "ST-046" and not _waterfall_valid(model):
			return false
		if not mesh_counts.has(item) or visual == null or not visual.visible:
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
		if members.size() != mesh_counts[item]:
			return false
		_groups.append({"identity": identity, "item": item, "bounds": broad, "members": members})
	return counts == _copy_counts() and _groups.size() == _group_count()


func _waterfall_valid(root: Node3D) -> bool:
	if root == null or root.get_class() != "Node3D" or not StadiumWaterfallModels._clean(root) \
		or root.get_child_count() != StadiumWaterfallModels.PARTS.size() \
		or not StadiumWaterfallModels._meta(root, "stadium_item", TYPE_STRING, "ST-046") \
		or not StadiumWaterfallModels._meta(root, "immutable_geometry_only", TYPE_BOOL, true) \
		or not StadiumWaterfallModels._meta(root, "geometry_version", TYPE_INT, 1) \
		or not StadiumWaterfallModels._meta(root, "obstacle_units", TYPE_INT, 0) \
		or not StadiumWaterfallModels._meta(root, "night_qualified", TYPE_BOOL, false):
		return false
	for id: String in StadiumWaterfallModels.PARTS:
		var part: MeshInstance3D = root.get_node_or_null(id) as MeshInstance3D
		if part == null or not StadiumWaterfallModels._clean(part) or part.get_child_count() != 0 \
			or part.transform != Transform3D(Basis.IDENTITY, StadiumWaterfallModels.PARTS[id][0]) \
			or not part.mesh is BoxMesh or part.mesh.size != StadiumWaterfallModels.PARTS[id][1] \
			or part.mesh.get_script() != null or part.mesh.flip_faces or part.mesh.subdivide_width != 0 \
			or part.mesh.subdivide_height != 0 or part.mesh.subdivide_depth != 0 \
			or part.material_overlay != null or part.get_surface_override_material(0) != null \
			or part.mesh.material != null or part.layers != 1 or part.transparency != 0.0:
			return false
		if not StadiumWaterfallModels._material(part.material_override,
			Color(StadiumWaterfallModels.PARTS[id][2])) \
			or not StadiumWaterfallModels._render_state(part):
			return false
	return true

