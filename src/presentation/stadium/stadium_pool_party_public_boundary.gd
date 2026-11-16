class_name StadiumPoolPartyPublicBoundary
extends Node3D
## GRAND-I public contact seam over the unchanged retained straight construction.
## Same retained Club batching, ordering and cleanup; only source/sweep types differ.
## Never builds geometry, adopts a private fixture or changes a retained copy.

signal contact_applied(event: Dictionary, resolver: BallPlayResolver)

const QUERY_MASK: int = StadiumPoolPartyPublicBoundarySource.QUERY_MASK
var source: StadiumPoolPartyPublicBoundarySource
var graph: StadiumTimberDugoutBoundary
var bodies: Array[StaticBody3D] = []
var items: Array[Node3D] = []
var pool_model: Node3D
var pool_bodies: Array[StaticBody3D] = []
var pool_query_exclusions: Dictionary = {}
var water_commits: Array[Dictionary] = []
var generation: int = 0
var last_live: Dictionary = {}
var _committing: bool = false
var _solid_frame: int = -1
var _water_witness: Dictionary = {}
var _previous: Dictionary = {}
var _resolver_ids: Dictionary = {}
var _bound_balls: Dictionary = {}


func configure(retained: StadiumPoolPartyPublicBoundarySource) -> bool:
	if is_instance_valid(source) or not is_instance_valid(retained) or retained.graph == null \
		or retained.bodies.is_empty():
		return false
	source = retained
	graph = retained.graph
	bodies = retained.bodies
	items = retained.items
	pool_model = retained.get_parent().pool_model
	if not is_instance_valid(pool_model):
		return false
	for body: StaticBody3D in pool_model.get_node("Collision").get_children():
		pool_bodies.append(body)
	return not pool_bodies.is_empty()


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
	_capture_pool_query_exclusions()
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


func _capture_pool_query_exclusions() -> void:
	# One cold bind traversal; each hot query uses the issued native collider RID list.
	pool_query_exclusions.clear()
	var property: StadiumNpcPublicProperty = get_parent() as StadiumNpcPublicProperty
	var lab: PitchBatLab = property.lab_ref.get_ref() as PitchBatLab if property != null \
		and property.lab_ref != null else null
	if lab == null:
		return
	var colliders: Array[Node] = lab.find_children("*", "CollisionObject3D", true, false)
	for body: StaticBody3D in pool_bodies:
		var excluded: Array[RID] = []
		for other: CollisionObject3D in colliders:
			if other != body:
				excluded.append(other.get_rid())
		pool_query_exclusions[body.get_instance_id()] = excluded


func include_collider(collider: CollisionObject3D) -> void:
	# Event-only update for ordinary new ball/actor colliders outside the retained property.
	for body: StaticBody3D in pool_bodies:
		if collider == body or not pool_query_exclusions.has(body.get_instance_id()):
			continue
		var excluded: Array[RID] = pool_query_exclusions[body.get_instance_id()]
		if not excluded.has(collider.get_rid()):
			excluded.append(collider.get_rid())


func _seed(point: Vector3, id: int) -> void:
	generation += 1
	_previous[id] = point
	last_live.erase(_resolver_ids.get(id, -1))


func _forget(id: int, resolver_id: int) -> void:
	_bound_balls.erase(id)
	_previous.erase(id)
	_resolver_ids.erase(id)
	last_live.erase(resolver_id)


func _contact_batch(ball: BattedBallBody, batch: Array[Dictionary],
	resolver: BallPlayResolver) -> void:
	if resolver == null or resolver.state == null or resolver.state.dead \
		or actual_ball(resolver) != ball:
		return
	var id: int = ball.get_instance_id()
	var current: Vector3 = ball.global_position
	var from: Vector3 = _previous.get(id, current)
	_previous[id] = current
	var contacts: Array[Dictionary] = []
	for contact: Dictionary in batch:
		var body: StaticBody3D = contact.body as StaticBody3D
		if body != null and pool_bodies.has(body):
			contacts.append(StadiumPoolPartyPublicSweep.pool_contact_event(body, contact.position, 1))
		elif body != null and bodies.has(body):
			contacts.append(StadiumTimberDugoutBoundary.contact_event(body, contact.position, 1))
	# A manifold solid has already happened; never award water from an uncertain same-step chord.
	if not contacts.is_empty():
		_solid_frame = Engine.get_physics_frames()
		contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.priority > b.priority if a.priority != b.priority else a.segment < b.segment)
		StadiumPoolPartyPublicSweep.apply(self, resolver, contacts[0])
		return
	var selected: Dictionary = StadiumPoolPartyPublicSweep.observe(self, resolver, from, current)
	if not selected.is_empty() or resolver.state.dead:
		return
	for contact: Dictionary in batch:
		if contact.body.get_meta("ball_surface", "") == "ground" \
			and get_parent().is_ancestor_of(contact.body) and not resolver.state.has_grounded:
			resolver.record_ground_contact(contact.position)


func actual_ball(resolver: BallPlayResolver) -> BattedBallBody:
	var property: StadiumNpcPublicProperty = get_parent() as StadiumNpcPublicProperty
	var lab: PitchBatLab = property.lab_ref.get_ref() as PitchBatLab if property != null \
		and property.lab_ref != null else null
	if lab == null or resolver != lab._ball_play_resolver or not property.callback_intact():
		return null
	var ball: BattedBallBody = lab._batted_ball
	if not is_instance_valid(ball) or not property._ball_owned(ball, resolver):
		return null
	return ball


func resolve_water(resolver: BallPlayResolver, event: Dictionary) -> bool:
	var property: StadiumNpcPublicProperty = get_parent() as StadiumNpcPublicProperty
	if property == null or not property._contact_dispatch or _water_witness != event \
		or event.is_empty():
		return false
	_water_witness.clear()
	if _committing or _solid_frame == Engine.get_physics_frames() or actual_ball(resolver) == null \
		or resolver.state == null or resolver.state.dead \
		or resolver.state.has_grounded or resolver.state.defender_touched \
		or resolver.state.bobbled or resolver.state.caught \
		or not resolver.state.stadium_contacts.is_empty() \
		or resolver.state.result_floor > BallPlayState.ResultFloor.DOUBLE:
		return false
	var lab: PitchBatLab = property.lab_ref.get_ref() as PitchBatLab
	var expected: BallPlayState = resolver.state
	var foul: bool = expected.is_foul_play
	var row: Dictionary = {"generation": generation,
		"position": [event.position.x, event.position.y, event.position.z],
		"foul": foul, "entry_fraction": event.fraction, "play_sequence": lab._play_records.size()}
	_committing = true
	# Commit receipt is staged before synchronous ordinary resolution callbacks capture a report.
	water_commits.append(row)
	var committed: bool = resolver.resolve_pool_party_water(expected, event.position, foul)
	if not committed:
		water_commits.pop_back()
	_committing = false
	return committed


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
