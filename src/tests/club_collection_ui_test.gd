extends "res://src/tests/club_collection_test.gd"
## Focused saved acquisition/UI path; grouped transaction coverage stays in its own scenes.


func _ready() -> void:
	SeasonSave.path = "user://collection-ui-%d.json" % OS.get_process_id()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var season: SeasonState = _paid_discovery()
	if season != null:
		_migration_collection(season)
		await _collection_ui(season)
		_carry_collection(season)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro focused collection UI checks passed: 60 entries, saved discovery and migration."
		)
	get_tree().quit(0 if _failures == 0 else 1)
