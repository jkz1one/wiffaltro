class_name StadiumNpcYardTwoReceiverV1
extends StadiumPitchReceiver
## Private retained chair adapter. Shared sweep, path and timing arithmetic stay inherited.
# gdlint: disable=max-returns

const COPY: String = StadiumNpcYardTwoV1.PREFIX + "RECEIVER-PRIMARY"
var property: StadiumNpcYardTwoPropertyV1
var _bound_chair: Node3D
var _visual: Node3D
var _actor: PitchFlightActor
var _pitch_state: PitchState
var _pitch_parameters: PitchLaunchParameters
var _pitch_epoch: int = 0
var _last_substep: int = 0
var _epoch: int = 0
var _follow: Tween
var _follow_state: PitchState
var _follow_parameters: PitchLaunchParameters
var _issued_path: Dictionary = {}
var _issued_bytes: PackedByteArray = []
var _segment_ticket: Dictionary = {}
var _route_ticket: Dictionary = {}
var _presentation_token: RefCounted
var _presentation_hit: Dictionary = {}
var _owned_rock: Tween
var _rock_epoch: int = 0
var _rock_token: RefCounted
var _rock_settled: bool = true
var _applied: Dictionary = {}
var _baseline_visual: Transform3D
var _last_visual: Transform3D
var _pitch_installation: int = -1
var _pitch_play: int = -1
var _follow_installation: int = -1
var _follow_play: int = -1
var _rock_installation: int = -1
var _rock_play: int = -1


func configure(_model: Node3D, _sound_player: PlaySounds = null) -> bool:
	return false


func configure_candidate(candidate: StadiumNpcYardTwoPropertyV1,
	sound_player: PlaySounds) -> bool:
	if property != null or candidate == null or is_inside_tree():
		return false
	var model: Node3D = candidate.objects.get(COPY) as Node3D
	if model == null or model.get_meta("stadium_item", "") != "ST-079" \
		or not candidate.model_intact(COPY):
		return false
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if candidate.contact_identity(body).is_empty():
			return false
	property = candidate
	_bound_chair = model
	_visual = model.get_node("Visual") as Node3D
	_baseline_visual = _visual.transform
	_last_visual = _baseline_visual
	return super.configure(model, sound_player)


func structure_bound() -> bool:
	if not is_instance_valid(property) or not is_instance_valid(chair) \
		or chair != _bound_chair or get_parent() != property \
		or property._owned_receiver() != self or property.receiver != self \
		or property.get_node_or_null("PitchReceiverPresentation") != self \
		or property.objects.get(COPY) != chair or not property._member_bound(COPY) \
		or chair.get_node_or_null("Visual") != _visual:
		return false
	for body: StaticBody3D in chair.get_node("Collision").get_children():
		if property._contact_member(body).is_empty():
			return false
	return true


func bound(check_state: bool = true) -> bool:
	return structure_bound() and property.binding_valid(check_state)


func bind_actor(actor: PitchFlightActor) -> bool:
	if _actor != null or not is_instance_valid(actor) or actor.receiver_router.is_valid() \
		or not bound():
		return false
	var lab: PitchBatLab = property.lab_ref.get_ref() as PitchBatLab
	if lab == null or lab._pitch_actor != actor or lab.get_node_or_null("PitchFlightActor") != actor:
		return false
	_actor = actor
	actor.receiver_router = route
	actor.segment_advanced.connect(_segment_advanced)
	actor.flight_stopped.connect(_flight_stopped)
	actor.tree_exiting.connect(_actor_exiting)
	return true


func owns_actor(actor: PitchFlightActor, check_state: bool = true) -> bool:
	return actor_wiring(actor) and bound(check_state)


func actor_wiring(actor: PitchFlightActor) -> bool:
	return is_instance_valid(actor) and actor == _actor and actor.receiver_router == route \
		and actor.segment_advanced.is_connected(_segment_advanced) \
		and actor.flight_stopped.is_connected(_flight_stopped) \
		and actor.tree_exiting.is_connected(_actor_exiting)


func _callback_owned() -> bool:
	# callback_intact owns the current binding and receiver structure checks.
	return actor_wiring(_actor) and is_instance_valid(property) and property.callback_intact()


func _segment_advanced(previous: Vector3, previous_elapsed: float) -> void:
	_segment_ticket.clear()
	_route_ticket.clear()
	if not _callback_owned() or not _actor.running or _actor.state == null \
		or _actor.parameters == null or not previous.is_finite() \
		or not is_finite(previous_elapsed) or previous_elapsed < 0 \
		or _actor.state.elapsed_time != previous_elapsed + PitchFlightSolver.SUBSTEP_SECONDS:
		return
	# start_pitch allocates the state. Admit its first actual substep, then exact increasing
	# source substeps; a late copied route payload cannot create this launch ownership.
	if _actor.state != _pitch_state or _actor.parameters != _pitch_parameters:
		if _actor._substep_count != 1 or previous_elapsed != 0.0 \
			or previous != _actor.parameters.position:
			return
		_pitch_state = _actor.state
		_pitch_parameters = _actor.parameters
		_pitch_epoch += 1
		_pitch_installation = property.installation_generation
		_pitch_play = property.play_generation
		_last_substep = 0
	if _actor._substep_count != _last_substep + 1 \
		or _pitch_installation != property.installation_generation \
		or _pitch_play != property.play_generation:
		return
	_last_substep = _actor._substep_count
	var current: Vector3 = _actor.state.position
	if previous.z <= _actor.plate_z or current.z > _actor.plate_z:
		return
	var denominator: float = previous.z - current.z
	var fraction: float = 1.0
	if absf(denominator) > 0.000001:
		fraction = clampf((previous.z - _actor.plate_z) / denominator, 0.0, 1.0)
	_segment_ticket = {"state": _actor.state, "parameters": _actor.parameters,
		"position": previous.lerp(current, fraction), "velocity": _actor.state.velocity,
		"tick": Engine.get_physics_frames(), "epoch": _pitch_epoch, "step": _last_substep,
		"installation": _pitch_installation, "play": _pitch_play}


func _flight_stopped(reason: StringName) -> void:
	_route_ticket.clear()
	if reason != &"plate_crossed" or _segment_ticket.is_empty() or not _callback_owned() \
		or _actor.running or _actor.state != _segment_ticket.state \
		or _actor.parameters != _segment_ticket.parameters \
		or _actor.state.position != _segment_ticket.position \
		or _actor.global_position != _segment_ticket.position \
		or _pitch_epoch != _segment_ticket.epoch \
		or _segment_ticket.installation != property.installation_generation \
		or _segment_ticket.play != property.play_generation \
		or _actor._substep_count != _segment_ticket.step \
		or Engine.get_physics_frames() != _segment_ticket.tick:
		_segment_ticket.clear()
		return
	_route_ticket = _segment_ticket
	_segment_ticket = {}


func route(actor: PitchFlightActor, start: Vector3, velocity: Vector3) -> bool:
	if not _callback_owned() or actor != _actor or _route_ticket.is_empty() or actor.running \
		or actor.state != _route_ticket.state or actor.parameters != _route_ticket.parameters \
		or start != _route_ticket.position or velocity != _route_ticket.velocity \
		or _pitch_epoch != _route_ticket.epoch or actor._substep_count != _route_ticket.step \
		or _route_ticket.installation != property.installation_generation \
		or _route_ticket.play != property.play_generation \
		or Engine.get_physics_frames() != _route_ticket.tick:
		return false
	_route_ticket.clear()
	_cancel_follow()
	_follow_state = actor.state
	_follow_parameters = actor.parameters
	_follow_installation = property.installation_generation
	_follow_play = property.play_generation
	_epoch += 1
	last_reason = ""
	var radius: float = actor.parameters.radius_m if actor.parameters != null else (
		ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID).aero_profile.radius_m)
	var path: Dictionary = trace(start, velocity, radius)
	_issued_path = path
	_issued_bytes = var_to_bytes(path)
	_follow = actor.create_tween().bind_node(actor)
	actor._plate_follow_tween = _follow
	for index in range(1, path.points.size()):
		_follow.tween_property(actor, "global_position", path.points[index],
			maxf(0.000001, path.times[index] - path.times[index - 1])).set_trans(Tween.TRANS_LINEAR)
	_follow.tween_callback(_finish_owned.bind(actor, path, _epoch, _follow))
	return true


func _owned_hit(hit: Dictionary, fraction: float) -> Dictionary:
	if hit.is_empty() or not _callback_owned() or typeof(hit.get("collider_id")) != TYPE_INT \
		or not hit.get("point") is Vector3 or not hit.point.is_finite() \
		or not is_finite(fraction) or fraction < 0 or fraction > 1:
		return {}
	var body: Node = instance_from_id(int(hit.collider_id)) as Node
	var row: Dictionary = property.contact_identity(body)
	if row.is_empty() or row.model != _bound_chair:
		return {}
	return super._owned_hit(hit, fraction)


func _finish(_actor_argument: PitchFlightActor, _path: Dictionary) -> void:
	return


func _finish_owned(actor: PitchFlightActor, path: Dictionary, epoch: int,
	follow: Tween) -> void:
	if not _callback_owned() or actor != _actor \
		or epoch != _epoch or follow != _follow or follow == null or not follow.is_valid() \
		or actor.state != _follow_state or actor.parameters != _follow_parameters \
		or _follow_installation != property.installation_generation \
		or _follow_play != property.play_generation \
		or actor._plate_follow_tween != follow or not is_same(path, _issued_path) \
		or var_to_bytes(path) != _issued_bytes:
		return
	_issued_path = {}
	_issued_bytes.clear()
	last_reason = path.reason
	if not path.hit.is_empty():
		var token: RefCounted = RefCounted.new()
		_presentation_token = token
		_presentation_hit = path.hit
		_present_issued(path.hit, "pitch", token)
	actor._hide_after_plate_follow_through()
	_follow = null
	_follow_state = null
	_follow_parameters = null


func present_contact(_hit: Dictionary, _kind: String) -> void:
	# Public dictionaries, including copies of actual traces, convey no issued provenance.
	return


func dispatch_batted_contact(body: Node, ball: BattedBallBody, resolver: BallPlayResolver,
	position: Vector3, token: RefCounted) -> bool:
	if not _callback_owned() or not is_instance_valid(ball) or resolver == null \
		or resolver.state == null or not position.is_finite():
		return false
	var row: Dictionary = property.contact_identity(body)
	if row.is_empty() or row.model != _bound_chair \
		or not property.consume_receiver_contact(body, ball, resolver, position, token):
		return false
	_presentation_token = token
	_presentation_hit = {"copy": COPY, "surface": row.surface, "position": position,
		"elapsed": resolver.state.elapsed_seconds}
	return _present_issued(_presentation_hit, "batted", token)


func _present_issued(hit: Dictionary, kind: String, token: RefCounted) -> bool:
	if token == null or token != _presentation_token or not is_same(hit, _presentation_hit):
		return false
	_presentation_token = null
	_presentation_hit = {}
	if not _callback_owned() or kind not in ["pitch", "batted"] or hit.get("copy") != COPY \
		or not hit.get("surface") is String or not hit.get("position") is Vector3 \
		or not hit.position.is_finite() or typeof(hit.get("elapsed")) != TYPE_FLOAT \
		or not is_finite(hit.elapsed) or hit.elapsed < 0 \
		or not StadiumNpcYardTwoStarterV1.surfaces("ST-079").has(hit.surface):
		return false
	contacts.append({"kind": kind, "copy": hit.copy, "surface": hit.surface,
		"elapsed": hit.elapsed, "position": [hit.position.x, hit.position.y, hit.position.z]})
	if is_instance_valid(sounds):
		sounds.play(_cue(hit.surface))
	if _owned_rock != null and _owned_rock.is_valid():
		_owned_rock.kill()
	var local_x: float = chair.to_local(hit.position).x
	_rock_epoch += 1
	_rock_installation = property.installation_generation
	_rock_play = property.play_generation
	_rock_token = RefCounted.new()
	_rock_settled = false
	_rock = chair.create_tween().bind_node(chair)
	_owned_rock = _rock
	_rock.tween_method(_rock_step.bind(local_x, _impacts, _rock_epoch, _rock_token), 0.0, 0.28, 0.28)
	_rock.tween_callback(_rock_finished.bind(_rock_epoch, _rock_token))
	_impacts += 1
	return true


func _animate(_elapsed: float, _local_x: float, _index: int) -> void:
	return


func _rock_step(elapsed: float, local_x: float, index: int, epoch: int,
	token: RefCounted) -> void:
	if not _callback_owned() or epoch != _rock_epoch or token != _rock_token \
		or _rock != _owned_rock or _owned_rock == null or not _owned_rock.is_valid() \
		or _rock_installation != property.installation_generation \
		or _rock_play != property.play_generation \
		or _visual.transform != _last_visual \
		or not is_finite(elapsed) or elapsed < 0 or elapsed > 0.28:
		return
	var write: RefCounted = property.begin_visual_write(self)
	if write == null:
		return
	StadiumNpcYardTwoStarterV1.receiver_rock(chair, local_x, elapsed, index)
	var applied_pose: Transform3D = _visual.transform
	if property.end_visual_write(write):
		_last_visual = applied_pose
		_applied = {"elapsed": elapsed, "local_x": local_x, "index": index, "epoch": epoch}


func _rock_finished(epoch: int, token: RefCounted) -> void:
	if _callback_owned() and epoch == _rock_epoch and token == _rock_token \
		and _rock_installation == property.installation_generation \
		and _rock_play == property.play_generation \
		and not _applied.is_empty() and _applied.epoch == epoch and _applied.elapsed == 0.28:
		_rock_settled = true


func copy_owned_rock(expected_chair: Node3D) -> bool:
	# Pure geometry reproduction: no callback_intact/bound recursion or foreign normalization.
	if not is_instance_valid(_bound_chair) or chair != _bound_chair \
		or not is_instance_valid(_visual) or chair.get_node_or_null("Visual") != _visual \
		or _rock != _owned_rock or _visual.transform != _last_visual or expected_chair == null \
		or expected_chair.get_meta("stadium_item", "") != "ST-079":
		return false
	var expected: Node3D = expected_chair.get_node_or_null("Visual") as Node3D
	if expected == null or expected.transform != _baseline_visual:
		return false
	if not _rock_settled and (_owned_rock == null or not _owned_rock.is_valid()):
		return false
	if _applied.is_empty():
		return _last_visual == _baseline_visual
	if _rock_token == null or int(_applied.epoch) <= 0 or int(_applied.epoch) > _rock_epoch:
		return false
	StadiumNpcYardTwoStarterV1.receiver_rock(expected_chair, _applied.local_x,
		_applied.elapsed, _applied.index)
	return expected.transform == _last_visual


func _cancel_follow() -> void:
	if _follow != null and _follow.is_valid():
		_follow.kill()
	if is_instance_valid(_actor) and _actor._plate_follow_tween == _follow:
		_actor._plate_follow_tween = null
	_follow = null
	_follow_state = null
	_follow_parameters = null
	_issued_path = {}
	_issued_bytes.clear()


func reset_play() -> void:
	_epoch += 1
	_rock_epoch += 1
	_segment_ticket.clear()
	_route_ticket.clear()
	_presentation_token = null
	_presentation_hit = {}
	_cancel_follow()
	if _owned_rock != null and _owned_rock.is_valid():
		_owned_rock.kill()
	if _rock == _owned_rock:
		_rock = null
	_owned_rock = null
	_rock_settled = true
	_rock_token = null
	if is_instance_valid(_visual) and _visual.transform == _last_visual:
		var write: RefCounted = property.begin_visual_write(self, true) \
			if is_instance_valid(property) else null
		if write != null:
			_visual.transform = _baseline_visual
			_last_visual = _baseline_visual
			_applied.clear()
			property.end_visual_write(write)
	_pitch_state = null
	_pitch_parameters = null
	_last_substep = 0


func cancel_owned() -> void:
	reset_play()
	if is_instance_valid(_actor):
		if _actor.receiver_router == route:
			_actor.receiver_router = Callable()
		if _actor.segment_advanced.is_connected(_segment_advanced):
			_actor.segment_advanced.disconnect(_segment_advanced)
		if _actor.flight_stopped.is_connected(_flight_stopped):
			_actor.flight_stopped.disconnect(_flight_stopped)
		if _actor.tree_exiting.is_connected(_actor_exiting):
			_actor.tree_exiting.disconnect(_actor_exiting)
	_actor = null
	_pitch_state = null
	_pitch_parameters = null
	_last_substep = 0


func _latch_owned_interruption() -> void:
	# Child/actor exit can precede explicit teardown. Cancellation must not erase evidence.
	if is_instance_valid(property) and property._owned_receiver() == self \
		and has_owned_activity():
		property._exit_had_owned_activity = true


func _actor_exiting() -> void:
	_latch_owned_interruption()
	cancel_owned()


func _exit_tree() -> void:
	_latch_owned_interruption()
	cancel_owned()


func has_owned_activity() -> bool:
	return (_follow != null and _follow.is_valid()) \
		or (_owned_rock != null and _owned_rock.is_valid())


func visual_intact() -> bool:
	# Only the receiver's owned dynamic transform/tween; no material or mesh enumeration.
	return is_instance_valid(_visual) and is_instance_valid(_bound_chair) \
		and _bound_chair.get_node_or_null("Visual") == _visual \
		and _visual.get_script() == null and _visual.get_parent() == _bound_chair \
		and _visual.transform == _last_visual and _rock == _owned_rock \
		and (_rock_settled or (_owned_rock != null and _owned_rock.is_valid()))
