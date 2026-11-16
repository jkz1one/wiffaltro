extends RefCounted
## Diagnostic only: exact JSON lexemes, Variant types and numeric bits. No acceptance repair.


static func report(encoded: Dictionary, decoded: Variant, json_text: String, error: Error) -> void:
	var before: Dictionary = {}
	var after: Dictionary = {}
	_leaves(encoded, "$", before)
	_leaves(decoded, "$", after)
	var differences: Array[Dictionary] = []
	for path: String in before:
		if not after.has(path) or before[path] != after[path]:
			differences.append({"path": path, "encoded": before[path], "decoded": after.get(path)})
	for path: String in after:
		if not before.has(path):
			differences.append({"path": path, "encoded": null, "decoded": after[path]})
	print(
		"MOGUL_ONE_RECEIPT_ROUNDTRIP_DIAGNOSTIC ",
		JSON.stringify(
			{
				"diagnostic_only": true,
				"stringify_options": {"indent": "", "sort_keys": true, "full_precision": true},
				"encoded_json": json_text,
				"parse_error": int(error),
				"aggregate_equal": decoded == encoded,
				"encoded_scalar_and_container_fields": before,
				"decoded_scalar_and_container_fields": after,
				"exact_field_differences": differences
			},
			"",
			true,
			true
		)
	)


static func _leaves(value: Variant, path: String, result: Dictionary) -> void:
	var row: Dictionary = {"variant_type": typeof(value), "type_name": type_string(typeof(value))}
	if value is Dictionary:
		row["size"] = value.size()
		row["key_types"] = {}
		for key: Variant in value:
			row["key_types"][str(key)] = typeof(key)
			_leaves(value[key], path + "." + str(key), result)
	elif value is Array:
		row["size"] = value.size()
		for index: int in range(value.size()):
			_leaves(value[index], "%s[%d]" % [path, index], result)
	else:
		row["readable_value"] = value
		row["variant_bytes_hex"] = var_to_bytes(value).hex_encode()
		if value is float or value is int:
			row["numeric_float64_native_hex"] = (
				PackedFloat64Array([float(value)]).to_byte_array().hex_encode()
			)
	result[path] = row
