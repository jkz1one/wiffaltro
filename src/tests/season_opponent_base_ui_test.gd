extends "res://src/tests/season_opponent_base_test.gd"
# Historical full-roster fixture; permanent-player defaults have separate integration tests.
## Native disclosure and a rendered cue from actual physical use of generated paid stock.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_base_units()
	if _base_paid != null:
		await _presented_base()
		await _base_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent Base UI checks passed: actual scoring cue and paid disclosure.")
	get_tree().quit(0 if _failures == 0 else 1)


func _presented_base() -> void:
	get_window().size = Vector2i(700, 400)
	await get_tree().process_frame
	var state: MatchState = MatchState.create(_base_team(_base_paid), _base_other())
	var source: MatchState = PhysicalMatchRequest.capture(state)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = state
	lab._player_home = true
	lab._sky_backdrop_enabled = false
	lab._automation = MatchAutomation.new()
	lab._automation.seed = 67
	lab._automation.presentation_enabled = true
	add_child(lab)
	var captured: bool = false
	if DisplayServer.get_name() != "headless":
		RenderingServer.set_render_loop_enabled(false)
	for frame in range(300000):
		await get_tree().physics_frame
		if not captured and state.phase == MatchState.Phase.PITCH_IN_FLIGHT \
			and lab._pitch_feedback.visible and lab._pitch_feedback.text.begins_with(
			"OPPONENT TAKE A BASE"):
			captured = true
			_check(get_viewport().get_visible_rect().encloses(lab._pitch_feedback.get_global_rect()),
				"actual scoring cue fits narrow viewport")
			RenderingServer.set_render_loop_enabled(true)
			await _capture(get_viewport(), "opponent-base-actual-cue")
			if DisplayServer.get_name() != "headless":
				RenderingServer.set_render_loop_enabled(false)
		if state.phase == MatchState.Phase.GAME_END:
			break
	RenderingServer.set_render_loop_enabled(true)
	var report: Dictionary = PhysicalMatchReport.capture(lab)
	_check(PhysicalMatchReport.valid(report)
		and PhysicalTacticalEvidence.report_matches(report, source),
		"presented paid Base game keeps exact physical proof")
	_check(captured and PhysicalBaseReport.runs(report, 0) == 1,
		"actual legal paid Base scores once and its cue is observed")
	print("NPC_BASE_PRESENTED releases=", report.releases.size(), " cue=", captured)
	lab.queue_free()
	await _frames()
	get_window().size = Vector2i(1280, 720)


func _base_ui() -> void:
	var app: SeasonApp = await _app()
	app.begin_season(SEED, true, false)
	_check(app.season.opponents._format == 13, "ordinary new start selects policy13")
	_check(SeasonSave.save(app.season), "new policy UI partial draft saves")
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-base-pregame")
	var card: VBoxContainer = SeasonPlayerCard.panel(app.menu._body, false)
	SeasonPages.wrapped(card, "Paid Base diagnostic • actual generated stock and physical use")
	_base_club["build"] = _base_paid
	SeasonOpponentTacticsUI.preview(card, _base_club, app.season._make_team(0))
	var labels: Array[Node] = card.find_children("*", "Label", true, false)
	_check(labels.any(func(node: Node) -> bool: return node.has_meta("opponent_base_policy"))
		and not labels.any(func(node: Node) -> bool: return node.text.contains("remains gated")),
		"current paid UI discloses Base price, legal priority and unused carry")
	await _frames()
	await _lesson_capture(app, card, "opponent-paid-base")
	app.queue_free()
	await _frames()
