class_name StadiumBoundaryObserver
extends RefCounted
## Isolated straight-graph trajectory rules; no obsolete infinite back-wall plane.


static func observe(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> Dictionary:
	if resolver == null or resolver.state == null or resolver.state.dead or resolver.field == null:
		return {}
	var event: Dictionary = StadiumBoundaryGraph.crossing(previous, current)
	var end: Vector3 = current if event.is_empty() else event.position
	if not resolver.state.is_foul_play:
		_bands(resolver, previous, end)
	if not event.is_empty():
		StadiumBoundaryGraph.apply(resolver, event)
	elif current.y < -2.0:
		resolver.resolve_settled(current)
	return event


static func _bands(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> void:
	var field: FieldDefinition = resolver.field
	var safe: Vector3 = resolver._forward_plane_crossing(previous, current, field.safe_hit_z_m)
	if safe != Vector3.INF and field.is_fair_point(safe):
		resolver.state.raise_result_floor(BallPlayState.ResultFloor.SINGLE)
	var deep: Vector3 = resolver._forward_plane_crossing(previous, current, field.deep_air_z_m)
	if deep != Vector3.INF and field.is_fair_point(deep) \
		and not resolver.state.has_grounded and not resolver.state.defender_touched:
		resolver.state.raise_result_floor(BallPlayState.ResultFloor.DOUBLE)
