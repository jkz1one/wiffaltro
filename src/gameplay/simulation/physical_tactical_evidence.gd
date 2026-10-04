class_name PhysicalTacticalEvidence
extends RefCounted
## Version3 binds each paid copy and deterministic featured-hitter use to actual PAs.
# gdlint: disable=max-returns


static func valid(row: Variant, roster: Array, performance: Dictionary, parity: int) -> bool:
	if not row is Dictionary or not SeasonOwnership._keys(row,
		["version", "featured", "plan", "initial", "consumed", "remaining", "stances"]):
		return false
	if not SeasonOwnership._whole(row.version, 1, 1) or not row.featured is String \
		or not roster.has(row.featured) or row.plan not in ["swing.contact", "swing.power"] \
		or not row.initial is Array or row.initial.size() > 2 or not row.consumed is Array \
		or row.consumed.size() > row.initial.size() or not row.remaining is Array \
		or not row.stances is Array:
		return false
	var ids: Array = []
	for copy: Variant in row.initial:
		if not copy is Dictionary or not SeasonOwnership._keys(copy, ["id", "item", "paid", "kind"]):
			return false
		if not copy.id is String or copy.id.is_empty() or ids.has(copy.id) \
			or copy.item not in SeasonOpponentTactics.ITEMS or copy.kind != "held" \
			or not SeasonOwnership._whole(copy.paid, 3, 3):
			return false
		ids.append(copy.id)
	var held: Array = row.initial.duplicate(true)
	var cursor: int = 0
	var counts: Dictionary = {}
	var previous: int = 0
	var ordinal: int = 0
	for stance: Variant in row.stances:
		if not stance is Dictionary or not SeasonOwnership._keys(stance,
			["pa", "half", "player", "left"]):
			return false
		if not SeasonOwnership._whole(stance.pa, previous + 1, 99999) \
			or not SeasonOwnership._whole(stance.half, 0, 9999) or int(stance.half) % 2 != parity \
			or stance.player != roster[ordinal % 4] or not stance.left is bool:
			return false
		previous = int(stance.pa)
		ordinal += 1
		counts[stance.player] = counts.get(stance.player, 0) + 1
		var selected: Dictionary = SeasonOpponentTactics.select(
			held, stance.player, row.featured, row.plan)
		if selected.is_empty():
			continue
		if cursor >= row.consumed.size():
			return false
		var action: Variant = row.consumed[cursor]
		cursor += 1
		if not action is Dictionary or not SeasonOwnership._keys(action,
			["receipt", "player", "pa", "swing"]):
			return false
		if action.receipt != selected.receipt or action.player != stance.player \
			or not SeasonOwnership._whole(action.pa, int(stance.pa), int(stance.pa)) \
			or action.swing != selected.swing:
			return false
		for index in range(held.size()):
			if held[index].id == action.receipt:
				held.remove_at(index)
				break
	for id: String in roster:
		if not performance.has(id) or counts.get(id, 0) != performance[id].pa:
			return false
	return cursor == row.consumed.size() and ClubCareer.same(held, row.remaining)


static func matches(row: Dictionary, team: TeamMatchState) -> bool:
	var player: PlayerDefinition = null
	for candidate: PlayerMatchState in team.roster:
		if String(candidate.definition.id) == team.ai_tactical_hitter:
			player = candidate.definition
	return player != null and row.featured == team.ai_tactical_hitter \
		and row.plan == SeasonOpponentTactics.plan(player) \
		and ClubCareer.same(row.initial, team.ai_tactical_initial)


static func report_valid(data: Dictionary) -> bool:
	var value: Variant = data.get("tactics")
	if not value is Dictionary or not SeasonOwnership._keys(value, ["version", "clubs", "teams"]):
		return false
	if not SeasonOwnership._whole(value.version, 1, 1) or not value.clubs is Array \
		or value.clubs.size() != 2 or not value.teams is Array or value.teams.size() != 2:
		return false
	if not value.clubs[0] is bool or not value.clubs[1] is bool \
		or not (value.clubs[0] or value.clubs[1]):
		return false
	for index in range(2):
		if value.clubs[index]:
			if not valid(value.teams[index], data.teams[index].roster, data.performance, index) \
				or not ClubCareer.same(value.teams[index].stances, data.teams[index].stances):
				return false
		elif not value.teams[index] is Dictionary or not value.teams[index].is_empty():
			return false
	return true


static func report_matches(data: Dictionary, state: MatchState) -> bool:
	var teams: Array[TeamMatchState] = [state.away_team, state.home_team]
	var flags: Array = teams.map(func(team: TeamMatchState) -> bool:
		return not team.ai_tactical_hitter.is_empty())
	if not (flags[0] or flags[1]):
		return data.version != PhysicalMatchReport.TACTICAL_VERSION
	if data.version != PhysicalMatchReport.TACTICAL_VERSION or data.tactics.clubs != flags:
		return false
	for index in range(2):
		if flags[index] and not matches(data.tactics.teams[index], teams[index]):
			return false
	return true


static func human_matches(
	season: SeasonState, fixture: Dictionary, row: Dictionary, performance: Dictionary
) -> bool:
	if season.opponents == null or season.opponents._format < 9:
		return row.is_empty()
	var index: int = fixture.away if fixture.home == 0 else fixture.home
	return valid(row, season.teams[index].roster, performance, 0 if fixture.away == index else 1) \
		and matches(row, season._make_team(index))
