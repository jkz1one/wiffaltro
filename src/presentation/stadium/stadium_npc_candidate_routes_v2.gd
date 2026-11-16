class_name StadiumNpcCandidateRoutesV2
extends RefCounted
## Explicit r2 receiver routes. Frozen factory route methods address r1 keys only.
## Exact retained algorithms, derived from actual installed r2 model transforms/shapes.


static func obstacles(property: StadiumNpcRetainedProperty) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if property == null or property.field == null or property.field.id != &"field.npc_venue":
		return result
	if property.venue_id == "AY-01":
		return result
	if property.venue_id not in ["AE-01", "AC-01"]:
		return result
	var prefix: String = "npc:" + property.venue_id + ":r2:"
	var target: Node3D = _model(property, prefix + "RECEIVER-PRIMARY")
	var net: Node3D = _model(property, prefix + "RECEIVER-CATCH")
	if target == null or net == null:
		return result
	if property.venue_id == "AE-01":
		for row: Array in [
			[target, StadiumNpcExpandedTargetV1.ENVELOPE], [net, StadiumNpcExpandedNetV1.ENVELOPE]
		]:
			var model: Node3D = row[0]
			var bounds: AABB = model.transform * row[1]
			result.append(
				{
					"center": bounds.get_center(),
					"radius": Vector2(bounds.size.x, bounds.size.z).length() / 2 + 0.32,
					"copy": model.get_meta("npc_instance")
				}
			)
		return result
	var collision: Node = net.get_node_or_null("Collision")
	if collision == null:
		return []
	for ends: Array in StadiumNpcClubNetV1.PANELS.values():
		var pieces: int = ceili(ends[0].distance_to(ends[1]) / 0.3)
		for index in range(pieces + 1):
			var point: Vector2 = ends[0].lerp(ends[1], float(index) / pieces)
			result.append({"center": Vector3(point.x, 0, point.y), "radius": 0.8})
	_bounds(result, target.transform * StadiumNpcClubTargetV1.ENVELOPE)
	for node: Node in collision.get_children():
		if not node is StaticBody3D or not node.has_meta("surface_id"):
			return []
		if String(node.get_meta("surface_id")).begins_with("ST073_ANCHOR"):
			if node.get_child_count() != 1 or not node.get_child(0) is CollisionShape3D:
				return []
			var shape: CollisionShape3D = node.get_child(0)
			if not shape.shape is BoxShape3D:
				return []
			var size: Vector3 = (shape.shape as BoxShape3D).size
			_bounds(
				result, net.transform * node.transform * shape.transform * AABB(-size / 2, size)
			)
	return result


static func _model(property: StadiumNpcRetainedProperty, identity: String) -> Node3D:
	var value: Variant = property.objects.get(identity)
	if (
		not value is Node3D
		or not is_instance_valid(value)
		or value.get_meta("npc_instance", "") != identity
		or not is_instance_valid(property.construction)
		or not property.construction.is_ancestor_of(value)
	):
		return null
	return value as Node3D


static func _bounds(result: Array[Dictionary], bounds: AABB) -> void:
	result.append(
		{
			"center": bounds.get_center(),
			"radius": Vector2(bounds.size.x, bounds.size.z).length() / 2 + 0.32
		}
	)
