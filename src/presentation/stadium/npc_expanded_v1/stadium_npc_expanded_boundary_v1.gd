class_name StadiumNpcExpandedBoundaryV1
extends StadiumNpcExpandedBoundaryBodyV1
## Retained AE-01/r1 correspondence copy.
## Original: src/presentation/stadium/stadium_expanded_boundary.gd
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
	for row: Dictionary in StadiumNpcExpandedWallRecipesV1.back(shape, item):
		var panel: Node3D = StadiumNpcExpandedWallPanelV1.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.transform = StadiumNpcExpandedWallRecipesV1.placement(row)
		panel.set_meta("stadium_item", row.item)
		panel.set_meta("npc_site", row.socket)
		panel.set_meta("npc_instance", "npc:AE-01:r1:" + row.socket)
		visual.add_child(panel)
