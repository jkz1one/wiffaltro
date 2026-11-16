extends "res://src/tests/season_opponent_sponsors_visible_test.gd"
# Historical full-roster fixture; permanent-player defaults have separate integration tests.
## Actual earned first-round purchase, committed managed grant, use and durable replay.

var _budget_used: bool = false
var _budget_captured: bool = false
var _swing_probe: OpponentTacticalProbe = OpponentTacticalProbe.new()


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var selected: int = -1
	var preparation_games: int = 0
	for seed_value: int in [47]: # Earned qualifying case recovered through actual first-round games.
		SeasonSave.path = "user://budget-earned-%d-%d.json" % [OS.get_process_id(), seed_value]
		PitchBatLabSettings.path = "user://budget-earned-%d.cfg" % OS.get_process_id()
		_app = SeasonApp.new()
		add_child(_app)
		await get_tree().process_frame
		_app.begin_season(seed_value, true, false)
		_app.season.opponents._format = 12
		_check(SeasonSave.save(_app.season), "historical policy12 partial draft saves")
		for pick in range(4):
			_app.choose_player(_app.season.offers()[0])
		if DisplayServer.get_name() != "headless":
			RenderingServer.set_render_loop_enabled(false)
		var fixture: Dictionary = _app.season.pending_fixture()
		var report: Dictionary = await _human_report(_app.season, fixture)
		if report.is_empty():
			break
		var index: int = fixture.away if fixture.home == 0 else fixture.home
		_app.round_ui.begin([fixture.id, report.away_runs, report.home_runs,
			report.performance, [], [], {}, [], [], {}, {}, [],
			report.tactics.teams[0 if fixture.away == index else 1]])
		await _wait_sponsor_round()
		preparation_games += 3
		_audit_season()
		var club: Dictionary = _app.season.opponents.clubs["4"]
		print("NPC_BUDGET_EARNED_CANDIDATE seed=", seed_value,
			" actual_next_outcome=", SeasonBudgetBites.outcome(club.build))
		if SeasonBudgetBites.outcome(club.build) == "granted":
			selected = seed_value
			break
		_app.queue_free()
		await get_tree().process_frame
		_clear_save()
	RenderingServer.set_render_loop_enabled(true)
	_check(selected >= 0, "actual completed first round earns a paid qualifying Budget sponsor")
	if selected >= 0:
		_prior_results = 1
		_app.menu.show_lineup()
		var labels: Array[Node] = _app.menu._body.find_children("*", "Label", true, false)
		_check(labels.any(func(node: Node) -> bool: return node.text.contains("seven sponsors"))
			and not labels.any(func(node: Node) -> bool: return node.text.contains("six sponsors")),
			"current pregame discloses the complete seven-sponsor pool")
		await _review("opponent-budget-earned-pregame")
		get_window().size = Vector2i(700, 400)
		await get_tree().process_frame
		var game: int = int(_app.season.pending_fixture().id)
		var stored: Dictionary = _app.season.opponents.clubs["4"].build.to_data()
		_app.play_season_game()
		_check(_app.lab != null, "ordinary Play Game starts earned Budget fixture")
		var state: MatchState = _app.lab._match_state
		var team: TeamMatchState = state.away_team
		_check(_app.season.pending_fixture().away == 4 and team.ai_budget.outcome == "granted",
			"next scheduled opponent commits its actual final Cash and bag")
		_check(ClubCareer.same(stored, _app.season.opponents.clubs["4"].build.to_data()),
			"managed projection leaves stored opponent checkout unchanged until settlement")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null and ClubCareer.same(restored._make_team(4).ai_tactical_initial,
			team.ai_tactical_initial), "unfinished restart derives exactly the same generated copy")
		if DisplayServer.get_name() != "headless":
			RenderingServer.set_render_loop_enabled(false)
		await _play_owned()
		await _wait_sponsor_round()
		RenderingServer.set_render_loop_enabled(true)
		get_window().size = Vector2i(1280, 720)
		_check(_budget_used and (_budget_captured or DisplayServer.get_name() == "headless"),
			"actual earned zero-paid Plan activates once and native cue is reviewed")
		_check(_app._result_saved and _app.season.player_results.size() == 2,
			"original managed outro and Continue publish the second three-game round")
		_audit_season()
		var build: SeasonBuild = _app.season.opponents.clubs["4"].build
		_check(build._pregames[str(game)].outcome == "granted", "exact scheduled grant is published")
		var snapshot: Dictionary = SeasonSave.snapshot(_app.season)
		var bad: Dictionary = snapshot.duplicate(true)
		bad.results[-1].ai_tactics["4"].budget.cash += 1
		_check(SeasonSave._decode(bad) == null, "altered committed Cash evidence rejects")
		_app.menu.show_lineup()
		await get_tree().process_frame
		await _capture("opponent-budget-earned-settled")
		print("NPC_BUDGET_EARNED seed=", selected, " preparation_games=", preparation_games,
			" managed_plus_round=3 ", _swing_probe.summary())
	if is_instance_valid(_app):
		_app.queue_free()
		await get_tree().process_frame
	_clear_save()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent Budget visible checks passed: earned purchase and managed grant.")
	get_tree().quit(0 if _failures == 0 else 1)


func _clear_save() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _process(_delta: float) -> void:
	if not is_instance_valid(_app) or _app.lab == null:
		return
	var lab: PitchBatLab = _app.lab
	_swing_probe.observe(lab, _check)
	var state: MatchState = lab._match_state
	if state == null:
		return
	var team: TeamMatchState = state.away_team
	if team.ai_budget.is_empty():
		return
	for action: Dictionary in team.tactics.consumed:
		if action.receipt == "budget:%d" % int(team.ai_budget.game):
			_budget_used = true
	if not _budget_captured and _budget_used and DisplayServer.get_name() != "headless" \
		and lab._pitch_feedback.visible and lab._pitch_feedback.text.begins_with("OPPONENT SWING PLAN"):
		_budget_captured = true
		_capture_budget(lab)


func _capture_budget(lab: PitchBatLab) -> void:
	RenderingServer.set_render_loop_enabled(true)
	_check(get_viewport().get_visible_rect().encloses(lab._pitch_feedback.get_global_rect()),
		"actual Budget Plan cue fits the narrow managed viewport")
	await _capture("opponent-budget-earned-cue")
	RenderingServer.set_render_loop_enabled(false)
