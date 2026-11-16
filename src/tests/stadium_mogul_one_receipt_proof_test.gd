extends Node
## Short exact receipt diagnosis. It cannot substitute for tracking or venue qualification.

const Proof = preload("res://src/tests/stadium_mogul_one_evidence_proof.gd")

var _failures: int = 0


func _ready() -> void:
	Proof.run(self)
	await TestAudioDrain.finish(get_tree())
	print("Wiffaltro AM-01 receipt proof finished: failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(value: bool, label: String) -> void:
	if not value:
		_failures += 1
		push_error(label)
