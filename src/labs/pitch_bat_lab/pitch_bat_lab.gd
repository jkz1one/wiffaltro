extends Node3D

func _ready() -> void:
	if not ContentDB.validate_or_error():
		push_error("Pitch/Bat Lab foundation loaded with invalid content.")
		return

	print(
		"Pitch/Bat Lab foundation ready: %d pitch(es), %d player(s), %d delivery profile(s)."
		% [
			ContentDB.pitch_by_id.size(),
			ContentDB.player_by_id.size(),
			ContentDB.delivery_by_id.size(),
		]
	)
