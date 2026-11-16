extends Node
## Deliberate inherited named-property hook, used only in disposable V71 controls.
var payload_reads: int = 0


func _get(name: StringName) -> Variant:
	if name in [&"process_mode", &"process_thread_group"]:
		payload_reads += 1
	return null
