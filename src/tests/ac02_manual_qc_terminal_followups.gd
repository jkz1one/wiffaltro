extends "res://src/tests/ac02_manual_qc_terminal_driver.gd"
## Exactly P6 and P7. Original manual gameplay inherits the accepted P5 public keys.
## P6 alone mutates one diagnostic revision after genuine settlement, then destroys
## the refused disposable fixture. P7 has no QC fault and cancels the first actual
## ordinary AI successor through Escape, not a completed-round publication claim.
const FOLLOWUP_CASES: Array[String] = ["p6_settled_revision_refusal", "p7_clean_terminal_successor"]
const FOLLOWUP_FEEL = preload("res://src/labs/pitch_bat_lab/pitch_bat_lab_feel_support.gd")
const SUCCESSOR_SECONDS: float = 120.0
var _case: String = ""
var _followup_complete: bool = false
var _observer_capture: Dictionary = {}
var _terminal_file: Array = []
var _terminal_export_records: Array = []
var _successor: WeakRef
var _successor_viewport: WeakRef
var _teardown: Dictionary = {}


func _enter_tree() -> void:
	super._enter_tree()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--manual-qc-terminal-followup="):
			_case = argument.trim_prefix("--manual-qc-terminal-followup=")


func _ready() -> void:
	if not _require(_case in FOLLOWUP_CASES, "An exact P6 or P7 case is required."):
		return
	print(
		"SYNTHETIC_TERMINAL_FOLLOWUP: ",
		_case,
		"; NOT human, human batting contact, renderer, FPS or speedup evidence."
	)
	print("SYNTHETIC_INPUT_QC_STAGE startup timeout_seconds=", STARTUP_SECONDS)
	if not await _wait_until(func() -> bool: return _observer._ready_to_observe):
		return
	_app = _observer._app
	var lab: PitchBatLab = _app.lab
	_original_lab = weakref(lab)
	_original_match = lab._match_state
	_issue = lab._ac02_issued_owner
	_exporter = lab._record_export
	_records = lab._play_records
	if not _require(
		_observer._mode == "candidate" and _intact() and _records.is_empty(),
		"This terminal followup requires the exact empty candidate manual fixture."
	):
		return
	_note("ready")
	_start_stage("two_natural_taken_pitches", TWO_PLAY_SECONDS)
	if not await _take_until(2):
		return
	await _terminal_followup_sample()


func _terminal_followup_sample() -> void:
	if not await _wait_until(func() -> bool: return _observer._sample_complete):
		return
	if not _require(
		(
			_observer._sample.get("ok", false)
			and _observer._errors.is_empty()
			and _intact()
			and _issue.manual_qc_pending()
			and not _issue._manual_qc_terminal_attempted
		),
		"The unchanged observer must accept the initial two-play native window."
	):
		return
	_checks["two_natural_taken_pitch_window"] = _observer._sample.duplicate(true)
	# The bounded collector measures only startup and this accepted native window.
	# Finish through its existing API, never raise its cap, clear errors or restart it.
	_measured_profile = TERMINAL_PERF.finish_session()
	_measurement_finished = true
	if not _require(
		(
			_measured_profile.get("errors", ["missing"]).is_empty()
			and int(_measured_profile.get("open_scopes", -1)) == 0
			and int(_measured_profile.get("entries", 0)) > 0
			and _measured_profile.get("entries") == _measured_profile.get("completed")
		),
		"Initial measured window must finish balanced and without collector errors."
	):
		return
	if not _terminal_json("initial-measured-window-profile.json", _measured_profile):
		return
	_checks["passive_attribution_scope"] = {
		"measured": "startup_and_initial_two_natural_records",
		"finished_before_terminal_scenario": true,
		"later_counters_inactive_non_evidence": true,
		"terminal_or_round_dispatch_count_claimed": false
	}
	await _terminal_followup_branch()


func _terminal_followup_branch() -> void:
	if _case == "p6_settled_revision_refusal":
		_failed_qc_path = (
			_observer
			. _output
			. path_join("missing-qc-parent-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
			. path_join("native-terminal-records.json")
		)
		if not _require(
			(
				not DirAccess.dir_exists_absolute(_failed_qc_path.get_base_dir())
				and not FileAccess.file_exists(_failed_qc_path)
				and _exporter.path.is_empty()
			),
			"P6 needs the same absent-parent native diagnostic failure, not a season-save fault."
		):
			return
		_exporter.path = _failed_qc_path
		_note("native_missing_parent_fault_armed")
	else:
		if not _require(
			_exporter.path.is_empty(), "P7 must retain the untouched native QC destination."
		):
			return
		_note("native_clean_QC_destination_untouched")
	_start_stage("natural_manual_game", GAME_SECONDS)
	if not await _play_to_natural_terminal():
		return
	_natural_terminal_seen = true
	_terminal_presentation["natural_GAME_END"] = _terminal_presentation_snapshot()
	_note("natural_GAME_END_no_more_gameplay_input")
	if not _timely():
		return
	_start_stage("ordinary_terminal_settlement", SETTLEMENT_SECONDS)
	if not await _wait_until(
		func() -> bool: return _app._result_recorded and not _app._ac02_settlement_ticket.is_empty()
	):
		return
	await _terminal_followup_settled()


func _terminal_followup_settled() -> void:
	if not _retain_terminal_outputs() or not _genuine_settlement():
		return
	_settled_season = _app.season
	_terminal_qc = TERMINAL_CONTROLS.telemetry(_issue)
	_terminal_file = TERMINAL_CONTROLS.file_state(_exporter)
	_terminal_export_records = _record_values()
	if not _retain_export_format_bytes():
		return
	if _case == "p6_settled_revision_refusal":
		if not _require(
			(
				TERMINAL_CONTROLS.capture_failed_qc_settlement(_app).get("ok", false)
				and _issue._manual_qc_saved_revision == 0
				and _app._ac02_settled_manual_qc_close_allowed()
			),
			"P6 must begin from the genuine failed-QC settled-close exception."
		):
			return
	else:
		if not _require(
			(
				not _issue.manual_qc_pending()
				and _terminal_qc.started
				and not _terminal_qc.opted_out
				and not _terminal_qc.inflight
				and _terminal_qc.terminal_attempted
				and _terminal_qc.saved == _records.size()
				and _terminal_qc.dirty == _records.size()
				and _terminal_qc.terminal_count == _records.size()
				and _terminal_qc.terminal_revision == _records.size()
				and _payload_matches(_terminal_export_records)
			),
			"P7 native terminal QC must succeed and acknowledge the exact natural record batch."
		):
			return
		if not _retain_qc_bytes():
			return
	_checks["genuine_terminal_settlement"] = {
		"ok": true,
		"qc": _terminal_qc,
		"file": _terminal_file,
		"qc_global_path": ProjectSettings.globalize_path(_exporter.path),
		"primary_sha256": FileAccess.get_sha256(SeasonSave.path),
		"original_manual_automation_null": _app.lab._automation == null,
		"later_attribution_counters_inactive_non_evidence": true
	}
	_note("genuine_settlement_retained")
	if not _timely():
		return
	_start_stage("public_CONTINUE", CONTINUE_SECONDS)
	await _terminal_followup_exit()


func _terminal_followup_exit() -> void:
	if not await _wait_until(
		func() -> bool:
			return (
				_app._continue.is_visible_in_tree()
				and not _app._continue.disabled
				and (
					_app.lab._match_presentation_director.mode
					== MatchPresentationDirector.Mode.OUTRO_HOLD
				)
			)
	):
		return
	_terminal_presentation["public_CONTINUE_ready"] = _terminal_presentation_snapshot()
	_write_evidence()
	if _failed or not _timely():
		return
	if _case == "p6_settled_revision_refusal":
		await _settled_revision_refusal()
	else:
		await _clean_successor()


func _genuine_settlement() -> bool:
	var args: Array = _app._ac02_settlement_ticket.human
	var restored: SeasonState = SeasonSave._read(SeasonSave.path)
	return _require(
		(
			_app._ac02_settlement_owner_intact()
			and _app._ac02_resume_authorized()
			and StadiumNpcYardTwoHumanEvidence.valid(args[16])
			and ClubCareer.same(args, _app.season.physical.pending.human)
			and _app.lab == _original_lab.get_ref()
			and _app.lab._automation == null
			and _app.lab._match_state == _original_match
			and _app.lab._ac02_issued_owner == _issue
			and _issue._settlement_report.is_empty()
			and not _app._result_saved
			and restored != null
			and ClubCareer.same(SeasonSave.snapshot(restored), SeasonSave.snapshot(_app.season))
		),
		"Original natural manual terminal must have a genuine durable pending-human settlement."
	)


func _settled_revision_refusal() -> void:
	_start_stage("scripted_settled_revision_refusal", SETTLEMENT_SECONDS)
	# Existing frozen control changes only dirty revision. It performs actual close
	# refusal, then actual round.resume/save/refused-close. Never restore it afterward.
	var result: Dictionary = TERMINAL_CONTROLS.settled_round_resume_refusal(_app, "revision")
	# Retain the actual returned result before a timing failure can terminate the process.
	_checks["settled_revision_refusal"] = result
	_write_evidence()
	if _failed or not _timely():
		return
	if not _require(
		(
			result.get("ok", false)
			and _app.lab == _original_lab.get_ref()
			and is_instance_valid(_app.lab)
			and _app.lab._automation == null
			and _issue._manual_qc_dirty_revision == int(_terminal_qc.dirty) + 1
			and _issue._manual_qc_saved_revision == int(_terminal_qc.saved)
			and _records_unchanged()
			and TERMINAL_CONTROLS.file_state(_exporter) == _terminal_file
		),
		"P6 must retain the refused original, accept its ordinary checkpoint, and never advance."
	):
		return
	var restored: SeasonState = SeasonSave._read(SeasonSave.path)
	if not _require(
		(
			restored != null
			and ClubCareer.same(SeasonSave.snapshot(restored), SeasonSave.snapshot(_app.season))
		),
		"P6 accepted retry checkpoint must independently decode to live season state."
	):
		return
	if not _terminal_json("after-refusal-season-raw.json", SeasonSave.snapshot(_app.season)):
		return
	_checks["refusal_scope"] = {
		"dirty_revision_only_mutation": true,
		"natural_terminal_precondition": true,
		"scripted_close_and_resume_not_public_button": true,
		"helper_counter_equalities_are_inactive_non_evidence": true,
		"no_retry_requires_raw_warning_and_file_review": true,
		"after_qc": TERMINAL_CONTROLS.telemetry(_issue),
		"after_primary_sha256": FileAccess.get_sha256(SeasonSave.path)
	}
	_note("settled_revision_refusal_retained")
	if not _capture_observer() or not _timely():
		return
	# Destructive test teardown only. The refused close is never repaired/retried.
	_start_stage("negative_fixture_teardown", UI_SECONDS)
	FOLLOWUP_FEEL.warn_pending_manual_records(_app.lab)
	_observer.set_process(false)
	_observer.set_process_input(false)
	_app.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if not _timely():
		return
	_teardown = {
		"test_owned_disposal_not_successful_close": true,
		"original_app_freed": not is_instance_valid(_app),
		"original_lab_freed": not is_instance_valid(_original_lab.get_ref()),
		"authority_restored": false
	}
	_settled_revision_teardown()


func _settled_revision_teardown() -> void:
	if not _require(
		_teardown.original_app_freed and _teardown.original_lab_freed,
		"P6 disposable original must finish teardown without authority reconstruction."
	):
		return
	_followup_complete = true
	_write_evidence()
	if _failed or not _timely():
		return
	print("SYNTHETIC_TERMINAL_FOLLOWUP_COMPLETE: ", _case)
	get_tree().quit(0)


func _clean_successor() -> void:
	# Functional public-button activation only. No keyboard/focus UX claim.
	var button: Button = _app._continue
	if not _require(
		(
			is_instance_valid(_app)
			and _app == _observer._app
			and is_instance_valid(button)
			and button == _app._continue
			and button.get_script() == null
			and button.get_viewport() == get_viewport()
			and button.is_visible_in_tree()
			and not button.disabled
			and not _app._busy
			and _app.lab == _original_lab.get_ref()
			and not _app.lab._debug_paused
			and _app.lab._match_state == _original_match
			and _app.lab._ac02_issued_owner == _issue
			and _app._ac02_settlement_owner_intact()
			and _app._ac02_resume_authorized()
			and _original_match.phase == MatchState.Phase.GAME_END
			and (
				_app.lab._match_presentation_director.mode
				== MatchPresentationDirector.Mode.OUTRO_HOLD
			)
		),
		"P7 activation requires the exact live enabled native CONTINUE and original ready context."
	):
		return
	var connections: Array[Dictionary] = button.get_signal_connection_list("pressed")
	if not _require(
		(
			connections.size() == 1
			and connections[0].get("callable") == Callable(_app, "finish_game")
			and int(connections[0].get("flags", -1)) == 0
		),
		"P7 CONTINUE must retain its sole ordinary pressed-to-finish_game connection."
	):
		return
	_checks["public_CONTINUE_activation"] = {
		"kind": "ordinary_button_pressed_signal",
		"button_id": button.get_instance_id(),
		"button_path": String(button.get_path()),
		"app_id": _app.get_instance_id(),
		"handler": "finish_game",
		"connection_count": 1,
		"connection_flags": 0,
		"visible_enabled": true,
		"original_ready_context": true,
		"keyboard_navigation_qualified": false,
		"forced_presentation_or_authority": false,
		"usec": Time.get_ticks_usec()
	}
	_write_evidence()
	if _failed or not _timely():
		return
	button.pressed.emit()
	if not _timely():
		return
	if not await _wait_until(
		func() -> bool: return _app.lab == null and not is_instance_valid(_original_lab.get_ref())
	):
		return
	await _clean_successor_continue()


func _clean_successor_continue() -> void:
	if not _require(
		_app._ac02_settlement_ticket.is_empty() and _clean_batch_unchanged(),
		"P7 public CONTINUE must close original/ticket without changing the acknowledged batch."
	):
		return
	_note("ordinary_resume_closed_original")
	if not _timely():
		return
	_start_stage("first_legitimate_successor", SUCCESSOR_SECONDS)
	if not await _wait_until(
		func() -> bool:
			return (
				_app.round_ui._working
				and _app.round_ui.runner._running
				and is_instance_valid(_app.round_ui.runner._lab)
			)
	):
		return
	var round_ui: SeasonRoundUI = _app.round_ui
	var next_lab: PitchBatLab = round_ui.runner._lab
	var projected: SeasonState = round_ui._projection.candidate
	var fixture: Dictionary = round_ui._projection.fixture
	var expected: Dictionary = SeasonVenues.for_fixture(projected, fixture)
	if not _require(
		(
			not round_ui.process_jobs
			and not round_ui.process_runner.running
			and fixture.id == 1
			and expected.manifest.id == "AE-02"
			and is_instance_valid(round_ui.runner._viewport)
			and round_ui.runner._viewport.get_parent() == round_ui.runner
			and next_lab.get_parent() == round_ui.runner._viewport
			and next_lab._match_state != _original_match
			and next_lab != _original_lab.get_ref()
			and next_lab._automation != null
			and next_lab._automation.get_script() == MatchAutomation
			and next_lab._automation.seed == SeasonPhysicalFixtures.seed_for(projected, fixture)
			and next_lab._match_state.phase != MatchState.Phase.GAME_END
			and next_lab._npc_season == projected
			and ClubCareer.same(next_lab._match_state.stadium, expected)
			and StadiumPropertyRuntime.npc_installed_bound(next_lab, expected)
			and _app.season == _settled_season
			and not _app._result_saved
			and _app.season.physical.pending.reports.is_empty()
		),
		"P7 successor must be the ordinary actually installed first AI job, not round publication."
	):
		return
	_successor = weakref(next_lab)
	_successor_viewport = weakref(round_ui.runner._viewport)
	_checks["first_legitimate_successor"] = {
		"ok": true,
		"fixture": fixture.duplicate(true),
		"lab_id": next_lab.get_instance_id(),
		"match_id": next_lab._match_state.get_instance_id(),
		"viewport_id": round_ui.runner._viewport.get_instance_id(),
		"parentage_intact": true,
		"automation_id": next_lab._automation.get_instance_id(),
		"seed": next_lab._automation.seed,
		"stadium": expected.duplicate(true),
		"running": round_ui.runner._running,
		"installed_bound": true,
		"original_lab_closed": true,
		"original_ticket_cleared": true,
		"successor_is_AI_not_manual_coverage": true,
		"completed_round_claimed": false
	}
	_note("first_legitimate_successor_retained")
	if not _timely():
		return
	_start_stage("public_cancel_successor", UI_SECONDS)
	await _clean_successor_overlay(round_ui)


func _clean_successor_overlay(round_ui: SeasonRoundUI) -> void:
	if not _require(
		round_ui.shade.is_visible_in_tree(), "Public Escape requires the real round overlay."
	):
		return
	if not await _key(KEY_ESCAPE, get_viewport()):
		return
	if not await _wait_until(
		func() -> bool:
			return (
				not _app.round_ui._working
				and not _app.round_ui.runner._running
				and _app.round_ui.runner._lab == null
				and _app.round_ui.runner._viewport == null
				and not is_instance_valid(_successor.get_ref())
				and not is_instance_valid(_successor_viewport.get_ref())
			)
	):
		return
	if not _timely():
		return
	_start_stage("post_cancel_settlement_readback", SETTLEMENT_SECONDS)
	var restored: SeasonState = SeasonSave._read(SeasonSave.path)
	if not _require(
		(
			_app.lab == null
			and not _app.round_ui.process_runner.running
			and _app._ac02_settlement_ticket.is_empty()
			and _clean_batch_unchanged()
			and _app.season == _settled_season
			and not _app._result_saved
			and _app.season.physical.pending.reports.is_empty()
			and restored != null
			and ClubCareer.same(SeasonSave.snapshot(restored), SeasonSave.snapshot(_app.season))
		),
		"Public round cancel must clean the successor while preserving the durable human checkpoint."
	):
		return
	_checks["public_successor_cancel"] = {
		"ok": true,
		"successor_freed": true,
		"old_qc": TERMINAL_CONTROLS.telemetry(_issue),
		"old_file": TERMINAL_CONTROLS.file_state(_exporter),
		"primary_sha256": FileAccess.get_sha256(SeasonSave.path),
		"round_published": false
	}
	await _clean_successor_cold_output()


func _clean_successor_cold_output() -> void:
	if not _terminal_json("paused-successor-season-raw.json", SeasonSave.snapshot(_app.season)):
		return
	_note("public_successor_cancelled")
	if not _capture_observer() or not _timely():
		return
	_native_route_complete = true
	_start_stage("native_F10_evidence_exit", UI_SECONDS)
	if not await _key(KEY_F10, get_viewport()):
		return
	var summary: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(_observer._output.path_join("manual-summary.json"))
	)
	if not _require(
		(
			summary is Dictionary
			and summary.get("sample", {}).get("ok", false)
			and summary.get("errors", ["missing"]).is_empty()
			and summary.get("natural_game_end_seen", false)
			and _inactive_counters_intact(summary.get("profile", {}))
		),
		"P7 unchanged observer summary must close cleanly."
	):
		return
	_observer_summary_written = true
	_followup_complete = true
	_write_evidence()
	if _failed or not _timely():
		return
	print("SYNTHETIC_TERMINAL_FOLLOWUP_COMPLETE: ", _case)


func _records_unchanged() -> bool:
	if _records.size() != _terminal_records.size():
		return false
	for index: int in range(_records.size()):
		if (
			_records[index].get_instance_id() != _terminal_record_ids[index]
			or _records[index].to_dict() != _terminal_records[index]
		):
			return false
	return true


func _clean_batch_unchanged() -> bool:
	var now: Dictionary = TERMINAL_CONTROLS.telemetry(_issue)
	for key: String in [
		"started",
		"opted_out",
		"dirty",
		"saved",
		"pending",
		"inflight",
		"terminal_attempted",
		"terminal_count",
		"terminal_revision",
		"count"
	]:
		if now.get(key) != _terminal_qc.get(key):
			return false
	return (
		_records_unchanged()
		and TERMINAL_CONTROLS.file_state(_exporter) == _terminal_file
		and _payload_matches(_terminal_export_records)
		and not FileAccess.file_exists(_exporter.path + ".tmp")
	)


# Match the literal native QC/stdout JSON format without a parse/re-serialize roundtrip.
func _retain_export_format_bytes() -> bool:
	var path: String = _observer._output.path_join("terminal-native-records-export-format.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failed = true
		_failure = "Cannot retain terminal evidence: " + path
		push_error(_failure)
		get_tree().quit(2)
		return false
	file.store_string(JSON.stringify(_terminal_records, "\t", true) + "\n")
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	if not ok:
		_failed = true
		_failure = "Terminal evidence write failed: " + path
		push_error(_failure)
		get_tree().quit(2)
	return ok


func _retain_qc_bytes() -> bool:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_exporter.path)
	var path: String = _observer._output.path_join("terminal-qc-written.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not _require(file != null and not bytes.is_empty(), "P7 actual QC file must be retained."):
		return false
	file.store_buffer(bytes)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return _require(
		(
			ok
			and FileAccess.get_file_as_bytes(path) == bytes
			and FileAccess.get_file_as_bytes(_exporter.path) == bytes
		),
		"P7 QC copy must be byte exact."
	)


func _capture_observer() -> bool:
	_observer_capture = {
		"pid": OS.get_process_id(),
		"user_data_dir": OS.get_user_data_dir(),
		"sample": _observer._sample.duplicate(true),
		"errors": _observer._errors.duplicate(),
		"natural_game_end_seen": _observer._terminal_seen,
		"input_event_observations": _observer._input_events.duplicate(true),
		"profile": TERMINAL_PERF.snapshot()
	}
	return _require(
		(
			_observer_capture.errors.is_empty()
			and _observer_capture.natural_game_end_seen
			and _inactive_counters_intact(_observer_capture.profile)
		),
		"Observer capture must precede teardown and remain balanced."
	)


func _write_evidence() -> void:
	if not is_instance_valid(_observer) or _observer._output.is_empty():
		return
	_terminal_json(
		"synthetic-terminal-followup.json",
		{
			"schema": "AC02-SYNTHETIC-TERMINAL-FOLLOWUP-v1",
			"case": _case,
			"pid": OS.get_process_id(),
			"mode": _observer._mode,
			"manifest_sha256_supplied_by_external_gate": _observer._manifest,
			"current_stage": _stage,
			"failed": _failed,
			"failure": _failure,
			"overall_seconds": TERMINAL_OVERALL_SECONDS,
			"checks": _checks,
			"stages": _stages,
			"paired_input_events": _events,
			"native_meter_releases": _meter_releases,
			"terminal_presentation_observations": _terminal_presentation,
			"observer_capture_before_teardown": _observer_capture,
			"teardown": _teardown,
			"measurement_finished_after_initial_window": _measurement_finished,
			"later_attribution_counters_inactive_non_evidence": _measurement_finished,
			"natural_GAME_END_observed": _natural_terminal_seen,
			"followup_complete": _followup_complete,
			"native_route_complete": _native_route_complete,
			"observer_summary_written": _observer_summary_written,
			"completed_AI_games": 0,
			"completed_round_claimed": false,
			"physical_human_witness": false,
			"human_batting_contact_coverage": false,
			"renderer_or_FPS_evidence": false,
			"performance_speedup_claimed": false
		}
	)
