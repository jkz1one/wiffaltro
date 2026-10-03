extends "res://src/tests/live_match_test.gd"
## A real player-owned fixture keeps its outro, then durable physical round settlement.

const RoundFixtures = preload("res://src/tests/season_physical_round_test.gd")
var _app: SeasonApp


func _ready() -> void:
	SeasonSave.path = "user://physical-visible-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://physical-visible-%d.cfg" % OS.get_process_id()
	var fixture: Node = RoundFixtures.new()
	var season: SeasonState = fixture._new(true)
	_check(fixture._failures == 0 and SeasonSave.save(season), "physical season fixture saves")
	fixture.free()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_app.play_season_game()
	_check(_app.lab != null, "ordinary saved pregame opens the managed match")
	await _play_owned()
	for frame in range(300000):
		await get_tree().physics_frame
		if _app.season.physical.pending.is_empty():
			break
		if not _app.round_ui._working:
			_check(false, "visible settlement paused: " + _app.round_ui.detail.text)
			break
	_check(_app._result_saved and _app.season.results.size() == 3,
		"real human fixture and two physical AI games publish one round")
	_check(_app.season.player_results[0].performance.size() == 8
		and SeasonSave.restore() != null, "actual human evidence replays with physical archive")
	_check(ClubCareer.same(SeasonSave.snapshot(_app.season),
		SeasonSave.snapshot(SeasonSave.restore())), "visible route preserves all receipts and evidence")
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro physical visible checks passed: human outro and atomic three-game round.")
	get_tree().quit(0 if _failures == 0 else 1)


func _play_owned() -> void:
	var lab: PitchBatLab = _app.lab
	lab._throw_number = 67000
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var previous: String = ""
	var stalled: int = 0
	for frame in range(90000):
		await get_tree().physics_frame
		var state: MatchState = lab._match_state
		if state.phase == MatchState.Phase.GAME_END:
			break
		var progress: String = "%d:%d:%d" % [
			state.phase, state.plate_appearance_number, lab._throw_number]
		stalled = stalled + 1 if progress == previous else 0
		previous = progress
		if stalled > 1200:
			_check(false, "visible managed fixture stalled: " + progress)
			return
		if lab._player_is_batting():
			# Passive human input is a state-flow fixture, not batting-balance evidence.
			if lab._awaiting_batter_confirm and state.phase == MatchState.Phase.PRE_PITCH:
				PitchBatLabFeelSupport.confirm_batter_ready(lab)
		elif state.phase == MatchState.Phase.PRE_PITCH:
			if not lab._release_controller.active:
				lab._pitch_target = lab.DEFAULT_TARGET
				lab._pitch_effort = 1.0
				PitchBatLabFeelSupport.begin_pitch_release(lab)
			elif lab._release_controller.elapsed_seconds >= PitchReleaseController.IDEAL_RELEASE_SECONDS:
				PitchBatLabFeelSupport.commit_pitch_release(lab)
	_check(lab._match_state.phase == MatchState.Phase.GAME_END, "actual human fixture completes")
	print("PHYSICAL_VISIBLE score=", lab._match_state.score_label(),
		" pitches=", lab._play_records.size())
	await _check_outro_and_restart(lab)


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
		and not _app.round_ui.shade.visible and _app.season.player_results.is_empty(),
		"completed game stays on its original outro until Continue")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.physical.pending.human[0] == _app._fixture_id,
		"completed actual human evidence survives closing at the outro")
	_check(lab._match_state.score_label() == score, "checkpoint preserves final score")
	_app.finish_game()
	_check(_app.lab == null and _app.round_ui._working, "Continue begins required physical jobs")
