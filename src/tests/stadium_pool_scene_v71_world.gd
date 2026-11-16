extends World3D
## Deliberate World3D named-property hook for guarded-read controls.
var payload_reads: int = 0


func _get(name: StringName) -> Variant:
	if name == &"space":
		payload_reads += 1
	return null
