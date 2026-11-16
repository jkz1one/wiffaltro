class_name StadiumClubPitchReceiver
extends StadiumTargetReceiver
## Corrected ST-073 pair: visual camera cut is separate from physical containment and logical calls.

const PAIR_VERSION: int = 1
const PAIR_TIMEOUT: float = 0.38
const PAIR_CLEANUP: float = -5.2
const CAMERA_CUT: float = -3.1
var net: Node3D
var camera_protection: Callable
var _pocket: Tween
var _flex_surface: String = ""
var _active_actor: WeakRef
var _active_tween: Tween


func configure(_model: Node3D, _sound_player: PlaySounds = null) -> bool:
	return false


func configure_pair(target: Node3D, catching_net: Node3D,
	sound_player: PlaySounds = null) -> bool:
	if target == null or catching_net == null \
		or catching_net.get_meta("stadium_item", "") != "ST-073" \
		or not catching_net.has_meta("owned_copy") \
		or target.get_meta("owned_copy", "") == catching_net.get_meta("owned_copy"):
		return false
	if not catching_net.global_transform.is_equal_approx(Transform3D.IDENTITY) \
		or not target.global_transform.is_equal_approx(Transform3D(
			Basis.IDENTITY, StadiumTargetModels.POSITION)):
		return false
	if not super.configure(target, sound_player):
		return false
	net = catching_net
	net.process_mode = Node.PROCESS_MODE_PAUSABLE
	for body: StaticBody3D in net.get_node("Collision").get_children():
		body.collision_layer |= LAYER
	return true


func trace(start: Vector3, velocity: Vector3, radius: float) -> Dictionary:
	if not start.is_finite() or not velocity.is_finite() or not is_finite(radius) or radius <= 0:
		return {}
	var points: Array[Vector3] = [start]
	var times: Array[float] = [0.0]
	var end: float = PAIR_TIMEOUT
	var hide_at: float = -1
	var reason: String = "receiver_presentation_timeout"
	if velocity.z < -0.001:
		var cleanup: float = (PAIR_CLEANUP - start.z) / velocity.z
		if cleanup <= end:
			end = maxf(0, cleanup)
			reason = "receiver_cleanup"
		var camera_time: float = (CAMERA_CUT - start.z) / velocity.z
		if start.z <= CAMERA_CUT and absf(start.x) <= 2.5:
			hide_at = 0
		elif camera_time >= 0 and absf(start.x + velocity.x * camera_time) <= 2.5:
			hide_at = camera_time
	var previous: Vector3 = start
	var elapsed: float = 0
	while elapsed < end:
		var next_time: float = minf(elapsed + STEP, end)
		var next: Vector3 = start + velocity * next_time + Vector3.DOWN * 4.9 * next_time * next_time
		var hit: Dictionary = _sweep(previous, next, radius)
		if not hit.is_empty():
			var contact_time: float = lerpf(elapsed, next_time, hit.fraction)
			points.append(previous.lerp(next, hit.fraction))
			times.append(contact_time)
			hit["elapsed"] = contact_time
			return {"points": points, "times": times, "hit": hit,
				"reason": "receiver_contact", "hide_at": hide_at}
		points.append(next)
		times.append(next_time)
		previous = next
		elapsed = next_time
	return {"points": points, "times": times, "hit": {}, "reason": reason, "hide_at": hide_at}


func route(actor: PitchFlightActor, start: Vector3, velocity: Vector3) -> bool:
	if not is_instance_valid(chair) or not is_instance_valid(net) or not is_instance_valid(actor) \
		or not start.is_finite() or not velocity.is_finite():
		return false
	last_reason = ""
	var radius: float = actor.parameters.radius_m if actor.parameters != null else 0.0365
	var path: Dictionary = trace(start, velocity, radius)
	if path.is_empty():
		return false
	_cancel_active(actor)
	actor._cancel_plate_follow_through()
	_active_actor = weakref(actor)
	actor._plate_follow_tween = actor.create_tween().bind_node(actor)
	_active_tween = actor._plate_follow_tween
	var hide_at: float = path.hide_at if camera_protection.is_valid() \
		and camera_protection.call() else -1.0
	if hide_at == 0:
		actor.visible = false
		hide_at = -1
	for index in range(1, path.points.size()):
		var from_time: float = path.times[index - 1]
		var to_time: float = path.times[index]
		if hide_at >= from_time and hide_at <= to_time:
			var fraction: float = 0 if to_time <= from_time else (
				inverse_lerp(from_time, to_time, hide_at))
			_motion(actor, path.points[index - 1].lerp(path.points[index], fraction), hide_at - from_time)
			actor._plate_follow_tween.tween_callback(func() -> void: actor.visible = false)
			from_time = hide_at
			hide_at = -1
		_motion(actor, path.points[index], to_time - from_time)
	actor._plate_follow_tween.tween_callback(_finish.bind(actor, path))
	return true


func _motion(actor: PitchFlightActor, point: Vector3, duration: float) -> void:
	actor._plate_follow_tween.tween_property(actor, "global_position", point,
		maxf(0.000001, duration)).set_trans(Tween.TRANS_LINEAR)


func _owned_hit(hit: Dictionary, fraction: float) -> Dictionary:
	var primary: Dictionary = super._owned_hit(hit, fraction)
	if not primary.is_empty() or hit.is_empty() or not is_instance_valid(net):
		return primary
	var body: Node = instance_from_id(int(hit.collider_id))
	if body == null or not net.is_ancestor_of(body) or not body.has_meta("owned_copy"):
		return {}
	return {"copy": body.get_meta("owned_copy"), "surface": body.get_meta("surface_id"),
		"position": hit.point, "fraction": fraction}


func present_contact(hit: Dictionary, kind: String) -> void:
	if is_instance_valid(chair) and hit.get("copy") == chair.get_meta("owned_copy"):
		super.present_contact(hit, kind)
		return
	if not is_instance_valid(net) or kind not in ["pitch", "batted"] \
		or hit.get("copy") != net.get_meta("owned_copy"):
		return
	contacts.append({"kind": kind, "copy": hit.copy, "surface": hit.surface,
		"elapsed": hit.elapsed, "position": [hit.position.x, hit.position.y, hit.position.z]})
	if is_instance_valid(sounds):
		sounds.play(&"net_cord" if StadiumReceiverNetModels.PANELS.has(hit.surface) else &"net_frame")
	if _pocket != null and _pocket.is_valid():
		_pocket.kill()
	if not _flex_surface.is_empty():
		StadiumReceiverNetModels.flex(net, _flex_surface, StadiumReceiverNetModels.SETTLE, Vector3.ZERO)
	_flex_surface = ""
	if StadiumReceiverNetModels.PANELS.has(hit.surface):
		_flex_surface = hit.surface
		_pocket = net.create_tween().bind_node(net)
		_pocket.tween_method(_flex_net.bind(hit.surface, hit.position),
			0.0, StadiumReceiverNetModels.SETTLE, StadiumReceiverNetModels.SETTLE)


func _flex_net(elapsed: float, surface: String, point: Vector3) -> void:
	if is_instance_valid(net):
		StadiumReceiverNetModels.flex(net, surface, elapsed, point)


func _finish(actor: PitchFlightActor, path: Dictionary) -> void:
	super._finish(actor, path)
	_active_actor = null
	_active_tween = null


func _cancel_active(keep_visible: PitchFlightActor = null) -> void:
	if _active_actor != null and is_instance_valid(_active_actor.get_ref()):
		var actor: PitchFlightActor = _active_actor.get_ref()
		if actor._plate_follow_tween == _active_tween:
			actor._cancel_plate_follow_through()
			if actor != keep_visible:
				actor.visible = false
	_active_actor = null
	_active_tween = null


func _exit_tree() -> void:
	_cancel_active()
	if _rock != null and _rock.is_valid():
		_rock.kill()
	if is_instance_valid(chair):
		StadiumTargetModels.flex(chair, 0.18)
	if _pocket != null and _pocket.is_valid():
		_pocket.kill()
	if is_instance_valid(net) and not _flex_surface.is_empty():
		StadiumReceiverNetModels.flex(net, _flex_surface, StadiumReceiverNetModels.SETTLE, Vector3.ZERO)
