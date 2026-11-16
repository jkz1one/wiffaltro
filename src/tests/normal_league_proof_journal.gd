extends RefCounted
## Harness-only write-ahead intent. No automatic reconciliation or game retry.
static func _read_json(file_path: String) -> Variant:
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(FileAccess.get_file_as_string(file_path))
	# Corrupt evidence is an expected refusal, not an engine error or repair request.
	return parser.data if error == OK else null

static func write_new(file_path: String, value: Dictionary) -> bool:
	if FileAccess.file_exists(file_path) or DirAccess.dir_exists_absolute(file_path): return false
	var bytes: String = JSON.stringify(value, "", true, true)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(bytes)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK and FileAccess.get_file_as_string(file_path) == bytes

static func ready(root: String, require_history: bool = false) -> bool:
	var folder: String = root.path_join("proof-journal")
	if not DirAccess.dir_exists_absolute(folder): return not require_history
	var names: PackedStringArray = DirAccess.get_files_at(folder)
	if require_history and names.is_empty(): return false
	for name: String in names:
		if not name.ends_with(".intent.json") and not name.ends_with(".complete.json"): return false
		var stem: String = name.trim_suffix(".intent.json") if name.ends_with(".intent.json") else name.trim_suffix(".complete.json")
		var intent_path: String = folder.path_join(stem + ".intent.json")
		var complete_path: String = folder.path_join(stem + ".complete.json")
		if not FileAccess.file_exists(intent_path) or not FileAccess.file_exists(complete_path): return false
		var intent: Variant = _read_json(intent_path)
		var complete: Variant = _read_json(complete_path)
		if not intent is Dictionary or not complete is Dictionary \
			or not SeasonOwnership._keys(complete, ["intent_sha256", "boundary", "boundary_sha256"]) \
			or complete.intent_sha256 != FileAccess.get_sha256(intent_path) \
			or not complete.boundary is String or complete.boundary.get_file() != complete.boundary \
			or not FileAccess.file_exists(root.path_join(complete.boundary)) \
			or complete.boundary_sha256 != FileAccess.get_sha256(root.path_join(complete.boundary)): return false
	return true

static func begin(root: String, name: String, binding: Dictionary) -> String:
	if name.get_file() != name or not ready(root): return ""
	var folder: String = root.path_join("proof-journal")
	if not DirAccess.dir_exists_absolute(folder) and DirAccess.make_dir_recursive_absolute(folder) != OK: return ""
	var intent: String = folder.path_join(name + ".intent.json")
	return intent if write_new(intent, binding) else ""

static func complete(root: String, intent: String, boundary: String) -> bool:
	if not FileAccess.file_exists(intent) or not FileAccess.file_exists(root.path_join(boundary)) \
		or not FileAccess.file_exists(root.path_join("resume-boundary.json")) \
		or FileAccess.get_sha256(root.path_join(boundary)) != FileAccess.get_sha256(root.path_join("resume-boundary.json")): return false
	var receipt: Variant = _read_json(root.path_join(boundary))
	if not receipt is Dictionary or receipt.get("save_sha256") != FileAccess.get_sha256(root.path_join("season.json")): return false
	return write_new(intent.trim_suffix(".intent.json") + ".complete.json", {
		"intent_sha256": FileAccess.get_sha256(intent), "boundary": boundary,
		"boundary_sha256": FileAccess.get_sha256(root.path_join(boundary))})
