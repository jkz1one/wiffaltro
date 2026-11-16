class_name StadiumPoolPartyAssetIntegrity
extends RefCounted
## Private exact model-tree comparison. A match is geometry identity, not physics qualification.


static func rigid(pose: Transform3D) -> bool:
	return (
		pose.is_finite()
		and pose.basis.determinant() > 0
		and pose.basis.is_equal_approx(pose.basis.orthonormalized())
		and pose.basis.get_scale().is_equal_approx(Vector3.ONE)
	)


static func same_tree(actual: Node3D, expected: Node3D) -> bool:
	if not rigid(actual.transform) or not rigid(expected.transform):
		return false
	if actual.is_inside_tree() and actual.global_transform != expected.transform:
		return false
	var actual_tree: Dictionary = snapshot(actual)
	var expected_tree: Dictionary = snapshot(expected)
	# A caller may label instances; all descendant surface names remain exact identity.
	for tree: Dictionary in [actual_tree, expected_tree]:
		tree.erase("name")
		tree.properties.erase("name")
	return var_to_bytes(actual_tree) == var_to_bytes(expected_tree)


static func snapshot(node: Node) -> Dictionary:
	var result: Dictionary = {
		"class": node.get_class(),
		"name": String(node.name),
		"properties": _stored(node),
		"metadata": {}
	}
	var keys: Array[StringName] = node.get_meta_list()
	keys.sort()
	for key: StringName in keys:
		result.metadata[String(key)] = _value(node.get_meta(key))
	var children: Array = []
	for child: Node in node.get_children(true):
		children.append(snapshot(child))
	result.children = children
	return result


static func _stored(object: Object) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in object.get_property_list():
		if int(row.usage) & PROPERTY_USAGE_STORAGE:
			result[String(row.name)] = _value(object.get(row.name))
	return result


static func _value(value: Variant) -> Variant:
	if value is Resource:
		return {"resource_class": value.get_class(), "properties": _stored(value)}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_value(entry))
		return result
	if value is Object:
		return {"unexpected_object": value.get_class()}
	return value


static func source_sha256() -> String:
	# Hash every execution-source file and project configuration, with deterministic path order.
	var paths: Array[String] = ["res://project.godot"]
	if not _source_paths("res://src", paths):
		return ""
	paths.sort()
	var rows: PackedStringArray = []
	for path: String in paths:
		var digest: String = FileAccess.get_sha256(path)
		if digest.length() != 64:
			return ""
		rows.append(path.trim_prefix("res://") + "\n" + digest + "\n")
	return "".join(rows).sha256_text()


static func _source_paths(path: String, result: Array[String]) -> bool:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return false
	for file: String in directory.get_files():
		if not file.ends_with(".uid") and not file.ends_with(".import"):
			result.append(path.path_join(file))
	for child: String in directory.get_directories():
		if not _source_paths(path.path_join(child), result):
			return false
	return true
