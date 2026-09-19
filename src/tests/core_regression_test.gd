extends Node

var _failures: int = 0

func _ready() -> void:
	_test_pitch_release_quality()
	_test_ai_pitch_determinism_and_counts()
	_test_match_count_rules()
	_test_play_record_serialization()
	if _failures == 0:
		print("Wiffaltro core regression checks passed.")
		get_tree().quit(0)
	else:
		push_error("Wiffaltro core regression failures: %d" % _failures)
		get_tree().quit(1)

func _test_pitch_release_quality() -> void:
	var perfect: float = PitchReleaseController.quality_at(0.72, 5, 0.0)
	var early: float = PitchReleaseController.quality_at(0.42, 5, 0.0)
	var tired_low_control: float = PitchReleaseController.quality_at(
		0.84,
		2,
		1.0
	)
	var fresh_high_control: float = PitchReleaseController.quality_at(
		0.84,
		9,
		0.0
	)
	_check(perfect > 0.99, "ideal release should grade perfect")
	_check(early < perfect, "early release should lose quality")
	_check(
		fresh_high_control > tired_low_control,
		"Control and freshness should widen the release window"
	)

func _test_ai_pitch_determinism_and_counts() -> void:
	var first: Dictionary = MatchLabSupport.ai_pitch_choice(4, 12, 3, 2, 1, 0)
	var replay: Dictionary = MatchLabSupport.ai_pitch_choice(4, 12, 3, 2, 1, 0)
	_check(first == replay, "AI choice should replay from the same state")
	var three_ball_strikes: int = 0
	var two_strike_strikes: int = 0
	for index in range(200):
		var protect: Dictionary = MatchLabSupport.ai_pitch_choice(
			4, index, 2, 3, 1, -1
		)
		var chase: Dictionary = MatchLabSupport.ai_pitch_choice(
			4, index, 2, 0, 2, -1
		)
		if _target_in_zone(protect["target"]):
			three_ball_strikes += 1
		if _target_in_zone(chase["target"]):
			two_strike_strikes += 1
	_check(
		three_ball_strikes > two_strike_strikes,
		"AI should attack the zone more often in three-ball counts"
	)

func _test_match_count_rules() -> void:
	var match_state: MatchState = MatchState.create(
		_make_team("Away"),
		_make_team("Home")
	)
	match_state.strikes = 2
	match_state.record_foul()
	_check(match_state.strikes == 2, "two-strike foul should preserve the count")
	match_state.continue_after_dead_ball()
	match_state.balls = 3
	match_state.record_ball()
	_check(
		match_state.away_team.batting_index == 1,
		"walk should complete the plate appearance"
	)
	_check(match_state.bases.first != &"", "walk should place the batter on first")

func _test_play_record_serialization() -> void:
	var record: PlayRecord = PlayRecord.new()
	record.play_number = 7
	record.pitch_id = &"pitch.test"
	record.intended_target = Vector2(0.2, 1.1)
	record.result = &"single"
	var encoded: Dictionary = record.to_dict()
	_check(encoded["play_number"] == 7, "record should retain play number")
	_check(
		is_equal_approx(float(encoded["intended_target"][0]), 0.2)
		and is_equal_approx(float(encoded["intended_target"][1]), 1.1),
		"record vectors should be JSON-safe arrays"
	)

func _make_team(team_name: String) -> TeamMatchState:
	var definitions: Array[PlayerDefinition] = []
	for index in range(TeamMatchState.ROSTER_SIZE):
		var definition: PlayerDefinition = PlayerDefinition.new()
		definition.id = StringName("player.test_%s_%d" % [team_name, index])
		definition.display_name = "%s %d" % [team_name, index]
		definitions.append(definition)
	return TeamMatchState.create(team_name, definitions)

func _target_in_zone(target: Vector2) -> bool:
	return (
		target.x >= -0.43
		and target.x <= 0.43
		and target.y >= 0.55
		and target.y <= 1.55
	)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
