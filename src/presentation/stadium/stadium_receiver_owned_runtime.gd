class_name StadiumReceiverOwnedRuntime
extends StadiumClubPitchReceiver
## Exact paid catching assembly; inherited bounded pitch routing and cancellation.

var primary: Node3D
var property: StadiumPropertyGeometry
var visibility: StadiumReceiverOwnedVisibility
var _models: Dictionary = {}
var _bodies: Dictionary = {}


func configure_owned(
	owner: StadiumPropertyGeometry, target: Node3D, catcher: Node3D, sound_player: PlaySounds = null
) -> bool:
	if (
		property != null
		or not is_instance_valid(owner)
		or not owner.props_intact()
		or not is_instance_valid(catcher)
		or catcher.get_meta("stadium_item", "") not in ["ST-072", "ST-073"]
	):
		return false
	property = owner
	primary = target
	net = catcher
	# The inherited route only requires a physical host, not a fictitious default primary.
	chair = primary if is_instance_valid(primary) else net
	sounds = sound_player
	var models: Array[Node3D] = [net]
	if is_instance_valid(primary):
		if primary.get_meta("stadium_item", "") not in ["ST-026", "ST-079"]:
			return false
		models.append(primary)
	for model: Node3D in models:
		var copy: String = model.get_meta("owned_copy", "")
		if copy.is_empty() or owner.objects.get(copy) != model or model.get_parent() != owner:
			return false
		_models[copy] = model
		var expected_mask: int = 0 if model.get_meta("stadium_item") == "ST-079" else 2
		for body: StaticBody3D in model.get_node("Collision").get_children():
			if body.collision_layer != (1 | LAYER) or body.collision_mask != expected_mask:
				return false
			_bodies[body] = {
				"model": model, "copy": copy, "surface": body.get_meta("surface_id", "")
			}
	return intact()


func intact() -> bool:
	if not is_instance_valid(property) or get_parent() != property or not property.props_intact():
		return false
	for copy: String in _models:
		if (
			not is_instance_valid(_models[copy])
			or property.objects.get(copy) != _models[copy]
			or _models[copy].get_parent() != property
		):
			return false
	return not _models.is_empty()


func cleanup_z() -> float:
	return (
		-3.10
		if is_instance_valid(net) and net.get_meta("stadium_item", "") == "ST-072"
		else PAIR_CLEANUP
	)


func trace(start: Vector3, velocity: Vector3, radius: float) -> Dictionary:
	if (
		not intact()
		or not start.is_finite()
		or not velocity.is_finite()
		or not is_finite(radius)
		or radius <= 0
	):
		return {}
	var points: Array[Vector3] = [start]
	var times: Array[float] = [0.0]
	var end: float = PAIR_TIMEOUT
	var reason: String = "receiver_presentation_timeout"
	var hide_at: float = -1.0
	if velocity.z < -0.001:
		var cleanup: float = (cleanup_z() - start.z) / velocity.z
		if cleanup <= end:
			end = maxf(0, cleanup)
			reason = "receiver_cleanup"
		var cut: float = (CAMERA_CUT - start.z) / velocity.z
		if start.z <= CAMERA_CUT and absf(start.x) <= 2.5:
			hide_at = 0.0
		elif cut >= 0 and absf(start.x + velocity.x * cut) <= 2.5:
			hide_at = cut
	var previous: Vector3 = start
	var elapsed: float = 0.0
	while elapsed < end:
		var next_time: float = minf(elapsed + STEP, end)
		var next: Vector3 = (
			start + velocity * next_time + Vector3.DOWN * 4.9 * next_time * next_time
		)
		var hit: Dictionary = _sweep(previous, next, radius)
		if not hit.is_empty():
			var contact_time: float = lerpf(elapsed, next_time, hit.fraction)
			points.append(previous.lerp(next, hit.fraction))
			times.append(contact_time)
			hit.elapsed = contact_time
			return {
				"points": points,
				"times": times,
				"hit": hit,
				"reason": "receiver_contact",
				"hide_at": hide_at
			}
		points.append(next)
		times.append(next_time)
		previous = next
		elapsed = next_time
	return {"points": points, "times": times, "hit": {}, "reason": reason, "hide_at": hide_at}


func _owned_hit(hit: Dictionary, fraction: float) -> Dictionary:
	if hit.is_empty() or not intact():
		return {}
	var body: Node = instance_from_id(int(hit.collider_id))
	if not _bodies.has(body):
		return {}
	var pin: Dictionary = _bodies[body]
	return {"copy": pin.copy, "surface": pin.surface, "position": hit.point, "fraction": fraction}


func present_contact(hit: Dictionary, kind: String) -> void:
	if not intact() or kind not in ["pitch", "batted"] or not _models.has(hit.get("copy", "")):
		return
	var valid_surface: bool = false
	for pin: Dictionary in _bodies.values():
		if pin.copy == hit.copy and pin.surface == hit.get("surface", ""):
			valid_surface = true
	if not valid_surface:
		return
	contacts.append(
		{
			"kind": kind,
			"copy": hit.copy,
			"surface": hit.surface,
			"elapsed": hit.elapsed,
			"position": [hit.position.x, hit.position.y, hit.position.z]
		}
	)
	var model: Node3D = _models[hit.copy]
	var item: String = model.get_meta("stadium_item")
	if item in ["ST-026", "ST-079"]:
		if is_instance_valid(sounds):
			sounds.play(target_cue(hit.surface) if item == "ST-026" else _cue(hit.surface))
		if _rock != null and _rock.is_valid():
			_rock.kill()
		if item == "ST-079":
			_rock = model.create_tween().bind_node(model)
			_rock.tween_method(
				_primary_motion.bind(model.to_local(hit.position).x, _impacts), 0.0, 0.28, 0.28
			)
			_impacts += 1
		elif hit.surface == "ST026_PANEL":
			_rock = model.create_tween().bind_node(model)
			_rock.tween_method(_primary_motion.bind(0.0, 0), 0.0, 0.18, 0.18)
		return
	var panels: Dictionary = (
		StadiumReceiverOwnedModels.CAGE_PANELS
		if item == "ST-072"
		else StadiumReceiverNetModels.PANELS
	)
	if is_instance_valid(sounds):
		sounds.play(&"net_cord" if panels.has(hit.surface) else &"net_frame")
	if _pocket != null and _pocket.is_valid():
		_pocket.kill()
	var settle: float = (
		StadiumReceiverOwnedModels.CAGE_SETTLE
		if item == "ST-072"
		else StadiumReceiverNetModels.SETTLE
	)
	if not _flex_surface.is_empty():
		_flex_net(settle, _flex_surface, Vector3.ZERO)
	_flex_surface = ""
	if panels.has(hit.surface):
		_flex_surface = hit.surface
		_pocket = model.create_tween().bind_node(model)
		_pocket.tween_method(_flex_net.bind(hit.surface, hit.position), 0.0, settle, settle)


func _primary_motion(elapsed: float, local_x: float, index: int) -> void:
	if not intact() or not is_instance_valid(primary):
		return
	if primary.get_meta("stadium_item") == "ST-079":
		StadiumStarterModels.receiver_rock(primary, local_x, elapsed, index)
	else:
		StadiumTargetModels.flex(primary, elapsed)


func _flex_net(elapsed: float, surface: String, point: Vector3) -> void:
	if intact() and visibility != null:
		visibility.flex_owned(net, surface, elapsed, net.to_local(point))


func _exit_tree() -> void:
	_cancel_active()
	if _rock != null and _rock.is_valid():
		_rock.kill()
	if _pocket != null and _pocket.is_valid():
		_pocket.kill()
	if visibility != null:
		visibility._abandon()
