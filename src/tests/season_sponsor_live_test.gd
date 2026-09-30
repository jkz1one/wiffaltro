extends "res://src/tests/live_match_test.gd"
## A whole physical match settles its actual statistics into a genuinely paid sponsor season.

const SponsorFixtures = preload("res://src/tests/season_sponsor_test.gd")
var _season: SeasonState
var _played_state: MatchState


func _ready() -> void:
	var fixture: Node = SponsorFixtures.new()
	_season = fixture._paid_income()
	_check(fixture._failures == 0 and _season != null, "valid genuinely paid season fixture")
	fixture.free()
	if _season == null:
		get_tree().quit(1)
		return
	var game: Dictionary = _season.pending_fixture()
	_check(game.home == 0, "live scripted player owns home sponsor club")
	var before: int = _season.cash()
	await _run_match(67)
	var stats: Dictionary = _played_state.performance.snapshot(_played_state)
	var own: Array = _season.teams[0].roster
	var walks: int = 0
	var arms: int = 0
	var extra_types: Dictionary = {}
	for id: String in own:
		walks += int(stats[id].bb)
		arms += 1 if stats[id].p_k > 0 else 0
		for type: String in ["double", "triple", "hr"]:
			if stats[id][type] > 0:
				extra_types[type] = true
	var earned: int = mini(2, walks) * 2 + mini(4, arms) * 2 + extra_types.size() * 3
	_check(
		_season.record_player_result(
			game.id, _played_state.away_team.runs, _played_state.home_team.runs, stats
		),
		"real completed-game evidence settles"
	)
	var base: int = 18 if _played_state.home_team.runs > _played_state.away_team.runs else 12
	_check(_season.cash() == before + base + earned, "real cash matches attributed live events")
	_check(
		not _season.record_player_result(
			game.id, _played_state.away_team.runs, _played_state.home_team.runs, stats
		),
		"actual result cannot pay again"
	)
	var path: String = "user://sponsor-live-%d.json" % OS.get_process_id()
	SeasonSave.path = path
	_check(SeasonSave.save(_season), "checkpoint actual sponsor result")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.cash() == _season.cash(),
		"actual result and income survive replay"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live sponsor checks passed: actual game, income, reload, outro and restart."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _progression_fixture() -> MatchState:
	return _season.make_match()


func _equip_fixture(state: MatchState) -> void:
	_played_state = state
