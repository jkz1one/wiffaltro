extends Node
## Source-only component gate, executable only under an explicitly reviewed source profile.
## Genuine public manual issuance and ordinary body installation; constructed diagnostic record
## and synthetic HR/GAME_END state. NOT natural play, completed-game, settlement or human evidence.
const FIXTURE = preload("res://src/tests/ac02_public_fixture.gd")
const QC = preload("res://src/tests/ac02_manual_qc_controls.gd")
const COMMAND = preload("res://src/labs/pitch_bat_lab/ac02_manual_qc_command_v1.gd")
var _app: SeasonApp
var _output: String = ""
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hr09-owned-output="):
			_output = argument.trim_prefix("--hr09-owned-output=")
	await _run()
	if is_instance_valid(_app):
		# Ordinary close may flush only the explicitly constructed diagnostic record
		# to this isolated output. It never commits the synthetic GAME_END as a result.
		_check(_app._close_match(), "ordinary isolated cleanup closes original issued lab")
		_app.queue_free()
		await TestAudioDrain.finish(get_tree())
	print(
		"HR_AC02_OWNED_CLEANUP09 checks=",
		_checks,
		" failures=",
		_failures,
		" synthetic_terminal=true constructed_records=true natural_game=false settlement=false"
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	if not _check(
		(
			_output.is_absolute_path()
			and not DirAccess.dir_exists_absolute(_output)
			and not FileAccess.file_exists(_output)
			and OS.get_cmdline_user_args().has("--physical-in-process")
		),
		"fresh isolated output and explicit in-process test required"
	):
		return
	if not _check(
		(
			StadiumNpcAc02IssuedQualificationV1.eligible()
			and StadiumNpcPublicRuntime.source_qualified()
			and COMMAND._profile_selected()
		),
		(
			"existing genuine source, native issuance and QC profile admission must all pass; "
			+ "never reseal here"
		)
	):
		return
	if not _check(DirAccess.make_dir_recursive_absolute(_output) == OK, "isolated output created"):
		return
	SeasonSave.path = _output.path_join("component-season.json")
	PitchBatLabSettings.path = _output.path_join("component-settings.cfg")
	var prepared: SeasonState = FIXTURE.season()
	if not _check(
		prepared != null and SeasonSave.save(prepared),
		"existing allocator fixture saved ordinarily"
	):
		return
	await get_tree().process_frame
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	_app.play_season_game()
	_app.set_process(false)
	var lab: PitchBatLab = _app.lab
	if not _check(
		(
			QC.active_manual(lab)
			and lab._managed_match
			and not lab._player_home
			and ClubCareer.same(_app.season.pending_fixture(), FIXTURE.fixture(_app.season))
		),
		"ordinary public Play owns the genuine manual AC02 fixture"
	):
		return
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._at_bat_cadence.stop()
	lab._record_export.path = _output.path_join("constructed-component-records.json")
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if not _check(issue.deep_intact(lab, property), "original issued owner starts deeply intact"):
		return
	_owned_cleanup_component_pitch(lab, issue, property)


func _owned_cleanup_component_pitch(
	lab: PitchBatLab, issue: StadiumNpcAc02IssuedStateV1, property: StadiumNpcPublicProperty
) -> void:
	var season_before: Dictionary = SeasonSave.snapshot(_app.season)
	var save_before: String = FileAccess.get_sha256(SeasonSave.path)
	if not _check(lab._match_state.begin_pitch(), "ordinary fixture can begin its component pitch"):
		return
	lab._at_bat_cadence.mark_pitch_live()
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 1, 0.28)
	launch.velocity = Vector3(0, 8, 12)
	launch.orientation = Quaternion.IDENTITY
	lab._start_ball_in_play(launch)
	var ball: BattedBallBody = lab._batted_ball
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var play: BallPlayState = resolver.state
	if not _check(
		(
			is_instance_valid(ball)
			and issue._ball == ball
			and issue._ball_state == play
			and issue.deep_intact(lab, property)
		),
		"ordinary launch binds same body/state to genuine issued owner"
	):
		return
	# Explicit synthetic component setup. Do not emit scored outcome or mutate season rewards.
	ball.freeze = true
	play.dead = true
	play.result_floor = BallPlayState.ResultFloor.HOME_RUN
	lab._match_state.phase = MatchState.Phase.GAME_END
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.HOME_RUN
	lab._home_run.resolve_ball(lab, outcome)
	var record: PlayRecord = PlayRecord.new()
	record.play_number = 1
	record.mode = "hr09_constructed_owned_cleanup_component"
	record.inning = lab._match_state.inning
	record.top_half = lab._match_state.top_half
	lab._active_play_record = record
	PitchBatLabFeelSupport.finish_record(lab, &"hr09_component_record", 0)
	if not _check(
		(
			issue.deep_intact(lab, property)
			and issue.manual_qc_pending()
			and lab._play_records.size() == 1
			and lab._play_records[0] == record
		),
		"synthetic terminal component keeps genuine owner and constructed pending diagnostic record"
	):
		return
	lab._home_run.advance(lab, 6.0)
	_check(
		(
			lab._home_run.flight_complete
			and lab._home_run.flight_end_reason == &"timeout"
			and issue._ball == ball
			and lab._batted_ball == ball
		),
		"terminal component retains issued body through timeout and return tail"
	)
	lab._home_run.advance(lab, 0.7)
	_check(
		(
			not lab._home_run.active
			and not lab._home_run.cleanup_refused
			and lab._batted_ball == null
			and issue._ball == null
			and issue._ball_state == null
			and ball.is_queued_for_deletion()
		),
		"natural presentation completion uses sanctioned issued-null transition"
	)
	_check(
		(
			lab._ball_play_resolver == resolver
			and resolver.state == play
			and play.dead
			and play.result_floor == BallPlayState.ResultFloor.HOME_RUN
		),
		"supported terminal cleanup preserves exact resolver evidence"
	)
	_check(
		(
			issue.deep_intact(lab, property)
			and issue.owns_cleanup(lab, property)
			and QC.active_manual(lab)
		),
		"original issued owner remains deeply intact after body retirement"
	)
	var admission: Dictionary = COMMAND._capture(lab)
	_check(
		(
			admission.get("outcome") == COMMAND.Outcome.HANDLED
			and issue.manual_qc_pending()
			and lab._play_records[0] == record
		),
		"fresh QC export admission remains ready with retained constructed record"
	)
	_check(
		(
			ClubCareer.same(season_before, SeasonSave.snapshot(_app.season))
			and FileAccess.get_sha256(SeasonSave.path) == save_before
			and not _app._result_recorded
			and not _app._result_saved
		),
		"component never scores, saves or settles the synthetic terminal match"
	)


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("HR_AC02_OWNED_CLEANUP09: " + message)
	return condition
