class_name StadiumScoreboardReadout
extends RefCounted
## Read-only actual match data. No inning history, errors, averages, or clock are invented.


static func capture(state: MatchState) -> Dictionary:
	if state == null or state.home_team == null or state.away_team == null:
		return {}
	for row: Array in [[state.phase, MatchState.Phase.PRE_PITCH, MatchState.Phase.GAME_END],
		[state.inning, 1, 9999], [state.home_team.runs, 0, 9999],
		[state.away_team.runs, 0, 9999], [state.balls, 0, 4], [state.strikes, 0, 3], [state.outs, 0, 3]]:
		if not SeasonOwnership._whole(row[0], row[1], row[2]):
			return {}
	var final: bool = state.phase == MatchState.Phase.GAME_END
	var transition: bool = state.phase == MatchState.Phase.INNING_TRANSITION
	var batting: TeamMatchState = state.batting_team()
	var defense: TeamMatchState = state.defensive_team()
	return {"base": {"inning": state.inning, "home": state.home_team.runs,
		"away": state.away_team.runs},
		"held": state.phase in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY],
		"details": {"away_name": clean(state.away_team.display_name),
			"home_name": clean(state.home_team.display_name),
			"half": "FINAL" if final else "TOP" if state.top_half else "BOTTOM",
			"balls": str(state.balls), "strikes": str(state.strikes), "outs": str(state.outs),
			"batter_heading": "GAME COMPLETE" if final else "INNING BREAK" if transition else "NOW BATTING",
			"pitcher_heading": "FINAL SCORE" if final else "ON THE MOUND",
			"batter": "" if final or transition else _player(batting, batting.batting_index),
			"pitcher": "" if final or transition else _player(defense, defense.pitcher_index),
			"event": clean(state.last_event)}}


static func _player(team: TeamMatchState, index: int) -> String:
	if team == null or index < 0 or index >= team.roster.size() \
		or team.roster[index] == null or team.roster[index].definition == null:
		return ""
	return clean(team.roster[index].definition.display_name)


static func clean(value: String) -> String:
	return value.replace("\n", " ").replace("\r", " ").replace("\t", " ").left(512)
