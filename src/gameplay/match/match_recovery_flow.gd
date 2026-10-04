class_name MatchRecoveryFlow
extends RefCounted
## Policy11-only actual workload events; no synthetic charge or stamina reward.

var initial: Dictionary = {}
var ready: Array[Dictionary] = []
var costs: Array[Dictionary] = []
var refunds: Array[Dictionary] = []
var refunders: Array[String] = []


func initialize(team: TeamMatchState) -> void:
	if team.ai_recovery_pitcher.is_empty() or not initial.is_empty():
		return
	for player: PlayerMatchState in team.roster:
		var id: String = String(player.definition.id)
		initial[id] = {"capacity": player.stamina_max, "initial": player.stamina_remaining}
		if player.definition.season_sponsors.get("B03", false):
			refunders.append(id)


func release(state: MatchState, recipe: StringName, paid: float) -> void:
	if state.defensive_team().ai_recovery_pitcher.is_empty():
		return
	costs.append({"pa": state.plate_appearance_number,
		"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
		"player": String(state.pitcher().definition.id), "recipe": String(recipe), "paid": paid})


func refund(state: MatchState, amount: float) -> void:
	if not state.defensive_team().ai_recovery_pitcher.is_empty():
		refunds.append({"pa": state.plate_appearance_number,
			"player": String(state.pitcher().definition.id), "amount": amount})


func evidence(state: MatchState, team: TeamMatchState) -> Dictionary:
	var remaining: Dictionary = {}
	for player: PlayerMatchState in team.roster:
		remaining[String(player.definition.id)] = player.stamina_remaining
	return {"pitcher": team.ai_recovery_pitcher, "initial": initial.duplicate(true),
		"ready": ready.duplicate(true), "costs": costs.duplicate(true),
		"refunds": refunds.duplicate(true), "refunders": refunders.duplicate(),
		"strikeouts": state.sure_shot.evidence(team).strikeouts, "remaining": remaining}
