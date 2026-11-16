extends RefCounted
## Transport identity only. This does not validate a season or cache any validator.
const PROFILE = "res://src/presentation/stadium/stadium_npc_current_source_profile.gd"
const MAX_BYTES = 8 * 1024 * 1024
const ROOT = "res://src/gameplay/season/async_save"

static func binding() -> Dictionary:
	var paths: Array[String] = ["res://project.godot"]
	_collect("res://src", paths)
	paths.sort()
	var rows: Array[String] = []
	for path: String in paths:
		var digest: String = FileAccess.get_sha256(path)
		if digest.is_empty():
			return {}
		rows.append(path + ":" + digest)
	# Bind external prototype scripts too, not merely the installed project.
	for name: String in ["async_save_protocol.gd", "async_save_worker.gd", "async_save_validator.gd", "async_save_coordinator.gd", "async_save_ui.gd"]:
		var path: String = ROOT.path_join(name)
		var digest: String = FileAccess.get_sha256(path)
		if digest.is_empty():
			return {}
		rows.append(name + ":" + digest)
	return {"source": "\n".join(rows).sha256_text(), "profile": FileAccess.get_sha256(PROFILE),
		"engine": FileAccess.get_sha256(OS.get_executable_path())}

static func _collect(root: String, result: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(root):
		result.append(root.path_join(file))
	for directory: String in DirAccess.get_directories_at(root):
		_collect(root.path_join(directory), result)

static func bytes_at(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	return bytes if file.get_error() == OK else null

static func digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		hashing.update(bytes)
	return hashing.finish().hex_encode()

static func standalone(season: SeasonState) -> bool:
	return season != null and season.career == null and season.build != null \
		and season.build.pitch_catalog_expanded() and season._dynasty_owner_binding.is_empty() \
		and not SeasonSave.dynasty_owner_bound() \
		and season._dynasty_career_session.is_empty() \
		and WorkingPitchDynastySave.owner_context_valid(season)
