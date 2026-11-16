extends Node3D
## Fixture-only entrant callback. Never admitted to the production lease domain.

var enter_hook: Callable


func _enter_tree() -> void:
	if enter_hook.is_valid():
		enter_hook.call(self)
