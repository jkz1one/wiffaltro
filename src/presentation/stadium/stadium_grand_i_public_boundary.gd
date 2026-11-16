class_name StadiumGrandIPublicBoundary
extends Node3D
## GRAND-I public contact seam over the unchanged retained straight construction.
## Same retained Club batching, ordering and cleanup; only source/sweep types differ.
## Never builds geometry, adopts a private fixture or changes a retained copy.

signal contact_applied(event: Dictionary, resolver: BallPlayResolver)

const QUERY_MASK: int = StadiumGrandIPublicBoundarySource.QUERY_MASK
var source: StadiumGrandIPublicBoundarySource
var graph: StadiumDugoutBoundary
var bodies: Array[StaticBody3D] = []
var items: Array[Node3D] = []
var last_live: Dictionary = {}
var _previous: Dictionary = {}
var _resolver_ids: Dictionary = {}
var _bound_balls: Dictionary = {}


func configure(retained: StadiumGrandIPublicBoundarySource) -> bool:
	if is_instance_valid(source) or not is_instance_valid(retained) or retained.graph == null \
		or retained.bodies.is_empty():
		return false
	source = retained
	graph = retained.graph
	bodies = retained.bodies
	items = retained.items
	return true


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	if not is_instance_valid(source) or ball == null or resolver == null:
		return
	var callback: Callable = _contact_batch.bind(resolver)
	if ball.physics_contact_router == callback \
		and ball.launch_started.is_connected(_seed.bind(ball.get_instance_id())) \
		and ball.tree_exited.is_connected(_forget.bind(
			ball.get_instance_id(), resolver.get_instance_id())) \
		and _resolver_ids.get(ball.get_instance_id()) == resolver.get_instance_id() \
		and _bound_balls.has(ball.get_instance_id()) \
		and _bound_balls[ball.get_instance_id()].get_ref() == ball:
		return
	_disconnect_ball(ball)
	ball.physics_contact_router = callback
	_bound_balls[ball.get_instance_id()] = weakref(ball)
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
	_bound_balls.erase(id)
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
	var selected: Dictionary = StadiumGrandIPublicSweep.observe(self, resolver, from, current)
	if not selected.is_empty() or resolver.state.dead:
		return
	var contacts: Array[Dictionary] = []
	for contact: Dictionary in batch:
		var body: StaticBody3D = contact.body as StaticBody3D
		if body != null and bodies.has(body):
			contacts.append(StadiumGrandIPublicSweep.contact_event(body, contact.position, 1))
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.priority > b.priority if a.priority != b.priority else a.segment < b.segment)
	if not contacts.is_empty():
		if contacts[0].role in ["DUGOUT_FACE_LIVE", "SIDE_RETURN_LIVE"] \
			and contacts[0].segment == prior_live:
			last_live[resolver.get_instance_id()] = prior_live
		StadiumGrandIPublicSweep.apply(self, resolver, contacts[0])


func _disconnect_ball(ball: BattedBallBody) -> void:
	if ball.physics_contact_router.get_object() == self:
		ball.physics_contact_router = Callable()
	for connection: Dictionary in ball.launch_started.get_connections():
		if connection.callable.get_object() == self:
			ball.launch_started.disconnect(connection.callable)
	for connection: Dictionary in ball.tree_exited.get_connections():
		if connection.callable.get_object() == self:
			ball.tree_exited.disconnect(connection.callable)


func _exit_tree() -> void:
	for reference: WeakRef in _bound_balls.values():
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if is_instance_valid(ball):
			_disconnect_ball(ball)
	_bound_balls.clear()
	_previous.clear()
	_resolver_ids.clear()
	last_live.clear()
