extends "res://src/tests/live_match_test.gd"

const Fixtures = preload("res://src/tests/season_reclamation_test.gd")
var _season: SeasonState
var _played_state: MatchState


func _ready() -> void:
	var fixture: Node = Fixtures.new()
	_season = fixture._reclamation_season()
	_check(fixture._failures == 0, "actual paid Gear and sponsor fixture")
	var game: Dictionary = _season.pending_fixture()
	_check(game.home == 0, "scripted player is home club")
	var ids: Array[String] = SeasonReclamation.receipts(_season.build.view().wallet)
	await _run_match(67)
	_check(
		_played_state.gear_usage.started and _played_state.gear_usage.first_pitch == ids,
		"real first release records exact equipped copies"
	)
	_check(
		_season.record_player_result(
			game.id,
			_played_state.away_team.runs,
			_played_state.home_team.runs,
			_played_state.performance.snapshot(_played_state),
			_played_state.gear_usage.first_pitch
		),
		"whole physical game settles actual use"
	)
	_check(
		_season.build.view().used_gear.size() == ids.size(),
		"all paid Gear qualifies after completion"
	)
	_check(
		_season.build.commit(fixture._command(_season.build, "open")).ok, "next actual shop opens"
	)
	_check(
		_season.build.commit(fixture._command(_season.build, "sell_gear", {"receipt": ids[0]})).ok,
		"sell physically used Gear"
	)
	_check(
		SeasonReclamation.credit(_season.build.view().shop) == 2,
		"actual completed game earns credit on sale"
	)
	SeasonSave.path = "user://reclamation-live-%d.json" % OS.get_process_id()
	_check(SeasonSave.save(_season) and SeasonSave.restore() != null, "live use and credit replay")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live Reclamation checks passed: paid copies, physical game, credit and restart."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _progression_fixture() -> MatchState:
	return _season.make_match()


func _equip_fixture(state: MatchState) -> void:
	_played_state = state


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	await super._check_outro_and_restart(lab)
	_check(
		(
			not lab._match_state.gear_usage.started
			and lab._match_state.gear_usage.first_pitch.is_empty()
		),
		"restart never inherits use evidence"
	)
