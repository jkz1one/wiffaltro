extends Node
## Test-only observation. Ordinary restore and one resume of a real retained checkpoint.
## No manufactured state, human replay, repeated report, or validator side effects.
# gdlint: disable=max-returns

const INPUT: String = "res://src/tests/fixtures/base-public-completed-pending.json"
const INPUT_SHA: String = "688611ea88162690c6da224ba2f7fbfc01f7b3c69fc0b3adb4104536fd3ee9b4"
const MAX_WALL_MSEC: int = 60000
const MAX_FRAMES: int = 10800
const MAX_SAMPLES: int = 24
const MAX_JSON_BYTES: int = 262144

var _app: SeasonApp
var _output: String = ""
var _runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _started: int = 0
var _samples: Array[Dictionary] = []
var _last_live: Dictionary = {}
var _failed_reason: String = ""
var _natural_reports: int = 0
var _admitted: bool = false
var _resumed: bool = false
var _status: String = "not_started"


func _ready() -> void:
	_started = Time.get_ticks_msec()
	var expected: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--base-observe-dir="):
			_output = argument.trim_prefix("--base-observe-dir=")
		elif argument.begins_with("--base-observe-runtime="):
			expected = argument.trim_prefix("--base-observe-runtime=")
		elif argument.begins_with("--base-observe-execution="):
			_execution = argument.trim_prefix("--base-observe-execution=")
		elif argument.begins_with("--base-observe-nonce="):
			_nonce = argument.trim_prefix("--base-observe-nonce=")
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if args.size() != 5 or not args.has("--physical-in-process") \
		or _runtime.length() != 64 or _runtime != expected \
		or _execution.length() != 64 or _nonce.length() != 32:
		print("BASE_PENDING_OBSERVATION refused source/run arguments")
		get_tree().quit(1)
		return
	await _observe()
	# Read before normal cancellation clears runner._lab and changes the pause text.
	var terminal: Dictionary = _sample("terminal") if is_instance_valid(_app) else {}
	var original_unchanged: bool = FileAccess.get_sha256(INPUT) == INPUT_SHA
	if is_instance_valid(_app):
		_app.round_ui.cancel()
		_app.queue_free()
	await TestAudioDrain.finish(get_tree())
	_write({"schema": "BASE-PENDING-OBSERVATION-v1", "pid": OS.get_process_id(),
		"runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"status": _status, "input_sha256": INPUT_SHA,
		"input_unchanged": original_unchanged, "terminal": terminal,
		"samples": _samples, "last_live": _last_live,
		"failed_reason": _failed_reason, "natural_reports_observed": _natural_reports,
		"wall_seconds": (Time.get_ticks_msec() - _started) / 1000.0,
		"diagnostic_only": true, "round_completion_qualified": false,
		"manual_input_qualified": false, "performance_qualified": false})
	print("BASE_PENDING_OBSERVATION status=", _status,
		" reports=", _natural_reports, " refusal=", _failed_reason)
	get_tree().quit(0 if original_unchanged and _resumed else 1)


func _observe() -> void:
	if not _output.is_absolute_path() or _output.is_empty() \
		or DirAccess.make_dir_recursive_absolute(_output) != OK \
		or not DirAccess.get_files_at(_output).is_empty() \
		or not DirAccess.get_directories_at(_output).is_empty():
		_status = "output_refused"
		return
	_admitted = true
	if FileAccess.get_sha256(INPUT) != INPUT_SHA \
		or FileAccess.get_file_as_bytes(INPUT).size() != 193427:
		_status = "input_refused"
		return
	SeasonSave.path = _output.path_join("public-season.json")
	PitchBatLabSettings.path = _output.path_join("public-settings.cfg")
	# Byte-copy only; the ordinary loader owns decoding and validation.
	if DirAccess.copy_absolute(INPUT, SeasonSave.path) != OK \
		or FileAccess.get_sha256(SeasonSave.path) != INPUT_SHA:
		_status = "copy_refused"
		return
	if Engine.physics_ticks_per_second != 60 or Engine.time_scale != 1.0 \
		or get_tree().paused:
		_status = "clock_refused"
		return
	await get_tree().process_frame
	_app = SeasonApp.new()
	get_tree().root.add_child(_app)
	if _app.season == null or _app.season.physical == null \
		or _app.season.physical.pending.is_empty():
		_status = "restore_refused"
		return
	var retained: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	if not ClubCareer.same(retained, SeasonSave.snapshot(_app.season)) \
		or _app.season.physical.pending.human.size() != 17 \
		or not _app.season.physical.pending.reports.is_empty() \
		or not _app.season.results.is_empty() or _app.lab != null \
		or _app.round_ui.process_jobs or _app.round_ui._working:
		_status = "restored_identity_refused"
		return
	_app.round_ui.runner.failed.connect(_on_failed)
	_app.round_ui.runner.finished.connect(_on_finished)
	_capture("restored_waiting")
	# Same method as the ordinary RESUME / RETRY action after loading the save.
	_resumed = true
	_app.round_ui.resume()
	_capture("after_resume")
	var next_sample: int = Time.get_ticks_msec() + 10000
	for frame: int in range(MAX_FRAMES):
		var row: Dictionary = _sample("observe")
		if not row.lab.is_empty() and row.lab.automation_present:
			_last_live = row.duplicate(true)
		if not _failed_reason.is_empty():
			_status = "runner_refused"
			return
		if not row.lab.is_empty() and row.lab.runtime_interrupted:
			_status = "runtime_lease_declined"
			return
		if not _app.round_ui._working:
			_status = "settled" if _app.season.physical.pending.is_empty() else "round_waiting"
			return
		if _natural_reports > 0:
			_status = "natural_report_observed"
			return
		if Time.get_ticks_msec() - _started >= MAX_WALL_MSEC:
			_status = "wall_window_ended_inconclusive"
			return
		if Time.get_ticks_msec() >= next_sample:
			_capture("progress")
			next_sample = Time.get_ticks_msec() + 10000
		await get_tree().physics_frame
	_status = "frame_window_ended_inconclusive"


func _on_failed(reason: String) -> void:
	_failed_reason = reason
	_capture("runner_failed")


func _on_finished(_report: Dictionary) -> void:
	# The existing UI persists the genuine report. Do not replay or synthesize it.
	_natural_reports += 1
	_capture("runner_finished")


func _capture(event: String) -> void:
	if _samples.size() < MAX_SAMPLES:
		var row: Dictionary = _sample(event)
		_samples.append(row)
		if not row.lab.is_empty() and row.lab.automation_present:
			_last_live = row.duplicate(true)
		print("BASE_PENDING_OPERANDS ", JSON.stringify(row, "", true, true))


func _sample(event: String) -> Dictionary:
	var ui: SeasonRoundUI = _app.round_ui
	var runner: PhysicalMatchRunner = ui.runner
	var pending: Dictionary = _app.season.physical.pending if _app.season != null \
		and _app.season.physical != null else {}
	return {"event": event, "wall_msec": Time.get_ticks_msec() - _started,
		"notice": _app.notice, "save_error": SeasonSave.last_error,
		"heading": ui.heading.text, "detail": ui.detail.text,
		"status_text": ui.status.text, "working": ui._working,
		"projection_fixture": ui._projection.get("fixture", {}).duplicate(true),
		"projection_error": ui._projection.get("error", ""),
		"result_saved": _app._result_saved,
		"pending_reports": pending.get("reports", []).size(),
		"runner_running": runner._running, "runner_elapsed": runner._elapsed,
		"runner_stalled": runner._stalled, "runner_progress": runner._progress,
		"process_jobs": ui.process_jobs, "process_runner_running": ui.process_runner.running,
		"tree_paused": get_tree().paused, "time_scale": Engine.time_scale,
		"physics_ticks": Engine.physics_ticks_per_second, "lab": _lab_operands(runner._lab)}


func _lab_operands(lab: PitchBatLab) -> Dictionary:
	if not is_instance_valid(lab):
		return {}
	var row: Dictionary = {"process_mode": lab.process_mode,
		"processing": lab.is_processing(), "physics_processing": lab.is_physics_processing(),
		"automation_present": lab._automation != null,
		"releases": lab._automation.releases.size() if lab._automation != null else -1,
		"plays": lab._play_records.size(), "throw_number": lab._throw_number,
		"runtime_interrupted": lab.get_meta("stadium_npc_runtime_interrupted", false),
		"runtime_restoring": lab.get_meta("stadium_npc_runtime_restoring", false),
		"public_bound": lab.get_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND, false),
		"property_present": false, "lease": {}}
	var property: StadiumNpcPublicProperty = lab.get_meta("stadium_property", null) \
		as StadiumNpcPublicProperty
	if is_instance_valid(property):
		row.property_present = true
		# Read cached operands only. Validation methods can mutate suspension state.
		row.lease = {"issued": property.issued, "suspended": property.suspended,
			"checking": property._checking, "cleaning": property._cleaning,
			"venue": property.venue_id, "inside_tree": property.is_inside_tree(),
			"queued_for_deletion": property.is_queued_for_deletion(),
			"process_mode": property.process_mode,
			"processing": property.is_processing(),
			"physics_processing": property.is_physics_processing()}
	var state: MatchState = lab._match_state
	if state != null:
		row.merge({"phase": state.phase, "plate_appearance": state.plate_appearance_number,
			"simulation_seconds": state.elapsed_seconds, "inning": state.inning,
			"top_half": state.top_half, "away": state.away_team.runs,
			"home": state.home_team.runs, "balls": state.balls, "strikes": state.strikes,
			"outs": state.outs, "last_event": state.last_event})
	return row


func _write(value: Dictionary) -> void:
	if not _admitted:
		return
	var text: String = JSON.stringify(value, "", true, true)
	if text.to_utf8_buffer().size() > MAX_JSON_BYTES:
		print("BASE_PENDING_OBSERVATION bounded output refused")
		return
	var file: FileAccess = FileAccess.open(_output.path_join("base-pending-observation.json"),
		FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
