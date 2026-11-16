extends "res://src/tests/ac02_manual_qc_command_cases_fixture_base.gd"
func _write_flush() -> void:
	if OS.get_name() != "Linux" or OS.get_environment("AC02_FAULT_FIXTURE") != "write_flush":
		_fault_fail("Reviewed child-only write-limit runner opt-in is required.")
		return
	# Baseline is genuinely saved before any limit, followed by ordinary component
	# completions. No custom serializer, artificial large field, or ACTIVE owner.
	if (
		not _row(
			"write_fault_baseline_saved", CC.native_boundary(_lab, true, "write_fault_baseline")
		)
		or not _seed_component_records(126)
	):
		return
	var path: String = _lab._record_export.path
	var temporary: String = path + ".tmp"
	var baseline: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var plan: Dictionary = _lab._record_export.prepare_manual_ac02_v1(
		_lab._play_records, _lab._field_definition, _lab.get_meta("stadium_snapshot", {})
	)
	var intended: PackedByteArray = str(plan.file_text).to_utf8_buffer()
	var lines: Array[String] = CC.expected_lines(_lab)
	var before: Dictionary = CC.observation(_lab)
	var original: Dictionary = _limit_read()
	var status: Dictionary = _fault_exec("/usr/bin/cat", ["/proc/%d/status" % OS.get_process_id()])
	var ignored: int = 0
	for line: String in str(status.output).split("\n"):
		if line.begins_with("SigIgn:"):
			ignored = line.trim_prefix("SigIgn:").strip_edges().hex_to_int()
	var signal_number: int = OS.get_environment("AC02_FAULT_SIGXFSZ").to_int()
	# Measure the actual log after baseline and all seeding Output. No compact QC
	# Output or result persistence occurs while the soft limit is in effect.
	var log_path: String = OS.get_user_data_dir().path_join("logs/godot.log")
	if not FileAccess.file_exists(log_path):
		_fault_fail("Actual owned engine log is required for a measured safety margin.")
		return
	var log_bytes: int = FileAccess.get_file_as_bytes(log_path).size()
	var cap: int = maxi(65536, log_bytes + 32768)
	var admission: Dictionary = Q._capture(_lab)
	if (
		original.is_empty()
		or original.soft != OS.get_environment("AC02_FAULT_FSIZE_SOFT")
		or original.hard != OS.get_environment("AC02_FAULT_FSIZE_HARD")
		or (original.soft != "unlimited" and int(original.soft) <= cap)
		or status.code != 0
		or signal_number != 25
		or (ignored & (1 << (signal_number - 1))) == 0
		or intended.size() <= cap + 8192
		or cap > 1048576
		or baseline.is_empty()
		or FileAccess.file_exists(temporary)
		or DirAccess.dir_exists_absolute(temporary)
		or admission.get("outcome") != Q.Outcome.HANDLED
	):
		_fault_fail(
			"Native payload, signal disposition, original limits, or clean temp preflight failed."
		)
		return
	_limit_fault = {
		"original": original,
		"cap": cap,
		"restored": false,
		"signal_ignored_mask": ignored,
		"signal_number": signal_number,
		"file_text_utf8_bytes": intended.size(),
		"engine_log_before_bytes": log_bytes,
		"temporary_absent_before": true,
		"native_admission": admission.outcome
	}
	var armed: Dictionary = _fault_exec(
		"/usr/bin/prlimit", ["--pid", str(OS.get_process_id()), "--fsize=%d:" % cap]
	)
	var applied: Dictionary = _limit_read()
	_limit_fault["applied"] = applied
	if armed.code != 0 or applied.get("soft") != str(cap) or applied.get("hard") != original.hard:
		_restore_limit_fault()
		_fault_fail("Temporary child soft limit did not read back exactly.")
		return
	var logger: WarningProbe = WarningProbe.new()
	OS.add_logger(logger)
	print("QC_COMMAND_WINDOW_BEGIN io_terminal_write_flush")
	var continued: bool = F.flush_pending_manual_records(_lab)
	print("QC_COMMAND_WINDOW_END io_terminal_write_flush")
	var first: Dictionary = CC.observation(_lab)
	var repeated: bool = F.flush_pending_manual_records(_lab)
	var second: Dictionary = CC.observation(_lab)
	var failed_temp: PackedByteArray = FileAccess.get_file_as_bytes(temporary)
	var committed_unchanged: bool = FileAccess.get_file_as_bytes(path) == baseline
	OS.remove_logger(logger)
	# Restore and read back BEFORE any retry, _row, profile, or evidence write.
	if not _restore_limit_fault():
		_fault_fail("Child original limits were not proven restored; no retry/evidence permitted.")
		return
	_limit_fault["engine_log_after_bytes"] = FileAccess.get_file_as_bytes(log_path).size()
	_limit_fault["failed_temp_bytes"] = failed_temp.size()
	var retained: bool = (
		continued
		and repeated
		and first.telemetry.pending
		and first.telemetry.saved == before.telemetry.saved
		and first.telemetry.dirty == before.telemetry.dirty
		and first.telemetry.terminal_attempted
		and not first.telemetry.inflight
		and second == first
		and first.metadata == before.metadata
		and first.file == before.file
		and committed_unchanged
		and first.status == before.status
		and first.guards - before.guards == 1
		and first.deep - before.deep == 1
		and logger.calls == 1
		and failed_temp.size() == cap
		and int(_limit_fault.engine_log_after_bytes) < cap
	)
	print("QC_COMMAND_WINDOW_BEGIN io_retry_write_flush")
	F.dump_records(_lab)
	print("QC_COMMAND_WINDOW_END io_retry_write_flush")
	var after: Dictionary = CC.observation(_lab)
	_row(
		"native_write_flush_retains_pending_and_retries",
		{
			"ok":
			(
				retained
				and C.active_manual(_lab)
				and after.telemetry.saved == before.telemetry.dirty
				and not after.telemetry.pending
				and not after.telemetry.inflight
				and after.telemetry.terminal_attempted
				and after.guards - second.guards == 1
				and after.deep - second.deep == 1
				and after.metadata == before.metadata
				and FileAccess.get_file_as_bytes(path) == intended
				and not FileAccess.file_exists(temporary)
				and C.saved_records_match(_lab)
			),
			"retained_pending_and_baseline": retained,
			"warning_calls": logger.calls,
			"warning_messages": logger.messages,
			"full_audit_calls": first.guards - before.guards,
			"latch_repeat_unchanged": second == first,
			"native_temp_bytes": failed_temp.size(),
			"committed_final_unchanged": committed_unchanged,
			"write_and_flush_separate_fault_claimed": false,
			"output_windows":
			[
				{"label": "io_terminal_write_flush", "lines": []},
				{"label": "io_retry_write_flush", "lines": lines}
			]
		}
	)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--manual-qc-command="):
			_case = argument.trim_prefix("--manual-qc-command=")
		elif argument.begins_with("--manual-qc-output="):
			_output = argument.trim_prefix("--manual-qc-output=")
		elif argument.begins_with("--manual-qc-data-root="):
			_data_root = argument.trim_prefix("--manual-qc-data-root=")
		elif argument.begins_with("--manual-qc-manifest="):
			_manifest = argument.trim_prefix("--manual-qc-manifest=")
	if not _need(
		(
			_case in COMMAND_CASES
			and _manifest.length() == 64
			and _output.is_absolute_path()
			and _data_root.is_absolute_path()
			and OS.get_cmdline_user_args().has("--physical-in-process")
			and OS.get_user_data_dir().begins_with(_data_root.trim_suffix("/") + "/")
		),
		"Select one reviewed command case, exact manifest and isolated data/evidence paths."
	):
		get_tree().quit(2)
		return
	if not _need(
		(
			DirAccess.make_dir_recursive_absolute(_output) == OK
			and DirAccess.get_files_at(_output).is_empty()
			and DirAccess.get_directories_at(_output).is_empty()
		),
		"Fresh empty evidence directory required."
	):
		get_tree().quit(2)
		return
	if not _need(
		(
			Engine.physics_ticks_per_second == 60
			and Engine.time_scale == 1.0
			and not get_tree().paused
		),
		"Ordinary fixed60 clock required."
	):
		get_tree().quit(2)
		return
	SeasonSave.path = _output.path_join("component-season.json")
	PitchBatLabSettings.path = _output.path_join("component-settings.cfg")
	var prepared: SeasonState = FIXTURE.season()
	if not _need(
		prepared != null and SeasonSave.save(prepared) and PERF.begin_session(_output),
		"Existing fixture and passive collector setup failed."
	):
		get_tree().quit(2)
		return
	_trace_open = true
	await get_tree().process_frame
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	_app.play_season_game()
	_lab = _app.lab
	if not _need(
		(
			C.active_manual(_lab)
			and _lab._managed_match
			and not _lab._player_home
			and _lab._play_records.is_empty()
			and _lab._active_play_record == null
			and _lab._record_export.get_script() == PlayRecordExport
			and ClubCareer.same(_app.season.pending_fixture(), FIXTURE.fixture(_app.season))
		),
		"Public Play must create original empty ACTIVE manual fixture."
	):
		await _finish()
		return
	_issue = _lab._ac02_issued_owner
	_season_snapshot = SeasonSave.snapshot(_app.season)
	_season_sha = FileAccess.get_sha256(SeasonSave.path)
	_lab._record_export.path = _output.path_join("fixed-session.json")
	_lab._record_export._revision = "qc-command-v1-fixed-revision"
	_lab._record_export._source_dirty = false
	print("QC_COMMAND_BEGIN ", _case)
	if not _row("fresh_no_pending_zero_audits", C.no_pending_terminal_control(_lab)):
		await _finish()
		return
	if _case == "native":
		if (
			_row("empty_F3_one_audit", CC.native_boundary(_lab, true, "empty_F3"))
			and _seed_component_records(2)
			and _row("pending_F3_one_audit", CC.native_boundary(_lab, true, "pending_F3"))
			and _row("saved_no_pending_zero_audits", C.no_pending_terminal_control(_lab))
			and _seed_component_records(1)
			and _row(
				"pending_terminal_one_audit", CC.native_boundary(_lab, false, "pending_terminal")
			)
		):
			_row("terminal_clean_zero_audits", C.no_pending_terminal_control(_lab))
	elif _seed_component_records(2):
		match _case:
			"drift":
				_drifts()
			"geometry":
				_row("invalid_geometry_no_publication", CC.geometry_refusal(_lab))
			"revoke":
				_row("supported_writer_no_revival", CC.supported_revoke(_lab))
			"io_mkdir", "io_open", "io_rename":
				_io()
			"opaque":
				_opaque()
			"exporter":
				_exporter()
			"reentry", "f3_drift", "terminal_drift":
				_callbacks()
			"warning_callbacks":
				_warning_callbacks()
			"io_write_flush":
				_write_flush()
			"timing":
				_timing()
	await _finish()


func _record_callback() -> void:
	_callback_events.append("record.to_dict")


func _exporter_callback() -> void:
	_callback_events.append("exporter.save")


func _warning_reenter() -> void:
	_warning_guard_held = _issue._manual_qc_flushing
	var before: Dictionary = CC.observation(_lab)
	F.dump_records(_lab)
	_warning_reentry_outcome = Q.run(_lab, true)
	_warning_reentry_unchanged = CC.observation(_lab) == before and _issue._manual_qc_flushing


func _warning_retire() -> void:
	_warning_retire_guard_held = _issue._manual_qc_flushing
	var property: StadiumNpcPublicProperty = CC.R._property(_lab)
	property.retire_installation("manual QC actual warning callback control")


func _elapsed_ok() -> bool:
	# 55+ second genuine startup plus 5-7 second audits. This is cooperative only;
	# parent metadata must supply an exact-child 360-second external timeout.
	if Time.get_ticks_msec() - _started > 300000:
		_failed = true
		_failure = "Command component cooperative 300-second budget exceeded."
	return not _failed
