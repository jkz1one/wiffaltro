class_name StadiumPoolBoundProperty
extends StadiumPropertyGeometry
## One private Pool layered onto an exact ordinary receiver-only backyard property.
## The ordinary receiver, boundary, ground, ray obstruction and contact rules remain authorities.
# gdlint: disable=max-returns

var pool_model: Node3D
var ground_body: StaticBody3D
var boundary: StadiumBoundaryPrototype
var receiver: StadiumPitchReceiver
var entitlement: StadiumPoolBoundEntitlement
var frozen_snapshot: Dictionary = {}
var footprint: Dictionary = {}
var old_nodes: Array[Node] = []
var old_order: Array[Node] = []
var saved_state: Dictionary = {}
var restoring: bool = false
var _lab_ref: WeakRef
var _host: StarterFieldLabGeometry
var _lab_parent: WeakRef
var _match_ref: WeakRef
var _ground_bytes: PackedByteArray
var _ground_ids: PackedInt64Array
var _boundary_bytes: PackedByteArray
var _boundary_ids: PackedInt64Array
var _descriptor: Dictionary = {}
var _snapshot_bytes: PackedByteArray
var _field_bytes: PackedByteArray
var _runtime_field: FieldDefinition
var _pool_ids: PackedInt64Array
var _receiver_id: int = 0
var _chair_id: int = 0
var _bound_balls: Dictionary = {}
var _static_bytes: PackedByteArray
var _actor_ids: PackedInt64Array
var _actor_scripts: Array = []


func build_private(lab: PitchBatLab, token: StadiumPoolBoundEntitlement) -> bool:
	if (
		token == null
		or lab == null
		or lab._match_state == null
		or not token.valid_for(lab, lab._match_state.stadium, "CONFIGURED")
	):
		return false
	entitlement = token
	_descriptor = token.descriptor()
	frozen_snapshot = lab._match_state.stadium.duplicate(true)
	_snapshot_bytes = var_to_bytes(frozen_snapshot)
	if not super.build(
		"backyard", frozen_snapshot.layout, StadiumLayoutSnapshot.ownership(frozen_snapshot)
	):
		return false
	pool_model = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	if pool_model == null:
		return false
	pool_model.transform = StadiumPoolContract.placement()
	add_child(pool_model)
	# Ownership is deliberately outside the immutable exact Pool model tree.
	objects[_descriptor.copy] = pool_model
	var template_wall: Node = get_node("TemplateBackWall")
	boundary = StadiumBoundaryRuntime.assemble(self) as StadiumBoundaryPrototype
	if is_instance_valid(template_wall) and template_wall.get_parent() == null:
		template_wall.free()  # Prospective off-tree removals cannot leak until a later frame.
	if boundary == null:
		return false
	receiver = StadiumPitchReceiver.new()
	receiver.name = "PitchReceiverPresentation"
	add_child(receiver)
	if not receiver.configure(objects["starter-v1:ST-079"], lab._sounds):
		return false
	ground_body = get_node_or_null("PropertyGround") as StaticBody3D
	if ground_body == null or not _ground_shape_exact():
		return false
	var reference: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	if reference == null:
		return false
	reference.transform = StadiumPoolContract.placement()
	var exact: bool = StadiumPoolPartyAssetIntegrity.same_tree(pool_model, reference)
	reference.free()
	if not exact:
		return false
	footprint = StadiumPoolBoundFootprint.validate(self, lab)
	if footprint.is_empty():
		return false
	_ground_bytes = var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(ground_body))
	_ground_ids = StadiumPoolInteriorV2._node_identities(ground_body)
	_boundary_bytes = _boundary_geometry()
	_boundary_ids = StadiumPoolInteriorV2._node_identities(boundary)
	_field_bytes = var_to_bytes(StadiumPoolPartyAssetIntegrity._value(field))
	_runtime_field = lab._field_definition
	_pool_ids = StadiumPoolInteriorV2._node_identities(pool_model)
	_receiver_id = receiver.get_instance_id()
	_chair_id = receiver.chair.get_instance_id()
	return true


func bind_owner(lab: PitchBatLab, host: StarterFieldLabGeometry) -> bool:
	if _lab_ref != null or not entitlement.claim(lab, frozen_snapshot, self):
		return false
	_lab_ref = weakref(lab)
	_match_ref = weakref(lab._match_state)
	_lab_parent = weakref(lab.get_parent())
	_host = host
	_static_bytes = _static_inventory(lab)
	_actor_ids = _actors(lab)
	_actor_scripts = _scripts(lab)
	return true


func valid_owner(lab: PitchBatLab) -> bool:
	if (
		lab == null
		or lab.is_queued_for_deletion()
		or lab.get_script() != load("res://src/labs/pitch_bat_lab/pitch_bat_lab.gd")
		or get_script() != load("res://src/presentation/stadium/stadium_pool_bound_property.gd")
		or _lab_ref == null
		or _lab_ref.get_ref() != lab
		or _lab_parent == null
		or _lab_parent.get_ref() != lab.get_parent()
		or lab.get_parent() == null
		or lab.get_parent().process_thread_group != Node.PROCESS_THREAD_GROUP_INHERIT
		or _match_ref == null
		or _match_ref.get_ref() != lab._match_state
		or not lab._match_mode
		or lab._field_id != PitchBatLab.FIELD_ID
		or not is_inside_tree()
		or is_queued_for_deletion()
		or lab.global_transform != Transform3D.IDENTITY
		or global_transform != Transform3D.IDENTITY
		or not is_instance_valid(_host)
		or _host.is_queued_for_deletion()
		or _host.get_script() != load("res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd")
		or _host.get_parent() != lab
		or _host.global_transform != Transform3D.IDENTITY
		or get_parent() != _host
		or not lab.has_meta("stadium_property")
		or lab.get_meta("stadium_property") != self
		or not lab.has_meta("stadium_pool_bound_property")
		or lab.get_meta("stadium_pool_bound_property") != self
		or lab._match_state == null
		or entitlement == null
		or not is_instance_valid(lab._pitch_actor)
		or not is_instance_valid(lab._pitcher_marker)
		or not is_instance_valid(lab._primary_fielder)
		or not is_instance_valid(lab._ball_play_resolver)
	):
		return false
	if (
		_actors(lab) != _actor_ids
		or _scripts(lab) != _actor_scripts
		or lab._primary_fielder.get_parent() != lab
		or lab._pitcher_marker.get_parent() != lab
		or lab._pitch_actor.get_parent() != lab
		or var_to_bytes(frozen_snapshot) != _snapshot_bytes
		or var_to_bytes(lab._match_state.stadium) != _snapshot_bytes
		or var_to_bytes(lab.get_meta("stadium_snapshot", {})) != _snapshot_bytes
		or entitlement.descriptor() != _descriptor
		or not entitlement.owns(lab, frozen_snapshot, self)
		or get_meta("property_signature", "") != frozen_snapshot.geometry
		or lab.get_meta("boundary_signature", "") != frozen_snapshot.boundary
	):
		return false
	if (
		not is_instance_valid(pool_model)
		or pool_model.get_parent() != self
		or StadiumPoolInteriorV2._node_identities(pool_model) != _pool_ids
		or pool_model.global_transform != StadiumPoolContract.placement()
		or objects.size() != 2
		or objects.get(_descriptor.copy) != pool_model
		or not is_instance_valid(receiver)
		or receiver.get_parent() != self
		or receiver.get_instance_id() != _receiver_id
		or (
			receiver.get_script()
			!= preload("res://src/presentation/stadium/stadium_pitch_receiver.gd")
		)
		or not is_instance_valid(receiver.chair)
		or receiver.chair.get_parent() != self
		or receiver.chair.get_instance_id() != _chair_id
		or receiver.chair != objects.get("starter-v1:ST-079")
		or receiver.chair.transform != Transform3D(Basis.IDENTITY, StadiumStarterLayout.RECEIVER)
		or lab._pitch_actor.receiver_router != receiver.route
	):
		return false
	if (
		not is_instance_valid(boundary)
		or boundary.get_parent() != self
		or (
			boundary.get_script()
			!= preload("res://src/presentation/stadium/stadium_boundary_prototype.gd")
		)
		or boundary.transform != Transform3D.IDENTITY
		or StadiumPoolInteriorV2._node_identities(boundary) != _boundary_ids
		or _boundary_geometry() != _boundary_bytes
	):
		return false
	return (
		ground_matches(ground_body)
		and _static_inventory(lab) == _static_bytes
		and field != null
		and lab._field_definition != null
		and lab._field_definition == _runtime_field
		and var_to_bytes(StadiumPoolPartyAssetIntegrity._value(field)) == _field_bytes
		and (
			var_to_bytes(StadiumPoolPartyAssetIntegrity._value(lab._field_definition))
			== _field_bytes
		)
		and lab._ball_play_resolver.segment_observer == StadiumBoundaryObserver.observe
		and lab._primary_fielder.stadium_boundary_clip == StadiumBoundaryGraph.clip
		and lab._primary_fielder.stadium_obstacles == route_obstacles()
	)


func ground_matches(body: StaticBody3D) -> bool:
	return (
		is_instance_valid(body)
		and body == ground_body
		and body.get_parent() == self
		and body.is_inside_tree()
		and not body.is_queued_for_deletion()
		and StadiumPoolInteriorV2._node_identities(body) == _ground_ids
		and var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(body)) == _ground_bytes
	)


func plain_actors(lab: PitchBatLab) -> bool:
	if (
		lab == null
		or not is_instance_valid(lab._pitcher_marker)
		or not is_instance_valid(lab._primary_fielder)
		or not is_instance_valid(lab._pitch_actor)
		or not is_instance_valid(lab._ball_play_resolver)
	):
		return false
	return (
		lab._pitcher_marker.get_class() == "Node3D"
		and lab._pitcher_marker.get_script() == null
		and lab._pitcher_marker.get_parent() == lab
		and not lab._pitcher_marker.is_queued_for_deletion()
		and lab._pitcher_marker.scale == Vector3.ONE
		and (
			lab._primary_fielder.get_script()
			== preload("res://src/presentation/fielding/fielder_controller.gd")
		)
		and lab._primary_fielder.get_parent() == lab
		and not lab._primary_fielder.is_queued_for_deletion()
		and lab._primary_fielder.scale == Vector3.ONE
		and not lab._pitch_actor.running
		and lab._primary_fielder.stadium_obstacles == route_obstacles()
		and lab._primary_fielder.stadium_boundary_clip == StadiumBoundaryGraph.clip
		and lab._primary_fielder.pitcher_defender == lab._pitcher_marker
		and (
			lab._ball_play_resolver.get_script()
			== preload("res://src/gameplay/ball_in_play/ball_play_resolver.gd")
		)
		and lab._ball_play_resolver.segment_observer == StadiumBoundaryObserver.observe
		and lab.process_thread_group == Node.PROCESS_THREAD_GROUP_INHERIT
		and lab.process_physics_priority == 0
		and lab._primary_fielder.process_physics_priority == 0
	)


func route_obstacles() -> Array[Dictionary]:
	if _descriptor.is_empty():
		return []
	return [
		{
			"center": StadiumStarterLayout.RECEIVER,
			"radius": Vector2(0.30, 0.43).length() + StadiumDefenderRoutes.BODY_RADIUS,
			"copy": "starter-v1:ST-079"
		},
		{
			"center": StadiumPoolContract.placement().origin,
			"radius": StadiumPoolBoundFootprint.ROUTE_RADIUS,
			"copy": _descriptor.copy
		}
	]


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	for id: int in _bound_balls.keys():
		if _bound_balls[id].ball.get_ref() == null:
			_bound_balls.erase(id)
	_bound_balls[ball.get_instance_id()] = {"ball": weakref(ball), "resolver": weakref(resolver)}
	super.bind_ball(ball, resolver)


func _ball_contact(body: Node, ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	if is_instance_valid(pool_model) and pool_model.is_ancestor_of(body):
		# Preserve ordinary ricochet/floor authority even when the water adapter declines.
		StadiumSurfaceRules.apply(
			resolver,
			"LIVE_RICOCHET",
			_descriptor.copy,
			ball.global_position,
			String(body.get_meta("surface_id", ""))
		)
		return
	super._ball_contact(body, ball, resolver)


func expected_body_callback(ball: BattedBallBody, resolver: BallPlayResolver) -> Callable:
	return _ball_contact.bind(ball, resolver)


func expected_boundary_router(resolver: BallPlayResolver) -> Callable:
	return boundary._contact_batch.bind(resolver) if is_instance_valid(boundary) else Callable()


func expected_exit_callback(ball: BattedBallBody) -> Callable:
	return (
		boundary._forget.bind(ball.get_instance_id()) if is_instance_valid(boundary) else Callable()
	)


func detach_ball_callbacks() -> void:
	for row: Dictionary in _bound_balls.values():
		var ball: BattedBallBody = row.ball.get_ref() as BattedBallBody
		var resolver: BallPlayResolver = row.resolver.get_ref() as BallPlayResolver
		if ball == null or resolver == null:
			continue
		var body_callback: Callable = expected_body_callback(ball, resolver)
		var exit_callback: Callable = expected_exit_callback(ball)
		if ball.body_entered.is_connected(body_callback):
			ball.body_entered.disconnect(body_callback)
		if exit_callback.is_valid() and ball.tree_exited.is_connected(exit_callback):
			ball.tree_exited.disconnect(exit_callback)
		if ball.physics_contact_router == expected_boundary_router(resolver):
			ball.physics_contact_router = Callable()
		if is_instance_valid(boundary):
			boundary._forget(ball.get_instance_id())
	_bound_balls.clear()


func _boundary_geometry() -> PackedByteArray:
	var rows: Array = []
	for child: Node in boundary.get_children():
		rows.append(StadiumPoolPartyAssetIntegrity.snapshot(child))
	return var_to_bytes(rows)


func _ground_shape_exact() -> bool:
	if (
		ground_body.get_script() != null
		or ground_body.collision_layer != 1
		or ground_body.collision_mask != 2
		or ground_body.get_meta("ball_surface", "") != &"ground"
		or ground_body.get_child_count() != 2
		or not ground_body.get_child(0) is CollisionShape3D
		or not ground_body.get_child(1) is MeshInstance3D
	):
		return false
	var shape: CollisionShape3D = ground_body.get_child(0)
	var mesh: MeshInstance3D = ground_body.get_child(1)
	var bounds: AABB = StadiumProperty.ground_bounds("backyard")
	return (
		shape.shape is BoxShape3D
		and mesh.mesh is BoxMesh
		and ground_body.transform == Transform3D(Basis.IDENTITY, bounds.get_center())
		and shape.transform == Transform3D.IDENTITY
		and shape.shape.size == bounds.size
		and mesh.transform == Transform3D.IDENTITY
		and mesh.mesh.size == bounds.size
	)


func _exit_tree() -> void:
	if not restoring:
		StadiumPoolBoundExtension.property_exiting(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for node: Node in old_nodes:
			if is_instance_valid(node) and node.get_parent() == null:
				node.free()
		old_nodes.clear()


func _static_inventory(lab: PitchBatLab) -> PackedByteArray:
	# Seal once at owner binding, not once per launch. Ordinary receiver animation
	# changes only Visual, so every real collider stays exact across deliveries.
	var rows: Array = []
	for body: StaticBody3D in lab.find_children("*", "StaticBody3D", true, false):
		rows.append(
			[
				body.get_instance_id(),
				body.get_parent().get_instance_id(),
				body.global_transform,
				StadiumPoolPartyAssetIntegrity.snapshot(body)
			]
		)
	return var_to_bytes(rows)


func _actors(lab: PitchBatLab) -> PackedInt64Array:
	return [
		lab._pitch_actor.get_instance_id(),
		lab._pitcher_marker.get_instance_id(),
		lab._primary_fielder.get_instance_id(),
		lab._ball_play_resolver.get_instance_id()
	]


func _scripts(lab: PitchBatLab) -> Array:
	return [
		lab._pitch_actor.get_script(),
		lab._pitcher_marker.get_script(),
		lab._primary_fielder.get_script(),
		lab._ball_play_resolver.get_script(),
		lab._match_state.get_script()
	]
