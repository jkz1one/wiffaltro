class_name StadiumNpcBoundProperty
extends StadiumNpcRetainedProperty
## Explicit cleanup/rebind seam for raw fixture17. Retained candidate lifecycle is not called.

var context: StadiumNpcQualificationContext
var frozen_snapshot: Dictionary = {}
var frozen_key: String
var old_receiver: Callable
var suspended: bool = false
var resume_mode: int = -1
var quarantined_resolved_flags: int = -1


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if not StadiumNpcRuntime.bind_ball(lab, ball, resolver, context):
		pause_invalid()


func bind_contacts(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	# Boundary binding seeds AC's current position even when launch already occurred.
	# Repeated binding must not accumulate duplicate WeakRefs or signal callbacks.
	for reference: WeakRef in bound_balls:
		if reference.get_ref() == ball:
			return
	bound_balls.assign(bound_balls.filter(func(reference: WeakRef) -> bool:
		return is_instance_valid(reference.get_ref())))
	super.bind_ball(ball, resolver)


func rebind(state: MatchState) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if context == null or state != context._match or not context.matches(lab):
		pause_invalid()
		return
	if not suspended:
		super.rebind(state)


func refresh_receiver_presentation(lab: PitchBatLab, force_visible: bool = false) -> void:
	# Generic presentation runs before generic bind_ball. Never silently rebind stale authority.
	if context == null or not context.matches(lab):
		pause_invalid()
		return
	if not suspended:
		super.refresh_receiver_presentation(lab, force_visible)


func _process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab == null:
		return
	rebind(lab._match_state)
	if not suspended:
		refresh_actor_presentation(lab)


func _physics_process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab != null and (context == null or not context.matches(lab)):
		pause_invalid()


func pause_invalid() -> void:
	if suspended:
		return
	suspended = true
	restore_presentations()
	if is_instance_valid(display):
		display.bind_match(null)
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if is_instance_valid(lab):
		resume_mode = lab.process_mode
		lab.process_mode = Node.PROCESS_MODE_DISABLED
		# Child physics actors may be explicitly PAUSABLE; disabling the parent is insufficient.
		if is_instance_valid(lab._batted_ball):
			lab._batted_ball.freeze = true
			lab._batted_ball.process_mode = Node.PROCESS_MODE_DISABLED
			lab._batted_ball.set_process(false)
			lab._batted_ball.set_physics_process(false)
			if lab._batted_ball.surface_contact.is_connected(lab._on_batted_surface_contact):
				lab._batted_ball.surface_contact.disconnect(lab._on_batted_surface_contact)
		disconnect_balls()
		for connection: Dictionary in lab._ball_play_resolver.play_resolved.get_connections():
			if connection.callable == lab._on_ball_play_resolved:
				quarantined_resolved_flags = connection.flags
				lab._ball_play_resolver.play_resolved.disconnect(connection.callable)
		lab._ball_play_resolver.segment_observer = Callable()
		lab._pitch_actor.receiver_router = Callable()
		lab._pitch_actor.reset_pitch()
		lab._release_controller.cancel()
		lab._at_bat_cadence.stop()
		# Do not rewrite the fixture, settle the resolver or manufacture a result.


func restore_resolved_connection(lab: PitchBatLab) -> void:
	if quarantined_resolved_flags >= 0:
		if not lab._ball_play_resolver.play_resolved.is_connected(lab._on_ball_play_resolved):
			lab._ball_play_resolver.play_resolved.connect(
				lab._on_ball_play_resolved, quarantined_resolved_flags)
		quarantined_resolved_flags = -1


func disconnect_balls() -> void:
	for reference: WeakRef in bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		var ball_id: int = ball.get_instance_id()
		if boundary is StadiumNpcRetainedClubBoundary:
			boundary._disconnect_ball(ball)
			boundary._forget(ball_id, boundary._resolver_ids.get(ball_id, -1))
		else:
			boundary._forget(ball_id)
	super.disconnect_balls()
	if boundary is StadiumNpcRetainedClubBoundary:
		boundary._bound_balls.clear()
		boundary._previous.clear()
		boundary._resolver_ids.clear()
		boundary.last_live.clear()
	elif is_instance_valid(boundary):
		boundary._touching.clear()


func _exit_tree() -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if is_instance_valid(lab):
		StadiumNpcRuntime.unexpected_exit(lab, self)
	disconnect_balls()
	if is_instance_valid(display):
		display.bind_match(null)
	for node: Node in old_nodes:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	old_nodes.clear()
	context = null
	frozen_snapshot.clear()
	frozen_key = ""
