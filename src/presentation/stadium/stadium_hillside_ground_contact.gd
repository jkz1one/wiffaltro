class_name StadiumHillsideGroundContact
extends Node
## Private admission of actual retained-terrain contacts to ordinary ground rules.
## This adapter never changes ball physics or infers ground from sampled height.

const NODE_NAME: StringName = &"HillsideGroundContact"

var blocked: bool = true
var last_error: String = "Explicit installation is required."
var _public_owner: StadiumNpcPublicProperty
var _lab: PitchBatLab
var _field: FieldDefinition
var _terrain: Node3D
var _body: StaticBody3D
var _shape_node: CollisionShape3D
var _shape: ConcavePolygonShape3D
var _profile: String
var _signature: String
var _ball: BattedBallBody
var _resolver: BallPlayResolver
var _state: BallPlayState
var _saved_router: Callable
var _wrapped_router: Callable
var _body_callback: Callable
var _exit_callback: Callable
var _resolved_callback: Callable


func install(lab: PitchBatLab, terrain: Node3D, profile: String) -> bool:
	if (
		get_parent() != null
		or get_script() != StadiumHillsideGroundContact
		or not is_instance_valid(lab)
		or not lab.is_inside_tree()
		or lab.get_node_or_null(NodePath(NODE_NAME)) != null
		or lab._field_definition == null
		or is_instance_valid(lab._batted_ball)
		or (lab._pitch_actor != null and lab._pitch_actor.running)
		or (lab._release_controller != null and lab._release_controller.active)
		or (
			lab._at_bat_cadence != null
			and lab._at_bat_cadence.state != AtBatCadenceController.State.IDLE
		)
		or not is_instance_valid(terrain)
		or not StadiumHillsideTerrain.PROFILES.has(profile)
	):
		return _refuse("An idle private lab and retained terrain/profile are required.")
	_lab = lab
	_field = lab._field_definition
	_terrain = terrain
	_profile = profile
	_signature = StadiumHillsideTerrain.signature(profile)
	_body = terrain.get_node_or_null("TerrainCollision") as StaticBody3D
	_shape_node = (
		terrain.get_node_or_null("TerrainCollision/ClosedTerrainShape") as CollisionShape3D
	)
	_shape = _shape_node.shape as ConcavePolygonShape3D if _shape_node != null else null
	if (
		not _private_context()
		or not _terrain_valid()
		or _shape.get_faces() != StadiumHillsideTerrainModels.geometry(profile).faces
	):
		return _refuse("The exact retained terrain geometry and private context must match.")
	name = NODE_NAME
	lab.add_child(self)
	if not _installed_valid():
		if get_parent() == lab:
			lab.remove_child(self)
		return _refuse("The explicit lab-child installation changed during attachment.")
	# Cold geometry equality above; mutation/removal invalidates instead of rescanning each contact.
	_shape.changed.connect(_invalidate_terrain)
	_terrain.tree_exiting.connect(_invalidate_terrain)
	_body.tree_exiting.connect(_invalidate_terrain)
	_shape_node.tree_exiting.connect(_invalidate_terrain)
	blocked = false
	last_error = ""
	return true


func bind_ball(lab: PitchBatLab, ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	if _ball == ball and _resolver == resolver and resolver != null and _state == resolver.state:
		if _binding_valid(ball, _state) and _terrain_valid():
			return true
		clear_binding()
		return _refuse("The current play or its router changed; it was not wrapped again.")
	clear_binding()
	if (
		blocked
		or lab != _lab
		or not _installed_valid()
		or not _terrain_valid()
		or resolver == null
		or resolver.state == null
		or resolver.state.dead
		or not _play_current(ball, resolver, resolver.state)
		or not _known_router(ball.physics_contact_router, resolver)
	):
		return _refuse("The actual live ball, resolver/state and ordinary router must match.")
	_ball = ball
	_resolver = resolver
	_state = resolver.state
	_saved_router = ball.physics_contact_router
	_body_callback = _on_body_entered.bind(ball, _state)
	_exit_callback = _on_ball_exiting.bind(ball, _state)
	_resolved_callback = _on_play_resolved.bind(_state)
	ball.body_entered.connect(_body_callback)
	ball.tree_exiting.connect(_exit_callback)
	resolver.play_resolved.connect(_resolved_callback)
	if _saved_router.is_valid():
		_wrapped_router = _contact_batch.bind(_state)
		ball.physics_contact_router = _wrapped_router
	last_error = ""
	return true


func clear_binding() -> void:
	if is_instance_valid(_ball):
		if _body_callback.is_valid() and _ball.body_entered.is_connected(_body_callback):
			_ball.body_entered.disconnect(_body_callback)
		if _exit_callback.is_valid() and _ball.tree_exiting.is_connected(_exit_callback):
			_ball.tree_exiting.disconnect(_exit_callback)
		if _wrapped_router.is_valid() and _ball.physics_contact_router == _wrapped_router:
			_ball.physics_contact_router = _saved_router
	if (
		_resolver != null
		and _resolved_callback.is_valid()
		and _resolver.play_resolved.is_connected(_resolved_callback)
	):
		_resolver.play_resolved.disconnect(_resolved_callback)
	_ball = null
	_resolver = null
	_state = null
	_saved_router = Callable()
	_wrapped_router = Callable()
	_body_callback = Callable()
	_exit_callback = Callable()
	_resolved_callback = Callable()


func _on_body_entered(body: Node, source_ball: BattedBallBody, source_state: BallPlayState) -> void:
	if source_ball != _ball or source_state != _state:
		return
	if not _binding_valid(source_ball, source_state) or not _terrain_valid():
		clear_binding()
		return
	if body == _body and source_ball._started:
		_report_ground(source_ball.global_position)


func _contact_batch(
	ball: BattedBallBody, batch: Array[Dictionary], source_state: BallPlayState
) -> void:
	if ball != _ball or source_state != _state or not _wrapped_router.is_valid():
		return
	if not _binding_valid(ball, source_state) or not ball._started:
		clear_binding()
		return
	var original: Callable = _saved_router
	var wrapper: Callable = _wrapped_router
	var resolver: BallPlayResolver = _resolver
	if _terrain_valid():
		for contact: Dictionary in batch:
			if contact.get("body") == _body and contact.get("position") is Vector3:
				_report_ground(contact["position"])
				break
	else:
		clear_binding()
	# Preserve the ordinary ground-first policy and the same full, unmodified batch.
	# Ground may resolve foul play and clear our binding. Never call into a replacement play/router.
	if (
		original.is_valid()
		and _play_current(ball, resolver, source_state)
		and ball.physics_contact_router in [wrapper, original]
	):
		original.call(ball, batch)


func _report_ground(position_value: Vector3) -> void:
	if _state == null or _state.dead or _state.has_grounded or not position_value.is_finite():
		return
	# The required ordinary lab listener records the first-ground note and resolver latch once.
	_ball.surface_contact.emit(&"ground", position_value)


func _binding_valid(ball: BattedBallBody, state: BallPlayState) -> bool:
	if _public_owner != null:
		return public_binding_intact(ball, state) and not state.dead
	return (
		not blocked
		and _installed_valid()
		and state != null
		and not state.dead
		and _play_current(ball, _resolver, state)
		and _known_router(_saved_router, _resolver)
		and (
			ball.physics_contact_router
			== (_wrapped_router if _wrapped_router.is_valid() else _saved_router)
		)
	)


func _play_current(ball: BattedBallBody, resolver: BallPlayResolver, state: BallPlayState) -> bool:
	return (
		is_instance_valid(_lab)
		and not _lab.is_queued_for_deletion()
		and _lab.is_inside_tree()
		and _lab._field_definition == _field
		and (
			_public_owner.hillside_owner_intact()
			if is_instance_valid(_public_owner)
			else (_public_owner == null and _lab._private_hillside_admits())
		)
		and is_instance_valid(ball)
		and not ball.is_queued_for_deletion()
		and ball.is_inside_tree()
		and ball.get_parent() == _lab
		and ball.get_script() == BattedBallBody
		and _lab._batted_ball == ball
		and _lab._ball_play_resolver == resolver
		and resolver != null
		and state != null
		and resolver.state == state
		and resolver.field == _field
		and ball.get_world_3d() == _lab.get_world_3d()
		and ball.surface_contact.is_connected(_lab._on_batted_surface_contact)
	)


func _known_router(router: Callable, resolver: BallPlayResolver) -> bool:
	if router.is_null():
		return true
	if not router.is_valid() or not router.get_object() is StadiumRecipeBoundaryBody:
		return false
	var boundary: StadiumRecipeBoundaryBody = router.get_object() as StadiumRecipeBoundaryBody
	return (
		(
			boundary.get_script()
			in [StadiumRecipeBoundaryBody, StadiumHeightBoundaryBody, StadiumHillsideBoundaryBody]
		)
		and boundary.is_inside_tree()
		and not boundary.is_queued_for_deletion()
		and _lab.is_ancestor_of(boundary)
		and boundary.get_world_3d() == _lab.get_world_3d()
		and router == Callable(boundary, "_contact_batch").bind(resolver)
	)


func _private_context() -> bool:
	return (
		is_instance_valid(_lab)
		and not _lab._managed_match
		and _lab._automation == null
		and _lab._npc_season == null
		and _lab._configured_match == null
		and not _lab.has_meta("stadium_snapshot")
		and not _lab.has_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND)
		and not _lab.has_meta(StadiumNpcYardTwoRuntimeV1.PUBLIC_BOUND)
		and not _lab.has_meta(StadiumNpcYardThreeRuntimeV1.PUBLIC_BOUND)
		and _lab.pool_active_receipt == null
		and _lab.pool_controller_active == null
		and not _lab.pool_bound_startup_failed
		and not _lab.yard_bound_startup_failed
		and (_lab._match_state == null or _lab._match_state.stadium.is_empty())
	)


func _installed_valid() -> bool:
	if _public_owner != null:
		return (
			is_instance_valid(_public_owner)
			and _public_owner.hillside_owner_intact()
			and get_parent() == _public_owner
			and not is_queued_for_deletion()
			and get_script() == StadiumHillsideGroundContact
			and _public_owner.get_node_or_null(NodePath(NODE_NAME)) == self
			and _public_owner.field == _field
			and _public_owner.construction.terrain == _terrain
		)
	return (
		_private_context()
		and not _lab.is_queued_for_deletion()
		and _lab.is_inside_tree()
		and _lab._field_definition == _field
		and get_parent() == _lab
		and not is_queued_for_deletion()
		and get_script() == StadiumHillsideGroundContact
		and _lab.get_node_or_null(NodePath(NODE_NAME)) == self
	)


func _terrain_valid() -> bool:
	if (
		not is_instance_valid(_terrain)
		or _terrain.is_queued_for_deletion()
		or not _terrain.is_inside_tree()
		or _terrain.global_transform != Transform3D.IDENTITY
		or _terrain.get_world_3d() != _lab.get_world_3d()
		or _terrain.get_meta("terrain_profile", "") != _profile
		or _terrain.get_meta("terrain_signature", "") != _signature
		or not is_instance_valid(_body)
		or _body.is_queued_for_deletion()
		or _terrain.get_node_or_null("TerrainCollision") != _body
		or _body.transform != Transform3D.IDENTITY
		or _body.get_meta("ball_surface", "") != StadiumHillsideTerrainModels.SURFACE
		or _body.get_meta("terrain_profile", "") != _profile
	):
		return false
	var required_layer: int = 1 | StadiumHillsideTerrainModels.QUERY_LAYER
	return (
		(_body.collision_layer & required_layer) == required_layer
		and (_body.collision_mask & 2) == 2
		and is_instance_valid(_shape_node)
		and not _shape_node.is_queued_for_deletion()
		and _body.get_node_or_null("ClosedTerrainShape") == _shape_node
		and not _shape_node.disabled
		and _shape_node.transform == Transform3D.IDENTITY
		and _shape != null
		and _shape_node.shape == _shape
		and _shape.margin == 0.0
		and not _shape.backface_collision
	)


func _on_ball_exiting(ball: BattedBallBody, state: BallPlayState) -> void:
	if ball == _ball and state == _state:
		clear_binding()


func _on_play_resolved(_outcome: BallPlayOutcome, state: BallPlayState) -> void:
	if state == _state:
		clear_binding()


func _invalidate_terrain() -> void:
	blocked = true
	last_error = "The retained terrain changed or left the tree; install a fresh explicit adapter."
	clear_binding()


func _refuse(message: String) -> bool:
	last_error = message
	return false


func _exit_tree() -> void:
	clear_binding()
	if _shape != null and _shape.changed.is_connected(_invalidate_terrain):
		_shape.changed.disconnect(_invalidate_terrain)
	if is_instance_valid(_terrain) and _terrain.tree_exiting.is_connected(_invalidate_terrain):
		_terrain.tree_exiting.disconnect(_invalidate_terrain)
	if is_instance_valid(_body) and _body.tree_exiting.is_connected(_invalidate_terrain):
		_body.tree_exiting.disconnect(_invalidate_terrain)
	if (
		is_instance_valid(_shape_node)
		and _shape_node.tree_exiting.is_connected(_invalidate_terrain)
	):
		_shape_node.tree_exiting.disconnect(_invalidate_terrain)
	blocked = true


func install_public(lab: PitchBatLab, owner: StadiumNpcPublicProperty) -> bool:
	if (
		get_parent() != null
		or get_script() != StadiumHillsideGroundContact
		or not is_instance_valid(owner)
		or not owner.hillside_owner_intact()
		or owner.lab_ref.get_ref() != lab
		or owner.get_node_or_null(NodePath(NODE_NAME)) != null
	):
		return false
	_public_owner = owner
	_lab = lab
	_field = owner.field
	_terrain = owner.construction.terrain
	_profile = "hill"
	_signature = StadiumHillsideTerrain.signature(_profile)
	_body = _terrain.get_node_or_null("TerrainCollision") as StaticBody3D
	_shape_node = (
		_terrain.get_node_or_null("TerrainCollision/ClosedTerrainShape") as CollisionShape3D
	)
	_shape = _shape_node.shape as ConcavePolygonShape3D if _shape_node != null else null
	if (
		not _terrain_valid()
		or _shape.get_faces() != StadiumHillsideTerrainModels.geometry(_profile).faces
	):
		return false
	name = NODE_NAME
	owner.add_child(self)
	if not _installed_valid():
		return false
	_shape.changed.connect(_invalidate_terrain)
	_terrain.tree_exiting.connect(_invalidate_terrain)
	_body.tree_exiting.connect(_invalidate_terrain)
	_shape_node.tree_exiting.connect(_invalidate_terrain)
	blocked = false
	return true


func bind_public_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	clear_binding()
	if (
		_public_owner == null
		or blocked
		or not _installed_valid()
		or not _terrain_valid()
		or resolver == null
		or resolver.state == null
		or resolver.state.dead
		or not _play_current(ball, resolver, resolver.state)
		or ball._started
		or (
			ball.physics_contact_router
			!= Callable(_public_owner, "_boundary_contact_batch").bind(resolver)
		)
	):
		return false
	_ball = ball
	_resolver = resolver
	_state = resolver.state
	# The property owns the one router. No private wrapper or resolver listener is installed.
	return _binding_valid(ball, _state)


func public_ground_first(
	ball: BattedBallBody, batch: Array[Dictionary], state: BallPlayState
) -> bool:
	if (
		_public_owner == null
		or not _binding_valid(ball, state)
		or not _terrain_valid()
		or not ball._started
	):
		return false
	for contact: Dictionary in batch:
		if contact.get("body") == _body and contact.get("position") is Vector3:
			_report_ground(contact.position)
			break
	# Ground callbacks may terminate or replace this play. Never forward to that replacement.
	return _binding_valid(ball, state) and _terrain_valid()


func public_binding_intact(ball: BattedBallBody, state: BallPlayState) -> bool:
	return (
		_public_owner != null
		and not blocked
		and _installed_valid()
		and state != null
		and state == _state
		and ball == _ball
		and _play_current(ball, _resolver, state)
		and (
			ball.physics_contact_router
			== Callable(_public_owner, "_boundary_contact_batch").bind(_resolver)
		)
	)
