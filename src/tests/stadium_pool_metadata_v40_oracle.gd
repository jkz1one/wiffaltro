extends RefCounted
## Exact uninstrumented V36-r2 metadata oracle; test-only, no production dependency.
# gdlint: disable=max-returns

const META_KEYS: Array[StringName] = [
	&"surface_id", &"surface_role", &"stadium_item", &"owned_copy", &"ball_surface",
	&"boundary_segment", &"geometry_version", &"model_id", &"placement_role",
	&"water_geometry_id", &"water_source_sha256", &"water_award_active", &"runtime_adapter",
	&"volume_id", &"volume_role", &"descriptor"
]


static func _metadata(node: Node) -> Array:
	var rows: Array = []
	for key: StringName in META_KEYS:
		var present: bool = node.has_meta(key)
		var value: Variant = node.get_meta(key) if present else null
		if present:
			if key == &"descriptor":
				if not _descriptor_shape(value):
					return []
			elif typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT,
				TYPE_STRING, TYPE_STRING_NAME]:
				return []
		rows.append([key, present, value])
	return rows


static func _descriptor_shape(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 12:
		return false
	for key: Variant in value:
		if not key is String:
			return false
		if typeof(value[key]) not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING,
			TYPE_PACKED_VECTOR2_ARRAY]:
			return false
	return true


