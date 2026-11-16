extends Node
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("SOURCE_CONTROL ", label, " ", value)
func _ready() -> void:
	check(StadiumHillsideDefinitionV1.sources_valid(), "qualified baseline")
	check(StadiumNpcPublicRuntime.source_qualified(), "whole profile baseline")
	if failures > 0:
		get_tree().quit(1)
		return
	var paths: Array[String] = []
	for key in StadiumHillsideDefinitionV1.RETAINED_SOURCE_SUCCESSORS:
		paths.append(StadiumHillsideDefinitionV1.SOURCE_PATHS[key])
	paths.append(StadiumHillsideDefinitionV1.SOURCE_PATHS["terrain-ground-contact"])
	paths.append("res://src/gameplay/stadium/stadium_hillside_definition_v1.gd")
	for path in paths:
		var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var before: String = FileAccess.get_sha256(path)
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(original)
		file.store_string("\n# isolated source-tamper negative control\n")
		file.close()
		check(not StadiumHillsideDefinitionV1.sources_valid(), "reject "+path)
		check(not StadiumNpcPublicRuntime.source_qualified(), "profile reject "+path)
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
		check(FileAccess.get_sha256(path) == before, "restored bytes "+path)
		check(StadiumHillsideDefinitionV1.sources_valid(), "restored source qualification "+path)
	print("HILLSIDE_SOURCE_CONTROLS checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
