class_name MatchSureShot
extends RefCounted
## Public pre-PA identity commitment; release evidence never includes hidden pitch state.

var releases: Array = []
var calls: Array = []
var strikeouts: Array = []
var _last_release: Dictionary = {}


func current(state: MatchState) -> Dictionary:
	for row: Dictionary in calls:
		if row.pa == state.plate_appearance_number:
			return row.duplicate(true)
	return {}


func remaining(team: TeamMatchState) -> int:
	var ids: Array = team.roster.map(
		func(player: PlayerMatchState) -> String: return String(player.definition.id)
	)
	return 2 - calls.filter(func(row: Dictionary) -> bool: return ids.has(row.player)).size()


func choose(state: MatchState, recipe: StringName) -> bool:
	if (
		state.phase != MatchState.Phase.PRE_PITCH
		or not state.between_batters
		or not current(state).is_empty()
		or remaining(state.defensive_team()) <= 0
		or not state.pitcher().definition.season_sponsors.get("F08", false)
		or not state.pitcher().definition.starting_pitches.any(
			func(pitch: PitchDefinition) -> bool: return pitch.id == recipe
		)
	):
		return false
	var row: Dictionary = _row(state)
	row["recipe"] = String(recipe)
	row["time"] = state.elapsed_seconds
	calls.append(row)
	state.defensive_team().sure_shot_locked = true
	state.pitch_disclosure = cue(state)
	return true


func allows(state: MatchState, recipe: StringName) -> bool:
	var call: Dictionary = current(state)
	return call.is_empty() or call.recipe == String(recipe)


func cue(state: MatchState) -> Dictionary:
	var call: Dictionary = current(state)
	if call.is_empty():
		return {}
	return {"source": "F08", "recipe": call.recipe, "time": call.time}


func release(state: MatchState, recipe: StringName) -> void:
	var player: PlayerMatchState = state.pitcher()
	var id: String = String(player.definition.id)
	if recipe.is_empty() or player.pitch_count <= _last_release.get(id, 0):
		return
	_last_release[id] = player.pitch_count
	var row: Dictionary = _row(state)
	row["recipe"] = String(recipe)
	releases.append(row)


func strikeout(state: MatchState) -> void:
	strikeouts.append(_row(state))


func evidence(team: TeamMatchState) -> Dictionary:
	var ids: Array = []
	for player: PlayerMatchState in team.roster:
		ids.append(String(player.definition.id))
	var result: Dictionary = {}
	for key: String in ["releases", "calls", "strikeouts"]:
		result[key] = (
			get(key)
			. filter(func(row: Dictionary) -> bool: return ids.has(row.player))
			. duplicate(true)
		)
	return result


func _row(state: MatchState) -> Dictionary:
	return {
		"pa": state.plate_appearance_number,
		"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
		"player": String(state.pitcher().definition.id)
	}
