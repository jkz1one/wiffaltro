class_name StadiumAdvancedPropertyGeometry
extends StadiumPropertyGeometry
## Complete owned advanced authoring property. Production dispatch stays gated separately.

var boundary: Node3D


func build_owned(property_tier: String, layout: Dictionary, stock: StadiumStock,
	ownership: StadiumWallPieceOwnership, surface_access: Array[String]) -> bool:
	var checked: Dictionary = StadiumAdvancedWallLayout.validate(layout, stock, ownership,
		property_tier, surface_access)
	if get_child_count() != 0 or not checked.ok:
		return false
	var advanced: bool = not checked.advanced_panels.is_empty()
	if advanced:
		boundary = StadiumOffsetBoundaryBody.new() if layout.advanced_back.shape == "offset_gables" \
			else StadiumHeightBoundaryBody.new()
		if not StadiumAdvancedOwnedAssembly.build(boundary, layout.advanced_back,
			layout.walls, stock, ownership.stock):
			boundary.free()
			boundary = null
			return false
	if not build(property_tier, StadiumAdvancedWallLayout.base(layout), stock):
		return _rollback()
	if advanced:
		get_node("TemplateBackWall").free()
		boundary.name = "BoundaryGraph"
		add_child(boundary)
		StadiumWallRenderQuality.attach(boundary)
		if not _surface(boundary.graph, layout, stock):
			return _rollback()
	else:
		boundary = StadiumBoundaryRuntime.assemble(self)
		if boundary == null:
			return _rollback()
	set_meta("advanced_layout", layout.duplicate(true))
	set_meta("advanced_stock", stock.to_data())
	set_meta("advanced_pieces", ownership.to_data())
	set_meta("advanced_surface_access", surface_access.duplicate())
	set_meta("property_signature", StadiumAdvancedWallLayout.geometry(property_tier))
	return true


func _surface(graph: StadiumRecipeBoundary, layout: Dictionary, stock: StadiumStock) -> bool:
	for id: String in ["OwnedSurfaceFinish", "FieldStylePreview",
		"GroundTreatment", "InfieldTreatment"]:
		var previous: Node = get_node_or_null(NodePath(id))
		if previous != null:
			previous.free()
	if not StadiumRecipeFieldStyles.apply(self, graph, {"line": layout.styles.line, "grass": ""},
		"", stock):
		return false
	var foundation: String = "grass" if layout.surface.foundation == "grass" else (
		"maintained_dirt" if layout.surface.condition == "prepared" else "rough_dirt")
	var finish: Node3D = StadiumSurfaceFinish.build(graph, foundation, layout.surface.height,
		layout.styles.grass, layout.ground)
	if finish == null:
		return false
	finish.name = "OwnedSurfaceFinish"
	finish.set_meta("boundary_signature", graph.signature())
	add_child(finish)
	return true


func _rollback() -> bool:
	if is_instance_valid(boundary) and boundary.get_parent() != self:
		boundary.free()
	for child: Node in get_children():
		child.free()
	boundary = null
	objects.clear()
	field = null
	tier = ""
	for key: StringName in [&"property_signature", &"wall_selection", &"wall_stock"]:
		remove_meta(key)
	return false


func observe(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> void:
	if boundary is StadiumHeightBoundaryBody:
		StadiumHeightSweep.observe(boundary, resolver, previous, current)
	elif boundary is StadiumRecipeBoundaryBody:
		boundary.graph.observe(resolver, previous, current)
	else:
		StadiumBoundaryObserver.observe(resolver, previous, current)


func rebind_displays(state: MatchState) -> void:
	for model: Node3D in objects.values():
		if model.get_meta("stadium_item", "") == "ST-039":
			var display: StadiumScoreboardDisplay = model.get_node("Visual/ScoreDisplay")
			if display._match != state:
				display.bind_match(state)
