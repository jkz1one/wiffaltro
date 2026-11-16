extends Node
## SOURCE-ONLY COMBINED-CANDIDATE SYNTHETIC INPUT DRIVER. Never a human witness or GAME_END test.
## The unchanged operator observer is a child scene. Only Viewport.push_input key
## events drive gameplay and GUI; observer access is read-only, with no gameplay hook.
const PROVENANCE: String = "synthetic_input_combined_startup_qc_manual_route_taken_pitch_only"
const COMBINED_QC = preload("res://src/labs/pitch_bat_lab/ac02_manual_qc_command_v1.gd")
const OVERALL_SECONDS: float = 600.0
const STARTUP_SECONDS: float = 180.0
const TWO_PLAY_SECONDS: float = 180.0
const NEXT_PLAY_SECONDS: float = 90.0
const IO_SECONDS: float = 60.0
const UI_SECONDS: float = 20.0
const MAX_FOCUS_STEPS: int = 12
var _app: SeasonApp
var _original_lab: WeakRef
var _original_match: MatchState
var _issue: StadiumNpcAc02IssuedStateV1
var _exporter: PlayRecordExport
var _records: Array[PlayRecord] = []
var _overall_deadline: int = 0
var _stage_deadline: int = 0
var _stage: String = "startup"
var _failed: bool = false
var _failure: String = ""
var _intro_input_sent: bool = false
var _events: Array[Dictionary] = []
var _stages: Array[Dictionary] = []
var _checks: Dictionary = {}
var _native_route_complete: bool = false
var _observer_summary_written: bool = false
@onready var _observer: Variant = $Observer


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Start before the child observer enters/loads its fixture, not after its ready work.
	var started: int = Time.get_ticks_msec()
	_overall_deadline = started + int(OVERALL_SECONDS * 1000.0)
	_stage_deadline = started + int(STARTUP_SECONDS * 1000.0)


func _ready() -> void:
	print(
		"SYNTHETIC_INPUT_QC: ",
		PROVENANCE,
		"; NOT human, contact, GAME_END, renderer, FPS or speedup evidence."
	)
	print("SYNTHETIC_INPUT_QC_STAGE startup timeout_seconds=", STARTUP_SECONDS)
	if not await _wait_until(func() -> bool: return _observer._ready_to_observe):
		return
	if not _require(
		_observer._mode == "candidate" and COMBINED_QC._profile_selected(),
		"Combined candidate mode and exact selected source/runtime profile are required."
	):
		return
	_app = _observer._app
	var lab: PitchBatLab = _app.lab
	_original_lab = weakref(lab)
	_original_match = lab._match_state
	_issue = lab._ac02_issued_owner
	_exporter = lab._record_export
	_records = lab._play_records
	if not _require(
		_intact() and _records.is_empty(), "Exact empty native manual fixture required."
	):
		return
	_note("ready")

	_start_stage("two_natural_taken_pitches", TWO_PLAY_SECONDS)
	if not await _take_until(2):
		return
	await _combined_observer_sample()


func _combined_observer_sample() -> void:
	if not await _wait_until(func() -> bool: return _observer._sample_complete):
		return
	if not _require(
		_observer._sample.get("ok", false) and _observer._errors.is_empty(),
		"The unchanged observer rejected the two-play native window."
	):
		return
	_checks["two_natural_taken_pitch_window"] = _observer._sample.duplicate(true)
	_note("two_play_window")

	_start_stage("pause_for_F3", UI_SECONDS)
	if not await _key(KEY_ESCAPE, get_viewport()):
		return
	if not await _wait_until(func() -> bool: return _paused()):
		return
	await _combined_pause_focus()


func _combined_pause_focus() -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	if not _require(
		focus is Button and (focus as Button).text.begins_with("RESUME"),
		"Native pause menu did not naturally focus RESUME."
	):
		return
	var paused_count: int = _records.size()
	var first_before: Dictionary = _capture_session()
	if (
		_observer._mode == "candidate"
		and not _require(
			bool(first_before.qc.get("pending", false)), "Candidate must be dirty before first F3."
		)
	):
		return

	_start_stage("F3_pending", IO_SECONDS)
	if not await _key(KEY_F3, get_viewport()):
		return
	if not _check_f3(first_before, paused_count, "F3_pending"):
		return
	_note("F3_pending_saved")
	var second_before: Dictionary = _capture_session()
	_start_stage("F3_no_pending", IO_SECONDS)
	if not await _key(KEY_F3, get_viewport()):
		return
	if not _check_f3(second_before, paused_count, "F3_no_pending"):
		return
	_note("F3_no_pending_saved_again")

	_start_stage("resume_and_next_natural_taken_pitch", NEXT_PLAY_SECONDS)
	await _combined_resume_pitch(paused_count)


func _combined_resume_pitch(paused_count: int) -> void:
	if not await _key(KEY_ESCAPE, get_viewport()):
		return
	if not await _wait_until(func() -> bool: return _intact() and not _paused()):
		return
	if not await _take_until(paused_count + 1):
		return
	if not await _key(KEY_ESCAPE, get_viewport()):
		return
	await _combined_pause_cancel(paused_count)


func _combined_pause_cancel(paused_count: int) -> void:
	if not await _wait_until(func() -> bool: return _paused()):
		return
	var before_cancel: Dictionary = _capture_session()
	if (
		_observer._mode == "candidate"
		and not _require(
			bool(before_cancel.qc.get("pending", false)),
			"A new natural record must dirty the candidate again."
		)
	):
		return
	if not _require(
		_records.size() > paused_count, "No naturally completed post-F3 record was observed."
	):
		return
	_note("dirty_again_before_leave")

	_start_stage("native_leave_dialog_cancel", UI_SECONDS)
	if not await _open_leave_dialog():
		return
	await _combined_cancel_dialog(before_cancel)


func _combined_cancel_dialog(before_cancel: Dictionary) -> void:
	var cancel: Button = _app._dialog.get_cancel_button()
	var dialog_viewport: Viewport = cancel.get_viewport()
	if not await _navigate_to(cancel, dialog_viewport):
		return
	if not await _key(KEY_ENTER, dialog_viewport):
		return
	if not await _wait_until(func() -> bool: return not _app._dialog.visible):
		return
	var cancel_unchanged: bool = (
		_same_session(before_cancel)
		and _paused()
		and _observer._calls() == before_cancel.calls
		and _observer._file_state(_exporter) == before_cancel.file
		and _observer._telemetry(_issue) == before_cancel.qc
		and _record_values() == before_cancel.values
		and _active_record_id() == before_cancel.active_record_id
	)
	if not _require(
		cancel_unchanged,
		"Cancel changed the dirty session, records, file, telemetry or QC counters."
	):
		return
	_checks["cancel_preserved_dirty_session_file_and_counters"] = true
	_note("cancel_preserved_dirty_session")

	_start_stage("native_leave_dialog_confirm", IO_SECONDS)
	var close_before: Dictionary = _capture_session()
	var season_before: Dictionary = SeasonSave.snapshot(_app.season)
	var season_file_before: String = FileAccess.get_sha256(SeasonSave.path)
	var result_flags: Array = [_app._result_recorded, _app._result_saved]
	if not await _open_leave_dialog():
		return
	var confirm: Button = _app._dialog.get_ok_button()
	dialog_viewport = confirm.get_viewport()
	await _combined_confirm_dialog(
		dialog_viewport, close_before, season_before, season_file_before, result_flags, confirm
	)


func _combined_confirm_dialog(
	dialog_viewport: Viewport, close_before: Dictionary, season_before: Dictionary,
	season_file_before: String, result_flags: Array, confirm: Button
) -> void:
	if not await _navigate_to(confirm, dialog_viewport):
		return
	if not await _key(KEY_ENTER, dialog_viewport):
		return
	if not await _wait_until(func() -> bool: return not is_instance_valid(_app.lab)):
		return
	var final_qc: Dictionary = _observer._telemetry(_issue)
	var guards_delta: int = int(_observer._calls().guards) - int(close_before.calls.guards)
	var closed_payload_ok: bool = _payload_matches(close_before.values)
	var season_unchanged: bool = (
		ClubCareer.same(SeasonSave.snapshot(_app.season), season_before)
		and FileAccess.get_sha256(SeasonSave.path) == season_file_before
		and [_app._result_recorded, _app._result_saved] == result_flags
	)
	var mode_close_ok: bool = guards_delta == 0
	if _observer._mode == "candidate":
		mode_close_ok = (
			guards_delta == 1
			and not bool(final_qc.get("pending", true))
			and int(final_qc.get("dirty", -1)) == int(final_qc.get("saved", -2))
		)
	if not _require(
		(
			closed_payload_ok
			and season_unchanged
			and mode_close_ok
			and not get_tree().paused
			and _observer._errors.is_empty()
		),
		"Confirmed native leave failed JSON parity, mode-specific flush, season isolation or unpause."
	):
		return
	_checks["confirmed_leave"] = {
		"ordered_cumulative_JSON_parity": closed_payload_ok,
		"season_file_and_results_unchanged": season_unchanged,
		"QC_guard_delta": guards_delta,
		"mode_specific_flush_ok": mode_close_ok,
		"final_qc": final_qc,
		"export": _observer._file_state(_exporter)
	}
	_native_route_complete = true
	_note("ordinary_confirmed_close_completed")
	_write_evidence()

	# F10 goes through the unchanged observer's real input path, only after actual close.
	_start_stage("native_F10_evidence_exit", UI_SECONDS)
	if not await _key(KEY_F10, get_viewport()):
		return
	var summary_path: String = _observer._output.path_join("manual-summary.json")
	var summary: Variant = (
		JSON.parse_string(FileAccess.get_file_as_string(summary_path))
		if FileAccess.file_exists(summary_path)
		else null
	)
	_observer_summary_written = (
		summary is Dictionary
		and summary.get("sample", {}).get("ok", false)
		and summary.get("errors", ["missing"]).is_empty()
	)
	if not _require(
		_observer_summary_written,
		"F10 did not produce the unchanged observer's passing route summary."
	):
		return
	_write_evidence()
	print(
		"SYNTHETIC_INPUT_QC_COMPLETE: ",
		PROVENANCE,
		". Read both summaries and process exit; human/contact/GAME_END/FPS remain unqualified."
	)


func _live() -> PitchBatLab:
	return _app.lab if is_instance_valid(_app) else null


func _intact() -> bool:
	var lab: PitchBatLab = _live()
	return (
		is_instance_valid(lab)
		and _original_lab != null
		and lab == _original_lab.get_ref()
		and _observer._active_manual(lab)
		and lab._automation == null
		and lab._match_state == _original_match
		and lab._ac02_issued_owner == _issue
		and lab._record_export == _exporter
		and _exporter.get_script() == PlayRecordExport
		and is_same(lab._play_records, _records)
		and lab._match_state.phase != MatchState.Phase.GAME_END
	)


func _paused() -> bool:
	var lab: PitchBatLab = _live()
	return (
		_intact()
		and get_tree().paused
		and lab._debug_paused
		and lab._pause_menu != null
		and lab._pause_menu.visible
	)


func _take_until(target_count: int) -> bool:
	while not _failed and _records.size() < target_count:
		if (
			not _timely()
			or not _require(
				_intact() and not get_tree().paused,
				"Natural-pitch driving lost its original unpaused manual owner."
			)
		):
			return false
		var lab: PitchBatLab = _live()
		var director: MatchPresentationDirector = lab._match_presentation_director
		if director != null and director.mode != MatchPresentationDirector.Mode.IDLE:
			if (
				(
					director.mode
					in [
						MatchPresentationDirector.Mode.INTRO,
						MatchPresentationDirector.Mode.INTRO_SETTLE
					]
				)
				and not _intro_input_sent
			):
				_intro_input_sent = true
				if not await _key(KEY_SPACE, get_viewport()):
					return false
		elif (
			lab._awaiting_batter_confirm
			and lab._match_state.top_half != lab._player_home
			and lab._match_state.phase == MatchState.Phase.PRE_PITCH
		):
			if not await _key(KEY_SPACE, get_viewport()):
				return false
			if not _require(
				not lab._awaiting_batter_confirm,
				"Native ready input was not consumed; refusing to spam Space."
			):
				return false
		else:
			# Taking a pitch sends NOTHING. Opponent AI/cadence resolves it naturally.
			await get_tree().process_frame
		if director != null and director.mode != MatchPresentationDirector.Mode.IDLE:
			await get_tree().process_frame
	return not _failed


func _open_leave_dialog() -> bool:
	if not _require(
		_paused() and not _app._dialog.visible,
		"LEAVE GAME navigation requires the genuine paused unfinished game."
	):
		return false
	var leave: Button = _live()._pause_menu._leave_button
	if not _require(
		leave != null and leave.text == "LEAVE GAME" and not leave.disabled,
		"Native LEAVE GAME button is unavailable."
	):
		return false
	if not await _navigate_to(leave, leave.get_viewport()):
		return false
	if not await _key(KEY_ENTER, leave.get_viewport()):
		return false
	return await _wait_until(
		func() -> bool: return _app._dialog.visible and _app._dialog.gui_get_focus_owner() != null
	)


func _navigate_to(button: Button, viewport: Viewport) -> bool:
	if not _require(
		(
			is_instance_valid(button)
			and is_instance_valid(viewport)
			and button.get_viewport() == viewport
			and button.is_visible_in_tree()
			and not button.disabled
		),
		"Navigation target is not a visible enabled button in its actual viewport."
	):
		return false
	var last_focus: Control = null
	for step: int in range(MAX_FOCUS_STEPS):
		var focus: Control = viewport.gui_get_focus_owner()
		if focus == button:
			return true
		# Observe real focus; use Down only when a Tab did not advance it. Never grab_focus.
		var key: Key = KEY_DOWN if step > 0 and focus == last_focus else KEY_TAB
		last_focus = focus
		if not await _key(key, viewport):
			return false
	return _require(
		viewport.gui_get_focus_owner() == button,
		"Bounded native Tab/Down navigation did not reach the exact target button."
	)


func _key(key: Key, viewport: Viewport) -> bool:
	if (
		not _timely()
		or not _require(
			(
				is_instance_valid(viewport)
				and key in [KEY_SPACE, KEY_ESCAPE, KEY_F3, KEY_TAB, KEY_DOWN, KEY_ENTER, KEY_F10]
			),
			"Input viewport was lost or a key outside the bounded route was requested."
		)
	):
		return false
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		event.echo = false
		var focus: Control = viewport.gui_get_focus_owner()
		var row: Dictionary = {
			"stage": _stage,
			"usec": Time.get_ticks_usec(),
			"keycode": int(key),
			"key": OS.get_keycode_string(key),
			"pressed": pressed,
			"viewport_id": viewport.get_instance_id(),
			"viewport_path": String(viewport.get_path()),
			"focus_path": String(focus.get_path()) if is_instance_valid(focus) else ""
		}
		_events.append(row)
		viewport.push_input(event, true)
		row["dispatch_return_usec"] = Time.get_ticks_usec()
		await get_tree().process_frame
	# Always submit the release before checking a timeout following synchronous dispatch.
	return _timely()


func _wait_until(condition: Callable) -> bool:
	while not _failed:
		if not _timely():
			return false
		if condition.call():
			return true
		await get_tree().process_frame
	return false


func _capture_session() -> Dictionary:
	return {
		"lab": _live(),
		"match": _original_match,
		"issue": _issue,
		"exporter": _exporter,
		"records": _records,
		"count": _records.size(),
		"values": _record_values(),
		"active_record_id": _active_record_id(),
		"file": _observer._file_state(_exporter),
		"calls": _observer._calls(),
		"qc": _observer._telemetry(_issue)
	}


func _same_session(before: Dictionary) -> bool:
	return (
		_intact()
		and _live() == before.lab
		and _original_match == before.match
		and _issue == before.issue
		and _exporter == before.exporter
		and is_same(_records, before.records)
		and _records.size() == int(before.count)
	)


func _active_record_id() -> int:
	return (
		_live()._active_play_record.get_instance_id()
		if is_instance_valid(_live()) and _live()._active_play_record != null
		else 0
	)


func _record_values() -> Array:
	var values: Array = []
	for record: PlayRecord in _records:
		if not _require(
			record.get_script() == PlayRecord and record.result != &"pending",
			"Synthetic route only accepts naturally completed exact native records."
		):
			return []
		values.append(JSON.parse_string(JSON.stringify(record.to_dict())))
	return values


func _payload_matches(expected: Array) -> bool:
	if _exporter.path.is_empty() or not FileAccess.file_exists(_exporter.path):
		return false
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(_exporter.path))
	return payload is Dictionary and payload.get("records") is Array and payload.records == expected


func _check_f3(before: Dictionary, count: int, label: String) -> bool:
	var after: Dictionary = _observer._telemetry(_issue)
	var guards_delta: int = int(_observer._calls().guards) - int(before.calls.guards)
	var candidate_ok: bool = (
		not bool(after.get("pending", true))
		and int(after.get("saved", -1)) == int(after.get("dirty", -2))
	)
	var saved_status: bool = (
		_live()._status_label.text.begins_with("Saved ") if _intact() else false
	)
	var ok: bool = (
		_same_session(before)
		and _paused()
		and _records.size() == count
		and _record_values() == before.values
		and _payload_matches(before.values)
		and (guards_delta == 1 if _observer._mode == "candidate" else guards_delta >= 4)
		and saved_status
		and (candidate_ok if _observer._mode == "candidate" else true)
	)
	_checks[label] = {
		"ok": ok,
		"QC_guard_delta": guards_delta,
		"before_qc": before.qc,
		"after_qc": after,
		"file": _observer._file_state(_exporter),
		"saved_status": saved_status
	}
	return _require(
		ok, label + " did not preserve records and perform the unconditional full native save."
	)


func _start_stage(label: String, timeout_seconds: float) -> void:
	_stage = label
	_stage_deadline = mini(_overall_deadline, Time.get_ticks_msec() + int(timeout_seconds * 1000.0))
	print("SYNTHETIC_INPUT_QC_STAGE ", label, " timeout_seconds=", timeout_seconds)


func _timely() -> bool:
	if _failed:
		return false
	return _require(
		Time.get_ticks_msec() <= _stage_deadline and Time.get_ticks_msec() <= _overall_deadline,
		"Explicit stage or overall wall deadline expired at " + _stage + "."
	)


func _note(label: String) -> void:
	_stages.append(
		{"label": label, "usec": Time.get_ticks_usec(), "observation": _observer._snapshot()}
	)
	_write_evidence()


func _require(condition: bool, message: String) -> bool:
	if condition:
		return not _failed
	if not _failed:
		_failed = true
		_failure = message
		push_error("SYNTHETIC_INPUT_QC_FAILED: " + message)
		_write_evidence()
		# Failure abort is explicitly NOT a successful leave, flush or full-game result.
		get_tree().quit(2)
	return false


func _write_evidence() -> void:
	if not _observer._ready_to_observe and not _native_route_complete:
		return
	var path: String = _observer._output.path_join("synthetic-input-driver.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failed = true
		_failure = "Could not write synthetic input provenance: " + path
		push_error(_failure)
		get_tree().quit(2)
		return
	var evidence: Dictionary = {
		"schema": "AC02-SYNTHETIC-INPUT-QC-v1",
		"provenance": PROVENANCE,
		"mode": _observer._mode,
		"manifest_sha256_supplied_by_external_gate": _observer._manifest,
		"native_route_complete": _native_route_complete,
		"failed": _failed,
		"failure": _failure,
		"observer_summary_written": _observer_summary_written,
		"current_stage": _stage,
		"overall_seconds": OVERALL_SECONDS,
		"stage_deadline_msec": _stage_deadline,
		"overall_deadline_msec": _overall_deadline,
		"checks": _checks,
		"stages": _stages,
		"paired_input_events": _events,
		"physical_human_witness": false,
		"contact_coverage": false,
		"GAME_END_coverage": false,
		"renderer_or_FPS_evidence": false,
		"performance_speedup_claimed": false,
		"observer_human_witness_flags_are_unfulfilled_requirements_not_driver_claims": true
	}
	file.store_string(JSON.stringify(evidence, "\t", true, true) + "\n")
	file.close()
