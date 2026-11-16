extends "res://src/tests/season_opponent_tactics_test.gd"
## Existing comprehensive supply-policy units, without unrelated historical menu fixtures.


func _ready() -> void:
	_tactical_units()
	await _tactical_game("A10")
	print("AI_PLAN_POLICY failures=", _failures)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
