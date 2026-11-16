extends "res://src/tests/stadium_season_test.gd"
## Rejected kill preconditions never enter the inherited OS termination probe.

var _guard_rejections: int = 0


func _ready() -> void:
	SeasonSave.path = "user://starter-pid-guard-%d.json" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	for row: Array in [[false, -1], [true, 0], [false, 999999]]:
		_app.round_ui.process_runner.running = row[0]
		_app.round_ui.process_runner._pid = row[1]
		await _killed_child()
	# Do not let fake runner state reach its normal cleanup path.
	_app.round_ui.process_runner.running = false
	_app.round_ui.process_runner._pid = -1
	_app.queue_free()
	if _guard_rejections == 3 and _failures == 0:
		print("Wiffaltro starter PID guard passed: three invalid child states refuse termination.")
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition and message == "kill probe requires this test's running positive child PID":
		_guard_rejections += 1
	else:
		super._check(condition, message)
