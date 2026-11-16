class_name PhysicalBudgetEvidence
extends RefCounted
## Proof4 adds a committed grant receipt; proof3 and all historical prices stay frozen.
# gdlint: disable=max-returns


static func shape(row: Variant, market: int = 11) -> bool:
	return _shape(row, market, 2)


static func league_shape(
	row: Variant, rules: Dictionary, ownership: Dictionary, market: int = 12
) -> bool:
	var wallet: Dictionary = PhysicalLeagueReport.wallet(rules, ownership)
	if wallet.is_empty():
		return false
	var tactical: Array = SeasonTacticalCatalog.held(wallet)
	# Development cards occupy the same bag even though AI proofs list only tactics.
	var capacity: int = int(wallet.capacity.held) - (wallet.held.size() - tactical.size())
	if not _shape(row, market, capacity):
		return false
	return ClubCareer.same(row.budget.before, tactical) \
		and row.budget.cash == wallet.cash and row.budget.active == wallet.sponsors.any(
			func(copy: Dictionary) -> bool: return copy.item == "E08")


# Only explicit ownership-replayed league adapters may supply a different capacity.
static func _shape(row: Variant, market: int, capacity: int) -> bool:
	if not row is Dictionary or row.get("version") != 4 or not row.get("budget") is Dictionary:
		return false
	var budget: Dictionary = row.budget
	if not SeasonOwnership._keys(budget, ["game", "cash", "active", "before", "outcome"]) \
		or not SeasonOwnership._whole(budget.game, 0, 32) \
		or not SeasonOwnership._whole(budget.cash, 0, 1000000) or not budget.active is bool \
		or not budget.before is Array or budget.before.size() > capacity:
		return false
	var outcome: String = "inactive" if not budget.active else "cash" if budget.cash > 4 \
		else "full" if budget.before.size() >= capacity else "granted"
	if budget.outcome != outcome:
		return false
	var expected: Array = budget.before.duplicate(true)
	if outcome == "granted":
		expected.append({"id": "budget:%d" % int(budget.game), "item": "C03", "paid": 0,
			"kind": "held"})
	if not row.get("initial") is Array or not ClubCareer.same(expected, row.initial):
		return false
	var ids: Array = []
	for copy: Variant in expected:
		if not copy is Dictionary or not SeasonOwnership._keys(copy, ["id", "item", "paid", "kind"]):
			return false
		if not copy.id is String or ids.has(copy.id) or copy.kind != "held" \
			or copy.item not in SeasonOpponentTactics.supported(market):
			return false
		ids.append(copy.id)
		if not SeasonOwnership._whole(copy.paid, 0, 100):
			return false
		if copy.paid == 0:
			if copy.item != "C03" or not grant_id(copy.id):
				return false
		elif not SeasonOwnership._whole(copy.paid, SeasonTacticalCatalog.item(copy.item).price,
			SeasonTacticalCatalog.item(copy.item).price) or copy.id.begins_with("budget:"):
			return false
	return true


static func grant_id(id: String) -> bool:
	if not id.begins_with("budget:"):
		return false
	var tail: String = id.trim_prefix("budget:")
	return tail.is_valid_int() and int(tail) in range(33) and str(int(tail)) == tail


static func recovery(row: Dictionary, normalize: bool = false) -> Dictionary:
	var result: Dictionary = row.duplicate(true)
	result.version = 3
	result.erase("budget")
	if normalize:
		for key: String in ["initial", "remaining"]:
			if not result.get(key) is Array:
				continue
			for copy: Variant in result[key]:
				if copy is Dictionary and copy.get("paid") == 0 and copy.get("item") == "C03":
					copy.paid = 3 # Adapter for unchanged historical structural checks only.
	return result


static func consistent_bag(row: Variant) -> bool:
	if not shape(row) or not row.get("remaining") is Array:
		return false
	# Reject price edits in remaining before adapting both arrays for the old validator.
	for copy: Variant in row.remaining:
		if not copy is Dictionary or not row.initial.any(func(initial: Dictionary) -> bool:
			return ClubCareer.same(initial, copy)):
			return false
	return true


static func valid(row: Variant, roster: Array, performance: Dictionary, parity: int) -> bool:
	return consistent_bag(row) and PhysicalRecoveryEvidence.valid(
		recovery(row, true), roster, performance, parity)


static func matches(row: Dictionary, team: TeamMatchState, other: TeamMatchState) -> bool:
	if not shape(row) or team.ai_budget.is_empty() or not ClubCareer.same(
		row.budget, team.ai_budget):
		return false
	var fresh: TeamMatchState = PhysicalMatchRequest._team(team)
	if fresh == null:
		return false
	fresh.ai_budget = {}
	return PhysicalRecoveryEvidence.matches(recovery(row), fresh, other)


static func report_valid(data: Dictionary) -> bool:
	var tactics: Variant = data.get("tactics")
	if not tactics is Dictionary or not SeasonOwnership._keys(tactics, ["version", "clubs", "teams"]):
		return false
	if tactics.version != 4 or not tactics.clubs is Array or tactics.clubs.size() != 2 \
		or not tactics.teams is Array or tactics.teams.size() != 2:
		return false
	var legacy: Dictionary = data.duplicate()
	legacy.tactics = tactics.duplicate()
	legacy.tactics.teams = tactics.teams.duplicate()
	legacy.version = PhysicalMatchReport.RECOVERY_VERSION
	legacy.resolver = PhysicalMatchReport.RECOVERY_RESOLVER
	legacy.tactics.version = 3
	for index in range(2):
		if not tactics.clubs[index] is bool:
			return false
		if tactics.clubs[index]:
			if not consistent_bag(tactics.teams[index]):
				return false
			legacy.tactics.teams[index] = recovery(tactics.teams[index], true)
	return PhysicalRecoveryEvidence.report_valid(legacy)


static func report_matches(data: Dictionary, state: MatchState) -> bool:
	if data.version != PhysicalMatchReport.BUDGET_VERSION:
		return false
	var teams: Array[TeamMatchState] = [state.away_team, state.home_team]
	var flags: Array = teams.map(func(team: TeamMatchState) -> bool:
		return not team.ai_budget.is_empty())
	if data.tactics.clubs != flags:
		return false
	for index in range(2):
		if flags[index] and not matches(data.tactics.teams[index], teams[index], teams[1 - index]):
			return false
	return true
