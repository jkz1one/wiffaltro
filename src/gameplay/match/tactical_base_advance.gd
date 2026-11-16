class_name TacticalBaseAdvance
extends RefCounted
## A consumable advance, never a batting result, steal or tag-up.


static func target(bases: BaseState) -> Dictionary:
	var occupied: Array[StringName] = [bases.first, bases.second, bases.third, &""]
	for index in range(3):
		if occupied[index] == &"":
			continue
		if occupied[index + 1] != &"":
			return {}
		return {"runner": String(occupied[index]), "from": index + 1, "to": index + 2}
	return {}


static func describe(state: MatchState, advance: Dictionary) -> String:
	if advance.is_empty():
		return "The lowest runner needs a free next base; empty bases cannot use this card."
	var name_text: String = "Automatic runner" if advance.runner.begins_with("extra_runner.") \
		else advance.runner
	for player: PlayerMatchState in state.batting_team().roster:
		if String(player.definition.id) == advance.runner:
			name_text = player.definition.display_name
	return (
		"%s: %dB → %s"
		% [name_text, advance.from, "HOME (+1 run)" if advance.to == 4 else "%dB" % advance.to]
	)


static func apply(state: MatchState) -> Dictionary:
	state.base_flow.prepare(state)
	var advance: Dictionary = target(state.bases)
	if advance.is_empty():
		return {}
	if advance.runner.begins_with("extra_runner."):
		advance["context"] = TacticalBaseContext.capture(state)
	match int(advance.from):
		1:
			state.bases.second = state.bases.first
			state.bases.first = &""
		2:
			state.bases.third = state.bases.second
			state.bases.second = &""
		3:
			state.bases.third = &""
			state._add_runs(1)
	state.base_flow.advanced(state, advance)
	var note: String = "Take a Base • " + describe(state, advance)
	state.last_event = (
		note + "\n" + state.last_event if state.phase == MatchState.Phase.GAME_END else note
	)
	return advance


static func valid(advance: Variant, roster: Array, performance: Dictionary) -> bool:
	if not advance is Dictionary or not advance.get("runner") is String:
		return false
	var ghost: bool = advance.runner.begins_with("extra_runner.")
	var keys: Array = ["runner", "from", "to"]
	if ghost:
		keys.append("context")
	if not SeasonOwnership._keys(advance, keys) \
		or not SeasonOwnership._whole(advance.from, 1, 3) or advance.to != advance.from + 1:
		return false
	if ghost:
		return TacticalBaseContext.valid(advance, roster, performance)
	return roster.has(advance.runner) and performance.has(advance.runner) \
		and performance[advance.runner].h + performance[advance.runner].bb > 0
