extends "res://src/tests/live_match_test.gd"

const Fixtures = preload("res://src/tests/season_school_test.gd")
var _season: SeasonState
var _played_state: MatchState


func _ready() -> void:
	var fixture: Node = Fixtures.new()
	_season = fixture._union_season()
	_check(fixture._failures == 0, "actual paid Union and Summer School fixture")
	var game: Dictionary = _season.pending_fixture()
	_check(game.home == 0, "paid club is home")
	var scholarship: Dictionary = SeasonSchoolSponsors.scholarship(_season.build)
	await _run_match(67)
	var stats: Dictionary = _played_state.performance.snapshot(_played_state)
	var hitters: int = 0
	for id: String in _season.build.roster():
		if stats.get(id, {}).get("h", 0) > 0:
			hitters += 1
	_check(hitters >= 3, "physical paid club earns three distinct credited hitters")
	_check(
		_season.record_player_result(
			game.id, _played_state.away_team.runs, _played_state.home_team.runs, stats
		),
		"completed physical game settles real contributor statistics"
	)
	_check(
		_season.build.view().shop.get("union_credit", 0) == 0,
		"pending reward is not usable before the next shop"
	)
	_check(
		_season.build.commit(fixture._command(_season.build, "open")).ok, "next actual shop opens"
	)
	_check(_season.build.view().shop.get("union_credit", 0) == 3, "physical contributors earn credit")
	_check(
		SeasonSchoolSponsors.scholarship(_season.build) == scholarship,
		"ordinary game participation cannot consume or retarget scholarships"
	)
	SeasonSave.path = "user://school-live-%d.json" % OS.get_process_id()
	_check(SeasonSave.save(_season), "physical contributor result saves")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == _season.build.view(),
		"physical result, credit and fixed student replay exactly"
	)
	print("SCHOOL_LIVE credited_hitters=", hitters, " union_credit=3")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live school checks passed: paid sponsors, actual hits, credit and restart."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _progression_fixture() -> MatchState:
	return _season.make_match()


func _equip_fixture(state: MatchState) -> void:
	_played_state = state


func _player_home_for_fixture() -> bool:
	# Synthetic control policy: AI bats for the genuinely paid home club; visitor
	# takes pitches. No fabricated hits or AI acquisition are introduced.
	return false
