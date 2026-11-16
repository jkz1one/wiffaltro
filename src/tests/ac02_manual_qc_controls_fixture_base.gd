extends RefCounted
## SOURCE-ONLY STAGED CONTROLS, NOT AN EXECUTION RECEIPT.
## Caller supplies genuine installed owners and naturally completed records.
## No fabricated issuer, score, phase, completion or season result is created here.
const I = preload("res://src/presentation/stadium/stadium_npc_ac02_issued_state_v1.gd")
const F = preload("res://src/labs/pitch_bat_lab/pitch_bat_lab_feel_support.gd")
const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const PERF = preload("res://src/diagnostics/ac02_passive_attribution.gd")
const PROBE_RECORD = preload("res://src/tests/ac02_manual_qc_probe_record.gd")
const PROBE_EXPORTER = preload("res://src/tests/ac02_manual_qc_probe_exporter.gd")
const DEEP_LABEL: String = "stadium_npc_public_runtime._construction_same"
const EXPORT_GUARD_LABEL: String = "stadium_npc_public_runtime.installed_bound"


static func active_manual(lab: PitchBatLab) -> bool:
	# Passive identity observation, NOT an authorization or substitute for a hot/deep check.
	if not is_instance_valid(lab) or lab._automation != null or lab._match_state == null:
		return false
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	var property: StadiumNpcPublicProperty = R._property(lab)
	return (
		issue != null
		and is_instance_valid(property)
		and property.has_ac02_issue()
		and property._ac02_issue == issue
		and property._ac02_issue_pin == issue
		and issue.state == I.Lifetime.ACTIVE
		and issue.generation == 1
		and property._ac02_generation == 1
		and issue._bindings_pin.get("lab") == lab
		and issue._bindings_pin.get("match") == lab._match_state
		and issue._bindings_pin.get("automation") == null
	)


static func telemetry(issue: StadiumNpcAc02IssuedStateV1) -> Dictionary:
	if issue == null:
		return {}
	return {
		"started": issue._manual_qc_started,
		"opted_out": issue._manual_qc_opted_out,
		"dirty": issue._manual_qc_dirty_revision,
		"saved": issue._manual_qc_saved_revision,
		"pending": issue.manual_qc_pending(),
		"inflight": issue._manual_qc_flushing,
		"terminal_attempted": issue._manual_qc_terminal_attempted,
		"terminal_count": issue._manual_qc_terminal_count,
		"terminal_revision": issue._manual_qc_terminal_revision,
		"count": issue._manual_qc_count,
		"state": issue.state,
		"generation": issue.generation
	}


static func file_state(exporter: PlayRecordExport) -> Array:
	var path: String = exporter.path
	var exists: bool = not path.is_empty() and FileAccess.file_exists(path)
	return [path, exists, FileAccess.get_sha256(path) if exists else ""]


static func calls(label: String) -> int:
	var total: int = 0
	for row: Dictionary in PERF.snapshot().rows:
		if row.label == label:
			total += int(row.calls)
	return total


static func capture(lab: PitchBatLab) -> Dictionary:
	if not active_manual(lab):
		return {"ok": false, "error": "Genuine ACTIVE manual installation required."}
	return {
		"ok": true,
		"lab": lab,
		"match": lab._match_state,
		"issue": lab._ac02_issued_owner,
		"exporter": lab._record_export,
		"records": lab._play_records,
		"count": lab._play_records.size(),
		"active_record": lab._active_play_record,
		"telemetry": telemetry(lab._ac02_issued_owner),
		"file": file_state(lab._record_export),
		"deep_calls": calls(DEEP_LABEL),
		"guard_calls": calls(EXPORT_GUARD_LABEL)
	}


static func same_session(lab: PitchBatLab, before: Dictionary) -> bool:
	return (
		before.get("ok", false)
		and is_instance_valid(lab)
		and lab == before.lab
		and lab._match_state == before.match
		and lab._ac02_issued_owner == before.issue
		and lab._record_export == before.exporter
		and is_same(lab._play_records, before.records)
	)


static func saved_records_match(lab: PitchBatLab) -> bool:
	var path: String = lab._record_export.path
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if (
		not payload is Dictionary
		or not payload.get("records") is Array
		or payload.records.size() != lab._play_records.size()
	):
		return false
	for index: int in range(lab._play_records.size()):
		if (
			payload.records[index]
			!= JSON.parse_string(JSON.stringify(lab._play_records[index].to_dict()))
		):
			return false
	return true


static func finish_manual_window(
	lab: PitchBatLab, before: Dictionary, observed_records: Array[PlayRecord]
) -> Dictionary:
	# Called AFTER real inputs complete >= 2 plays. Never invokes finish_record.
	if not same_session(lab, before) or not active_manual(lab):
		return {"ok": false, "error": "Manual window lost its original ACTIVE owner."}
	var count: int = lab._play_records.size() - int(before.count)
	var ordered: bool = count >= 2 and observed_records.size() == count
	for index: int in range(count):
		var record: PlayRecord = lab._play_records[int(before.count) + index]
		ordered = (
			ordered
			and record.get_script() == PlayRecord
			and record.result != &"pending"
			and index < observed_records.size()
			and observed_records[index] == record
			and lab._active_play_record != record
		)
	var issue: StadiumNpcAc02IssuedStateV1 = before.issue
	var deep_delta: int = calls(DEEP_LABEL) - int(before.deep_calls)
	var guard_delta: int = calls(EXPORT_GUARD_LABEL) - int(before.guard_calls)
	var no_export: bool = file_state(lab._record_export) == before.file
	return {
		"ok":
		(
			ordered
			and no_export
			and deep_delta == 0
			and guard_delta == 0
			and not issue._manual_qc_opted_out
			and issue.manual_qc_pending()
			and issue._manual_qc_dirty_revision == int(before.telemetry.dirty) + count
		),
		"naturally_observed_records": count,
		"record_order_preserved": ordered,
		"no_automatic_file_change": no_export,
		"deep_comparisons": deep_delta,
		"deep_dispatches": guard_delta,
		"telemetry": telemetry(issue),
		"manual_witness_required": true,
		"timing_speedup_claimed": false
	}


static func f3_control(lab: PitchBatLab, pending_expected: bool) -> Dictionary:
	# Scripted boundary control, not the real-keypress/manual-performance acceptance sample.
	var before: Dictionary = capture(lab)
	if not before.ok or bool(before.telemetry.pending) != pending_expected:
		return {"ok": false, "error": "F3 needs the specified genuine pending state."}
	F.dump_records(lab)
	var saved: bool = (
		same_session(lab, before)
		and active_manual(lab)
		and not lab._ac02_issued_owner.manual_qc_pending()
		and saved_records_match(lab)
	)
	var guards: int = calls(EXPORT_GUARD_LABEL) - int(before.guard_calls)
	return {
		"ok": saved and guards >= 4,
		"pending_before": pending_expected,
		"unconditional_full_save": saved,
		"deep_dispatches": guards,
		"status": lab._status_label.text if lab._status_label != null else "",
		"output_lines_require_log_review": true
	}


static func no_pending_terminal_control(lab: PitchBatLab) -> Dictionary:
	var before: Dictionary = capture(lab)
	if not before.ok or before.telemetry.pending:
		return {"ok": false, "error": "Fresh or successfully flushed ACTIVE session required."}
	var continued: bool = F.flush_pending_manual_records(lab)
	var untouched: bool = (
		continued
		and same_session(lab, before)
		and telemetry(before.issue) == before.telemetry
		and file_state(before.exporter) == before.file
		and calls(DEEP_LABEL) == before.deep_calls
		and calls(EXPORT_GUARD_LABEL) == before.guard_calls
	)
	return {"ok": untouched, "no_pending_did_no_export_or_deep_audit": untouched}


static func failed_terminal_and_f3_retry(
	lab: PitchBatLab, missing_parent_path: String
) -> Dictionary:
	var before: Dictionary = capture(lab)
	if (
		not before.ok
		or not before.telemetry.pending
		or before.telemetry.terminal_attempted
		or not missing_parent_path.is_absolute_path()
		or DirAccess.dir_exists_absolute(missing_parent_path.get_base_dir())
	):
		return {
			"ok": false,
			"error": "Fresh native-dirty session and nonexistent output parent required."
		}
	# Fault injection changes only native export destination, never script/issuer/result/phase.
	var old_path: String = lab._record_export.path
	lab._record_export.path = missing_parent_path
	var continued: bool = F.flush_pending_manual_records(lab)
	var after_first: Dictionary = telemetry(before.issue)
	var first_guards: int = calls(EXPORT_GUARD_LABEL) - int(before.guard_calls)
	var once_calls: int = calls(EXPORT_GUARD_LABEL)
	var repeated_continue: bool = F.flush_pending_manual_records(lab)
	var once_only: bool = (
		calls(EXPORT_GUARD_LABEL) == once_calls and telemetry(before.issue) == after_first
	)
	lab._record_export.path = old_path
	var pending_retained: bool = before.issue.manual_qc_pending()
	var explicit_retry: Dictionary = f3_control(lab, true)
	return {
		"ok":
		(
			continued
			and repeated_continue
			and same_session(lab, before)
			and after_first.pending
			and after_first.terminal_attempted
			and after_first.saved == before.telemetry.saved
			and first_guards >= 2
			and once_only
			and pending_retained
			and explicit_retry.ok
			and before.issue._manual_qc_terminal_attempted
		),
		"automatic_retry_suppressed": once_only,
		"failure_did_not_acknowledge": pending_retained,
		"explicit_f3_retry": explicit_retry,
		"warning_requires_log_review": true,
		"season_durability_proven": false
	}


static func cancellation_control(app: SeasonApp) -> Dictionary:
	var lab: PitchBatLab = app.lab
	var before: Dictionary = capture(lab)
	if not before.ok or lab._match_state.phase == MatchState.Phase.GAME_END:
		return {"ok": false, "error": "Live unfinished manual app required."}
	app.ask_leave_game()
	var shown: bool = app._dialog.visible
	# Equivalent cancel notification without invoking the confirmed action.
	app._dialog.get_cancel_button().pressed.emit()
	app._dialog.hide()
	app._dialog.canceled.emit()
	return {
		"ok":
		(
			shown
			and app.lab == lab
			and same_session(lab, before)
			and telemetry(before.issue) == before.telemetry
			and file_state(before.exporter) == before.file
			and calls(EXPORT_GUARD_LABEL) == before.guard_calls
		),
		"dialog_cancel_control_only": true,
		"human_ui_click_still_required": true
	}


static func ordinary_reset_and_managed_r(lab: PitchBatLab) -> Dictionary:
	var before: Dictionary = capture(lab)
	if not before.ok or not lab._managed_match or not before.telemetry.pending:
		return {"ok": false, "error": "Managed genuine manual pending session required."}
	lab._start_new_match()
	var r_noop: bool = (
		same_session(lab, before)
		and telemetry(before.issue) == before.telemetry
		and lab._play_records.size() == before.count
		and file_state(before.exporter) == before.file
	)
	lab._reset_lab()
	return {
		"ok":
		(
			r_noop
			and same_session(lab, before)
			and telemetry(before.issue) == before.telemetry
			and lab._play_records.size() == before.count
			and file_state(before.exporter) == before.file
		),
		"managed_r_noop": r_noop,
		"ordinary_reset_preserved_pending": before.issue.manual_qc_pending()
	}


static func clear_control(lab: PitchBatLab, failure_path: String = "") -> Dictionary:
	var before: Dictionary = capture(lab)
	if not before.ok or not before.telemetry.pending:
		return {
			"ok": false,
			"error":
			"Genuine dirty manual session required, including after a failed terminal attempt."
		}
	if not failure_path.is_empty():
		if (
			not failure_path.is_absolute_path()
			or DirAccess.dir_exists_absolute(failure_path.get_base_dir())
		):
			return {"ok": false, "error": "Failure destination must have a nonexistent parent."}
		lab._record_export.path = failure_path
	F.clear_records(lab)
	var rotated: bool = (
		active_manual(lab)
		and lab._match_state == before.match
		and lab._ac02_issued_owner == before.issue
		and lab._record_export != before.exporter
		and is_same(lab._play_records, before.records)
		and lab._play_records.is_empty()
		and lab._active_play_record == null
	)
	var reset: Dictionary = telemetry(before.issue)
	var old_file: Array = file_state(before.exporter)
	return {
		"ok":
		(
			rotated
			and not reset.pending
			and not reset.started
			and not reset.terminal_attempted
			and reset.dirty == 0
			and reset.saved == 0
			and reset.opted_out == before.telemetry.opted_out
			and (bool(old_file[1]) if failure_path.is_empty() else not bool(old_file[1]))
		),
		"rotated_original_session": rotated,
		"old_export": old_file,
		"deliberate_failed_discard": not failure_path.is_empty(),
		"warning_requires_log_review": true
	}


static func install_custom_pending_record(lab: PitchBatLab) -> Dictionary:
	# ONLY a custom/historical control; never part of native performance acceptance.
	if not active_manual(lab) or lab._active_play_record == null:
		return {"ok": false, "error": "Genuine naturally pending record required."}
	var original: PlayRecord = lab._active_play_record
	var custom: PlayRecord = PROBE_RECORD.new()
	for property: Dictionary in original.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			custom.set(property.name, original.get(property.name))
	lab._active_play_record = custom
	return {
		"ok": true,
		"record": custom,
		"original": original,
		"count": lab._play_records.size(),
		"export_before": file_state(lab._record_export),
		"note": "Wait for ordinary gameplay completion. Do not directly call finish_record."
	}


static func observe_custom_then_native(
	lab: PitchBatLab, custom: PlayRecord, calls_after_custom: int, native_index: int
) -> Dictionary:
	# Caller records custom.serialize_calls after its natural completion, then waits
	# for a subsequent ordinary native completion without F3 or any explicit save.
	if (
		not active_manual(lab)
		or custom.get_script() != PROBE_RECORD
		or native_index < 0
		or native_index >= lab._play_records.size()
	):
		return {"ok": false, "error": "Real custom then native completions required."}
	var native_record: PlayRecord = lab._play_records[native_index]
	return {
		"ok":
		(
			lab._ac02_issued_owner._manual_qc_opted_out
			and native_record.get_script() == PlayRecord
			and native_record.result != &"pending"
			and lab._play_records.has(custom)
			and int(custom.get("serialize_calls")) > calls_after_custom
			and saved_records_match(lab)
		),
		"sticky_custom_callback_preserved": int(custom.get("serialize_calls")) > calls_after_custom,
		"performance_sample": false
	}


static func custom_exporter(lab: PitchBatLab) -> PlayRecordExport:
	if not active_manual(lab):
		return null
	var probe: PlayRecordExport = PROBE_EXPORTER.new()
	probe.path = lab._record_export.path
	probe.set("issue", weakref(lab._ac02_issued_owner))
	lab._record_export = probe
	return probe


static func callback_reentry(app: SeasonApp, callback_record: PlayRecord) -> Dictionary:
	# Record callback fires through real dump serialization, not a forged save-success result.
	var lab: PitchBatLab = app.lab
	var before: Dictionary = capture(lab)
	if (
		not before.ok
		or not before.telemetry.started
		or callback_record.get_script() != PROBE_RECORD
		or not lab._play_records.has(callback_record)
	):
		return {
			"ok": false, "error": "Actual retained custom record in ACTIVE manual session required."
		}
	var outcome: Dictionary = {
		"called": 0, "flush_refused": false, "close_refused": false, "clear_refused": false
	}
	callback_record.set(
		"on_serialize",
		func() -> void:
			outcome.called += 1
			outcome.flush_refused = not F.flush_pending_manual_records(lab)
			outcome.close_refused = not app._close_match()
			F.clear_records(lab)
			outcome.clear_refused = (
				app.lab == lab
				and same_session(lab, before)
				and lab._play_records.size() == before.count
			)
	)
	F.dump_records(lab)
	return {
		"ok":
		(
			outcome.called == 1
			and outcome.flush_refused
			and outcome.close_refused
			and outcome.clear_refused
			and app.lab == lab
			and same_session(lab, before)
			and not before.issue._manual_qc_flushing
		),
		"callback": outcome,
		"performance_sample": false
	}


static func ownership_flush_refusal(
	lab: PitchBatLab, mutation: String, foreign_lab: PitchBatLab = null
) -> Dictionary:
	var before: Dictionary = capture(lab)
	if not before.ok or not before.telemetry.pending:
		return {"ok": false, "error": "Genuine pending manual issue required."}
	if mutation not in ["revoked", "foreign_issue", "match", "exporter", "array"]:
		return {"ok": false, "error": "Unknown bounded mutation."}
	var foreign_before: Dictionary = {}
	match mutation:
		"revoked":
			before.issue.revoke("manual QC negative control")
		"foreign_issue":
			if not active_manual(foreign_lab) or foreign_lab == lab:
				return {"ok": false, "error": "Second genuine ACTIVE manual lab required."}
			foreign_before = capture(foreign_lab)
			lab._ac02_issued_owner = foreign_lab._ac02_issued_owner
		"match":
			lab._match_state = MatchState.new()
		"exporter":
			lab._record_export = PlayRecordExport.new()
		"array":
			lab._play_records = []
	var current_file: Array = file_state(lab._record_export)
	var saved_before: int = before.issue._manual_qc_saved_revision
	F.flush_pending_manual_records(lab)
	var no_ack: bool = before.issue._manual_qc_saved_revision == saved_before
	var no_write: bool = (
		file_state(lab._record_export) == current_file
		and file_state(before.exporter) == before.file
	)
	var foreign_unchanged: bool = (
		foreign_before.is_empty()
		or (
			same_session(foreign_lab, foreign_before)
			and telemetry(foreign_before.issue) == foreign_before.telemetry
			and file_state(foreign_before.exporter) == foreign_before.file
		)
	)
	# Restore routing for cleanup only. Never restore issue state or grant authority.
	if mutation == "foreign_issue":
		lab._ac02_issued_owner = before.issue
	elif mutation == "match":
		lab._match_state = before.match
	elif mutation == "exporter":
		lab._record_export = before.exporter
	elif mutation == "array":
		lab._play_records = before.records
	return {
		"ok": no_ack and no_write and foreign_unchanged,
		"mutation": mutation,
		"no_unrelated_acknowledgement": no_ack,
		"no_export": no_write,
		"foreign_telemetry_untouched": foreign_unchanged,
		"must_discard_fixture_after_control": true
	}


static func readonly_completion_refusal(lab: PitchBatLab) -> Dictionary:
	var before: Dictionary = capture(lab)
	if not before.ok or lab._active_play_record == null:
		return {"ok": false, "error": "Real pending manual record required."}
	var record: PlayRecord = lab._active_play_record
	var values: Array = [record.result, record.runs_scored]
	lab._play_records.make_read_only()
	# Negative attempt preserves the existing outcome values, never invents success.
	F.finish_record(lab, record.result, record.runs_scored)
	return {
		"ok":
		(
			lab._active_play_record == record
			and lab._play_records.size() == before.count
			and [record.result, record.runs_scored] == values
			and file_state(before.exporter) == before.file
			and before.issue.state == I.Lifetime.REVOKED
		),
		"negative_only": true,
		"must_discard_fixture_after_control": true
	}


static func callback_session_drift(
	lab: PitchBatLab, callback_record: PlayRecord, mutation: String, foreign_lab: PitchBatLab = null
) -> Dictionary:
	# F3's one-shot custom callback fires in OUTPUT serialization BEFORE _save_records.
	# A nonempty batch lease must be rechecked there, before any swapped data is saved.
	var before: Dictionary = capture(lab)
	if (
		not before.ok
		or not before.telemetry.started
		or not before.telemetry.pending
		or callback_record.get_script() != PROBE_RECORD
		or not lab._play_records.has(callback_record)
	):
		return {
			"ok": false,
			"error": "Previously batched, now custom, genuinely pending session required."
		}
	if (
		mutation
		not in [
			"exporter",
			"array",
			"count",
			"revision",
			"match",
			"revoke",
			"automation",
			"issuer_lost",
			"foreign_issue"
		]
	):
		return {"ok": false, "error": "Unknown callback mutation."}
	var foreign_before: Dictionary = {}
	if mutation == "foreign_issue":
		if foreign_lab == lab or not active_manual(foreign_lab):
			return {"ok": false, "error": "A second genuinely installed manual owner is required."}
		foreign_before = capture(foreign_lab)
	var status_before: String = lab._status_label.text if lab._status_label != null else ""
	var invoked: Array[int] = [0]
	var replacement_exporter: PlayRecordExport = PlayRecordExport.new()
	var replacement_file: Array = file_state(replacement_exporter)
	var replacement_records: Array[PlayRecord] = []
	var replacement_match: MatchState = MatchState.new()
	var replacement_automation: MatchAutomation = MatchAutomation.new()
	callback_record.set(
		"on_serialize",
		func() -> void:
			invoked[0] += 1
			match mutation:
				"exporter":
					lab._record_export = replacement_exporter
				"array":
					lab._play_records = replacement_records
				"count":
					lab._play_records.append(PlayRecord.new())
				"revision":
					before.issue._manual_qc_dirty_revision += 1
				"match":
					lab._match_state = replacement_match
				"revoke":
					before.issue.revoke("manual QC callback control")
				"automation":
					lab._automation = replacement_automation
				"issuer_lost":
					lab._ac02_issued_owner = null
				"foreign_issue":
					lab._ac02_issued_owner = foreign_before.issue
	)
	F.dump_records(lab)
	var no_ack: bool = before.issue._manual_qc_saved_revision == before.telemetry.saved
	var replacement_untouched: bool = file_state(replacement_exporter) == replacement_file
	if mutation == "exporter":
		replacement_untouched = replacement_untouched and lab._record_export == replacement_exporter
	elif mutation == "array":
		replacement_untouched = (
			replacement_untouched
			and is_same(lab._play_records, replacement_records)
			and replacement_records.is_empty()
		)
	elif mutation == "match":
		replacement_untouched = replacement_untouched and lab._match_state == replacement_match
	elif mutation == "automation":
		replacement_untouched = replacement_untouched and lab._automation == replacement_automation
	var foreign_untouched: bool = (
		foreign_before.is_empty()
		or (
			same_session(foreign_lab, foreign_before)
			and active_manual(foreign_lab)
			and telemetry(foreign_before.issue) == foreign_before.telemetry
			and file_state(foreign_before.exporter) == foreign_before.file
		)
	)
	var no_write: bool = (
		file_state(before.exporter) == before.file
		and file_state(replacement_exporter) == replacement_file
	)
	var no_new_saved_status: bool = (
		lab._status_label == null or lab._status_label.text == status_before
	)
	return {
		"ok":
		(
			invoked[0] == 1
			and no_ack
			and replacement_untouched
			and foreign_untouched
			and no_write
			and no_new_saved_status
			and not before.issue._manual_qc_flushing
		),
		"mutation": mutation,
		"no_acknowledgement_after_drift": no_ack,
		"original_and_replacement_exporter_path_and_file_unchanged": no_write,
		"replacement_preserved": replacement_untouched,
		"foreign_owner_untouched": foreign_untouched,
		"no_new_saved_status": no_new_saved_status,
		"automation_replacement_never_acknowledged": mutation == "automation" and no_ack,
		"callback_boundary": "F3 Output, before actual save",
		"must_discard_fixture_after_control": true
	}


static func close_callback_replacement(
	app: SeasonApp, callback_record: PlayRecord, replacement_lab: PitchBatLab
) -> Dictionary:
	var lab: PitchBatLab = app.lab
	var before: Dictionary = capture(lab)
	var replacement: Dictionary = capture(replacement_lab)
	if (
		not before.ok
		or not before.telemetry.pending
		or before.telemetry.terminal_attempted
		or not replacement.ok
		or replacement_lab == lab
		or callback_record.get_script() != PROBE_RECORD
		or not lab._play_records.has(callback_record)
	):
		return {
			"ok": false,
			"error": "Genuine pending captured session and second installed manual lab required."
		}
	var called: Array[int] = [0]
	callback_record.set(
		"on_serialize",
		func() -> void:
			called[0] += 1
			app.lab = replacement_lab
	)
	var closed: bool = app._close_match()
	var intact: bool = (
		app.lab == replacement_lab
		and same_session(replacement_lab, replacement)
		and active_manual(replacement_lab)
		and telemetry(replacement.issue) == replacement.telemetry
		and file_state(replacement.exporter) == replacement.file
		and not replacement_lab.is_queued_for_deletion()
	)
	# App routing is restored only to enable caller-owned cleanup; authority is untouched.
	app.lab = lab
	return {
		"ok":
		(
			called[0] == 1
			and not closed
			and intact
			and is_instance_valid(lab)
			and not lab.is_queued_for_deletion()
		),
		"aborted_close_reported": not closed,
		"replacement_not_disposed": intact,
		"must_discard_fixture_after_control": true
	}


static func commit_callback_replacement(
	app: SeasonApp, callback_record: PlayRecord, replacement_lab: PitchBatLab
) -> Dictionary:
	# Requires the REAL final state before the app's ordinary first terminal commit.
	# Caller may arrange a read-only debugger stop at that boundary; never set phase.
	var lab: PitchBatLab = app.lab
	var before: Dictionary = capture(lab)
	var replacement: Dictionary = capture(replacement_lab)
	if (
		not before.ok
		or not before.telemetry.pending
		or before.telemetry.terminal_attempted
		or not replacement.ok
		or replacement_lab == lab
		or lab._match_state.phase != MatchState.Phase.GAME_END
		or not app._season_game
		or app._result_recorded
		or app._result_saved
		or not app._ac02_settlement_ticket.is_empty()
		or callback_record.get_script() != PROBE_RECORD
		or not lab._play_records.has(callback_record)
	):
		return {
			"ok": false,
			"error":
			(
				"Uncommitted naturally ended game, pending lease, retained custom record and second "
				+ "real lab required."
			)
		}
	var old_season: SeasonState = app.season
	var season_before: Dictionary = SeasonSave.snapshot(old_season)
	var season_path: String = SeasonSave.path
	var season_exists: bool = FileAccess.file_exists(season_path)
	var season_hash: String = FileAccess.get_sha256(season_path) if season_exists else ""
	var called: Array[int] = [0]
	callback_record.set(
		"on_serialize",
		func() -> void:
			called[0] += 1
			app.lab = replacement_lab
	)
	var committed: bool = app._commit_result()
	var intact: bool = (
		app.lab == replacement_lab
		and same_session(replacement_lab, replacement)
		and active_manual(replacement_lab)
		and telemetry(replacement.issue) == replacement.telemetry
		and file_state(replacement.exporter) == replacement.file
		and not replacement_lab.is_queued_for_deletion()
	)
	var season_unchanged: bool = (
		app.season == old_season
		and ClubCareer.same(SeasonSave.snapshot(old_season), season_before)
		and SeasonSave.path == season_path
		and FileAccess.file_exists(season_path) == season_exists
		and (not season_exists or FileAccess.get_sha256(season_path) == season_hash)
		and not app._result_recorded
		and not app._result_saved
		and app._ac02_settlement_ticket.is_empty()
	)
	# Restore only app routing for caller-owned cleanup. Never restore issued authority.
	app.lab = lab
	return {
		"ok": called[0] == 1 and not committed and intact and season_unchanged,
		"aborted_commit_reported": not committed,
		"replacement_not_committed": intact,
		"result_and_durable_season_unchanged": season_unchanged,
		"must_discard_fixture_after_control": true
	}


static func clear_preexisting_substitution(lab: PitchBatLab, mutation: String) -> Dictionary:
	var before: Dictionary = capture(lab)
	if (
		not before.ok
		or not before.telemetry.started
		or not before.telemetry.pending
		or mutation not in ["exporter", "array"]
	):
		return {
			"ok": false,
			"error": "Started genuine pending batch and exporter/array mutation required."
		}
	var original_order: Array[PlayRecord] = lab._play_records.duplicate()
	var original_active: PlayRecord = lab._active_play_record
	var replacement_exporter: PlayRecordExport = PlayRecordExport.new()
	var replacement_records: Array[PlayRecord] = []
	# A pending sentinel makes accidental replacement clearing visible, not merely rotation.
	var sentinel: PlayRecord = PlayRecord.new()
	replacement_records.append(sentinel)
	if mutation == "exporter":
		lab._record_export = replacement_exporter
	else:
		lab._play_records = replacement_records
	var seen_exporter: PlayRecordExport = lab._record_export
	var seen_records: Array[PlayRecord] = lab._play_records
	F.clear_records(lab)
	var unchanged: bool = (
		lab._record_export == seen_exporter
		and is_same(lab._play_records, seen_records)
		and lab._active_play_record == original_active
		and before.records == original_order
		and file_state(before.exporter) == before.file
		and file_state(replacement_exporter) == ["", false, ""]
		and before.issue._manual_qc_saved_revision == before.telemetry.saved
	)
	if mutation == "array":
		unchanged = (
			unchanged and replacement_records.size() == 1 and replacement_records[0] == sentinel
		)
	# Restore only diagnostic routing for caller-owned cleanup, never authority or telemetry.
	lab._record_export = before.exporter
	lab._play_records = before.records
	return {
		"ok": unchanged,
		"mutation": mutation,
		"replacement_and_original_not_cleared": unchanged,
		"must_discard_fixture_after_control": true
	}


static func prepare_flushed_custom_failure(
	lab: PitchBatLab, missing_parent_path: String
) -> Dictionary:
	# Start with a REAL native batch that a successful F3 already acknowledged.
	# Install only a custom pending diagnostic record; ordinary gameplay must finish it.
	var before: Dictionary = capture(lab)
	if (
		not before.ok
		or not before.telemetry.started
		or before.telemetry.pending
		or int(before.telemetry.dirty) <= 0
		or before.telemetry.dirty != before.telemetry.saved
		or not missing_parent_path.is_absolute_path()
		or DirAccess.dir_exists_absolute(missing_parent_path.get_base_dir())
	):
		return {
			"ok": false, "error": "F3-flushed native batch and nonexistent output parent required."
		}
	var custom: Dictionary = install_custom_pending_record(lab)
	if not custom.ok:
		return custom
	lab._record_export.path = missing_parent_path
	return {
		"ok": true,
		"before": before,
		"custom": custom.record,
		"failed_path": missing_parent_path,
		"note": "Wait for ordinary custom-record gameplay completion, with no F3 or explicit flush."
	}
