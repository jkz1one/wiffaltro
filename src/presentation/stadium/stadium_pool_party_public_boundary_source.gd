class_name StadiumPoolPartyPublicBoundarySource
extends Node3D
## Exact DB/CH/CI source construction. No private owned-property or paid-copy authority.

const QUERY_MASK: int = 32
var graph: StadiumTimberDugoutBoundary
var bodies: Array[StaticBody3D] = []
var items: Array[Node3D] = []


func build(shape: String = "straight") -> bool:
	if get_child_count() != 0 or shape != "straight":
		return false
	graph = StadiumTimberDugoutBoundary.candidate(shape)
	if graph == null:
		return false
	var rows: Array[Dictionary] = graph.segments()
	if rows.size() != graph.polygon().size():
		return false
	for index in range(rows.size()):
		if not rows[index].role.begins_with("DUGOUT"):
			_slab(rows[index], index)
	for left: bool in [false, true]:
		var dugout: Node3D = StadiumTimberDugoutModels.create()
		dugout.transform = StadiumTimberDugoutContract.placement(left)
		# Prove the untouched shared asset before attaching any public-instance provenance.
		if not StadiumTimberDugoutContract.valid_binding(
			dugout, left, StadiumTimberDugoutContract.interface(left)):
			dugout.free()
			return false
		dugout.name = "DugoutLeft" if left else "DugoutRight"
		dugout.remove_meta("stadium_candidate_only")
		dugout.set_meta("runtime_adapter", "ST032_SPHERE_SWEEP_v1")
		dugout.set_meta("candidate_site", "DUGOUT-L" if left else "DUGOUT-R")
		add_child(dugout)
		items.append(dugout)
		for body: StaticBody3D in dugout.get_node("Collision").get_children():
			var prefix: String = "DUGOUT-L" if left else "DUGOUT-R"
			var role: String = body.get_meta("surface_role")
			var id: String = prefix + "-" + String(body.name)
			if role == "DUGOUT_FACE_LIVE":
				var inner: bool = String(body.name).ends_with("-1") == left
				id = prefix + ("-FACE-IN" if inner else "-FACE-OUT")
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
	_art()
	_receivers()
	return items.size() == 61


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
	# Outside furniture keeps ordinary solid art but cannot enter the preterminal sweep.
	body.collision_layer = 1 if role == "DECORATIVE_AFTER_TERMINAL" else 1 | QUERY_MASK
	body.collision_mask = 2
	body.set_meta("club_surface", id)
	body.set_meta("surface_role", role)
	body.set_meta("surface_priority", priority)
	body.set_meta("surface_kind", kind)
	if role != "DECORATIVE_AFTER_TERMINAL":
		bodies.append(body)


func _art() -> void:
	var rows: Array[Dictionary] = StadiumWallRecipes.back("straight", "ST-024")
	rows.append_array(StadiumTimberDugoutContract.panels(false))
	rows.append_array(StadiumTimberDugoutContract.panels(true))
	var visual: Node3D = Node3D.new()
	visual.name = "PanelVisuals"
	add_child(visual)
	for row: Dictionary in rows:
		var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.set_meta("stadium_item", row.item)
		panel.set_meta("candidate_site", row.socket)
		panel.transform = StadiumWallRecipes.placement(row)
		visual.add_child(panel)
		items.append(panel)
	# Free rear template infrastructure is not an additional paid physical copy.
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "TemplateRearWall"
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(16, 1.2, 0.35)
	mesh.position = Vector3(0, 0.6, -6.175)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("897756")
	mesh.material_override = material
	add_child(mesh)


func _receivers() -> void:
	var target: Node3D = StadiumTargetModels.create()
	target.position = StadiumTargetModels.POSITION
	target.set_meta("candidate_site", "RECEIVER-PRIMARY")
	var net: Node3D = StadiumNetModels.create()
	net.position = StadiumNetModels.POSITION
	net.set_meta("candidate_site", "RECEIVER-CATCH")
	for model: Node3D in [target, net]:
		add_child(model)
		items.append(model)
		for body: StaticBody3D in model.get_node("Collision").get_children():
			_tag(body, String(body.name), "RECEIVER_CONTAINMENT_FOUL", 450, "receiver")
