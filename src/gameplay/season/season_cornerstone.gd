class_name SeasonCornerstone
extends RefCounted
## Working F01: explicit pre-PA choice, no future-contact information.


static func choose(state: MatchState, anchored: bool) -> bool:
	if (
		(anchored and state.jumpstart_mode != "normal")
		or not state.can_change_defense()
		or not state.fielder().definition.season_sponsors.get("F01", false)
	):
		return false
	state.cornerstone_anchored = anchored
	return true


static func active(state: MatchState) -> bool:
	return (
		state.cornerstone_anchored and state.fielder().definition.season_sponsors.get("F01", false)
	)


static func position_locked(state: MatchState) -> bool:
	return active(state) and not state.can_change_defense()


static func margin(state: MatchState, fielder: FielderController) -> float:
	return (
		0.12
		if (
			active(state)
			and fielder.stationary
			and fielder.reaction_ready()
			and fielder.last_reaction_margin_seconds >= 0.0
		)
		else 0.0
	)
