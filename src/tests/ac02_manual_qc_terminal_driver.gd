extends "res://src/tests/ac02_manual_qc_input_driver.gd"
## Separate synthetic-input scenario. The passed observer and input driver stay unchanged.
## No automation/phase/result edits, direct completion, export, close or resume calls.

const TERMINAL_CONTROLS = preload("res://src/tests/ac02_manual_qc_controls.gd")
const TERMINAL_PERF = preload("res://src/diagnostics/ac02_passive_attribution.gd")
const TERMINAL_PROVENANCE: String = "synthetic_input_manual_route_natural_terminal_failed_qc"
const TERMINAL_OVERALL_SECONDS: float = 2800.0
const GAME_SECONDS: float = 1200.0
const PROGRESS_SECONDS: float = 90.0
const METER_SECONDS: float = 5.0
const SETTLEMENT_SECONDS: float = 120.0
const CONTINUE_SECONDS: float = 180.0
const ROUND_SECONDS: float = 900.0

var _meter_releases: Array[Dictionary] = []
var _terminal_records: Array = []
var _terminal_record_ids: Array[int] = []
var _terminal_qc: Dictionary = {}
var _failed_qc_path: String = ""
var _settled_season: SeasonState
var _natural_terminal_seen: bool = false
var _round_complete: bool = false
var _measured_profile: Dictionary = {}
var _measurement_finished: bool = false
var _terminal_presentation: Dictionary = {}


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var started: int = Time.get_ticks_msec()
	_overall_deadline = started + int(TERMINAL_OVERALL_SECONDS * 1000.0)
	_stage_deadline = started + int(STARTUP_SECONDS * 1000.0)


func _ready() -> void:
	print(
		"SYNTHETIC_TERMINAL_QC: ",
		TERMINAL_PROVENANCE,
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
		"This terminal failure scenario requires the exact empty candidate manual fixture."
	):
		return
	_note("ready")
	_start_stage("two_natural_taken_pitches", TWO_PLAY_SECONDS)
	if not await _take_until(2):
		return
	if not await _wait_until(func() -> bool: return _observer._sample_complete):
		return
	await _terminal_observer_sample()


func _terminal_observer_sample() -> void:
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
		"finished_before_diagnostic_fault": true,
		"later_counters_inactive_non_evidence": true,
		"terminal_or_round_dispatch_count_claimed": false
	}
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
		"Fault destination must have an absent unique parent and no prior native QC path."
	):
		return
	# The ONLY gameplay-fixture mutation: the original native diagnostic I/O destination.
	_exporter.path = _failed_qc_path
	_note("native_missing_parent_fault_armed")
	_start_stage("natural_manual_game", GAME_SECONDS)
	if not await _play_to_natural_terminal():
		return
	_natural_terminal_seen = true
	_terminal_presentation["natural_GAME_END"] = _terminal_presentation_snapshot()
	_note("natural_GAME_END_no_more_gameplay_input")
	_start_stage("ordinary_terminal_settlement", SETTLEMENT_SECONDS)
	await _terminal_settlement_ticket()


func _terminal_settlement_ticket() -> void:
	if not await _wait_until(
		func() -> bool: return _app._result_recorded and not _app._ac02_settlement_ticket.is_empty()
	):
		return
	if not _retain_terminal_outputs():
		return
	# This helper is read-only. Its separate consuming direct-close control is NOT RUN.
	var settled: Dictionary = TERMINAL_CONTROLS.capture_failed_qc_settlement(_app)
	var human_args: Array = _app._ac02_settlement_ticket.human
	if not _require(
		(
			settled.get("ok", false)
			and _app._ac02_resume_authorized()
			and StadiumNpcYardTwoHumanEvidence.valid(human_args[16])
			and ClubCareer.same(human_args, _app.season.physical.pending.human)
			and _app.lab == _original_lab.get_ref()
			and _app.lab._automation == null
			and _app.lab._match_state == _original_match
			and _app.lab._ac02_issued_owner == _issue
			and _issue._settlement_report.is_empty()
			and _issue._manual_qc_saved_revision == 0
			and not _app._result_saved
			and _app._ac02_settled_manual_qc_close_allowed()
		),
		"Natural failed QC must leave the genuine saved/revoked original settlement continuable."
	):
		return
	_settled_season = _app.season
	_terminal_qc = TERMINAL_CONTROLS.telemetry(_issue)
	_checks["failed_qc_settlement"] = {
		"ok": true,
		"qc": _terminal_qc,
		"primary_sha256": settled.season_sha256,
		"file": settled.file,
		"attribution_counters_inactive_not_terminal_evidence": true
	}
	_note("failed_qc_genuine_settlement_retained")
	if not _timely():
		return
	# Enter may synchronously save, close and install the next ordinary physical fixture.
	_start_stage("public_CONTINUE", CONTINUE_SECONDS)
	await _terminal_successor_ticket()


func _terminal_successor_ticket() -> void:
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
	if (
		not await _navigate_to(_app._continue, get_viewport())
		or not await _key(KEY_ENTER, get_viewport())
	):
		return
	if not await _wait_until(
		func() -> bool: return _app.lab == null and not is_instance_valid(_original_lab.get_ref())
	):
		return
	if not _require(
		_app._ac02_settlement_ticket.is_empty() and _old_batch_unchanged(),
		"Public CONTINUE must dispose the original lab/ticket without acknowledging failed QC."
	):
		return
	_checks["ordinary_resume_closed_original"] = {
		"ok": true,
		"old_qc": TERMINAL_CONTROLS.telemetry(_issue),
		"old_file": _observer._file_state(_exporter),
		"no_second_qc_failure_and_one_discard_warning_require_external_log_review": true
	}
	_note("ordinary_resume_closed_original")
	_start_stage("ordinary_remaining_AI_round_jobs", ROUND_SECONDS)
	await _terminal_round_readback()


func _terminal_round_readback() -> void:
	if not await _wait_for_round():
		return
	if not _retain_and_check_round():
		return
	if not _timely():
		return
	_round_complete = true
	_native_route_complete = true
	_note("genuine_round_complete")
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
		"Unchanged observer summary must retain its genuine sample and natural terminal observation."
	):
		return
	_observer_summary_written = true
	_write_evidence()  # The unchanged observer owns TestAudioDrain and successful process exit.
	var terminal_summary: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(_observer._output.path_join("synthetic-terminal-driver.json"))
	)
	if not _require(
		(
			not _failed
			and terminal_summary is Dictionary
			and not terminal_summary.get("failed", true)
			and terminal_summary.get("round_complete", false)
			and terminal_summary.get("native_route_complete", false)
			and terminal_summary.get("observer_summary_written", false)
		),
		"Both retained summaries must show successful scenario completion before the final marker."
	):
		return
	print(
		"SYNTHETIC_TERMINAL_QC_COMPLETE: ",
		TERMINAL_PROVENANCE,
		". Read both summaries, warning log and process exit; not human/contact/FPS proof."
	)


func _play_to_natural_terminal() -> bool:
	var progress: String = ""
	var progress_deadline: int = Time.get_ticks_msec() + int(PROGRESS_SECONDS * 1000.0)
	while not _failed:
		if not _timely():
			return false
		var lab: PitchBatLab = _live()
		if not _require(
			(
				is_instance_valid(lab)
				and lab == _original_lab.get_ref()
				and lab._automation == null
				and lab._match_state == _original_match
			),
			"Original automation-null manual lab must survive until natural GAME_END."
		):
			return false
		# Do not weaken inherited ACTIVE _intact(). Terminal observations use separate proof.
		if _original_match.phase == MatchState.Phase.GAME_END:
			return true
		if not _require(
			_intact() and not get_tree().paused,
			"Live gameplay requires the unchanged original ACTIVE native session."
		):
			return false
		var current: String = (
			"%s:%s:%s:%s:%s:%s"
			% [
				_original_match.inning,
				_original_match.top_half,
				_original_match.phase,
				_original_match.plate_appearance_number,
				lab._throw_number,
				_records.size()
			]
		)
		if current != progress:
			progress = current
			progress_deadline = Time.get_ticks_msec() + int(PROGRESS_SECONDS * 1000.0)
			print("SYNTHETIC_TERMINAL_PROGRESS ", progress)
		if not await _terminal_native_pitch_frame(lab, progress, progress_deadline):
			return false
	return false


func _native_meter_pitch(lab: PitchBatLab) -> bool:
	var controller: PitchReleaseController = lab._release_controller
	var viewport: Viewport = get_viewport()
	var deadline: int = mini(_stage_deadline, Time.get_ticks_msec() + int(METER_SECONDS * 1000.0))
	_space_edge(true, viewport)
	await get_tree().process_frame
	var meter_visible: bool = is_instance_valid(lab) and lab._pitch_release_bar.is_visible_in_tree()
	# No _require/_timely while held: even timeout or identity loss must release the key first.
	while (
		is_instance_valid(lab)
		and lab._automation == null
		and lab._match_state == _original_match
		and controller.active
		and controller.elapsed_seconds < PitchReleaseController.IDEAL_RELEASE_SECONDS
		and Time.get_ticks_msec() <= deadline
	):
		await get_tree().physics_frame
	var elapsed: float = controller.elapsed_seconds
	var active: bool = controller.active
	var timed_out: bool = Time.get_ticks_msec() > deadline
	var auto_released: bool = not active and elapsed >= PitchReleaseController.AUTO_RELEASE_SECONDS
	_space_edge(false, viewport)
	await get_tree().process_frame
	_meter_releases.append(
		{
			"elapsed_before_key_up": elapsed,
			"active_before_key_up": active,
			"meter_visible_after_key_down": meter_visible,
			"native_auto_release_observed": auto_released,
			"timed_out": timed_out,
			"native_last_quality": controller.last_quality,
			"native_last_offset_seconds": controller.last_offset_seconds,
			"ideal_seconds": PitchReleaseController.IDEAL_RELEASE_SECONDS,
			"auto_seconds": PitchReleaseController.AUTO_RELEASE_SECONDS
		}
	)
	return (
		_require(
			(
				not timed_out
				and (meter_visible or auto_released)
				and (active or auto_released)
				and not controller.active
				and is_instance_valid(lab)
				and lab._automation == null
			),
			"Native meter pitch failed or timed out; Space release was dispatched before refusal."
		)
		and _timely()
	)


func _space_edge(pressed: bool, viewport: Viewport) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = false
	_events.append(
		{
			"stage": _stage,
			"usec": Time.get_ticks_usec(),
			"key": "Space",
			"keycode": KEY_SPACE,
			"pressed": pressed,
			"viewport_id": viewport.get_instance_id(),
			"focus": str(viewport.gui_get_focus_owner()),
			"meter_hold_edge": true
		}
	)
	viewport.push_input(event, true)
	_events.back()["dispatch_return_usec"] = Time.get_ticks_usec()


func _retain_terminal_outputs() -> bool:
	var ticket: Dictionary = _app._ac02_settlement_ticket
	var args: Variant = ticket.get("human")
	if not _require(
		(
			ticket.get("issue") == _issue
			and args is Array
			and args.size() == 17
			and args[16] is Dictionary
		),
		"Actual terminal ticket must expose its native human output."
	):
		return false
	for record: PlayRecord in _records:
		if not _require(
			record.get_script() == PlayRecord and record.result != &"pending",
			"Only naturally completed native records may be retained."
		):
			return false
		_terminal_records.append(record.to_dict().duplicate(true))
		_terminal_record_ids.append(record.get_instance_id())
	# Full precision actual producer output, retained BEFORE validators. Never live recapture.
	if (
		not _terminal_json("terminal-native-records-raw.json", _terminal_records)
		or not _terminal_json("terminal-human-raw.json", args[16].duplicate(true))
		or not _terminal_json(
			"terminal-chronology.json",
			{
				"human_args": args.duplicate(true),
				"fixture": ticket.get("fixture", {}).duplicate(true),
				"fixture_id": ticket.get("fixture_id"),
				"issue_id": _issue.get_instance_id(),
				"generation": _issue.generation,
				"state": _issue.state,
				"reason": _issue.reason,
				"qc": TERMINAL_CONTROLS.telemetry(_issue),
				"automated_settlement_report": _issue._settlement_report.duplicate(true),
				"automated_report_expected_absent_for_original_manual_route": true,
				"record_ids_in_order": _terminal_record_ids,
				"failed_path": _failed_qc_path
			}
		)
	):
		return false
	var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SeasonSave.path)
	var copy_path: String = _observer._output.path_join("original-pending-primary.json")
	var copy_file: FileAccess = FileAccess.open(copy_path, FileAccess.WRITE)
	if not _require(
		copy_file != null and not original_bytes.is_empty(),
		"Pending primary must be readable/copyable."
	):
		return false
	copy_file.store_buffer(original_bytes)
	copy_file.close()
	return _require(
		(
			FileAccess.get_file_as_bytes(copy_path) == original_bytes
			and FileAccess.get_file_as_bytes(SeasonSave.path) == original_bytes
		),
		"Retained original pending primary must be byte-identical before CONTINUE."
	)


func _old_batch_unchanged() -> bool:
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
	if (
		_records.size() != _terminal_records.size()
		or _exporter.path != _failed_qc_path
		or FileAccess.file_exists(_failed_qc_path)
		or FileAccess.file_exists(_failed_qc_path + ".tmp")
		or DirAccess.dir_exists_absolute(_failed_qc_path.get_base_dir())
	):
		return false
	for index: int in range(_records.size()):
		if (
			_records[index].get_instance_id() != _terminal_record_ids[index]
			or _records[index].to_dict() != _terminal_records[index]
		):
			return false
	return true


func _wait_for_round() -> bool:
	var next_heartbeat: int = Time.get_ticks_msec() + int(PROGRESS_SECONDS * 1000.0)
	while not (
		_app._result_saved
		and not _app.round_ui._working
		and _app.season.physical.pending.is_empty()
	):
		if (
			not _timely()
			or not _require(
				_app.round_ui._working,
				"Ordinary round stopped before publication: " + _app.round_ui.detail.text
			)
		):
			return false
		if Time.get_ticks_msec() >= next_heartbeat:
			print(
				"SYNTHETIC_TERMINAL_PROGRESS stage=ordinary_remaining_AI_round_jobs fixture=",
				_app.round_ui._projection.get("fixture", {}).get("id", -1),
				" completed_reports=",
				_app.season.physical.pending.get("reports", []).size()
			)
			next_heartbeat = Time.get_ticks_msec() + int(PROGRESS_SECONDS * 1000.0)
		await get_tree().process_frame
	return not _failed


func _retain_and_check_round() -> bool:
	var season_value: SeasonState = _app.season
	var snapshot: Dictionary = SeasonSave.snapshot(season_value)
	if (
		not _terminal_json("ordinary-successor-season-raw.json", snapshot)
		or not _terminal_json(
			"ordinary-successor-AI-reports-raw.json", season_value.physical.reports
		)
	):
		return false
	var restored: SeasonState = SeasonSave._read(SeasonSave.path)
	if not _require(
		(
			season_value != _settled_season
			and season_value.round_index == 1
			and season_value.results.size() == 3
			and season_value.player_results.size() == 1
			and season_value.physical.reports.size() == 2
			and season_value.physical.pending.is_empty()
			and _app.lab == null
			and _app._ac02_settlement_ticket.is_empty()
			and _old_batch_unchanged()
			and restored != null
			and ClubCareer.same(snapshot, SeasonSave.snapshot(restored))
		),
		"Ordinary remaining jobs must publish and durably read back the genuine successor round."
	):
		return false
	for index: int in range(2):
		var row: Dictionary = season_value.physical.reports[index]
		var fixture: Dictionary = SeasonVenues.fixture_for_id(season_value, index + 1)
		var expected: Dictionary = SeasonVenues.for_fixture(season_value, fixture)
		var report: Dictionary = row.report
		var family_ok: bool = (
			StadiumNpcPublicReport.matches(report, expected)
			if index == 0
			else StadiumNpcYardTwoReport.matches(report, expected)
		)
		if not _require(
			(
				int(row.fixture) == index + 1
				and PhysicalMatchReport.valid(report)
				and family_ok
				and report.property.manifest.id == (["AE-02", "AY-02"][index])
			),
			"Fresh ordinary AI report must bind its actual scheduled successor fixture."
		):
			return false
	_checks["ordinary_round_publication"] = {
		"ok": true,
		"primary_sha256": FileAccess.get_sha256(SeasonSave.path),
		"remaining_AI_reports": 2,
		"AI_jobs_are_not_manual_coverage": true,
		"old_qc": TERMINAL_CONTROLS.telemetry(_issue)
	}
	return true


func _terminal_json(filename: String, value: Variant) -> bool:
	var path: String = _observer._output.path_join(filename)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failed = true
		_failure = "Cannot retain terminal evidence: " + path
		push_error(_failure)
		get_tree().quit(2)
		return false
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	if not ok:
		_failed = true
		_failure = "Terminal evidence write failed: " + path
		push_error(_failure)
		get_tree().quit(2)
	return ok


func _inactive_counters_intact(profile: Dictionary) -> bool:
	# Equality confirms the declared measurement stop, not absence of later work.
	# Snapshot wall time and checkpoint stage can still advance after finish_session.
	if not _measurement_finished or not profile.get("errors", ["missing"]).is_empty():
		return false
	for key: String in [
		"entries",
		"completed",
		"open_scopes",
		"max_depth",
		"collector_bookkeeping_usec",
		"errors",
		"rows"
	]:
		# The observer summary is JSON-decoded; compare full-precision JSON values,
		# not native-int versus decoded-float container representation. No tolerance.
		if not ClubCareer.same({"value": profile.get(key)}, {"value": _measured_profile.get(key)}):
			return false
	return true


func _terminal_presentation_snapshot() -> Dictionary:
	# Passive fields only: no action/admission guard, director advance or input dispatch.
	var original: PitchBatLab = (
		_original_lab.get_ref() as PitchBatLab if _original_lab != null else null
	)
	var row: Dictionary = {
		"usec": Time.get_ticks_usec(), "original_lab_alive": is_instance_valid(original)
	}
	if not is_instance_valid(original):
		return row
	row["lab_id"] = original.get_instance_id()
	row["original_is_current_lab"] = is_instance_valid(_app) and _app.lab == original
	row["debug_paused"] = original._debug_paused
	row["lab_process_mode"] = original.process_mode
	row["runtime_interrupted"] = original.has_meta("stadium_npc_runtime_interrupted")
	var director: MatchPresentationDirector = original._match_presentation_director
	if director != null:
		row["director_mode"] = director.mode
		row["director_elapsed_seconds"] = director.elapsed_seconds
	if _issue != null:
		row["issue_id"] = _issue.get_instance_id()
		row["original_is_current_issue"] = original._ac02_issued_owner == _issue
		row["issue_state"] = _issue.state
		row["issue_generation"] = _issue.generation
		row["issue_paused"] = _issue._paused
		var captured_property: Variant = _issue._bindings_pin.get("property")
		if is_instance_valid(captured_property) and captured_property is StadiumNpcPublicProperty:
			var property: StadiumNpcPublicProperty = captured_property as StadiumNpcPublicProperty
			row["original_is_current_property"] = (
				original.get_meta("stadium_property", null) == property
			)
			row["property_issued"] = property.issued
			row["property_suspended"] = property.suspended
	return row


func _write_evidence() -> void:
	if not is_instance_valid(_observer) or _observer._output.is_empty():
		return
	_terminal_json(
		"synthetic-terminal-driver.json",
		{
			"schema": "AC02-SYNTHETIC-TERMINAL-QC-v1",
			"provenance": TERMINAL_PROVENANCE,
			"mode": _observer._mode,
			"manifest_sha256_supplied_by_external_gate": _observer._manifest,
			"current_stage": _stage,
			"failed": _failed,
			"failure": _failure,
			"overall_seconds": TERMINAL_OVERALL_SECONDS,
			"overall_deadline_msec": _overall_deadline,
			"stage_deadline_msec": _stage_deadline,
			"checks": _checks,
			"stages": _stages,
			"paired_input_events": _events,
			"native_meter_releases": _meter_releases,
			"terminal_presentation_observations": _terminal_presentation,
			"measurement_finished_after_initial_window": _measurement_finished,
			"later_attribution_counters_inactive_non_evidence": _measurement_finished,
			"natural_GAME_END_observed": _natural_terminal_seen,
			"round_complete": _round_complete,
			"native_route_complete": _native_route_complete,
			"observer_summary_written": _observer_summary_written,
			"physical_human_witness": false,
			"human_batting_contact_coverage": false,
			"renderer_or_FPS_evidence": false,
			"performance_speedup_claimed": false,
			"warning_and_no_second_QC_failure_log_review_required": true,
			"clean_QC_terminal_and_corrupted_settled_revision_controls": "NOT RUN"
		}
	)


func _terminal_native_pitch_frame(
	lab: PitchBatLab, progress: String, progress_deadline: int
) -> bool:
	if not _require(
		Time.get_ticks_msec() <= progress_deadline,
		"Natural game progress stalled at " + progress + "; no forced progression is allowed."
	):
		return false
	if (
		lab._match_presentation_director.mode == MatchPresentationDirector.Mode.IDLE
		and _original_match.phase == MatchState.Phase.PRE_PITCH
	):
		var batting: bool = _original_match.top_half != lab._player_home
		if batting and lab._awaiting_batter_confirm:
			if not await _key(KEY_SPACE, get_viewport()):
				return false
			if not _require(
				not lab._awaiting_batter_confirm, "Native batter-ready input was not consumed."
			):
				return false
		elif not batting and not lab._release_controller.active:
			if not _require(
				(
					not lab._field_setup_active
					and not lab._pitching_staff_active
					and not lab._display_menu_open
					and not lab.has_meta("loadout_open")
					and not lab.has_meta("player_inspection_open")
					and get_viewport().gui_get_focus_owner() == null
				),
				"Native pitching requires unblocked HUD and no GUI focus conflict."
			):
				return false
			if not await _native_meter_pitch(lab):
				return false
	await get_tree().process_frame
	return true
