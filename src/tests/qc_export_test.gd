# gdlint: disable=max-returns
extends Node


func _ready() -> void:
	var exporter: PlayRecordExport = PlayRecordExport.new()
	var field: FieldDefinition = ContentDB.get_field(&"field.starter_backyard")
	var record: PlayRecord = PlayRecord.new()
	record.mode = "match"
	record.play_number = 1
	record.result = &"single"
	var records: Array[PlayRecord] = [record]
	if exporter.save(records, field) != OK:
		_fail("initial QC save failed")
		return
	var first_path: String = exporter.path
	if exporter.save(records, field) != OK:
		_fail("repeated QC save failed")
		return
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(first_path))
	if payload.records.size() != 1 or payload.records[0].mode != "match":
		_fail("repeated save duplicated records or lost mode")
		return
	if payload.field.single_m != field.safe_hit_z_m:
		_fail("QC snapshot lost loaded field geometry")
		return
	var second: PlayRecord = PlayRecord.new()
	second.mode = "mechanics_lab"
	records.append(second)
	if exporter.save(records, field) != OK:
		_fail("updated QC save failed")
		return
	payload = JSON.parse_string(FileAccess.get_file_as_string(first_path))
	if payload.records.size() != 2 or payload.records[1].mode != "mechanics_lab":
		_fail("QC update lost the second record")
		return
	var next_session: PlayRecordExport = PlayRecordExport.new()
	if next_session.save([], field) != OK or next_session.path == first_path:
		_fail("new session must preserve the previous session file")
		return
	if not FileAccess.file_exists(first_path):
		_fail("new session erased previous records")
		return
	DirAccess.remove_absolute(first_path)
	DirAccess.remove_absolute(next_session.path)
	if not _test_automatic_save(field):
		return
	print("Wiffaltro QC export checks passed.")
	get_tree().quit(0)


func _test_automatic_save(field: FieldDefinition) -> bool:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._field_definition = field
	lab._active_play_record = PlayRecord.new()
	PitchBatLabFeelSupport.finish_record(lab, &"single")
	var previous_path: String = lab._record_export.path
	PitchBatLabFeelSupport.clear_records(lab)
	lab._active_play_record = PlayRecord.new()
	PitchBatLabFeelSupport.finish_record(lab, &"double")
	var current_path: String = lab._record_export.path
	var passed: bool = (
		previous_path != current_path and FileAccess.file_exists(previous_path)
		and FileAccess.file_exists(current_path) and lab._play_records.size() == 1
	)
	DirAccess.remove_absolute(previous_path)
	DirAccess.remove_absolute(current_path)
	lab.free()
	if not passed:
		_fail("completed plays must autosave and reset must preserve earlier files")
	return passed


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
