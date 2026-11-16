class_name StadiumOffsetBoundaryBody
extends StadiumRecipeBoundaryBody
## Isolated candidate assembly; original saved-recipe builders remain untouched.


func build(recipe: String = "offset_gables", material_id: String = "ST-024") -> bool:
	if get_child_count() != 0 or recipe != "offset_gables" \
		or not StadiumWallRecipes.BACK_IDS.has(material_id):
		return false
	graph = StadiumOffsetBoundary.new()
	var rows: Array[Dictionary] = graph.segments()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var next: int = (index + 1) % rows.size()
		var polygon: Array[Vector2] = [row.a, row.b,
			graph.outer_vertex(next), graph.outer_vertex(index)]
		var points: PackedVector3Array = []
		for height: float in [0.0, float(row.height)]:
			for corner: Vector2 in polygon:
				points.append(Vector3(corner.x, height, corner.y))
		var body: StaticBody3D = StaticBody3D.new()
		body.name = row.id
		body.collision_layer = 1
		body.collision_mask = 2
		body.set_meta("boundary_segment", row.id)
		body.set_meta("ball_surface", &"stadium_boundary")
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = ConvexPolygonShape3D.new()
		shape.shape.points = points
		body.add_child(shape)
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face: Array in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1],
			[1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
			for vertex: int in [face[0], face[1], face[2], face[0], face[2], face[3]]:
				surface.add_vertex(points[vertex])
		surface.generate_normals()
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = "TemplateWallVisual"
		mesh.mesh = surface.commit()
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color("547079") if row.role == "BACK_WALL_TERMINAL" \
			else Color("897756")
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.9
		mesh.material_override = material
		mesh.visible = row.role == "REAR_PERIMETER_DEAD"
		body.add_child(mesh)
		add_child(body)
	_panels(recipe, material_id)
	return true


func _panels(_recipe: String, item: String) -> void:
	var visual: Node3D = Node3D.new()
	visual.name = "PanelVisuals"
	add_child(visual)
	for row: Dictionary in StadiumOffsetWallRecipes.back(item):
		var panel: Node3D = StadiumOffsetWallModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.transform = StadiumWallRecipes.placement(row)
		visual.add_child(panel)
	var sides: Array[Dictionary] = StadiumWallRecipes.side(false)
	sides.append_array(StadiumWallRecipes.side(true))
	for row: Dictionary in sides:
		var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.transform = StadiumWallRecipes.placement(row)
		visual.add_child(panel)
