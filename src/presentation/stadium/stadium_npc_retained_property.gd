class_name StadiumNpcRetainedProperty
extends StadiumPropertyGeometry

const AC02_PASSIVE_6 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Isolated compatibility adapter, not a human layout or ownership authority.
## Construction remains the untouched retained Node3D factory beneath this adapter.

var venue_id: String
var construction: Node3D
var boundary: Node3D
var receiver: Variant
var display: Node3D
var lab_ref: WeakRef
var old_nodes: Array[Node] = []
var old_field_id: StringName
var old_field: FieldDefinition
var old_camera_mask: int
var old_camera: MatchCameraDirector
var old_visibility: BallTrackingVisibility
var old_observer: Callable
var old_clip: Callable
var old_obstacles: Array[Dictionary] = []
var host_children: Array[Node] = []
var bound_balls: Array[WeakRef] = []
var provenance: Array[Dictionary] = []
var actor_cutaway: StadiumNpcRetainedActorCutaway = StadiumNpcRetainedActorCutaway.new()
var ball_readability: StadiumNpcRetainedBallReadability = StadiumNpcRetainedBallReadability.new()
var presentation_director: MatchCameraDirector
var presentation_camera: WeakRef


func build(_tier: String, _layout: Dictionary, _stock: StadiumStock) -> bool:
	# Do not inherit a callable human-ownership construction path.
	return false


func route_obstacles() -> Array[Dictionary]:
	if field != null and field.id == &"field.npc_venue":
		return StadiumNpcCandidateRoutesV2.obstacles(self)
	return construction.route_obstacles()


func view_graph() -> StadiumRecipeBoundary:
	if venue_id == "AC-01":
		return StadiumNpcClubV1.TemplateView.new()
	return (
		StadiumNpcYardV1.TemplateView.new()
		if venue_id == "AY-01"
		else (StadiumNpcExpandedV1.TemplateView.new())
	)


func clip(from: Vector3, to: Vector3) -> Vector3:
	return (
		StadiumNpcYardGraphV1.clip(from, to)
		if venue_id == "AY-01"
		else (boundary.graph.clip(from, to))
	)


func observe(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> Dictionary:
	if venue_id == "AC-01":
		return StadiumNpcRetainedClubSweep.observe(boundary, resolver, previous, current)
	if venue_id == "AE-01":
		return boundary.graph.observe(resolver, previous, current)
	if resolver == null or resolver.state == null or resolver.state.dead or resolver.field == null:
		return {}
	var event: Dictionary = StadiumNpcYardGraphV1.crossing(previous, current)
	var end: Vector3 = current if event.is_empty() else event.position
	if not resolver.state.is_foul_play:
		StadiumBoundaryObserver._bands(resolver, previous, end)
	if not event.is_empty():
		StadiumNpcYardGraphV1.apply(resolver, event)
	elif current.y < -2.0:
		resolver.resolve_settled(current)
	return event


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	if venue_id != "AC-01":
		super.bind_ball(ball, resolver)
	boundary.bind_ball(ball, resolver)
	bound_balls.append(weakref(ball))


func _ball_contact(body: Node, ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	# Capture observed preterminal provenance before shared surface rules can terminate play.
	if is_ancestor_of(body) and body.has_meta("npc_instance") and provenance.size() < 4096:
		provenance.append(
			{
				"instance": body.get_meta("npc_instance"),
				"surface": body.get_meta("surface_id", ""),
				"preterminal": not resolver.state.dead,
				"elapsed": resolver.state.elapsed_seconds
			}
		)
	super._ball_contact(body, ball, resolver)


func _club_contact(event: Dictionary, resolver: BallPlayResolver) -> void:
	# Real swept/batch contact identity is captured before a terminal rule changes state.
	if not event.get("npc_instance", "").is_empty() and provenance.size() < 4096:
		provenance.append(
			{
				"instance": event.npc_instance,
				"surface": event.get("surface", ""),
				"preterminal": not resolver.state.dead,
				"elapsed": resolver.state.elapsed_seconds
			}
		)
	if event.get("kind") == "receiver":
		receiver.present_contact(
			{
				"copy": event.get("npc_instance", ""),
				"surface": event.get("surface", ""),
				"position": event.position,
				"elapsed": resolver.state.elapsed_seconds
			},
			"batted"
		)


func _receiver_camera_protection() -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	return lab != null and lab._camera_director.shot == MatchCameraDirector.Shot.BATTING


func presentation_actors(lab: PitchBatLab) -> Array[Node3D]:
	var actors: Array[Node3D] = []
	if (
		is_instance_valid(lab._batter_avatar)
		and lab.get_node_or_null("BatterAvatar") == lab._batter_avatar
		and lab._batter_avatar.role == PlayerAvatar.Role.BATTER
	):
		actors.append(lab._batter_avatar)
		if is_instance_valid(lab._bat_actor) and lab.get_node_or_null("BatActor") == lab._bat_actor:
			actors.append(lab._bat_actor)
	if (
		is_instance_valid(lab._pitcher_avatar)
		and lab.get_node_or_null("PitcherDefender/PitcherAvatar") == lab._pitcher_avatar
		and lab.get_node_or_null("PitcherDefender") == lab._pitcher_marker
		and lab._pitcher_avatar.role == PlayerAvatar.Role.PITCHER
	):
		actors.append(lab._pitcher_avatar)
	if (
		is_instance_valid(lab._primary_fielder)
		and is_instance_valid(lab._primary_fielder._avatar)
		and lab.get_node_or_null("PrimaryFielder") == lab._primary_fielder
		and lab._primary_fielder.get_node_or_null("FielderAvatar") == lab._primary_fielder._avatar
		and lab._primary_fielder._avatar.role == PlayerAvatar.Role.FIELDER
	):
		actors.append(lab._primary_fielder._avatar)
	return actors


func refresh_actor_presentation(lab: PitchBatLab) -> void:
	var ac02_token: int = AC02_PASSIVE_6.enter(
		"stadium_npc_retained_property.refresh_actor_presentation"
	)
	_ac02_passive_06_refresh_actor_presentation(lab)
	AC02_PASSIVE_6.leave(ac02_token)


func _ac02_passive_06_refresh_actor_presentation(lab: PitchBatLab) -> void:
	# One ordinary retained runtime path, also used by deterministic inspection callers.
	# Neither ball visibility toggles nor force-visible receiver inspection change live policy.
	if (
		lab == null
		or lab_ref == null
		or lab_ref.get_ref() != lab
		or not lab.has_meta("stadium_property")
		or lab.get_meta("stadium_property") != self
		or lab._camera_director != presentation_director
		or presentation_director == null
		or presentation_camera == null
		or presentation_camera.get_ref() != lab._camera
	):
		restore_presentations()
		return
	var live: bool = (
		lab._ball_in_play_is_live()
		and presentation_director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY
	)
	ball_readability.update(lab._batted_ball, lab._camera, live)
	actor_cutaway.apply_actors(
		presentation_actors(lab),
		lab._camera,
		lab._batted_ball,
		live,
		ball_readability.effective_radius()
	)


func refresh_receiver_presentation(lab: PitchBatLab, force_visible: bool = false) -> void:
	var ac02_token: int = AC02_PASSIVE_6.enter(
		"stadium_npc_retained_property.refresh_receiver_presentation"
	)
	_ac02_passive_06_refresh_receiver_presentation(lab, force_visible)
	AC02_PASSIVE_6.leave(ac02_token)


func _ac02_passive_06_refresh_receiver_presentation(
	lab: PitchBatLab, force_visible: bool = false
) -> void:
	rebind(lab._match_state)
	refresh_actor_presentation(lab)
	_refresh_receiver_visuals(lab, force_visible)


func _refresh_receiver_visuals(lab: PitchBatLab, force_visible: bool) -> void:
	if receiver == null:
		return
	var hidden: bool = (
		not force_visible
		and not is_instance_valid(lab._batted_ball)
		and lab._camera_director.shot == MatchCameraDirector.Shot.BATTING
	)
	var radius: float = ball_readability.effective_radius()
	for model: Node3D in [receiver.chair, receiver.net]:
		var alpha: float = 1.0
		if not hidden and is_instance_valid(lab._camera) and is_instance_valid(lab._batted_ball):
			if model.get_meta("stadium_item") == "ST-073":
				# Preserve the open cup: per-member local bounds, never one filled net box.
				for mesh: MeshInstance3D in model.get_node("Visual").get_children():
					var inverse: Transform3D = mesh.global_transform.affine_inverse()
					var local_radius: float = (
						radius
						* maxf(
							inverse.basis.x.length(),
							maxf(inverse.basis.y.length(), inverse.basis.z.length())
						)
					)
					if (
						mesh.get_aabb().grow(local_radius).intersects_segment(
							inverse * lab._camera.global_position,
							inverse * lab._batted_ball.global_position
						)
						!= null
					):
						alpha = StadiumReceiverVisibility.FADED_ALPHA
						break
			elif (
				StadiumReceiverVisibility._bounds(model).grow(radius).intersects_segment(
					lab._camera.global_position, lab._batted_ball.global_position
				)
				!= null
			):
				alpha = StadiumReceiverVisibility.FADED_ALPHA
		StadiumReceiverVisibility._style(model, hidden, alpha)


func restore_presentations() -> void:
	actor_cutaway.restore_all()
	ball_readability.restore_all()


func rebind(state: MatchState) -> void:
	if is_instance_valid(display) and display._match != state:
		display.bind_match(state)


func _process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab != null:
		rebind(lab._match_state)
		refresh_actor_presentation(lab)


func disconnect_balls() -> void:
	restore_presentations()
	for reference: WeakRef in bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		for connection: Dictionary in ball.body_entered.get_connections():
			if connection.callable.get_object() == self:
				ball.body_entered.disconnect(connection.callable)
		if ball.physics_contact_router.get_object() == boundary:
			ball.physics_contact_router = Callable()
		for connection: Dictionary in ball.tree_exited.get_connections():
			if connection.callable.get_object() == boundary:
				ball.tree_exited.disconnect(connection.callable)
	bound_balls.clear()


func _exit_tree() -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if is_instance_valid(lab):
		StadiumNpcRetainedRuntime.unexpected_exit(lab, self)
	disconnect_balls()
	if is_instance_valid(display):
		display.bind_match(null)
	for node: Node in old_nodes:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	old_nodes.clear()
