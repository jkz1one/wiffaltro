extends Node
## Component fault fixtures only. Records are explicitly constructed, NOT natural plays.
## Uses genuine ordinary public issuance; never constructs/revives an issued owner,
## edits score/phase/result flags, or fabricates a settlement ticket/save receipt.
const FIXTURE = preload("res://src/tests/ac02_public_fixture.gd")
const C = preload("res://src/tests/ac02_manual_qc_controls.gd")
const F = preload("res://src/labs/pitch_bat_lab/pitch_bat_lab_feel_support.gd")
const PERF = preload("res://src/diagnostics/ac02_passive_attribution.gd")
const CASES: Array[String] = ["failed_terminal_retry", "cancel_reset", "revoked_close_refusal"]
const PROVENANCE: String = "genuine_issued_manual_component_with_constructed_diagnostic_records"
var _case: String = ""
var _output: String = ""
var _data_root: String = ""
var _manifest: String = ""
var _app: SeasonApp
var _lab: PitchBatLab
var _issue: StadiumNpcAc02IssuedStateV1
var _rows: Array[Dictionary] = []
var _constructed: int = 0
var _started: int = 0
var _failed: bool = false
var _failure: String = ""
var _season_snapshot: Dictionary
var _season_sha: String
var _trace_open: bool = false


func _enter_tree() -> void:
	_started = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--manual-qc-component="):
			_case = argument.trim_prefix("--manual-qc-component=")
		elif argument.begins_with("--manual-qc-output="):
			_output = argument.trim_prefix("--manual-qc-output=")
		elif argument.begins_with("--manual-qc-data-root="):
			_data_root = argument.trim_prefix("--manual-qc-data-root=")
		elif argument.begins_with("--manual-qc-manifest="):
			_manifest = argument.trim_prefix("--manual-qc-manifest=")
	if not _need(
		(
			_case in CASES
			and _manifest.length() == 64
			and _output.is_absolute_path()
			and _data_root.is_absolute_path()
			and OS.get_cmdline_user_args().has("--physical-in-process")
			and OS.get_user_data_dir().begins_with(_data_root.trim_suffix("/") + "/")
		),
		"Explicit component case, verified source identity and isolated paths are required."
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
		"Could not prepare the existing fixture using ordinary SeasonSave."
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
		"Public Play must create the genuine original empty ACTIVE manual fixture."
	):
		get_tree().quit(2)
		return
	_issue = _lab._ac02_issued_owner
	_season_snapshot = SeasonSave.snapshot(_app.season)
	_season_sha = FileAccess.get_sha256(SeasonSave.path)
	print("MANUAL_QC_COMPONENT_BEGIN: ", JSON.stringify({"case": _case, "provenance": PROVENANCE}))
	PERF.checkpoint("component_ready", _identity(), _case)
	if not _row("fresh_no_pending", C.no_pending_terminal_control(_lab)):
		await _finish()
		return
	await _active_component_records()


func _active_component_records() -> void:
	if not _seed_component_records(2):
		await _finish()
		return
	match _case:
		"failed_terminal_retry":
			if _row(
				"failed_terminal_and_explicit_scripted_F3_retry",
				C.failed_terminal_and_f3_retry(_lab, _missing_path("terminal"))
			):
				_row("clean_no_pending_after_retry", C.no_pending_terminal_control(_lab))
		"cancel_reset":
			if (
				_row("cancel_signal_control", C.cancellation_control(_app))
				and _row("managed_R_and_ordinary_reset", C.ordinary_reset_and_managed_r(_lab))
				and _row("successful_clear_rotation", C.clear_control(_lab))
				and _seed_component_records(1)
			):
				_row(
					"failed_clear_explicit_discard_rotation",
					C.clear_control(_lab, _missing_path("clear"))
				)
		"revoked_close_refusal":
			if _row("real_revoke_then_flush_refusal", C.ownership_flush_refusal(_lab, "revoked")):
				_row("close_and_leave_continuation_refused", _close_refusal())
	await _finish()


func _missing_path(label: String) -> String:
	# Missing parent stays absent; only this isolated diagnostic exporter is redirected.
	return _output.path_join("absent-" + label).path_join("records.json")


func _seed_component_records(count: int) -> bool:
	# Explicit component setup, not a gameplay event and not natural-play evidence.
	# Only construct native PlayRecord and exercise the ordinary completion boundary.
	if not _need(
		C.active_manual(_lab) and _lab._active_play_record == null,
		"Component records require the original live native owner and no gameplay record."
	):
		return false
	var before: Dictionary = C.capture(_lab)
	for index: int in range(count):
		var record: PlayRecord = PlayRecord.new()
		record.play_number = _constructed + 1
		record.mode = "manual_qc_constructed_component"
		record.inning = _lab._match_state.inning
		record.top_half = _lab._match_state.top_half
		_lab._active_play_record = record
		F.finish_record(_lab, &"component_record", 0)
		if not _need(
			(
				_lab._active_play_record == null
				and not _lab._play_records.is_empty()
				and _lab._play_records.back() == record
				and record.result == &"component_record"
				and record.runs_scored == 0
			),
			"Native component completion did not preserve the constructed record."
		):
			return false
		_constructed += 1
	var after: Dictionary = C.telemetry(_issue)
	return _row(
		"constructed_native_records_%d" % _constructed,
		{
			"ok":
			(
				C.active_manual(_lab)
				and C.same_session(_lab, before)
				and _lab._play_records.size() == int(before.count) + count
				and after.pending
				and not after.opted_out
				and after.dirty == int(before.telemetry.dirty) + count
				and C.file_state(before.exporter) == before.file
				and C.calls(C.DEEP_LABEL) == before.deep_calls
				and C.calls(C.EXPORT_GUARD_LABEL) == before.guard_calls
			),
			"constructed_records": count,
			"natural_play_claimed": false,
			"telemetry": after
		}
	)


func _close_refusal() -> Dictionary:
	var records: Array[PlayRecord] = _lab._play_records
	var order: Array[PlayRecord] = records.duplicate()
	var match_state: MatchState = _lab._match_state
	var exporter: PlayRecordExport = _lab._record_export
	var old_file: Array = C.file_state(exporter)
	var telemetry: Dictionary = C.telemetry(_issue)
	var ledger: ClubAssetLedger = _lab._stadium_ledger
	var ticket: Dictionary = _app._ac02_settlement_ticket
	var ticket_values: Dictionary = ticket.duplicate(true)
	var menu_visible: bool = _app.menu.visible
	var notice: String = _app.notice
	var guards: int = C.calls(C.EXPORT_GUARD_LABEL)
	var deep: int = C.calls(C.DEEP_LABEL)
	var first: bool = _app._close_match()
	var second: bool = _app._close_match()
	_app.leave_game()
	var retained: bool = (
		is_instance_valid(_lab)
		and _app.lab == _lab
		and not _lab.is_queued_for_deletion()
		and _lab.get_parent() == _app
		and _lab._match_state == match_state
		and _lab._ac02_issued_owner == _issue
		and _lab._automation == null
		and _lab._record_export == exporter
		and is_same(_lab._play_records, records)
		and records == order
		and _lab._stadium_ledger == ledger
		and is_same(_app._ac02_settlement_ticket, ticket)
		and ticket == ticket_values
		and C.telemetry(_issue) == telemetry
		and C.file_state(exporter) == old_file
		and _app.menu.visible == menu_visible
		and _app.notice == notice
		and C.calls(C.EXPORT_GUARD_LABEL) == guards
		and C.calls(C.DEEP_LABEL) == deep
	)
	return {
		"ok": not first and not second and retained,
		"repeated_close_refused_without_IO_or_disposal": not first and not second and retained,
		"leave_game_stopped_before_menu_transition": retained,
		"settled_round_resume_guard_covered": false,
		"negative_context_discard_only_no_authority_revival": true
	}


func _identity() -> Dictionary:
	return {
		"lab_id": _lab.get_instance_id(),
		"issue_id": _issue.get_instance_id(),
		"match_id": _lab._match_state.get_instance_id(),
		"automation_null": _lab._automation == null,
		"telemetry": C.telemetry(_issue),
		"case": _case,
		"constructed_records": _constructed
	}


func _row(label: String, result: Dictionary) -> bool:
	_rows.append({"label": label, "result": result})
	print("MANUAL_QC_COMPONENT_ROW: ", JSON.stringify(_rows.back()))
	return _need(result.get("ok", false), "Component assertion failed: " + label)


func _need(condition: bool, message: String) -> bool:
	if not condition and not _failed:
		_failed = true
		_failure = message
		push_error("MANUAL_QC_COMPONENT_FAILED: " + message)
	return condition and _elapsed_ok()


func _elapsed_ok() -> bool:
	if Time.get_ticks_msec() - _started > 180000:
		_failed = true
		_failure = ("Component cooperative 180-second bound exceeded; external exact-child " + \
			"timeout is still required.")
	return not _failed


func _finish() -> void:
	# Every case uses a fresh process. A corrupt/revoked context is never reused.
	if is_instance_valid(_app) and _issue != null:
		_need(
			(
				ClubCareer.same(SeasonSave.snapshot(_app.season), _season_snapshot)
				and FileAccess.get_sha256(SeasonSave.path) == _season_sha
			),
			"Active component case changed durable season progress."
		)
	if is_instance_valid(_app) and is_instance_valid(_app.lab):
		if _case == "revoked_close_refusal" or _failed:
			F.warn_pending_manual_records(_app.lab)
			# Test teardown only. This is NOT a successful production close.
			_app.queue_free()
		else:
			_need(_app._close_match(), "Healthy component fixture did not close normally.")
			_app.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	var profile: Dictionary = PERF.finish_session() if _trace_open else {}
	_need(
		(
			profile.get("schema") == "AC02-PASSIVE-ATTRIBUTION-v1"
			and profile.get("errors", []).is_empty()
			and profile.get("open_scopes", -1) == 0
			and profile.get("entries") == profile.get("completed")
		),
		"Passive collector did not close cleanly."
	)
	var result: Dictionary = {
		"schema": "AC02-MANUAL-QC-ACTIVE-COMPONENT-v1",
		"case": _case,
		"provenance": PROVENANCE,
		"passed": not _failed,
		"failure": _failure,
		"pid": OS.get_process_id(),
		"user_data_dir": OS.get_user_data_dir(),
		"manifest_sha256_supplied_by_external_gate": _manifest,
		"constructed_records": _constructed,
		"natural_plays_claimed": 0,
		"rows": _rows,
		"profile": profile,
		"season_primary_sha256": _season_sha,
		"physical_human_qualified": false,
		"natural_pitch_qualified": false,
		"public_F3_key_qualified": false,
		"public_cancel_click_qualified": false,
		"settled_close_qualified": false,
		"round_advance_refusal_qualified": false,
		"full_game_qualified": false,
		"renderer_FPS_speedup_qualified": false,
		"failed_fixture_teardown_is_not_successful_close":
		_case == "revoked_close_refusal" or _failed
	}
	var file: FileAccess = FileAccess.open(
		_output.path_join("active-component-result.json"), FileAccess.WRITE
	)
	if file == null:
		push_error("MANUAL_QC_COMPONENT_FAILED: evidence write failed")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(result, "\t", true, true) + "\n")
	file.close()
	print(
		"MANUAL_QC_COMPONENT_COMPLETE: ",
		JSON.stringify(
			{
				"case": _case,
				"passed": not _failed,
				"provenance": PROVENANCE,
				"constructed_records": _constructed
			}
		)
	)
	get_tree().quit(1 if _failed else 0)
