class_name TacticalBaseContext
extends RefCounted
## Extra-inning automatic runners are real baserunners, not credited player hits or walks.


static func capture(state: MatchState) -> Dictionary:
	return {"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
		"bases": [String(state.bases.first), String(state.bases.second), String(state.bases.third)]}


static func valid(advance: Dictionary, roster: Array, performance: Dictionary) -> bool:
	if not SeasonOwnership._whole(advance.from, 2, 3) or roster.size() != 4 or performance.size() != 8:
		return false
	var context: Variant = advance.get("context")
	if not context is Dictionary or not SeasonOwnership._keys(context, ["half", "bases"]):
		return false
	if not SeasonOwnership._whole(context.half, MatchState.REGULATION_INNINGS * 2, 19997) \
		or not context.bases is Array or context.bases.size() != 3:
		return false
	var inning: int = int(int(context.half) / 2) + 1
	var expected: String = "extra_runner.%s.%d" % [
		"away" if int(context.half) % 2 == 0 else "home", inning]
	if advance.runner != expected:
		return false
	var seen: Array = []
	for runner: Variant in context.bases:
		if not runner is String:
			return false
		if runner.is_empty():
			continue
		if seen.has(runner) or (runner != expected and not roster.has(runner)):
			return false
		seen.append(runner)
	var bases: BaseState = BaseState.new()
	bases.first = StringName(context.bases[0])
	bases.second = StringName(context.bases[1])
	bases.third = StringName(context.bases[2])
	if not ClubCareer.same(TacticalBaseAdvance.target(bases), {
		"runner": advance.runner, "from": advance.from, "to": advance.to}):
		return false
	var own_outs: int = 0
	var other_outs: int = 0
	for id: String in performance:
		if not performance[id] is Dictionary \
			or not SeasonOwnership._whole(performance[id].get("outs"), 0, 99999):
			return false
		if roster.has(id):
			own_outs += int(performance[id].outs)
		else:
			other_outs += int(performance[id].outs)
	return mini(own_outs, other_outs) >= (inning - 1) * MatchState.OUTS_PER_HALF
