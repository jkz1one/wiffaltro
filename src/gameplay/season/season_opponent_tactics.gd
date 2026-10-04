class_name SeasonOpponentTactics
extends RefCounted
## Policy9: paid offensive supplies, shared capacity/effects and public pre-PA readiness.

const ITEMS: Array[String] = ["A10", "C03"]


static func pool() -> Dictionary:
	var result: Dictionary = {}
	for id: String in ITEMS:
		result[id] = SeasonTacticalCatalog.weights()[id]
	return result


static func purchase(build: SeasonBuild, club: Dictionary, game: int) -> bool:
	if build._market != 8 or build._bank.view().held.size() >= build._bank.view().capacity.held:
		return false
	for item: String in ITEMS:
		var price: int = SeasonTacticalCatalog.item(item).price
		if build.cash() < price:
			continue
		for offer: String in build._visit.offers:
			if build._visit.offers[offer] != item:
				continue
			var request: Dictionary = SeasonOpponentPolicy.command(build, "tactical_buy", {"offer": offer})
			if not build.commit(request).ok:
				return false
			club.decisions.append({"game": game, "request": request.id, "player": club.roles.hitter,
				"stat": "tactical", "item": item, "paid": price, "reason": "featured hitter supply"})
			return true
	return false


static func useful_price(build: SeasonBuild) -> int:
	return 3 if build._market == 8 and build._bank.view().held.size() < (
		build._bank.view().capacity.held) else 0


static func plan(player: PlayerDefinition) -> String:
	return "swing.power" if player.power > player.contact else "swing.contact"


static func select(held: Array, batter: String, featured: String, swing: String) -> Dictionary:
	if batter != featured:
		return {}
	for item: String in ITEMS:
		for copy: Dictionary in held:
			if copy.item == item:
				return {"receipt": copy.id, "swing": swing if item == "C03" else ""}
	return {}


static func prepare(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	if state == null or state.phase != MatchState.Phase.PRE_PITCH or not state.between_batters \
		or not MatchAutomation.batting(lab):
		return
	var team: TeamMatchState = state.batting_team()
	if team.ai_tactical_hitter.is_empty():
		return
	var action: Dictionary = select(team.tactics.held, String(state.batter().definition.id),
		team.ai_tactical_hitter, plan(state.batter().definition))
	if not action.is_empty():
		team.tactics.activate(state, team, action.receipt, StringName(action.swing))


static func evidence(state: MatchState, team: TeamMatchState) -> Dictionary:
	if team.ai_tactical_hitter.is_empty():
		return {}
	var player: PlayerDefinition = null
	for candidate: PlayerMatchState in team.roster:
		if String(candidate.definition.id) == team.ai_tactical_hitter:
			player = candidate.definition
	return {"version": 1, "featured": team.ai_tactical_hitter, "plan": plan(player),
		"initial": team.ai_tactical_initial.duplicate(true),
		"consumed": team.tactics.consumed.duplicate(true),
		"remaining": team.tactics.held.duplicate(true), "stances": state.sides.evidence(team)}
