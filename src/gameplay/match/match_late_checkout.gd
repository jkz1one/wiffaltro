class_name MatchLateCheckout
extends RefCounted
## A next-batter effect offer, never a held copy or additional consumption.

var used: bool = false
var inherited_pa: int = 0
var inherited_receipt: String = ""
var _receipts: Dictionary = {}
var _pending: Array[String] = []
var _swing: StringName = &""
var _pa: int = 0
var _inning: int = 0
var _top: bool = true


func clear() -> void:
	_pending.clear()
	_receipts.clear()


func walk(state: MatchState, team: TeamMatchState) -> void:
	clear()
	var tactics: MatchTactics = team.tactics
	var effect: String = tactics.active(state)
	if effect not in ["A10", "C03", MatchTactics.COMBO]:
		return
	# Only original consumption is evidence; inherited effects cannot chain or earn uses.
	var original: bool = false
	for action: Dictionary in tactics.consumed:
		if action.pa == state.plate_appearance_number:
			original = true
			_receipts["C03" if action.swing != "" else "A10"] = action.receipt
			if tactics.track_walks:
				action["walked"] = true
	if (
		not original
		or used
		or not team.current_batter().definition.season_sponsors.get("G03", false)
	):
		return
	_pending.assign(["A10", "C03"] if effect == MatchTactics.COMBO else [effect])
	_swing = tactics.locked_swing(state)
	_pa = state.plate_appearance_number + 1
	_inning = state.inning
	_top = state.top_half


func options(state: MatchState, team: TeamMatchState) -> Array[String]:
	if (
		used
		or team != state.batting_team()
		or team.tactics.checkout != self
		or state.phase != MatchState.Phase.PRE_PITCH
		or not state.between_batters
		or state.plate_appearance_number != _pa
		or state.inning != _inning
		or state.top_half != _top
		or team.tactics._used_pa == _pa
		or not team.current_batter().definition.season_sponsors.get("G03", false)
	):
		return []
	return _pending.duplicate()


func accept(state: MatchState, team: TeamMatchState, item: String) -> bool:
	if not options(state, team).has(item):
		return false
	var tactics: MatchTactics = team.tactics
	tactics._active = item
	tactics._active_pa = _pa
	tactics._used_pa = _pa
	tactics._swing = _swing if item == "C03" else &""
	inherited_pa = _pa
	inherited_receipt = _receipts[item]
	used = true
	clear()
	return true


func decline(state: MatchState, team: TeamMatchState) -> bool:
	if options(state, team).is_empty():
		return false
	clear()
	return true
