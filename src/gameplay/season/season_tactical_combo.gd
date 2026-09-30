class_name SeasonTacticalCombo
extends RefCounted
## One named exception, with both exact consumed copies bound to the same batter/PA.


static func valid(build: SeasonBuild, actions: Array) -> bool:
	var pair: Array = []
	for action: Variant in actions:
		if not action is Dictionary:
			return false
		if action.has("combo"):
			if not action.combo is bool or not action.combo:
				return false
			pair.append(action)
	if pair.is_empty():
		return true
	if (
		build._format < 16
		or pair.size() != 2
		or SeasonSchoolSponsors.active(build, "E07").is_empty()
	):
		return false
	var types: Array[String] = []
	for action: Dictionary in pair:
		if not action.get("receipt") is String:
			return false
		var copy: Dictionary = SeasonOwnership._owned(build._bank.view(), action.receipt)
		if copy.is_empty():
			return false
		types.append(copy.item)
	return (
		types == ["A10", "C03"]
		and pair[0].get("pa", -1) == pair[1].get("pa", -2)
		and pair[0].get("player", "") == pair[1].get("player", "invalid")
	)
