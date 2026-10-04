class_name PhysicalRecoveryFlow
extends RefCounted
## Reconcile actual readiness, paid releases, bounded recovery and earned Strikecraft credits.
# gdlint: disable=max-returns


static func valid(row: Dictionary, order: Array) -> bool:
	var flow: Dictionary = row.recovery
	var current: Dictionary = {}
	for id: String in flow.initial:
		current[id] = float(flow.initial[id].initial)
	var held: Array = row.initial.duplicate(true)
	var consumed: Array = []
	var recovered: Array[String] = []
	var refunds: Array = []
	var cursor: int = 0
	for stance: Dictionary in order:
		if row.opposition.roster.has(stance.player):
			if cursor >= flow.ready.size():
				return false
			var ready: Dictionary = flow.ready[cursor]
			cursor += 1
			if ready.pa != stance.pa or ready.half != stance.half \
				or not near(ready.remaining, current[ready.player]):
				return false
			var pitcher: String = ready.player
			var capacity: float = float(flow.initial[pitcher].capacity)
			var action: Dictionary = {}
			if pitcher == flow.pitcher and not recovered.has(pitcher) \
				and SeasonOpponentRecovery.eligible(capacity, float(ready.remaining)):
				action = select(held, "C02")
			if action.is_empty() and stance.player == row.opposition.target:
				action = select(held, SeasonTacticalCatalog.HEAT)
			if not action.is_empty():
				consumed.append({"receipt": action.id, "player": pitcher,
					"pa": stance.pa, "swing": ""})
				remove(held, action.id)
				if action.item == "C02":
					current[pitcher] = minf(capacity, float(current[pitcher]) + capacity * 0.10)
					recovered.append(pitcher)
			if not charge(flow, int(stance.pa), current, refunds):
				return false
		else:
			var action: Dictionary = SeasonOpponentTactics.select(
				held, stance.player, row.featured, row.plan)
			if not action.is_empty():
				consumed.append({"receipt": action.receipt, "player": stance.player,
					"pa": stance.pa, "swing": action.swing})
				remove(held, action.receipt)
	if cursor != flow.ready.size() or not ClubCareer.same(consumed, row.consumed) \
		or not ClubCareer.same(held, row.remaining) or refunds.size() != flow.refunds.size():
		return false
	for index in range(refunds.size()):
		var actual: Dictionary = flow.refunds[index]
		if actual.pa != refunds[index].pa or actual.player != refunds[index].player \
			or not near(actual.amount, refunds[index].amount):
			return false
	for id: String in current:
		if not near(current[id], flow.remaining[id]):
			return false
	return true


static func charge(flow: Dictionary, pa: int, current: Dictionary, refunds: Array) -> bool:
	var first: Dictionary = {}
	var final_pitcher: String = ""
	for release: Dictionary in flow.costs:
		if release.pa != pa:
			continue
		final_pitcher = release.player
		if float(release.paid) > float(current[release.player]) + 0.000001:
			return false
		current[release.player] = maxf(0.0, float(current[release.player]) - float(release.paid))
		if not first.has(release.player):
			first[release.player] = {}
		if first[release.player].size() < 3 and not first[release.player].has(release.recipe):
			first[release.player][release.recipe] = float(release.paid)
	if final_pitcher.is_empty() or not flow.refunders.has(final_pitcher) or refunds.size() >= 2 \
		or first[final_pitcher].size() != 3 or not flow.strikeouts.any(
			func(strikeout: Dictionary) -> bool: return strikeout.pa == pa):
		return true
	var amount: float = 0.0
	for paid: float in first[final_pitcher].values():
		amount += paid
	amount = minf(6.0, amount * 0.25)
	var before: float = current[final_pitcher]
	current[final_pitcher] = minf(float(flow.initial[final_pitcher].capacity), before + amount)
	refunds.append({"pa": pa, "player": final_pitcher,
		"amount": float(current[final_pitcher]) - before})
	return true


static func select(held: Array, item: String) -> Dictionary:
	for copy: Dictionary in held:
		if copy.item == item:
			return copy
	return {}


static func remove(held: Array, receipt: String) -> void:
	for index in range(held.size()):
		if held[index].id == receipt:
			held.remove_at(index)
			return


static func near(a: Variant, b: Variant) -> bool:
	return absf(float(a) - float(b)) <= 0.000001
