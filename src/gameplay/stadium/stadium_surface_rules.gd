class_name StadiumSurfaceRules
extends RefCounted
## Named construction contacts. These do not replace ground or defender-touch history.


static func apply(resolver: BallPlayResolver, role: String, copy: String,
	position: Vector3, surface: String = "") -> bool:
	if resolver == null or resolver.state == null or resolver.state.dead or copy.is_empty():
		return false
	if role not in ["LIVE_RICOCHET", "RECEIVER_CONTAINMENT_FOUL"]:
		return false
	if resolver.segment_observer.is_valid() and not surface.is_empty():
		resolver.state.record_stadium_contact("item", copy, surface, role, position, "contact")
	match role:
		"LIVE_RICOCHET":
			resolver.record_live_object_contact(StringName(copy))
		"RECEIVER_CONTAINMENT_FOUL":
			resolver._resolve_foul(&"receiver_containment", position)
		_:
			return false
	return true
