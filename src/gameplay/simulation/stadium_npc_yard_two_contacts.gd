class_name StadiumNpcYardTwoContacts
extends RefCounted
## Frozen AY-02 identities, ordinary terminal roles and bounded recorded contact positions.
# gdlint: disable=max-returns


static func valid(value: Variant, plays: Array, snapshot: Dictionary) -> bool:
	if not value is Array or value.size() != plays.size() or value.size() > 9999:
		return false
	var placements: Dictionary = _placements(snapshot)
	for index in range(value.size()):
		var row: Variant = value[index]
		if not row is Dictionary or not SeasonOwnership._keys(row, ["play", "reason", "events"]) \
			or not SeasonOwnership._whole(row.play, index, index) \
			or not row.reason is String or row.reason.length() > 80 \
			or row.reason.begins_with("owned_pool_") or row.reason.begins_with("private_pool_") \
			or not row.events is Array or row.events.size() > 128:
			return false
		var play: Dictionary = plays[index]
		if not row.events.is_empty() and (not SeasonOwnership._whole(play.get("contact"), 1, 3)
			or not PhysicalMatchReport.number(play.get("exit_speed"), 0.0001, 1000)):
			return false
		var required: Array = PhysicalStadiumContacts._reason_roles(row.reason)
		if row.events.is_empty() and (not required.is_empty() or play.result in ["triple", "home_run"]):
			return false
		var last_time: float = -1.0
		for event_index in range(row.events.size()):
			var event: Variant = row.events[event_index]
			if not _event(event, placements) or event.time < last_time:
				return false
			last_time = float(event.time)
			if event.role not in ["SIDE_RETURN_LIVE", "LIVE_RICOCHET"]:
				if event_index != row.events.size() - 1 \
					or not PhysicalStadiumContacts._terminal(event.role, play) \
					or not required.has(event.role):
					return false
		if not required.is_empty() and not required.has(row.events[-1].role):
			return false
	return true


static func _placements(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in snapshot.manifest.instances:
		if row.item not in ["ST-001", "ST-079"]:
			continue
		var pose: Transform3D = StadiumNpcYardTwoContractV1.transform(row.transform)
		result[row.instance] = {"copy": row.instance, "item": row.item,
			"position": pose.origin, "yaw": rad_to_deg(pose.basis.get_euler().y),
			"role": "LIVE_RICOCHET" if row.item == "ST-001" else "RECEIVER_CONTAINMENT_FOUL"}
	return result


static func _event(value: Variant, placements: Dictionary) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["source", "id", "surface", "role", "position", "time", "kind"]):
		return false
	for key: String in ["source", "id", "surface", "role", "kind"]:
		if not value[key] is String:
			return false
	if value.source == "item":
		return PhysicalStadiumContacts._event(value, placements)
	if value.source != "boundary" or value.id != StadiumNpcYardGraphV1.ID \
		or value.kind not in ["contact", "crossing"] \
		or not PhysicalMatchReport.number(value.time, 0, 3600) \
		or not value.position is Array or value.position.size() != 3:
		return false
	for coordinate: Variant in value.position:
		if not PhysicalMatchReport.number(coordinate, -1000, 1000):
			return false
	var segment: Dictionary = StadiumNpcYardGraphV1.segment(value.surface)
	if segment.is_empty():
		return false
	var roles: Array = [segment.role]
	if value.kind == "crossing":
		if segment.role == "SIDE_RETURN_LIVE":
			roles.append("SIDE_EXIT_DEAD")
		elif segment.role == "BACK_WALL_TERMINAL":
			roles.append("BACK_CLEAR")
	var point: Vector3 = Vector3(value.position[0], value.position[1], value.position[2])
	var planar: Vector2 = Vector2(point.x, point.z)
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(planar, segment.a, segment.b)
	if not roles.has(value.role) or closest.distance_to(planar) > 0.05 or point.y < -0.05:
		return false
	if value.role in ["SIDE_EXIT_DEAD", "BACK_CLEAR"]:
		return point.y >= segment.height - 0.0001
	return point.y <= segment.height + 0.05 or (
		value.kind == "crossing" and value.role == "REAR_PERIMETER_DEAD")


static func provenance(value: Variant, snapshot: Dictionary) -> bool:
	if not value is Array or value.size() > 4096:
		return false
	var instances: Dictionary = {}
	for row: Dictionary in snapshot.manifest.instances:
		instances[row.instance] = row.item
	for row: Variant in value:
		if not row is Dictionary or not SeasonOwnership._keys(row,
			["instance", "surface", "preterminal", "elapsed"]) \
			or not row.instance is String or not instances.has(row.instance) \
			or not row.surface is String or not row.preterminal is bool or not row.preterminal \
			or not PhysicalMatchReport.number(row.elapsed, 0, 3600) \
			or not _surfaces(instances[row.instance]).has(row.surface):
			return false
	return true


static func _surfaces(item: String) -> Array:
	if item != "ST-027":
		return StadiumStarterModels.surfaces(item)
	var result: Array = ["LowerBench", "UpperBench", "LowerFootboard", "UpperFootboard",
		"RearGuardRail", "RearGuardPost-1", "RearGuardPost1", "FinishedEnd-1", "FinishedEnd1"]
	for index in range(3):
		for prefix: String in ["GroundRunner", "LowSupport", "HighSupport", "Diagonal"]:
			result.append(prefix + str(index))
	for index in range(4):
		result.append("AccessStep" + str(index))
	return result
