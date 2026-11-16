class_name StadiumMogulTwoReceiver
extends StadiumClubPitchReceiver
## Existing paired algorithms with exact installed AM02 body/actor identity guards.

var property_ref: WeakRef
var actor_ref: WeakRef
var lab_ref: WeakRef
var released: bool = false
var _bodies: Dictionary = {}
var _models: Dictionary = {}


func configure_candidate(property: StadiumMogulTwoProperty, lab: PitchBatLab) -> bool:
	if property == null or lab == null or not _models.is_empty() or released:
		return false
	var pair: Array[Node3D] = []
	for site: String in ["RECEIVER-PRIMARY", "RECEIVER-CATCH"]:
		var identity: String = StadiumMogulTwoStudy.PREFIX + site
		var model: Node3D = property.objects.get(identity) as Node3D
		if (
			model == null
			or model.get_parent() != property.boundary
			or model.get_meta("candidate_instance", "") != identity
			or model.get_meta("owned_copy", "") != identity
		):
			return false
		var collision: Node = model.get_node_or_null("Collision")
		if collision == null or collision.get_child_count() == 0:
			return false
		_models[model] = {
			"identity": identity, "collision": collision, "children": collision.get_children()
		}
		for child: Node in collision.get_children():
			if (
				not child is StaticBody3D
				or child.get_meta("owned_copy", "") != identity
				or not child.get_meta("surface_id", null) is String
			):
				return false
			_bodies[child] = {
				"model": model,
				"identity": identity,
				"surface": child.get_meta("surface_id"),
				"children": child.get_children()
			}
		pair.append(model)
	if not super.configure_pair(pair[0], pair[1], lab._sounds):
		return false
	property_ref = weakref(property)
	actor_ref = weakref(lab._pitch_actor)
	lab_ref = weakref(lab)
	return true


func intact() -> bool:
	var property: StadiumMogulTwoProperty = (
		property_ref.get_ref() as StadiumMogulTwoProperty if property_ref != null else null
	)
	if released or property == null or property.ended or not property.is_inside_tree():
		return false
	if (
		not is_instance_valid(property.boundary)
		or property.global_transform != Transform3D.IDENTITY
		or property.boundary.global_transform != Transform3D.IDENTITY
		or not is_instance_valid(chair)
		or not is_instance_valid(net)
		or chair.global_transform != Transform3D(Basis.IDENTITY, StadiumTargetModels.POSITION)
		or net.global_transform != Transform3D.IDENTITY
	):
		return false
	for key: Variant in _models:
		if not is_instance_valid(key):
			return false
		var model: Node3D = key as Node3D
		var row: Dictionary = _models[key]
		if (
			model == null
			or property.objects.get(row.identity) != model
			or model.get_parent() != property.boundary
			or model.get_node_or_null("Collision") != row.collision
			or row.collision.get_children() != row.children
			or model.get_meta("owned_copy", "") != row.identity
			or model.get_meta("candidate_instance", "") != row.identity
		):
			return false
	return true


func route(actor: PitchFlightActor, start: Vector3, velocity: Vector3) -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if (
		not intact()
		or actor_ref == null
		or actor_ref.get_ref() != actor
		or lab == null
		or lab._pitch_actor != actor
		or lab.get_node_or_null("PitchFlightActor") != actor
	):
		return false
	return super.route(actor, start, velocity)


func _owned_hit(hit: Dictionary, fraction: float) -> Dictionary:
	if hit.is_empty() or not intact():
		return {}
	var body: Node = instance_from_id(int(hit.get("collider_id", 0)))
	if body == null or not _bodies.has(body):
		return {}
	var row: Dictionary = _bodies[body]
	if (
		body.get_parent() != _models[row.model].collision
		or body.get_children() != row.children
		or body.get_meta("owned_copy", "") != row.identity
		or body.get_meta("surface_id", "") != row.surface
	):
		return {}
	return super._owned_hit(hit, fraction)


func _finish(actor: PitchFlightActor, path: Dictionary) -> void:
	if (
		not intact()
		or actor_ref == null
		or actor_ref.get_ref() != actor
		or not is_instance_valid(actor)
		or actor._plate_follow_tween != _active_tween
	):
		return
	super._finish(actor, path)


func release_actor() -> void:
	if released:
		return
	released = true
	_cancel_active()
	actor_ref = null
	if _rock != null and _rock.is_valid():
		_rock.kill()
	if is_instance_valid(chair):
		StadiumTargetModels.flex(chair, 0.18)
	if _pocket != null and _pocket.is_valid():
		_pocket.kill()
	if is_instance_valid(net) and not _flex_surface.is_empty():
		StadiumReceiverNetModels.flex(
			net, _flex_surface, StadiumReceiverNetModels.SETTLE, Vector3.ZERO
		)
	_flex_surface = ""


func _exit_tree() -> void:
	release_actor()
