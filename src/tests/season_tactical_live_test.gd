extends "res://src/tests/live_match_test.gd"

const Fixtures = preload("res://src/tests/season_tactical_test.gd")
var _season: SeasonState
var _played_state: MatchState
var _observed_swings: int = 0


func _ready() -> void:
	var fixture: Node = Fixtures.new()
	for card: String in ["A10", "C03"]:
		_season = fixture._paid_tactics([card, "C02"])
		_check(_season != null and fixture._failures == 0, "actual generated tactical stock")
		if _season == null:
			break
		for id: String in [card, "C02"]:
			_check(
				(
					_season
					. build
					. commit(
						fixture._command(
							_season.build,
							"tactical_buy",
							{"offer": fixture._offer(_season.build, id)}
						)
					)
					. ok
				),
				"pay full ordinary tactical price"
			)
		SeasonSave.path = "user://tactical-live-%s-%d.json" % [card, OS.get_process_id()]
		_check(SeasonSave.save(_season), "save pregame inventory")
		var before: Dictionary = _season.build.view()
		var interrupted: MatchState = _season.make_match()
		var copies: Array = interrupted.home_team.tactics.held
		interrupted.home_team.current_pitcher().stamina_remaining -= 30
		for copy: Dictionary in copies:
			if copy.item == "C02":
				_check(
					interrupted.home_team.tactics.activate(
						interrupted, interrupted.home_team, copy.id
					),
					"unfinished recovery activates"
				)
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored != null and restored.build.view() == before,
			"unfinished match retains saved inventory"
		)
		var restarted: MatchState = restored.make_match()
		_check(
			(
				restarted.home_team.tactics.held.size() == 2
				and restarted.home_team.tactics.consumed.is_empty()
			),
			"restart restores copies without prior uses"
		)
		_check(
			restarted.pitcher().stamina_remaining == restarted.pitcher().stamina_max,
			"restart restores pregame resources too"
		)
		_observed_swings = 0
		var game: Dictionary = _season.pending_fixture()
		_check(game.home == 0, "paid home club fixture")
		await _run_match(67)
		var used: Array = _played_state.home_team.tactics.consumed
		_check(
			used.size() == 2 and _observed_swings > 0,
			"both paid copies used and actual AI swing profile observed"
		)
		var stats: Dictionary = _played_state.performance.snapshot(_played_state)
		var invalid: Array = used.duplicate(true)
		invalid[1].receipt = invalid[0].receipt
		_check(
			(
				not _season.record_player_result(
					game.id,
					_played_state.away_team.runs,
					_played_state.home_team.runs,
					stats,
					[],
					invalid
				)
				and _season.build.view() == before
			),
			"duplicate consumption rejects whole result"
		)
		for patch: Dictionary in [
			{"receipt": "foreign"},
			{"pa": 0},
			{"pa": 9999},
			{"player": "player.foreign"},
			{"swing": "swing.invalid"},
			{"extra": true}
		]:
			invalid = used.duplicate(true)
			invalid[0].merge(patch, true)
			_check(
				(
					not _season.record_player_result(
						game.id,
						_played_state.away_team.runs,
						_played_state.home_team.runs,
						stats,
						[],
						invalid
					)
					and _season.build.view() == before
				),
				"invalid activation evidence rejects result atomically"
			)
		await _settlement_retry(game, before)
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
		saved.results[-1].tactics[0].pa += 1
		_check(SeasonSave._decode(saved) == null, "result and build consumption must agree exactly")
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live tactical checks passed: paid cards, two physical games and atomic settlement."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _settlement_retry(game: Dictionary, before: Dictionary) -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	app.season = _season
	app._fixture_id = game.id
	app._season_game = true
	app.lab = PitchBatLab.new()
	app.lab._match_state = _played_state
	app.lab._player_home = true
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	_check(
		not app._commit_result() and app._result_recorded,
		"postgame failed save leaves one retryable result"
	)
	var settled: Dictionary = app.season.build.view()
	_check(settled.wallet.held.is_empty(), "both used copies removed with result")
	SeasonSave.path = path
	_check(
		FileAccess.get_file_as_string(path) == bytes, "failed result write preserves pregame bytes"
	)
	_check(
		SeasonSave.restore().build.view() == before,
		"reloading failed write restores whole pregame snapshot"
	)
	_check(
		app._commit_result() and app.season.build.view() == settled,
		"retry saves without spending or paying again"
	)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.build.view() == settled,
		"completed game replay consumes exact copies"
	)
	_check(
		app._commit_result() and app.season.build.view() == settled, "repeated continue idempotent"
	)
	app.lab.free()
	app.lab = null
	app.queue_free()
	await get_tree().process_frame


func _progression_fixture() -> MatchState:
	return _season.make_match()


func _equip_fixture(state: MatchState) -> void:
	_played_state = state


func _player_home_for_fixture() -> bool:
	# Synthetic driver lets the genuinely paid home club bat via shared AI swing hooks.
	return false


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.home_team
	if state.phase == MatchState.Phase.PRE_PITCH and state.between_batters:
		for copy: Dictionary in team.tactics.held.duplicate(true):
			var swing: StringName = &"swing.contact" if copy.item == "C03" else &""
			team.tactics.activate(state, team, copy.id, swing)
	if state.batting_team() == team and lab._swing_tracker != null and lab._swing_tracker.active:
		var profile: SwingProfileDefinition = lab._swing_tracker.profile
		if team.tactics.active(state) == "C03":
			_check(
				profile.id == &"swing.contact" and profile.tactical_quality_exit_scale == 1.06,
				"AI honors Contact plan"
			)
			_observed_swings += 1
		elif team.tactics.active(state) == "A10":
			_check(
				is_equal_approx(profile.gear_fair_exit_scale, 0.95), "actual Tape fair-exit penalty"
			)
			_observed_swings += 1
