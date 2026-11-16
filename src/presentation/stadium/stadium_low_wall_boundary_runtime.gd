class_name StadiumLowWallBoundaryRuntime
extends StadiumBoundaryOwnedRuntime
## Complete family46 construction only. Native issuance/contact routing is inherited unchanged.
## A validated result is evidence to compare, never authority accepted from caller metadata.

const ISSUED_CONTRACT_VERSION: int = 3

var _low_nodes: Array[Dictionary] = []
var _low_hot_nodes: Array[StadiumLowWallNodeSeal] = []
var _low_resources: Array[Dictionary] = []
var _low_children: Array[Node] = []
var _low_meta: Dictionary = {}
var _low_graph: StadiumRecipeBoundary
var _low_graph_script: Script
var _low_graph_meta: Dictionary = {}
var _low_captured: bool = false
var _low_root: Dictionary = {}
var _low_pool_evidence: Dictionary = {}
var _low_collision_nodes: Array[StadiumLowWallNodeSeal] = []
var _low_collision_resources: Array[Dictionary] = []


func build(_recipe: String = "straight", _material_id: String = "ST-024") -> bool:
	return false


func build_owned(_walls: Dictionary, _stock: StadiumStock) -> bool:
	return false


func build_from(
	_target: StadiumPropertyGeometry, _layout: Dictionary, _stock: StadiumStock
) -> bool:
	return false


func build_complete(
	property: StadiumPropertyGeometry,
	layout: Dictionary,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	surface_access: Array[String],
	validated: Dictionary
) -> bool:
	if (
		get_child_count() != 0
		or _low_captured
		or property == null
		or transform != Transform3D.IDENTITY
		or property.transform != Transform3D.IDENTITY
		or not StadiumPropertyGeometry.construction_target_allowed(property)
		or not StadiumLowWallLayout.is_family(layout)
		or stock == null
		or pieces == null
		or StadiumWallPieceOwnership.from_data(pieces.to_data(), stock.capacity_count()) == null
	):
		return false
	var checked: Dictionary = StadiumLowWallLayout.validate(
		layout, stock, pieces, surface_access, property.tier
	)
	if (
		not checked.get("ok", false)
		or not ClubCareer.same(checked, validated)
		or StadiumLowWallLayout.graph_for(layout) == null
	):
		return false
	_property = property
	graph = StadiumLowWallLayout.graph_for(layout)
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
	if layout.walls.back.is_empty() and checked.low_panels.is_empty():
		panel_rows.append_array(StadiumWallRecipes.back(graph._shape, "ST-024"))
	for row: Dictionary in panel_rows:
		var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
		panel.get_node("PanelCollision").free()
		panel.transform = StadiumWallRecipes.placement(row)
		panel.set_meta("owned_copy", row.get("copy", ""))
		panel.set_meta("wall_socket", row.socket)
		art.add_child(panel)
	for row: Dictionary in checked.low_panels:
		var panel: Node3D = StadiumLowWallModels.create(row)
		if panel == null:
			return false
		panel.transform = StadiumWallRecipes.placement(row)
		panel.set_meta("stadium_item", row.item)
		panel.set_meta("wall_height", row.height)
		panel.set_meta("wall_width", row.width)
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
	_low_pool_evidence = StadiumLowWallResourcePool.prepare(self)
	return _low_pool_evidence.get("ok", false) and _capture_low_seal()


func _slab(row: Dictionary, index: int) -> void:
	if not graph is StadiumLowWallGraph or row.role != "BACK_WALL_TERMINAL":
		super._slab(row, index)
		return
	# The authored straight outfield prisms are exactly axis-aligned boxes. This
	# keeps identical native extents; only this family supplies exact sphere contact times.
	var body: StaticBody3D = StaticBody3D.new()
	body.name = row.id
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Shape"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(absf(row.a.x - row.b.x), row.height, StadiumRecipeBoundary.THICKNESS)
	shape.margin = 0
	collider.shape = shape
	collider.position = Vector3(
		(row.a.x + row.b.x) * 0.5, row.height * 0.5, row.a.y + StadiumRecipeBoundary.THICKNESS * 0.5
	)
	body.add_child(collider)
	add_child(body)
	_tag(body, row.id, row.role, row.priority, "boundary")


func _sweep(body: StaticBody3D, previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	if (
		not graph is StadiumLowWallGraph
		or body.get_parent() != self
		or body.get_meta("surface_role", "") != "BACK_WALL_TERMINAL"
	):
		return super._sweep(body, previous, current, radius)
	var collider: CollisionShape3D = body.get_node_or_null("Shape") as CollisionShape3D
	if collider == null or not collider.shape is BoxShape3D:
		return {}
	# Jolt can report tangent contact later than the center crossing. Prove
	# contact against this exact sealed native box, then verify its owner using the
	# existing contact tolerance inward. No ball radius or physical solid is enlarged.
	var inverse: Transform3D = collider.global_transform.affine_inverse()
	var from: Vector3 = inverse * previous
	var to: Vector3 = inverse * current
	var half: Vector3 = collider.shape.size * 0.5
	var fraction: float = _box_sphere_fraction(from, to, half, radius)
	if fraction < 0:
		return {}
	var local: Vector3 = from.lerp(to, fraction)
	var toward: Vector3 = local.clamp(-half, half) - local
	if toward.length_squared() == 0:
		toward = Vector3.UP
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.shape.margin = 0
	query.margin = 0
	query.collision_mask = QUERY_MASK
	query.transform.origin = (
		collider.global_transform * (local + toward.normalized() * StadiumHeightSweep.CONTACT_EPS_M)
	)
	var excluded: Array[RID] = []
	for row: Dictionary in _issued:
		if row.node != body:
			excluded.append(row.node.get_rid())
	query.exclude = excluded
	if not StadiumTimberDugoutBoundary._witness(get_world_3d().direct_space_state, query, body):
		_retire()  # A proven contact without native ownership cannot award a clearance.
		return {}
	var selected: Dictionary = _contact_event(body, previous.lerp(current, fraction), fraction)
	selected["low_wall_exact_witness"] = true
	return selected


static func _box_sphere_fraction(from: Vector3, to: Vector3, half: Vector3, radius: float) -> float:
	# Squared distance to an AABB is piecewise quadratic. Split at all slab
	# crossings, solve each exact interval, and retain the first contact only.
	var motion: Array[float] = [float(to.x) - from.x, float(to.y) - from.y, float(to.z) - from.z]
	var cuts: Array[float] = [0.0, 1.0]
	for axis: int in range(3):
		if motion[axis] != 0:
			for edge: float in [-half[axis], half[axis]]:
				var at: float = (edge - from[axis]) / motion[axis]
				if at > 0 and at < 1:
					cuts.append(at)
	cuts.sort()
	for index: int in range(cuts.size() - 1):
		var begin: float = cuts[index]
		var end: float = cuts[index + 1]
		var a: float = 0
		var b: float = 0
		var c: float = -radius * radius
		for axis: int in range(3):
			var midpoint: float = from[axis] + motion[axis] * ((begin + end) * 0.5)
			if midpoint >= -half[axis] and midpoint <= half[axis]:
				continue
			var edge: float = -half[axis] if midpoint < -half[axis] else half[axis]
			var gap: float = from[axis] + motion[axis] * begin - edge
			a += motion[axis] * motion[axis]
			b += 2 * gap * motion[axis]
			c += gap * gap
		if c <= 0:
			return begin
		if a == 0:
			continue
		var discriminant: float = b * b - 4 * a * c
		if discriminant < 0:
			continue
		var root: float = (-b - sqrt(discriminant)) / (2 * a)
		if root >= 0 and root <= end - begin:
			return begin + root
	return -1


func _capture_low_seal() -> bool:
	_low_root = {"script": get_script()}
	for description: Dictionary in get_property_list():
		var key: StringName = description.name
		if (
			int(description.usage) & PROPERTY_USAGE_STORAGE
			and not int(description.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE
			and key != &"script"
			and not String(key).begins_with("metadata/")
		):
			_low_root[key] = _copy_value(get(key))
	_low_graph = graph
	_low_graph_script = graph.get_script()
	_low_graph_meta = _metadata(graph)
	_low_graph_meta.make_read_only()
	_low_children = get_children(true)
	_low_meta = _metadata(self)
	var seen: Dictionary = {}
	for node: Node in find_children("*", "", true, false):
		if not node is Node3D or node.get_script() != null:
			return false
		if node.get_child_count(true) != node.get_child_count():
			return false
		var seal: StadiumLowWallNodeSeal = StadiumLowWallNodeSeal.new(node)
		_low_hot_nodes.append(seal)
		node.tree_exiting.connect(_retire)
		node.child_order_changed.connect(_retire)
		var fields: Array[StringName] = [&"transform", &"top_level", &"visible", &"process_mode"]
		# Include all stored native state, not only values used by collision authority.
		for description: Dictionary in node.get_property_list():
			var key: StringName = description.name
			if (
				int(description.usage) & PROPERTY_USAGE_STORAGE
				and not fields.has(key)
				and key != &"script"
				and not String(key).begins_with("metadata/")
			):
				fields.append(key)
		var values: Array = []
		for key: StringName in fields:
			var value: Variant = node.get(key)
			values.append(_copy_value(value))
			if not _capture_nested_resources(value, seen):
				return false
		var metadata: Dictionary = _metadata(node)
		if not _capture_nested_resources(metadata, seen):
			return false
		_low_nodes.append(
			{
				"node": node,
				"parent": node.get_parent(),
				"name": node.name,
				"children": node.get_children(),
				"fields": fields,
				"values": values,
				"metadata": metadata
			}
		)
	# Every ancestor transform/process state of a physical body is authority,
	# including optional owned model Collision containers in empty46 layouts.
	var critical_nodes: Dictionary = {}
	for seal: StadiumLowWallNodeSeal in _low_hot_nodes:
		if seal.body == null and seal.collision == null:
			continue
		var ancestor: Node = seal.node
		while ancestor != null and ancestor != self:
			critical_nodes[ancestor.get_instance_id()] = true
			ancestor = ancestor.get_parent()
	for seal: StadiumLowWallNodeSeal in _low_hot_nodes:
		if critical_nodes.has(seal.node.get_instance_id()):
			_low_collision_nodes.append(seal)
	for row: Dictionary in _low_nodes:
		for key: String in ["children", "fields", "values", "metadata"]:
			row[key].make_read_only()
		row.make_read_only()
	for row: Dictionary in _low_resources:
		row.keys.make_read_only()
		row.values.make_read_only()
		row.metadata.make_read_only()
		row.make_read_only()
	for row: Dictionary in _low_resources:
		if row.resource is Shape3D or row.resource is PhysicsMaterial:
			_low_collision_resources.append(row)
	_low_collision_nodes.make_read_only()
	_low_collision_resources.make_read_only()
	tree_exiting.connect(_retire)
	child_order_changed.connect(_retire)
	_low_nodes.make_read_only()
	_low_hot_nodes.make_read_only()
	_low_resources.make_read_only()
	_low_children.make_read_only()
	_low_meta.make_read_only()
	_low_root.make_read_only()
	_low_captured = true
	return true


func _capture_nested_resources(value: Variant, seen: Dictionary, depth: int = 0) -> bool:
	if depth > 16:
		return false
	return _capture_nested_resources_remaining_checks(value, seen, depth)


func _capture_nested_resources_remaining_checks(
	value: Variant,
	seen: Dictionary,
	depth: int
) -> bool:
	if value is Resource:
		return _capture_resource_children(value, seen, depth)
	if value is Array:
		for nested: Variant in value:
			if not _capture_nested_resources(nested, seen, depth + 1):
				return false
	elif value is Dictionary:
		for nested: Variant in value.values():
			if not _capture_nested_resources(nested, seen, depth + 1):
				return false
	return true




func _capture_resource_children(value: Resource, seen: Dictionary, depth: int) -> bool:
	if seen.has(value.get_instance_id()):
		return true
	# The existing finite material serializer also captures inactive native fields.
	var start: int = _low_resources.size()
	if not StadiumFloodlightOwnedModels._capture_resource(value, _low_resources, seen, 0, true):
		return false
	for index in range(start, _low_resources.size()):
		var row: Dictionary = _low_resources[index]
		row["metadata"] = _metadata(row.resource)
		row["resource_name"] = row.resource.resource_name
		row["resource_path"] = row.resource.resource_path
		row["resource_local_to_scene"] = row.resource.resource_local_to_scene
		if not row.resource.changed.is_connected(_retire):
			row.resource.changed.connect(_retire)
		for nested: Variant in row.values:
			if not _capture_nested_resources(nested, seen, depth + 1):
				return false
		if not _capture_nested_resources(row.metadata, seen, depth + 1):
			return false
	return true


func intact() -> bool:
	# New issued contract: cosmetic leaf state is checked at deep transitions.
	# Native collision authority and fresh owner inputs remain synchronous.
	return _intact(false)


func deep_intact() -> bool:
	return _intact(true)


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	bind_issued_ball(ball, resolver)


func bind_issued_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	if (
		not is_instance_valid(ball)
		or resolver == null
		or resolver.state == null
		or resolver.state.dead
		or not deep_intact()
	):
		return false
	var previous_serial: int = _next_flight
	super.bind_ball(ball, resolver)
	var flight: Dictionary = _flights.get(resolver.get_instance_id(), {})
	return (
		_live
		and not flight.is_empty()
		and int(flight.serial) > previous_serial
		and flight.ball.get_ref() == ball
		and flight.resolver == resolver
		and flight.state == resolver.state
		and flight.field == resolver.field
		and flight.parent == ball.get_parent()
		and ball.physics_contact_router == _contact_batch.bind(resolver)
	)


func _intact(deep: bool) -> bool:
	if (
		_property is StadiumLowWallProperty
		and not (_property as StadiumLowWallProperty).low_context_intact(deep)
	):
		_retire()
		return false
	if not deep:
		return _issued_alive()
	if (
		not _low_captured
		or not super.intact()
		or graph != _low_graph
		or (_sealed and global_transform != Transform3D.IDENTITY)
		or graph.get_script() != _low_graph_script
		or not _metadata_matches(graph, _low_graph_meta)
		or get_children(true) != _low_children
		or not _metadata_matches(self, _low_meta)
	):
		_retire()
		return false
	for key: StringName in _low_root:
		if get(key) != _low_root[key]:
			_retire()
			return false
	return _captured_nodes_intact(deep)


func _captured_nodes_intact(deep: bool) -> bool:
	for seal: StadiumLowWallNodeSeal in _low_hot_nodes if deep else _low_collision_nodes:
		if not seal.intact():
			_retire()
			return false
	if deep:
		for row: Dictionary in _low_nodes:
			var node: Node = row.node
			if (
				not is_instance_valid(node)
				or node.is_queued_for_deletion()
				or node.get_script() != null
				or node.get_parent() != row.parent
				or node.name != row.name
				or node.get_children() != row.children
				or not _metadata_matches(node, row.metadata)
			):
				_retire()
				return false
			for index in range(row.fields.size()):
				if node.get(row.fields[index]) != row.values[index]:
					_retire()
					return false
	for row: Dictionary in _low_resources if deep else _low_collision_resources:
		var resource: Resource = row.resource
		if (
			not is_instance_valid(resource)
			or not _metadata_matches(resource, row.metadata)
			or resource.resource_name != row.resource_name
			or resource.resource_path != row.resource_path
			or resource.resource_local_to_scene != row.resource_local_to_scene
		):
			_retire()
			return false
		for index in range(row.keys.size()):
			if resource.get(row.keys[index]) != row.values[index]:
				_retire()
				return false
	return true


static func _copy_value(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


static func _metadata(object: Object) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in object.get_meta_list():
		result[key] = _copy_value(object.get_meta(key))
	return result


static func _metadata_matches(object: Object, expected: Dictionary) -> bool:
	if object.get_meta_list().size() != expected.size():
		return false
	for key: StringName in expected:
		if not object.has_meta(key) or object.get_meta(key) != expected[key]:
			return false
	return true


func _issued_alive() -> bool:
	# Contract3: supported APIs/lifecycle own mutation; full captured native
	# fields/resources and graph signatures remain at deep proof boundaries.
	if (
		not _live
		or not _low_captured
		or not is_instance_valid(_property)
		or graph != _low_graph
		or graph == null
		or graph.get_script() != _low_graph_script
		or (_sealed and (get_parent() != _property or global_transform != _world))
	):
		_retire()
		return false
	for seal: StadiumLowWallNodeSeal in _low_collision_nodes:
		if (
			not is_instance_valid(seal.node)
			or seal.node.is_queued_for_deletion()
			or seal.node.get_parent() != seal.parent
		):
			_retire()
			return false
	return true
