extends RefCounted
## Focused component controls, not natural-game or timing qualification.
## Every owner comes from the existing public fixture. No ACTIVE owner is forged.
const C = preload("res://src/tests/ac02_manual_qc_controls.gd")
const F = preload("res://src/labs/pitch_bat_lab/pitch_bat_lab_feel_support.gd")
const Q = preload("res://src/labs/pitch_bat_lab/ac02_manual_qc_command_v1.gd")
const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")


static func metadata(exporter: PlayRecordExport) -> Array:
	return [exporter.path, exporter._revision, exporter._source_dirty]


static func observation(lab: PitchBatLab) -> Dictionary:
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	return {
		"issue": issue,
		"telemetry": C.telemetry(issue),
		"file": C.file_state(lab._record_export),
		"metadata": metadata(lab._record_export),
		"deep": C.calls(C.DEEP_LABEL),
		"guards": C.calls(C.EXPORT_GUARD_LABEL),
		"status": lab._status_label.text if lab._status_label != null else ""
	}


static func expected_lines(lab: PitchBatLab) -> Array[String]:
	var serialized: Array[Dictionary] = []
	for record: PlayRecord in lab._play_records:
		serialized.append(record.to_dict())
	return [
		(
			"WIFFALTRO_FIELD_QC "
			+ JSON.stringify(
				PlayRecordExport.field_metadata(
					lab._field_definition, lab.get_meta("stadium_snapshot", {})
				)
			)
		),
		"WIFFALTRO_PLAY_RECORDS " + JSON.stringify(serialized)
	]


static func native_boundary(lab: PitchBatLab, output: bool, label: String) -> Dictionary:
	if not C.active_manual(lab) or lab._record_export.path.is_empty():
		return {
			"ok": false, "error": "Native parity requires original ACTIVE fixture and fixed path."
		}
	# Independent oracle is the literal unchanged save(), not the new preparation helper.
	# It writes the same isolated fixed path, whose exact bytes are retained before dispatch.
	var oracle: PlayRecordExport = PlayRecordExport.new()
	oracle.path = lab._record_export.path
	oracle._revision = lab._record_export._revision
	oracle._source_dirty = lab._record_export._source_dirty
	var error: Error = oracle.save(
		lab._play_records, lab._field_definition, lab.get_meta("stadium_snapshot", {})
	)
	if error != OK:
		return {"ok": false, "error": "Literal native parity oracle failed.", "code": error}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(oracle.path)
	var oracle_sha256: String = FileAccess.get_sha256(oracle.path)
	var lines: Array[String] = []
	if output:
		lines = expected_lines(lab)
	var before: Dictionary = observation(lab)
	print("QC_COMMAND_WINDOW_BEGIN ", label)
	var continued: bool = true
	if output:
		F.dump_records(lab)
	else:
		continued = F.flush_pending_manual_records(lab)
	print("QC_COMMAND_WINDOW_END ", label)
	var after: Dictionary = observation(lab)
	var parity: bool = FileAccess.get_file_as_bytes(oracle.path) == bytes
	return {
		"ok":
		(
			continued
			and C.active_manual(lab)
			and parity
			and after.guards - before.guards == 1
			and after.deep - before.deep == 1
			and not after.telemetry.pending
			and not after.telemetry.inflight
			and after.telemetry.saved == before.telemetry.dirty
		),
		"output_window": label,
		"expected_output_lines": lines,
		"file_byte_parity_with_literal_save": parity,
		"expected_file_sha256": oracle_sha256,
		"actual_file_sha256": FileAccess.get_sha256(oracle.path),
		"full_audit_calls": after.guards - before.guards,
		"construction_comparisons": after.deep - before.deep,
		"before": before.telemetry,
		"after": after.telemetry,
		"timestamp_session_id_compared": false
	}


static func capture_without_publication(lab: PitchBatLab) -> Dictionary:
	var before: Dictionary = observation(lab)
	var admission: Dictionary = Q._capture(lab)
	var plan: Dictionary = {}
	if admission.get("outcome") == Q.Outcome.HANDLED and admission.get("context") is Dictionary:
		plan = lab._record_export.prepare_manual_ac02_v1(
			lab._play_records, lab._field_definition, lab.get_meta("stadium_snapshot", {})
		)
	var after: Dictionary = observation(lab)
	return {
		"ok":
		(
			admission.get("outcome") == Q.Outcome.HANDLED
			and admission.get("context") is Dictionary
			and not admission.context.is_empty()
			and not plan.is_empty()
			and before == after
		),
		"context": admission.get("context", {}),
		"metadata": before.metadata,
		"before": before,
		"plan": plan
	}


static func drift(lab: PitchBatLab, mutation: String) -> Dictionary:
	# Each selector uses ORIGINAL captured context, then mutates the actual operand.
	# Routing cleanup is not publication, acknowledgment, or proof of revived authority.
	var captured: Dictionary = capture_without_publication(lab)
	if not captured.ok:
		return {"ok": false, "error": "Read-only native capture failed."}
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	var property: StadiumNpcPublicProperty = R._property(lab)
	var old_match: MatchState = lab._match_state
	var old_receipt: Dictionary = old_match.stadium
	var old_exporter: PlayRecordExport = lab._record_export
	var old_records: Array[PlayRecord] = lab._play_records
	var old_order: Array[PlayRecord] = old_records.duplicate()
	var old_field: FieldDefinition = lab._field_definition
	var old_revision: int = issue._manual_qc_dirty_revision
	var old_issue_generation: int = issue.generation
	match mutation:
		"owner":
			lab._ac02_issued_owner = null
		"property":
			lab.set_meta("stadium_property", Node3D.new())
		"match":
			lab._match_state = MatchState.new()
		"receipt":
			old_match.stadium = old_receipt.duplicate(true)
		"exporter":
			lab._record_export = PlayRecordExport.new()
		"array":
			lab._play_records = old_records.duplicate()
		"record_identity":
			old_records[0] = PlayRecord.new()
		"record_order":
			old_records.reverse()
		"count":
			old_records.append(PlayRecord.new())
		"revision":
			issue._manual_qc_dirty_revision += 1
		"export_path":
			old_exporter.path += ".changed"
		"export_revision":
			old_exporter._revision += "-changed"
		"source_dirty":
			old_exporter._source_dirty = not bool(old_exporter._source_dirty)
		"field":
			lab._field_definition = FieldDefinition.new()
		"generation":
			issue.generation += 1
		_:
			return {"ok": false, "error": "Unknown drift selector."}
	var replacement_file: Array = C.file_state(lab._record_export)
	var replacement_metadata: Array = metadata(lab._record_export)
	var status_before: String = lab._status_label.text if lab._status_label != null else ""
	print("QC_COMMAND_WINDOW_BEGIN drift_", mutation)
	var intact: bool = Q._intact(captured.context, captured.metadata)
	# Invoke the REAL writer only with already-invalid original context. It must
	# reject at its first guard, never borrow a successful capture as an audit lease.
	var writer: Dictionary = Q._persist(captured.context, captured.plan)
	print("QC_COMMAND_WINDOW_END drift_", mutation)
	var replacement_untouched: bool = (
		C.file_state(lab._record_export) == replacement_file
		and metadata(lab._record_export) == replacement_metadata
		and not FileAccess.file_exists(str(captured.metadata[0]) + ".tmp")
		and not FileAccess.file_exists(str(replacement_metadata[0]) + ".tmp")
		and (lab._status_label == null or lab._status_label.text == status_before)
	)
	var after: Dictionary = C.telemetry(issue)
	var unchanged_file: bool = C.file_state(old_exporter)[1] == captured.before.file[1]
	if not str(captured.before.file[0]).is_empty() and bool(captured.before.file[1]):
		unchanged_file = (
			FileAccess.get_sha256(str(captured.before.file[0])) == captured.before.file[2]
		)
	var no_audit: bool = C.calls(C.EXPORT_GUARD_LABEL) == captured.before.guards
	# Restore only ordinary routing/data, not state/generation. Generation selector is
	# terminal for this process; do not reuse its original command or repair its lifetime.
	match mutation:
		"owner":
			lab._ac02_issued_owner = issue
		"property":
			var replacement: Node = lab.get_meta("stadium_property")
			lab.set_meta("stadium_property", property)
			replacement.free()
		"match":
			lab._match_state = old_match
		"receipt":
			old_match.stadium = old_receipt
		"exporter":
			lab._record_export = old_exporter
		"array":
			lab._play_records = old_records
		"record_identity", "record_order", "count":
			old_records.assign(old_order)
		"revision":
			issue._manual_qc_dirty_revision = old_revision
		"export_path", "export_revision", "source_dirty":
			old_exporter.path = captured.metadata[0]
			old_exporter._revision = captured.metadata[1]
			old_exporter._source_dirty = captured.metadata[2]
		"field":
			lab._field_definition = old_field
	return {
		"ok":
		(
			not intact
			and no_audit
			and unchanged_file
			and replacement_untouched
			and writer.get("context_lost", false)
			and writer.get("error") == ERR_UNAUTHORIZED
			and after.saved == captured.before.telemetry.saved
			and not after.inflight
		),
		"mutation": mutation,
		"original_context_rejected": not intact,
		"output_window": "drift_" + mutation,
		"expected_output_lines": [],
		"actual_writer_refused_before_io": writer.get("context_lost", false),
		"global_revoked": issue.state == StadiumNpcAc02IssuedStateV1.Lifetime.REVOKED,
		"command_rejection_is_not_itself_global_revocation": true,
		"old_command_used_for_publication": false,
		"no_full_audit_or_publication": no_audit and unchanged_file,
		"generation_left_changed_for_disposal": mutation == "generation",
		"original_issue_generation": old_issue_generation,
		"guard_seam_control_not_callback_or_full_command_execution": true
	}


static func geometry_refusal(lab: PitchBatLab) -> Dictionary:
	var property: StadiumNpcPublicProperty = R._property(lab)
	var model: Node3D = property.objects["npc:AC-02:r1:SCORE-SMALL"]
	if model == null:
		return {"ok": false, "error": "Actual installed SCORE-SMALL witness missing."}
	var before: Dictionary = observation(lab)
	var pose: Transform3D = model.transform
	model.position.x += 0.01
	print("QC_COMMAND_WINDOW_BEGIN invalid_geometry")
	F.dump_records(lab)
	print("QC_COMMAND_WINDOW_END invalid_geometry")
	model.transform = pose
	var after: Dictionary = observation(lab)
	return {
		"ok":
		(
			after.file == before.file
			and after.telemetry.saved == before.telemetry.saved
			and after.telemetry.pending
			and not after.telemetry.inflight
			and not FileAccess.file_exists(lab._record_export.path + ".tmp")
			and after.guards - before.guards == 1
			and after.telemetry.state == StadiumNpcAc02IssuedStateV1.Lifetime.REVOKED
		),
		"output_window": "invalid_geometry",
		"expected_output_lines": [],
		"full_audit_calls": after.guards - before.guards,
		"global_revoked": after.telemetry.state == StadiumNpcAc02IssuedStateV1.Lifetime.REVOKED,
		"old_geometry_restored_only_for_disposal": true
	}


static func supported_revoke(lab: PitchBatLab) -> Dictionary:
	var prepared: Dictionary = capture_without_publication(lab)
	if not prepared.ok:
		return {"ok": false, "error": "Original native admission required before retirement."}
	var property: StadiumNpcPublicProperty = R._property(lab)
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	var body: StaticBody3D = property.boundary.bodies[0]
	var container: Node = body.get_parent()
	property.retire_installation("manual QC command supported writer control")
	container.remove_child(body)
	container.add_child(body)
	var refused_context: bool = not Q._intact(prepared.context, prepared.metadata)
	var writer: Dictionary = Q._persist(prepared.context, prepared.plan)
	print("QC_COMMAND_WINDOW_BEGIN supported_revoke")
	var outcome: int = Q.run(lab, true)
	var continued: bool = F.flush_pending_manual_records(lab)
	print("QC_COMMAND_WINDOW_END supported_revoke")
	var after: Dictionary = observation(lab)
	return {
		"ok":
		(
			refused_context
			and outcome == Q.Outcome.DENIED
			and not continued
			and writer.get("context_lost", false)
			and writer.get("error") == ERR_UNAUTHORIZED
			and issue.state == StadiumNpcAc02IssuedStateV1.Lifetime.REVOKED
			and issue.generation == 2
			and property.suspended
			and not property.issued
			and lab.has_meta("stadium_npc_runtime_interrupted")
			and after.file == prepared.before.file
			and after.telemetry.saved == prepared.before.telemetry.saved
			and after.guards == prepared.before.guards
		),
		"output_window": "supported_revoke",
		"expected_output_lines": [],
		"original_body_and_route_restoration_did_not_revive": refused_context,
		"global_revoked": true,
		"new_command_outcome": outcome
	}


static func failure_and_retry(
	lab: PitchBatLab, fault: String, retry_path: String, before_retry: Callable = Callable()
) -> Dictionary:
	var before: Dictionary = observation(lab)
	var lines: Array[String] = expected_lines(lab)
	print("QC_COMMAND_WINDOW_BEGIN io_terminal_", fault)
	var continued: bool = F.flush_pending_manual_records(lab)
	print("QC_COMMAND_WINDOW_END io_terminal_", fault)
	var first: Dictionary = observation(lab)
	var continued_again: bool = F.flush_pending_manual_records(lab)
	var second: Dictionary = observation(lab)
	print("QC_COMMAND_WINDOW_BEGIN io_f3_", fault)
	F.dump_records(lab)
	print("QC_COMMAND_WINDOW_END io_f3_", fault)
	var failed_f3: Dictionary = observation(lab)
	var failed_temp_exists: bool = FileAccess.file_exists(lab._record_export.path + ".tmp")
	var failed_status: String = "QC save failed. Records remain in Output."
	var retained: bool = (
		first.telemetry.pending
		and first.telemetry.saved == before.telemetry.saved
		and first.telemetry.terminal_attempted
		and not first.telemetry.inflight
		and first.file == before.file
		and first.metadata == before.metadata
		and failed_f3.file == before.file
		and failed_f3.metadata == before.metadata
		and second == first
		and failed_f3.telemetry.pending
		and failed_f3.telemetry.saved == before.telemetry.saved
		and failed_f3.status == failed_status
	)
	# Test fixture cleanup, not a command hook. No retry may run under a temporary
	# directory restriction; an unproven restore must stop before evidence is emitted.
	if before_retry.is_valid() and not bool(before_retry.call()):
		return {
			"ok": false, "inconclusive": true, "error": "Fault restoration failed before retry."
		}
	lab._record_export.path = retry_path
	print("QC_COMMAND_WINDOW_BEGIN io_retry_", fault)
	F.dump_records(lab)
	print("QC_COMMAND_WINDOW_END io_retry_", fault)
	var retried: Dictionary = observation(lab)
	return {
		"ok":
		(
			continued
			and continued_again
			and retained
			and first.guards - before.guards == 1
			and first.deep - before.deep == 1
			and failed_f3.guards - first.guards == 1
			and retried.guards - failed_f3.guards == 1
			and retried.telemetry.saved == before.telemetry.dirty
			and not retried.telemetry.pending
			and retried.telemetry.terminal_attempted
			and C.saved_records_match(lab)
		),
		"fault": fault,
		"native_filesystem_only": true,
		"temporary_file_exists_after_failed_f3": failed_temp_exists,
		"failed_path_and_revision_unchanged": first.metadata == before.metadata,
		"terminal_continuation_safe_despite_io_failure": continued,
		"terminal_latch_suppressed_duplicate_audit_and_io": second == first,
		"dirty_revision_retained_until_successful_explicit_retry": retained,
		"output_windows":
		[
			{"label": "io_terminal_" + fault, "lines": []},
			{"label": "io_f3_" + fault, "lines": lines},
			{"label": "io_retry_" + fault, "lines": lines}
		],
		"error_warning_requires_engine_log_review": true,
		"write_and_flush_separate_fault_claimed": false
	}
