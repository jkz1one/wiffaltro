class_name PlayRecordExport
extends RefCounted

var path: String = ""
var _revision: String = "unknown"
var _source_dirty: Variant = null


func save(records: Array[PlayRecord], field: FieldDefinition, stadium: Dictionary = {}) -> Error:
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
		"field": field_metadata(field, stadium),
		"records": serialized,
	}
	if payload.field.has("property_key"):
		payload.schema_version = 2
		payload["property"] = StadiumLayoutSnapshot.normalized(stadium)
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


func prepare_manual_ac02_v1(records: Array[PlayRecord], field: FieldDefinition,
	stadium: Dictionary) -> Dictionary:
	# Only the versioned command admits participants. This method grants no authority.
	# All serialization, metadata, time and git reads precede that command's full audit.
	# Neither the live exporter nor the filesystem is changed by preparation.
	var target: String = path
	var revision_source: PlayRecordExport = PlayRecordExport.new()
	revision_source._revision = _revision
	revision_source._source_dirty = _source_dirty
	if target.is_empty():
		target = "user://qc/plays-%d-%d.json" % [
			int(Time.get_unix_time_from_system() * 1000000), OS.get_process_id()]
		revision_source._read_revision()
	var serialized: Array[Dictionary] = []
	for record: PlayRecord in records:
		serialized.append(record.to_dict())
	var metadata: Dictionary = field_metadata(field, stadium)
	var payload: Dictionary = {
		"schema_version": 1,
		"session_id": target.get_file().get_basename(),
		"engine": Engine.get_version_info().string,
		"commit": revision_source._revision,
		"source_dirty": revision_source._source_dirty,
		"field": metadata,
		"records": serialized,
	}
	return {"metadata": [target, revision_source._revision, revision_source._source_dirty],
		"mkdir": path.is_empty(), "field_line": "WIFFALTRO_FIELD_QC " + JSON.stringify(metadata),
		"records_line": "WIFFALTRO_PLAY_RECORDS " + JSON.stringify(serialized),
		"file_text": JSON.stringify(payload, "\t") + "\n",
		"success_status": "Saved %d records to %s" % [records.size(),
			ProjectSettings.globalize_path(target)]}


static func field_metadata(field: FieldDefinition, stadium: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"field_id": String(field.id),
		"single_m": field.safe_hit_z_m,
		"deep_air_m": field.deep_air_z_m,
		"wall_m": field.back_wall_z_m,
		"hr_height_m": field.home_run_height_m,
		"shallow_anchor_m": field.shallow_anchor_z_m,
		"side_anchor_x_m": field.side_anchor_x_m,
	}
	if not stadium.get("layout") is Dictionary \
		or not (SeasonOwnership._whole(stadium.layout.get("version"), 11, 11)
			or SeasonOwnership._whole(stadium.layout.get("version"), 14, 14)
			or SeasonOwnership._whole(stadium.layout.get("version"), 15, 15)) \
		or not StadiumLayoutSnapshot.valid(stadium):
		return result
	var graph: StadiumRecipeBoundary = StadiumOwnedLayout.graph_for(stadium.layout)
	var rows: Array[Dictionary] = StadiumBoundaryGraph.segments() if graph == null else (
		graph.segments())
	result["property_key"] = StadiumLayoutSnapshot.key(stadium)
	result["boundary"] = stadium.boundary
	result["wall_sections"] = []
	result["wall_measurement"] = "maximum_forward_depth"
	result.wall_m = 0.0
	for row: Dictionary in rows:
		result.wall_m = maxf(result.wall_m, maxf(row.a.y, row.b.y))
		result.wall_sections.append({"id": row.id, "a": [row.a.x, row.a.y],
			"b": [row.b.x, row.b.y], "height_m": row.height, "role": row.role})
	return result


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
