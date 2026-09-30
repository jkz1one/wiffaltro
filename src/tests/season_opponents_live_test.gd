extends "res://src/tests/season_tactical_live_test.gd"

const OpponentFixtures = preload("res://src/tests/season_opponents_test.gd")
var _paid_frames: int = 0


func _ready() -> void:
	var fixture: Node = OpponentFixtures.new()
	_season = fixture._opponent_season(42, 3)
	fixture._audit(_season)
	_check(fixture._failures == 0, "genuine paid opponent fixture")
	fixture.free()
	SeasonSave.path = "user://opponent-live-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	app.season = _season
	var saved: bool = SeasonPregameCommit.save(app)
	_check(saved, "checkpoint completed AI buying before physical match")
	if not saved:
		app.free()
		get_tree().quit(1)
		return
	app.free()
	var game: Dictionary = _season.pending_fixture()
	var before: Dictionary = _season.build.view()
	_check(game.home == 0, "human club home")
	await _run_match(67)
	_check(_paid_frames > 0, "actual paid opponent uses shared live controllers")
	await _settlement_retry(game, before)
	_check(
		SeasonSave.restore().opponents.to_data() == _season.opponents.to_data(),
		"actual result settles and reloads all own wallets"
	)
	print("OPPONENT_LIVE paid_frames=", _paid_frames)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live paid opponent checks passed: actual developed club, game and durable settlement."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _player_home_for_fixture() -> bool:
	return true


func _observe_live_frame(lab: PitchBatLab) -> void:
	if lab._match_state.top_half:
		var definition: PlayerDefinition = lab._match_state.batter().definition
		var expected: PlayerDefinition = _season.player_definition(String(definition.id))
		_check(
			definition.contact == expected.contact and definition.power == expected.power,
			"live swing reads purchased opponent ratings"
		)
		_paid_frames += 1
