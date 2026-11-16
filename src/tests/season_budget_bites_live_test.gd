extends "res://src/tests/season_tactical_live_test.gd"

const BudgetFixtures = preload("res://src/tests/season_budget_bites_test.gd")
var _use_plan: bool = true


func _ready() -> void:
	var fixture: Node = BudgetFixtures.new()
	for use_plan: bool in [true, false]:
		_use_plan = use_plan
		_observed_swings = 0
		_season = fixture._paid_budget()
		_check(_season != null and fixture._failures == 0, "actual paid sponsor and spend-down")
		SeasonSave.path = "user://budget-live-%s-%d.json" % [str(use_plan), OS.get_process_id()]
		var app: SeasonApp = SeasonApp.new()
		app.season = _season
		_check(SeasonPregameCommit.save(app), "production pregame commitment saves generated Plan")
		app.free()
		var before: Dictionary = _season.build.view()
		_check(
			before.wallet.held.size() == 1 and before.wallet.held[0].paid == 0, "one ordinary grant"
		)
		var game: Dictionary = _season.pending_fixture()
		_check(game.home == 0, "paid home club")
		await _run_match(67)
		var used: Array = _played_state.home_team.tactics.consumed
		_check(used.size() == (1 if use_plan else 0), "consume only explicitly activated grant")
		if use_plan:
			_check(_observed_swings > 0, "actual shared AI Plan execution")
			await _settlement_retry(game, before)
		else:
			_check(
				_season.record_player_result(
					game.id,
					_played_state.away_team.runs,
					_played_state.home_team.runs,
					_played_state.performance.snapshot(_played_state)
				),
				"complete game with unused grant"
			)
			_check(
				_season.build.view().wallet.held == before.wallet.held,
				"unused exact receipt carries"
			)
			_check(
				(
					SeasonSave.save(_season)
					and SeasonSave.restore().build.view() == _season.build.view()
				),
				"completed carried grant replays"
			)
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored.build._pregames[str(game.id)].outcome == "granted",
			"completed commitment history retained"
		)
		print("BUDGET_LIVE used=", use_plan, " swing_frames=", _observed_swings)
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live Budget Bites checks passed: generated Plan use, carry and durable results."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.home_team
	if _use_plan and state.phase == MatchState.Phase.PRE_PITCH and state.between_batters:
		for copy: Dictionary in team.tactics.held.duplicate(true):
			team.tactics.activate(state, team, copy.id, &"swing.contact")
	if (
		team.tactics.active(state) == "C03"
		and lab._swing_tracker != null
		and lab._swing_tracker.active
	):
		_check(
			(
				lab._swing_tracker.profile.id == &"swing.contact"
				and lab._swing_tracker.profile.tactical_quality_exit_scale == 1.06
			),
			"generated Plan uses ordinary lock and resolver"
		)
		_observed_swings += 1
