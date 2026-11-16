extends Node
func _ready() -> void:
	print("PROBE_SOURCE_QUALIFIED=", StadiumNpcPublicRuntime.source_qualified())
	get_tree().quit()
