class_name StadiumExpandedBoundary
extends StadiumRecipeBoundaryBody
## Back-only AE-01 manifest; inherited joined slabs retain free sides and rear.


func build(recipe: String = "deeper_center", material_id: String = "ST-024") -> bool:
	if recipe != "deeper_center" or material_id != "ST-024":
		return false
	if not super.build(recipe, material_id):
		return false
	for row: Dictionary in graph.segments():
		get_node(row.id + "/TemplateWallVisual").visible = row.role != "BACK_WALL_TERMINAL"
	return true


func _panels(shape: String, item: String) -> void:
	var visual: Node3D = Node3D.new()
	visual.name = "PanelVisuals"
	add_child(visual)
	for row: Dictionary in StadiumWallRecipes.back(shape, item):
		var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.transform = StadiumWallRecipes.placement(row)
		panel.set_meta("stadium_item", row.item)
		panel.set_meta("candidate_site", row.socket)
		panel.set_meta("candidate_instance", "npc-candidate:AE-01:" + row.socket)
		visual.add_child(panel)
