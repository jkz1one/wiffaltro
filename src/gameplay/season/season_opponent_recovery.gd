class_name SeasonOpponentRecovery
extends RefCounted
## Paid planned-pitcher recovery precedes Heat, using only actual readiness workload.


static func eligible(capacity: float, remaining: float) -> bool:
	return capacity > 0.0 and capacity - remaining >= capacity * 0.10


static func prepare(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	if state == null or state.phase != MatchState.Phase.PRE_PITCH or not state.between_batters \
		or not MatchAutomation.pitching(lab):
		return
	var team: TeamMatchState = state.defensive_team()
	if team.ai_recovery_pitcher.is_empty() or team.recovery.ready.any(
		func(row: Dictionary) -> bool: return row.pa == state.plate_appearance_number):
		return
	var pitcher: PlayerMatchState = state.pitcher()
	team.recovery.ready.append({"pa": state.plate_appearance_number,
		"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
		"player": String(pitcher.definition.id), "remaining": pitcher.stamina_remaining})
	if String(pitcher.definition.id) != team.ai_recovery_pitcher \
		or not eligible(pitcher.stamina_max, pitcher.stamina_remaining):
		return
	for copy: Dictionary in team.tactics.held:
		if copy.item == "C02" and team.tactics.reason(state, team, copy.id).is_empty():
			team.tactics.activate(state, team, copy.id)
			return


static func evidence(state: MatchState, team: TeamMatchState, row: Dictionary) -> Dictionary:
	row.version = 3
	row["recovery"] = team.recovery.evidence(state, team)
	if state.phase == MatchState.Phase.GAME_END and not state.top_half and team == state.away_team:
		var pa: int = state.plate_appearance_number
		var bases: Array = state.home_team.tactics.consumed.filter(func(action: Dictionary) -> bool:
			return action.pa == pa and action.get("advance", {}).get("to") == 4)
		if bases.size() == 1 and not state.sides.rows.any(
			func(stance: Dictionary) -> bool: return stance.pa == pa):
			row["terminal"] = {"pa": pa, "half": (state.inning - 1) * 2 + 1,
				"player": String(state.batter().definition.id),
				"pitcher": String(state.pitcher().definition.id), "base_receipt": bases[0].receipt,
				"advance": bases[0].advance.duplicate(true)}
	return row
