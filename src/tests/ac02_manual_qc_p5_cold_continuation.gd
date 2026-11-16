extends "res://src/tests/ac02_failedround02_continuation_test.gd"
## Separate cold continuation of the exact failed P5 retained primary, not a rerun.
## Override BOTH historical lifecycle functions; reuse writers and bound validators only.
## No Observer, manual match, retained report17, live issuer, or settlement ticket.

const P5_FILES: Dictionary = {
	"original-pending-primary.json":
	"b822e03de83f7c8b99f53a288336618824bae436c7f6edf495734f8c8801abd9",
	"manual-season.json": "b822e03de83f7c8b99f53a288336618824bae436c7f6edf495734f8c8801abd9",
	"terminal-human-raw.json": "f5e103d82aeeba7dd6fa786bd986ac34d9d8085a4369ecee026679bdb8f882e3",
	"terminal-chronology.json": "8dc8be24fa9fed1754330d1b98f97f5b1e890967f4395338866fd405dfc382e9",
	"synthetic-terminal-driver.json":
	"466c9f35e6e708b554c60cef67a0eaa30792f2716d1c48b1932b65672dc341d9"
}
const P5_INPUT_MANIFEST_SHA256: String = \
	"cb11f6138f1ad6aa0a920efb087552e1d71586167df72acab33f53a6c9115267"
const PREPARATION_SECONDS: float = 180.0
const ROUND_SECONDS: float = 900.0
const OVERALL_SECONDS: float = 2800.0
var _round_started: int = 0
var _activation_count: int = 0
var _last_progress_usec: int = 0
var _final_primary_sha256: String = ""
var _final_backup_sha256: String = ""
var _durable_readback: bool = false
var _raw_inputs: Dictionary = {}


func _ready() -> void:
	_started = Time.get_ticks_usec()
	var args: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.split("=", true, 1)
		if parts.size() == 2 and not args.has(parts[0]):
			args[parts[0]] = parts[1]
	_output = args.get("--ac02-cont-dir", "")
	_input = args.get("--ac02-cont-input", "")
	_input_manifest = args.get("--ac02-cont-files", "")
	_input_sha = args.get("--ac02-cont-files-sha", "")
	_execution = args.get("--ac02-cont-execution", "")
	_nonce = args.get("--ac02-cont-nonce", "")
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if _check(
		(
			OS.get_cmdline_user_args().size() == 8
			and args.size() == 7
			and OS.get_cmdline_user_args().has("--physical-in-process")
			and _runtime.length() == 64
			and args.get("--ac02-cont-runtime") == _runtime
			and _execution.length() == 64
			and _nonce.length() == 32
			and _input_sha == P5_INPUT_MANIFEST_SHA256
		),
		"exact source-bound cold P5 continuation arguments"
	):
		await _run()
	# Capture failure state before cancellation; cleanup is ONLY this new cold app.
	if _admitted:
		if not _write(
			"p5-cold-precleanup.json",
			{
				"checks": _checks,
				"failures": _failures,
				"failed": _failed,
				"io_failed": _io_failed,
				"round_error": _round_error,
				"new_ai_reports": _ai_reports,
				"new_human_starts": _human_starts,
				"current_save":
				(
					SeasonSave.snapshot(_app.season)
					if is_instance_valid(_app) and _app.season != null
					else {}
				)
			}
		):
			_settled = false
	if is_instance_valid(_app):
		_app.round_ui.cancel()
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
	if not _within_overall("after cold-app cleanup and audio drain"):
		_settled = false
	var success: bool = _settled and _durable_readback and _failures == 0 and not _io_failed
	var summary_written: bool = _write(
		"p5-cold-continuation-summary.json",
		{
			"schema": "AC02-MANUAL-QC-P5-COLD-CONTINUATION-v1",
			"pid": OS.get_process_id(),
			"runtime": _runtime,
			"execution": _execution,
			"nonce": _nonce,
			"checks": _checks,
			"failures": _failures,
			"failed": _failed,
			"io_failed": _io_failed,
			"round_error": _round_error,
			"settled": success,
			"retained_input_manifest_sha256": _input_sha,
			"retained_inputs": _raw_inputs,
			"predecessor": "natural-terminal03/run01",
			"predecessor_status": "failed",
			"original_failed_p5_passed": false,
			"original_live_cleanup_proved": false,
			"original_issuer_reused": false,
			"live_issuer_authority": false,
			"warm_owner_transition_qualified": false,
			"cold_continuation_only": true,
			"original_keyboard_navigation_fixed": false,
			"human_replayed": false,
			"manual_record17_as_automated_report17_claimed": false,
			"retained_automated_human_report_count": 0,
			"retained_human_play_count": 103,
			"retained_human_score": _terminal,
			"retained_ai_reports": 0,
			"new_human_starts": _human_starts,
			"new_ai_reports": _ai_reports.size(),
			"family_ids": _family_ids,
			"explicit_assignment_verified": _assignment_verified,
			"activation_route": "visible RESUME / RETRY pressed -> sole _activate connection",
			"activation_count": _activation_count,
			"durable_readback": _durable_readback,
			"durable_readback_scope":
			"normal primary reopen in this separate cold continuation process",
			"fresh_process_final_readback_claimed": false,
			"final_primary_sha256": _final_primary_sha256,
			"final_backup_sha256": _final_backup_sha256,
			"preparation_seconds_limit": PREPARATION_SECONDS,
			"round_seconds_limit": ROUND_SECONDS,
			"overall_seconds_limit": OVERALL_SECONDS,
			"wall_seconds": (Time.get_ticks_usec() - _started) / 1000000.0,
			"physical_human_witness": false,
			"manual_input_qualified": false,
			"renderer_or_fps_evidence": false,
			"performance_qualified": false
		}
	)
	var final_deadline_ok: bool = (Time.get_ticks_usec() - _started) / 1000000.0 <= OVERALL_SECONDS
	if not final_deadline_ok:
		_check(false, "cooperative overall deadline after final summary write and readback")
	print(
		(
			"AC02_P5_COLD_CONTINUATION checks=%d failures=%d settled=%s source=%s"
			% [_checks, _failures, success and summary_written and final_deadline_ok, _runtime]
		)
	)
	get_tree().quit(
		(
			0
			if (
				success
				and summary_written
				and final_deadline_ok
				and _failures == 0
				and not _io_failed
			)
			else 1
		)
	)


func _run() -> void:
	if not _check(
		(
			_output.is_absolute_path()
			and _input.is_absolute_path()
			and _input_manifest.is_absolute_path()
			and _output != _input
			and DirAccess.make_dir_recursive_absolute(_output) == OK
			and DirAccess.get_files_at(_output).is_empty()
			and DirAccess.get_directories_at(_output).is_empty()
		),
		"fresh isolated cold output"
	):
		return
	_admitted = true
	if not _check(
		(
			FileAccess.file_exists(_input_manifest)
			and FileAccess.get_sha256(_input_manifest) == _input_sha
			and ClubCareer.same(
				JSON.parse_string(FileAccess.get_file_as_string(_input_manifest)), P5_FILES
			)
		),
		"exact five-file P5 input manifest"
	):
		return
	var inputs: Dictionary = {}
	for name: String in P5_FILES:
		var path: String = _input.path_join(name)
		if not _check(
			FileAccess.file_exists(path) and FileAccess.get_sha256(path) == P5_FILES[name],
			"exact retained P5 bytes " + name
		):
			return
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not _check(bytes.size() > 0 and bytes.size() <= MAX_JSON_BYTES, "bounded input " + name):
			return
		if not _write_bytes("retained-" + name, bytes):
			return
		_raw_inputs[name] = {"file": "retained-" + name, "sha256": P5_FILES[name]}
		var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if not _check(value is Dictionary, "retained input JSON object " + name):
			return
		inputs[name] = value
	await _p5_cold_retained_inputs(inputs)


func _p5_cold_retained_inputs(inputs: Dictionary) -> void:
	if not _write("p5-cold-retained-inputs.json", _raw_inputs):
		return
	_pending = inputs["original-pending-primary.json"]
	var human: Dictionary = inputs["terminal-human-raw.json"]
	var chronology: Dictionary = inputs["terminal-chronology.json"]
	var failed: Dictionary = inputs["synthetic-terminal-driver.json"]
	if not _check(
		(
			_pending.version == 61
			and _pending.results.is_empty()
			and _pending.physical.reports.is_empty()
			and _pending.physical.pending.reports.is_empty()
			and _pending.physical.pending.human.size() == 17
			and ClubCareer.same(inputs["manual-season.json"], _pending)
			and ClubCareer.same(human, _pending.physical.pending.human[16])
			and ClubCareer.same(chronology.human_args, _pending.physical.pending.human)
			and human.away_runs == 0
			and human.home_runs == 11
			and human.plays.size() == 103
			and chronology.automated_report_expected_absent_for_original_manual_route
			and chronology.automated_settlement_report.is_empty()
			and chronology.qc.terminal_attempted
			and chronology.qc.terminal_count == 103
			and chronology.qc.saved == 0
			and chronology.state == 3
			and failed.failed
			and failed.natural_GAME_END_observed
			and not failed.round_complete
			and failed.current_stage == "public_CONTINUE"
			and (
				failed.failure
				== "Bounded native Tab/Down navigation did not reach the exact target button."
			)
			and failed.checks.failed_qc_settlement.ok
			and (
				failed.checks.failed_qc_settlement.primary_sha256
				== P5_FILES["original-pending-primary.json"]
			)
		),
		"exact natural 103-play manual terminal, failed QC and later P5 navigation failure; no prior AI"
	):
		return
	SeasonSave.path = _output.path_join("p5-cold-season.json")
	PitchBatLabSettings.path = _output.path_join("p5-cold-settings.cfg")
	if not _write_bytes(
		"p5-cold-season.json",
		FileAccess.get_file_as_bytes(_output.path_join("retained-original-pending-primary.json"))
	):
		return
	if not _check(
		(
			FileAccess.get_sha256(SeasonSave.path) == P5_FILES["original-pending-primary.json"]
			and not FileAccess.file_exists(SeasonSave.path + ".bak")
			and Engine.physics_ticks_per_second == 60
			and Engine.time_scale == 1.0
			and not get_tree().paused
		),
		"fresh byte-exact ordinary primary and fixed60 clock"
	):
		return
	await get_tree().process_frame
	_app = SeasonApp.new()
	_app.child_entered_tree.connect(_observe_app_child)
	get_tree().root.add_child(_app)
	if not _check(
		(
			_app.is_node_ready()
			and _app.season != null
			and _app.season.physical != null
			and ClubCareer.same(_pending, SeasonSave.snapshot(_app.season))
			and FileAccess.get_sha256(SeasonSave.path) == P5_FILES["original-pending-primary.json"]
			and _app.lab == null
			and _human_starts == 0
			and _app._ac02_settlement_ticket.is_empty()
			and not _app.round_ui.process_jobs
			and not _app.round_ui._working
		),
		"SeasonApp ready normally restores exact retained primary without manual lab or revived ticket"
	):
		return
	_assignment_verified = _assignment(_app.season)
	if not _check(_assignment_verified, "unchanged saved seed6 ordinal0 assignment3 golden map"):
		return
	await _p5_cold_ai_fixtures(human)


func _p5_cold_ai_fixtures(human: Dictionary) -> void:
	for fixture_id: int in range(3):
		var fixture: Dictionary = SeasonVenues.fixture_for_id(_app.season, fixture_id)
		if not _check(
			_binding(SeasonVenues.for_fixture(_app.season, fixture), _app.season, fixture_id),
			"original scheduled fixture binding " + str(fixture_id)
		):
			return
	if not _check(
		(
			StadiumNpcYardTwoHumanEvidence.valid(human)
			and StadiumNpcYardTwoHumanEvidence.pending_valid(
				_app.season, _app.season.physical.pending.human
			)
			and _binding(human.property, _app.season, 0)
		),
		"retained manual human evidence, not automated report17"
	):
		return
	_family_ids.append(human.property.manifest.id)
	_terminal = {"away": human.away_runs, "home": human.home_runs}
	var projection: Dictionary = SeasonRoundSettlement.project(_app.season)
	if not _check(
		(
			not projection.has("error")
			and projection.has("fixture")
			and ClubCareer.same(projection.fixture, {"id": 1, "round": 0, "away": 4, "home": 1})
			and ClubCareer.same(_pending, SeasonSave.snapshot(_app.season))
		),
		"ordinary projection requests AE02 fixture1 without mutating retained season"
	):
		return
	var forged: Dictionary = _pending.duplicate(true)
	forged.physical.pending.human[16].clear()
	if not _check(SeasonSave._decode(forged) == null, "stripped retained manual evidence refuses"):
		return
	var assignment: String = SeasonVenues.key(_app.season.npc_venues)
	var home: String = StadiumLayoutSnapshot.key(_app.season.home_property)
	var ledger: Dictionary = ClubPlayers.assets(_app.season.career).to_data()
	var round_ui: SeasonRoundUI = _app.round_ui
	_app.round_ui.runner.failed.connect(_observe_ai_failure)
	_app.round_ui.runner.finished.connect(_retain_ai_report)
	await get_tree().process_frame
	var action: Button = _app.round_ui.action
	var connections: Array[Dictionary] = action.get_signal_connection_list("pressed")
	if not _check(
		(
			_app.round_ui == round_ui
			and round_ui.app == _app
			and round_ui.get_parent() == _app
			and round_ui.get_script() == SeasonRoundUI
			and action == round_ui.action
			and action.get_class() == "Button"
			and action.get_script() == null
			and action.is_visible_in_tree()
			and not action.disabled
			and action.text == "RESUME / RETRY"
			and action.get_global_rect().has_area()
			and _app.round_ui.shade.visible
			and _app.round_ui.heading.text == "ROUND WAITING"
			and connections.size() == 1
			and connections[0].get("flags", -1) == 0
			and connections[0].get("signal") == Signal(action, "pressed")
			and connections[0].get("callable") == Callable(_app.round_ui, "_activate")
		),
		"real visible enabled RESUME / RETRY has its sole original pressed -> _activate connection"
	):
		return
	if (
		not _check(
			(Time.get_ticks_usec() - _started) / 1000000.0 <= PREPARATION_SECONDS,
			"cooperative preparation bound"
		)
		or not _within_overall("before activation")
	):
		return
	await _p5_cold_activation(human, assignment, home, ledger, round_ui, action, connections)


func _p5_cold_activation(
	human: Dictionary, assignment: String, home: String, ledger: Dictionary,
	round_ui: SeasonRoundUI, action: Button, connections: Array[Dictionary]
) -> void:
	if not _write(
		"p5-cold-activation.json",
		{
			"button_text": action.text,
			"visible": action.is_visible_in_tree(),
			"disabled": action.disabled,
			"pressed_connection_count": connections.size(),
			"pressed_connection_flags": 0,
			"native_button_script_null": true,
			"round_ui_identity_exact": true,
			"target": "SeasonRoundUI._activate",
			"activation": "pressed.emit",
			"physical_human_input": false,
			"retained_primary_sha256": P5_FILES["original-pending-primary.json"]
		}
	):
		return
	_round_started = Time.get_ticks_usec()
	_last_progress_usec = _round_started
	_activation_count += 1
	action.pressed.emit()
	for _frame: int in range(MAX_ROUND_FRAMES):
		if _io_failed or not _within_round("ordinary AI round"):
			return
		if not _check(_round_error.is_empty(), "ordinary AI job error: " + _round_error):
			return
		if _app.season.results.size() == 3 and _app.season.physical.pending.is_empty():
			break
		if not _check(
			(
				_app.round_ui == round_ui
				and _app.round_ui._working
				and _app.round_ui.heading.text != "ROUND WAITING"
				and not get_tree().paused
				and Engine.time_scale == 1.0
				and Engine.physics_ticks_per_second == 60
				and _app.lab == null
				and _human_starts == 0
				and _app._ac02_settlement_ticket.is_empty()
			),
			"ordinary cold round remains running with fixed60 and no human lab or issuer ticket"
		):
			return
		if Time.get_ticks_usec() - _last_progress_usec >= 90000000:
			_last_progress_usec = Time.get_ticks_usec()
			print(
				"AC02_P5_COLD_PROGRESS new_ai=",
				_ai_reports.size(),
				" fixture=",
				_app.round_ui._projection.get("fixture", {}).get("id", -1)
			)
		await get_tree().physics_frame
	if not _write("p5-cold-settlement-raw.json", SeasonSave.snapshot(_app.season)):
		return
	if not _check(
		(
			_app.season.results.size() == 3
			and _app.season.player_results.size() == 1
			and _app.season.physical.reports.size() == 2
			and _app.season.physical.pending.is_empty()
			and _app.season.round_index == 1
			and _app._result_saved
			and _ai_reports.size() == 2
			and _human_starts == 0
			and _app.lab == null
			and _app._ac02_settlement_ticket.is_empty()
			and _app.round_ui.runner._lab == null
			and _app.round_ui.runner._viewport == null
			and not _app.round_ui._working
			and _activation_count == 1
		),
		"exactly two ordinary AI jobs settle retained human round once and release their own labs"
	):
		return
	_p5_cold_ai_validation(human, assignment, home, ledger)


func _p5_cold_ai_validation(
	human: Dictionary, assignment: String, home: String, ledger: Dictionary
) -> void:
	for index: int in range(2):
		var ai: Dictionary = _ai_reports[index]
		if not _check(
			(
				_report_bound(ai, _app.season, index + 1)
				and ClubCareer.same(ai, _app.season.physical.reports[index].report)
				and ClubCareer.same(
					ai,
					JSON.parse_string(
						FileAccess.get_file_as_string(
							_output.path_join("p5-cold-ai-%d.json" % index)
						)
					)
				)
			),
			"durable bound raw AI report " + str(index)
		):
			return
		_family_ids.append(ai.property.manifest.id)
	var after: Dictionary = SeasonSave.snapshot(_app.season)
	if not _check(
		(
			_family_ids == ["AC-02", "AE-02", "AY-02"]
			and ClubCareer.same(_app.season.player_results[0].yard_evidence, human)
			and SeasonVenues.key(_app.season.npc_venues) == assignment
			and StadiumLayoutSnapshot.key(_app.season.home_property) == home
			and ClubCareer.same(ledger, ClubPlayers.assets(_app.season.career).to_data())
		),
		"retained manual evidence and paid home inventory remain exact across ordinary settlement"
	):
		return
	var settled_errors: Array[String] = StadiumNpcYardTwoPublicChecks.settled(_app.season, 0)
	if not _check(
		settled_errors.is_empty(), "settled replay and duplicate controls: " + str(settled_errors)
	):
		return
	if not _write("p5-cold-final-save.json", after):
		return
	for suffix: String in ["", ".bak"]:
		var path: String = SeasonSave.path + suffix
		if not _check(FileAccess.file_exists(path), "ordinary final save exists " + suffix):
			return
		if not _write_bytes(
			"p5-cold-final-primary.json" if suffix.is_empty() else "p5-cold-final-backup.json",
			FileAccess.get_file_as_bytes(path)
		):
			return
	_final_primary_sha256 = FileAccess.get_sha256(SeasonSave.path)
	_final_backup_sha256 = FileAccess.get_sha256(SeasonSave.path + ".bak")
	_p5_cold_durable_readback(after)


func _p5_cold_durable_readback(after: Dictionary) -> void:
	var restored: SeasonState = SeasonSave.restore()
	_durable_readback = (
		restored != null
		and SeasonSave.last_error.is_empty()
		and ClubCareer.same(after, SeasonSave.snapshot(restored))
	)
	if not _check(
		(
			_durable_readback
			and _final_primary_sha256 == FileAccess.get_sha256(SeasonSave.path)
			and _final_backup_sha256 == FileAccess.get_sha256(SeasonSave.path + ".bak")
			and ClubCareer.same(
				after, JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
			)
		),
		"actual final primary normally restores exact completed round without fallback or rewrite"
	):
		return
	if not _write(
		"p5-cold-durable-readback.json",
		{
			"schema": "AC02-P5-COLD-DURABLE-READBACK-v1",
			"primary_sha256": _final_primary_sha256,
			"backup_sha256": _final_backup_sha256,
			"restored_snapshot": SeasonSave.snapshot(restored),
			"exact": _durable_readback
		}
	):
		return
	for name: String in P5_FILES:
		if not _check(
			(
				FileAccess.get_sha256(_input.path_join(name)) == P5_FILES[name]
				and FileAccess.get_sha256(_output.path_join("retained-" + name)) == P5_FILES[name]
			),
			"original P5 and retained copy unchanged " + name
		):
			return
	if not _check(
		FileAccess.get_sha256(_input_manifest) == _input_sha, "P5 input manifest unchanged"
	):
		return
	_settled = (
		_within_round("after final evidence and normal durable readback")
		and _failures == 0
		and not _io_failed
	)


func _observe_app_child(node: Node) -> void:
	if node is PitchBatLab:
		_human_starts += 1


func _observe_ai_failure(reason: String) -> void:
	_round_error = reason


func _retain_ai_report(report: Dictionary) -> void:
	_ai_reports.append(report.duplicate(true))
	if not _check(_ai_reports.size() <= 2, "at most two new AI reports"):
		return
	if not _write("p5-cold-ai-%d.json" % (_ai_reports.size() - 1), report):
		_io_failed = true


func _within_overall(label: String) -> bool:
	return _check(
		(Time.get_ticks_usec() - _started) / 1000000.0 <= OVERALL_SECONDS,
		"cooperative overall deadline: " + label
	)


func _within_round(label: String) -> bool:
	return (
		_within_overall(label)
		and _check(
			(
				_round_started > 0
				and (Time.get_ticks_usec() - _round_started) / 1000000.0 <= ROUND_SECONDS
			),
			"cooperative round deadline: " + label
		)
	)


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		_failed.append(label)
		print("AC02_P5_COLD_CONTINUATION_FAIL ", label)
	return ok
