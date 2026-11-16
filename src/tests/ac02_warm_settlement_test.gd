extends "res://src/tests/ac02_warm_settlement_test_fixture_base.gd"
func _run() -> void:
	if not _check(
		(
			_output.is_absolute_path()
			and not _output.is_empty()
			and DirAccess.make_dir_recursive_absolute(_output) == OK
			and DirAccess.get_files_at(_output).is_empty()
			and DirAccess.get_directories_at(_output).is_empty()
		),
		"fresh isolated output"
	):
		return
	_admitted = true
	SeasonSave.path = _output.path_join("public-season.json")
	PitchBatLabSettings.path = _output.path_join("public-settings.cfg")
	if not _check(
		(
			Engine.physics_ticks_per_second == 60
			and Engine.time_scale == 1.0
			and not get_tree().paused
		),
		"ordinary unpaused fixed60 clock"
	):
		return
	# Test setup uses the same real allocator and draft helper as the installed-slice proofs.
	# Save first; SeasonApp's ordinary loader and managed away entry consume the fixture.
	var prepared: SeasonState = FIXTURE.season()
	if not _check(
		(
			prepared != null
			and _assignment(prepared)
			and prepared.results.is_empty()
			and prepared.player_results.is_empty()
			and prepared.physical.pending.is_empty()
			and prepared.physical.reports.is_empty()
		),
		"fixed Base ordinal0 seed6 actual five-host assignment and genuine completed draft"
	):
		return
	_assignment_verified = true
	var initial: Dictionary = SeasonSave.snapshot(prepared)
	if not _check(
		initial.get("version") == 61 and SeasonSave.save(prepared),
		"real drafted AC02 fixture saved through save61 before ordinary app restore"
	):
		return
	await get_tree().process_frame
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	await get_tree().process_frame
	await _warm_pending_fixture_checks(initial)


func _warm_pending_fixture_checks(initial: Dictionary) -> void:
	var restored: SeasonState = SeasonSave.restore()
	if not _warm_initial_restore_checks(initial, restored):
		return
	var fixture: Dictionary = _app.season.pending_fixture()
	if not _warm_managed_fixture_entry_checks(fixture):
		return
	var lab: PitchBatLab = _app.lab
	var state: MatchState = lab._match_state
	if not _warm_initial_issue_capture_checks(lab):
		return
	var live: WeakRef = weakref(lab)
	if not await _warm_await_managed_game_end(lab, state):
		return
	if not _check(
		(
			state.phase == MatchState.Phase.GAME_END
			and _app._result_recorded
			and not _app.season.physical.pending.is_empty()
		),
		"natural game end reaches ordinary durable pending branch"
	):
		return
	if not _warm_retain_terminal_evidence(lab, state, fixture):
		return
	restored = SeasonSave.restore()
	await _warm_cold_pending_replay_checks(restored, live)


func _warm_cold_pending_replay_checks(restored: SeasonState, live: WeakRef) -> void:
	if not _check(
		restored != null and ClubCareer.same(_pending, SeasonSave.snapshot(restored)),
		"actual completed pending state survives exact saved replay"
	):
		return
	var forged: Dictionary = _pending.duplicate(true)
	forged.physical.pending.human[16].clear()
	_check(
		SeasonSave._decode(forged) == null,
		"stripped completed human venue evidence refuses pending replay"
	)
	await _warm_tail(live)


func _ready() -> void:
	_started = Time.get_ticks_usec()
	var expected: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--ac02-public-dir="):
			_output = argument.trim_prefix("--ac02-public-dir=")
		elif argument.begins_with("--ac02-public-runtime="):
			expected = argument.trim_prefix("--ac02-public-runtime=")
		elif argument.begins_with("--ac02-public-execution="):
			_execution = argument.trim_prefix("--ac02-public-execution=")
		elif argument.begins_with("--ac02-public-nonce="):
			_nonce = argument.trim_prefix("--ac02-public-nonce=")
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if _check(
		(
			args.size() == 5
			and args.has("--physical-in-process")
			and _runtime.length() == 64
			and _runtime == expected
			and _execution.length() == 64
			and _nonce.length() == 32
		),
		"fixed source/run arguments and in-process round jobs"
	):
		await _run()
	if _admitted:
		_write(
			"warm-precleanup.json",
			{
				"checks": _checks,
				"failures": _failures,
				"failed": _failed,
				"io_failed": _io_failed,
				"terminal": _terminal,
				"pending": _pending,
				"queue": _warm_queue,
				"resume": _warm_resume,
				"cleanup": _warm_cleanup,
				"probes": _warm_probes
			}
		)
	if is_instance_valid(_app):
		_app.round_ui.cancel()
		_app._close_match()
		_app.queue_free()
	if is_instance_valid(_adopt_holder):
		_adopt_holder.free()
	var profile: Dictionary = TRACE.finish_session() if _trace_started else {}
	await TestAudioDrain.finish(get_tree())
	_write(
		"warm-summary.json",
		{
			"schema": "AC02-WARM-SETTLEMENT-v1",
			"pid": OS.get_process_id(),
			"runtime": _runtime,
			"execution": _execution,
			"nonce": _nonce,
			"checks": _checks,
			"failures": _failures,
			"failed": _failed,
			"io_failed": _io_failed,
			"human_starts": _human_starts,
			"ai_reports": _ai_reports.size(),
			"probes": _warm_probes,
			"initial": _warm_initial,
			"queue": _warm_queue,
			"resume": _warm_resume,
			"cleanup": _warm_cleanup,
			"terminal": _terminal,
			"profile": profile,
			"warm_qualified": _warm_complete and _failures == 0 and not _io_failed,
			"full_round_qualified": false,
			"manual_input_qualified": false,
			"performance_qualified": false,
			"in_call_swap_qualified": false,
			"backup_failure_qualified": false,
			"wall_seconds": (Time.get_ticks_usec() - _started) / 1000000.0
		}
	)
	print(
		(
			"AC02_WARM_SETTLEMENT checks=%d failures=%d human=%d ai=%d source=%s"
			% [_checks, _failures, _human_starts, _ai_reports.size(), _runtime]
		)
	)
	get_tree().quit(0 if _warm_complete and _failures == 0 and not _io_failed else 1)




func _warm_initial_restore_checks(initial: Dictionary, restored: SeasonState) -> bool:
	if not _check(
		(
			_app.season != null
			and restored != null
			and ClubCareer.same(initial, SeasonSave.snapshot(_app.season))
			and ClubCareer.same(initial, SeasonSave.snapshot(restored))
		),
		"ordinary app and save61 restore exact assignment and genuine drafted season"
	):
		return false
	if not _write("ac02-public-initial-save.json", SeasonSave.snapshot(_app.season)):
		return false
	return true


func _warm_managed_fixture_entry_checks(fixture: Dictionary) -> bool:
	if not _check(
		(
			ClubCareer.same(fixture, {"id": 0, "round": 0, "away": 0, "home": 5})
			and ClubCareer.same(fixture, FIXTURE.fixture(_app.season))
			and SeasonState.field_for_fixture(fixture, _app.season).id == &"field.npc_venue"
		),
		"real opening schedule selects AC02r1 without edited fixture or history"
	):
		return false
	for fixture_id: int in range(3):
		var scheduled: Dictionary = SeasonVenues.fixture_for_id(_app.season, fixture_id)
		if not _check(
			_binding(SeasonVenues.for_fixture(_app.season, scheduled), _app.season, fixture_id),
			"opening fixture%d binds exact saved owner and day environment" % fixture_id
		):
			return false
	var assignment: String = SeasonVenues.key(_app.season.npc_venues)
	var home: String = StadiumLayoutSnapshot.key(_app.season.home_property)
	var ledger: Dictionary = ClubPlayers.assets(_app.season.career).to_data()
	_app.child_entered_tree.connect(_configure_automation)
	_app.round_ui.runner.failed.connect(func(reason: String) -> void: _round_error = reason)
	_app.round_ui.runner.finished.connect(
		func(report: Dictionary) -> void:
			_ai_reports.append(report.duplicate(true))
			if not _write("ac02-public-ai-%d.json" % (_ai_reports.size() - 1), report):
				_io_failed = true
	)
	_app.play_season_game()
	if not _check(
		(
			_app.lab != null
			and _automation_ready
			and _human_starts == 1
			and _app.lab._managed_match
			and not _app.lab._player_home
			and _app.lab._npc_season == _app.season
			and StadiumNpcSnapshot.matches_fixture(
				_app.lab._match_state.stadium, _app.season, fixture
			)
			and StadiumNpcPublicRuntime.installed_bound(_app.lab, _app.lab._match_state.stadium)
		),
		"real managed away entry installs bound AC02r1 before ordinary inputs"
	):
		return false
	if not _copy_pregame_durable():
		return false
	return true


func _warm_initial_issue_capture_checks(lab: PitchBatLab) -> bool:
	var initial_issue: Dictionary = _issued_observation(lab)
	if not _write("ac02-public-issued-start.json", initial_issue):
		return false
	if not _check(
		initial_issue.get("active", false), "actual AC02 begins with issued ACTIVE ownership"
	):
		return false
	_initial_issue_id = int(initial_issue.instance_id)
	if not _capture_warm_initial(lab):
		return false
	return true


func _warm_await_managed_game_end(lab: PitchBatLab, state: MatchState) -> bool:
	var last_progress: String = ""
	var stalled: int = 0
	var logged: int = -1
	for frame: int in range(MAX_MATCH_FRAMES):
		if _io_failed:
			return false
		if not is_instance_valid(lab):
			_check(false, "managed public game interrupted before natural completion")
			return false
		# Settlement intentionally revokes before pending is durable. Once that
		# terminal boundary exists, validate its exact retained ticket below instead
		# of requiring the completed lab to retain live gameplay authority.
		if (
			state.phase == MatchState.Phase.GAME_END
			and _app._result_recorded
			and not _app.season.physical.pending.is_empty()
		):
			break
		if lab.has_meta("stadium_npc_runtime_interrupted") or lab._automation == null:
			_check(false, "managed public game interrupted before natural completion")
			return false
		var progress: String = (
			"%d:%d:%d" % [state.phase, state.plate_appearance_number, lab._throw_number]
		)
		stalled = stalled + 1 if progress == last_progress else 0
		last_progress = progress
		if stalled > 1800 or state.elapsed_seconds >= PhysicalMatchRunner.MAX_SECONDS:
			_check(false, "ordinary managed game exceeded existing progress/time bounds")
			return false
		if lab._automation.releases.size() % 25 == 0 and logged != lab._automation.releases.size():
			logged = lab._automation.releases.size()
			print(
				"AC02_PUBLIC_PROGRESS stage=human releases=",
				logged,
				" inning=",
				state.inning,
				" away=",
				state.away_team.runs,
				" home=",
				state.home_team.runs,
				" sim=",
				state.elapsed_seconds
			)
		await get_tree().physics_frame
	return true


func _warm_retain_terminal_evidence(
	lab: PitchBatLab, state: MatchState, fixture: Dictionary
) -> bool:
	_pending = SeasonSave.snapshot(_app.season)
	if not _warm_write_pending_checkpoint():
		return false
	var retained: Dictionary = _retain_settlement_outputs(lab, fixture)
	if retained.is_empty():
		return false
	# Same original terminal predicates, applied to actual pre-revocation outputs.
	# Never recapture through a revoked issuer or use retained data as live authority.
	var terminal_checks: Dictionary = RETAINED_CHECKS.terminal(
		_app.season, retained.human, retained.report
	)
	for error: String in terminal_checks.errors:
		_check(false, error)
	if not _check(terminal_checks.errors.is_empty(), "focused actual terminal report negatives"):
		return false
	var report: Dictionary = terminal_checks.report
	var human: Dictionary = terminal_checks.human
	if not _check(
		(
			report.get("version") == 17
			and PhysicalMatchReport.valid(report)
			and _report_bound(report, _app.season, 0)
			and not human.is_empty()
			and _app.season.physical.pending.human.size() == 17
			and ClubCareer.same(human, _app.season.physical.pending.human[16])
		),
		"actual terminal report17 and human evidence bind same saved fixture"
	):
		return false
	_family_ids.append(report.property.manifest.id)
	_terminal = {
		"away": state.away_team.runs,
		"home": state.home_team.runs,
		"inning": state.inning,
		"top_half": state.top_half,
		"releases": report.releases.size(),
		"plays": lab._play_records.size(),
		"simulation_seconds": state.elapsed_seconds,
		"report_version": report.version,
		"fixture_key": StadiumNpcSnapshot.key(state.stadium)
	}
	if not _warm_write_terminal_records(report, human):
		return false
	return true


func _warm_write_pending_checkpoint() -> bool:
	if not _write("ac02-public-pending.json", _pending):
		return false
	if not _copy_durable("queue"):
		return false
	return true


func _warm_write_terminal_records(report: Dictionary, human: Dictionary) -> bool:
	if not _write("ac02-public-report17.json", report):
		return false
	if not _write("ac02-public-human-evidence.json", human):
		return false
	return true
