class_name MatchColdStreak
extends RefCounted
## Finalized individual batting outcomes; walks are neutral and hits clear after contact.

var appearances: Dictionary = {}
var _cold: Dictionary = {}
var _resolved: Dictionary = {}


func complete(state: MatchState, outcome: String) -> void:
	if _resolved.has(state.plate_appearance_number):
		return
	_resolved[state.plate_appearance_number] = true
	var player: PlayerMatchState = state.batter()
	var id: String = String(player.definition.id)
	if not appearances.has(id):
		appearances[id] = []
	appearances[id].append(outcome)
	if not player.definition.season_sponsors.get("E10", false):
		_cold.erase(id)
	elif outcome in ["single", "double", "triple", "hr"]:
		_cold[id] = 0
	elif outcome in ["out", "strikeout"]:
		_cold[id] = mini(2, stacks(player) + 1)


func stacks(player: PlayerMatchState) -> int:
	if not player.definition.season_sponsors.get("E10", false):
		return 0
	return int(_cold.get(String(player.definition.id), 0))


func evidence(team: TeamMatchState) -> Dictionary:
	var result: Dictionary = {}
	for player: PlayerMatchState in team.roster:
		var id: String = String(player.definition.id)
		result[id] = appearances.get(id, []).duplicate()
	return result


func label(player: PlayerMatchState) -> String:
	var count: int = stacks(player)
	return "Cold %d/2 • Power +%d%% speed • Contact −%d%% coverage" % [count, count * 3, count * 4]


func swing(
	profile: SwingProfileDefinition, source: SwingProfileDefinition, player: PlayerMatchState
) -> void:
	var count: int = stacks(player)
	var misc: Dictionary = SeasonGearCatalog.item(player.definition.season_gear.get("misc", ""))
	if source.id == &"swing.power":
		profile.gear_fair_exit_scale += count * 0.03 * float(misc.get("exit", 1.0))
	elif source.id == &"swing.contact":
		var penalty: float = count * 0.04 * float(misc.get("radius", 1.0))
		profile.contact_radius_x_m -= source.contact_radius_x_m * penalty
		profile.contact_radius_y_m -= source.contact_radius_y_m * penalty
