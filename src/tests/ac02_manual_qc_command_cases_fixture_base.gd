extends "res://src/tests/ac02_manual_qc_active_components.gd"
## SOURCE-ONLY command controls. Reuses existing genuine issuance/component harness.
## Each selector is a fresh isolated process. No full game or natural-play claim.
const CC = preload("res://src/tests/ac02_manual_qc_command_controls.gd")
const Q = preload("res://src/labs/pitch_bat_lab/ac02_manual_qc_command_v1.gd")
const HISTORICAL_F3 = preload("res://src/tests/ac02_manual_qc_historical_feel_support.gd")
const COMMAND_CASES: Array[String] = [
	"native",
	"drift",
	"geometry",
	"revoke",
	"io_mkdir",
	"io_open",
	"io_rename",
	"opaque",
	"exporter",
	"reentry",
	"f3_drift",
	"terminal_drift",
	"warning_callbacks",
	"io_write_flush",
	"timing"
]
var _callback_events: Array[String] = []
var _warning_guard_held: bool = false
var _warning_reentry_outcome: int = -1
var _warning_reentry_unchanged: bool = false
var _warning_retire_guard_held: bool = false
var _fault_commands: Array[Dictionary] = []
var _mkdir_fault: Dictionary = {}
var _limit_fault: Dictionary = {}
var _fault_inconclusive: bool = false


class WarningProbe:
	extends Logger
	var action: Callable
	var calls: int = 0
	var messages: Array[String] = []

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		# Other threads never touch script fields. The observed QC push_warning is
		# synchronous on the main thread. Never print/push another log from this hook.
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			return
		if (
			error_type != Logger.ERROR_TYPE_WARNING
			or (
				not code.begins_with("QC export failed:")
				and not rationale.begins_with("QC export failed:")
			)
		):
			return
		calls += 1
		messages.append(code if code.begins_with("QC export failed:") else rationale)
		if action.is_valid():
			var once: Callable = action
			action = Callable()
			once.call()


func _callbacks() -> void:
	# This is explicitly constructed component provenance, not the natural P1-P4 sample.
	# The unchanged probe is completed through the ordinary finish_record boundary.
	var prior_path: String = _lab._record_export.path
	_lab._record_export.path = _output.path_join("absent-custom/records.json")
	var probe: PlayRecord = C.PROBE_RECORD.new()
	probe.play_number = _constructed + 1
	probe.mode = "manual_qc_constructed_custom_component"
	_lab._active_play_record = probe
	F.finish_record(_lab, &"component_record", 0)
	_constructed += 1
	_lab._record_export.path = prior_path
	if not _need(
		(
			_lab._play_records.back() == probe
			and probe.result == &"component_record"
			and _issue._manual_qc_opted_out
			and _issue.manual_qc_pending()
			and int(probe.get("serialize_calls")) > 0
		),
		"Ordinary custom completion provenance missing."
	):
		return
	var calls_before: int = int(probe.get("serialize_calls"))
	var before: Dictionary = CC.observation(_lab)
	var outcome: int = Q.run(_lab, true)
	if not _row(
		"custom_classification_before_callbacks",
		{
			"ok":
			(
				outcome == Q.Outcome.FALLBACK
				and int(probe.get("serialize_calls")) == calls_before
				and CC.observation(_lab) == before
			),
			"early_native_admission_executed_no_serializer": true
		}
	):
		return
	match _case:
		"reentry":
			_row("unchanged_callback_reentry", C.callback_reentry(_app, probe))
		"f3_drift":
			_row("unchanged_f3_exporter_drift", C.callback_session_drift(_lab, probe, "exporter"))
		"terminal_drift":
			_row(
				"unchanged_terminal_count_drift",
				C.terminal_callback_drift_repeated_refusal(_lab, probe, "count")
			)


func _drifts() -> void:
	# All selected comparisons happen before hot_intact. Stop if any unexpectedly
	# retires the original owner; do not restore state or use a revoked fixture.
	for mutation: String in [
		"owner",
		"property",
		"match",
		"receipt",
		"exporter",
		"array",
		"record_identity",
		"record_order",
		"count",
		"revision",
		"export_path",
		"export_revision",
		"source_dirty",
		"field",
		"generation"
	]:
		var result: Dictionary = CC.drift(_lab, mutation)
		if not _row("original_context_" + mutation, result):
			return
		if (
			mutation != "generation"
			and not _need(
				not result.global_revoked,
				"A pure context mismatch retired the fixture; no authority revival is attempted."
			)
		):
			return


func _exporter() -> void:
	var probe: PlayRecordExport = C.custom_exporter(_lab)
	if not _need(probe != null, "Original ACTIVE fixture required for custom exporter control."):
		return
	probe.path = _output.path_join("custom-exporter.json")
	# Diagnostic custom substitution copies one genuinely completed component record.
	# No match outcome, owner, completion, or authority is manufactured here.
	var original: PlayRecord = _lab._play_records[0]
	var custom: PlayRecord = C.PROBE_RECORD.new()
	for member: Dictionary in original.get_property_list():
		if int(member.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			custom.set(member.name, original.get(member.name))
	_lab._play_records[0] = custom
	custom.set("on_serialize", Callable(self, "_record_callback"))
	probe.set("on_save", Callable(self, "_exporter_callback"))
	var before: Dictionary = CC.observation(_lab)
	var classification: int = Q.run(_lab, true)
	var untouched: bool = (
		CC.observation(_lab) == before
		and int(probe.get("save_calls")) == 0
		and int(custom.get("serialize_calls")) == 0
		and _callback_events.is_empty()
	)
	print("QC_COMMAND_WINDOW_BEGIN custom_exporter")
	F.dump_records(_lab)
	print("QC_COMMAND_WINDOW_END custom_exporter")
	_row(
		"literal_custom_exporter",
		{
			"ok":
			(
				classification == Q.Outcome.FALLBACK
				and untouched
				and int(probe.get("save_calls")) == 1
				and int(custom.get("serialize_calls")) == 2
				and _callback_events == ["record.to_dict", "exporter.save"]
				and C.saved_records_match(_lab)
			),
			"native_admission_never_called_custom_exporter": untouched,
			"save_calls": int(probe.get("save_calls")),
			"events": _callback_events,
			"legacy_order": "Output serialization, exporter.save, file serialization"
		}
	)


func _fault_fail(reason: String) -> bool:
	_fault_inconclusive = true
	return _need(false, "Fault fixture inconclusive: " + reason)


func _fault_exec(binary: String, arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var code: int = OS.execute(binary, arguments, output, true)
	var response: String = ""
	for chunk: Variant in output:
		response += str(chunk)
	response = response.strip_edges()
	_fault_commands.append(
		{"binary": binary, "arguments": Array(arguments), "exit_code": code, "output": response}
	)
	return {"code": code, "output": response}


func _limit_read() -> Dictionary:
	var result: Dictionary = _fault_exec(
		"/usr/bin/prlimit",
		[
			"--pid",
			str(OS.get_process_id()),
			"--fsize",
			"--output",
			"SOFT,HARD",
			"--raw",
			"--noheadings"
		]
	)
	var parts: PackedStringArray = str(result.output).split(" ", false)
	if result.code != 0 or parts.size() != 2:
		return {}
	return {"soft": parts[0], "hard": parts[1]}


func _restore_limit_fault() -> bool:
	if _limit_fault.is_empty():
		return true
	var current: Dictionary = _limit_read()
	if current.is_empty() or current.hard != _limit_fault.original.hard:
		return false
	if current != _limit_fault.original:
		if current.soft != str(_limit_fault.cap):
			return false
		var restored: Dictionary = _fault_exec(
			"/usr/bin/prlimit",
			["--pid", str(OS.get_process_id()), "--fsize=" + str(_limit_fault.original.soft) + ":"]
		)
		if restored.code != 0:
			return false
		current = _limit_read()
	_limit_fault["restored"] = current == _limit_fault.original
	return bool(_limit_fault.restored)


func _fault_stat(path: String) -> Dictionary:
	var canonical: Dictionary = _fault_exec("/usr/bin/readlink", ["-e", "--", path])
	var info: Dictionary = _fault_exec("/usr/bin/stat", ["--format=%d %i %u %a", "--", path])
	if canonical.code != 0 or canonical.output != path or info.code != 0:
		return {}
	var parts: PackedStringArray = str(info.output).split(" ", false)
	if parts.size() != 4:
		return {}
	return {
		"path": path, "device": parts[0], "inode": parts[1], "owner": parts[2], "mode": parts[3]
	}


func _same_fault_directory(current: Dictionary) -> bool:
	return (
		not current.is_empty()
		and current.path == _mkdir_fault.path
		and current.device == _mkdir_fault.device
		and current.inode == _mkdir_fault.inode
		and current.owner == _mkdir_fault.owner
	)


func _restore_mkdir_fault() -> bool:
	if _mkdir_fault.is_empty():
		return true
	var current: Dictionary = _fault_stat(str(_mkdir_fault.path))
	if not _same_fault_directory(current):
		return false
	if current.mode != _mkdir_fault.mode:
		if current.mode != _mkdir_fault.armed_mode:
			return false  # Never overwrite unrelated permission drift.
		var restored: Dictionary = _fault_exec(
			"/usr/bin/chmod", [str(_mkdir_fault.mode), "--", str(_mkdir_fault.path)]
		)
		if restored.code != 0:
			return false
		current = _fault_stat(str(_mkdir_fault.path))
	var intact: bool = _same_fault_directory(current) and current.mode == _mkdir_fault.mode
	_mkdir_fault["restored"] = intact
	return intact


func _finish() -> void:
	# GDScript has no finally. All normal early returns converge here; the runner
	# independently restores the exact owned directory after abnormal child exit.
	# No result/profile persistence or teardown proceeds under an unproven limit.
	if not _restore_limit_fault() or not _restore_mkdir_fault():
		_fault_fail("Cleanup could not prove exact original state; external cleanup required.")
		print("QC_COMMAND_FAULT_RESTORE_REQUIRED")
		get_tree().quit(3)
		return
	if is_instance_valid(_app) and _issue != null:
		_need(
			(
				ClubCareer.same(SeasonSave.snapshot(_app.season), _season_snapshot)
				and FileAccess.get_sha256(SeasonSave.path) == _season_sha
			),
			"Command component changed durable season progress."
		)
	# Uniform diagnostic teardown. Never ask corrupt/revoked routing to close, flush,
	# settle, repair, or issue again; no successful production-close claim follows.
	if is_instance_valid(_app):
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
		"schema": "AC02-MANUAL-QC-COMMAND-CONTROLS-v1",
		"case": _case,
		"passed": not _failed,
		"failure": _failure,
		"rows": _rows,
		"profile": profile,
		"manifest_sha256_supplied_by_external_gate": _manifest,
		"pid": OS.get_process_id(),
		"user_data_dir": OS.get_user_data_dir(),
		"constructed_records": _constructed,
		"genuine_public_issuance": _issue != null,
		"natural_plays_claimed": 0,
		"full_game_qualified": false,
		"public_F3_key_qualified": false,
		"settled_close_qualified": false,
		"native_renderer_fps_speedup_qualified": false,
		"engine_receipt_requires_external_metadata": true,
		"fault_fixture_inconclusive": _fault_inconclusive,
		"owned_directory_fault": _mkdir_fault,
		"child_limit_fault": _limit_fault,
		"fault_native_commands": _fault_commands,
		"diagnostic_teardown_is_not_successful_production_close": true
	}
	var file: FileAccess = FileAccess.open(
		_output.path_join("command-component-result.json"), FileAccess.WRITE
	)
	if file == null:
		push_error("QC_COMMAND_FAILED evidence write failed")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(result, "\t", true, true) + "\n")
	file.close()
	print("QC_COMMAND_COMPLETE ", JSON.stringify({"case": _case, "passed": not _failed}))
	get_tree().quit(1 if _failed else 0)
func _arm_mkdir_fault() -> bool:
	var target: String = OS.get_user_data_dir()
	var qc: String = ProjectSettings.globalize_path("user://qc")
	var identity: Dictionary = _fault_exec("/usr/bin/id", ["-u"])
	var original: Dictionary = _fault_stat(target)
	if (
		OS.get_name() != "Linux"
		or OS.get_environment("AC02_FAULT_FIXTURE") != "mkdir"
		or target != _data_root.trim_suffix("/").path_join("godot/app_userdata/Wiffaltro")
		or original.is_empty()
		or identity.code != 0
		or original.owner != identity.output
		or FileAccess.file_exists(qc)
		or DirAccess.dir_exists_absolute(qc)
	):
		return _fault_fail("Owned canonical isolated directory and absent qc are required.")
	var external_original: Variant = JSON.parse_string(
		OS.get_environment("AC02_FAULT_DIRECTORY_RECEIPT")
	)
	if not external_original is Dictionary or external_original != original:
		return _fault_fail("Independent runner directory preimage did not match before arming.")
	var mode: int = 0
	var mode_text: String = str(original.mode)
	for index: int in range(mode_text.length()):
		var digit: String = mode_text.substr(index, 1)
		if not digit.is_valid_int() or digit.to_int() > 7:
			return _fault_fail("Original permission mode was not octal.")
		mode = mode * 8 + digit.to_int()
	if (mode & 146) == 0:  # 0222: a genuine removal of write bits is required.
		return _fault_fail("Original directory had no write bit to remove.")
	_mkdir_fault = original.duplicate()
	_mkdir_fault["armed_mode"] = String.num_int64(mode & ~146, 8)
	_mkdir_fault["restored"] = false
	# Durable before the mode change. The existing parent runner can restore only
	# this exact inode even if an unexpected script error prevents _finish.
	var ledger: FileAccess = FileAccess.open(
		_output.path_join("owned-directory-fault.json"), FileAccess.WRITE
	)
	if ledger == null:
		_mkdir_fault.clear()
		return _fault_fail("Could not write the exact-target restoration ledger.")
	ledger.store_string(JSON.stringify(_mkdir_fault) + "\n")
	ledger.flush()
	var ledger_error: Error = ledger.get_error()
	ledger.close()
	return _mkdir_fault_durable_ledger_checks(target, qc, ledger_error)


func _mkdir_fault_durable_ledger_checks(target: String, qc: String, ledger_error: Error) -> bool:
	if ledger_error != OK:
		_mkdir_fault.clear()
		return _fault_fail("Restoration ledger was not durable before arming.")
	var armed: Dictionary = _fault_exec("/usr/bin/chmod", ["a-w", "--", target])
	var current: Dictionary = _fault_stat(target)
	if (
		armed.code != 0
		or not _same_fault_directory(current)
		or current.mode != _mkdir_fault.armed_mode
	):
		_restore_mkdir_fault()
		return _fault_fail("Owned directory restriction was not proven.")
	# Independent literal save witness: directory failure is its only return before
	# assigning a generated path. This is not a fabricated guard seam.
	var oracle: PlayRecordExport = PlayRecordExport.new()
	oracle._revision = _lab._record_export._revision
	oracle._source_dirty = _lab._record_export._source_dirty
	var before: Array = CC.metadata(oracle)
	var error: Error = oracle.save(
		_lab._play_records, _lab._field_definition, _lab.get_meta("stadium_snapshot", {})
	)
	_mkdir_fault["literal_error"] = error
	_mkdir_fault["literal_metadata_unchanged"] = CC.metadata(oracle) == before
	_mkdir_fault["qc_absent_after_literal"] = (
		not FileAccess.file_exists(qc) and not DirAccess.dir_exists_absolute(qc)
	)
	if (
		error == OK
		or not _mkdir_fault.literal_metadata_unchanged
		or not _mkdir_fault.qc_absent_after_literal
	):
		_restore_mkdir_fault()
		return _fault_fail(
			"Permissions did not defeat literal native mkdir before metadata assignment."
		)
	return true


func _io() -> void:
	var fault: String = _case.trim_prefix("io_")
	match fault:
		"mkdir":
			if not _arm_mkdir_fault():
				return
			_lab._record_export.path = ""
		"open":
			_lab._record_export.path = _output.path_join("absent-parent/records.json")
		"rename":
			var destination: String = _output.path_join("occupied-final.json")
			if not _need(
				DirAccess.make_dir_absolute(destination) == OK, "Rename blocker directory failed."
			):
				return
			var blocker: FileAccess = FileAccess.open(
				destination.path_join("keep.txt"), FileAccess.WRITE
			)
			if not _need(blocker != null, "Rename blocker witness failed."):
				return
			blocker.store_string("Final destination is a nonempty directory.\n")
			blocker.close()
			_lab._record_export.path = destination

	var restore: Callable = Callable()
	var mkdir_logger: WarningProbe = null
	if fault == "mkdir":
		restore = Callable(self, "_restore_mkdir_fault")
		mkdir_logger = WarningProbe.new()
		OS.add_logger(mkdir_logger)
	var result: Dictionary = CC.failure_and_retry(
		_lab, fault, _output.path_join("successful-explicit-retry.json"), restore
	)
	if mkdir_logger != null:
		OS.remove_logger(mkdir_logger)
		var expected: String = (
			"QC export failed: %s" % error_string(int(_mkdir_fault.literal_error))
		)
		var same_error: bool = (
			mkdir_logger.calls == 2 and mkdir_logger.messages == [expected, expected]
		)
		result["literal_mkdir_error_matches_both_command_warnings"] = same_error
		result["warning_messages"] = mkdir_logger.messages
		result["ok"] = result.ok and same_error and bool(_mkdir_fault.restored)
	if result.get("inconclusive", false):
		_fault_fail("Directory restoration was not proven; no retry/result publication.")
		return
	_row("native_" + fault + "_retains_pending_and_retries", result)


func _opaque() -> void:
	var record: PlayRecord = _lab._play_records[0]
	for selector: String in ["pitch_disclosure", "frozen_launch", "stadium_contacts"]:
		match selector:
			"pitch_disclosure":
				record.pitch_disclosure = {"opaque": Vector2(1, 2)}
			"frozen_launch":
				record.frozen_launch = {"opaque": Vector3(1, 2, 3)}
			"stadium_contacts":
				record.stadium_contacts = [{"opaque": Vector2(3, 4)}]
		var before: Dictionary = CC.observation(_lab)
		var classified: int = Q.run(_lab, true)
		var no_new_work: bool = CC.observation(_lab) == before
		var lines: Array[String] = CC.expected_lines(_lab)
		print("QC_COMMAND_WINDOW_BEGIN opaque_", selector)
		F.dump_records(_lab)
		print("QC_COMMAND_WINDOW_END opaque_", selector)
		var after: Dictionary = CC.observation(_lab)
		if not _row(
			"literal_opaque_" + selector,
			{
				"ok":
				(
					classified == Q.Outcome.FALLBACK
					and no_new_work
					and after.guards - before.guards >= 4
					and C.saved_records_match(_lab)
				),
				"native_admission_did_not_serialize_publish_or_mutate": no_new_work,
				"literal_fallback_full_audits": after.guards - before.guards,
				"output_window": "opaque_" + selector,
				"expected_output_lines": lines
			}
		):
			return
		record.pitch_disclosure = {}
		record.frozen_launch = {}
		record.stadium_contacts = []
	# Unsafe-to-serialize forms only test early classification, never legacy JSON output.
	var cycle: Array = []
	cycle.append(cycle)
	var forms: Array[Dictionary] = [{"nonfinite": INF}, {1: "non-string-key"}, {"cycle": cycle}]
	for index: int in range(forms.size()):
		record.pitch_disclosure = forms[index]
		var before: Dictionary = CC.observation(_lab)
		var outcome: int = Q.run(_lab, true)
		if not _row(
			"bounded_reject_form_%d" % index,
			{
				"ok": outcome == Q.Outcome.FALLBACK and CC.observation(_lab) == before,
				"literal_unsafe_serialization_not_executed": true
			}
		):
			break
	record.pitch_disclosure = {}
	cycle.clear()


func _timing_state() -> Dictionary:
	# Called outside timed intervals. Compare bytes, not only their digest.
	var observed: Dictionary = CC.observation(_lab)
	observed.erase("issue")
	observed.erase("deep")
	observed.erase("guards")
	var record_ids: Array[int] = []
	for record: PlayRecord in _lab._play_records:
		record_ids.append(record.get_instance_id())
	observed["record_ids"] = record_ids
	observed["expected_lines"] = CC.expected_lines(_lab)
	observed["file_bytes"] = FileAccess.get_file_as_bytes(_lab._record_export.path)
	observed["temporary_exists"] = (
		FileAccess.file_exists(_lab._record_export.path + ".tmp")
		or DirAccess.dir_exists_absolute(_lab._record_export.path + ".tmp")
	)
	observed["no_active_record"] = _lab._active_play_record == null
	observed["match_phase"] = _lab._match_state.phase
	observed["tree_paused"] = get_tree().paused
	observed["active_manual"] = C.active_manual(_lab)
	return observed


func _timing_sample(
	label: String, historical: bool, measured: bool, context: Dictionary, entry: Dictionary
) -> Dictionary:
	if not Q._intact(context, context.metadata) or _timing_state() != entry:
		return {
			"ok": false,
			"error": "Original context or clean command-entry operands drifted.",
			"label": label
		}
	var guards: int = C.calls(C.EXPORT_GUARD_LABEL)
	var deep: int = C.calls(C.DEEP_LABEL)
	print("QC_COMMAND_WINDOW_BEGIN ", label)
	var cpu_before: Dictionary = PERF._cpu_sample()
	var started: int = Time.get_ticks_usec()
	if historical:
		HISTORICAL_F3.dump_records(_lab)
	else:
		F.dump_records(_lab)
	var stopped: int = Time.get_ticks_usec()
	var cpu_after: Dictionary = PERF._cpu_sample()
	print("QC_COMMAND_WINDOW_END ", label)
	var guard_delta: int = C.calls(C.EXPORT_GUARD_LABEL) - guards
	var deep_delta: int = C.calls(C.DEEP_LABEL) - deep
	var expected_audits: int = 4 if historical else 1
	var intact: bool = Q._intact(context, context.metadata)
	var after: Dictionary = _timing_state() if intact else {}
	var same_entry: bool = intact and after == entry
	var cpu_valid: bool = (
		cpu_before.get("available", false)
		and cpu_after.get("available", false)
		and int(cpu_before.get("ticks_per_second", 0)) > 0
		and cpu_before.get("ticks_per_second") == cpu_after.get("ticks_per_second")
		and int(cpu_after.get("user_ticks", -1)) >= int(cpu_before.get("user_ticks", 0))
		and int(cpu_after.get("system_ticks", -1)) >= int(cpu_before.get("system_ticks", 0))
	)
	var cpu_seconds: float = -1.0
	if cpu_valid:
		cpu_seconds = (
			float(
				(
					int(cpu_after.user_ticks)
					- int(cpu_before.user_ticks)
					+ int(cpu_after.system_ticks)
					- int(cpu_before.system_ticks)
				)
			)
			/ float(cpu_before.ticks_per_second)
		)
	return {
		"ok":
		(
			same_entry
			and cpu_valid
			and guard_delta == expected_audits
			and deep_delta == expected_audits
			and stopped > started
		),
		"label": label,
		"measured": measured,
		"historical": historical,
		"output_window": label,
		"expected_output_lines": entry.expected_lines,
		"original_context_and_command_entry_state_preserved": same_entry,
		"file_byte_status_metadata_record_order_and_telemetry_parity": same_entry,
		"entry_telemetry": entry.telemetry,
		"entry_metadata": entry.metadata,
		"entry_record_ids": entry.record_ids,
		"entry_status": entry.status,
		"expected_file_sha256": entry.file[2],
		"actual_file_sha256": after.get("file", ["", false, ""])[2],
		"full_audit_calls": guard_delta,
		"construction_comparisons": deep_delta,
		"wall_usec": stopped - started,
		"process_cpu_seconds": cpu_seconds,
		"cpu_before": cpu_before,
		"cpu_after": cpu_after,
		"wall_scope":
		(
			"Synchronous dump_records call including audits, serialization, Output and native I/O; "
			+ "excludes setup, assertions and evidence writes"
		),
		"cpu_scope":
		(
			"Bracketing /proc/self/stat process CPU across all threads with tick resolution and "
			+ "boundary-sampling overhead; not thread or per-audit CPU"
		),
		"external_log_output_parity_review_required": true,
		"public_F3_key_natural_play_renderer_FPS_speedup_claimed": false
	}


func _timing() -> void:
	# Headless synchronous component wall/CPU only, never renderer/input performance.
	var cpu: Dictionary = PERF._cpu_sample()
	if not _need(
		(
			DisplayServer.get_name() == "headless"
			and cpu.get("available", false)
			and int(cpu.get("ticks_per_second", 0)) > 0
			and _constructed == 2
			and _lab._play_records.size() == 2
		),
		"Timing needs headless, process CPU ticks and two native component records."
	):
		return
	# Warm B then A. B genuinely persists and acknowledges; no private revision edit.
	if not _row("timing_warm_B", CC.native_boundary(_lab, true, "timing_warm_B")):
		return
	var admission: Dictionary = Q._capture(_lab)
	if not _need(
		admission.get("outcome") == Q.Outcome.HANDLED,
		"Warm candidate did not leave the original eligible native context."
	):
		return
	var context: Dictionary = admission.context
	var entry: Dictionary = _timing_state()
	if not _need(
		(
			entry.telemetry.started
			and entry.telemetry.dirty == 2
			and entry.telemetry.saved == 2
			and not entry.telemetry.pending
			and not entry.telemetry.inflight
			and not entry.telemetry.opted_out
			and not entry.telemetry.terminal_attempted
			and not entry.temporary_exists
			and entry.file[1]
			and entry.no_active_record
			and entry.active_manual
			and not entry.tree_paused
			and Q._intact(context, context.metadata)
		),
		"Timing must begin with one genuinely saved, clean, unchanged native batch."
	):
		return
	if not _row("timing_warm_A", _timing_sample("timing_warm_A", true, false, context, entry)):
		return
	var labels: Array[String] = ["timing_A1", "timing_B1", "timing_B2", "timing_A2"]
	var historical: Array[bool] = [true, false, false, true]
	var samples: Array[Dictionary] = []
	# No await/frame/input between commands. Each must retain the same clean entry.
	for index: int in range(labels.size()):
		var sample: Dictionary = _timing_sample(
			labels[index], historical[index], true, context, entry
		)
		if not _row(labels[index], sample):
			return
		samples.append(sample)
	var baseline_wall: float = (float(samples[0].wall_usec) + float(samples[3].wall_usec)) / 2.0
	var candidate_wall: float = (float(samples[1].wall_usec) + float(samples[2].wall_usec)) / 2.0
	var baseline_cpu: float = (
		(float(samples[0].process_cpu_seconds) + float(samples[3].process_cpu_seconds)) / 2.0
	)
	var candidate_cpu: float = (
		(float(samples[1].process_cpu_seconds) + float(samples[2].process_cpu_seconds)) / 2.0
	)
	_row(
		"matched_headless_F3_timing",
		{
			"ok": true,
			"sample_order": labels,
			"baseline_mean_wall_usec": baseline_wall,
			"candidate_mean_wall_usec": candidate_wall,
			"baseline_mean_process_cpu_seconds": baseline_cpu,
			"candidate_mean_process_cpu_seconds": candidate_cpu,
			"paired_wall_reduction_usec":
			[
				samples[0].wall_usec - samples[1].wall_usec,
				samples[3].wall_usec - samples[2].wall_usec
			],
			"paired_process_cpu_reduction_seconds":
			[
				samples[0].process_cpu_seconds - samples[1].process_cpu_seconds,
				samples[3].process_cpu_seconds - samples[2].process_cpu_seconds
			],
			"baseline": "Literal historical F3 branch on the same qualified candidate runtime",
			"warm_order": ["candidate", "historical"],
			"same_genuine_active_fixture": true,
			"constructed_native_records": 2,
			"same_clean_dirty_and_saved_revision": 2,
			"descriptive_two_pairs_not_statistical_significance": true,
			"instrumentation_overhead_not_subtracted": true,
			"renderer": DisplayServer.get_name(),
			"os_cache_timestamp_and_clock_state_not_identical": true,
			"natural_play_F3_key_renderer_FPS_cold_launch_or_full_game_speedup_claimed": false
		}
	)


func _warning_callbacks() -> void:
	_lab._record_export.path = _output.path_join("absent-warning-parent/records.json")
	var logger: WarningProbe = WarningProbe.new()
	var before: Dictionary = CC.observation(_lab)
	logger.action = Callable(self, "_warning_reenter")
	OS.add_logger(logger)
	print("QC_COMMAND_WINDOW_BEGIN warning_reentry")
	# terminal=false is intentional: a latch must not suppress the second real failure.
	var first: int = Q.run(_lab, false, false)
	print("QC_COMMAND_WINDOW_END warning_reentry")
	OS.remove_logger(logger)
	var after_first: Dictionary = CC.observation(_lab)
	if not _row(
		"actual_warning_reentry_under_lock",
		{
			"ok":
			(
				first == Q.Outcome.HANDLED
				and logger.calls == 1
				and _warning_guard_held
				and _warning_reentry_unchanged
				and _warning_reentry_outcome == Q.Outcome.DENIED
				and after_first.guards - before.guards == 1
				and after_first.deep - before.deep == 1
				and after_first.telemetry.pending
				and not after_first.telemetry.inflight
				and not after_first.telemetry.terminal_attempted
				and after_first.telemetry.saved == before.telemetry.saved
				and after_first.file == before.file
				and C.active_manual(_lab)
			),
			"output_window": "warning_reentry",
			"expected_output_lines": [],
			"actual_logger_calls": logger.calls,
			"warning_messages": logger.messages.duplicate(),
			"guard_held_in_callback": _warning_guard_held,
			"nested_F3_no_output_io_audit_acknowledgment": _warning_reentry_unchanged
		}
	):
		return
	logger.action = Callable(self, "_warning_retire")
	OS.add_logger(logger)
	print("QC_COMMAND_WINDOW_BEGIN warning_retirement")
	var second: int = Q.run(_lab, false, false)
	var continued: bool = F.flush_pending_manual_records(_lab, false)
	print("QC_COMMAND_WINDOW_END warning_retirement")
	OS.remove_logger(logger)
	var after_second: Dictionary = CC.observation(_lab)
	_row(
		"actual_warning_retirement_denies_continuation",
		{
			"ok":
			(
				second == Q.Outcome.DENIED
				and not continued
				and logger.calls == 2
				and _warning_retire_guard_held
				and after_second.guards - after_first.guards == 1
				and after_second.deep - after_first.deep == 1
				and after_second.telemetry.pending
				and not after_second.telemetry.inflight
				and after_second.telemetry.saved == before.telemetry.saved
				and after_second.telemetry.state == StadiumNpcAc02IssuedStateV1.Lifetime.REVOKED
				and after_second.telemetry.generation == 2
				and after_second.file == before.file
			),
			"output_window": "warning_retirement",
			"expected_output_lines": [],
			"actual_logger_calls": logger.calls,
			"warning_messages": logger.messages.duplicate(),
			"guard_held_in_callback": _warning_retire_guard_held,
			"post_warning_result": second,
			"later_pending_flush_returned": continued,
			"global_revoked": true,
			"retirement_is_last_no_revival_attempt": true
		}
	)
