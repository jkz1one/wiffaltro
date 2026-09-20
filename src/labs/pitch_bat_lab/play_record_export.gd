class_name PlayRecordExport
extends RefCounted

var path: String = ""
var _revision: String = "unknown"
var _source_dirty: Variant = null


func save(records: Array[PlayRecord], field: FieldDefinition) -> Error:
	if path.is_empty():
		var folder: String = "user://qc"
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(folder)
		if directory_error != OK:
			return directory_error
		path = "%s/plays-%d-%d.json" % [
			folder, int(Time.get_unix_time_from_system() * 1000000), OS.get_process_id()
		]
		_read_revision()
	var serialized: Array[Dictionary] = []
	for record in records:
		serialized.append(record.to_dict())
	var payload: Dictionary = {
		"schema_version": 1,
		"session_id": path.get_file().get_basename(),
		"engine": Engine.get_version_info().string,
		"commit": _revision,
		"source_dirty": _source_dirty,
		"field": field_metadata(field),
		"records": serialized,
	}
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	return DirAccess.rename_absolute(path + ".tmp", path)


static func field_metadata(field: FieldDefinition) -> Dictionary:
	return {
		"field_id": String(field.id),
		"single_m": field.safe_hit_z_m,
		"deep_air_m": field.deep_air_z_m,
		"wall_m": field.back_wall_z_m,
		"hr_height_m": field.home_run_height_m,
		"shallow_anchor_m": field.shallow_anchor_z_m,
		"side_anchor_x_m": field.side_anchor_x_m,
	}


func _read_revision() -> void:
	var root: String = ProjectSettings.globalize_path("res://")
	if not DirAccess.dir_exists_absolute(root.path_join(".git")) \
		and not FileAccess.file_exists(root.path_join(".git")):
		return
	var output: Array = []
	if OS.execute("git", ["-C", root, "rev-parse", "HEAD"], output) == 0:
		_revision = str(output[0]).strip_edges()
	output.clear()
	if OS.execute("git", ["-C", root, "status", "--porcelain", "--untracked-files=no"], output) == 0:
		_source_dirty = not str(output[0]).strip_edges().is_empty()
