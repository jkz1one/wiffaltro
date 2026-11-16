extends "res://src/tests/ac02_manual_qc_controls_fixture_base.gd"
static func flushed_custom_failure_no_terminal_retry(
	lab: PitchBatLab, prepared: Dictionary
) -> Dictionary:
	if (
		not prepared.get("ok", false)
		or not same_session(lab, prepared.before)
		or not active_manual(lab)
		or lab._active_play_record == prepared.custom
		or not lab._play_records.has(prepared.custom)
		or prepared.custom.result == &"pending"
		or lab._record_export.path != prepared.failed_path
		or int(prepared.custom.get("serialize_calls")) < 1
	):
		return {
			"ok": false,
			"error": "Ordinary custom completion and attempted failing historical save required."
		}
	var before_terminal: Dictionary = capture(lab)
	var unchanged_native_revision: bool = (
		before_terminal.telemetry.dirty == prepared.before.telemetry.dirty
		and before_terminal.telemetry.saved == prepared.before.telemetry.saved
		and not before_terminal.telemetry.pending
	)
	var continued: bool = F.flush_pending_manual_records(lab)
	var no_retry: bool = (
		continued
		and telemetry(before_terminal.issue) == before_terminal.telemetry
		and calls(DEEP_LABEL) == before_terminal.deep_calls
		and calls(EXPORT_GUARD_LABEL) == before_terminal.guard_calls
		and file_state(lab._record_export) == before_terminal.file
		and not bool(before_terminal.file[1])
	)
	# Restore only the original output destination for caller-owned cleanup.
	lab._record_export.path = str(prepared.before.file[0])
	return {
		"ok": unchanged_native_revision and no_retry and before_terminal.issue._manual_qc_opted_out,
		"custom_failure_did_not_create_new_native_pending": unchanged_native_revision,
		"terminal_did_not_retry_historical_failure": no_retry,
		"historical_save_failure_warning_requires_log_review": true,
		"performance_sample": false
	}


static func terminal_callback_drift_repeated_refusal(
	lab: PitchBatLab, callback_record: PlayRecord, mutation: String, foreign_lab: PitchBatLab = null
) -> Dictionary:
	# Unlike F3, this callback runs INSIDE the original native exporter.save. The
	# original file may already be written; it must never become an authority receipt.
	var before: Dictionary = capture(lab)
	if (
		not before.ok
		or not before.telemetry.started
		or not before.telemetry.pending
		or before.telemetry.terminal_attempted
		or callback_record.get_script() != PROBE_RECORD
		or not lab._play_records.has(callback_record)
	):
		return {
			"ok": false,
			"error":
			"Genuine pending lease with no terminal attempt and retained custom record required."
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
		return {
			"ok": false,
			"error": "Terminal repeat control requires captured owner/session/count/revision drift."
		}
	var foreign_before: Dictionary = {}
	if mutation == "foreign_issue":
		if foreign_lab == lab or not active_manual(foreign_lab):
			return {"ok": false, "error": "A second genuinely installed manual owner is required."}
		foreign_before = capture(foreign_lab)
	var invoked: Array[int] = [0]
	var replacement_exporter: PlayRecordExport = PlayRecordExport.new()
	var replacement_file: Array = file_state(replacement_exporter)
	var replacement_records: Array[PlayRecord] = []
	var replacement_match: MatchState = MatchState.new()
	var replacement_automation: MatchAutomation = MatchAutomation.new()
	var status_before: String = lab._status_label.text if lab._status_label != null else ""
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
					before.issue.revoke("manual QC terminal callback control")
				"automation":
					lab._automation = replacement_automation
				"issuer_lost":
					lab._ac02_issued_owner = null
				"foreign_issue":
					lab._ac02_issued_owner = foreign_before.issue
	)
	var first_refused: bool = not F.flush_pending_manual_records(lab)
	var first_deep: int = calls(DEEP_LABEL)
	var first_guards: int = calls(EXPORT_GUARD_LABEL)
	var first_original_file: Array = file_state(before.exporter)
	var first_current_file: Array = file_state(lab._record_export)
	var after_first: Dictionary = telemetry(before.issue)
	var second_refused: bool = not F.flush_pending_manual_records(lab)
	var third_refused: bool = not F.flush_pending_manual_records(lab)
	var no_retry: bool = (
		calls(DEEP_LABEL) == first_deep
		and calls(EXPORT_GUARD_LABEL) == first_guards
		and file_state(before.exporter) == first_original_file
		and file_state(lab._record_export) == first_current_file
		and telemetry(before.issue) == after_first
	)
	var foreign_untouched: bool = (
		foreign_before.is_empty()
		or (
			same_session(foreign_lab, foreign_before)
			and active_manual(foreign_lab)
			and telemetry(foreign_before.issue) == foreign_before.telemetry
			and file_state(foreign_before.exporter) == foreign_before.file
		)
	)
	var no_ack: bool = before.issue._manual_qc_saved_revision == before.telemetry.saved
	var no_new_saved_status: bool = (
		lab._status_label == null or lab._status_label.text == status_before
	)
	var replacement_untouched: bool = file_state(replacement_exporter) == replacement_file
	if mutation == "array":
		replacement_untouched = (
			replacement_untouched
			and replacement_records.is_empty()
			and is_same(lab._play_records, replacement_records)
		)
	return {
		"ok":
		(
			invoked[0] == 1
			and first_refused
			and second_refused
			and third_refused
			and no_retry
			and no_ack
			and after_first.pending
			and after_first.terminal_attempted
			and not after_first.inflight
			and replacement_untouched
			and foreign_untouched
			and no_new_saved_status
		),
		"mutation": mutation,
		"first_terminal_continuation_refused": first_refused,
		"repeated_terminal_continuation_still_refused": second_refused and third_refused,
		"repeated_attempts_did_no_io_or_deep_audit": no_retry,
		"no_acknowledgement_after_drift": no_ack,
		"replacement_exporter_unwritten": replacement_untouched,
		"foreign_owner_untouched": foreign_untouched,
		"no_new_saved_status": no_new_saved_status,
		"callback_boundary": "inside native exporter.save",
		"original_file_may_have_been_written_before_drift_was_detected": true,
		"must_discard_fixture_after_control": true
	}


static func capture_failed_qc_settlement(app: SeasonApp) -> Dictionary:
	# PRECONDITION ONLY: never sets phase, result flags, tickets or settlement success.
	# Caller must retain the real GAME_END/failed-QC/ordinary-settlement provenance.
	if app == null or not app._ac02_settlement_owner_intact():
		return {"ok": false, "error": "A genuine original revoked settlement owner is required."}
	var lab: PitchBatLab = app.lab
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	var exporter: PlayRecordExport = lab._record_export
	if (
		issue == null
		or issue.get_script() != I
		or lab._automation != null
		or issue._bindings_pin.get("lab") != lab
		or issue._bindings_pin.get("match") != lab._match_state
		or issue._bindings_pin.get("automation") != null
		or not issue._manual_qc_started
		or not issue.manual_qc_pending()
		or issue._manual_qc_flushing
		or not issue._manual_qc_terminal_attempted
		or exporter == null
		or exporter.get_script() != PlayRecordExport
		or exporter != issue._manual_qc_exporter
		or not is_same(lab._play_records, issue._manual_qc_records)
		or lab._play_records.size() != issue._manual_qc_terminal_count
		or issue._manual_qc_dirty_revision != issue._manual_qc_terminal_revision
	):
		return {"ok": false, "error": "Exact failed native terminal batch/session is required."}
	if (
		exporter.path.is_empty()
		or FileAccess.file_exists(exporter.path)
		or DirAccess.dir_exists_absolute(exporter.path.get_base_dir())
	):
		return {
			"ok": false, "error": "Retain the actual native failed-write path with absent parent."
		}
	# Read/decode the primary file, not a backup and not a synthetic save receipt.
	var restored: SeasonState = SeasonSave._read(SeasonSave.path)
	var snapshot: Dictionary = SeasonSave.snapshot(app.season)
	if restored == null or not ClubCareer.same(SeasonSave.snapshot(restored), snapshot):
		return {"ok": false, "error": "Ordinary settlement must already be durably saved."}
	return {
		"ok": true,
		"lab": lab,
		"match": lab._match_state,
		"issue": issue,
		"exporter": exporter,
		"records": lab._play_records,
		"record_order": lab._play_records.duplicate(),
		"telemetry": telemetry(issue),
		"file": file_state(exporter),
		"season": app.season,
		"snapshot": snapshot,
		"season_path": SeasonSave.path,
		"season_sha256": FileAccess.get_sha256(SeasonSave.path),
		"ticket": app._ac02_settlement_ticket,
		"ledger": lab._stadium_ledger,
		"result_flags": [app._result_recorded, app._result_saved],
		"deep_calls": calls(DEEP_LABEL),
		"guard_calls": calls(EXPORT_GUARD_LABEL)
	}


static func failed_qc_settled_close_control(app: SeasonApp) -> Dictionary:
	var before: Dictionary = capture_failed_qc_settlement(app)
	if not before.ok:
		return before
	var allowed: bool = app._ac02_settled_manual_qc_close_allowed()
	var closed: bool = app._close_match()
	var no_qc_retry: bool = (
		calls(DEEP_LABEL) == before.deep_calls
		and calls(EXPORT_GUARD_LABEL) == before.guard_calls
		and file_state(before.exporter) == before.file
	)
	var season_unchanged: bool = (
		app.season == before.season
		and ClubCareer.same(SeasonSave.snapshot(app.season), before.snapshot)
		and SeasonSave.path == before.season_path
		and FileAccess.get_sha256(SeasonSave.path) == before.season_sha256
		and [app._result_recorded, app._result_saved] == before.result_flags
	)
	var not_acknowledged: bool = (
		before.issue._manual_qc_saved_revision == int(before.telemetry.saved)
		and before.issue.manual_qc_pending()
		and before.records == before.record_order
	)
	return {
		"ok":
		(
			allowed
			and closed
			and app.lab == null
			and app._ac02_settlement_ticket.is_empty()
			and no_qc_retry
			and season_unchanged
			and not_acknowledged
		),
		"close_allowed_only_after_genuine_settlement": allowed,
		"no_post_revocation_qc_retry_or_deep_audit": no_qc_retry,
		"season_and_primary_file_unchanged_by_close": season_unchanged,
		"diagnostics_not_acknowledged": not_acknowledged,
		"discard_warning_requires_log_review": true,
		"prior_natural_GAME_END_and_failed_IO_witness_required": true
	}


static func settled_close_identity_refusal(
	app: SeasonApp, mutation: String, foreign_lab: PitchBatLab = null
) -> Dictionary:
	var before: Dictionary = capture_failed_qc_settlement(app)
	if not before.ok:
		return before
	var issue: StadiumNpcAc02IssuedStateV1 = before.issue
	var foreign: Dictionary = {}
	if mutation == "foreign_issue":
		foreign = capture(foreign_lab)
		if not foreign.ok or foreign_lab == app.lab:
			return {
				"ok": false, "error": "A second genuinely installed ACTIVE fixture is required."
			}
	var replacement: PlayRecordExport = null
	match mutation:
		"forged_ticket":
			app._ac02_settlement_ticket = app._ac02_settlement_ticket.duplicate()
			app._ac02_settlement_ticket["fixture_id"] = app._fixture_id + 1
		"missing_ticket":
			app._ac02_settlement_ticket = {}
		"foreign_issue":
			app.lab._ac02_issued_owner = foreign.issue
		"exporter":
			replacement = PlayRecordExport.new()
			app.lab._record_export = replacement
		"array":
			app.lab._play_records = [PlayRecord.new()]
		"count":
			app.lab._play_records.append(PlayRecord.new())
		"revision":
			issue._manual_qc_dirty_revision += 1
		"terminal_count":
			issue._manual_qc_terminal_count += 1
		"terminal_revision":
			issue._manual_qc_terminal_revision += 1
		"automation":
			app.lab._automation = MatchAutomation.new()
		_:
			return {"ok": false, "error": "Unknown settled-close negative mutation."}
	var seen_records: Array[PlayRecord] = app.lab._play_records
	var seen_order: Array[PlayRecord] = seen_records.duplicate()
	var original_seen_order: Array[PlayRecord] = before.records.duplicate()
	var seen_exporter: PlayRecordExport = app.lab._record_export
	var seen_issue: StadiumNpcAc02IssuedStateV1 = app.lab._ac02_issued_owner
	var seen_ticket: Dictionary = app._ac02_settlement_ticket
	var seen_ticket_values: Dictionary = seen_ticket.duplicate()
	var seen_telemetry: Dictionary = telemetry(issue)
	var replacement_file: Array = file_state(replacement) if replacement != null else []
	var allowed: bool = app._ac02_settled_manual_qc_close_allowed()
	var closed: bool = app._close_match()
	var retained: bool = (
		is_instance_valid(before.lab)
		and app.lab == before.lab
		and not before.lab.is_queued_for_deletion()
		and before.lab.get_parent() == app
		and before.lab._match_state == before.match
		and before.lab._stadium_ledger == before.ledger
		and before.lab._ac02_issued_owner == seen_issue
		and before.lab._record_export == seen_exporter
		and is_same(before.lab._play_records, seen_records)
		and seen_records == seen_order
		and is_same(app._ac02_settlement_ticket, seen_ticket)
		and seen_ticket == seen_ticket_values
	)
	var untouched: bool = (
		telemetry(issue) == seen_telemetry
		and before.records == original_seen_order
		and is_same(issue._manual_qc_records, before.records)
		and issue._manual_qc_exporter == before.exporter
		and file_state(before.exporter) == before.file
		and (replacement == null or file_state(replacement) == replacement_file)
		and calls(DEEP_LABEL) == before.deep_calls
		and calls(EXPORT_GUARD_LABEL) == before.guard_calls
	)
	var season_unchanged: bool = (
		app.season == before.season
		and ClubCareer.same(SeasonSave.snapshot(app.season), before.snapshot)
		and SeasonSave.path == before.season_path
		and FileAccess.get_sha256(SeasonSave.path) == before.season_sha256
		and [app._result_recorded, app._result_saved] == before.result_flags
	)
	var foreign_unchanged: bool = (
		foreign.is_empty()
		or (
			same_session(foreign_lab, foreign)
			and telemetry(foreign.issue) == foreign.telemetry
			and file_state(foreign.exporter) == foreign.file
		)
	)
	# Deliberately leave corrupted disposable routing/state visible. Never revive or
	# reconstruct authority for a later positive case; tear down the isolated fixture.
	return {
		"ok":
		(
			not allowed
			and not closed
			and retained
			and untouched
			and season_unchanged
			and foreign_unchanged
		),
		"mutation": mutation,
		"predicate_and_actual_close_refused": not allowed and not closed,
		"original_lab_ledger_ticket_and_session_retained": retained,
		"no_qc_audit_IO_acknowledgement_or_session_clear": untouched,
		"season_unchanged": season_unchanged,
		"foreign_owner_unchanged": foreign_unchanged,
		"negative_fixture_must_not_be_reused_for_positive_evidence": true
	}


static func settled_round_resume_refusal(app: SeasonApp, mutation: String) -> Dictionary:
	# A separate caller-propagation control. The normal preceding settlement checkpoint
	# may adopt a new cleanup career; only subsequent round advancement must stop.
	var before: Dictionary = capture_failed_qc_settlement(app)
	if not before.ok:
		return before
	if (
		not (
			mutation
			in ["exporter", "array", "count", "revision", "terminal_count", "terminal_revision"]
		)
		or app.season.physical == null
		or not app._ac02_resume_authorized()
		or app.round_ui._working
		or app.round_ui.runner._lab != null
		or app.round_ui.process_runner.running
	):
		return {
			"ok": false,
			"error": "An idle genuine pending-human round and diagnostic-only drift are required."
		}
	var projection: Dictionary = app.round_ui._projection
	var projection_values: Dictionary = projection.duplicate(true)
	var started: int = app.round_ui._started
	var menu_visible: bool = app.menu.visible
	var round_values: Array = [
		app.season.phase,
		app.season.round_index,
		app.season.results.duplicate(true),
		app.season.player_results.duplicate(true),
		app.season.pending_fixture().duplicate(true),
		app.season.physical.pending.duplicate(true)
	]
	var cleanup_career: ClubCareer = before.issue._cleanup_career
	var negative: Dictionary = settled_close_identity_refusal(app, mutation)
	if not negative.ok or not app._ac02_resume_authorized():
		return {
			"ok": false,
			"error": "The diagnostic negative must refuse close without invalidating settlement.",
			"direct_close": negative
		}
	var guards: int = calls(EXPORT_GUARD_LABEL)
	app.round_ui.resume()
	# Actual accepted normal save adopts its new durable career. This distinguishes
	# reaching the refused-close guard from merely stopping on an earlier save error.
	var checkpoint_accepted: bool = (
		before.issue._cleanup_career != cleanup_career
		and before.issue._cleanup_career == app.season.career
		and SeasonSave.last_error.is_empty()
		and app._ac02_settlement_owner_intact()
	)
	var stopped: bool = (
		app.lab == before.lab
		and is_instance_valid(before.lab)
		and not before.lab.is_queued_for_deletion()
		and before.lab.get_parent() == app
		and app.round_ui._started == started
		and not app.round_ui._working
		and is_same(app.round_ui._projection, projection)
		and app.round_ui._projection == projection_values
		and app.round_ui.runner._lab == null
		and not app.round_ui.process_runner.running
		and app.menu.visible == menu_visible
		and is_same(app._ac02_settlement_ticket, before.ticket)
	)
	var round_unchanged: bool = (
		app.season == before.season
		and app.season.physical != null
		and ClubCareer.same(
			[
				app.season.phase,
				app.season.round_index,
				app.season.results,
				app.season.player_results,
				app.season.pending_fixture(),
				app.season.physical.pending
			],
			round_values
		)
		and [app._result_recorded, app._result_saved] == before.result_flags
	)
	var no_qc_retry: bool = (
		calls(EXPORT_GUARD_LABEL) == guards
		and file_state(before.exporter) == before.file
		and before.issue._manual_qc_saved_revision == int(before.telemetry.saved)
	)
	return {
		"ok": checkpoint_accepted and stopped and round_unchanged and no_qc_retry,
		"mutation": mutation,
		"direct_close": negative,
		"normal_checkpoint_actually_accepted_before_refused_close": checkpoint_accepted,
		"resume_stopped_before_next_or_runner_start": stopped,
		"no_round_result_fixture_or_pending_report_advancement": round_unchanged,
		"no_post_revocation_QC_retry": no_qc_retry,
		"preceding_existing_season_checkpoint_and_cleanup_career_adoption_allowed": true,
		"authorized_four_file_overlay_guard": true
	}
