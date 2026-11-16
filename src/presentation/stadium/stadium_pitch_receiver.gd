class_name StadiumPitchReceiver
extends Node3D
## CA4 chair-only post-call presentation. Never changes logical calls, counts or pitch statistics.

const LAYER: int = 16
const STEP: float = 1.0 / 240.0
const TIMEOUT: float = 0.24
const CLEANUP_Z: float = -1.40

var chair: Node3D
var sounds: PlaySounds
var contacts: Array[Dictionary] = []
var last_reason: String = ""
var _impacts: int = 0
var _rock: Tween


func configure(model: Node3D, sound_player: PlaySounds = null) -> bool:
	if not StadiumPropertyGeometry.construction_target_allowed(self) \
		or not StadiumPropertyGeometry.construction_target_allowed(model):
		return false
	if model == null or model.get_meta("stadium_item", "") != "ST-079" \
		or not model.has_meta("owned_copy"):
		return false
	chair = model
	chair.process_mode = Node.PROCESS_MODE_PAUSABLE
	sounds = sound_player
	for body: StaticBody3D in chair.get_node("Collision").get_children():
		body.collision_layer |= LAYER
	return true


func trace(start: Vector3, velocity: Vector3, radius: float) -> Dictionary:
	var points: Array[Vector3] = [start]
	var times: Array[float] = [0.0]
	var end: float = TIMEOUT
	var reason: String = "receiver_presentation_timeout"
	if velocity.z < -0.001:
		var cleanup_time: float = (cleanup_z() - start.z) / velocity.z
		if cleanup_time <= end:
			end = maxf(0, cleanup_time)
			reason = "receiver_cleanup"
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
			return {"points": points, "times": times, "hit": hit, "reason": "receiver_contact"}
		points.append(next)
		times.append(next_time)
		previous = next
		elapsed = next_time
	return {"points": points, "times": times, "hit": {}, "reason": reason}


func route(actor: PitchFlightActor, start: Vector3, velocity: Vector3) -> bool:
	if not is_instance_valid(chair):
		return false
	last_reason = ""
	var radius: float = actor.parameters.radius_m if actor.parameters != null else (
		ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID).aero_profile.radius_m)
	var path: Dictionary = trace(start, velocity, radius)
	actor._plate_follow_tween = actor.create_tween().bind_node(actor)
	for index in range(1, path.points.size()):
		actor._plate_follow_tween.tween_property(actor, "global_position", path.points[index],
			maxf(0.000001, path.times[index] - path.times[index - 1])).set_trans(Tween.TRANS_LINEAR)
	actor._plate_follow_tween.tween_callback(_finish.bind(actor, path))
	return true


func _sweep(from: Vector3, to: Vector3, radius: float) -> Dictionary:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.collision_mask = LAYER
	query.margin = 0.0005
	query.transform = Transform3D(Basis.IDENTITY, from)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var resting: Dictionary = space.get_rest_info(query)
	if not resting.is_empty():
		return _owned_hit(resting, 0.0)
	query.motion = to - from
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() != 2 or (fractions[0] >= 1.0 and fractions[1] >= 1.0):
		return {}
	query.transform.origin = from.lerp(to, minf(1.0, fractions[1] + 0.0001))
	query.motion = Vector3.ZERO
	return _owned_hit(space.get_rest_info(query), fractions[0])


func _owned_hit(hit: Dictionary, fraction: float) -> Dictionary:
	if hit.is_empty():
		return {}
	var body: Node = instance_from_id(int(hit.collider_id))
	if body == null or not chair.is_ancestor_of(body) or not body.has_meta("owned_copy"):
		return {}
	return {"copy": body.get_meta("owned_copy"), "surface": body.get_meta("surface_id"),
		"position": hit.point, "fraction": fraction}


func _finish(actor: PitchFlightActor, path: Dictionary) -> void:
	last_reason = path.reason
	if not path.hit.is_empty():
		present_contact(path.hit, "pitch")
	actor._hide_after_plate_follow_through()


func present_contact(hit: Dictionary, kind: String) -> void:
	if not is_instance_valid(chair) or kind not in ["pitch", "batted"]:
		return
	if hit.get("copy") != chair.get_meta("owned_copy"):
		return
	contacts.append({"kind": kind, "copy": hit.copy, "surface": hit.surface,
		"elapsed": hit.elapsed, "position": [hit.position.x, hit.position.y, hit.position.z]})
	if is_instance_valid(sounds):
		sounds.play(_cue(hit.surface))
	if _rock != null and _rock.is_valid():
		_rock.kill()
	var local_x: float = chair.to_local(hit.position).x
	_rock = chair.create_tween().bind_node(chair)
	_rock.tween_method(_animate.bind(local_x, _impacts), 0.0, 0.28, 0.28)
	_impacts += 1


func _animate(elapsed: float, local_x: float, index: int) -> void:
	if is_instance_valid(chair):
		StadiumStarterModels.receiver_rock(chair, local_x, elapsed, index)


static func _cue(surface: String) -> StringName:
	if surface == "ST079_BACK":
		return &"chair_back"
	if surface == "ST079_SEAT":
		return &"chair_seat"
	if surface.begins_with("ST079_ARM"):
		return &"chair_arms"
	return &"chair_legs"


func cleanup_z() -> float:
	return CLEANUP_Z
