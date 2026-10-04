class_name PhysicalRecoveryEvidence
extends RefCounted
## Report5/proof3: the exact four-type paid bag and actual stamina chronology.
# gdlint: disable=max-returns


static func valid(row: Variant, roster: Array, performance: Dictionary, parity: int) -> bool:
	if not row is Dictionary:
		return false
	var keys: Array = ["version", "featured", "plan", "initial", "consumed", "remaining",
		"stances", "opposition", "pitching", "recovery"]
	if row.has("terminal"):
		keys.append("terminal")
	if not SeasonOwnership._keys(row, keys) or row.version != 3 or not row.recovery is Dictionary:
		return false
	var empty: Dictionary = row.duplicate(true)
	empty.erase("recovery")
	empty.erase("terminal")
	empty.version = 2
	empty.initial = []
	empty.consumed = []
	empty.remaining = []
	if not PhysicalHeatEvidence.valid(empty, roster, performance, parity) or not bag(row):
		return false
	var order: Array = row.stances + row.opposition.stances
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pa < b.pa)
	if row.has("terminal"):
		if not terminal(row, roster, performance, parity, order):
			return false
		order.append({"pa": row.terminal.pa, "half": row.terminal.half,
			"player": row.terminal.player})
	return flow_shape(row, roster, performance, parity) and PhysicalRecoveryFlow.valid(row, order)


static func bag(row: Dictionary) -> bool:
	if not row.initial is Array or row.initial.size() > 2 or not row.consumed is Array \
		or row.consumed.size() > row.initial.size() or not row.remaining is Array:
		return false
	var ids: Array[String] = []
	for copy: Variant in row.initial:
		if not copy is Dictionary or not SeasonOwnership._keys(copy, ["id", "item", "paid", "kind"]):
			return false
		if not copy.id is String or copy.id.is_empty() or ids.has(copy.id) \
			or copy.item not in SeasonOpponentTactics.supported(10) or copy.kind != "held" \
			or not SeasonOwnership._whole(copy.paid, SeasonTacticalCatalog.item(copy.item).price,
				SeasonTacticalCatalog.item(copy.item).price):
			return false
		ids.append(copy.id)
	for action: Variant in row.consumed:
		if not action is Dictionary or not SeasonOwnership._keys(
			action,
			["receipt", "player", "pa", "swing"]):
			return false
	return true


static func flow_shape(
	row: Dictionary, roster: Array, performance: Dictionary, parity: int
) -> bool:
	var flow: Dictionary = row.recovery
	if not SeasonOwnership._keys(flow, ["pitcher", "initial", "ready", "costs", "refunds",
		"refunders", "strikeouts", "remaining"]) or not flow.pitcher is String \
		or not roster.has(flow.pitcher) or not flow.initial is Dictionary \
		or not flow.remaining is Dictionary or not SeasonOwnership._keys(flow.initial, roster) \
		or not SeasonOwnership._keys(flow.remaining, roster) or not flow.refunders is Array \
		or not flow.ready is Array or not flow.costs is Array or not flow.refunds is Array \
		or not flow.strikeouts is Array or flow.refunds.size() > 2:
		return false
	for id: String in roster:
		var value: Variant = flow.initial[id]
		if not value is Dictionary or not SeasonOwnership._keys(value, ["capacity", "initial"]):
			return false
		if not PhysicalMatchReport.number(value.capacity, 0.001, 1000000.0) \
			or not PhysicalMatchReport.number(value.initial, 0.0, float(value.capacity)) \
			or not PhysicalMatchReport.number(flow.remaining[id], 0.0, float(value.capacity)):
			return false
	var seen: Array = []
	for id: Variant in flow.refunders:
		if not id is String or not roster.has(id) or seen.has(id):
			return false
		seen.append(id)
	if flow.costs.size() != row.pitching.size():
		return false
	var first: Dictionary = {}
	var last: Dictionary = {}
	for index in range(flow.costs.size()):
		var cost: Variant = flow.costs[index]
		if not cost is Dictionary or not SeasonOwnership._keys(cost,
			["pa", "half", "player", "recipe", "paid"]):
			return false
		for key: String in row.pitching[index]:
			if cost.get(key) != row.pitching[index][key]:
				return false
		if not PhysicalMatchReport.number(cost.paid, 0.0, 1000000.0):
			return false
		if not first.has(int(cost.pa)):
			first[int(cost.pa)] = cost.player
		last[int(cost.pa)] = cost.player
	var counts: Dictionary = {}
	var previous: int = 0
	for strikeout: Variant in flow.strikeouts:
		if not strikeout is Dictionary or not SeasonOwnership._keys(
			strikeout, ["pa", "half", "player"]):
			return false
		if not PhysicalMatchEvidence._row(strikeout, roster, 1 - parity) \
			or strikeout.pa <= previous or last.get(int(strikeout.pa)) != strikeout.player:
			return false
		previous = int(strikeout.pa)
		counts[strikeout.player] = counts.get(strikeout.player, 0) + 1
	for id: String in roster:
		if counts.get(id, 0) != performance[id].p_k:
			return false
	for ready: Variant in flow.ready:
		if not ready is Dictionary or not SeasonOwnership._keys(
			ready, ["pa", "half", "player", "remaining"]):
			return false
		if not PhysicalMatchEvidence._row(ready, roster, 1 - parity) \
			or not PhysicalMatchReport.number(ready.remaining, 0.0,
				float(flow.initial[ready.player].capacity)):
			return false
		if row.has("terminal") and ready.pa == row.terminal.pa:
			if ready.player != row.terminal.pitcher:
				return false
		elif first.get(int(ready.pa)) != ready.player:
			return false
	for refund: Variant in flow.refunds:
		if not refund is Dictionary or not SeasonOwnership._keys(refund, ["pa", "player", "amount"]):
			return false
		if not SeasonOwnership._whole(refund.pa, 1, 99999) or not refund.player is String \
			or not roster.has(refund.player) or not PhysicalMatchReport.number(refund.amount, 0.0, 6.0):
			return false
	return true


static func terminal(
	row: Dictionary, roster: Array, performance: Dictionary, parity: int, order: Array
) -> bool:
	var value: Variant = row.terminal
	if parity != 0 or not value is Dictionary or not SeasonOwnership._keys(
		value, ["pa", "half", "player", "pitcher", "base_receipt", "advance"]):
		return false
	var half: int = int(order[-1].half) if not order.is_empty() else 0
	return (SeasonOwnership._whole(value.pa, order.size() + 1, order.size() + 1)
		and SeasonOwnership._whole(value.half, maxi(5, half), half + 1)
		and int(value.half) % 2 == 1 and value.player == row.opposition.roster[
			row.opposition.stances.size() % 4] and value.pitcher is String
		and roster.has(value.pitcher) and value.base_receipt is String
		and not value.base_receipt.is_empty() and TacticalBaseAdvance.valid(
			value.advance, row.opposition.roster, performance)
		and value.advance.from == 3 and value.advance.to == 4)


static func matches(row: Dictionary, team: TeamMatchState, other: TeamMatchState) -> bool:
	if row.get("version") != 3 or team.ai_recovery_pitcher.is_empty():
		return false
	var fresh: TeamMatchState = PhysicalMatchRequest._team(team)
	if fresh == null:
		return false
	fresh.ai_recovery_pitcher = ""
	var base: Dictionary = row.duplicate(true)
	base.version = 2
	base.erase("recovery")
	if not PhysicalHeatEvidence.matches(base, fresh, other) \
		or row.recovery.pitcher != team.ai_recovery_pitcher:
		return false
	var refunders: Array[String] = []
	for player: PlayerMatchState in team.roster:
		var id: String = String(player.definition.id)
		var initial: Dictionary = row.recovery.initial[id]
		if not PhysicalRecoveryFlow.near(initial.capacity, player.stamina_max) \
			or not PhysicalRecoveryFlow.near(initial.initial, player.stamina_remaining):
			return false
		if player.definition.season_sponsors.get("B03", false):
			refunders.append(id)
	return ClubCareer.same(refunders, row.recovery.refunders)


static func report_valid(data: Dictionary) -> bool:
	var tactics: Variant = data.get("tactics")
	if not tactics is Dictionary or not SeasonOwnership._keys(tactics, ["version", "clubs", "teams"]):
		return false
	if tactics.version != 3 or not tactics.clubs is Array or tactics.clubs.size() != 2 \
		or not tactics.teams is Array or tactics.teams.size() != 2 \
		or not tactics.clubs[0] is bool or not tactics.clubs[1] is bool \
		or not (tactics.clubs[0] or tactics.clubs[1]):
		return false
	for index in range(2):
		var proof: Variant = tactics.teams[index]
		var team: Dictionary = data.teams[index]
		var other: Dictionary = data.teams[1 - index]
		if tactics.clubs[index]:
			if not valid(proof, team.roster, data.performance, index) or proof.has("terminal") \
				or not ClubCareer.same(proof.stances, team.stances) \
				or not ClubCareer.same(proof.pitching, team.pitching.releases) \
				or not ClubCareer.same(proof.opposition.roster, other.roster) \
				or not ClubCareer.same(proof.opposition.stances, other.stances) \
				or not ClubCareer.same(proof.recovery.strikeouts, team.pitching.strikeouts) \
				or not ClubCareer.same(proof.recovery.costs, data.releases.filter(
					func(release: Dictionary) -> bool: return team.roster.has(release.player))):
				return false
			for id: String in team.roster:
				if not ClubCareer.same(proof.recovery.initial[id], {
					"capacity": team.workload[id].capacity, "initial": team.workload[id].initial}) \
					or not PhysicalRecoveryFlow.near(proof.recovery.remaining[id],
						team.workload[id].remaining):
					return false
		elif not proof is Dictionary or not proof.is_empty():
			return false
	return true


static func report_matches(data: Dictionary, state: MatchState) -> bool:
	if data.version != PhysicalMatchReport.RECOVERY_VERSION:
		return false
	var teams: Array[TeamMatchState] = [state.away_team, state.home_team]
	var flags: Array = teams.map(func(team: TeamMatchState) -> bool:
		return not team.ai_recovery_pitcher.is_empty())
	if data.tactics.clubs != flags:
		return false
	for index in range(2):
		if flags[index] and not matches(data.tactics.teams[index], teams[index], teams[1 - index]):
			return false
	return true
