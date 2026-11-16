class_name StadiumBoundaryOwnedRuntime
extends StadiumRecipeBoundaryBody
## One paid boundary/contact owner, built from the shared validated layout and real native solids.

const QUERY_MASK: int = 32
var bodies: Array[StaticBody3D] = []
var owned_models: Dictionary = {}
var _issued: Array[Dictionary] = []
var _models: Array[Dictionary] = []
var _live: bool = true
var _property: StadiumPropertyGeometry
var _layout_hash: String = ""
var _graph_hash: String = ""
var _world: Transform3D = Transform3D.IDENTITY
var _sealed: bool = false
var _flights: Dictionary = {}
var _events: Dictionary = {}
var _next_event: int = 0
var _next_flight: int = 0
var _last_live: Dictionary = {}


func build_from(property: StadiumPropertyGeometry, layout: Dictionary, stock: StadiumStock) -> bool:
	if get_child_count() != 0 or property == null or not StadiumBoundaryItems.is_family(layout):
		return false
	var checked: Dictionary = StadiumBoundaryItems.validate(layout, stock, property.tier)
	if not checked.ok:
		return false
	_property = property
	graph = StadiumBoundaryItems.graph_for(layout)
	_graph_hash = graph.signature()
	_layout_hash = JSON.stringify(layout, "", true, true).sha256_text()
	set_meta("boundary_layout_hash", _layout_hash)
	set_meta("wall_manifest", JSON.stringify(layout.walls, "", true, true).sha256_text())
	var rear_paid: bool = false
	for row: Dictionary in checked.boundary_placements:
		if row.item in StadiumBoundaryItems.FENCES:
			rear_paid = true
	var rows: Array[Dictionary] = graph.segments()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		if row.role.begins_with("DUGOUT") or (row.role == "REAR_PERIMETER_DEAD" and rear_paid):
			continue
		_slab(row, index)
	var art: Node3D = Node3D.new()
	art.name = "PanelVisuals"
	add_child(art)
	var panel_rows: Array[Dictionary] = []
	panel_rows.append_array(checked.wall_panels)
	for side: String in ["left", "right"]:
		if layout.walls[side].is_empty():
			var left: bool = side == "left"
			panel_rows.append_array(
				(
					StadiumDugoutRecipe.panels(left)
					if not StadiumBoundaryItems._dugout(layout, left).is_empty()
					else StadiumWallRecipes.side(left)
				)
			)
	if layout.walls.back.is_empty():
		panel_rows.append_array(StadiumWallRecipes.back(graph._shape, "ST-024"))
	for row: Dictionary in panel_rows:
		var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.transform = StadiumWallRecipes.placement(row)
		panel.set_meta("owned_copy", row.get("copy", ""))
		panel.set_meta("wall_socket", row.socket)
		art.add_child(panel)
	for row: Dictionary in checked.boundary_placements:
		var model: Node3D = StadiumBoundaryOwnedModels.create(row.item, row)
		if model == null:
			return false
		model.name = "Owned_" + String(row.copy).sha256_text()
		model.position = row.position
		model.rotation.y = deg_to_rad(float(row.yaw))
		model.set_meta("site", row.site)
		if row.item == "ST-074" and property.has_meta("player_tunnel_layout"):
			var tunnel_host: Dictionary = StadiumPlayerTunnelHostAdapters.binding(
				property.get_meta("player_tunnel_layout"), row.copy, "dugout"
			)
			if (
				not tunnel_host.is_empty()
				and not StadiumPlayerTunnelHostAdapters.apply_dugout(model, tunnel_host)
			):
				model.free()
				return false
		add_child(model)
		owned_models[row.copy] = model
		property.objects[row.copy] = model
		for body: StaticBody3D in model.get_node("Collision").get_children():
			var role: String = body.get_meta("surface_role", "")
			var segment: String = row.site + ":" + str(body.name)
			var kind: String = "dugout"
			var priority: int = 400
			if row.item in StadiumBoundaryItems.DUGOUTS:
				if role == "DUGOUT_FACE_LIVE":
					var inner: bool = String(body.name).ends_with("-1") == (row.site == "DUGOUT-L")
					segment = row.site + ("-FACE-IN" if inner else "-FACE-OUT")
					priority = 650
				elif role == "DUGOUT_ROOF_TERMINAL":
					priority = 700
				elif (
					row.item == "ST-074"
					and (
						String(body.name).begins_with("EndWall")
						or String(body.name).begins_with("Rear")
					)
				):
					role = "DUGOUT_EXTERIOR_DEAD"
			elif row.item == "ST-021":
				kind = "pole"
				segment = row.site
				priority = 900
				body.set_meta("wall_cap_height", row.split)
			elif row.item in StadiumBoundaryItems.FENCES:
				kind = "boundary"
				segment = "REAR-01"
				role = "REAR_PERIMETER_DEAD"
				priority = 300
			elif row.item == "ST-064":
				kind = "panel"
				priority = 250
				role = "BACK_WALL_TERMINAL"
			_tag(body, segment, role, priority, kind)
		var host_meta: Dictionary = {}
		for key: String in [
			"player_tunnel_copy",
			"player_tunnel_adapter_version",
			"player_tunnel_host_profile",
			"player_tunnel_host_port"
		]:
			if model.has_meta(key):
				host_meta[key] = model.get_meta(key)
		_models.append(
			{
				"node": model,
				"copy": row.copy,
				"item": row.item,
				"site": row.site,
				"pose": model.transform,
				"children": model.get_child_count(),
				"host_meta": host_meta
			}
		)
	return true


func _ready() -> void:
	_world = global_transform
	_sealed = true


func _slab(row: Dictionary, index: int) -> void:
	var next: int = (index + 1) % graph.polygon().size()
	var polygon: Array[Vector2] = [
		row.a, row.b, graph.outer_vertex(next), graph.outer_vertex(index)
	]
	var points: PackedVector3Array = []
	for height: float in [0.0, float(row.height)]:
		for corner: Vector2 in polygon:
			points.append(Vector3(corner.x, height, corner.y))
	var body: StaticBody3D = StaticBody3D.new()
	body.name = row.id
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Shape"
	collider.shape = ConvexPolygonShape3D.new()
	collider.shape.margin = 0
	collider.shape.points = points
	body.add_child(collider)
	add_child(body)
	if row.role == "REAR_PERIMETER_DEAD":
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = "TemplateRearWall"
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(16, 1.2, 0.35)
		visual.mesh = mesh
		visual.position = Vector3(0, 0.6, -6.175)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color("897756")
		visual.material_override = material
		body.add_child(visual)
	_tag(body, row.id, row.role, row.priority, "boundary")


func _tag(body: StaticBody3D, segment: String, role: String, priority: int, kind: String) -> void:
	body.collision_layer = 1 | QUERY_MASK
	body.collision_mask = 2
	body.set_meta("club_surface", segment)
	body.set_meta("surface_role", role)
	body.set_meta("surface_priority", priority)
	body.set_meta("surface_kind", kind)
	body.set_meta("boundary_owned", true)
	var shapes: Array = []
	for node: Node in body.get_children():
		if node is CollisionShape3D:
			if not node.shape.changed.is_connected(_retire):
				node.shape.changed.connect(_retire)
			shapes.append({"node": node, "shape": node.shape, "pose": node.transform})
	var meta: Dictionary = {}
	for key: String in [
		"owned_copy",
		"paid_copy",
		"stadium_item",
		"surface_id",
		"surface_role",
		"club_surface",
		"surface_kind",
		"surface_priority",
		"wall_cap_height"
	]:
		meta[key] = {
			"present": body.has_meta(key),
			"value": body.get_meta(key) if body.has_meta(key) else null
		}
	_issued.append(
		{
			"node": body,
			"parent": body.get_parent(),
			"pose": body.transform,
			"shapes": shapes,
			"meta": meta,
			"children": body.get_child_count()
		}
	)
	if role != "DECORATIVE_AFTER_TERMINAL":
		bodies.append(body)


func _retire() -> void:
	_live = false
	_events.clear()


func owns_model(copy: String, model: Node3D) -> bool:
	return owned_models.get(copy) == model


func intact() -> bool:
	if (
		not _live
		or not is_instance_valid(_property)
		or graph == null
		or graph.signature() != _graph_hash
		or (_sealed and (get_parent() != _property or global_transform != _world))
	):
		_retire()
		return false
	for row: Dictionary in _models:
		if (
			not is_instance_valid(row.node)
			or row.node.is_queued_for_deletion()
			or row.node.get_parent() != self
			or row.node.transform != row.pose
			or row.node.get_child_count() != row.children
			or _property.objects.get(row.copy) != row.node
			or row.node.get_meta("owned_copy", "") != row.copy
			or row.node.get_meta("stadium_item", "") != row.item
			or row.node.get_meta("site", "") != row.site
		):
			_retire()
			return false
		for key: String in row.host_meta:
			if not row.node.has_meta(key) or row.node.get_meta(key) != row.host_meta[key]:
				_retire()
				return false
	return _intact_remaining_checks()


func _intact_remaining_checks() -> bool:
	for row: Dictionary in _issued:
		var body: StaticBody3D = row.node
		if (
			not is_instance_valid(body)
			or body.is_queued_for_deletion()
			or body.get_parent() != row.parent
			or body.transform != row.pose
			or body.collision_layer != (1 | QUERY_MASK)
			or body.collision_mask != 2
			or body.get_child_count() != row.children
		):
			_retire()
			return false
		for key: String in row.meta:
			if (
				body.has_meta(key) != row.meta[key].present
				or (row.meta[key].present and body.get_meta(key) != row.meta[key].value)
			):
				_retire()
				return false
		for shape: Dictionary in row.shapes:
			if (
				not is_instance_valid(shape.node)
				or shape.node.get_parent() != body
				or shape.node.transform != shape.pose
				or shape.node.disabled
				or shape.node.shape != shape.shape
			):
				_retire()
				return false
	return true


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	if (
		not intact()
		or not is_instance_valid(ball)
		or resolver == null
		or resolver.state == null
		or resolver.state.dead
	):
		return
	var id: int = resolver.get_instance_id()
	_next_flight += 1
	_flights[id] = {
		"serial": _next_flight,
		"ball": weakref(ball),
		"resolver": resolver,
		"state": resolver.state,
		"field": resolver.field,
		"parent": ball.get_parent(),
		"previous": ball.global_position
	}
	var callback: Callable = _contact_batch.bind(resolver)
	ball.physics_contact_router = callback
	var launch: Callable = _seed.bind(id, ball.get_instance_id())
	if not ball.launch_started.is_connected(launch):
		ball.launch_started.connect(launch)
	_last_live.erase(id)
	var removed: Callable = _forget_flight.bind(id, ball.get_instance_id())
	if not ball.tree_exited.is_connected(removed):
		ball.tree_exited.connect(removed, CONNECT_ONE_SHOT)


func _forget_flight(id: int, ball_id: int) -> void:
	var bound: Dictionary = _flights.get(id, {})
	if not bound.is_empty():
		var ball: BattedBallBody = bound.ball.get_ref()
		if is_instance_valid(ball) and ball.get_instance_id() == ball_id:
			_flights.erase(id)
			_last_live.erase(id)


func _seed(point: Vector3, id: int, ball_id: int) -> void:
	var bound: Dictionary = _flights.get(id, {})
	if not bound.is_empty():
		var ball: BattedBallBody = bound.ball.get_ref()
		if is_instance_valid(ball) and ball.get_instance_id() == ball_id:
			_next_flight += 1
			bound.serial = _next_flight
			bound.previous = point
			bound.erase("junk_car_trap")
			bound.erase("waterfall_trap")
			bound.erase("waterfall_floor")
			bound.erase("waterfall_solid_frame")
			bound.erase("furnishing_solid_frame")
			_last_live.erase(id)


func _flight(resolver: BallPlayResolver) -> Dictionary:
	if not intact() or resolver == null or resolver.state == null or resolver.state.dead:
		return {}
	var row: Dictionary = _flights.get(resolver.get_instance_id(), {})
	if (
		row.is_empty()
		or row.resolver != resolver
		or row.state != resolver.state
		or row.field != resolver.field
	):
		return {}
	var ball: BattedBallBody = row.ball.get_ref()
	if (
		not is_instance_valid(ball)
		or ball.get_parent() != row.parent
		or StadiumTimberDugoutBoundary.ball_radius(ball) <= 0
	):
		return {}
	return row


func event(
	previous: Vector3, current: Vector3, radius: float, resolver: BallPlayResolver = null
) -> Dictionary:
	if (
		not intact()
		or not is_inside_tree()
		or not previous.is_finite()
		or not current.is_finite()
		or radius <= 0
	):
		return {}
	var candidates: Array[Dictionary] = []
	var crossing: Dictionary = graph.crossing(previous, current)
	if not crossing.is_empty():
		crossing["kind"] = "boundary"
		candidates.append(crossing)
	for body: StaticBody3D in bodies:
		var hit: Dictionary = _sweep(body, previous, current, radius)
		if not hit.is_empty():
			candidates.append(hit)
	if (
		_property.has_meta("live_furnishing_layout")
		and not _property.issued_feature_absent(&"live_furnishings")
	):
		var furnishing_flight: Dictionary = (
			{} if resolver == null else _flights.get(resolver.get_instance_id(), {})
		)
		var allow_water: bool = (
			furnishing_flight.get("furnishing_solid_frame", -1) != Engine.get_physics_frames()
		)
		var furnishing: Dictionary = StadiumLiveFurnishingRuntime.event(
			_property, previous, current, radius, allow_water
		)
		if not furnishing.is_empty():
			candidates.append(furnishing)
	if (
		_property.has_meta("salvage_car_layout")
		and not _property.issued_feature_absent(&"salvage_car")
	):
		var car_flight: Dictionary = {} if resolver == null else _flight(resolver)
		var car: Dictionary = StadiumJunkCarRuntime.event(
			_property,
			previous,
			current,
			radius,
			car_flight,
			car_flight.get("furnishing_solid_frame", -1) != Engine.get_physics_frames()
		)
		if not car.is_empty():
			candidates.append(car)
	if _property.has_live_waterfall():
		var waterfall_flight: Dictionary = {} if resolver == null else _flight(resolver)
		var waterfall: Dictionary = StadiumWaterfallLiveRuntime.event(
			_property,
			previous,
			current,
			radius,
			waterfall_flight,
			waterfall_flight.get("waterfall_solid_frame", -1) != Engine.get_physics_frames()
		)
		if not waterfall.is_empty():
			candidates.append(waterfall)
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return StadiumTimberDugoutBoundary.precedes(a, b, previous.distance_to(current))
	)
	if candidates.is_empty():
		return {}
	var selected: Dictionary = candidates[0]
	_next_event += 1
	selected["issued"] = _next_event
	selected["flight"] = -1 if resolver == null else resolver.get_instance_id()
	selected["play"] = (
		-1 if resolver == null or resolver.state == null else resolver.state.get_instance_id()
	)
	var bound: Dictionary = {} if resolver == null else _flight(resolver)
	selected["ball"] = -1 if bound.is_empty() else bound.ball.get_ref().get_instance_id()
	selected["serial"] = -1 if bound.is_empty() else bound.serial
	_events[_next_event] = selected.duplicate(true)
	return selected


func _sweep(body: StaticBody3D, previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.shape.margin = 0
	query.margin = 0
	query.collision_mask = QUERY_MASK
	query.transform.origin = previous
	var excluded: Array[RID] = []
	for other: StaticBody3D in bodies:
		if other != body:
			excluded.append(other.get_rid())
	for row: Dictionary in _issued:
		if row.node != body and not bodies.has(row.node):
			excluded.append(row.node.get_rid())
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shapes: Array[Node] = body.find_children("*", "CollisionShape3D", true, false)
	if shapes.size() == 1 and (shapes[0] as CollisionShape3D).shape is BoxShape3D:
		var shape: CollisionShape3D = shapes[0]
		# Existing exact native sphere witness rebased by the real oriented box broad phase.
		if shape.name != "Shape" or body.get_meta("surface_kind") == "panel":
			return _cast_witness(space, query, body, previous, current)
		var hit: Dictionary = StadiumTimberDugoutBoundary._front_contact(
			space, query, body, previous, current, radius
		)
		if not hit.is_empty():
			hit["body_id"] = body.get_instance_id()
			hit["owned_copy"] = body.get_meta("owned_copy", "")
		return hit
	return _cast_witness(space, query, body, previous, current)


func _cast_witness(
	space: PhysicsDirectSpaceState3D,
	query: PhysicsShapeQueryParameters3D,
	body: StaticBody3D,
	previous: Vector3,
	current: Vector3
) -> Dictionary:
	var fraction: float = 0.0
	if not StadiumTimberDugoutBoundary._witness(space, query, body):
		query.motion = current - previous
		var fractions: PackedFloat32Array = space.cast_motion(query)
		if fractions.size() != 2 or fractions[0] >= 1:
			return {}
		fraction = fractions[1]
		query.motion = Vector3.ZERO
		var advance: float = (
			StadiumHeightSweep.CONTACT_EPS_M
			/ maxf(previous.distance_to(current), StadiumHeightSweep.CONTACT_EPS_M)
		)
		query.transform.origin = previous.lerp(current, minf(1, fraction + advance))
		if not StadiumTimberDugoutBoundary._witness(space, query, body):
			return {}
	return _contact_event(body, previous.lerp(current, fraction), fraction)


func _contact_event(body: StaticBody3D, at: Vector3, fraction: float) -> Dictionary:
	if not bodies.has(body):
		return {}
	var role: String = body.get_meta("surface_role")
	if body.get_meta("surface_kind") == "pole":
		role = StadiumFoulPoleModels.role_at(
			clampf(at.y, 0, StadiumFoulPoleSites.HEIGHT), body.get_meta("wall_cap_height")
		)
	return {
		"segment": body.get_meta("club_surface"),
		"role": role,
		"position": at,
		"fraction": fraction,
		"priority": body.get_meta("surface_priority"),
		"kind": body.get_meta("surface_kind"),
		"swept_contact": true,
		"body_id": body.get_instance_id(),
		"owned_copy": body.get_meta("owned_copy", "")
	}


func observe(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> Dictionary:
	var bound: Dictionary = _flight(resolver)
	if bound.is_empty():
		return {}
	var ball: BattedBallBody = bound.ball.get_ref()
	var selected: Dictionary = event(
		previous, current, StadiumTimberDugoutBoundary.ball_radius(ball), resolver
	)
	var floor_before: int = int(resolver.state.result_floor)
	var observed_end: Vector3 = current if selected.is_empty() else selected.position
	if not resolver.state.is_foul_play:
		StadiumBoundaryObserver._bands(resolver, previous, observed_end)
	if _property.has_live_waterfall():
		StadiumWaterfallLiveRuntime.record_bands(
			_property, bound, previous, observed_end, floor_before
		)
	if selected.is_empty():
		_last_live.erase(resolver.get_instance_id())
	else:
		apply_event(resolver, selected)
	return selected


func apply_event(resolver: BallPlayResolver, selected: Dictionary) -> bool:
	var bound: Dictionary = _flight(resolver)
	if (
		bound.is_empty()
		or selected.get("ball", -1) != bound.ball.get_ref().get_instance_id()
		or selected.get("serial", -1) != bound.serial
		or selected.get("flight", -1) != resolver.get_instance_id()
		or selected.get("play", -1) != resolver.state.get_instance_id()
		or not _events.has(selected.get("issued", -1))
		or not ClubCareer.same(_events[selected.issued], selected)
	):
		return false
	_events.erase(selected.issued)
	var id: int = resolver.get_instance_id()
	if selected.role in ["DUGOUT_FACE_LIVE", "SIDE_RETURN_LIVE", "LIVE_RICOCHET"]:
		if _last_live.get(id, "") == selected.segment:
			return false
		_last_live[id] = selected.segment
	else:
		_last_live.erase(id)
	var applied: bool = false
	if selected.kind in ["waterfall_solid", "waterfall_trap"]:
		if selected.kind == "waterfall_solid":
			bound["waterfall_solid_frame"] = Engine.get_physics_frames()
		elif bound.get("waterfall_solid_frame", -1) == Engine.get_physics_frames():
			return false
		applied = StadiumWaterfallLiveRuntime.apply(_property, resolver, selected, bound)
	elif selected.kind in ["junk_car_solid", "junk_car_trap"]:
		if selected.kind == "junk_car_solid":
			bound["furnishing_solid_frame"] = Engine.get_physics_frames()
		elif bound.get("furnishing_solid_frame", -1) == Engine.get_physics_frames():
			return false
		applied = StadiumJunkCarRuntime.apply(_property, resolver, selected, bound)
	elif selected.kind in ["furnishing_solid", "furnishing_water"]:
		if selected.kind == "furnishing_solid":
			bound["furnishing_solid_frame"] = Engine.get_physics_frames()
		elif bound.get("furnishing_solid_frame", -1) == Engine.get_physics_frames():
			return false
		applied = StadiumLiveFurnishingRuntime.apply(_property, resolver, selected)
	elif selected.kind == "boundary" or selected.role == "DUGOUT_FACE_LIVE":
		applied = graph.apply(resolver, selected)
	else:
		resolver.state.record_stadium_contact(
			"boundary",
			graph.identity(),
			selected.segment,
			selected.role,
			selected.position,
			"contact"
		)
		if selected.kind == "pole":
			resolver.state.is_foul_play = false
			resolver.state.is_fair = true
			if (
				selected.role == "FOUL_POLE_UPPER"
				and not resolver.state.has_grounded
				and not resolver.state.defender_touched
			):
				resolver.state.raise_result_floor(BallPlayState.ResultFloor.HOME_RUN)
				resolver._resolve_floor(&"foul_pole_upper", selected.position)
			else:
				resolver.record_back_wall_contact(selected.position)
		elif selected.kind == "panel":
			resolver.record_back_wall_contact(selected.position)
		else:
			StadiumDugoutBoundary.dead_area(resolver, selected.position, &"dugout_terminal")
		applied = true
	if applied:
		contacts.append(
			{
				"segment": selected.segment,
				"role": selected.role,
				"position": selected.position,
				"owned_copy": selected.get("owned_copy", ""),
				"body_id": selected.get("body_id", 0),
				"frame": Engine.get_physics_frames()
			}
		)
	return applied


func _contact_batch(
	ball: BattedBallBody, batch: Array[Dictionary], resolver: BallPlayResolver
) -> void:
	var bound: Dictionary = _flight(resolver)
	if bound.is_empty() or bound.ball.get_ref() != ball:
		return
	for contact: Dictionary in batch:
		if (
			contact.body.get_meta("ball_surface", "") == "ground"
			and _property.is_ancestor_of(contact.body)
			and not resolver.state.has_grounded
		):
			resolver.record_ground_contact(contact.position)
	# An actual native car manifold also wins if solver correction leaves no
	# later sweep overlap. It cannot coincide with an unreachable-ball award.
	for contact: Dictionary in batch:
		var body: StaticBody3D = contact.body as StaticBody3D
		if (
			body != null
			and body.get_meta("stadium_item", "") == "ST-005"
			and not StadiumJunkCarRuntime.native_event(_property, body, contact.position).is_empty()
		):
			bound["furnishing_solid_frame"] = Engine.get_physics_frames()
			StadiumJunkCarRuntime.interrupt_dwell(bound)
	var waterfall_impact: bool = false
	if _property.has_live_waterfall():
		for contact: Dictionary in batch:
			if (
				contact.body is StaticBody3D
				and contact.body.get_meta("stadium_item", "") == "ST-046"
				and not (
					StadiumWaterfallLiveRuntime
					. native_event(_property, contact.body, contact.position)
					. is_empty()
				)
			):
				waterfall_impact = StadiumWaterfallLiveRuntime.native_impact(_property, ball, bound)
				if waterfall_impact:
					bound["waterfall_solid_frame"] = Engine.get_physics_frames()
				break
	var from: Vector3 = bound.previous
	bound.previous = ball.global_position
	var prior_live: String = _last_live.get(resolver.get_instance_id(), "")
	var selected: Dictionary = observe(resolver, from, ball.global_position)
	if not selected.is_empty() or resolver.state.dead:
		return
	var candidates: Array[Dictionary] = []
	for contact: Dictionary in batch:
		var body: StaticBody3D = contact.body as StaticBody3D
		if body != null and bodies.has(body):
			candidates.append(_contact_event(body, contact.position, 1))
		elif (
			body != null
			and _property.has_live_waterfall()
			and body.get_meta("stadium_item", "") == "ST-046"
		):
			if waterfall_impact:
				var waterfall: Dictionary = StadiumWaterfallLiveRuntime.native_event(
					_property, body, contact.position
				)
				if not waterfall.is_empty():
					candidates.append(waterfall)
		elif (
			body != null
			and _property.has_meta("salvage_car_layout")
			and body.get_meta("stadium_item", "") == "ST-005"
		):
			var car: Dictionary = StadiumJunkCarRuntime.native_event(
				_property, body, contact.position
			)
			if not car.is_empty():
				candidates.append(car)
		elif (
			body != null
			and _property.has_meta("live_furnishing_layout")
			and StadiumLiveFurnishingItems.PRICES.has(body.get_meta("stadium_item", ""))
		):
			var furnishing: Dictionary = StadiumLiveFurnishingRuntime.native_event(
				_property, body, contact.position
			)
			if not furnishing.is_empty():
				candidates.append(furnishing)
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.priority > b.priority if a.priority != b.priority else a.segment < b.segment
	)
	if not candidates.is_empty():
		if (
			candidates[0].role in ["DUGOUT_FACE_LIVE", "SIDE_RETURN_LIVE", "LIVE_RICOCHET"]
			and candidates[0].segment == prior_live
		):
			_last_live[resolver.get_instance_id()] = prior_live
		_next_event += 1
		candidates[0]["issued"] = _next_event
		candidates[0]["flight"] = resolver.get_instance_id()
		candidates[0]["play"] = resolver.state.get_instance_id()
		candidates[0]["ball"] = ball.get_instance_id()
		candidates[0]["serial"] = bound.serial
		_events[_next_event] = candidates[0].duplicate(true)
		apply_event(resolver, candidates[0])
	# Family24 receivers reuse this native batch after all existing boundary priority.
	if not resolver.state.dead and _property.has_meta("receiver_layout"):
		for contact: Dictionary in batch:
			if resolver.state.dead:
				break
			if contact.body.get_meta("surface_role", "") == "RECEIVER_CONTAINMENT_FOUL":
				_property._receiver_native_contact(contact.body, ball, resolver, contact.position)
