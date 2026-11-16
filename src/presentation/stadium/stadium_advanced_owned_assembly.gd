class_name StadiumAdvancedOwnedAssembly
extends RefCounted
## Complete exact-copy authoring assembly, without production installation.

const VERSION: int = 1


static func build(boundary: StadiumRecipeBoundaryBody, manifest: Dictionary,
	walls: Dictionary, stock: StadiumStock, pieces: StadiumWallPieceStock) -> bool:
	if boundary == null or boundary.get_child_count() != 0:
		return false
	var checked: Dictionary = StadiumAdvancedWallManifest.validate(manifest, stock, pieces)
	var sides: Dictionary = StadiumWallLayout.validate(walls, stock)
	if not checked.ok or checked.panels.is_empty() or not sides.ok or not walls.back.is_empty():
		return false
	if manifest.shape != "offset_gables":
		if not boundary is StadiumHeightBoundaryBody or not StadiumHeightOwnedAssembly.build(
			boundary, manifest, walls, stock, pieces):
			return false
	else:
		if not boundary is StadiumOffsetBoundaryBody or not boundary.build(
			manifest.shape, manifest.material):
			return false
		var visual: Node3D = Node3D.new()
		visual.name = "PanelVisuals"
		for row: Dictionary in checked.panels + sides.panels:
			var panel: Node3D = StadiumOffsetWallModels.create(row.item, row.span) \
				if StadiumWallRecipes.BACK_IDS.has(row.item) else StadiumWallPanelModels.create(
					row.item, row.span)
			panel.get_node("PanelCollision").free()
			panel.transform = StadiumWallRecipes.placement(row)
			panel.set_meta("owned_copy", row.copy)
			panel.set_meta("piece_item", row.item)
			panel.set_meta("wall_socket", row.socket)
			visual.add_child(panel)
		boundary.get_node("PanelVisuals").free()
		boundary.add_child(visual)
		for row: Dictionary in boundary.graph.segments():
			var paid: bool = row.role == "BACK_WALL_TERMINAL" or (
				row.id in ["SIDE-L-01", "RETURN-L-01"] and not walls.left.is_empty()) or (
				row.id in ["SIDE-R-01", "RETURN-R-01"] and not walls.right.is_empty())
			boundary.get_node(row.id + "/TemplateWallVisual").visible = not paid
	for body: StaticBody3D in boundary.find_children("*", "StaticBody3D", true, false):
		body.collision_layer |= 16
	boundary.set_meta("advanced_manifest", manifest_key(manifest, walls))
	return true


static func manifest_key(manifest: Dictionary, walls: Dictionary) -> String:
	return JSON.stringify({"version": VERSION, "back": manifest, "sides": walls},
		"", true, true).sha256_text()
