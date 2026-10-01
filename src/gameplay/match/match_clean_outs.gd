class_name MatchCleanOuts
extends RefCounted
## Final fielded outs only, recorded before the PA advances; no paid effect required.

var rows: Array[Dictionary] = []
var _last_pa: int = -1


func record(state: MatchState, play: BallPlayState, outcome: BallPlayOutcome) -> void:
	if outcome.result != BallPlayOutcome.Result.OUT or _last_pa == state.plate_appearance_number:
		return
	if play.last_defender_touch not in [&"primary_fielder", &"pitcher"]:
		return
	_last_pa = state.plate_appearance_number
	var primary: bool = play.last_defender_touch == &"primary_fielder"
	rows.append(
		{
			"pa": state.plate_appearance_number,
			"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
			"player": String((state.fielder() if primary else state.pitcher()).definition.id),
			"pitcher": String(state.pitcher().definition.id),
			"primary": primary,
			"air": outcome.caught,
			"clean": not play.bobbled and not play.is_foul_play
		}
	)

	state.defensive_team().field_supply.record(state, rows[-1])


func evidence(team: TeamMatchState) -> Array:
	var ids: Array[String] = []
	for player: PlayerMatchState in team.roster:
		ids.append(String(player.definition.id))
	return rows.filter(func(row: Dictionary) -> bool: return ids.has(row.player)).duplicate(true)
