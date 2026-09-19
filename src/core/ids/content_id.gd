class_name ContentId
extends RefCounted

const _PATTERN := "^[a-z0-9_]+(\\.[a-z0-9_]+)+$"

static func is_valid(value: StringName) -> bool:
	var text := String(value)
	if text.is_empty():
		return false

	var regex := RegEx.new()
	if regex.compile(_PATTERN) != OK:
		return false

	return regex.search(text) != null
