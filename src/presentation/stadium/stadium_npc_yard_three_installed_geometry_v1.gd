class_name StadiumNpcYardThreeInstalledGeometryV1
extends RefCounted
## Strict fresh-retained comparison for AY03. No authoring factory, mutable catalog or disk.


static func same(actual: Node, expected: Node) -> bool:
	return is_instance_valid(actual) and is_instance_valid(expected) \
		and _policies(actual, expected) \
		and var_to_bytes(StadiumNpcRetainedGeometry._geometry(actual)) == var_to_bytes(
			StadiumNpcRetainedGeometry._geometry(expected))


static func _policies(actual: Node, expected: Node) -> bool:
	if actual.get_script() != expected.get_script() \
		or actual.get_child_count() != expected.get_child_count() \
		or actual.process_mode != expected.process_mode \
		or actual.process_priority != expected.process_priority \
		or actual.process_physics_priority != expected.process_physics_priority:
		return false
	if actual is CollisionObject3D and (not expected is CollisionObject3D \
		or actual.disable_mode != expected.disable_mode):
		return false
	if actual is Light3D and (not expected is Light3D \
		or var_to_bytes(StadiumNpcRetainedGeometry._stored(actual)) != var_to_bytes(
			StadiumNpcRetainedGeometry._stored(expected))):
		return false
	for node: Node in [actual, expected]:
		for property: Dictionary in node.get_property_list():
			if property.name == "script" or int(property.usage) & PROPERTY_USAGE_STORAGE == 0:
				continue
			if not _resources(node.get(property.name), []):
				return false
	for index in range(actual.get_child_count()):
		if not _policies(actual.get_child(index), expected.get_child(index)):
			return false
	return true


static func _resources(value: Variant, seen: Array[int]) -> bool:
	if value is Resource:
		if value.get_script() != null:
			return false
		if seen.has(value.get_instance_id()):
			return true
		seen.append(value.get_instance_id())
		for property: Dictionary in value.get_property_list():
			if property.name == "script" or int(property.usage) & PROPERTY_USAGE_STORAGE == 0:
				continue
			if not _resources(value.get(property.name), seen):
				return false
	elif value is Array:
		for item: Variant in value:
			if not _resources(item, seen):
				return false
	elif value is Dictionary:
		for item: Variant in value.values():
			if not _resources(item, seen):
				return false
	return true
