# gdlint: disable=max-public-methods
class_name StadiumNpcYardTwoPropertyV1
extends StadiumNpcRetainedProperty
## AY02/r1 retained adapter. Separate saved-fixture and private admission, owned callbacks.
# gdlint: disable=max-returns

const PREFIX: String = StadiumNpcYardTwoV1.PREFIX
var bound_state: MatchState
var public_bound: bool = false
var public_snapshot: Dictionary = {}
var public_season: SeasonState
var public_assignments: Dictionary = {}
var public_fixture: Dictionary = {}
var public_automation: MatchAutomation
var public_managed: bool = false
var receiver_configured: bool = false
var motion: StadiumNpcYardTwoCameraMotionV1
var camera: StadiumNpcYardTwoCameraV1
var visibility: StadiumNpcYardTwoVisibilityV1
var actor_presentation: StadiumNpcYardTwoActorPresentationV1
var old_router: Callable
var old_camera_transform: Transform3D
var old_camera_fov: float
var phase: StringName = &"staging"
var installation_generation: int = 0
var play_generation: int = 0
# Frozen only after the complete installation audit; never refreshed during a play.
var _issued_public_context: Dictionary = {}:
	set(_value):
		pass
var _members: Dictionary = {}
var _bodies: Dictionary = {}
var _identities: Array = []
var _support: Array = []
var _field: FieldDefinition
var _construction: StadiumNpcYardTwoV1
var _boundary: StadiumNpcYardBoundaryV1
var _receiver: StadiumNpcYardTwoReceiverV1
var _host: Node3D
var _actor: PitchFlightActor
var _resolver: BallPlayResolver
var _fielder: FielderController
var _lab_camera: Camera3D
var _sounds: PlaySounds
var _release: PitchReleaseController
var _cadence: AtBatCadenceController
var _style_state: String = ""
var _style_alpha: float = 1.0
var _contact_token: RefCounted
var _token_args: Array = []
var _token_generation: Vector2i = Vector2i(-1, -1)
var _exit_had_owned_activity: bool = false
var _visibility_pin: Array = []
var _signal_pin: Array = []
# Supported static installation, not arbitrary native mutate/restore authentication.
# Only gameplay owners/colliders are pinned here; full decorative content stays cold.
var _play_kind: StringName = &""
var _play_pitch: PitchState
var _play_parameters: PitchLaunchParameters
var _play_ball: BattedBallBody
var _play_state: BallPlayState
var _outcome_generation: int = -1
var _camera_launch_generation: int = -1
var _auditing: bool = false
var _geometry_scanning: bool = false
var _visual_writing: RefCounted
var _visual_generation: int = -1
var _owners: Array[Dictionary] = []
var _colliders: Array[Dictionary] = []
var _shapes: Array[Dictionary] = []
var _host_count: int = -1
var _retirement_reason: String = ""

# Independent immutable authority is born with this property, before installed geometry exists.
# The setter prevents replacing the frozen snapshot, including through Object.set().
var _geometry_reference: Dictionary = StadiumNpcYardTwoInstalledGeometryV1.build_reference():
	set(_value):
		pass


func pin_construction() -> void:
	_construction = construction
	_boundary = boundary
	_field = field
	_members = objects.duplicate()
	for identity: String in objects:
		var model: Node3D = objects[identity]
		for body: StaticBody3D in model.get_node("Collision").get_children():
			_bodies[body] = {"instance": identity, "model": model,
				"surface": body.get_meta("surface_id"), "role": body.get_meta("surface_role"),
				"item": model.get_meta("stadium_item"),
				"container": body.get_parent(), "children": body.get_children()}
	_identities = StadiumNpcYardTwoInstalledGeometryV1.identities(construction)


func pin_support() -> void:
	_receiver = receiver
	_support = [receiver, motion, camera, visibility, actor_presentation,
		actor_cutaway, ball_readability]


func pin_lab(lab: PitchBatLab) -> void:
	lab_ref = weakref(lab)
	_host = lab.get_node("StarterFieldGeometry")
	_actor = lab._pitch_actor
	_resolver = lab._ball_play_resolver
	_fielder = lab._primary_fielder
	_lab_camera = lab._camera
	_sounds = lab._sounds
	_release = lab._release_controller
	_cadence = lab._at_bat_cadence
	presentation_director = camera
	presentation_camera = weakref(_lab_camera)


func _owned_receiver() -> StadiumNpcYardTwoReceiverV1:
	return _receiver if is_instance_valid(_receiver) \
		and _receiver.get_script() == StadiumNpcYardTwoReceiverV1 else null


func support_intact() -> bool:
	return _support == [receiver, motion, camera, visibility, actor_presentation,
		actor_cutaway, ball_readability] and is_instance_valid(receiver) \
		and receiver.get_script() == StadiumNpcYardTwoReceiverV1 \
		and receiver.get_parent() == self and get_node_or_null("PitchReceiverPresentation") == receiver \
		and receiver.transform == Transform3D.IDENTITY and not receiver.top_level \
		and receiver.visible and receiver.process_mode == Node.PROCESS_MODE_INHERIT \
		and receiver.process_priority == 0 and receiver.process_physics_priority == 0 \
		and receiver.get_child_count() == 0 \
		and is_instance_valid(motion) and motion.get_script() == StadiumNpcYardTwoCameraMotionV1 \
		and is_instance_valid(camera) and camera.get_script() == StadiumNpcYardTwoCameraV1 \
		and is_instance_valid(visibility) and visibility.get_script() == StadiumNpcYardTwoVisibilityV1 \
		and is_instance_valid(actor_presentation) \
		and actor_presentation.get_script() == StadiumNpcYardTwoActorPresentationV1 \
		and actor_presentation.get_parent() == self \
		and get_node_or_null("AY02ActorPresentation") == actor_presentation \
		and actor_presentation.get_child_count() == 0 \
		and actor_presentation.process_physics_priority == 0 \
		and is_instance_valid(actor_cutaway) \
		and actor_cutaway.get_script() == StadiumNpcRetainedActorCutaway \
		and is_instance_valid(ball_readability) \
		and ball_readability.get_script() == StadiumNpcRetainedBallReadability \
		and get_children() == [construction, receiver, actor_presentation]


func geometry_intact() -> bool:
	# The public diagnostic remains the original full canonical scanner.
	if _geometry_scanning or _visual_writing != null:
		retire_installation("reentrant geometry audit")
		return false
	var generation: int = installation_generation
	_geometry_scanning = true
	var valid: bool = _geometry_intact_full()
	_geometry_scanning = false
	return valid and generation == installation_generation


func _geometry_intact_full() -> bool:
	return get_script() == StadiumNpcYardTwoPropertyV1 \
		and transform == Transform3D.IDENTITY and not top_level and visible \
		and process_mode == Node.PROCESS_MODE_INHERIT \
		and process_priority == 0 and process_physics_priority == 0 \
		and name == &"AY02InstalledProperty" and venue_id == "AY-02" and tier == "backyard" \
		and is_instance_valid(construction) and construction == _construction \
		and construction.get_parent() == self and construction.get_script() == StadiumNpcYardTwoV1 \
		and construction.tier == "backyard" \
		and boundary == _boundary and boundary == construction.get_node_or_null("BoundaryGraph") \
		and is_instance_valid(field) and field == _field and field == construction.field \
		and field.get_script() == FieldDefinition and objects == _members \
		and objects == construction.objects and display == null \
		and StadiumNpcYardTwoInstalledGeometryV1.intact(self)


func model_intact(identity: String) -> bool:
	return _member_bound(identity) and geometry_intact()


func contact_identity(body: Node) -> Dictionary:
	if _contact_member(body).is_empty() or phase == &"retired":
		return {}
	if not (callback_intact() if phase != &"staging" else geometry_intact()):
		return {}
	return _bodies[body].duplicate()


func binding_valid(check_state: bool = true) -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	return StadiumNpcYardTwoRuntimeV1.binding_valid(lab, self, check_state, not hot_eligible())


func callback_intact(check_state: bool = true) -> bool:
	# A callback between launch audit and camera dispatch consumes no reusable evidence.
	_camera_launch_generation = -1
	if _auditing or _geometry_scanning or _visual_writing != null:
		retire_installation("reentrant admission")
		_request_interruption()
		return false
	if phase == &"retired":
		_request_interruption()
		return false
	if hot_eligible():
		var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab
		if StadiumNpcYardTwoRuntimeV1.binding_valid(lab, self, check_state, false) \
			and StadiumNpcYardTwoRuntimeV1._components_bound(lab, self, false) \
			and routing_intact() and _physical_records_intact() and _play_bindings_intact():
			return true
		retire_installation("live ownership changed")
		_request_interruption()
		return false
	# Issued owner pins remain fresh even when an extra observer requires strict callbacks.
	if phase == &"playing" and _play_kind in [&"pitch", &"ball"] \
		and not _play_bindings_intact():
		retire_installation("play owner changed")
		_request_interruption()
		return false
	# Unissued actor-start diagnostics/custom implementations retain the strict route.
	var valid: bool = audit_installation(check_state)
	if not valid:
		_request_interruption()
	return valid


func routing_intact() -> bool:
	return not _signal_pin.is_empty() and _signal_pin == _signal_data() \
		and _actor.receiver_router == receiver.route \
		and _resolver.segment_observer == observe and _fielder.stadium_boundary_clip == clip \
		and _fielder.stadium_obstacles == route_obstacles()


func physical_intact() -> bool:
	# Fresh ownership plus bounded physical records for issued ordinary gameplay.
	return callback_intact()


func route_obstacles() -> Array[Dictionary]:
	return construction.route_obstacles() if is_instance_valid(construction) else []


func view_graph() -> StadiumRecipeBoundary:
	return StadiumNpcYardV1.TemplateView.new()


func clip(from: Vector3, to: Vector3) -> Vector3:
	return StadiumNpcYardGraphV1.clip(from, to) if callback_intact() else from


func observe(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> Dictionary:
	if not callback_intact() or resolver != _resolver or resolver.state == null \
		or resolver.state.dead or resolver.field != field:
		return {}
	# Explicit Yard route; never the inherited Expanded fallback.
	return super.observe(resolver, previous, current)


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if not callback_intact() or not is_instance_valid(ball) or ball != lab._batted_ball \
		or resolver != _resolver or ball.get_script() != BattedBallBody \
		or not ball.is_inside_tree() or not lab.is_ancestor_of(ball):
		return
	var callback: Callable = _ball_contact.bind(ball, resolver)
	if not ball.body_entered.is_connected(callback):
		ball.body_entered.connect(callback)
	ball.physics_contact_router = _boundary_contact_batch.bind(resolver)
	if not ball.tree_exited.is_connected(_forget_ball.bind(ball.get_instance_id())):
		ball.tree_exited.connect(_forget_ball.bind(ball.get_instance_id()), CONNECT_ONE_SHOT)
	for reference: WeakRef in bound_balls:
		if reference.get_ref() == ball:
			return
	bound_balls.append(weakref(ball))


func _ball_owned(ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if not callback_intact() or not is_instance_valid(ball) or lab._batted_ball != ball \
		or resolver != _resolver or resolver.state == null or resolver.field != field \
		or ball.get_script() != BattedBallBody or not ball._started or not ball.is_inside_tree() \
		or not lab.is_ancestor_of(ball) \
		or ball.physics_contact_router != _boundary_contact_batch.bind(resolver) \
		or not ball.body_entered.is_connected(_ball_contact.bind(ball, resolver)) \
		or not ball.tree_exited.is_connected(_forget_ball.bind(ball.get_instance_id())):
		return false
	for reference: WeakRef in bound_balls:
		if reference.get_ref() == ball:
			return true
	return false


func _boundary_contact_batch(ball: BattedBallBody, batch: Array[Dictionary],
	resolver: BallPlayResolver) -> void:
	if not _ball_owned(ball, resolver) or resolver.state.dead:
		return
	for contact: Dictionary in batch:
		if not contact.get("body") is StaticBody3D or not is_instance_valid(contact.body) \
			or not construction.is_ancestor_of(contact.body) \
			or not contact.get("position") is Vector3 or not contact.position.is_finite():
			return
	boundary._contact_batch(ball, batch, resolver)


func _ball_contact(body: Node, ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	if not _ball_owned(ball, resolver) or resolver.state.dead \
		or not ball.get_colliding_bodies().has(body):
		return
	var row: Dictionary = contact_identity(body)
	if row.is_empty():
		return
	if provenance.size() < 4096:
		provenance.append({"instance": row.instance, "surface": row.surface,
			"preterminal": true, "elapsed": resolver.state.elapsed_seconds})
	var applied: bool = StadiumSurfaceRules.apply(resolver, row.role, row.instance,
		ball.global_position, row.surface)
	if applied and row.role == "RECEIVER_CONTAINMENT_FOUL":
		_contact_token = RefCounted.new()
		_token_args = [body, ball, resolver, ball.global_position]
		_token_generation = Vector2i(installation_generation, play_generation)
		receiver.dispatch_batted_contact(body, ball, resolver, ball.global_position, _contact_token)
		_contact_token = null
		_token_args.clear()


func consume_receiver_contact(body: Node, ball: BattedBallBody, resolver: BallPlayResolver,
	position: Vector3, token: RefCounted) -> bool:
	if token == null or token != _contact_token or _token_args != [body, ball, resolver, position] \
		or _token_generation != Vector2i(installation_generation, play_generation) \
		or not _ball_owned(ball, resolver):
		return false
	_contact_token = null
	_token_args.clear()
	return true


func _forget_ball(id: int) -> void:
	if is_instance_valid(boundary):
		boundary._forget(id)


func rebind(state: MatchState) -> void:
	bound_state = state


func copy_owned_style(expected_chair: Node3D) -> bool:
	var chair: Node3D = _members.get(PREFIX + "RECEIVER-PRIMARY")
	if not is_instance_valid(chair):
		return false
	if _style_state.is_empty():
		return not chair.has_meta("receiver_render_state")
	if not chair.has_meta("receiver_render_state") \
		or chair.get_meta("receiver_render_state") != _style_state:
		return false
	StadiumReceiverVisibility._style(expected_chair, _style_state == "hidden", _style_alpha)
	return true


func refresh_actor_presentation(lab: PitchBatLab) -> void:
	# Direct inspection shares the original AY02 actor policy; no inherited ball enlargement.
	if binding_valid() and lab_ref.get_ref() == lab and camera == lab._camera_director:
		camera.refresh_actor_cutaway(lab._camera, lab._ball_in_play_is_live())
	else:
		restore_presentations()


func refresh_receiver_presentation(lab: PitchBatLab, force_visible: bool = false) -> void:
	if not callback_intact() or lab_ref.get_ref() != lab:
		restore_presentations()
		return
	# Inline only this synchronous admitted path; the public actor/camera entries stay guarded.
	# Preserve the nested admission around any unreviewed virtual lab/state behavior.
	if lab.get_script() != PitchBatLab or (lab._ball_play_resolver.state != null \
		and lab._ball_play_resolver.state.get_script() != BallPlayState):
		refresh_actor_presentation(lab)
	elif binding_valid() and lab_ref.get_ref() == lab and camera == lab._camera_director:
		var cutaway_live: bool = lab._ball_in_play_is_live()
		if camera.actor_cutaway != null:
			var cutaway_lab: PitchBatLab = (
				camera.lab_ref.get_ref() as PitchBatLab if camera.lab_ref != null else null)
			var cutaway_property: StadiumNpcYardTwoPropertyV1
			if cutaway_lab != null and cutaway_lab.has_meta("stadium_property"):
				cutaway_property = cutaway_lab.get_meta("stadium_property") \
					as StadiumNpcYardTwoPropertyV1
			if cutaway_lab == null or cutaway_property != self \
				or camera.property_ref == null or camera.property_ref.get_ref() != self \
				or cutaway_property.camera != camera \
				or cutaway_property.actor_cutaway != camera.actor_cutaway \
				or cutaway_lab._camera_director != camera or lab._camera != cutaway_lab._camera:
				camera._restore_owned()
			else:
				camera.actor_cutaway.apply_actors(
					StadiumGrandIIICameraDirector.presentation_actors(cutaway_lab),
					lab._camera, cutaway_lab._batted_ball,
					cutaway_live and camera.shot == MatchCameraDirector.Shot.BALL_IN_PLAY
				)
	else:
		restore_presentations()
	var hidden: bool = not force_visible and not is_instance_valid(lab._batted_ball) \
		and camera.shot == MatchCameraDirector.Shot.BATTING
	var write: RefCounted = begin_visual_write(self)
	if write == null:
		return
	StadiumReceiverVisibility.apply(receiver.chair, hidden, lab._camera, lab._batted_ball)
	var style_state: String = receiver.chair.get_meta("receiver_render_state")
	if end_visual_write(write):
		_style_state = style_state
		_style_alpha = StadiumReceiverVisibility.FADED_ALPHA if _style_state == "faded" else 1.0


func restore_presentations() -> void:
	var owned: StadiumNpcRetainedActorCutaway = _owned_actor_cutaway()
	if owned != null:
		owned.restore_all()


func _process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab != null:
		refresh_receiver_presentation(lab)


func disconnect_balls() -> void:
	restore_presentations()
	_contact_token = null
	_token_args.clear()
	for reference: WeakRef in bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		var callback: Callable = _ball_contact.bind(ball, _resolver)
		if ball.body_entered.is_connected(callback):
			ball.body_entered.disconnect(callback)
		if ball.physics_contact_router == _boundary_contact_batch.bind(_resolver):
			ball.physics_contact_router = Callable()
		var forgotten: Callable = _forget_ball.bind(ball.get_instance_id())
		if ball.tree_exited.is_connected(forgotten):
			ball.tree_exited.disconnect(forgotten)
		_forget_ball(ball.get_instance_id())
	bound_balls.clear()


func _exit_tree() -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if is_instance_valid(lab):
		StadiumNpcYardTwoRuntimeV1.unexpected_exit(lab, self)
	disconnect_balls()
	bound_state = null
	for node: Node in old_nodes:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	old_nodes.clear()


func pin_signals() -> void:
	_signal_pin = _signal_data()


func _signal_data() -> Array:
	return [_actor.segment_advanced.get_connections(), _actor.flight_stopped.get_connections(),
		_actor.tree_exiting.get_connections()]


func pin_visibility() -> void:
	_visibility_pin = _visibility_data()


func visibility_intact() -> bool:
	return not _visibility_pin.is_empty() and _visibility_data() == _visibility_pin


func _visibility_data() -> Array:
	if visibility._recipe == null or visibility._wall_prisms == null:
		return []
	if not _visibility_pin.is_empty() and (visibility._recipe != _visibility_pin[4] \
		or visibility._recipe.get_script() != _visibility_pin[5] \
		or visibility._wall_prisms != _visibility_pin[8] \
		or visibility._wall_prisms.get_script() != _visibility_pin[9]):
		return []
	return [visibility._obstacles.duplicate(), visibility._uprights.duplicate(),
		visibility._wall_bounds.duplicate(), visibility.field_wall_z,
		visibility._recipe, visibility._recipe.get_script(), visibility._recipe.polygon(),
		visibility._recipe.segments(), visibility._wall_prisms,
		visibility._wall_prisms.get_script(), visibility._wall_prisms.walls.duplicate(true)]


func _member_bound(identity: String) -> bool:
	var model: Node3D = _members.get(identity)
	return is_instance_valid(model) and is_instance_valid(construction) \
		and model.get_parent() == construction and objects.get(identity) == model \
		and construction.objects.get(identity) == model \
		and model.has_meta("npc_instance") and model.get_meta("npc_instance") == identity \
		and model.has_meta("owned_copy") and model.get_meta("owned_copy") == identity


func _contact_member(body: Node) -> Dictionary:
	if not is_instance_valid(body) or not _bodies.has(body):
		return {}
	var row: Dictionary = _bodies[body]
	if not _member_bound(row.instance) or body.get_parent() != row.container \
		or row.container != row.model.get_node_or_null("Collision") \
		or body.get_children() != row.children:
		return {}
	for key: String in ["owned_copy", "npc_instance", "surface_id", "surface_role", "stadium_item"]:
		var expected: String = {"owned_copy": row.instance, "npc_instance": row.instance,
			"surface_id": row.surface, "surface_role": row.role, "stadium_item": row.item}[key]
		if not body.has_meta(key) or body.get_meta(key) != expected:
			return {}
	return row.duplicate()


func _owned_camera() -> StadiumNpcYardTwoCameraV1:
	return _support[2] if _support.size() == 7 and is_instance_valid(_support[2]) \
		and _support[2].get_script() == StadiumNpcYardTwoCameraV1 else null


func _owned_actor_presentation() -> StadiumNpcYardTwoActorPresentationV1:
	return _support[4] if _support.size() == 7 and is_instance_valid(_support[4]) \
		and _support[4].get_script() == StadiumNpcYardTwoActorPresentationV1 else null


func _owned_actor_cutaway() -> StadiumNpcRetainedActorCutaway:
	return _support[5] if _support.size() == 7 and is_instance_valid(_support[5]) \
		and _support[5].get_script() == StadiumNpcRetainedActorCutaway else null


func hot_eligible() -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if phase not in [&"ready", &"playing"] or not is_instance_valid(lab) \
		or lab.get_script() != PitchBatLab or not is_instance_valid(_actor) \
		or not is_instance_valid(_resolver) \
		or _auditing or _geometry_scanning or _visual_writing != null:
		return false
	if lab._match_state == null or lab._match_state.get_script() != MatchState \
		or (_resolver.state != null and _resolver.state.get_script() != BallPlayState) \
		or not ordinary_callbacks():
		return false
	if phase == &"ready":
		return not _actor.running and not is_instance_valid(lab._batted_ball)
	return _play_kind in [&"pitch", &"ball"] or (public_context_issued() \
		and _play_kind in [&"pitch_pending", &"ball_pending", &"reset_pending"])


func audit_installation(check_state: bool = true) -> bool:
	if phase == &"retired" or _auditing or _geometry_scanning or _visual_writing != null:
		retire_installation("reentrant or retired audit")
		return false
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var generation: int = installation_generation
	_auditing = true
	var valid: bool = StadiumNpcYardTwoRuntimeV1._installed_body(lab, self, check_state)
	_auditing = false
	valid = valid and generation == installation_generation and phase != &"retired"
	if not valid and phase != &"staging":
		retire_installation("canonical installation audit failed")
	return valid


func issue_installation() -> bool:
	if phase == &"retired" or (public_bound and not _issued_public_context.is_empty()) \
		or not audit_installation():
		return false
	_capture_physical_records()
	installation_generation += 1
	play_generation += 1
	_clear_play()
	phase = &"ready"
	if public_bound:
		_issued_public_context.merge({"generation": installation_generation,
			"snapshot": public_snapshot, "assignments": public_assignments,
			"fixture": public_fixture, "season": public_season, "state": bound_state,
			"automation": public_automation, "managed": public_managed})
		_freeze_public_context(_issued_public_context)
	return true


func public_context_intact() -> bool:
	if _issued_public_context.is_empty():
		return phase == &"staging"
	return phase in [&"ready", &"playing"] \
		and _issued_public_context.generation == installation_generation \
		and is_same(_issued_public_context.snapshot, public_snapshot) \
		and is_same(_issued_public_context.assignments, public_assignments) \
		and is_same(_issued_public_context.fixture, public_fixture) \
		and _issued_public_context.season == public_season \
		and _issued_public_context.state == bound_state \
		and _issued_public_context.automation == public_automation \
		and _issued_public_context.managed == public_managed


func public_context_issued() -> bool:
	return public_bound and not _issued_public_context.is_empty() \
		and public_context_intact() and ordinary_callbacks()


func _freeze_public_context(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values():
			_freeze_public_context(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value:
			_freeze_public_context(child)
		value.make_read_only()


func retire_installation(reason: String = "supported static edit") -> void:
	if phase == &"retired":
		return
	phase = &"retired"
	_retirement_reason = reason
	installation_generation += 1
	play_generation += 1
	_clear_play()


func _clear_play() -> void:
	_play_kind = &""
	_play_pitch = null
	_play_parameters = null
	_play_ball = null
	_play_state = null
	_camera_launch_generation = -1
	_contact_token = null
	_token_args.clear()


func begin_play(kind: StringName) -> bool:
	if phase == &"playing" and _play_kind in [&"pitch_pending", &"ball_pending", &"reset_pending"]:
		retire_installation("reentrant launch")
		return false
	if kind not in [&"pitch_pending", &"ball_pending"] or not audit_installation():
		return false
	play_generation += 1
	_clear_play()
	_play_kind = kind
	phase = &"playing"
	return true


func _play_bindings_intact() -> bool:
	if phase == &"ready":
		return not _actor.running
	if _play_kind == &"pitch":
		return _actor.state == _play_pitch and _actor.parameters == _play_parameters \
			and _play_pitch != null and _play_pitch.get_script() == PitchState \
			and _play_parameters != null and _play_parameters.get_script() == PitchLaunchParameters
	if _play_kind == &"ball":
		var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab
		return is_instance_valid(_play_ball) and lab._batted_ball == _play_ball \
			and _play_ball.get_script() == BattedBallBody and _play_ball.get_parent() == lab \
			and _play_ball.is_inside_tree() and not _play_ball.is_queued_for_deletion() \
			and _resolver.state == _play_state and _play_state != null \
			and _play_state.get_script() == BallPlayState and _resolver.field == field
	# Exact ordinary lab code owns these synchronous transitions. Every continuation
	# still checks current owners, routes, context and its caller's play generation.
	if _play_kind in [&"pitch_pending", &"ball_pending", &"reset_pending"]:
		return public_context_issued()
	return false


func begin_visual_write(writer: Object, cleanup: bool = false) -> RefCounted:
	if writer != self and writer != _owned_receiver():
		return null
	if _auditing or _geometry_scanning or _visual_writing != null:
		retire_installation("reentrant owned presentation write")
		return null
	if not cleanup and not callback_intact():
		return null
	_visual_writing = RefCounted.new()
	_visual_generation = installation_generation
	return _visual_writing


func end_visual_write(token: RefCounted) -> bool:
	if token == null or token != _visual_writing:
		return false
	var valid: bool = installation_generation == _visual_generation and phase != &"retired"
	_visual_writing = null
	return valid


func _request_interruption() -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if is_instance_valid(lab) and phase == &"retired":
		StadiumNpcYardTwoRuntimeV1.interrupt(lab, self)


func _installation_changed() -> void:
	retire_installation("owned static membership changed")
	_request_interruption()


func _capture_owner(node: Node3D) -> void:
	_owners.append({"node": node, "parent": node.get_parent(), "script": node.get_script(),
		"count": node.get_child_count(true), "pose": node.transform,
		"top_level": node.top_level, "process": node.process_mode})
	for signal_name: StringName in [&"tree_exiting", &"child_order_changed", &"script_changed"]:
		if not node.is_connected(signal_name, _installation_changed):
			node.connect(signal_name, _installation_changed)


func _capture_body(body: StaticBody3D) -> void:
	_capture_owner(body)
	_colliders.append({"node": body, "layer": body.collision_layer, "mask": body.collision_mask,
		"disable_mode": body.disable_mode,
		"surface": body.get_meta("ball_surface") if body.has_meta("ball_surface") else null,
		"segment": body.get_meta("boundary_segment") if body.has_meta("boundary_segment") else null})
	for child: Node in body.get_children(true):
		if child is CollisionShape3D:
			var shape: CollisionShape3D = child
			_capture_owner(shape)
			_shapes.append({"node": shape, "shape": shape.shape, "disabled": shape.disabled,
				"margin": shape.shape.margin if shape.shape != null else NAN,
				"bias": shape.shape.custom_solver_bias if shape.shape != null else NAN})
			if shape.shape != null and not shape.shape.changed.is_connected(_installation_changed):
				shape.shape.changed.connect(_installation_changed)


func _capture_physical_records() -> void:
	_owners.clear()
	_colliders.clear()
	_shapes.clear()
	_host_count = _host.get_child_count(true)
	_capture_owner(self)
	_capture_owner(construction)
	_capture_owner(boundary)
	# Fixed physical infrastructure and the four contact models, never a decorative walk.
	for child: Node in construction.get_children(true):
		if child is StaticBody3D:
			_capture_body(child)
	for child: Node in boundary.get_children(true):
		if child is StaticBody3D:
			_capture_body(child)
	for identity: String in _members:
		var model: Node3D = _members[identity]
		_capture_owner(model)
		var collision: Node3D = model.get_node("Collision")
		_capture_owner(collision)
		for body: StaticBody3D in collision.get_children():
			_capture_body(body)


func _physical_records_intact() -> bool:
	if _owners.is_empty() or _host.get_child_count(true) != _host_count \
		or get_script() != StadiumNpcYardTwoPropertyV1 or construction != _construction \
		or field != _field or construction.field != _field or objects != _members \
		or construction.objects != _members or boundary != _boundary \
		or field.get_script() != FieldDefinition:
		return false
	for row: Dictionary in _owners:
		var node: Node3D = row.node
		if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion() \
			or node.get_parent() != row.parent or node.get_script() != row.script \
			or node.get_child_count(true) != row.count or node.transform != row.pose \
			or node.top_level != row.top_level or node.process_mode != row.process:
			return false
	for row: Dictionary in _colliders:
		var body: StaticBody3D = row.node
		if body.collision_layer != row.layer or body.collision_mask != row.mask \
			or body.disable_mode != row.disable_mode \
			or (body.get_meta("ball_surface") if body.has_meta("ball_surface") else null) != row.surface \
			or (body.get_meta("boundary_segment") if body.has_meta("boundary_segment") else null) \
				!= row.segment:
			return false
	if not _shape_records_intact():
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		if typeof(field.get(key)) != typeof(_geometry_reference.field[key]) \
			or field.get(key) != _geometry_reference.field[key]:
			return false
	for body: StaticBody3D in _bodies:
		if _contact_member(body).is_empty():
			return false
	return field.id == _geometry_reference.field.id \
		and field.display_name == _geometry_reference.field.display_name \
		and receiver.visual_intact() and _style_intact()


func _shape_records_intact() -> bool:
	# Native margin/solver-bias setters do not emit Resource.changed on this engine.
	# Read actual current values on every issued callback; never cache admission.
	for row: Dictionary in _shapes:
		var shape: CollisionShape3D = row.node
		if shape.shape != row.shape or shape.shape == null or shape.shape.get_script() != null \
			or shape.disabled != row.disabled or shape.shape.margin != row.margin \
			or shape.shape.custom_solver_bias != row.bias:
			return false
	return true


func ordinary_callbacks() -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab == null or not is_instance_valid(_actor) or not is_instance_valid(_resolver) \
		or (_actor.state != null and _actor.state.get_script() != PitchState) \
		or (_actor.parameters != null and _actor.parameters.get_script() != PitchLaunchParameters):
		return false
	for row: Array in [[_actor.plate_crossed, lab._on_plate_crossed],
		[_actor.trace_sampled, lab._on_trace_sampled],
		[_resolver.play_resolved, lab._on_ball_play_resolved]]:
		var connections: Array = row[0].get_connections()
		if connections.size() != 1 or connections[0].callable != row[1] \
			or connections[0].flags != 0:
			return false
	return true


func _style_intact() -> bool:
	if _style_state.is_empty():
		return not receiver.chair.has_meta("receiver_render_state")
	return receiver.chair.get_meta("receiver_render_state", "") == _style_state \
		and receiver._visual.visible == (_style_state != "hidden") \
		and _style_alpha == (StadiumReceiverVisibility.FADED_ALPHA \
			if _style_state == "faded" else 1.0)
