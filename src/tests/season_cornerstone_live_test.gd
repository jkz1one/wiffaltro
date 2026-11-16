extends "res://src/tests/live_match_test.gd"
## Genuinely paid club; deterministic test policy explicitly chooses each defensive PA.

const Fixtures = preload("res://src/tests/season_cornerstone_test.gd")
var _season: SeasonState
var _played_state: MatchState
var _choices: Dictionary = {}
var _fixed_frames: int = 0


func _ready() -> void:
	var fixture: Node = Fixtures.new()
	_season = fixture._paid_season()
	_check(fixture._failures == 0, "actual paid Cornerstone fixture")
	var game: Dictionary = _season.pending_fixture()
	_check(game.home == 0, "paid human club is home")
	await _run_match(67)
	_check(not _choices.is_empty() and _fixed_frames > 0, "whole game uses anchored fair contact")
	_check(
		_season.record_player_result(
			game.id,
			_played_state.away_team.runs,
			_played_state.home_team.runs,
			_played_state.performance.snapshot(_played_state)
		),
		"actual complete anchored game settles"
	)
	SeasonSave.path = "user://cornerstone-live-%d.json" % OS.get_process_id()
	_check(SeasonSave.save(_season), "paid result saves")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == _season.build.view(),
		"paid ownership and actual result replay"
	)
	print("CORNERSTONE_LIVE choices=", _choices.size(), " fixed_frames=", _fixed_frames)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live Cornerstone checks passed: paid club, fixed defense, result and restart."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _progression_fixture() -> MatchState:
	return _season.make_match()


func _equip_fixture(state: MatchState) -> void:
	_played_state = state


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	if state.can_change_defense() and state.fielder().definition.season_sponsors.get("F01", false):
		if not _choices.has(state.plate_appearance_number):
			_check(SeasonCornerstone.choose(state, true), "explicit pre-PA test choice")
			_choices[state.plate_appearance_number] = true
	var fielder: FielderController = lab._primary_fielder
	if fielder.active and fielder.stationary:
		_fixed_frames += 1
		_check(
			fielder.global_position == fielder.anchor_position and fielder.velocity == Vector3.ZERO,
			"every live anchored frame preserves exact position"
		)


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	await super._check_outro_and_restart(lab)
	_check(
		not lab._match_state.cornerstone_anchored and not lab._primary_fielder.stationary,
		"fresh match has no prior commitment or controller lock"
	)
