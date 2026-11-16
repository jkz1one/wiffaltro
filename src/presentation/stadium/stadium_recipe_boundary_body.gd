class_name StadiumRecipeBoundaryBody
extends Node3D
## Isolated recipe-aware joined collision with exact authored panels. No season activation.

var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create("straight")

var contacts: Array[Dictionary] = []
var _touching: Dictionary = {}


func build(recipe: String = "straight", material_id: String = "ST-024") -> bool:
	if get_child_count() != 0 or not StadiumWallRecipes.SHAPES.has(recipe) \
		or not StadiumWallRecipes.BACK_IDS.has(material_id):
		return false
	graph = StadiumRecipeBoundary.create(recipe)
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


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	var callback: Callable = _contact_batch.bind(resolver)
	if ball.physics_contact_router == callback:
		return
	ball.physics_contact_router = callback
	ball.tree_exited.connect(_forget.bind(ball.get_instance_id()), CONNECT_ONE_SHOT)


func _forget(id: int) -> void:
	_touching.erase(id)


func _contact_batch(ball: BattedBallBody, batch: Array[Dictionary],
	resolver: BallPlayResolver) -> void:
	var id: int = ball.get_instance_id()
	var previous: Array = _touching.get(id, [])
	var current: Array = []
	var candidates: Array[Dictionary] = []
	for contact: Dictionary in batch:
		var body: Node = contact.body
		if body.get_meta("ball_surface", "") == "ground" \
			and get_parent().is_ancestor_of(body) and not resolver.state.has_grounded:
			# All manifold contacts belong to this physics step. Record actual ground
			# history before a terminal wall uses its airborne/grounded classification.
			ball.surface_contact.emit(&"ground", contact.position)
			resolver.record_ground_contact(contact.position)
		if not is_ancestor_of(body) or not body.has_meta("boundary_segment"):
			continue
		var segment: String = body.get_meta("boundary_segment")
		var row: Dictionary = graph.segment(segment)
		if row.is_empty():
			continue
		current.append(segment)
		if not previous.has(segment):
			candidates.append({"segment": segment, "role": row.role,
				"position": contact.position, "priority": row.priority})
	_touching[id] = current
	if candidates.is_empty():
		return
	# A shared-corner manifold is one event, independent of body-entered callback order.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.priority > b.priority if a.priority != b.priority else a.segment < b.segment)
	var event: Dictionary = candidates[0]
	if graph.apply(resolver, event):
		event["frame"] = Engine.get_physics_frames()
		contacts.append(event)


func visibility_bounds() -> Array[AABB]:
	var bounds: Array[AABB] = []
	var rows: Array[Dictionary] = graph.segments()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var pieces: int = ceili(row.a.distance_to(row.b) / 0.75)
		var outer_a: Vector2 = graph.outer_vertex(index)
		var outer_b: Vector2 = graph.outer_vertex((index + 1) % rows.size())
		for piece in range(pieces):
			var low: float = float(piece) / pieces
			var high: float = float(piece + 1) / pieces
			var a: Vector2 = row.a.lerp(row.b, low)
			var box: AABB = AABB(Vector3(a.x, 0, a.y), Vector3(0, row.height, 0))
			for point: Vector2 in [row.a.lerp(row.b, high), outer_a.lerp(outer_b, low),
				outer_a.lerp(outer_b, high)]:
				box = box.expand(Vector3(point.x, 0, point.y))
			bounds.append(box)
	return bounds


func _panels(shape: String, item: String) -> void:
	var visual: Node3D = Node3D.new()
	visual.name = "PanelVisuals"
	add_child(visual)
	var rows: Array[Dictionary] = StadiumWallRecipes.back(shape, item)
	rows.append_array(StadiumWallRecipes.side(false))
	rows.append_array(StadiumWallRecipes.side(true))
	for row: Dictionary in rows:
		var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.transform = StadiumWallRecipes.placement(row)
		visual.add_child(panel)


func build_owned(walls: Dictionary, stock: StadiumStock) -> bool:
	var checked: Dictionary = StadiumWallLayout.validate(walls, stock)
	if not checked.ok or not checked.has_paid:
		return false
	var material_id: String = "ST-024" if walls.back.is_empty() else String(walls.back.item)
	if not build(checked.shape, material_id):
		return false
	get_node("PanelVisuals").free()
	var visual: Node3D = Node3D.new()
	visual.name = "PanelVisuals"
	add_child(visual)
	for row: Dictionary in checked.panels:
		var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.transform = StadiumWallRecipes.placement(row)
		panel.set_meta("owned_copy", row.copy)
		panel.set_meta("wall_socket", row.socket)
		visual.add_child(panel)
	for row: Dictionary in graph.segments():
		var paid: bool = not walls.back.is_empty() if row.role == "BACK_WALL_TERMINAL" else (
			not walls.right.is_empty() if row.id in ["SIDE-R-01", "RETURN-R-01"] else (
				not walls.left.is_empty() if row.id in ["SIDE-L-01", "RETURN-L-01"] else false))
		get_node(row.id + "/TemplateWallVisual").visible = not paid
	set_meta("wall_manifest", JSON.stringify(walls, "", true, true).sha256_text())
	return true
