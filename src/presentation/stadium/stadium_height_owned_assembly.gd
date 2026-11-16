class_name StadiumHeightOwnedAssembly
extends RefCounted
## Isolated owned-manifest assembly. No journal, shop, saved-layout or fixture activation.


static func build(boundary: StadiumHeightBoundaryBody, manifest: Dictionary,
	walls: Dictionary, stock: StadiumStock, pieces: StadiumWallPieceStock) -> bool:
	if boundary == null or boundary.get_child_count() != 0:
		return false
	var checked: Dictionary = StadiumHeightWallManifest.validate(manifest, stock, pieces)
	var sides: Dictionary = StadiumWallLayout.validate(walls, stock)
	if not checked.ok or checked.panels.is_empty() or not sides.ok or not walls.back.is_empty():
		return false
	var visual: Node3D = Node3D.new()
	visual.name = "PanelVisuals"
	for row: Dictionary in checked.panels:
		var panel: Node3D = StadiumHeightWallStudy.create(row.item, row.width, row.height)
		panel.transform = StadiumWallRecipes.placement(row)
		panel.set_meta("owned_copy", row.copy)
		panel.set_meta("piece_item", row.piece_item)
		panel.set_meta("wall_socket", row.socket)
		visual.add_child(panel)
	for row: Dictionary in sides.panels:
		var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.transform = StadiumWallRecipes.placement(row)
		panel.set_meta("owned_copy", row.copy)
		panel.set_meta("piece_item", row.item)
		panel.set_meta("wall_socket", row.socket)
		visual.add_child(panel)
	if not boundary.build(manifest.shape, manifest.material):
		visual.free()
		return false
	boundary.get_node("PanelVisuals").free()
	boundary.add_child(visual)
	for row: Dictionary in boundary.graph.segments():
		var paid: bool = row.role == "BACK_WALL_TERMINAL" or (
			row.id in ["SIDE-L-01", "RETURN-L-01"] and not walls.left.is_empty()) or (
			row.id in ["SIDE-R-01", "RETURN-R-01"] and not walls.right.is_empty())
		boundary.get_node(row.id + "/TemplateWallVisual").visible = not paid
	boundary.set_meta("height_manifest", JSON.stringify(manifest, "", true, true).sha256_text())
	return true
