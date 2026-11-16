extends Node
## Synthetic unit fixtures only. No actual user achievement or saved progress is earned.

var _failures: Array[String] = []


func _ready() -> void:
	var game: Dictionary = _fixture()
	var compact: Dictionary = WorkingExoticEligibility._capture_game(game)
	_check(not compact.is_empty(), "prospective complete fixture captures")
	var game_wire: Variant = JSON.parse_string(JSON.stringify(game))
	var cold: Dictionary = WorkingExoticEligibility._capture_game(game_wire)
	_check(not cold.is_empty() and cold.evidence_hash == compact.evidence_hash,
		"actual JSON numeric normalization preserves cold proof hash")
	var evidence: Dictionary = _evidence(compact)
	var wire: Variant = JSON.parse_string(JSON.stringify(evidence))
	_check(WorkingExoticEligibility.valid(wire), "actual JSON float-number roundtrip accepted")
	_check(WorkingExoticEligibility.eligible_ids(wire).size() == 3,
		"exact documented conditions unlock three unique named designs")
	for bad: Variant in [true, false, null, "1", 1.5, 2]:
		var changed: Dictionary = wire.duplicate(true)
		changed.version = bad
		_check(not WorkingExoticEligibility.valid(changed), "invalid numeric version rejected")
	var historical: Dictionary = game.duplicate(true)
	historical.erase("pitching_current")
	var historic_evidence: Dictionary = _evidence(WorkingExoticEligibility._capture_game(historical))
	var historic_ids: Array[String] = WorkingExoticEligibility.eligible_ids(historic_evidence)
	_check(historic_ids.size() == 2 and not historic_ids.has("pitch.trapdoor"),
		"generic old K evidence never implies called third strikes")
	var changed: Dictionary = game.duplicate(true)
	changed.pitching_current.called_strikeouts.append({"pa": 90, "half": 1,
		"player": game.club_roster[0]})
	_check(WorkingExoticEligibility._capture_game(changed).is_empty(), "uncredited called K rejected")
	changed = game.duplicate(true)
	changed.pitching.releases[0].player = game.club_roster[1]
	changed.pitching_current.pitching = changed.pitching.duplicate(true)
	var split: Dictionary = _evidence(WorkingExoticEligibility._capture_game(changed))
	_check(not WorkingExoticEligibility.eligible_ids(split).has("pitch.switchback"),
		"one pitcher's earlier movement cannot credit another pitcher's K")
	changed = game.duplicate(true)
	changed.performance[game.club_roster[0]].p_k += 1
	_check(WorkingExoticEligibility._capture_game(changed).is_empty(), "totals must match credited Ks")
	_check(WorkingExoticEligibility.capture(SeasonState.new()).is_empty(),
		"uncommitted report-only data never grants capture")
	_test_prospective_recorder()
	if _failures.is_empty():
		print("Working Exotic eligibility unit checks passed; all game evidence here is synthetic.")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_prospective_recorder() -> void:
	var state: MatchState = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, "Synthetic home", "Synthetic away")
	var team: TeamMatchState = state.defensive_team()
	_check(state.sure_shot.evidence_current(team).is_empty(), "old context has no current proof")
	_check(state.sure_shot.enable_current_evidence(), "explicit pre-release admission")
	state.strikes = 2
	state.record_strike(false)
	var current: Dictionary = state.sure_shot.evidence_current(team)
	_check(current.version == 2 and current.called_strikeouts.size() == 1,
		"actual record_strike(false) is the called-K source")
	_check(SeasonOwnership._keys(state.sure_shot.evidence(team), ["releases", "calls", "strikeouts"]),
		"historical proof shape stays exact")
	var called_wire: Variant = JSON.parse_string(JSON.stringify(current))
	_check(WorkingExoticEligibility.current_proof_valid(called_wire, called_wire.pitching),
		"version2 current proof roundtrips JSON")
	state.strikes = 2
	state.record_strike(true)
	_check(state.sure_shot.evidence_current(team).called_strikeouts.size() == 1,
		"swinging K cannot become called evidence")
	var late: MatchState = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, "Synthetic home", "Synthetic away")
	late.sure_shot.strikeout(late)
	_check(not late.sure_shot.enable_current_evidence(), "no retroactive opt-in after a K")


static func _fixture() -> Dictionary:
	var roster: Array[String] = SeasonPlayerCatalog.ids().slice(0, 4)
	var releases: Array = []
	var strikeouts: Array = []
	var called: Array = []
	var performance: Dictionary = {}
	for id: String in roster:
		performance[id] = {"p_k": 0}
	var sequences: Array = [
		["pitch.overhand_sinker", "pitch.overhand_slider"], ["pitch.overhand_four_seam"],
		["pitch.sidearm_sinker"], ["pitch.drop"], ["pitch.drop"], ["pitch.three_quarter_drop"]]
	for index: int in range(sequences.size()):
		var player: String = roster[0] if index < 3 else roster[1]
		var row: Dictionary = {"pa": index + 1, "half": 1, "player": player}
		for recipe: String in sequences[index]:
			var release: Dictionary = row.duplicate()
			release["recipe"] = recipe
			releases.append(release)
		strikeouts.append(row)
		performance[player].p_k += 1
		if index >= 3:
			called.append(row.duplicate())
	var pitching: Dictionary = {"releases": releases, "calls": [], "strikeouts": strikeouts}
	return {"id": 0, "club_roster": roster, "performance": performance, "pitching": pitching,
		"pitching_current": {"version": 2, "pitching": pitching.duplicate(true),
			"called_strikeouts": called}}


static func _evidence(game: Dictionary) -> Dictionary:
	return {"version": 1, "catalog": WorkingPitchCatalog.signature(),
		"season": "synthetic-unit-fixture", "games": [game]}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
