extends Node
## SOURCE-ONLY P1-P4 representatives. One fresh isolated process per selected case.
## Gameplay uses paired synthetic keys and natural taken pitches, NOT human input.
## Only frozen diagnostic controls substitute a naturally pending probe or mutate
## the selected boundary. Scheduling-only component controls below temporarily set
## plain presentation fields or finally remove ownership; never manufacture a
## completion, owner, phase or settlement. No natural terminal coverage is inferred.
const C = preload("res://src/tests/ac02_manual_qc_controls.gd")
const F = preload("res://src/labs/pitch_bat_lab/pitch_bat_lab_feel_support.gd")
const PERF = preload("res://src/diagnostics/ac02_passive_attribution.gd")
const FIXTURE = preload("res://src/tests/ac02_public_fixture.gd")
const CASES: Array[String] = [
	"p1_sticky_reentry", "p2_f3_exporter", "p3_terminal_count", "p4_close_replacement"
]
const PROVENANCE: String = \
	("synthetic_paired_keys_natural_taken_pitches_with_explicit_diagnostic_s" + "ubstitution")
const OVERALL_SECONDS: float = 600.0
const PROFILE_STOP_ENTRIES: int = 1900000
var _case: String = ""
var _app: SeasonApp
var _lab: PitchBatLab
var _donor_app: SeasonApp
var _donor_lab: PitchBatLab
var _original_match: MatchState
var _issue: StadiumNpcAc02IssuedStateV1
var _exporter: PlayRecordExport
var _records: Array[PlayRecord] = []
var _probe: PlayRecord
var _probe_calls_after_completion: int = -1
var _started: int = 0
var _deadline: int = 0
var _stage: String = "startup"
var _failed: bool = false
var _failure: String = ""
var _intro_sent: bool = false
var _rows: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _completions: Array[Dictionary] = []
var _season_before: Dictionary = {}
var _season_path: String = ""
var _season_hash: String = ""
var _final_observation: Dictionary = {}
var _donor_proof: Dictionary = {}
var _scheduling_rows: Array[Dictionary] = []
var _post_missing_owner_observation: Dictionary = {}
@onready var _observer: Variant = $Observer


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started = Time.get_ticks_msec()
	_deadline = _started + 180000
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--manual-qc-mutation="):
			_case = argument.trim_prefix("--manual-qc-mutation=")


func _ready() -> void:
	await _run()
	await _finish()


func _run() -> void:
	if not _need(_case in CASES, "Select exactly one P1-P4 representative case."):
		return
	while not _observer._ready_to_observe:
		if not _timely():
			return
		await get_tree().process_frame
	if not _need(
		_observer._mode == "candidate", "Mutation cases require the bound candidate, not baseline."
	):
		return
	_app = _observer._app
	_lab = _app.lab
	if not _need(
		C.active_manual(_lab), "Unchanged observer did not install a genuine ACTIVE manual lab."
	):
		return
	_original_match = _lab._match_state
	_issue = _lab._ac02_issued_owner
	_exporter = _lab._record_export
	_records = _lab._play_records
	_season_path = SeasonSave.path
	_season_before = SeasonSave.snapshot(_app.season)
	_season_hash = FileAccess.get_sha256(_season_path)
	if not _need(_intact() and _records.is_empty(), "Original empty native session required."):
		return
	print("MANUAL_QC_MUTATION_BEGIN: ", _case, "; ", PROVENANCE)
	_start("two_natural_native_completions", 180.0)
	if not await _take_to(2):
		return
	await _mutation_observer_sample()


func _mutation_observer_sample() -> void:
	while not _observer._sample_complete:
		if not _healthy():
			return
		await get_tree().process_frame
	if not _row("unchanged_observer_two_play_window", _observer._sample.duplicate(true)):
		return
	if _case == "p1_sticky_reentry":
		await _p1()
	else:
		await _negative()


func _p1() -> void:
	_start("native_F3", 60.0)
	if not await _pause(true):
		return
	var f3_before: Dictionary = C.capture(_lab)
	if not _need(
		f3_before.ok and f3_before.telemetry.pending, "Native batch must be pending before F3."
	):
		return
	if not _schedule_native_component("native_before_F3"):
		return
	if not await _key(KEY_F3):
		return
	var f3_after: Dictionary = C.telemetry(_issue)
	if not _row(
		"native_F3_flushed_batch",
		{
			"ok":
			(
				C.same_session(_lab, f3_before)
				and not f3_after.pending
				and f3_after.dirty > 0
				and f3_after.dirty == f3_after.saved
				and C.saved_records_match(_lab)
				and _lab._status_label.text.begins_with("Saved ")
				and C.calls(C.EXPORT_GUARD_LABEL) >= int(f3_before.guard_calls) + 4
			),
			"before": f3_before.telemetry,
			"after": f3_after,
			"file": C.file_state(_exporter),
			"public_paired_F3_key": true
		}
	):
		return
	if not _schedule_native_component("native_after_F3"):
		return
	_start("naturally_pending_probe_after_F3", 90.0)
	await _mutation_pending_reentry()


func _mutation_pending_reentry() -> void:
	if not await _pause(false) or not await _pending():
		return
	var pending: Dictionary = _pending_evidence()
	var prepared: Dictionary = C.prepare_flushed_custom_failure(_lab, _missing_path())
	if not _need(
		prepared.get("ok", false),
		"Frozen flushed-custom preparation refused its natural prerequisites."
	):
		return
	_probe = prepared.custom
	_rows.append(
		{"label": "diagnostic_probe_substituted_into_naturally_pending_record", "result": pending}
	)
	var expected_count: int = _records.size() + 1
	_start("ordinary_custom_completion_and_failed_historical_save", 90.0)
	if not await _take_to(expected_count):
		return
	# Capture immediately, BEFORE any parity helper or custom serializing readback.
	_probe_calls_after_completion = int(_probe.get("serialize_calls"))
	if not _need(
		(
			_records.back() == _probe
			and _probe.result != &"pending"
			and _probe_calls_after_completion > 0
		),
		"Ordinary custom completion/historical save was not observed."
	):
		return
	_start("historical_failure_no_terminal_retry", 60.0)
	if not await _pause(true):
		return
	if not _row(
		"flushed_custom_failure_no_terminal_retry",
		C.flushed_custom_failure_no_terminal_retry(_lab, prepared)
	):
		return
	_start("later_natural_native_completion", 90.0)
	await _mutation_recursive_refusal(expected_count)


func _mutation_recursive_refusal(expected_count: int) -> void:
	if not await _pause(false) or not await _take_to(expected_count + 1):
		return
	_start("sticky_callback_and_recursive_refusal", 60.0)
	if not await _pause(true):
		return
	if not _row(
		"observe_custom_then_native",
		C.observe_custom_then_native(_lab, _probe, _probe_calls_after_completion, expected_count)
	):
		return
	if not _schedule_fallback("sticky_custom_after_later_native", "opted_out"):
		return
	if not _row("callback_reentry", C.callback_reentry(_app, _probe)):
		return
	if not _legitimate_clear():
		return
	_start("natural_native_completion_after_legitimate_clear", 90.0)
	await _mutation_missing_owner_finish()


func _mutation_missing_owner_finish() -> void:
	var guards: int = C.calls(C.EXPORT_GUARD_LABEL)
	if not await _pause(false) or not await _take_to(1):
		return
	_start("sticky_autosave_observation", 60.0)
	if not await _pause(true):
		return
	var after: Dictionary = C.telemetry(_issue)
	_row(
		"sticky_historical_native_autosave_after_clear",
		{
			"ok":
			(
				_intact()
				and _records.size() == 1
				and _records[0].get_script() == PlayRecord
				and _records[0].result != &"pending"
				and after.opted_out
				and not after.started
				and after.dirty == 0
				and after.saved == 0
				and not after.pending
				and C.saved_records_match(_lab)
				and C.calls(C.EXPORT_GUARD_LABEL) >= guards + 2
			),
			"telemetry": after,
			"file": C.file_state(_exporter),
			"no_new_batch_or_revived_eligibility": true
		}
	)


func _negative() -> void:
	_start("naturally_pending_probe", 90.0)
	if not await _pending():
		return
	var native: Dictionary = C.capture(_lab)
	var pending: Dictionary = _pending_evidence()
	if not _need(
		(
			native.ok
			and native.telemetry.started
			and native.telemetry.pending
			and not native.telemetry.terminal_attempted
		),
		"Fresh pending native lease required."
	):
		return
	var installed: Dictionary = C.install_custom_pending_record(_lab)
	if not _need(installed.get("ok", false), "Natural probe installation refused."):
		return
	_probe = installed.record
	_rows.append(
		{"label": "diagnostic_probe_substituted_into_naturally_pending_record", "result": pending}
	)
	_exporter.path = _missing_path()
	_start("ordinary_custom_completion_and_failed_historical_save", 90.0)
	if not await _take_to(int(native.count) + 1):
		return
	_probe_calls_after_completion = int(_probe.get("serialize_calls"))
	_start("freeze_natural_pending_custom_lease", 60.0)
	if not await _pause(true):
		return
	var qc: Dictionary = C.telemetry(_issue)
	if not _row(
		"natural_custom_failed_save_retained_native_pending",
		{
			"ok":
			(
				_records.back() == _probe
				and _probe.result != &"pending"
				and _lab._active_play_record == null
				and _probe_calls_after_completion > 0
				and qc.started
				and qc.pending
				and qc.opted_out
				and not qc.terminal_attempted
				and qc.dirty == native.telemetry.dirty
				and qc.saved == native.telemetry.saved
				and not FileAccess.file_exists(_missing_path())
				and not DirAccess.dir_exists_absolute(_missing_path().get_base_dir())
			),
			"serialize_calls_immediately_after_natural_completion": _probe_calls_after_completion,
			"failed_path": _missing_path(),
			"telemetry": qc,
			"historical_failure_warning_requires_log_review": true
		}
	):
		return
	# Restore only the destination. No telemetry, ownership or eligibility is reset.
	_exporter.path = str(native.file[0])
	_mutation_failed_preparation(native)


func _mutation_failed_preparation(native: Dictionary) -> void:
	if not _need(
		C.file_state(_exporter) == native.file,
		"Original file changed during failed custom preparation."
	):
		return
	if _case == "p4_close_replacement":
		_start("independent_donor_installation", 180.0)
		if not _install_donor():
			return
	_start("selected_mutation_boundary", 60.0)
	if not _healthy():
		return
	var before: Dictionary = _observe()
	var result: Dictionary = {}
	match _case:
		"p2_f3_exporter":
			result = C.callback_session_drift(_lab, _probe, "exporter")
		"p3_terminal_count":
			result = C.terminal_callback_drift_repeated_refusal(_lab, _probe, "count")
			result["appended_record_is_diagnostic_count_sentinel_not_gameplay"] = true
		"p4_close_replacement":
			result = C.close_callback_replacement(_app, _probe, _donor_lab)
	var after: Dictionary = _observe()
	_rows.append({"label": "selected_boundary_before_after", "before": before, "after": after})
	if not _row(_case, result):
		return
	if _case == "p2_f3_exporter" and not _schedule_fallback("after_exporter_drift", "exporter"):
		return
	if _case == "p3_terminal_count" and not _schedule_fallback("after_count_drift", "count"):
		return
	if _case == "p4_close_replacement":
		# Helper already checked replacement routing before restoring app.lab. Observe
		# original and donor parents/UI too, without a second destructive close attempt.
		_row(
			"both_real_labs_survive_false_close",
			{
				"ok":
				(
					_survives(_lab, _app)
					and _survives(_donor_lab, _donor_app)
					and _app.lab == _lab
					and _donor_app.lab == _donor_lab
					and before.ui == after.ui
					and before.season_sha256 == after.season_sha256
				),
				"original": _lab_state(_lab),
				"replacement": _lab_state(_donor_lab),
				"direct_close_only_not_leave_or_round_resume_caller_coverage": true,
				"routing_restoration_is_cleanup_not_new_positive_authority": true
			}
		)


func _schedule_snapshot() -> Dictionary:
	# Plain scalar/array evidence only. Never serialize the diagnostic probe again.
	var snapshot: Dictionary = _observe()
	snapshot.erase("collector_entries")
	var director: MatchPresentationDirector = _lab._match_presentation_director
	snapshot["director"] = {
		"id": director.get_instance_id(),
		"mode": director.mode,
		"elapsed": director.elapsed_seconds,
		"shot_index": director.shot_index,
		"shots": director.shot_sequence.duplicate(),
		"motions": director.motion_sequence.duplicate()
	}
	snapshot["retained_issue_qc"] = C.telemetry(_issue)
	return snapshot


func _schedule_native_component(label: String) -> bool:
	var director: MatchPresentationDirector = _lab._match_presentation_director
	if not _need(
		(
			_intact()
			and _app.get_script() == SeasonApp
			and director != null
			and director.get_script() == MatchPresentationDirector
			and _issue._manual_qc_started
			and not _issue._manual_qc_opted_out
			and director.mode == MatchPresentationDirector.Mode.IDLE
		),
		"Native scheduling component requires the genuine idle native session."
	):
		return false
	var before: Dictionary = _schedule_snapshot()
	var live_wait: bool = _app._ac02_wait_for_manual_outro()
	var prior_mode: MatchPresentationDirector.Mode = director.mode
	var prior_paused: bool = _lab._debug_paused
	# CLASSIFICATION ONLY. These exact native fields have no setter callbacks.
	# No await, input, commit, presentation advance, or return until both are restored.
	# SceneTree.paused is untouched; these are predicate operands, not a real outro.
	_lab._debug_paused = false
	var idle_unpaused_wait: bool = _app._ac02_wait_for_manual_outro()
	director.mode = MatchPresentationDirector.Mode.OUTRO_HOLD
	var hold_unpaused_wait: bool = _app._ac02_wait_for_manual_outro()
	_lab._debug_paused = true
	var hold_paused_wait: bool = _app._ac02_wait_for_manual_outro()
	director.mode = prior_mode
	_lab._debug_paused = prior_paused
	var after: Dictionary = _schedule_snapshot()
	return _schedule_row(
		label,
		{
			"ok":
			(
				live_wait
				and idle_unpaused_wait
				and not hold_unpaused_wait
				and hold_paused_wait
				and before == after
			),
			"live_should_wait": live_wait,
			"IDLE_debug_unpaused_should_wait": idle_unpaused_wait,
			"HOLD_debug_unpaused_should_wait": hold_unpaused_wait,
			"HOLD_debug_paused_should_wait": hold_paused_wait,
			"before": before,
			"after": after,
			"plain_fields_restored_before_any_await": true,
			"classification_only_not_natural_outro_or_real_pause_transition": true
		}
	)


func _schedule_fallback(label: String, exclusion: String) -> bool:
	var before: Dictionary = _schedule_snapshot()
	var selected_present: bool = _issue._manual_qc_opted_out
	if exclusion == "exporter":
		selected_present = _lab._record_export != _issue._manual_qc_exporter
	elif exclusion == "count":
		selected_present = _lab._play_records.size() != _issue._manual_qc_count
	var should_wait: bool = _app._ac02_wait_for_manual_outro()
	var after: Dictionary = _schedule_snapshot()
	return _schedule_row(
		label,
		{
			"ok":
			(
				selected_present
				and _issue._manual_qc_opted_out
				and not should_wait
				and before == after
			),
			"should_wait": should_wait,
			"selected_exclusion": exclusion,
			"selected_exclusion_present": selected_present,
			"sticky_opt_out_already_independently_sufficient": true,
			"isolated_exporter_or_count_branch_coverage": false,
			"before": before,
			"after": after,
			"false_is_not_settlement_authority": true
		}
	)


func _schedule_missing_owner_endpoint() -> void:
	# P4 only, after ALL original assertions and their final snapshot. No positive
	# reuse follows: next operations disable the observer and queue both trees free.
	var before: Dictionary = _schedule_snapshot()
	_lab._ac02_issued_owner = null
	var should_wait: bool = _app._ac02_wait_for_manual_outro()
	var after: Dictionary = _schedule_snapshot()
	var expected: Dictionary = before.duplicate(true)
	expected.original["issue_id"] = 0
	expected.original["qc"] = {}
	_post_missing_owner_observation = _observe()
	_schedule_row(
		"missing_owner_final_destructive_classification",
		{
			"ok": not should_wait and after == expected and _lab._ac02_issued_owner == null,
			"should_wait": should_wait,
			"before": before,
			"after": after,
			"owner_pointer_restored": false,
			"positive_reuse_or_commit_attempted": false,
			"donor_classification_not_tested_and_foreign_owner_not_assumed_ineligible": true
		}
	)


func _schedule_row(label: String, result: Dictionary) -> bool:
	_scheduling_rows.append({"label": label, "result": result})
	print("MANUAL_QC_SCHEDULING_ROW: ", JSON.stringify(_scheduling_rows.back()))
	return (
		_need(result.get("ok", false), "Scheduling component assertion failed: " + label)
		and _healthy()
	)


func _legitimate_clear() -> bool:
	var before: Dictionary = C.capture(_lab)
	if not _need(
		(
			before.ok
			and before.telemetry.opted_out
			and not before.telemetry.pending
			and _lab._active_play_record == null
		),
		"Clear must follow acknowledged custom/native history at an idle record boundary."
	):
		return false
	F.clear_records(_lab)
	var live: bool = is_instance_valid(_lab)
	if not _need(live, "Clear disposed the original lab."):
		return false
	var after: Dictionary = C.telemetry(_issue)
	var rotated: bool = _lab._record_export != _exporter
	_exporter = _lab._record_export
	return _row(
		"ordinary_clear_preserves_sticky_opt_out",
		{
			"ok":
			(
				rotated
				and _intact()
				and _records.is_empty()
				and _lab._active_play_record == null
				and after.opted_out
				and not after.started
				and not after.pending
				and after.dirty == 0
				and after.saved == 0
				and not after.terminal_attempted
				and C.file_state(before.exporter) == before.file
			),
			"before": before.telemetry,
			"after": after,
			"old_file": C.file_state(before.exporter),
			"new_native_exporter_id": _exporter.get_instance_id() if _exporter != null else 0,
			"ordinary_clear_not_corrupt_owner_repair": true
		}
	)


func _install_donor() -> bool:
	# Synchronous independent restore + public Play after the native sample. No
	# frame/input occurs with donor installed before the selected close boundary.
	var primary_path: String = SeasonSave.path
	var settings_path: String = PitchBatLabSettings.path
	var primary_hash: String = FileAccess.get_sha256(primary_path)
	var donor_path: String = _observer._output.path_join("donor-season.json")
	SeasonSave.path = donor_path
	PitchBatLabSettings.path = _observer._output.path_join("donor-settings.cfg")
	var prepared: SeasonState = FIXTURE.season()
	var saved: bool = prepared != null and SeasonSave.save(prepared)
	if saved:
		_donor_app = SeasonApp.new()
		get_tree().root.add_child(_donor_app)
		_donor_app.play_season_game()
		_donor_lab = _donor_app.lab
	SeasonSave.path = primary_path
	PitchBatLabSettings.path = settings_path
	var independent: bool = (
		saved and C.active_manual(_donor_lab) and _survives(_donor_lab, _donor_app)
	)
	if independent:
		independent = (
			_donor_lab != _lab
			and _donor_app != _app
			and _donor_app.season != _app.season
			and _donor_lab._match_state != _original_match
			and _donor_lab._ac02_issued_owner != _issue
			and _donor_lab._record_export != _exporter
			and not is_same(_donor_lab._play_records, _records)
			and _donor_lab._play_records.is_empty()
			and _donor_lab._active_play_record == null
			and _donor_lab._automation == null
			and _donor_lab._record_export != null
			and _donor_lab._record_export.get_script() == PlayRecordExport
			and _donor_lab._managed_match
			and not _donor_lab._player_home
			and ClubCareer.same(
				_donor_app.season.pending_fixture(), FIXTURE.fixture(_donor_app.season)
			)
		)
	_donor_proof = {
		"ok":
		(
			independent
			and SeasonSave.path == primary_path
			and FileAccess.get_sha256(primary_path) == primary_hash
		),
		"method":
		"independent FIXTURE.season -> separate SeasonSave -> second SeasonApp restore -> public Play",
		"donor_season_path": donor_path,
		"donor_season_sha256":
		FileAccess.get_sha256(donor_path) if FileAccess.file_exists(donor_path) else "",
		"primary_season_sha256_preserved": primary_hash,
		"donor": _lab_state(_donor_lab),
		"no_copied_owner_ticket_or_constructed_donor": true
	}
	return _row("independently_installed_ACTIVE_donor", _donor_proof)


func _intact() -> bool:
	return (
		is_instance_valid(_app)
		and is_instance_valid(_lab)
		and _app.lab == _lab
		and C.active_manual(_lab)
		and _lab._automation == null
		and _lab._match_state == _original_match
		and _lab._ac02_issued_owner == _issue
		and _exporter != null
		and _lab._record_export == _exporter
		and _exporter.get_script() == PlayRecordExport
		and is_same(_lab._play_records, _records)
		and _original_match.phase != MatchState.Phase.GAME_END
	)


func _take_to(target: int) -> bool:
	var initial: int = _records.size()
	if not await _drive_until(func() -> bool: return _records.size() >= target):
		return false
	for index: int in range(initial, _records.size()):
		var record: PlayRecord = _records[index]
		if not _need(
			record != null and record.result != &"pending" and _lab._active_play_record != record,
			"Observed record is not a naturally completed pitch."
		):
			return false
		_completions.append(
			{
				"stage": _stage,
				"index": index,
				"record_id": record.get_instance_id(),
				"result": String(record.result),
				"play_number": record.play_number,
				"exact_native_script": record.get_script() == PlayRecord,
				"diagnostic_probe_on_natural_play": record == _probe,
				"usec": Time.get_ticks_usec()
			}
		)
	return _need(
		_records.size() == target, "Natural record target overran before the intended boundary."
	)


func _pending() -> bool:
	if not await _drive_until(func() -> bool: return _lab._active_play_record != null):
		return false
	return _need(
		(
			_lab._active_play_record.get_script() == PlayRecord
			and _lab._active_play_record.result == &"pending"
		),
		"An exact naturally pending native record is required."
	)


func _pending_evidence() -> Dictionary:
	var record: PlayRecord = _lab._active_play_record
	return {
		"ok": true,
		"record_id": record.get_instance_id(),
		"result_before": String(record.result),
		"native_values_before_substitution": record.to_dict(),
		"completed_count_before": _records.size(),
		"substitution_is_diagnostic_only_completion_must_remain_ordinary_gameplay": true
	}


func _drive_until(condition: Callable) -> bool:
	while not _failed:
		if (
			not _healthy()
			or not _need(
				_intact() and not get_tree().paused,
				"Synthetic taken-pitch route lost its original unpaused manual session."
			)
		):
			return false
		if condition.call():
			return true
		var director: MatchPresentationDirector = _lab._match_presentation_director
		if director != null and director.mode != MatchPresentationDirector.Mode.IDLE:
			if (
				(
					director.mode
					in [
						MatchPresentationDirector.Mode.INTRO,
						MatchPresentationDirector.Mode.INTRO_SETTLE
					]
				)
				and not _intro_sent
			):
				_intro_sent = true
				if not await _key(KEY_SPACE):
					return false
			else:
				await get_tree().process_frame
		elif (
			_lab._awaiting_batter_confirm
			and _original_match.top_half != _lab._player_home
			and _original_match.phase == MatchState.Phase.PRE_PITCH
		):
			if not await _key(KEY_SPACE):
				return false
			if not _need(
				not _lab._awaiting_batter_confirm,
				"Native ready input was not consumed; no Space spam."
			):
				return false
		else:
			# Taking a pitch sends no swing/release. AI/cadence completes it naturally.
			await get_tree().process_frame
	return false


func _pause(paused: bool) -> bool:
	if not _need(_intact(), "Cannot toggle pause without the original live session."):
		return false
	if get_tree().paused != paused or _lab._debug_paused != paused:
		if not await _key(KEY_ESCAPE):
			return false
	return _need(
		(
			_intact()
			and get_tree().paused == paused
			and _lab._debug_paused == paused
			and _lab._pause_menu != null
			and _lab._pause_menu.visible == paused
		),
		"Native pause state did not match."
	)


func _key(key: Key) -> bool:
	if (
		not _healthy()
		or not _need(key in [KEY_SPACE, KEY_ESCAPE, KEY_F3], "Key outside the bounded route.")
	):
		return false
	var viewport: Viewport = get_viewport()
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		event.echo = false
		_events.append(
			{
				"stage": _stage,
				"key": OS.get_keycode_string(key),
				"pressed": pressed,
				"usec": Time.get_ticks_usec(),
				"viewport_id": viewport.get_instance_id()
			}
		)
		viewport.push_input(event, true)
		await get_tree().process_frame
	# Always release the key before evaluating a timeout caused by synchronous work.
	return _healthy()


func _missing_path() -> String:
	return _observer._output.path_join("absent-historical-parent").path_join("records.json")


func _survives(lab: Variant, app: Variant) -> bool:
	return (
		is_instance_valid(lab)
		and is_instance_valid(app)
		and not lab.is_queued_for_deletion()
		and lab.get_parent() == app
	)


func _lab_state(lab: Variant) -> Dictionary:
	if not is_instance_valid(lab):
		return {"live": false}
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	return {
		"live": true,
		"id": lab.get_instance_id(),
		"queued": lab.is_queued_for_deletion(),
		"parent_id": lab.get_parent().get_instance_id() if lab.get_parent() != null else 0,
		"automation_null": lab._automation == null,
		"issue_id": issue.get_instance_id() if issue != null else 0,
		"match_id": lab._match_state.get_instance_id() if lab._match_state != null else 0,
		"phase": lab._match_state.phase if lab._match_state != null else -1,
		"exporter_id": lab._record_export.get_instance_id() if lab._record_export != null else 0,
		"export": C.file_state(lab._record_export) if lab._record_export != null else [],
		"record_count": lab._play_records.size(),
		"active_record": lab._active_play_record != null,
		"qc": C.telemetry(issue),
		"debug_paused": lab._debug_paused
	}


func _observe() -> Dictionary:
	var ui: Dictionary = {}
	if is_instance_valid(_app):
		ui = {
			"menu_visible": _app.menu.visible if is_instance_valid(_app.menu) else null,
			"continue_visible":
			_app._continue.visible if is_instance_valid(_app._continue) else null,
			"dialog_visible": _app._dialog.visible if is_instance_valid(_app._dialog) else null,
			"notice": _app.notice,
			"result_recorded": _app._result_recorded,
			"result_saved": _app._result_saved,
			"settlement_ticket_empty": _app._ac02_settlement_ticket.is_empty()
		}
	return {
		"stage": _stage,
		"original": _lab_state(_lab),
		"donor": _lab_state(_donor_lab),
		"ui": ui,
		"tree_paused": get_tree().paused,
		"guards": C.calls(C.EXPORT_GUARD_LABEL),
		"deep": C.calls(C.DEEP_LABEL),
		"season_sha256":
		FileAccess.get_sha256(_season_path) if FileAccess.file_exists(_season_path) else "",
		"probe_serialize_calls": int(_probe.get("serialize_calls")) if _probe != null else -1,
		"collector_active": PERF._active,
		"collector_entries": PERF._entries
	}


func _start(label: String, seconds: float) -> void:
	_stage = label
	_deadline = mini(
		_started + int(OVERALL_SECONDS * 1000.0), Time.get_ticks_msec() + int(seconds * 1000.0)
	)
	print("MANUAL_QC_MUTATION_STAGE ", label, " timeout_seconds=", seconds)


func _timely() -> bool:
	return _need(
		(
			Time.get_ticks_msec() <= _deadline
			and Time.get_ticks_msec() - _started <= int(OVERALL_SECONDS * 1000.0)
		),
		"Bounded wall deadline expired: " + _stage
	)


func _healthy() -> bool:
	if not _timely():
		return false
	return _need(
		(
			PERF._active
			and PERF._errors.is_empty()
			and PERF._entries < PROFILE_STOP_ENTRIES
			and PERF._stack.is_empty()
		),
		"Collector inactive, unhealthy or nearing its unchanged 2,000,000-entry cap."
	)


func _need(condition: bool, message: String) -> bool:
	if not condition and not _failed:
		_failed = true
		_failure = message
		push_error("MANUAL_QC_MUTATION_FAILED: " + message)
	return condition and not _failed


func _row(label: String, result: Dictionary) -> bool:
	_rows.append({"label": label, "result": result})
	print("MANUAL_QC_MUTATION_ROW: ", JSON.stringify(_rows.back()))
	return (
		_need(result.get("ok", false), "Representative assertion failed: " + label) and _healthy()
	)


func _finish() -> void:
	# Capture all lifecycle/authority/UI evidence before disposal. No post-free node
	# field reads, no inferred successful close, and no continued negative gameplay.
	if is_instance_valid(_app) and _issue != null:
		_need(
			(
				SeasonSave.path == _season_path
				and ClubCareer.same(SeasonSave.snapshot(_app.season), _season_before)
				and FileAccess.get_sha256(_season_path) == _season_hash
				and not _app._result_recorded
				and not _app._result_saved
				and _app._ac02_settlement_ticket.is_empty()
			),
			"Short mutation case changed season/result/settlement progress."
		)
		_need(_observer._errors.is_empty(), "Unchanged native observer reported an error.")
		_final_observation = _observe()
		_healthy()
	if _case == "p4_close_replacement" and not _failed:
		_schedule_missing_owner_endpoint()
	_observer.set_process(false)
	_observer.set_process_input(false)
	var original_ref: WeakRef = weakref(_lab) if is_instance_valid(_lab) else null
	var donor_ref: WeakRef = weakref(_donor_lab) if is_instance_valid(_donor_lab) else null
	# Test disposal only. Do not invoke another close, flush, revoke, or pointer repair.
	if is_instance_valid(_app):
		_app.queue_free()
	if is_instance_valid(_donor_app):
		_donor_app.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	var original_gone: bool = original_ref == null or not is_instance_valid(original_ref.get_ref())
	var donor_gone: bool = donor_ref == null or not is_instance_valid(donor_ref.get_ref())
	_need(
		original_gone and donor_gone,
		"Isolated test-disposal did not retire both owned scene trees."
	)
	var profile: Dictionary = PERF.finish_session() if PERF._used else {}
	_need(
		(
			profile.get("errors", []).is_empty()
			and profile.get("open_scopes", -1) == 0
			and profile.get("entries", -1) == profile.get("completed", -2)
			and int(profile.get("entries", PERF.MAX_ENTRIES)) < PERF.MAX_ENTRIES
		),
		"Profiler completion invalid; inactive/overflow counters are never no-dispatch proof."
	)
	var result: Dictionary = {
		"schema": "AC02-MANUAL-QC-MUTATION-REPRESENTATIVE-v1",
		"case": _case,
		"passed": not _failed,
		"failure": _failure,
		"provenance": PROVENANCE,
		"pid": OS.get_process_id(),
		"user_data_dir": OS.get_user_data_dir(),
		"manifest_sha256_supplied_by_external_gate": _observer._manifest,
		"rows": _rows,
		"paired_input_events": _events,
		"natural_completion_observations": _completions,
		"scheduling_component_rows": _scheduling_rows,
		"post_missing_owner_pre_teardown_observation": _post_missing_owner_observation,
		"scheduling_controls_are_classification_only_not_terminal_runtime_coverage": true,
		"immediate_probe_serialize_calls_after_completion": _probe_calls_after_completion,
		"native_two_play_sample": _observer._sample,
		"observer_errors": _observer._errors,
		"final_pre_teardown_observation": _final_observation,
		"donor_installation": _donor_proof,
		"teardown":
		{
			"original_gone": original_gone,
			"donor_gone": donor_gone,
			"forced_test_disposal_not_successful_production_close": true
		},
		"profile": profile,
		"natural_GAME_END_settlement_or_round_resume_coverage": false,
		"physical_human_contact_renderer_FPS_or_speedup_qualified": false,
		"unselected_aliases": "NOT RUN; source reviewed only; runtime acceptance open",
		"historical_IO_warning_and_process_exit_require_external_review": true,
		"wall_msec": Time.get_ticks_msec() - _started
	}
	var output: String = _observer._output
	if output.is_empty() or not DirAccess.dir_exists_absolute(output):
		push_error("MANUAL_QC_MUTATION_FAILED: no initialized isolated evidence directory")
		get_tree().quit(2)
		return
	var file: FileAccess = FileAccess.open(
		output.path_join("manual-mutation-result.json"), FileAccess.WRITE
	)
	if file == null:
		push_error("MANUAL_QC_MUTATION_FAILED: result write failed")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(result, "\t", true, true) + "\n")
	file.close()
	print("MANUAL_QC_MUTATION_COMPLETE: ", _case, " passed=", not _failed)
	get_tree().quit(1 if _failed else 0)
