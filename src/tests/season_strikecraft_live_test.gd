extends "res://src/tests/season_gameplay_sponsor_live_test.gd"
## Whole physical game with synthetic owning clubs; no AI purchases are implied.

var _played: MatchState


func _ready() -> void:
	await _run_match(67)
	var uses: int = 0
	var refunded: float = 0.0
	for team: TeamMatchState in [_played.home_team, _played.away_team]:
		uses += team.strikecraft_uses
		refunded += team.strikecraft_refunded
		_check(
			team.strikecraft_uses <= 2 and team.strikecraft_refunded <= 12.0,
			"physical game obeys team caps"
		)
	_check(uses > 0 and refunded > 0.0, "actual attributed strikeout sequence refunds stamina")
	print("STRIKECRAFT uses=", uses, " refunded=", refunded)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live Strikecraft checks passed: attributed physical sequence and whole game."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _equip_fixture(state: MatchState) -> void:
	super._equip_fixture(state)
	_played = state
	for team: TeamMatchState in [state.away_team, state.home_team]:
		for player: PlayerMatchState in team.roster:
			player.definition.season_sponsors.B03 = true


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	await super._check_outro_and_restart(lab)
	for team: TeamMatchState in [lab._match_state.away_team, lab._match_state.home_team]:
		_check(
			team.strikecraft_uses == 0 and team.strikecraft_refunded == 0.0,
			"restart resets per-game recovery counters"
		)
	_check(
		(
			lab
			. _match_state
			. pitch_ledger
			. first_costs(lab._match_state.pitcher().definition.id)
			. is_empty()
		),
		"restart does not retain prior PA costs"
	)
