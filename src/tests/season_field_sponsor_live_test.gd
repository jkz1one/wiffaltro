extends "res://src/tests/live_match_test.gd"
## Synthetic paid-build equivalents, not a claim of opponent purchasing policy.

var _choices: Dictionary = {}
var _contact_swings: Dictionary = {}


func _ready() -> void:
	await _run_match(67)
	_check(not _choices.is_empty(), "whole game exercises pre-PA modes")
	_check(not _contact_swings.is_empty(), "physical AI Contact consumes Optics shapes")
	print("FIELD_SPONSORS choices=", _choices.size(), " contact_swings=", _contact_swings.size())
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro live field sponsor checks passed: physical game, shapes and restart.")
	get_tree().quit(0 if _failures == 0 else 1)


func _equip_fixture(state: MatchState) -> void:
	super._equip_fixture(state)
	for team: TeamMatchState in [state.away_team, state.home_team]:
		for player: PlayerMatchState in team.roster:
			player.definition.season_sponsors = {"F02": true, "F03": true, "G04": true}


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	if state.can_change_defense() and not _choices.has(state.plate_appearance_number):
		var mode: String = "wide" if state.plate_appearance_number % 2 == 0 else "tall"
		_check(
			SeasonSponsorEffects.choose_optics(state, mode), "explicit synthetic pre-PA selection"
		)
		_choices[state.plate_appearance_number] = mode
	if lab._swing_tracker.active and lab._swing_tracker.profile.id == &"swing.contact":
		_contact_swings[state.plate_appearance_number] = true
		var expected: SwingProfileDefinition = SeasonSponsorEffects.swing(
			ContentDB.get_swing(&"swing.contact"), state
		)
		_check(
			(
				is_equal_approx(
					lab._swing_tracker.profile.contact_radius_x_m, expected.contact_radius_x_m
				)
				and is_equal_approx(
					lab._swing_tracker.profile.contact_radius_y_m, expected.contact_radius_y_m
				)
			),
			"actual swing uses Gear and selected shape exactly once"
		)


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	await super._check_outro_and_restart(lab)
	_check(lab._match_state.optics_mode == "normal", "restart clears prior selection")
