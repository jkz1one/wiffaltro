class_name StadiumHillsidePublicContactAdapter
extends Node3D
## Exact Hillside delegate. The public property alone installs, clips and routes contacts.
## Finite-sphere native witnesses reuse timber front arithmetic without widening its API.
# gdlint: disable=max-returns

signal contact_applied(event: Dictionary, resolver: BallPlayResolver)

const QUERY_MASK: int = StadiumHillsidePublicBoundarySource.QUERY_MASK
var source: StadiumHillsidePublicBoundarySource
var construction: StadiumHillsidePublicConstruction
var graph: StadiumHillsidePublicBoundary
var bodies: Array[StaticBody3D] = []
var items: Array[Node3D] = []
var last_live: Dictionary = {}
var _bound_balls: Dictionary = {}
var _resolver_ids: Dictionary = {}
var _previous: Dictionary = {}
var _bindings: Dictionary = {}
var _owner: StadiumNpcPublicProperty
var _lab: PitchBatLab
var _members: Array[Dictionary] = []
var _witness: Dictionary = {}
var _dispatching: bool = false


func configure(retained: Variant) -> bool:
	if (
		source != null
		or typeof(retained) != TYPE_OBJECT
		or not is_instance_valid(retained)
		or not retained is StadiumHillsidePublicBoundarySource
		or retained.get_script() != StadiumHillsidePublicBoundarySource
		or not retained.get_parent() is StadiumHillsidePublicConstruction
		or not is_instance_valid(retained.graph)
		or retained.graph.get_script() != StadiumHillsidePublicBoundary
		or retained.bodies.size() != 10
		or retained.member_bodies.size() <= 10
	):
		return false
	source = retained
	construction = retained.get_parent()
	graph = retained.graph
	for body: Variant in retained.member_bodies:
		if (
			typeof(body) != TYPE_OBJECT
			or not is_instance_valid(body)
			or not body is StaticBody3D
			or not construction.is_ancestor_of(body)
			or not StadiumTimberDugoutBoundary._tagged(body)
		):
			return false
		_members.append(
			{
				"body": body,
				"parent": body.get_parent(),
				"pose": body.transform,
				"layer": body.collision_layer,
				"mask": body.collision_mask,
				"segment": body.get_meta("club_surface"),
				"role": body.get_meta("surface_role"),
				"priority": body.get_meta("surface_priority"),
				"kind": body.get_meta("surface_kind"),
				"copy": body.get_meta("npc_instance", ""),
				"surface": body.get_meta("surface_id", "")
			}
		)
	bodies.assign(retained.member_bodies)
	items.assign(retained.items)
	graph.contact_adapter = weakref(self)
	return true


func bind_public_property(value: Variant) -> bool:
	if (
		_owner != null
		or typeof(value) != TYPE_OBJECT
		or not is_instance_valid(value)
		or not value is StadiumNpcPublicProperty
		or value.get_script() != StadiumNpcPublicProperty
		or not is_instance_valid(construction)
		or not is_instance_valid(source)
		or not is_instance_valid(graph)
		or value.venue_id != "HILLSIDE"
		or value.construction != construction
		or get_parent() != value
		or value.boundary != self
	):
		return false
	_owner = value
	_lab = value.lab_ref.get_ref() as PitchBatLab if value.lab_ref != null else null
	return construction.qualify_contacts(self)


func dynamic_intact() -> bool:
	# Fixed captured identities only. No source hashes, fresh geometry or tree traversal.
	if (
		not is_instance_valid(_owner)
		or not is_instance_valid(construction)
		or not is_instance_valid(graph)
		or _owner.get_script() != StadiumNpcPublicProperty
		or _owner.boundary != self
		or _owner.construction != construction
		or get_parent() != _owner
		or not is_instance_valid(source)
		or source.get_parent() != construction
		or source.get_script() != StadiumHillsidePublicBoundarySource
		or source != construction.boundary
		or graph != source.graph
		or graph.get_script() != StadiumHillsidePublicBoundary
		or graph._shape != "deeper_center"
		or construction.transform != Transform3D.IDENTITY
		or source.transform != Transform3D.IDENTITY
		or _owner.transform != Transform3D.IDENTITY
		or graph.contact_adapter == null
		or graph.contact_adapter.get_ref() != self
		or bodies != source.member_bodies
		or items != source.items
		or bodies.size() != _members.size()
	):
		return false
	for index in range(_members.size()):
		var row: Dictionary = _members[index]
		var body: Variant = row.body
		if (
			typeof(body) != TYPE_OBJECT
			or not is_instance_valid(body)
			or not body is StaticBody3D
			or body != bodies[index]
			or body.is_queued_for_deletion()
			or body.get_parent() != row.parent
			or body.transform != row.pose
			or body.collision_mask != row.mask
			or body.collision_layer != row.layer
			or body.get_meta("club_surface", "") != row.segment
			or body.get_meta("surface_role", "") != row.role
			or body.get_meta("surface_priority", -1) != row.priority
			or body.get_meta("surface_kind", "") != row.kind
			or body.get_meta("npc_instance", "") != row.copy
			or body.get_meta("surface_id", "") != row.surface
		):
			return false
	return true


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	if _lab == null and is_instance_valid(_owner) and _owner.lab_ref != null:
		_lab = _owner.lab_ref.get_ref() as PitchBatLab
	if (
		not dynamic_intact()
		or not is_instance_valid(_lab)
		or not is_instance_valid(ball)
		or not is_instance_valid(resolver)
		or not is_instance_valid(resolver.state)
		or resolver.state.get_script() != BallPlayState
		or ball.get_script() != BattedBallBody
		or ball.get_parent() != _lab
		or _lab._batted_ball != ball
		or _lab._ball_play_resolver != resolver
	):
		return false
	if binding_intact(ball, resolver, resolver.state):
		return true
	_disconnect_ball(ball)
	if not _bindings.is_empty():
		return false
	# One exact ball sphere is captured at bind; later checks use only these identities.
	var radius: float = StadiumTimberDugoutBoundary.ball_radius(ball)
	if radius <= 0:
		return false
	var collider: CollisionShape3D = ball.find_children("*", "CollisionShape3D", true, false)[0]
	var id: int = ball.get_instance_id()
	_bound_balls[id] = weakref(ball)
	_resolver_ids[id] = resolver.get_instance_id()
	_bindings[id] = {
		"resolver": resolver,
		"state": resolver.state,
		"shape_node": collider,
		"shape": collider.shape,
		"radius": radius,
		"aero_radius": ball.radius_m,
		"frame": -1,
		"batch": []
	}
	ball.launch_started.connect(_seed.bind(id))
	ball.tree_exited.connect(_forget.bind(id, resolver.get_instance_id()), CONNECT_ONE_SHOT)
	_seed(ball.global_position, id)
	return true


func binding_intact(ball: BattedBallBody, resolver: BallPlayResolver, state: BallPlayState) -> bool:
	if (
		not dynamic_intact()
		or not is_instance_valid(ball)
		or not is_instance_valid(resolver)
		or not is_instance_valid(state)
		or state.get_script() != BallPlayState
		or resolver.get_script() != BallPlayResolver
		or resolver.state != state
		or resolver.field != _owner.field
		or not is_instance_valid(_lab)
		or _owner.lab_ref == null
		or _owner.lab_ref.get_ref() != _lab
		or _lab._batted_ball != ball
		or _lab._ball_play_resolver != resolver
		or ball.get_parent() != _lab
		or ball.get_script() != BattedBallBody
	):
		return false
	var id: int = ball.get_instance_id()
	if (
		not _bound_balls.has(id)
		or _bound_balls[id].get_ref() != ball
		or _resolver_ids.get(id) != resolver.get_instance_id()
		or not _bindings.has(id)
	):
		return false
	var bound: Dictionary = _bindings[id]
	var shape_node: Variant = bound.shape_node
	return (
		bound.resolver == resolver
		and bound.state == state
		and typeof(shape_node) == TYPE_OBJECT
		and is_instance_valid(shape_node)
		and shape_node is CollisionShape3D
		and shape_node.get_parent() == ball
		and shape_node.transform == Transform3D.IDENTITY
		and not shape_node.disabled
		and shape_node.shape == bound.shape
		and bound.shape is SphereShape3D
		and bound.shape.radius == bound.radius
		and ball.radius_m == bound.aero_radius
		and StadiumPoolPartyAssetIntegrity.rigid(ball.global_transform)
		and ball.launch_started.is_connected(_seed.bind(id))
		and ball.tree_exited.is_connected(_forget.bind(id, resolver.get_instance_id()))
	)


func _seed(point: Vector3, id: int) -> void:
	if not _bindings.has(id) or not point.is_finite():
		return
	var ball: BattedBallBody = _bound_balls[id].get_ref() as BattedBallBody
	var bound: Dictionary = _bindings[id]
	if (
		ball == null
		or not binding_intact(ball, bound.resolver, bound.state)
		or point != ball.global_position
	):
		return
	_previous[id] = point
	bound.frame = -1
	bound.batch = []
	last_live.erase(_resolver_ids[id])


func _forget(id: int, resolver_id: int) -> void:
	_bound_balls.erase(id)
	_resolver_ids.erase(id)
	_previous.erase(id)
	_bindings.erase(id)
	last_live.erase(resolver_id)
	_witness.clear()


func forget(ball: BattedBallBody) -> void:
	if is_instance_valid(ball):
		_forget(ball.get_instance_id(), _resolver_ids.get(ball.get_instance_id(), -1))


func _disconnect_ball(ball: BattedBallBody) -> void:
	if not is_instance_valid(ball):
		return
	# Never own, replace or clear the property's router.
	for connection: Dictionary in ball.launch_started.get_connections():
		if connection.callable.get_object() == self:
			ball.launch_started.disconnect(connection.callable)
	for connection: Dictionary in ball.tree_exited.get_connections():
		if connection.callable.get_object() == self:
			ball.tree_exited.disconnect(connection.callable)
	forget(ball)


func disconnect_ball(ball: BattedBallBody) -> void:
	_disconnect_ball(ball)


func actual_ball(resolver: BallPlayResolver) -> BattedBallBody:
	if (
		not is_instance_valid(_lab)
		or not is_instance_valid(resolver)
		or not is_instance_valid(resolver.state)
	):
		return null
	var ball: BattedBallBody = _lab._batted_ball
	return ball if binding_intact(ball, resolver, resolver.state) else null


func native_batch(
	ball: BattedBallBody, batch: Array[Dictionary], resolver: BallPlayResolver
) -> void:
	_contact_batch(ball, batch, resolver)


func _contact_batch(
	ball: BattedBallBody, batch: Array[Dictionary], resolver: BallPlayResolver
) -> void:
	# Property verifies the actual native manifold and dispatches real terrain ground first.
	if _dispatching or not _owner_dispatch(ball, resolver):
		return
	var bound: Dictionary = _bindings[ball.get_instance_id()]
	var frame: int = Engine.get_physics_frames()
	if bound.frame == frame and bound.batch == batch:
		return
	bound.frame = frame
	bound.batch = batch.duplicate()
	var current: Vector3 = ball.global_position
	var previous: Vector3 = _previous.get(ball.get_instance_id(), current)
	_previous[ball.get_instance_id()] = current
	var contacts: Array[Dictionary] = []
	for contact: Dictionary in batch:
		var body: StaticBody3D = contact.get("body") as StaticBody3D
		if body != null and bodies.has(body) and contact.get("position") is Vector3:
			var hit: Dictionary = _contact_event(body, contact.position, 1.0)
			if not hit.is_empty():
				contacts.append(hit)
	if not contacts.is_empty():
		contacts.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return (
					a.priority > b.priority if a.priority != b.priority else a.segment < b.segment
				)
		)
		_apply(resolver, contacts[0])
		return
	_observe_owned(ball, resolver, previous, current)


func observe(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> Dictionary:
	var ball: BattedBallBody = actual_ball(resolver)
	if (
		not _owner_dispatch(ball, resolver)
		or current != ball.global_position
		or previous != _lab._previous_batted_position
	):
		return {}
	_previous[ball.get_instance_id()] = current
	return _observe_owned(ball, resolver, previous, current)


func _owner_dispatch(ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	return (
		is_instance_valid(_owner)
		and _owner._contact_dispatch
		and not _owner.suspended
		and is_instance_valid(resolver)
		and is_instance_valid(resolver.state)
		and not resolver.state.dead
		and binding_intact(ball, resolver, resolver.state)
		and _owner.callback_intact()
	)


func _observe_owned(
	ball: BattedBallBody, resolver: BallPlayResolver, previous: Vector3, current: Vector3
) -> Dictionary:
	var selected: Dictionary = _event(previous, current, _bindings[ball.get_instance_id()].radius)
	if not _owner_dispatch(ball, resolver):
		return {}
	if not resolver.state.is_foul_play:
		StadiumBoundaryObserver._bands(
			resolver, previous, current if selected.is_empty() else selected.position
		)
	if selected.is_empty():
		last_live.erase(resolver.get_instance_id())
	else:
		_apply(resolver, selected)
	return selected


func _event(previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	if (
		not dynamic_intact()
		or not is_inside_tree()
		or construction.global_transform != Transform3D.IDENTITY
		or not previous.is_finite()
		or not current.is_finite()
		or not is_finite(radius)
		or radius <= 0
	):
		return {}
	var candidates: Array[Dictionary] = []
	var crossing: Dictionary = graph.crossing(previous, current)
	# A graph line cannot prove timber contact; only actual sphere/native front witnesses can.
	if not crossing.is_empty() and crossing.role != "DUGOUT_FACE_LIVE":
		crossing["kind"] = "boundary"
		candidates.append(crossing)
	for body: StaticBody3D in bodies:
		var hit: Dictionary = _sphere_contact(body, previous, current, radius)
		if not hit.is_empty():
			candidates.append(hit)
	var distance: float = previous.distance_to(current)
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return StadiumTimberDugoutBoundary.precedes(a, b, distance)
	)
	return {} if candidates.is_empty() else candidates[0]


func _sphere_contact(
	body: StaticBody3D, previous: Vector3, current: Vector3, radius: float
) -> Dictionary:
	if not body.is_inside_tree() or not construction.is_ancestor_of(body):
		return {}
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
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if body.get_meta("surface_role") == "DUGOUT_FACE_LIVE":
		var front: Dictionary = StadiumTimberDugoutBoundary._front_contact(
			space, query, body, previous, current, radius
		)
		return {} if front.is_empty() else _contact_event(body, front.position, front.fraction)
	var overlaps: Array[Dictionary] = space.intersect_shape(query, 1)
	if not overlaps.is_empty():
		if overlaps[0].get("collider") != body or overlaps[0].get("rid") != body.get_rid():
			return {}
		var resting: Dictionary = space.get_rest_info(query)
		if (
			resting.is_empty()
			or resting.get("collider_id", 0) != body.get_instance_id()
			or resting.get("rid") != body.get_rid()
			or not resting.get("point") is Vector3
		):
			return {}
		return _contact_event(body, resting.point, 0.0)
	query.motion = current - previous
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() != 2 or fractions[0] >= 1:
		return {}
	var advance: float = (
		StadiumTimberDugoutBoundary.CONTACT_EPS_M
		/ maxf(previous.distance_to(current), StadiumTimberDugoutBoundary.CONTACT_EPS_M)
	)
	query.transform.origin = previous.lerp(current, minf(1, fractions[1] + advance))
	query.motion = Vector3.ZERO
	var witness: Dictionary = space.get_rest_info(query)
	if (
		witness.is_empty()
		or witness.get("collider_id", 0) != body.get_instance_id()
		or witness.get("rid") != body.get_rid()
		or not witness.get("point") is Vector3
	):
		return {}
	return _contact_event(body, witness.point, fractions[0])


func _contact_event(body: StaticBody3D, at: Vector3, fraction: float) -> Dictionary:
	if (
		not bodies.has(body)
		or not at.is_finite()
		or not is_finite(fraction)
		or fraction < 0
		or fraction > 1
	):
		return {}
	var result: Dictionary = StadiumTimberDugoutBoundary.contact_event(body, at, fraction)
	if result.is_empty():
		return {}
	# The pole cap is relative to its actual elevated model origin, never world Y.
	if result.kind == "pole":
		var model: Node3D = body.get_parent().get_parent()
		var local_height: float = (model.global_transform.affine_inverse() * at).y
		result.role = StadiumFoulPoleModels.role_at(
			clampf(local_height, 0, StadiumFoulPoleSites.HEIGHT), body.get_meta("wall_cap_height")
		)
	result["body_id"] = body.get_instance_id()
	return result


func _apply(resolver: BallPlayResolver, event: Dictionary) -> void:
	var ball: BattedBallBody = actual_ball(resolver)
	if _dispatching or not _owner_dispatch(ball, resolver) or event.is_empty():
		return
	var state: BallPlayState = resolver.state
	var id: int = resolver.get_instance_id()
	if event.role in ["DUGOUT_FACE_LIVE", "SIDE_RETURN_LIVE"]:
		if last_live.get(id, "") == event.segment:
			return
		last_live[id] = event.segment
	else:
		last_live.erase(id)
	_dispatching = true
	contact_applied.emit(event, resolver)
	if not _owner_dispatch(ball, resolver) or resolver.state != state:
		_dispatching = false
		return
	if event.kind == "boundary" or event.role == "DUGOUT_FACE_LIVE":
		_witness = event.duplicate(true)
		graph.apply(resolver, event)
		_witness.clear()
	else:
		state.record_stadium_contact(
			"boundary", graph.identity(), event.segment, event.role, event.position, "contact"
		)
		if event.kind == "pole":
			state.is_foul_play = false
			state.is_fair = true
			if (
				event.role == "FOUL_POLE_UPPER"
				and not state.has_grounded
				and not state.defender_touched
			):
				state.raise_result_floor(BallPlayState.ResultFloor.HOME_RUN)
				resolver._resolve_floor(&"foul_pole_upper", event.position)
			else:
				resolver.record_back_wall_contact(event.position)
		elif event.kind == "receiver":
			resolver._resolve_foul(&"stadium_receiver", event.position)
	_dispatching = false


func consume_witness(resolver: BallPlayResolver, event: Dictionary) -> bool:
	if (
		not _dispatching
		or _witness.is_empty()
		or event != _witness
		or not _owner_dispatch(actual_ball(resolver), resolver)
	):
		return false
	_witness.clear()
	return true


func _exit_tree() -> void:
	for reference: WeakRef in _bound_balls.values().duplicate():
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if is_instance_valid(ball):
			_disconnect_ball(ball)
	_bound_balls.clear()
	_resolver_ids.clear()
	_previous.clear()
	_bindings.clear()
	last_live.clear()
	_witness.clear()
