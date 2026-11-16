class_name StadiumClubBoundaryStudy
extends Node3D
## Complete candidate side replacement. No journal, saved fixture or production factory activation.

signal contact_applied(event: Dictionary, resolver: BallPlayResolver)

const QUERY_MASK: int = 32
var graph: StadiumDugoutBoundary
var bodies: Array[StaticBody3D] = []
var items: Array[Node3D] = []
var last_live: Dictionary = {}
var _previous: Dictionary = {}
var _resolver_ids: Dictionary = {}


func build(shape: String = "straight") -> bool:
	if get_child_count() != 0:
		return false
	graph = StadiumDugoutBoundary.candidate(shape)
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


func _art(shape: String) -> void:
	var rows: Array[Dictionary] = StadiumWallRecipes.back(shape, "ST-065")
	rows.append_array(StadiumDugoutRecipe.panels(false))
	rows.append_array(StadiumDugoutRecipe.panels(true))
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


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	var callback: Callable = _contact_batch.bind(resolver)
	if ball.physics_contact_router == callback:
		return
	ball.physics_contact_router = callback
	var id: int = ball.get_instance_id()
	last_live.erase(_resolver_ids.get(id, -1))
	_resolver_ids[id] = resolver.get_instance_id()
	var launch: Callable = _seed.bind(id)
	if not ball.launch_started.is_connected(launch):
		ball.launch_started.connect(launch)
	_seed(ball.global_position, id)
	ball.tree_exited.connect(_forget.bind(id, resolver.get_instance_id()), CONNECT_ONE_SHOT)


func _seed(point: Vector3, id: int) -> void:
	_previous[id] = point
	last_live.erase(_resolver_ids.get(id, -1))


func _forget(id: int, resolver_id: int) -> void:
	_previous.erase(id)
	_resolver_ids.erase(id)
	last_live.erase(resolver_id)


func _contact_batch(ball: BattedBallBody, batch: Array[Dictionary],
	resolver: BallPlayResolver) -> void:
	if resolver == null or resolver.state == null or resolver.state.dead:
		return
	var id: int = ball.get_instance_id()
	var current: Vector3 = ball.global_position
	var from: Vector3 = _previous.get(id, current)
	_previous[id] = current
	for contact: Dictionary in batch:
		if contact.body.get_meta("ball_surface", "") == "ground" \
			and get_parent().is_ancestor_of(contact.body) and not resolver.state.has_grounded:
			resolver.record_ground_contact(contact.position)
	var prior_live: String = last_live.get(resolver.get_instance_id(), "")
	var selected: Dictionary = StadiumClubBoundarySweep.observe(self, resolver, from, current)
	if not selected.is_empty() or resolver.state.dead:
		return
	var contacts: Array[Dictionary] = []
	for contact: Dictionary in batch:
		var body: StaticBody3D = contact.body as StaticBody3D
		if body != null and bodies.has(body):
			contacts.append(StadiumClubBoundarySweep.contact_event(body, contact.position, 1))
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.priority > b.priority if a.priority != b.priority else a.segment < b.segment)
	if not contacts.is_empty():
		if contacts[0].role in ["DUGOUT_FACE_LIVE", "SIDE_RETURN_LIVE"] \
			and contacts[0].segment == prior_live:
			last_live[resolver.get_instance_id()] = prior_live
		StadiumClubBoundarySweep.apply(self, resolver, contacts[0])
