class_name MatchRecoveryFlow
extends RefCounted
## Policy11-only actual workload events; no synthetic charge or stamina reward.

var workload_initial: Dictionary = {}
var workload_events: Array[Dictionary] = []
var workload_input: Dictionary = {}

var initial: Dictionary = {}
var ready: Array[Dictionary] = []
var costs: Array[Dictionary] = []
var refunds: Array[Dictionary] = []
var refunders: Array[String] = []


func initialize(team: TeamMatchState) -> void:
	if LeagueRules.doubleheader(team.league_rules) and workload_initial.is_empty():
		for player: PlayerMatchState in team.roster:
			workload_initial[String(player.definition.id)] = {
				"capacity": player.stamina_max, "initial": player.stamina_remaining
			}
	if team.ai_recovery_pitcher.is_empty() or not initial.is_empty():
		return
	for player: PlayerMatchState in team.roster:
		var id: String = String(player.definition.id)
		initial[id] = {"capacity": player.stamina_max, "initial": player.stamina_remaining}
		if player.definition.season_sponsors.get("B03", false):
			refunders.append(id)


func release(state: MatchState, recipe: StringName, paid: float) -> void:
	if LeagueRules.doubleheader(state.defensive_team().league_rules):
		var after: float = state.pitcher().stamina_remaining
		var event: Dictionary = _workload_event(state, "release", after + paid, after)
		event["recipe"] = String(recipe)
		event["paid"] = paid
		event.merge(workload_input.duplicate(true))
		workload_input.clear()
		workload_events.append(event)
	if state.defensive_team().ai_recovery_pitcher.is_empty():
		return
	costs.append(
		{
			"pa": state.plate_appearance_number,
			"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
			"player": String(state.pitcher().definition.id),
			"recipe": String(recipe),
			"paid": paid
		}
	)


func refund(state: MatchState, amount: float) -> void:
	if LeagueRules.doubleheader(state.defensive_team().league_rules):
		var after: float = state.pitcher().stamina_remaining
		var event: Dictionary = _workload_event(state, "refund", after - amount, after)
		event["amount"] = amount
		workload_events.append(event)
	if not state.defensive_team().ai_recovery_pitcher.is_empty():
		refunds.append(
			{
				"pa": state.plate_appearance_number,
				"player": String(state.pitcher().definition.id),
				"amount": amount
			}
		)


func evidence(state: MatchState, team: TeamMatchState) -> Dictionary:
	var remaining: Dictionary = {}
	for player: PlayerMatchState in team.roster:
		remaining[String(player.definition.id)] = player.stamina_remaining
	return {
		"pitcher": team.ai_recovery_pitcher,
		"initial": initial.duplicate(true),
		"ready": ready.duplicate(true),
		"costs": costs.duplicate(true),
		"refunds": refunds.duplicate(true),
		"refunders": refunders.duplicate(),
		"strikeouts": state.sure_shot.evidence(team).strikeouts,
		"remaining": remaining
	}


func workload_recovery(state: MatchState, receipt: String, before: float) -> void:
	if not LeagueRules.doubleheader(state.defensive_team().league_rules):
		return
	var event: Dictionary = _workload_event(
		state, "recovery", before, state.pitcher().stamina_remaining
	)
	event["receipt"] = receipt
	workload_events.append(event)


static func _workload_event(
	state: MatchState, kind: String, before: float, after: float
) -> Dictionary:
	return {
		"kind": kind,
		"pa": state.plate_appearance_number,
		"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
		"player": String(state.pitcher().definition.id),
		"before": before,
		"after": after
	}
