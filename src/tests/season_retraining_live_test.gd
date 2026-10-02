extends "res://src/tests/season_tactical_live_test.gd"

const RetrainingFixtures = preload("res://src/tests/season_retraining_test.gd")
var _transformed: String = ""
var _seen: int = 0


func _ready() -> void:
	SeasonSave.path = "user://retraining-live-%d.json" % OS.get_process_id()
	var fixture: Node = RetrainingFixtures.new()
	_season = fixture._paid_retraining()
	_check(_season != null and fixture._failures == 0, "genuinely paid training and stock")
	var command: Dictionary = fixture._purchase(_season.build)
	_transformed = command.player
	_check(_season.build.commit(command).ok, "pay for actual transformation")
	# Use the next scheduled home fixture so the inherited settlement driver owns the home club.
	while _season.pending_fixture().home != 0:
		fixture._record(_season)
	_check(SeasonSave.save(_season), "save before physical game")
	fixture.free()
	var before: Dictionary = _season.build.view()
	var game: Dictionary = _season.pending_fixture()
	var points: Dictionary = SeasonRetraining.points(_season.build._book, _transformed)
	await _run_match(67)
	_check(_seen > 0, "transformed player participates in real live controllers")
	await _settlement_retry(game, before)
	_check(
		SeasonRetraining.points(SeasonSave.restore().build._book, _transformed) == points,
		"physical result and career rebuild retain exact transformed provenance"
	)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live retraining checks passed: paid ratings, physical game and settlement."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	if String(state.batter().definition.id) == _transformed:
		var expected: PlayerDefinition = _season.build.definition(_transformed)
		_check(
			SeasonPlayerCard.values(state.batter().definition) == SeasonPlayerCard.values(expected),
			"physical batter uses all four transformed ratings"
		)
		_seen += 1
