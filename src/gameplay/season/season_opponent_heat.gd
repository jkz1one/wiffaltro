class_name SeasonOpponentHeat
extends RefCounted
## Policy10: public opposing ratings, paid shared Heat and no future-pitch sensing.


static func target(team: TeamMatchState) -> String:
	var players: Array[PlayerMatchState] = team.roster.duplicate()
	players.sort_custom(func(a: PlayerMatchState, b: PlayerMatchState) -> bool:
		return a.definition.power > b.definition.power if a.definition.power != b.definition.power \
			else String(a.definition.id) < String(b.definition.id))
	return String(players[0].definition.id)


static func prepare(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	if state == null or state.phase != MatchState.Phase.PRE_PITCH or not state.between_batters \
		or not MatchAutomation.pitching(lab) or not state.defensive_team().ai_heat \
		or String(state.batter().definition.id) != target(state.batting_team()):
		return
	var team: TeamMatchState = state.defensive_team()
	for copy: Dictionary in team.tactics.held:
		if copy.item == SeasonTacticalCatalog.HEAT:
			team.tactics.activate(state, team, copy.id)
			return


static func evidence(state: MatchState, team: TeamMatchState, row: Dictionary) -> Dictionary:
	var other: TeamMatchState = state.home_team if team == state.away_team else state.away_team
	row.version = 2
	row["opposition"] = {"roster": other.roster.map(func(player: PlayerMatchState) -> String:
		return String(player.definition.id)), "target": target(other),
		"stances": state.sides.evidence(other)}
	row["pitching"] = state.sure_shot.evidence(team).releases
	PhysicalHeatTerminal.capture(state, team, row)
	return row
