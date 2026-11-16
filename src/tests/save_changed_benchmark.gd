extends "res://src/tests/save_pending_benchmark.gd"


## Changed save: current real pending result replaces its settled predecessor.
func _ready() -> void:
	var input: String = ""
	var output: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--input="):
			input = arg.trim_prefix("--input=")
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input))
	var current: SeasonState = SeasonSave._decode(data)
	check(current != null, "current retained pending restores")
	var prior_data: Dictionary = data.duplicate(true)
	payload(prior_data).physical.pending = {}
	var prior: SeasonState = SeasonSave._decode(prior_data)
	check(prior != null, "settled predecessor validates independently")
	if current == null or prior == null:
		get_tree().quit(1)
		return
	SeasonSave.path = "user://changed-save.json"
	var prior_snapshot: Dictionary = SeasonSave.snapshot(prior)
	var file: FileAccess = FileAccess.open(SeasonSave.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(prior_snapshot, "", true, true))
	file.close()
	var before: Dictionary = SeasonSave.snapshot(current)
	var start: int = Time.get_ticks_usec()
	var saved: bool = SeasonSave.save(current)
	var elapsed: int = Time.get_ticks_usec() - start
	check(saved, "new pending checkpoint durably replaces settled predecessor")
	check(
		ClubCareer.same(JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path)), data),
		"primary exactly current pending"
	)
	check(
		ClubCareer.same(
			JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path + ".bak")),
			prior_snapshot
		),
		"backup exactly different valid predecessor"
	)
	check(ClubCareer.same(before, SeasonSave.snapshot(current)), "source unchanged")
	var result: Dictionary = {
		"checks": checks,
		"failures": failures,
		"us": elapsed,
		"snapshot": digest(before),
		"backup_snapshot": digest(prior_snapshot),
		"input": input
	}
	file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t", true, true))
	file.close()
	print("CHANGED_SAVE_RESULT ", JSON.stringify(result))
	get_tree().quit(0 if failures == 0 else 1)
