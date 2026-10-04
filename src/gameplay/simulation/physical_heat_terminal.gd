class_name PhysicalHeatTerminal
extends RefCounted
## A human Base game ending can end a legal defensive activation before any pitch/credited PA.
# gdlint: disable=max-returns


static func capture(state: MatchState, team: TeamMatchState, row: Dictionary) -> void:
	if state.phase != MatchState.Phase.GAME_END or state.top_half or team != state.away_team:
		return
	var pa: int = state.plate_appearance_number
	var actions: Array = team.tactics.consumed.filter(func(action: Dictionary) -> bool:
		return action.pa == pa)
	var bases: Array = state.home_team.tactics.consumed.filter(func(action: Dictionary) -> bool:
		return action.pa == pa and action.get("advance", {}).get("to") == 4)
	if actions.size() != 1 or bases.size() != 1 or state.sides.rows.any(
		func(stance: Dictionary) -> bool: return stance.pa == pa):
		return
	row["terminal"] = {"pa": pa, "half": (state.inning - 1) * 2 + 1,
		"player": String(state.batter().definition.id), "pitcher": actions[0].player,
		"base_receipt": bases[0].receipt, "advance": bases[0].advance.duplicate(true)}


static func valid(row: Dictionary, roster: Array, performance: Dictionary, parity: int) -> bool:
	var terminal: Variant = row.terminal
	if parity != 0 or not terminal is Dictionary or not SeasonOwnership._keys(terminal,
		["pa", "half", "player", "pitcher", "base_receipt", "advance"]):
		return false
	if not row.get("opposition") is Dictionary or not row.opposition.get("stances") is Array \
		or not row.opposition.get("roster") is Array or row.opposition.roster.size() != 4 \
		or not row.get("stances") is Array or not row.get("consumed") is Array \
		or row.consumed.is_empty() or not row.get("initial") is Array:
		return false
	var total: int = row.stances.size() + row.opposition.stances.size()
	if not SeasonOwnership._whole(terminal.pa, total + 1, total + 1) \
		or not SeasonOwnership._whole(terminal.half, 5, 9999) or int(terminal.half) % 2 != 1 \
		or terminal.player != row.opposition.get("target") \
		or terminal.player != row.opposition.roster[row.opposition.stances.size() % 4] \
		or not terminal.pitcher is String or not roster.has(terminal.pitcher) \
		or not terminal.base_receipt is String or terminal.base_receipt.is_empty() \
		or not TacticalBaseAdvance.valid(terminal.advance, row.opposition.roster, performance) \
		or terminal.advance.from != 3 or terminal.advance.to != 4:
		return false
	var action: Variant = row.consumed[-1]
	if not action is Dictionary or not SeasonOwnership._keys(
		action, ["receipt", "player", "pa", "swing"]):
		return false
	if action.pa != terminal.pa or action.player != terminal.pitcher or action.swing != "":
		return false
	var copies: Array = row.initial.filter(func(copy: Variant) -> bool:
		return (copy is Dictionary and copy.get("id") == action.get("receipt")
			and copy.get("item") == SeasonTacticalCatalog.HEAT))
	if copies.size() != 1:
		return false
	var ordinary: Dictionary = row.duplicate(true)
	ordinary.erase("terminal")
	ordinary.consumed.pop_back()
	ordinary.remaining = []
	for copy: Variant in row.initial:
		var used: bool = false
		for consumed: Variant in ordinary.consumed:
			if consumed is Dictionary and copy is Dictionary \
				and consumed.get("receipt") == copy.get("id"):
				used = true
		if not used:
			ordinary.remaining.append(copy)

	if not PhysicalHeatEvidence.valid(ordinary, roster, performance, parity):
		return false
	var half: int = 0
	for stance: Dictionary in ordinary.stances + ordinary.opposition.stances:
		half = maxi(half, int(stance.half))
	if not SeasonOwnership._whole(terminal.half, half, half + 1):
		return false
	return ClubCareer.same(row.remaining, ordinary.remaining.filter(func(copy: Dictionary) -> bool:
		return copy.id != action.receipt))


static func human(row: Dictionary, tactics: Array, fixture: Dictionary) -> bool:
	if not row.has("terminal"):
		return true
	if fixture.home != 0 or tactics.is_empty():
		return false
	var terminal: Dictionary = row.terminal
	var action: Variant = tactics[-1]
	if not action is Dictionary or action.get("receipt") != terminal.base_receipt \
		or action.get("pa") != terminal.pa or action.get("player") != terminal.player \
		or not ClubCareer.same(action.get("advance"), terminal.advance):
		return false
	# Live reward validates actual Base ownership; decoded build replay already validates the ledger.
	return SeasonOwnership._keys(action, ["receipt", "player", "pa", "swing", "advance"]) \
		and action.get("swing") == ""


static func ended(row: Dictionary, home_runs: int, away_runs: int) -> bool:
	if not row.has("terminal"):
		return true
	if not row.terminal is Dictionary or not row.terminal.get("half") is float \
		and not row.terminal.get("half") is int:
		return false
	var inning: int = int(row.terminal.half) / 2 + 1
	return home_runs > away_runs and (inning >= MatchState.REGULATION_INNINGS \
		or (inning >= 3 and home_runs - away_runs >= MatchState.MERCY_RUNS))
