class_name MatchPitchLedger
extends RefCounted
## Actual successful releases, partitioned by pitcher within one plate appearance.
## Keep the first cost of only the first three distinct exact recipe IDs.

var _pitchers: Dictionary = {}


func record(player: PlayerMatchState, recipe: StringName, paid: float) -> void:
	if recipe.is_empty() or not is_finite(paid) or paid < 0.0 or player.pitch_count < 1:
		return
	var id: StringName = player.definition.id
	var row: Dictionary = _pitchers.get(id, {"release": 0, "recipes": [], "costs": []})
	if player.pitch_count <= row.release:
		return
	row.release = player.pitch_count
	if row.recipes.size() < 3 and not row.recipes.has(recipe):
		row.recipes.append(recipe)
		row.costs.append(paid)
	_pitchers[id] = row


func first_costs(player_id: StringName) -> Array:
	return _pitchers.get(player_id, {}).get("costs", []).duplicate()


func clear() -> void:
	_pitchers.clear()
