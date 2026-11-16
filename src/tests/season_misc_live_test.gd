extends "res://src/tests/live_match_test.gd"
## Whole-game integration: first-batter workload and widened AI swing windows.

var _equipped_state: MatchState


func _ready() -> void:
	await _run_match(67)
	var participants: int = 0
	for player: PlayerMatchState in _equipped_state.home_team.roster:
		if player.pitch_count > 0:
			participants += 1
			_check(player.first_batter_completed, "live Kit pitcher completes their first batter")
	_check(participants > 0, "full-game fixture uses Kit pitchers")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro live Misc checks passed: complete Kit/Gloves game, outro and restart.")
	get_tree().quit(0 if _failures == 0 else 1)


func _equip_fixture(state: MatchState) -> void:
	_equipped_state = state
	for team: TeamMatchState in [state.home_team, state.away_team]:
		for player: PlayerMatchState in team.roster:
			player.definition = SeasonGearCatalog.equip(
				player.definition,
				{
					"bat": {"item": "BAT-CON-01" if team == state.home_team else "BAT-POW-01"},
					"ball": {"item": "BALL-HYB-01"},
					"misc": {"item": "D02" if team == state.home_team else "MISC-BAT-01"}
				}
			)
