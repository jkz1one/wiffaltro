extends Node
## Interactive observer only. It NEVER installs automation, submits input, finishes a
## record, edits a score/phase, creates an issuer, or manufactures settlement evidence.
## Runs unchanged on baseline and candidate: new telemetry is inspected dynamically.
const FIXTURE = preload("res://src/tests/ac02_public_fixture.gd")
const PERF = preload("res://src/diagnostics/ac02_passive_attribution.gd")
const I = preload("res://src/presentation/stadium/stadium_npc_ac02_issued_state_v1.gd")
const DEEP_LABEL: String = "stadium_npc_public_runtime._construction_same"
const GUARD_LABEL: String = "stadium_npc_public_runtime.installed_bound"
var _app: SeasonApp
var _lab: WeakRef
var _issue: WeakRef
var _match: WeakRef
var _exporter: WeakRef
var _records: Array[PlayRecord] = []
var _observed: Array[PlayRecord] = []
var _output: String = ""
var _data_root: String = ""
var _manifest: String = ""
var _mode: String = ""
var _ready_to_observe: bool = false
var _sample_complete: bool = false
var _sample: Dictionary = {}
var _errors: Array[String] = []
var _input_events: Array[Dictionary] = []
var _initial_file: Array = []
var _window_calls: Dictionary = {}
var _window_count: int = 0
var _window_started: int = 0
var _last_count: int = 0
var _snapshots: int = 0
var _terminal_seen: bool = false
var _was_live: bool = false


func _ready() -> void:
	# Observe F9/F10 even while the game uses its ordinary supported pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--manual-qc-output="):
			_output = argument.trim_prefix("--manual-qc-output=")
		elif argument.begins_with("--manual-qc-data-root="):
			_data_root = argument.trim_prefix("--manual-qc-data-root=")
		elif argument.begins_with("--manual-qc-manifest="):
			_manifest = argument.trim_prefix("--manual-qc-manifest=")
		elif argument.begins_with("--manual-qc-mode="):
			_mode = argument.trim_prefix("--manual-qc-mode=")
	if (
		_mode not in ["baseline", "candidate"]
		or _manifest.length() != 64
		or not _output.is_absolute_path()
		or not _data_root.is_absolute_path()
		or not OS.get_cmdline_user_args().has("--physical-in-process")
		or not OS.get_user_data_dir().begins_with(_data_root.trim_suffix("/") + "/")
	):
		push_error(
			(
				"Manual QC observer requires explicit baseline/candidate, manifest, fresh output and "
				+ "isolated user-data root."
			)
		)
		get_tree().quit(2)
		return
	if (
		DirAccess.make_dir_recursive_absolute(_output) != OK
		or not DirAccess.get_files_at(_output).is_empty()
		or not DirAccess.get_directories_at(_output).is_empty()
	):
		push_error("Manual QC output must be a fresh empty isolated directory.")
		get_tree().quit(2)
		return
	if Engine.physics_ticks_per_second != 60 or Engine.time_scale != 1.0 or get_tree().paused:
		push_error("Manual QC observer requires the ordinary unpaused fixed60 clock.")
		get_tree().quit(2)
		return
	SeasonSave.path = _output.path_join("manual-season.json")
	PitchBatLabSettings.path = _output.path_join("manual-settings.cfg")
	var prepared: SeasonState = FIXTURE.season()
	if prepared == null or not SeasonSave.save(prepared) or not PERF.begin_session(_output):
		push_error("Could not prepare the exact real fixture through ordinary SeasonSave.")
		get_tree().quit(2)
		return
	# Leave this test node's tree-entry callback before adding the real application.
	await get_tree().process_frame
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	_app.play_season_game()
	var lab: PitchBatLab = _app.lab
	if (
		not _active_manual(lab)
		or not lab._play_records.is_empty()
		or lab._record_export.get_script() != PlayRecordExport
		or not lab._managed_match
		or lab._player_home
		or not ClubCareer.same(_app.season.pending_fixture(), FIXTURE.fixture(_app.season))
	):
		push_error(
			"Ordinary public Play did not create the exact empty native ACTIVE manual fixture."
		)
		get_tree().quit(2)
		return
	_lab = weakref(lab)
	_issue = weakref(lab._ac02_issued_owner)
	_match = weakref(lab._match_state)
	_exporter = weakref(lab._record_export)
	_records = lab._play_records
	_initial_file = _file_state(lab._record_export)
	_window_count = lab._play_records.size()
	_last_count = _window_count
	PERF.checkpoint("manual_ready", _snapshot(), "actual_manual_two_play_window")
	_window_calls = _calls()
	_window_started = Time.get_ticks_usec()
	_ready_to_observe = true
	_was_live = true
	print(
		(
			"MANUAL_QC_READY: Play normally using real keyboard/controller input. No "
			+ "F3/reset/leave until TWO_PLAY_WINDOW is printed. F9 snapshots; F10 finishes only "
			+ "after ordinary leave/close."
		)
	)


func _input(event: InputEvent) -> void:
	if not _ready_to_observe:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_checkpoint("operator_snapshot")
			return
		if event.keycode == KEY_F10:
			_finish()
			return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_F3
		and not _sample_complete
	):
		_error_once("F3 interrupted the native two-play window.")
	# Observation is not input synthesis. This log alone cannot authenticate a human.
	if event.is_pressed() and _input_events.size() < 2048:
		var actions: Array[String] = []
		for action: String in ["match_advance", "pitch_release", "swing_contact", "swing_power"]:
			if event.is_action_pressed(action):
				actions.append(action)
		if not actions.is_empty() or (event is InputEventKey and event.keycode == KEY_F3):
			_input_events.append(
				{
					"usec": Time.get_ticks_usec(),
					"actions": actions,
					"f3": event is InputEventKey and event.keycode == KEY_F3
				}
			)


func _process(_delta: float) -> void:
	if not _ready_to_observe:
		return
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	if is_instance_valid(lab):
		if not _sample_complete and get_tree().paused:
			_error_once("The native two-play window was paused before completion.")
		if lab._automation != null:
			_error_once("Automation appeared; the actual-manual sample is invalid.")
		if Engine.physics_ticks_per_second != 60 or Engine.time_scale != 1.0:
			_error_once("Clock changed during manual observation.")
		if is_same(lab._play_records, _records):
			for index: int in range(_last_count, lab._play_records.size()):
				_observed.append(lab._play_records[index])
			_last_count = lab._play_records.size()
		elif not _sample_complete:
			_error_once("Record-array identity changed during the native sample.")
		if not _sample_complete and _observed.size() >= 2:
			_complete_sample(lab)
		if not _terminal_seen and lab._match_state.phase == MatchState.Phase.GAME_END:
			_terminal_seen = true
			_checkpoint("natural_game_end_observed")
	elif _was_live:
		_was_live = false
		_checkpoint("ordinary_close_observed")


func _complete_sample(lab: PitchBatLab) -> void:
	_sample_complete = true
	var ordered: bool = (
		is_same(lab._play_records, _records)
		and lab._match_state == _match.get_ref()
		and lab._ac02_issued_owner == _issue.get_ref()
		and lab._record_export == _exporter.get_ref()
		and lab._play_records.size() == _window_count + _observed.size()
	)
	var serialized: Array[Dictionary] = []
	for index: int in range(_observed.size()):
		var record: PlayRecord = _observed[index]
		ordered = (
			ordered
			and record.get_script() == PlayRecord
			and record.result != &"pending"
			and lab._play_records[_window_count + index] == record
			and lab._active_play_record != record
		)
		serialized.append(record.to_dict())
	var now: Dictionary = _calls()
	var no_file_change: bool = _file_state(lab._record_export) == _initial_file
	var telemetry: Dictionary = _telemetry(lab._ac02_issued_owner)
	var candidate_ok: bool = (
		no_file_change
		and int(now.deep) == int(_window_calls.deep)
		and int(now.guards) == int(_window_calls.guards)
		and bool(telemetry.get("pending", false))
		and not bool(telemetry.get("opted_out", true))
		and int(telemetry.get("dirty", -1)) == _observed.size()
		and int(telemetry.get("saved", -1)) == 0
	)
	var baseline_ok: bool = (
		not no_file_change
		and _saved_records_match(lab)
		and int(now.guards) >= int(_window_calls.guards) + 2 * _observed.size()
	)
	_sample = {
		"ok":
		(
			ordered
			and _active_manual(lab)
			and _errors.is_empty()
			and (candidate_ok if _mode == "candidate" else baseline_ok)
		),
		"mode": _mode,
		"observed_natural_records": _observed.size(),
		"ordered": ordered,
		"records": serialized,
		"no_file_change": no_file_change,
		"deep_comparisons": int(now.deep) - int(_window_calls.deep),
		"deep_dispatches": int(now.guards) - int(_window_calls.guards),
		"wall_usec_including_human_input_and_observer_overhead":
		Time.get_ticks_usec() - _window_started,
		"telemetry": telemetry,
		"manual_witness_required": true,
		"timing_speedup_qualified": false,
		"full_game_qualified": false
	}
	PERF.checkpoint("two_play_window", _sample, "manual_boundary_controls")
	print("TWO_PLAY_WINDOW: ", JSON.stringify(_sample))
	print(
		(
			"Now exercise real F3 pending + no-pending, another real play, cancel leave, and "
			+ "confirmed leave OR continue to natural GAME_END. Use F9 before/after each boundary."
		)
	)


func _checkpoint(label: String) -> void:
	_snapshots += 1
	PERF.checkpoint("%s_%02d" % [label, _snapshots], _snapshot(), "manual_boundary_controls")


func _snapshot() -> Dictionary:
	var lab: PitchBatLab = _app.lab if is_instance_valid(_app) else null
	var issue: StadiumNpcAc02IssuedStateV1 = (
		lab._ac02_issued_owner if is_instance_valid(lab) else null
	)
	var result: Dictionary = {
		"sample_complete": _sample_complete,
		"errors": _errors.duplicate(),
		"live_lab": is_instance_valid(lab),
		"app_result_recorded": _app._result_recorded,
		"app_result_saved": _app._result_saved,
		"settlement_ticket": not _app._ac02_settlement_ticket.is_empty(),
		"season_path": SeasonSave.path,
		"season_file": FileAccess.file_exists(SeasonSave.path),
		"season_sha256":
		FileAccess.get_sha256(SeasonSave.path) if FileAccess.file_exists(SeasonSave.path) else "",
		"trace_counts": _calls()
	}
	if is_instance_valid(lab):
		result.merge(
			{
				"lab_id": lab.get_instance_id(),
				"automation_null": lab._automation == null,
				"phase": lab._match_state.phase,
				"record_count": lab._play_records.size(),
				"active_record": lab._active_play_record != null,
				"export": _file_state(lab._record_export),
				"issue_id": issue.get_instance_id() if issue != null else 0,
				"issue_state": issue.state if issue != null else -1,
				"issue_generation": issue.generation if issue != null else -1,
				"qc": _telemetry(issue),
				"status": lab._status_label.text if lab._status_label != null else ""
			}
		)
	return result


func _finish() -> void:
	if is_instance_valid(_app.lab):
		print(
			(
				"MANUAL_QC: Use ordinary confirmed leave/postgame close before F10. No forced "
				+ "disposal is counted as acceptance."
			)
		)
		return
	_ready_to_observe = false
	var evidence: Dictionary = {
		"schema": "AC02-ACTUAL-MANUAL-QC-v1",
		"mode": _mode,
		"manifest_sha256_supplied_by_verified_external_gate": _manifest,
		"pid": OS.get_process_id(),
		"user_data_dir": OS.get_user_data_dir(),
		"sample": _sample,
		"input_event_observations": _input_events,
		"natural_game_end_seen": _terminal_seen,
		"errors": _errors,
		"profile": PERF.finish_session(),
		"actual_human_witness_required": true,
		"performance_speedup_claimed": false,
		"full_game_acceptance_claimed": false
	}
	var file: FileAccess = FileAccess.open(
		_output.path_join("manual-summary.json"), FileAccess.WRITE
	)
	if file == null:
		push_error("Manual evidence write failed.")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(evidence, "\t", true, true) + "\n")
	file.close()
	print(
		(
			"MANUAL_QC_EVIDENCE_WRITTEN: Review snapshots, engine log and actual-human witness "
			+ "before acceptance."
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _sample.get("ok", false) and _errors.is_empty() else 1)


func _active_manual(lab: PitchBatLab) -> bool:
	if not is_instance_valid(lab) or lab._automation != null or lab._ac02_issued_owner == null:
		return false
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	return (
		is_instance_valid(property)
		and property.has_ac02_issue()
		and property._ac02_issue == issue
		and property._ac02_issue_pin == issue
		and issue.state == I.Lifetime.ACTIVE
		and issue.generation == 1
		and property._ac02_generation == 1
		and issue._bindings_pin.get("lab") == lab
		and issue._bindings_pin.get("automation") == null
	)


func _telemetry(issue: StadiumNpcAc02IssuedStateV1) -> Dictionary:
	if issue == null:
		return {}
	var available: Dictionary = {}
	for property: Dictionary in issue.get_property_list():
		available[property.name] = true
	var mapping: Dictionary = {
		"started": "_manual_qc_started",
		"opted_out": "_manual_qc_opted_out",
		"dirty": "_manual_qc_dirty_revision",
		"saved": "_manual_qc_saved_revision",
		"terminal_attempted": "_manual_qc_terminal_attempted",
		"inflight": "_manual_qc_flushing",
		"terminal_count": "_manual_qc_terminal_count",
		"terminal_revision": "_manual_qc_terminal_revision"
	}
	var result: Dictionary = {}
	for key: String in mapping:
		if available.has(mapping[key]):
			result[key] = issue.get(mapping[key])
	if result.has_all(["dirty", "saved"]):
		result["pending"] = int(result.dirty) > int(result.saved)
	return result


func _calls() -> Dictionary:
	var result: Dictionary = {"deep": 0, "guards": 0}
	for row: Dictionary in PERF.snapshot().rows:
		if row.label == DEEP_LABEL:
			result.deep += int(row.calls)
		elif row.label == GUARD_LABEL:
			result.guards += int(row.calls)
	return result


func _file_state(exporter: PlayRecordExport) -> Array:
	var exists: bool = not exporter.path.is_empty() and FileAccess.file_exists(exporter.path)
	return [exporter.path, exists, FileAccess.get_sha256(exporter.path) if exists else ""]


func _saved_records_match(lab: PitchBatLab) -> bool:
	if lab._record_export.path.is_empty() or not FileAccess.file_exists(lab._record_export.path):
		return false
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(lab._record_export.path))
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


func _error_once(message: String) -> void:
	if not _errors.has(message):
		_errors.append(message)
		push_error(message)
