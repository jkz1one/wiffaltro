extends "res://src/tests/stadium_mounted_scoreboard_staging_test.gd"
## Normal paid mounted save/reopen and failed-write/land/season transition atomicity.


func _ready() -> void:
	SeasonSave.path = "user://mounted-scoreboard-save-%d.json" % OS.get_process_id()
	_check(StadiumMountedScoreboardLayout.RUNTIME_READY, "mounted normal admission is enabled")
	await _admitted()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard save passed: exact ownership and atomic normal saves.")
	get_tree().quit(0 if _failures == 0 else 1)
