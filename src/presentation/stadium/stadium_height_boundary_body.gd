class_name StadiumHeightBoundaryBody
extends StadiumRecipeBoundaryBody
## Isolated candidate assembly; original saved-recipe builders remain untouched.

var _motion_previous: Dictionary = {}


func build(recipe: String = "left_loft", material_id: String = "ST-024") -> bool:
	if get_child_count() != 0 or not StadiumHeightWallRecipes.SHAPES.has(recipe) \
		or not StadiumWallRecipes.BACK_IDS.has(material_id):
		return false
	graph = StadiumHeightBoundary.candidate(recipe)
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
		body.collision_layer = 1 | 16
		body.collision_mask = 2
		body.set_meta("boundary_segment", row.id)
		body.set_meta("ball_surface", &"stadium_boundary")
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = ConvexPolygonShape3D.new()
		shape.shape.margin = 0.0
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


func _panels(recipe: String, item: String) -> void:
	var visual: Node3D = Node3D.new()
	visual.name = "PanelVisuals"
	add_child(visual)
	for row: Dictionary in StadiumHeightWallRecipes.rows(recipe, item):
		var panel: Node3D = StadiumHeightWallStudy.create(row.item, row.width, row.height)
		panel.transform = StadiumWallRecipes.placement(row)
		visual.add_child(panel)
	var sides: Array[Dictionary] = StadiumWallRecipes.side(false)
	sides.append_array(StadiumWallRecipes.side(true))
	for row: Dictionary in sides:
		var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.transform = StadiumWallRecipes.placement(row)
		visual.add_child(panel)


func _contact_batch(ball: BattedBallBody, batch: Array[Dictionary],
	resolver: BallPlayResolver) -> void:
	if resolver == null or resolver.state == null or resolver.state.dead:
		return
	var id: int = ball.get_instance_id()
	var current: Vector3 = ball.global_position
	var previous: Vector3 = _motion_previous.get(id, current)
	_motion_previous[id] = current
	for contact: Dictionary in batch:
		var body: Node = contact.body
		if body.get_meta("ball_surface", "") == "ground" \
			and get_parent().is_ancestor_of(body) and not resolver.state.has_grounded:
			ball.surface_contact.emit(&"ground", contact.position)
			resolver.record_ground_contact(contact.position)
	var first: Dictionary = StadiumHeightSweep.event(self, previous, current, ball.radius_m)
	if first.get("role", "") in ["BACK_CLEAR", "BACK_WALL_TERMINAL", "REAR_PERIMETER_DEAD"]:
		if graph.apply(resolver, first):
			if first.get("swept_contact", false):
				first["frame"] = Engine.get_physics_frames()
				contacts.append(first)
		return
	super._contact_batch(ball, batch, resolver)


func _forget(id: int) -> void:
	_motion_previous.erase(id)
	super._forget(id)


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	super.bind_ball(ball, resolver)
	var callback: Callable = _seed_motion.bind(ball.get_instance_id())
	if not ball.launch_started.is_connected(callback):
		ball.launch_started.connect(callback)
		_seed_motion(ball.global_position, ball.get_instance_id())


func _seed_motion(position_value: Vector3, id: int) -> void:
	_motion_previous[id] = position_value
