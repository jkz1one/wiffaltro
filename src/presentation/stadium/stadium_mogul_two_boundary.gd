class_name StadiumMogulTwoBoundary
extends StadiumClubBoundaryStudy
## Whole shaped-wall/dugout composition, isolated from original study and production builders.


func build(shape: String = "left_loft") -> bool:
	if get_child_count() != 0 or shape != "left_loft":
		return false
	graph = StadiumMogulTwoGraph.new()
	if graph == null:
		return false
	var rows: Array[Dictionary] = graph.segments()
	if rows.size() != graph.polygon().size():
		return false
	for index in range(rows.size()):
		if not rows[index].role.begins_with("DUGOUT"):
			_slab(rows[index], index)
	for left in [false, true]:
		var dugout: Node3D = StadiumConcreteDugoutModels.create()
		dugout.name = "DugoutLeft" if left else "DugoutRight"
		add_child(dugout)
		dugout.transform = StadiumDugoutRecipe.placement(left)
		dugout.set_meta("candidate_site", "DUGOUT-L" if left else "DUGOUT-R")
		items.append(dugout)
		for body: StaticBody3D in dugout.get_node("Collision").get_children():
			var prefix: String = "DUGOUT-L" if left else "DUGOUT-R"
			var role: String = body.get_meta("surface_role")
			var id: String = prefix + "-" + String(body.name)
			if role == "DUGOUT_FACE_LIVE":
				var inner: bool = String(body.name).ends_with("-1") == left
				id = prefix + ("-FACE-IN" if inner else "-FACE-OUT")
			elif String(body.name).begins_with("EndWall"):
				role = "DUGOUT_EXTERIOR_DEAD"
			_tag(body, id, role, 350 if role == "DUGOUT_FACE_LIVE" else 300, "dugout")
	for row: Dictionary in StadiumFoulPoleSites.rows(graph):
		var pole: Node3D = StadiumFoulPoleModels.create(row.split)
		pole.name = row.site
		add_child(pole)
		pole.position = row.position
		pole.set_meta("candidate_site", row.site)
		items.append(pole)
		var body: StaticBody3D = pole.get_node("Collision/Pole")
		_tag(body, row.site, "FOUL_POLE_CONTACT", 500, "pole")
		body.set_meta("wall_cap_height", row.split)
	_art(shape)
	_receivers()
	return true


func _art(_shape: String) -> void:
	var visual: Node3D = Node3D.new()
	visual.name = "PanelVisuals"
	add_child(visual)
	for row: Dictionary in StadiumHeightWallRecipes.rows("left_loft", "ST-065"):
		var panel: Node3D = StadiumHeightWallStudy.create("ST-065", row.width, row.height)
		panel.set_meta("stadium_item", "ST-065-T" if row.height == 4.875 else "ST-065")
		panel.set_meta("candidate_site", row.socket)
		panel.transform = StadiumWallRecipes.placement(row)
		visual.add_child(panel)
		items.append(panel)
	var sides: Array[Dictionary] = StadiumDugoutRecipe.panels(false)
	sides.append_array(StadiumDugoutRecipe.panels(true))
	for row: Dictionary in sides:
		var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.set_meta("stadium_item", row.item)
		panel.set_meta("candidate_site", row.socket)
		panel.transform = StadiumWallRecipes.placement(row)
		visual.add_child(panel)
		items.append(panel)
	# Rear boundary remains plain template infrastructure, not a purchased panel grant.
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "TemplateRearWall"
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(16, 1.2, 0.35)
	mesh.position = Vector3(0, 0.6, -6.175)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("897756")
	mesh.material_override = material
	add_child(mesh)
