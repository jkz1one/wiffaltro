class_name StadiumNpcAc02PublicReceiver
extends StadiumNpcRetainedClubReceiver
## AC-02/r1 identity admission and issued-owner continuation gates.
## Retained sweep/timing/flex algorithms remain unchanged; new issued callbacks are owner-bound.
# gdlint: disable=max-returns

# This binding is local to one receiver and never adopts a later property's token.
var _issued_lifetime: bool = false
var _issued_property_ref: WeakRef
var _issued_token_ref: WeakRef
var _issued_generation: int = 0
var _issued_chair: Node3D
var _issued_net: Node3D
var _issued_restoring: bool = false
var _issued_actor_ref: WeakRef
var _issued_motion_from: Vector3 = Vector3.ZERO


func configure_pair(target: Node3D, catching_net: Node3D, sound_player: PlaySounds = null) -> bool:
	if _issued_lifetime:
		cleanup_issued_local()
		return false
	if (
		not StadiumNpcAc02IssuedWritersV1.preissue_only(self, "receiver-reconfigure")
		or not StadiumNpcAc02IssuedWritersV1.preissue_only(target, "receiver-target-reconfigure")
		or not StadiumNpcAc02IssuedWritersV1.preissue_only(catching_net, "receiver-net-reconfigure")
	):
		return false
	if (
		target == null
		or catching_net == null
		or not target.has_meta("npc_instance")
		or not catching_net.has_meta("npc_instance")
		or not target.has_meta("owned_copy")
		or not catching_net.has_meta("owned_copy")
		or target.get_meta("npc_instance", "") != "npc:AC-02:r1:RECEIVER-PRIMARY"
		or catching_net.get_meta("npc_instance", "") != "npc:AC-02:r1:RECEIVER-CATCH"
		or target.get_meta("owned_copy", "") != target.get_meta("npc_instance")
		or catching_net.get_meta("owned_copy", "") != catching_net.get_meta("npc_instance")
		or target.get_meta("stadium_item", "") != "ST-026"
		or catching_net.get_meta("stadium_item", "") != "ST-073"
		or target.transform != Transform3D(Basis.IDENTITY, StadiumNpcClubTargetV1.POSITION)
		or catching_net.transform != Transform3D.IDENTITY
	):
		return false
	for surface: String in StadiumNpcClubNetV1.PANELS:
		_rest_meshes[surface] = catching_net.get_node("Visual/" + surface).mesh
	chair = target
	net = catching_net
	sounds = sound_player
	for model: Node3D in [chair, net]:
		model.process_mode = Node.PROCESS_MODE_PAUSABLE
		for body: StaticBody3D in model.get_node("Collision").get_children():
			body.collision_layer |= LAYER
	return true


func mark_issued(property: StadiumNpcPublicProperty) -> void:
	if (
		_issued_lifetime
		or not is_instance_valid(property)
		or property.receiver != self
		or not property.has_ac02_issue()
		or property._ac02_issue == null
	):
		return
	_issued_lifetime = true
	_issued_property_ref = weakref(property)
	_issued_token_ref = weakref(property._ac02_issue)
	_issued_generation = property._ac02_issue.generation
	_issued_chair = chair
	_issued_net = net
	_issued_actor_ref = weakref(property._actor)


func _issued_property() -> StadiumNpcPublicProperty:
	return (
		_issued_property_ref.get_ref() as StadiumNpcPublicProperty
		if _issued_property_ref != null
		else null
	)


func _issued_live() -> bool:
	if not _issued_lifetime:
		return true
	var property: StadiumNpcPublicProperty = _issued_property()
	var token: StadiumNpcAc02IssuedStateV1 = (
		_issued_token_ref.get_ref() as StadiumNpcAc02IssuedStateV1
		if _issued_token_ref != null
		else null
	)
	var lab: PitchBatLab = (
		property.lab_ref.get_ref() as PitchBatLab
		if is_instance_valid(property) and property.lab_ref != null
		else null
	)
	if (
		is_instance_valid(property)
		and token != null
		and property.receiver == self
		and chair == _issued_chair
		and net == _issued_net
		and token.hot_intact(lab, property, _issued_generation)
	):
		return true
	if is_instance_valid(property):
		property.ac02_revoke("receiver continuation lost owner")
	cleanup_issued_local()
	return false


func _issued_cleanup_owned() -> bool:
	var property: StadiumNpcPublicProperty = _issued_property()
	var token: StadiumNpcAc02IssuedStateV1 = (
		_issued_token_ref.get_ref() as StadiumNpcAc02IssuedStateV1
		if _issued_token_ref != null
		else null
	)
	return (
		is_instance_valid(property)
		and token != null
		and property.receiver == self
		and property._ac02_issue == token
		and property._ac02_issue_pin == token
		and get_parent() == property
		and chair == _issued_chair
		and net == _issued_net
		and property.ac02_owns_cleanup()
	)


func cleanup_issued_local() -> void:
	if not _issued_lifetime:
		return
	var token: StadiumNpcAc02IssuedStateV1 = (
		_issued_token_ref.get_ref() as StadiumNpcAc02IssuedStateV1
		if _issued_token_ref != null
		else null
	)
	if token != null:
		token.revoke("receiver local cleanup")
	# Kill only handles created by this receiver. In particular, do not call
	# actor._cancel_plate_follow_through() or change the actor's current tween/visibility.
	for tween: Tween in [_rock, _pocket, _active_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_rock = null
	_pocket = null
	_active_tween = null
	_active_actor = null


func route(actor: PitchFlightActor, start: Vector3, velocity: Vector3) -> bool:
	if not _issued_lifetime:
		return super.route(actor, start, velocity)
	if (
		not _issued_live()
		or not is_instance_valid(actor)
		or _issued_actor_ref == null
		or _issued_actor_ref.get_ref() != actor
		or not start.is_finite()
		or not velocity.is_finite()
	):
		return false
	last_reason = ""
	var radius: float = actor.parameters.radius_m if actor.parameters != null else 0.0365
	var path: Dictionary = trace(start, velocity, radius)
	if path.is_empty() or not _issued_live():
		return false
	_cancel_active(actor)
	actor._cancel_plate_follow_through()
	if not _issued_live():
		return false
	_active_actor = weakref(actor)
	actor._plate_follow_tween = actor.create_tween().bind_node(actor)
	_active_tween = actor._plate_follow_tween
	_issued_motion_from = actor.global_position
	var hide_at: float = (
		path.hide_at if camera_protection.is_valid() and camera_protection.call() else -1.0
	)
	if not _issued_active_actor(actor):
		return false
	if hide_at == 0:
		_hide_issued_actor(actor)
		hide_at = -1
	for index in range(1, path.points.size()):
		if not _issued_active_actor(actor):
			return false
		var from_time: float = path.times[index - 1]
		var to_time: float = path.times[index]
		if hide_at >= from_time and hide_at <= to_time:
			var fraction: float = (
				0 if to_time <= from_time else (inverse_lerp(from_time, to_time, hide_at))
			)
			_motion(
				actor,
				path.points[index - 1].lerp(path.points[index], fraction),
				hide_at - from_time
			)
			_active_tween.tween_callback(_hide_issued_actor.bind(actor))
			from_time = hide_at
			hide_at = -1
		_motion(actor, path.points[index], to_time - from_time)
	if not _issued_active_actor(actor):
		return false
	_active_tween.tween_callback(_finish.bind(actor, path))
	return true


func _issued_active_actor(actor: PitchFlightActor) -> bool:
	if (
		not _issued_live()
		or not is_instance_valid(actor)
		or _issued_actor_ref == null
		or _issued_actor_ref.get_ref() != actor
		or _active_actor == null
		or _active_actor.get_ref() != actor
		or _active_tween == null
		or actor._plate_follow_tween != _active_tween
	):
		cleanup_issued_local()
		return false
	return true


func _motion(actor: PitchFlightActor, point: Vector3, duration: float) -> void:
	if not _issued_lifetime:
		super._motion(actor, point, duration)
		return
	if not _issued_active_actor(actor):
		return
	# Same linear endpoints and durations as the inherited property tween. Every
	# actual write now checks its captured issue, rather than trusting a queued tween.
	(
		_active_tween
		. tween_method(
			_move_issued_actor.bind(actor), _issued_motion_from, point, maxf(0.000001, duration)
		)
		. set_trans(Tween.TRANS_LINEAR)
	)
	_issued_motion_from = point


func _move_issued_actor(point: Vector3, actor: PitchFlightActor) -> void:
	if _issued_active_actor(actor):
		actor.global_position = point


func _hide_issued_actor(actor: PitchFlightActor) -> void:
	if _issued_active_actor(actor):
		actor.visible = false


func _flex(elapsed: float) -> void:
	if _issued_live():
		super._flex(elapsed)


func _flex_net(elapsed: float, surface: String, point: Vector3) -> void:
	if _issued_live():
		super._flex_net(elapsed, surface, point)


func _restore_panel(surface: String) -> void:
	if not _issued_lifetime or (_issued_restoring and _issued_cleanup_owned()) or _issued_live():
		super._restore_panel(surface)


func present_contact(hit: Dictionary, kind: String) -> void:
	if _issued_live():
		super.present_contact(hit, kind)


func _finish(actor: PitchFlightActor, path: Dictionary) -> void:
	if not _issued_lifetime:
		super._finish(actor, path)
		return
	if (
		not _issued_live()
		or not is_instance_valid(actor)
		or _active_actor == null
		or _active_actor.get_ref() != actor
		or actor._plate_follow_tween != _active_tween
	):
		cleanup_issued_local()
		return
	last_reason = path.reason
	if not path.hit.is_empty():
		present_contact(path.hit, "pitch")
	if _issued_active_actor(actor):
		actor.visible = false
		if _issued_active_actor(actor):
			actor._plate_follow_tween = null
	_active_actor = null
	_active_tween = null


func _cancel_active(keep_visible: PitchFlightActor = null) -> void:
	if _issued_lifetime and not _issued_cleanup_owned():
		cleanup_issued_local()
		return
	super._cancel_active(keep_visible)


func _exit_tree() -> void:
	if not _issued_lifetime:
		super._exit_tree()
		return
	var property: StadiumNpcPublicProperty = _issued_property()
	if is_instance_valid(property):
		property.ac02_revoke("receiver tree exit")
	if not _issued_cleanup_owned():
		cleanup_issued_local()
		return
	# Original retained cleanup, with a fresh owner proof between borrowed-owner writes.
	_cancel_active()
	if not _issued_cleanup_owned():
		cleanup_issued_local()
		return
	if _rock != null and _rock.is_valid():
		_rock.kill()
	if is_instance_valid(chair):
		StadiumNpcClubTargetV1.flex(chair, 0.18)
	if not _issued_cleanup_owned():
		cleanup_issued_local()
		return
	if _pocket != null and _pocket.is_valid():
		_pocket.kill()
	if is_instance_valid(net) and not flex_surface.is_empty():
		_issued_restoring = true
		_restore_panel(flex_surface)
		_issued_restoring = false
	cleanup_issued_local()
