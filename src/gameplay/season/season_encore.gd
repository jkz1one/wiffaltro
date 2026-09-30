class_name SeasonEncore
extends RefCounted
## One explicit return exception; ordinary pitching changes retain the no-return rule.


static func available(team: TeamMatchState, index: int) -> bool:
	return (
		not team.encore_used
		and index >= 0
		and index < team.roster.size()
		and index != team.pitcher_index
		and team.roster[index].pitching_finished
		and bool(team.roster[index].definition.season_sponsors.get("G05", false))
	)


static func return_pitcher(state: MatchState, index: int) -> bool:
	var team: TeamMatchState = state.defensive_team()
	if not state.can_change_defense() or not available(team, index):
		return false
	# Reuse the same player instance, including stamina, opening-batter and Recovery flags.
	team.roster[index].pitching_finished = false
	if not team.select_pitcher(index):
		team.roster[index].pitching_finished = true
		return false
	team.encore_used = true
	return true
