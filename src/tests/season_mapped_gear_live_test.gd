extends "res://src/tests/live_match_test.gd"
## Complete match through both physical Shoe variants and Alley-equipped AI contact.


func _ready() -> void:
	await _run_match(67)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro live mapped Gear checks passed: complete Shoes/Alley game and restart.")
	get_tree().quit(0 if _failures == 0 else 1)


func _equip_fixture(state: MatchState) -> void:
	for team: TeamMatchState in [state.home_team, state.away_team]:
		for player: PlayerMatchState in team.roster:
			player.definition = SeasonGearCatalog.equip(
				player.definition,
				{
					"bat": {"item": "A02"},
					"ball": {"item": "BALL-HYB-01"},
					"misc": {"item": "MISC-FLD-01" if team == state.home_team else "MISC-FLD-02"}
				}
			)
