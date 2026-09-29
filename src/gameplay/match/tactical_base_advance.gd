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
	var name_text: String = advance.runner
	for player: PlayerMatchState in state.batting_team().roster:
		if String(player.definition.id) == advance.runner:
			name_text = player.definition.display_name
	return (
		"%s: %dB → %s"
		% [name_text, advance.from, "HOME (+1 run)" if advance.to == 4 else "%dB" % advance.to]
	)


static func apply(state: MatchState) -> Dictionary:
	var advance: Dictionary = target(state.bases)
	if advance.is_empty():
		return {}
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
	var note: String = "Take a Base • " + describe(state, advance)
	state.last_event = (
		note + "\n" + state.last_event if state.phase == MatchState.Phase.GAME_END else note
	)
	return advance


static func valid(advance: Variant, roster: Array, performance: Dictionary) -> bool:
	if not advance is Dictionary or not SeasonOwnership._keys(advance, ["runner", "from", "to"]):
		return false
	if (
		not advance.runner is String
		or not roster.has(advance.runner)
		or not performance.has(advance.runner)
	):
		return false
	if not SeasonOwnership._whole(advance.from, 1, 3) or advance.to != advance.from + 1:
		return false
	return performance[advance.runner].h + performance[advance.runner].bb > 0
