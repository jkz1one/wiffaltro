extends "res://src/tests/season_tactical_live_test.gd"

const Supplies = preload("res://src/tests/season_tactical_sponsors_test.gd")
var _chosen: StringName = &"swing.contact"


func _ready() -> void:
	var fixture: Node = Supplies.new()
	for swing: StringName in [&"swing.contact", &"swing.power"]:
		_chosen = swing
		_observed_swings = 0
		_season = fixture._paid_combo()
		_check(_season != null and fixture._failures == 0, "real paid combo sponsor/cards")
		if _season == null:
			break
		SeasonSave.path = "user://combo-live-%s-%d.json" % [String(swing), OS.get_process_id()]
		_check(SeasonSave.save(_season), "save actual pregame inventory")
		var before: Dictionary = _season.build.view()
		var interrupted: MatchState = _season.make_match()
		interrupted.top_half = false
		var tactics: MatchTactics = interrupted.home_team.tactics
		_check(
			tactics.activate_combo(
				interrupted, interrupted.home_team, tactics.combo_copies(), swing
			),
			"unfinished combo"
		)
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored != null and restored.build.view() == before,
			"restart restores exact paid copies"
		)
		var restarted: MatchState = restored.make_match()
		_check(
			(
				not restarted.home_team.tactics._combo_used
				and restarted.home_team.tactics.held.size() == 2
			),
			"restart retains no effect or used flag"
		)
		var game: Dictionary = _season.pending_fixture()
		_check(game.home == 0, "paid club home")
		await _run_match(67)
		var used: Array = _played_state.home_team.tactics.consumed
		_check(
			used.size() == 2 and _observed_swings > 0,
			"both paid copies used with actual combo swings"
		)
		var stats: Dictionary = _played_state.performance.snapshot(_played_state)
		for patch: Dictionary in [
			{"combo": false},
			{"combo": "true"},
			{"pa": 9999},
			{"receipt": "missing"},
			{"player": "foreign"}
		]:
			var invalid: Array = used.duplicate(true)
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
				"invalid pair rejects result atomically"
			)
		var unmarked: Array = used.duplicate(true)
		for action: Dictionary in unmarked:
			action.erase("combo")
		_check(
			not _season.record_player_result(
				game.id,
				_played_state.away_team.runs,
				_played_state.home_team.runs,
				stats,
				[],
				unmarked
			),
			"unmarked same-PA pair rejected"
		)
		var no_sponsor: SeasonBuild = _season.build._fork()
		no_sponsor._bank._state.sponsors.clear()
		_check(
			not SeasonTacticalPurchase.settle(no_sponsor, used, stats).is_empty(),
			"pair requires actual sponsor ownership at settlement"
		)
		await _settlement_retry(game, before)
		print("COMBO_LIVE swing=", swing, " actual_swing_frames=", _observed_swings)
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live tactical sponsor checks passed: paid combo, physical games and replay."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.home_team
	if state.phase == MatchState.Phase.PRE_PITCH and state.between_batters:
		team.tactics.activate_combo(state, team, team.tactics.combo_copies(), _chosen)
	if (
		state.batting_team() == team
		and team.tactics.active(state) == MatchTactics.COMBO
		and lab._swing_tracker != null
		and lab._swing_tracker.active
	):
		var profile: SwingProfileDefinition = lab._swing_tracker.profile
		var normal: SwingProfileDefinition = SeasonGearCatalog.swing(
			ContentDB.get_swing(_chosen), state.batter().definition
		)
		_check(
			profile.id == _chosen and profile.tactical_quality_exit_scale == 1.06,
			"actual AI swing respects paired lock"
		)
		_check(
			(
				is_equal_approx(profile.contact_radius_x_m / normal.contact_radius_x_m, 1.08)
				and is_equal_approx(
					profile.gear_fair_exit_scale / normal.gear_fair_exit_scale, 0.95
				)
			),
			"actual AI profile preserves both tradeoffs"
		)
		_observed_swings += 1
