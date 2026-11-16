extends "res://src/tests/ac02_startup_input_witness_controls.gd"
## Source-only combined PREPARING/QC bridge. No validation interposer or publication.
## Inherits all original controls, including the subsequent real camera-guard refusal.
const Q = preload("res://src/labs/pitch_bat_lab/ac02_manual_qc_command_v1.gd")
const CC = preload("res://src/tests/ac02_manual_qc_command_controls.gd")


func _readonly_and_alias_controls(attempt: RefCounted) -> void:
	super._readonly_and_alias_controls(attempt)
	var lab: PitchBatLab = attempt.lab
	var property: StadiumNpcPublicProperty = attempt.property
	if not _need(Q._profile_selected() and attempt.state == ATTEMPT.State.PREPARING
		and attempt.context() and lab.ac02_startup_pending() and attempt.issue == null
		and lab._ac02_issued_owner == null and property._ac02_issue == null
		and property._ac02_issue_pin == null and not lab._ac02_issued_history
		and lab._play_records.is_empty() and lab._active_play_record == null
		and lab._record_export.path.is_empty() and not DirAccess.dir_exists_absolute("user://qc"),
		"combined selected profile, genuine unpublished PREPARING owners and no QC file"):
		return
	var before: Dictionary = CC.observation(lab)
	var state_before: Array = _pending_state(attempt)
	var records: Array[PlayRecord] = lab._play_records
	var exporter: PlayRecordExport = lab._record_export
	var match_state: MatchState = lab._match_state
	var field: FieldDefinition = lab._field_definition
	var checkpoint_sha: String = FileAccess.get_sha256(SeasonSave.path)
	print("QC_COMMAND_WINDOW_BEGIN combined_pending_preparing")
	var admission: Dictionary = Q._capture(lab)
	var output_outcome: int = Q.run(lab, true)
	var terminal_outcome: int = Q.run(lab, false)
	PitchBatLabFeelSupport.dump_records(lab)
	var clean_flush: bool = PitchBatLabFeelSupport.flush_pending_manual_records(lab)
	print("QC_COMMAND_WINDOW_END combined_pending_preparing")
	var after: Dictionary = CC.observation(lab)
	var unchanged: bool = after == before and _pending_state(attempt) == state_before \
		and attempt.context() and attempt.state == ATTEMPT.State.PREPARING \
		and _app.lab == lab and attempt.lab == lab and attempt.property == property \
		and lab._ac02_startup_attempt == attempt and property._ac02_startup_attempt == attempt \
		and lab._match_state == match_state and lab._field_definition == field \
		and lab._record_export == exporter and is_same(lab._play_records, records) \
		and records.is_empty() and lab._active_play_record == null \
		and attempt.issue == null and lab._ac02_issued_owner == null \
		and property._ac02_issue == null and property._ac02_issue_pin == null \
		and not DirAccess.dir_exists_absolute("user://qc") \
		and FileAccess.get_sha256(SeasonSave.path) == checkpoint_sha
	var fallback: bool = admission.get("outcome", -1) == Q.Outcome.FALLBACK \
		and not admission.has("context") and output_outcome == Q.Outcome.FALLBACK \
		and terminal_outcome == Q.Outcome.FALLBACK
	_need(fallback and unchanged and clean_flush,
		"PREPARING QC fallback and pending F3 barrier preserve owners, records, files and state")
	# True is the inherited clean terminal no-op, never startup/settlement permission.
	_need(not StadiumNpcPublicRuntime.installed(lab)
		and not PitchBatLabFeelSupport._public_export_intact(lab)
		and not StadiumNpcAc02IssuedStateV1.before_settlement(lab)
		and lab.ac02_startup_pending() and not lab._ac02_startup_committed
		and not property._ac02_startup_committed and not property.issued
		and attempt.issue == null and lab._ac02_issued_owner == null,
		"clean terminal no-op grants no public installation, export, ACTIVE owner or settlement")
	_evidence["combined_pending_qc"] = {"ok": fallback and unchanged and clean_flush,
		"capture_and_run_fallback": fallback, "owners_records_files_pending_state_unchanged": unchanged,
		"terminal_clean_noop_returned_true": clean_flush, "startup_or_settlement_permission": false,
		"output_window": "combined_pending_preparing", "expected_output_lines": [],
		"no_QC_publication_requires_exact_log_window_review": true,
		"native_visual_acceptance": false, "performance_qualified": false}


func _pending_state(attempt: RefCounted) -> Array:
	return [attempt.state, attempt.reason, attempt.executing, attempt.setup_complete,
		attempt.lab._ac02_startup_enrolled, attempt.lab._ac02_startup_committed,
		attempt.property._ac02_startup_enrolled, attempt.property._ac02_startup_committed,
		attempt.property.issued, attempt.property.suspended, attempt.lab._ac02_issued_history]
