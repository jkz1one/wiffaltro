class_name StadiumYardTwoReceiver
extends StadiumPitchReceiver
## Candidate membership guards only. Shared receiver physics, timing, contact and rock are
## inherited.

var property: StadiumYardTwoProperty
var _bound_chair: Node3D
var _actor: PitchFlightActor


func configure(_model: Node3D, _sound_player: PlaySounds = null) -> bool:
	# Human/foreign configuration cannot rebind an already-installed candidate callback.
	return false


func configure_candidate(candidate: StadiumYardTwoProperty, sound_player: PlaySounds) -> bool:
	if property != null or candidate == null:
		return false
	var candidate_model: Variant = candidate.objects.get(
		StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY"
	)
	if not candidate_model is Node3D:
		return false
	var model: Node3D = candidate_model
	if (
		model == null
		or not StadiumYardTwoProperty._meta_equals(model, "stadium_item", "ST-079")
		or not candidate.model_intact(StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY")
	):
		return false
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if candidate.contact_identity(body).is_empty():
			return false
	property = candidate
	_bound_chair = model
	return super.configure(model, sound_player)


func bound() -> bool:
	if (
		not is_instance_valid(property)
		or not is_instance_valid(chair)
		or chair != _bound_chair
		or get_parent() != property
		or not is_same(property.objects.get(StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY"), chair)
		or not property.model_intact(StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY")
	):
		return false
	for body: StaticBody3D in chair.get_node("Collision").get_children():
		if property.contact_identity(body).is_empty():
			return false
	return true


func bind_actor(actor: PitchFlightActor) -> bool:
	if _actor != null or actor == null or actor.receiver_router.is_valid() or not bound():
		return false
	_actor = actor
	actor.receiver_router = route
	return true


func route(actor: PitchFlightActor, start: Vector3, velocity: Vector3) -> bool:
	if not bound() or actor != _actor or actor.receiver_router != route:
		return false
	return super.route(actor, start, velocity)


func _owned_hit(hit: Dictionary, fraction: float) -> Dictionary:
	if (
		hit.is_empty()
		or not bound()
		or typeof(hit.get("collider_id")) != TYPE_INT
		or not hit.get("point") is Vector3
		or not is_finite(fraction)
		or fraction < 0
		or fraction > 1
		or not hit.point.is_finite()
	):
		return {}
	var body: Node = instance_from_id(int(hit.collider_id))
	var row: Dictionary = property.contact_identity(body)
	if row.is_empty() or row.model != _bound_chair:
		return {}
	return super._owned_hit(hit, fraction)


func present_contact(hit: Dictionary, kind: String) -> void:
	if (
		not bound()
		or kind not in ["pitch", "batted"]
		or not hit.get("copy") is String
		or hit.copy != StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY"
		or not hit.get("surface") is String
		or not hit.get("position") is Vector3
		or typeof(hit.get("elapsed")) not in [TYPE_INT, TYPE_FLOAT]
		or not is_finite(float(hit.elapsed))
		or float(hit.elapsed) < 0
		or not hit.position.is_finite()
		or not StadiumStarterModels.surfaces("ST-079").has(hit.get("surface", ""))
	):
		return
	super.present_contact(hit, kind)


func _finish(actor: PitchFlightActor, path: Dictionary) -> void:
	if bound() and actor == _actor and actor.receiver_router == route:
		super._finish(actor, path)


func _animate(elapsed: float, local_x: float, index: int) -> void:
	if bound():
		super._animate(elapsed, local_x, index)
