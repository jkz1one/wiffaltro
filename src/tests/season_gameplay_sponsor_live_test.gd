extends "res://src/tests/live_match_test.gd"
## Synthetic fully developed/equipped clubs exercise both shared control paths.
## Paid purchase/provenance is covered separately; AI buying is not implemented.

var _deli_windows: Dictionary = {}
var _deli_swings: Dictionary = {}
var _natural_releases: Dictionary = {}


func _ready() -> void:
	await _run_match(67)
	_check(not _deli_windows.is_empty(), "real credited Singles create Deli windows")
	_check(not _deli_swings.is_empty(), "live AI takes a Contact swing during a Deli window")
	_check(not _natural_releases.is_empty(), "live pitchers release natural-delivery pitches")
	print(
		"GAMEPLAY_SPONSORS deli_windows=",
		_deli_windows.size(),
		" deli_swings=",
		_deli_swings.size(),
		" natural_releases=",
		_natural_releases.size()
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live gameplay sponsor checks passed: physical effects, whole game and restart."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _equip_fixture(state: MatchState) -> void:
	super._equip_fixture(state)
	for team: TeamMatchState in [state.away_team, state.home_team]:
		for player: PlayerMatchState in team.roster:
			player.definition.season_sponsors = {"A07": true, "B02": 4}


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	if SeasonSponsorEffects.deli_active(state):
		_deli_windows[state.plate_appearance_number] = true
		if lab._swing_tracker.active and lab._swing_tracker.profile.id == &"swing.contact":
			_deli_swings[state.plate_appearance_number] = true
			var expected: float = 1.09 if state.top_half else 1.0
			_check(
				is_equal_approx(lab._swing_tracker.profile.gear_fair_exit_scale, expected),
				"live AI/player Deli adds to actual equipped Bat modifier"
			)
	if lab._pitch_actor.running:
		var pitcher: PlayerMatchState = state.pitcher()
		if lab._selected_pitch().delivery_profile.id == pitcher.definition.natural_delivery.id:
			_natural_releases["%s:%d" % [pitcher.definition.id, pitcher.pitch_count]] = true


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	await super._check_outro_and_restart(lab)
	_check(not lab._match_state._deli_next_batter, "restart cannot retain a Singles chain")
