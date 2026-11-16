extends "res://src/tests/stadium_mogul_one_tracking_test.gd"
## Exact-field scheduling diagnosis only. No native image or visibility qualification claim.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await HistoryProof.run(self, true, true)
	await TestAudioDrain.finish(get_tree())
	print(
		"Wiffaltro AM-01 lock diagnostic finished: four authentic trials; no pixel qualification."
	)
	get_tree().quit(0 if _failures == 0 else 1)
