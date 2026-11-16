extends "res://src/tests/stadium_lower_transition_models_test.gd"
## Primitive mutation preserves the original encoded bytes; never decode/repack a host.

var _roundtrip_reported: bool = false


func _rebuild_array_mesh(source: ArrayMesh, strip: bool) -> ArrayMesh:
	# Godot's bound resource-serialization methods retain ArrayMesh bookkeeping and
	# raw surface buffers. Direct RenderingServer edits would leave its cached surface
	# primitive stale. See scene/resources/mesh.cpp::_get_surfaces / _set_surfaces.
	var supported: bool = source.has_method("_get_surfaces") \
		and source.has_method("_set_surfaces") and source.get_blend_shape_count() == 0
	_check(supported, "raw ArrayMesh serializer is available for this unblended canonical host")
	if not supported:
		return null
	var encoded: Variant = source.call("_get_surfaces")
	if typeof(encoded) != TYPE_ARRAY:
		_check(false, "raw mesh serializer must return actual surface records")
		return null
	var records: Array = encoded.duplicate(true)
	var valid: bool = records.size() == source.get_surface_count() and not records.is_empty()
	for record: Variant in records:
		if typeof(record) != TYPE_DICTIONARY:
			valid = false
			continue
		for key: String in ["primitive", "format", "vertex_data", "vertex_count", "aabb"]:
			valid = valid and record.has(key)
	_check(valid, "complete raw surface records exist before any primitive mutation")
	if not valid:
		return null
	var result: ArrayMesh = ArrayMesh.new()
	result.blend_shape_mode = source.blend_shape_mode
	result.custom_aabb = source.custom_aabb
	result.shadow_mesh = source.shadow_mesh
	if strip:
		records[0]["primitive"] = Mesh.PRIMITIVE_TRIANGLE_STRIP
	result.call("_set_surfaces", records)
	var exact: bool = _exact_raw_rebuild(result, source, records, strip)
	_check(exact, "primitive control retains exact raw format buffers materials and decoded arrays")
	if not exact:
		_mesh_difference(result, source, "raw reconstruction precondition failed")
		return null
	return result


func _exact_raw_rebuild(actual: ArrayMesh, source: ArrayMesh,
	expected_records: Array, strip: bool) -> bool:
	if actual.get_surface_count() != source.get_surface_count() \
		or actual.get_blend_shape_count() != source.get_blend_shape_count() \
		or actual.custom_aabb != source.custom_aabb \
		or var_to_bytes(actual.call("_get_surfaces")) != var_to_bytes(expected_records):
		return false
	for surface in range(source.get_surface_count()):
		var primitive: int = Mesh.PRIMITIVE_TRIANGLE_STRIP if strip and surface == 0 \
			else source.surface_get_primitive_type(surface)
		if actual.surface_get_primitive_type(surface) != primitive \
			or actual.surface_get_format(surface) != source.surface_get_format(surface) \
			or actual.surface_get_material(surface) != source.surface_get_material(surface) \
			or var_to_bytes(actual.surface_get_arrays(surface)) \
			!= var_to_bytes(source.surface_get_arrays(surface)):
			return false
	return true


func _report_decoded_roundtrip_once(source: ArrayMesh) -> void:
	if _roundtrip_reported:
		return
	_roundtrip_reported = true
	# This detached diagnostic establishes which components the rejected old method
	# actually changed. It neither changes the host nor participates in admission.
	var decoded: ArrayMesh = ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		decoded.add_surface_from_arrays(source.surface_get_primitive_type(surface),
			source.surface_get_arrays(surface))
		decoded.surface_set_material(surface, source.surface_get_material(surface))
	_mesh_difference(decoded, source, "decoded-array round-trip diagnostic only")


func _mesh_difference(actual: Mesh, source: Mesh, label: String) -> void:
	print("Mesh diagnostic %s: class %s/%s; surfaces %d/%d" %
		[label, actual.get_class(), source.get_class(), actual.get_surface_count(),
			source.get_surface_count()])
	for surface in range(mini(3, mini(actual.get_surface_count(), source.get_surface_count()))):
		if actual is ArrayMesh and source is ArrayMesh:
			print("  surface%d primitive %d/%d format %d/%d custom_aabb %s/%s" %
				[surface, actual.surface_get_primitive_type(surface),
					source.surface_get_primitive_type(surface), actual.surface_get_format(surface),
					source.surface_get_format(surface), actual.custom_aabb, source.custom_aabb])
			_raw_record_difference(actual, source, surface)
		print("  surface%d material ids %s/%s" % [surface,
			_material_identity(actual.surface_get_material(surface)),
			_material_identity(source.surface_get_material(surface))])
		var changed: Array = actual.surface_get_arrays(surface)
		var original: Array = source.surface_get_arrays(surface)
		for component in range(mini(changed.size(), original.size())):
			if var_to_bytes(changed[component]) != var_to_bytes(original[component]):
				_component_difference(component, changed[component], original[component])


func _raw_record_difference(actual: ArrayMesh, source: ArrayMesh, surface: int) -> void:
	if not actual.has_method("_get_surfaces") or not source.has_method("_get_surfaces"):
		return
	var changed: Array = actual.call("_get_surfaces")
	var original: Array = source.call("_get_surfaces")
	if surface >= changed.size() or surface >= original.size():
		return
	var fields: Array = original[surface].keys()
	for key: Variant in changed[surface]:
		if key not in fields:
			fields.append(key)
	fields.sort()
	var differences: int = 0
	for key: Variant in fields:
		var a: Variant = changed[surface].get(key)
		var b: Variant = original[surface].get(key)
		if var_to_bytes(a) == var_to_bytes(b):
			continue
		differences += 1
		if differences <= 8:
			print("  raw field %s differs: type %d/%d encoded bytes %d/%d sha256 %s/%s" %
				[key, typeof(a), typeof(b), var_to_bytes(a).size(), var_to_bytes(b).size(),
					var_to_bytes(a).hex_encode().sha256_text(),
					var_to_bytes(b).hex_encode().sha256_text()])
	print("  raw differing field count: ", differences)


func _component_difference(component: int, actual: Variant, source: Variant) -> void:
	print("  decoded component%d differs: type %d/%d encoded bytes %d/%d sha256 %s/%s" %
		[component, typeof(actual), typeof(source), var_to_bytes(actual).size(),
			var_to_bytes(source).size(), var_to_bytes(actual).hex_encode().sha256_text(),
			var_to_bytes(source).hex_encode().sha256_text()])
	var packed: Array[int] = [TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY,
		TYPE_PACKED_VECTOR4_ARRAY]
	if typeof(actual) != typeof(source) or typeof(actual) not in packed:
		return
	var differences: int = 0
	for index in range(mini(actual.size(), source.size())):
		if var_to_bytes(actual[index]) == var_to_bytes(source[index]):
			continue
		differences += 1
		if differences <= 3:
			print("    entry%d value %s/%s exact scalar-or-vector bytes %s/%s" % [index,
				actual[index], source[index], var_to_bytes(actual[index]).hex_encode(),
				var_to_bytes(source[index]).hex_encode()])
	print("    differing entries: %d; lengths %d/%d" %
		[differences, actual.size(), source.size()])


func _material_identity(material: Material) -> String:
	return "null" if material == null else "%s:%d" % [material.get_class(), material.get_instance_id()]
