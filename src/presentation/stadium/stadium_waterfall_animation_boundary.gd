class_name StadiumWaterfallAnimationBoundary
extends StadiumBoundaryOwnedRuntime
## Exact47/base45 issued owner. Original45 construction and contact routing stay inherited.

var _boundary_issue_attempted: bool = false
var _boundary_issued_ever: bool = false
var _boundary_issued_live: bool = false
var _boundary_root: Dictionary = {}
var _boundary_nodes: Array[Dictionary] = []
var _boundary_collision_nodes: Array[Dictionary] = []
var _boundary_issued_records: Array[Dictionary] = []
var _boundary_model_records: Array[Dictionary] = []
var _boundary_bodies: Array[StaticBody3D] = []
var _boundary_owned_models: Dictionary = {}


func seal_issued_context() -> bool:
	# One attempt, after attachment/animation construction and the original deep proof.
	# A failed attempt or a later retirement can never recapture a replacement graph.
	if _boundary_issue_attempted or _boundary_issued_ever:
		return false
	_boundary_issue_attempted = true
	if not _sealed or not is_inside_tree() or is_queued_for_deletion() or not deep_intact():
		_retire()
		return false
	var property: StadiumWaterfallAnimationProperty = _property as StadiumWaterfallAnimationProperty
	if not property._context_attached or get_parent() != property:
		_retire()
		return false
	_boundary_root = {
		"property": property,
		"parent": get_parent(),
		"pose": transform,
		"world": _world,
		"graph": graph,
		"graph_script": graph.get_script(),
		"graph_signature": _graph_hash,
		"layout_hash": _layout_hash,
		"children": get_children(true),
		"boundary_layout_hash": get_meta("boundary_layout_hash", ""),
		"wall_manifest": get_meta("wall_manifest", "")
	}
	var critical: Dictionary = {}
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		# find_children omits internal nodes. Reject them before sealing instead of
		# leaving an unobserved structural/collision branch in the issued tree.
		if (
			not is_instance_valid(node)
			or node.is_queued_for_deletion()
			or node.get_child_count(true) != node.get_child_count()
		):
			_retire()
			return false
		if node != self:
			var row: Dictionary = {
				"node": node,
				"parent": node.get_parent(),
				"script": node.get_script(),
				"name": node.name,
				"children": node.get_children(true),
				"process_mode": node.process_mode
			}
			if node is Node3D:
				row["pose"] = node.transform
				row["top_level"] = node.top_level
			_boundary_nodes.append(row)
		if node is CollisionObject3D or node is CollisionShape3D:
			var ancestor: Node = node
			while ancestor != null and ancestor != self:
				critical[ancestor.get_instance_id()] = true
				ancestor = ancestor.get_parent()
			if ancestor != self:
				_retire()
				return false
		pending.append_array(node.get_children())
	return _seal_issued_context_remaining_checks(critical)


func _seal_issued_context_remaining_checks(critical: Dictionary) -> bool:
	for row: Dictionary in _boundary_nodes:
		if critical.has(row.node.get_instance_id()):
			_boundary_collision_nodes.append(row)
	# These are independent comparison records, never the mutable flight/event state.
	_boundary_issued_records = _issued.duplicate(true)
	_boundary_model_records = _models.duplicate(true)
	_boundary_bodies = bodies.duplicate()
	_boundary_owned_models = owned_models.duplicate()
	for value: Variant in [
		_boundary_root,
		_boundary_nodes,
		_boundary_collision_nodes,
		_boundary_issued_records,
		_boundary_model_records,
		_boundary_bodies,
		_boundary_owned_models
	]:
		_freeze_comparison(value)
	if not _watch_issued_node(self):
		_retire()
		return false
	for row: Dictionary in _boundary_nodes:
		if not _watch_issued_node(row.node):
			_retire()
			return false
	# Reconcile after capture and signal hookup; publish live issuance only last.
	if not deep_intact() or not _issued_owner_intact() or not _issued_records_intact():
		_retire()
		return false
	_boundary_issued_ever = true
	_boundary_issued_live = true
	return true


func _watch_issued_node(node: Node) -> bool:
	if not node.tree_exiting.is_connected(_retire) and node.tree_exiting.connect(_retire) != OK:
		return false
	if (
		not node.child_order_changed.is_connected(_retire)
		and node.child_order_changed.connect(_retire) != OK
	):
		return false
	return true


func _retire() -> void:
	_boundary_issue_attempted = true
	_boundary_issued_live = false
	super._retire()


func intact() -> bool:
	# Construction/admission still uses the original full proof. Issued hot work
	# relies on supported API retirement, exact owner inputs and physical identity.
	if not _boundary_issued_ever:
		return deep_intact()
	if not _boundary_issued_live or not _issued_owner_intact():
		_retire()
		return false
	return true


func deep_intact() -> bool:
	# Do not call property.props_intact here: that proof can call this boundary.
	if not _motion_context(true):
		_retire()
		return false
	# Reconcile immutable comparison records before the inherited proof consumes
	# its mutable construction tables, including their expected field schemas.
	if (
		_boundary_issued_ever
		and (
			not _boundary_issued_live or not _issued_owner_intact() or not _issued_records_intact()
		)
	):
		_retire()
		return false
	if not super.intact():
		_retire()
		return false
	return true


func _motion_context(deep: bool) -> bool:
	return (
		is_instance_valid(_property)
		and not _property.is_queued_for_deletion()
		and _property.get_script() == StadiumWaterfallAnimationProperty
		and (
			(_property as StadiumWaterfallAnimationProperty).animation_layout.get("animation_base")
			== 45
		)
		and (_property as StadiumWaterfallAnimationProperty).motion_context_intact(deep)
	)


func _issued_owner_intact() -> bool:
	if (
		not _live
		or not _sealed
		or not is_inside_tree()
		or is_queued_for_deletion()
		or get_script() != StadiumWaterfallAnimationBoundary
		or _boundary_root.is_empty()
		or not _motion_context(false)
		or _property != _boundary_root.property
		or get_parent() != _boundary_root.parent
		or get_parent() != _property
		or transform != _boundary_root.pose
		or _world != _boundary_root.world
		or global_transform != _boundary_root.world
		or not is_instance_valid(graph)
		or graph != _boundary_root.graph
		or graph.get_script() != _boundary_root.graph_script
	):
		return false
	for row: Dictionary in _boundary_collision_nodes:
		if (
			not is_instance_valid(row.node)
			or row.node.is_queued_for_deletion()
			or row.node.get_parent() != row.parent
		):
			return false
	return true


func _issued_records_intact() -> bool:
	if (
		_graph_hash != _boundary_root.graph_signature
		or graph.signature() != _boundary_root.graph_signature
		or _layout_hash != _boundary_root.layout_hash
		or get_meta("boundary_layout_hash", "") != _boundary_root.boundary_layout_hash
		or get_meta("wall_manifest", "") != _boundary_root.wall_manifest
		or get_children(true) != _boundary_root.children
		or _issued != _boundary_issued_records
		or _models != _boundary_model_records
		or bodies != _boundary_bodies
		or owned_models != _boundary_owned_models
	):
		return false
	for row: Dictionary in _boundary_nodes:
		var node: Node = row.node
		if (
			not is_instance_valid(node)
			or node.is_queued_for_deletion()
			or node.get_parent() != row.parent
			or node.get_script() != row.script
			or node.name != row.name
			or node.get_children(true) != row.children
			or node.process_mode != row.process_mode
		):
			return false
		if node is Node3D and (node.transform != row.pose or node.top_level != row.top_level):
			return false
	return true


static func _freeze_comparison(value: Variant) -> void:
	if value is Dictionary:
		for nested: Variant in value.values():
			_freeze_comparison(nested)
		value.make_read_only()
	elif value is Array:
		for nested: Variant in value:
			_freeze_comparison(nested)
		value.make_read_only()


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	bind_issued_ball(ball, resolver)


func bind_issued_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	if (
		not _boundary_issued_ever
		or not _boundary_issued_live
		or not is_instance_valid(ball)
		or ball.is_queued_for_deletion()
		or resolver == null
		or resolver.state == null
		or resolver.state.dead
		or not deep_intact()
		or not (_property as StadiumWaterfallAnimationProperty).deep_props_intact()
	):
		return false
	var previous_serial: int = _next_flight
	super.bind_ball(ball, resolver)
	var flight: Dictionary = _flights.get(resolver.get_instance_id(), {})
	return (
		_live
		and _boundary_issued_live
		and not flight.is_empty()
		and _next_flight == previous_serial + 1
		and int(flight.serial) == _next_flight
		and flight.ball.get_ref() == ball
		and flight.resolver == resolver
		and flight.state == resolver.state
		and flight.field == resolver.field
		and flight.parent == ball.get_parent()
		and flight.previous == ball.global_position
		and ball.physics_contact_router == _contact_batch.bind(resolver)
	)
