extends Node

var _failures: int = 0


func _ready() -> void:
	for run_seed in [11, 29]:
		await _run_match(run_seed)
	if _failures == 0:
		print("Wiffaltro live match checks passed: 2 scripted-player matches.")
	get_tree().quit(0 if _failures == 0 else 1)


func _run_match(run_seed: int) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab._throw_number = run_seed * 1000
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	# Keep synthetic test records out of human QC sessions.
	var export_path: String = "user://live-match-test-%d-%d.json" % [OS.get_process_id(), run_seed]
	lab._record_export.path = export_path
	var previous_progress: String = ""
	var stalled_frames: int = 0
	var live_balls: int = 0
	var previous_phase: MatchState.Phase = MatchState.Phase.PRE_PITCH
	for frame in range(90000):
		await get_tree().physics_frame
		var state: MatchState = lab._match_state
		if state.phase == MatchState.Phase.GAME_END:
			break
		var progress: String = "%d:%d:%d" % [
			state.phase, state.plate_appearance_number, lab._throw_number
		]
		stalled_frames = stalled_frames + 1 if progress == previous_progress else 0
		previous_progress = progress
		if stalled_frames > 1200:
			_check(false, "live match stalled for 20 simulated seconds: " + progress)
			break
		if state.phase == MatchState.Phase.BALL_IN_PLAY and previous_phase != state.phase:
			live_balls += 1
		previous_phase = state.phase
		if lab._player_is_batting():
			# Passive hitter intentionally takes every pitch. This is a state-flow
			# stress case, not a skill model or batting-balance sample.
			if lab._awaiting_batter_confirm and state.phase == MatchState.Phase.PRE_PITCH:
				PitchBatLabFeelSupport.confirm_batter_ready(lab)
		elif state.phase == MatchState.Phase.PRE_PITCH:
			if not lab._release_controller.active:
				lab._pitch_target = lab.DEFAULT_TARGET
				lab._pitch_effort = 1.0
				PitchBatLabFeelSupport.begin_pitch_release(lab)
			elif lab._release_controller.elapsed_seconds >= PitchReleaseController.IDEAL_RELEASE_SECONDS:
				PitchBatLabFeelSupport.commit_pitch_release(lab)
	_check(lab._match_state.phase == MatchState.Phase.GAME_END, "live match must finish")
	_check(live_balls > 0, "live match must exercise AI contact and ball-in-play")
	_check(lab._play_records.size() > 0, "live match must produce completed play records")
	print("LIVE_MATCH seed=", run_seed, " score=", lab._match_state.score_label(),
		" inning=", lab._match_state.inning, " records=", lab._play_records.size(),
		" balls_in_play=", live_balls)
	lab.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(export_path)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
