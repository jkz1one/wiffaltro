class_name MatchGearUsage
extends RefCounted
## Capture the player's exact equipped receipts on the first actual release.

var equipped: Array[String] = []
var first_pitch: Array[String] = []
var started: bool = false


func released() -> void:
	if started:
		return
	started = true
	first_pitch = equipped.duplicate()
