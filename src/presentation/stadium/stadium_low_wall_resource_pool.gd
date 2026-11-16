class_name StadiumLowWallResourcePool
extends RefCounted
## Instance-local exact-value optimization, aligned with Night candidate3 pool.
var _target: Node3D
var _low_target_pool: Dictionary = {}


static func prepare(target: Node3D) -> Dictionary:
	var pool: StadiumLowWallResourcePool = StadiumLowWallResourcePool.new()
	pool._target = target
	if not _low_no_internal_children(target):
		return {"ok": false, "pooled": false, "reason": "internal descendant at admission"}
	for node: Node in target.find_children("*", "", true, false):
		if node.get_class() not in ["Node3D", "MeshInstance3D", "StaticBody3D", "CollisionShape3D"]:
			return {
				"ok": true,
				"pooled": false,
				"reason": "non-default native class retains exhaustive seal"
			}
	for node: Node in target.find_children("*", "MeshInstance3D", true, false):
		if not node.mesh is BoxMesh:
			return {
				"ok": true, "pooled": false, "reason": "non-default mesh retains exhaustive seal"
			}
	var ok: bool = pool._pool_low_target_visuals()
	return {"ok": ok, "pooled": ok, "evidence": pool._low_target_pool.duplicate(true)}


static func _low_value_equal(actual: Variant, expected: Variant) -> bool:
	# Typed foreign metadata must refuse, not throw during cleanup/guard comparison.
	return (
		typeof(actual) == typeof(expected)
		and (is_same(actual, expected) if actual is Object else actual == expected)
	)


static func _low_no_internal_children(root: Node) -> bool:
	if not is_instance_valid(root):
		return false
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var children: Array[Node] = node.get_children()
		if node.get_child_count(true) != children.size():
			return false
		pending.append_array(children)
	return true


func _low_target_visual_fingerprint() -> String:
	var resources: Array[Dictionary] = []
	var seen: Dictionary = {}
	var rows: Array = []
	for node: Node in _target.find_children("*", "", true, false):
		var fields: Array = []
		var values: Array = []
		for property: Dictionary in node.get_property_list():
			if (
				not int(property.usage) & PROPERTY_USAGE_STORAGE
				or property.name in ["script", "owner"]
			):
				continue
			var value: Variant = node.get(property.name)
			fields.append(property.name)
			values.append(value)
			if (
				value is Resource
				and not StadiumFloodlightOwnedModels._capture_resource(
					value, resources, seen, 0, true
				)
			):
				return ""
		rows.append(
			[
				String(node.name),
				String(node.get_parent().name),
				node.get_index(),
				fields,
				values,
				_metadata(node)
			]
		)
	var hashes: Dictionary = {}
	for row: Dictionary in resources:
		var values: Array = []
		for value: Variant in row.values:
			if value is Resource:
				if not hashes.has(value):
					return ""
				values.append({"resource": hashes[value]})
			else:
				values.append(value)
		hashes[row.resource] = (
			_data([row.resource.get_class(), row.keys, values, _metadata(row.resource)])
			. sha256_text()
		)
	for row: Array in rows:
		for index in range(row[4].size()):
			if row[4][index] is Resource:
				row[4][index] = {"resource": hashes[row[4][index]]}
	return _data(rows).sha256_text()


func _pool_low_target_visuals() -> bool:
	# Candidate3 instance-local preparation only. Never changes a historical factory,
	# collider resource or source asset. Full native-value equality proves each merge.
	if not _low_no_internal_children(_target):
		return false
	var before: String = _low_target_visual_fingerprint()
	if before.is_empty():
		return false
	return _pool_low_target_visuals_remaining_checks(before)


func _pool_low_target_visuals_remaining_checks(before: String) -> bool:
	var resources: Array[Dictionary] = []
	var seen: Dictionary = {}
	var visuals: Array[MeshInstance3D] = []
	for node: Node in _target.find_children("*", "MeshInstance3D", true, false):
		var visual: MeshInstance3D = node as MeshInstance3D
		if visual == null or not visual.mesh is BoxMesh:
			return false
		visuals.append(visual)
		for resource: Resource in [visual.mesh, visual.material_override, visual.material_overlay]:
			if (
				resource != null
				and not StadiumFloodlightOwnedModels._capture_resource(
					resource, resources, seen, 0, true
				)
			):
				return false
		for index in range(visual.mesh.get_surface_count()):
			var material: Material = visual.get_surface_override_material(index)
			if (
				material != null
				and not StadiumFloodlightOwnedModels._capture_resource(
					material, resources, seen, 0, true
				)
			):
				return false
	var canonical: Dictionary = {}
	var buckets: Dictionary = {}
	var unique: int = 0
	# Capture emits referenced materials before their parent meshes.
	for row: Dictionary in resources:
		var resource: Resource = row.resource
		if not resource is StandardMaterial3D and not resource is BoxMesh:
			return false  # This exact default boundary has no textures or custom shaders.
		for index in range(row.keys.size()):
			var value: Variant = row.values[index]
			if value is Resource and canonical.has(value) and not is_same(value, canonical[value]):
				resource.set(row.keys[index], canonical[value])
				row.values[index] = canonical[value]
		var values: Array = []
		for value: Variant in row.values:
			values.append({"resource_id": value.get_instance_id()} if value is Resource else value)
		var fingerprint: String = (
			_data([resource.get_class(), row.keys, values, _metadata(resource)]).sha256_text()
		)
		var match_row: Dictionary = {}
		for candidate: Dictionary in buckets.get(fingerprint, []):
			if candidate.keys != row.keys or _metadata(candidate.resource) != _metadata(resource):
				continue
			var equal: bool = true
			for index in range(row.keys.size()):
				equal = equal and _low_value_equal(candidate.values[index], row.values[index])
			if equal:
				match_row = candidate
				break
		if match_row.is_empty():
			if not buckets.has(fingerprint):
				buckets[fingerprint] = []
			buckets[fingerprint].append(row)
			canonical[resource] = resource
			unique += 1
		else:
			canonical[resource] = match_row.resource
	for visual: MeshInstance3D in visuals:
		visual.mesh = canonical[visual.mesh]
		if visual.material_override != null:
			visual.material_override = canonical[visual.material_override]
		if visual.material_overlay != null:
			visual.material_overlay = canonical[visual.material_overlay]
		for index in range(visual.mesh.get_surface_count()):
			var material: Material = visual.get_surface_override_material(index)
			if material != null:
				visual.set_surface_override_material(index, canonical[material])
	_low_target_pool = {
		"before": resources.size(),
		"after": unique,
		"visuals": visuals.size(),
		"proof": "exact-full-native-values-and-resource-reference-equality-before-merge",
		"before_fingerprint": before,
		"after_fingerprint": _low_target_visual_fingerprint()
	}
	return not visuals.is_empty() and _low_target_pool.after_fingerprint == before


static func _metadata(object: Object) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in object.get_meta_list():
		var value: Variant = object.get_meta(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


static func _data(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)
