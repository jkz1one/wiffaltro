class_name StadiumScoreboardAssembly
extends RefCounted
## Exact-profile geometry/accessors shared by complete14 and closed-gate mounted15.


static func profile(row: Dictionary) -> Dictionary:
	if row.has("mount_profile"):
		return StadiumScoreboardMountCatalog._placement(row, 1)
	if StadiumScoreboardModels.bounds(row) == AABB():
		return {}
	return {"item": row.item, "model": row.model, "site": row.site,
		"display_path": "Visual/ScoreDisplay", "mount_profile": ""}


static func base(layout: Dictionary) -> Dictionary:
	return StadiumScoreboardLayout.base(StadiumMountedScoreboardLayout.base(layout)) \
		if SeasonOwnership._whole(layout.get("version"), 15, 15) else (
			StadiumScoreboardLayout.base(layout))


static func pose(row: Dictionary) -> Transform3D:
	if profile(row).is_empty():
		return Transform3D.IDENTITY
	return StadiumScoreboardMountCatalog.pose(row.item, row.model, row.site, row.mount_profile, 1) \
		if row.has("mount_profile") else StadiumScoreboardSites.pose(row.site)


static func bounds(row: Dictionary) -> AABB:
	return StadiumScoreboardMountCatalog.bounds(row, 1) if row.has("mount_profile") else (
		StadiumScoreboardModels.bounds(row))


static func display(model: Variant, row: Dictionary) -> StadiumScoreboardTierDisplay:
	var spec: Dictionary = profile(row)
	if not model is Node3D or not is_instance_valid(model) or spec.is_empty():
		return null
	var value: Node = model.get_node_or_null(NodePath(spec.display_path))
	return value if value is StadiumScoreboardTierDisplay else null


static func create(row: Dictionary) -> Node3D:
	var spec: Dictionary = profile(row)
	if spec.is_empty():
		return null
	if not row.has("mount_profile"):
		return StadiumScoreboardModels.create(row.item, row.model)
	var cabinet: Node3D = StadiumScoreboardModels.create(row.item, row.model)
	cabinet.set_meta("scoreboard_mount_profile", row.mount_profile)
	cabinet.set_meta("scoreboard_mount_catalog", 1)
	cabinet.set_meta("stadium_item", row.item)
	cabinet.set_meta("scoreboard_owned_model", row.model)
	if spec.mount_profile.is_empty():
		return cabinet
	var root: Node3D = Node3D.new()
	root.name = spec.node_name
	root.set_meta("scoreboard_mount_profile", row.mount_profile)
	root.set_meta("scoreboard_mount_catalog", 1)
	root.set_meta("stadium_item", row.item)
	root.set_meta("scoreboard_owned_model", row.model)
	root.set_meta("scoreboard_model_version", StadiumScoreboardTiers.VERSION)
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	cabinet.name = "ElectronicV2Cabinet"
	cabinet.position.y = spec.lift
	for path: String in spec.remove_model_nodes:
		var old: Node = cabinet.get_node_or_null(NodePath(path))
		if old == null:
			cabinet.free()
			root.free()
			return null
		old.free()
	visual.add_child(cabinet)
	for part: Dictionary in spec.support:
		if part.kind == "box":
			StadiumScoreboardTiers._box(root, part.name, _vector(part.center),
				_vector(part.size), Color(part.color))
		else:
			StadiumScoreboardTiers._beam(root, part.name, _vector(part.from),
				_vector(part.to), part.width, Color(part.color))
	return root


static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


static func center_model(property: StadiumScoreboardPropertyGeometry) -> Node3D:
	if not is_instance_valid(property):
		return null
	var layout: Variant = property.get_meta("scoreboard_layout", {})
	if not layout is Dictionary or not StadiumMountedScoreboardLayout._grammar(layout):
		return null
	for row: Dictionary in layout.scoreboards:
		if row.mount_profile != StadiumScoreboardMountCatalog.CENTER_PROFILE:
			continue
		var model: Variant = property.board_objects.get(row.copy)
		if model is Node3D and is_instance_valid(model) and model.get_parent() == property \
			and property.objects.get(row.copy) is Node3D \
			and property.objects.get(row.copy) == model and model.transform == pose(row):
			return model
	return null


static func is_center_root(model: Node) -> bool:
	return is_instance_valid(model) and model.get_parent() is StadiumScoreboardPropertyGeometry \
		and center_model(model.get_parent()) == model
