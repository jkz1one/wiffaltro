class_name MatchBattingSides
extends RefCounted
## Committed actual stances, independent of sponsor ownership and throwing hands.

var rows: Array[Dictionary] = []
var _locked: Dictionary = {}
var _previous: Dictionary = {}


func lock(state: MatchState) -> void:
	if _locked.get("pa") == state.plate_appearance_number:
		return
	_locked = {
		"pa": state.plate_appearance_number,
		"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
		"player": String(state.batter().definition.id),
		"left": state.batter().bats_left()
	}


func cancel(state: MatchState) -> void:
	if state.between_batters:
		_locked.clear()


func complete(state: MatchState) -> void:
	if not rows.is_empty() and rows[-1].pa == state.plate_appearance_number:
		return
	lock(state)
	rows.append(_locked.duplicate())
	_previous = _locked.duplicate()


func qualifies(state: MatchState) -> bool:
	var half: int = (state.inning - 1) * 2 + (0 if state.top_half else 1)
	if _previous.is_empty() or _previous.half != half:
		return false
	var left: bool = state.batter().bats_left()
	if _locked.get("pa") == state.plate_appearance_number:
		left = _locked.left
	return left != _previous.left


func active(state: MatchState) -> bool:
	return state.batter().definition.season_sponsors.get("F06", false) and qualifies(state)


func evidence(team: TeamMatchState) -> Array:
	var ids: Array = team.roster.map(
		func(player: PlayerMatchState) -> String: return String(player.definition.id)
	)
	return rows.filter(func(row: Dictionary) -> bool: return ids.has(row.player)).duplicate(true)


func label(state: MatchState) -> String:
	return (
		"Alternating • Contact +4% / Power −4% speed"
		if qualifies(state)
		else "Same side or first batter • no speed modifier"
	)


func swing(profile: SwingProfileDefinition, state: MatchState) -> void:
	if not active(state):
		return
	var misc: Dictionary = SeasonGearCatalog.item(
		state.batter().definition.season_gear.get("misc", "")
	)
	var amount: float = 0.04 if profile.id == &"swing.contact" else -0.04
	profile.gear_fair_exit_scale += amount * float(misc.get("exit", 1.0))
