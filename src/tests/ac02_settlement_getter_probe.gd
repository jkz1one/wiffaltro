extends Node
## Unknown scripted app-shaped component probe, never attached or issued.
var events: Array[String] = []
var lab: Variant:
	get:
		events.append("lab")
		return null
var season: Variant:
	get:
		events.append("season")
		return null
var _ac02_settlement_ticket: Dictionary:
	get:
		events.append("ticket")
		return {}


func _get(property: StringName) -> Variant:
	events.append("dynamic:" + String(property))
	return null
