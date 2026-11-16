class_name StadiumNpcAc02PublicBoundarySource
extends Node3D
## Detached exact A RightShelf geometry; no authoring installer or contact router.
const QUERY_MASK: int = 32
var graph: StadiumNpcAc02PublicGraph
var bodies: Array[StaticBody3D] = []
var items: Array[Node3D] = []


func build(shape: String = "right_shelf") -> bool:
	if not StadiumNpcAc02IssuedWritersV1.preissue_only(self, "boundary-source-rebuild"):
		return false
	if get_child_count() != 0 or shape != "right_shelf":
		return false
	graph = StadiumNpcAc02PublicGraph.new()
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
	for row: Dictionary in StadiumHeightWallRecipes.rows("right_shelf", "ST-065"):
		var panel: Node3D = StadiumHeightWallStudy.create("ST-065", row.width, row.height)
		panel.set_meta("stadium_item", "ST-065-L" if row.height == 1.625 else "ST-065")
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


func _slab(row: Dictionary, index: int) -> void:
	var next: int = (index + 1) % graph.polygon().size()
	var polygon: Array[Vector2] = [row.a, row.b, graph.outer_vertex(next), graph.outer_vertex(index)]
	var points: PackedVector3Array = []
	for height: float in [0.0, float(row.height)]:
		for point: Vector2 in polygon:
			points.append(Vector3(point.x, height, point.y))
	var body: StaticBody3D = StaticBody3D.new()
	body.name = row.id
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = ConvexPolygonShape3D.new()
	collider.shape.margin = 0
	collider.shape.points = points
	body.add_child(collider)
	add_child(body)
	_tag(body, row.id, row.role, row.priority, "boundary")


func _tag(body: StaticBody3D, id: String, role: String, priority: int, kind: String) -> void:
	body.collision_layer = 1 | QUERY_MASK
	body.collision_mask = 2
	body.set_meta("club_surface", id)
	body.set_meta("surface_role", role)
	body.set_meta("surface_priority", priority)
	body.set_meta("surface_kind", kind)
	bodies.append(body)


func _receivers() -> void:
	var target: Node3D = StadiumTargetModels.create()
	target.position = StadiumTargetModels.POSITION
	target.set_meta("candidate_site", "RECEIVER-PRIMARY")
	var net: Node3D = StadiumReceiverNetModels.create()
	net.set_meta("candidate_site", "RECEIVER-CATCH")
	for model: Node3D in [target, net]:
		add_child(model)
		items.append(model)
		for body: StaticBody3D in model.get_node("Collision").get_children():
			_tag(body, String(body.name), "RECEIVER_CONTAINMENT_FOUL", 450, "receiver")
