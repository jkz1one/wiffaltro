extends "res://src/tests/season_tactical_live_test.gd"

const GearFixtures = preload("res://src/tests/season_gear_progress_test.gd")
var _gear_pitches: int = 0


func _ready() -> void:
	SeasonSave.path = "user://gear-progress-live-%d.json" % OS.get_process_id()
	var fixture: Node = GearFixtures.new()
	_season = fixture._chain()
	_check(_season != null and fixture._failures == 0, "real paid chain reaches nineteen")
	fixture.free()
	if _season == null:
		get_tree().quit(1)
		return
	var app: SeasonApp = SeasonApp.new()
	app.season = _season
	var saved: bool = SeasonPregameCommit.save(app)
	app.free()
	_check(saved, "durable pregame at nineteen")
	if not saved:
		get_tree().quit(1)
		return
	var game: Dictionary = _season.pending_fixture()
	var before: Dictionary = _season.build.view()
	_check(game.home == 0, "actual final is home fixture")
	await _run_match(67)
	_check(_observed_swings > 0 and _gear_pitches > 0, "earned Gear reaches both actual actors")
	await _settlement_retry(game, before)
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null, "physical threshold result reloads")
	if restored != null:
		for id: String in ["BAT-CON-02", "BALL-MOV-02"]:
			_check(
				restored.career.gear_counts()[id] == 20, "physical final grants twentieth use once"
			)
		_check(
			restored.build._gear_progress.eligible().has("BAT-CON-03"),
			"physical result earns third tier"
		)
		print(
			"GEAR_LIVE counts=",
			restored.career.gear_counts(),
			" swings=",
			_observed_swings,
			" pitches=",
			_gear_pitches
		)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live earned Gear checks passed: paid effects, twentieth use and save retry."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	if (
		state.batting_team() == state.home_team
		and lab._swing_tracker != null
		and lab._swing_tracker.active
	):
		_check(
			is_equal_approx(lab._swing_tracker.profile.gear_fair_exit_scale, 0.93),
			"real swing gets only Jumbo penalty"
		)
		_observed_swings += 1
	if state.batting_team() == state.away_team and lab._pitch_actor.running:
		var base: PitchDefinition = lab._selected_pitch()
		_check(
			is_equal_approx(
				lab._pitch_actor.parameters.mastery_movement_scale,
				base.mastery_movement_scale * 1.15
			),
			"real pitch gets Cut Ball movement exactly once"
		)
		_gear_pitches += 1
