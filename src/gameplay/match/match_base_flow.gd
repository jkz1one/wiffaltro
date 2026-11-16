class_name MatchBaseFlow
extends RefCounted
## Actual readiness, normal results, tags and consumable advances. No outcome or RNG changes.

var ready: Array[Dictionary] = []
var results: Array[Dictionary] = []
var tags: Array[Dictionary] = []
var advances: Array[Dictionary] = []


static func enabled(state: MatchState) -> bool:
	return state.away_team.track_bases or state.home_team.track_bases \
		or state.away_team.ai_base or state.home_team.ai_base


static func snapshot(state: MatchState) -> Dictionary:
	return {"pa": state.plate_appearance_number,
		"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
		"player": String(state.batter().definition.id),
		"pitcher": String(state.pitcher().definition.id), "outs": state.outs,
		"away": state.away_team.runs, "home": state.home_team.runs,
		"bases": [String(state.bases.first), String(state.bases.second), String(state.bases.third)]}


func prepare(state: MatchState) -> void:
	if not enabled(state) or state.phase != MatchState.Phase.PRE_PITCH or not state.between_batters:
		return
	if ready.is_empty() or ready[-1].pa != state.plate_appearance_number:
		ready.append(snapshot(state))


func complete(state: MatchState, outcome: String, rbi: int) -> void:
	if not enabled(state):
		return
	var row: Dictionary = snapshot(state)
	row["outcome"] = outcome
	row["rbi"] = rbi
	results.append(row)


func tag(
	state: MatchState, position: Vector3, rating: int, gather: float, travel: float, defender: String
) -> void:
	if not enabled(state):
		return
	tags.append({"pa": state.plate_appearance_number,
		"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
		"defender": defender, "position": [position.x, position.y, position.z],
		"rating": rating, "gather": gather, "travel": travel})


func advanced(state: MatchState, advance: Dictionary) -> void:
	if not enabled(state):
		return
	advances.append({"receipt": state.batting_team().tactics.consumed[-1].receipt,
		"advance": advance.duplicate(true), "after": snapshot(state)})


func evidence(state: MatchState) -> Dictionary:
	return {"version": 1, "ready": ready.duplicate(true), "results": results.duplicate(true),
		"tags": tags.duplicate(true), "advances": advances.duplicate(true), "final": snapshot(state)}
