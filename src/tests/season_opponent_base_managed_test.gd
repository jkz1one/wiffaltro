extends "res://src/tests/season_opponent_base_rounds_test.gd"
# Historical full-roster fixture; permanent-player defaults have separate integration tests.
## Ordinary managed match and original outro; native physics uses periodic real render drains.

var _native_sampling: bool = false
var _native_drawing: bool = false
var _native_frames: int = 0
var _native_draws: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://base-managed-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://base-managed-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_app.begin_season(443, true, false)
	_check(_app.season.opponents._format == 13, "ordinary managed start selects policy13")
	_check(SeasonSave.save(_app.season), "explicit policy13 managed draft saves")
	for pick in range(4):
		_app.choose_player(_app.season.offers()[0])
	_app.menu.show_lineup()
	await _review("opponent-base-managed-pregame")
	get_window().size = Vector2i(700, 400)
	await get_tree().process_frame
	_app.play_season_game()
	_check(_app.lab != null, "ordinary Play Game starts managed policy13")
	var fixture: Dictionary = _app.season.pending_fixture()
	var opponent: TeamMatchState = _app.lab._match_state.away_team if fixture.home == 0 \
		else _app.lab._match_state.home_team
	_check(opponent.ai_base, "managed opponent enables the same Base rules")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw # Initialize native resources before fast preparation.
		_native_sampling = true
		RenderingServer.set_render_loop_enabled(false)
	await _play_owned()
	await _wait_sponsor_round()
	_native_sampling = false
	RenderingServer.set_render_loop_enabled(true)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(_native_draws > 0, "native resource drains render real progress frames")
		print("NPC_BASE_NATIVE_DRAWS ", _native_draws)
	_check(_app._result_saved and _app.season.player_results.size() == 1,
		"original outro Continue publishes one complete three-game round")
	_audit_season()
	var snapshot: Dictionary = SeasonSave.snapshot(_app.season)
	_check(snapshot.version == 57, "managed result keeps schema57")
	for row: Dictionary in _app.season.physical.reports:
		_check(row.report.version == 7, "other clubs use the same report7 physics")
	get_window().size = Vector2i(1280, 720)
	_app.menu.show_lineup()
	await get_tree().process_frame
	await _capture("opponent-base-managed-settled")
	_app.queue_free()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent Base managed checks passed: real outro, restart and atomic round.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	for frame in range(780):
		await get_tree().physics_frame
		if lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD:
			break
	_check(lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD,
		"real human fixture finishes its celebration and outro")
	var score: String = lab._match_state.score_label()
	_check(_app._result_recorded,
		"game end automatically queues evidence without granting a partial round")
	_check(_app.lab == lab and not _app.round_ui._working
		and not _app.round_ui.shade.visible
		and _app.season.player_results.size() == _prior_results,
		"completed game stays on its original outro until Continue")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.physical.pending.human[0] == _app._fixture_id,
		"completed actual human evidence survives closing at the outro")
	_check(lab._match_state.score_label() == score, "checkpoint preserves final score")
	_app.finish_game()
	_check(_app.lab == null and _app.round_ui._working, "Continue begins required physical jobs")


func _review(label: String) -> void:
	await get_tree().process_frame
	var found: bool = false
	for node: Node in _app.menu._body.find_children("*", "Label", true, false):
		if not node.has_meta("opponent_base_policy"):
			continue
		found = true
		var scroll: ScrollContainer = _app.menu._body.get_parent()
		scroll.ensure_control_visible(node)
		await get_tree().process_frame
		await _capture(label)
		get_window().size = Vector2i(700, 400)
		await get_tree().process_frame
		scroll.ensure_control_visible(node)
		await get_tree().process_frame
		_check(get_viewport().get_visible_rect().encloses(_app.menu._footer.get_global_rect()),
			"narrow Base policy disclosure preserves navigation")
		await _capture(label + "-small")
		get_window().size = Vector2i(1280, 720)
		break
	_check(found, "new empty starting bag still discloses the actual Base policy")


func _process(delta: float) -> void:
	super._process(delta)
	if not _native_sampling or _native_drawing:
		return
	_native_frames += 1
	if _native_frames % 180 == 0:
		_native_progress_frame()


func _native_progress_frame() -> void:
	_native_drawing = true
	RenderingServer.set_render_loop_enabled(true)
	await RenderingServer.frame_post_draw
	_native_draws += 1
	if _native_sampling:
		RenderingServer.set_render_loop_enabled(false)
	_native_drawing = false
