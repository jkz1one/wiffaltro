class_name PhysicalJobFiles
extends RefCounted
## JSON-only local transport. Never deserialize objects or accept arbitrary executable paths.

const ROOT: String = "user://physical-jobs"
const LIMIT: int = 12 * 1024 * 1024


static func directory(token: String) -> String:
	if token.length() != 32 or not token.is_valid_hex_number(false):
		return ""
	return ProjectSettings.globalize_path(ROOT.path_join(token))


static func read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > LIMIT:
		return null
	return JSON.parse_string(file.get_as_text())


static func write(path: String, value: Variant) -> bool:
	var text: String = JSON.stringify(value, "", true, true)
	if text.to_utf8_buffer().size() > LIMIT:
		return false
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(path + ".tmp", path) == OK


static func clean(token: String) -> void:
	var folder: String = directory(token)
	if folder.is_empty():
		return
	for name: String in ["request.json", "response.json", "status.json", "heartbeat.json",
		"worker.log", "worker.log.1", "worker-settings.cfg", "diagnostics.json"]:
		for suffix: String in ["", ".tmp"]:
			if FileAccess.file_exists(folder.path_join(name + suffix)):
				DirAccess.remove_absolute(folder.path_join(name + suffix))
	DirAccess.remove_absolute(folder)
