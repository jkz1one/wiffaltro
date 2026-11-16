extends "res://src/tests/live_match_test.gd"

const Fixtures = preload("res://src/tests/season_wholesale_test.gd")
var _season: SeasonState
var _played_state: MatchState


func _ready() -> void:
	var fixture: Node = Fixtures.new()
	_season = fixture._paid_wholesale("gear")
	_check(fixture._failures == 0 and _season != null, "actual paid Wholesale stock")
	if _season == null:
		fixture.free()
		get_tree().quit(1)
		return
	var request: Dictionary = fixture._generated_pair(_season.build, "gear")
	_check(_season.build.commit(request).ok, "buy both actual offered Gear before game")
	var receipts: Array[String] = SeasonReclamation.receipts(_season.build.view().wallet)
	_check(receipts.size() == 2, "two exact paid Gear receipts")
	var game: Dictionary = _season.pending_fixture()
	_check(game.home == 0, "paid club home fixture")
	await _run_match(67)
	_check(
		_played_state.gear_usage.first_pitch == receipts, "first release records paired receipts"
	)
	_check(
		_season.record_player_result(
			game.id,
			_played_state.away_team.runs,
			_played_state.home_team.runs,
			_played_state.performance.snapshot(_played_state),
			receipts
		),
		"whole physical game settles discounted Gear use"
	)
	_check(_season.build.view().used_gear.size() == 2, "completed game qualifies both exact copies")
	SeasonSave.path = "user://wholesale-live-%d.json" % OS.get_process_id()
	_check(SeasonSave.save(_season), "save completed paired Gear game")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == _season.build.view(),
		"paid provenance replays"
	)
	fixture.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro live wholesale checks passed: paired Gear, real game, use and reload.")
	get_tree().quit(0 if _failures == 0 else 1)


func _progression_fixture() -> MatchState:
	return _season.make_match()


func _equip_fixture(state: MatchState) -> void:
	_played_state = state
