class_name SeasonTacticalCombo
extends RefCounted
## One named exception, with both exact consumed copies bound to the same batter/PA.


static func valid(build: SeasonBuild, actions: Array, game: int = -1) -> bool:
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
	if build._format < 16 or pair.size() != 2 or not _owned_for_game(build, game):
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


static func _owned_for_game(build: SeasonBuild, game: int) -> bool:
	if not SeasonSchoolSponsors.active(build, "E07").is_empty():
		return true
	# A used pair survives a later live sale, bound to this saved match attempt.
	if build._format < 26 or build._match_inventory.get("game", -2) != game:
		return false
	for copy: Dictionary in build._match_inventory.get("sponsors", []):
		if copy.item == "E07":
			return true
	return false
