class_name PhysicalRoundProcess
extends Node
## One same-binary fixed-step job; owner remains responsive and alone may settle results.

const DynastyOwnerStore = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const DynastyCareerOwner = preload("res://src/gameplay/season/dynasty_career_owner.gd")

signal finished(report: Dictionary)
signal failed(reason: String)
signal diagnostic_finished(data: Dictionary)

var running: bool = false
var progress: Dictionary = {}
var _pid: int = -1
var _token: String = ""
var _folder: String = ""
var _key: String = ""
var _fixture: Dictionary = {}
var _candidate: SeasonState
var _started: int = 0
var _poll: int = 0
var _diagnostic: bool = false
# Opt-in source-editor instrumentation, never a gameplay/save format.
var _test_capture: Callable
var _test_enabled: bool = false
var _test_blocked: bool = false
var _test_capturing: bool = false
var _test_terminating: bool = false
var _start_attempted: bool = false
var _test_last_context: Dictionary = {}
var _test_supervision: PhysicalTestSupervision


func configure_physical_test(capture: Callable, supervisor: Callable = Callable()) -> bool:
	if _test_enabled or _start_attempted or running or not capture.is_valid() \
		or not OS.has_feature("editor") \
		or not OS.get_cmdline_user_args().has("--physical-test-retention"):
		return false
	_test_capture = capture
	if supervisor.is_valid():
		_test_supervision = PhysicalTestSupervision.new()
		_test_supervision.callback = supervisor
	_test_enabled = true
	return true


func physical_test_enabled() -> bool:
	return _test_enabled


func physical_test_can_advance() -> bool:
	if _test_enabled and (_test_capturing or _test_terminating):
		_test_blocked = true
	return not _test_enabled or not _test_blocked


# Called synchronously by the coordinator after its save, before starting another
# job, and again before final publication. No signal ordering or polling contract.
func capture_test_checkpoint(stage: String) -> bool:
	if not _test_enabled:
		return true
	if not physical_test_can_advance() or stage not in ["pending_checkpoint", "before_publish"]:
		_test_blocked = true
		return false
	var context: Dictionary = _test_last_context.duplicate(true)
	context["stage"] = stage
	return _capture_test(context)


func _capture_test(context: Dictionary) -> bool:
	if _test_capturing:
		_test_blocked = true
		return false
	_test_capturing = true
	var accepted: Variant = (
		_test_capture.call(context.duplicate(true)) if _test_capture.is_valid() else false
	)
	_test_capturing = false
	if not accepted is bool or not accepted:
		_test_blocked = true
	return not _test_blocked


static func supported() -> bool:
	return OS.get_name() in ["Linux", "Windows", "macOS"] and not OS.has_feature("web")


func _can_start() -> bool:
	if not physical_test_can_advance():
		return false
	if running:
		if _test_enabled:
			_fail("Physical test attempted an overlapping job.")
		return false
	if _test_enabled:
		_test_last_context = {}
		_fixture = {}
		_key = ""
		_folder = ""
	if not supported() or not is_inside_tree():
		return _start_failed("Physical process execution is unavailable.", false)
	return true


func start(season: SeasonState) -> bool:
	_start_attempted = true
	if not _can_start():
		return false
	var projection: Dictionary = SeasonRoundSettlement.project(season)
	if not projection.has("fixture"):
		return _start_failed("No physical fixture could be projected.", false)
	_candidate = projection.candidate
	_fixture = projection.fixture.duplicate(true)
	_key = SeasonPhysicalFixtures.request_key(_candidate, _fixture)
	_token = Crypto.new().generate_random_bytes(16).hex_encode()
	_folder = PhysicalJobFiles.directory(_token)
	if DirAccess.make_dir_recursive_absolute(_folder) != OK:
		return _start_failed("Physical job directory could not be created.", false)
	var request: Dictionary = request_for(season, _token, _key, int(_fixture.id))
	if request.is_empty() or not PhysicalJobFiles.write(_folder.path_join("request.json"), request) or not _heartbeat():
		return _start_failed("Physical job request or heartbeat could not be saved.")
	var arguments: PackedStringArray = ["--headless", "--fixed-fps", "60",
		"--log-file", _folder.path_join("worker.log")]
	var resource_root: String = ProjectSettings.globalize_path("res://")
	var source_editor: bool = OS.has_feature("editor") and not resource_root.is_empty()
	if source_editor:
		arguments.append_array(["--path", resource_root])
	_diagnostic = OS.get_cmdline_user_args().has("--physical-probes")
	if source_editor:
		var scene: String = "res://src/tests/physical_round_probe_worker.tscn" if _diagnostic else (
			"res://src/gameplay/simulation/physical_round_worker.tscn")
		arguments.append(scene)
	arguments.append_array(["--", "--physical-job=" + _token])
	if _diagnostic and not source_editor:
		arguments.append("--physical-probes")
	_pid = (_test_supervision.launch(OS.get_executable_path(), arguments,
		_job_context("job_started", "running")) if _test_supervision != null
		else OS.create_process(OS.get_executable_path(), arguments))
	if _pid <= 0:
		return _start_failed("Physical child process could not start.")
	running = true
	progress = {}
	_started = Time.get_ticks_msec()
	_poll = 0
	return _capture_started_job()


func _capture_started_job() -> bool:
	if not _test_enabled:
		return true
	_test_last_context = _job_context("job_started", "running")
	if not _capture_test(_test_last_context):
		return _start_failed("Physical test start capture failed.")
	return true


func _start_failed(reason: String, clean_default: bool = true) -> bool:
	if _test_enabled:
		_finish_job("start_failed", reason)
	elif clean_default:
		PhysicalJobFiles.clean(_token)
	return false


func cancel() -> void:
	if _test_enabled:
		_test_blocked = true
	if _test_terminating or _test_capturing:
		return
	if _test_enabled and _token.is_empty() and not running:
		return
	_finish_job("cancelled", "Physical job cancelled.")


func _exit_tree() -> void:
	if _test_enabled and not _token.is_empty():
		_finish_job("exited", "Physical process owner left the tree.")
	else:
		cancel()


# Retention is unconditional once enabled, including failed/invalid capture.
# Keep token, folder and PID intact through the synchronous capture. Successful
# completion does not call cancel, so it cannot capture twice or latch cancellation.
func _finish_job(outcome: String, reason: String = "", exit_code: int = -1) -> bool:
	if _test_terminating or _test_capturing:
		_test_blocked = true
		return false
	_test_terminating = true
	var kill_error: int = OK
	if _test_supervision != null:
		kill_error = _stop_supervised_job(outcome)
	elif _pid > 0 and OS.is_process_running(_pid):
		kill_error = OS.kill(_pid)
	running = false
	if _test_enabled:
		if outcome != "finished" or kill_error != OK \
			or _child_running():
			_test_blocked = true
		_test_last_context = _job_context("job_terminal", outcome, reason, exit_code, kill_error)
		if not _capture_test(_test_last_context):
			_test_blocked = true
	else:
		PhysicalJobFiles.clean(_token)
	_pid = -1
	_token = ""
	_candidate = null
	progress = {}
	_test_terminating = false
	if _test_supervision != null and not _test_blocked:
		var supervisor: Callable = _test_supervision.callback
		_test_supervision = PhysicalTestSupervision.new()
		_test_supervision.callback = supervisor
	return not _test_enabled or not _test_blocked


func _stop_supervised_job(outcome: String) -> int:
	if _test_supervision.running or _test_supervision.blocked:
		return OK if _test_supervision.stop(_job_context("job_terminal", outcome)) else FAILED
	return OK


func _job_context(
	stage: String, outcome: String, reason: String = "", exit_code: int = -1, kill_error: int = OK
) -> Dictionary:
	var context: Dictionary = {"stage": stage, "outcome": outcome, "reason": reason,
		"token": _token, "folder": _folder, "pid": _pid,
		"request_key": _key, "fixture": _fixture.duplicate(true),
		"exit_code": exit_code, "kill_error": kill_error,
		"child_running": _child_running()}
	if _test_supervision != null:
		context["provenance"] = "external_direct_owner_v1"
	return context


func _child_running() -> bool:
	if _test_supervision != null:
		return _test_supervision.running
	return _pid > 0 and OS.is_process_running(_pid)


func _process(_delta: float) -> void:
	if not running or Time.get_ticks_msec() - _poll < 100:
		return
	_poll = Time.get_ticks_msec()
	if Time.get_ticks_msec() - _started > 2400000:
		_fail("Physical job exceeded its wall-time limit. Retry keeps completed games.")
		return
	if not _heartbeat():
		_fail("Physical job heartbeat could not be saved.")
		return
	var supervised: Dictionary = {}
	if _test_supervision != null:
		supervised = _test_supervision.status(_job_context("job_terminal", "running"))
		if supervised.is_empty():
			_fail("Physical supervisor status failed; originals retained.")
			return
	if _child_running():
		var status: Variant = PhysicalJobFiles.read(_folder.path_join("status.json"))
		if status is Dictionary and SeasonOwnership._keys(status,
			["token", "inning", "top", "away", "home"]) and status.token == _token \
			and SeasonOwnership._whole(status.inning, 1, 9999) and status.top is bool \
			and SeasonOwnership._whole(status.away, 0, 9999) \
			and SeasonOwnership._whole(status.home, 0, 9999):
			progress = status.duplicate(true)
		return
	var exit_code: int = (int(supervised.exit_code) if _test_supervision != null
		else OS.get_process_exit_code(_pid))
	if _test_supervision != null and (not supervised.normal_exit or supervised.raw_wait_status != 0):
		_fail("Physical supervised worker did not exit normally with status zero.", exit_code)
		return
	var response: Variant = PhysicalJobFiles.read(_folder.path_join("response.json"))
	var log_path: String = _folder.path_join("worker.log")
	var log: String = (FileAccess.get_file_as_string(log_path)
		if FileAccess.file_exists(log_path) else "")
	if exit_code != 0 or log.contains("SCRIPT ERROR:") or log.contains("ERROR:") \
		or not _valid(response):
		_fail("Physical job failed validation; no score was published. Retry is safe.", exit_code)
		return
	_deliver_response(response, exit_code)


func _deliver_response(response: Dictionary, exit_code: int) -> void:
	# Validate diagnostic data without signalling before test capture.
	if _test_enabled:
		var data: Dictionary = _read_diagnostics() if _diagnostic else {}
		if _diagnostic and data.is_empty():
			_fail("Requested physical diagnostic evidence is missing or invalid.", exit_code)
			return
		if not _finish_job("finished", "", exit_code):
			failed.emit("Physical test capture failed; originals retained. No retry or publication.")
			return
		if _diagnostic:
			_test_terminating = true
			diagnostic_finished.emit(data)
			_test_terminating = false
	elif not _emit_diagnostics():
		_fail("Requested physical diagnostic evidence is missing or invalid.", exit_code)
		return
	var report: Dictionary = response.report.duplicate(true)
	print("PHYSICAL_PROCESS fixture=", _fixture.id, " wall_ms=", Time.get_ticks_msec() - _started)
	if not _test_enabled:
		cancel()
	if not physical_test_can_advance():
		failed.emit("Physical test was stopped before result delivery; originals retained.")
		return
	finished.emit(report)


func _emit_diagnostics() -> bool:
	if not _diagnostic:
		return true
	var data: Dictionary = _read_diagnostics()
	if data.is_empty():
		return false
	diagnostic_finished.emit(data)
	return true


func _read_diagnostics() -> Dictionary:
	var data: Variant = PhysicalJobFiles.read(_folder.path_join("diagnostics.json"))
	if not data is Dictionary or not SeasonOwnership._keys(data,
		["activations", "releases", "tape_frames", "plan_frames"]):
		return {}
	for value: Variant in data.values():
		if not SeasonOwnership._whole(value, 0, 10000000):
			return {}
	return data.duplicate(true)


func _valid(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["version", "token", "request", "fixture", "report"]) or value.version != 1 \
		or value.token != _token or value.request != _key or value.fixture != _fixture.id \
		or not PhysicalMatchReport.accepted(value.report, SeasonPhysicalFixtures.catalog_for(_candidate)):
		return false
	# The ordinary archive resolver also binds roster, workload, recipes and committed policies.
	var probe: SeasonPhysicalFixtures = SeasonPhysicalFixtures.new()
	probe.reports = [{"fixture": int(_fixture.id), "request": _key, "report": value.report}]
	return not probe.resolve(_candidate, _fixture).is_empty()


func _heartbeat() -> bool:
	return PhysicalJobFiles.write(_folder.path_join("heartbeat.json"), {"token": _token})


func _fail(reason: String, exit_code: int = -1) -> void:
	_finish_job("failed", reason, exit_code)
	failed.emit(reason)


# Version 2 transports only an exact selected Standard checkpoint. The child's
# authority comes from read-only current owner inspection, never the job grant.
static func request_for(season: SeasonState, token: String, key: String, fixture: int) -> Dictionary:
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	if snapshot.is_empty():
		return {}
	var result: Dictionary = {"version": 1, "token": token, "request": key,
		"fixture": fixture, "season": snapshot}
	if SeasonSave.OwnedDraftSave.version_in(snapshot.get("version"), [WorkingPitchDynastySave.VERSION, WorkingPitchDynastySave.BOUND_VERSION]):
		return WorkingPitchDynastySave.worker_request(season, token, key, fixture)
	if WorkingPitchProgression.is_version(snapshot.get("version"), ExpandedSeasonProgression.SEASON_VERSION):
		if not ExpandedSeasonProgression.season_envelope_valid(snapshot):
			return {}
		result.version = 11
		result["pitch_catalog"] = ExpandedSeasonCatalog.signature()
		return result
	if WorkingPitchProgression.is_version(snapshot.get("version"), WorkingPitchProgression.SEASON_VERSION):
		if not WorkingPitchProgression.season_envelope_valid(snapshot):
			return {}
		result.version = 7
		result["pitch_catalog"] = WorkingPitchCatalog.signature()
		return result
	if WorkingPitchProgression.is_version(snapshot.get("version"), WorkingPitchLeagueSave.VERSION):
		if WorkingPitchLeagueSave.parts(snapshot).is_empty():
			return {}
		result.version = WorkingPitchLeagueSave.WORKER_VERSION
		result["pitch_catalog"] = WorkingPitchCatalog.signature()
		return result
	if WorkingPitchProgression.is_version(snapshot.get("version"), WorkingPitchCareerSave.VERSION):
		if WorkingPitchCareerSave.parts(snapshot).is_empty():
			return {}
		result.version = WorkingPitchCareerSave.WORKER_VERSION
		result["pitch_catalog"] = WorkingPitchCatalog.signature()
		return result
	var league_home: bool = SeasonOwnership._whole(snapshot.get("version"), 91, 92)
	var shared_time: bool = SeasonSave.OwnedDraftSave.version_in(snapshot.get("version"), [95, 96])
	if not league_home and not shared_time and not SeasonOwnership._whole(snapshot.get("version"), 88, 89):
		return result
	var path: String = SeasonSave._dynasty_owner_path
	var binding: Dictionary = season._dynasty_owner_binding
	if path.is_empty() or binding.get("path") != path:
		return {}
	var absolute: String = DynastyOwnerStore._canonical(path)
	if FileAccess.file_exists(absolute + ".intent"):
		return {}
	var found: Dictionary = DynastyOwnerStore.inspect(absolute)
	var owner: Dictionary = found.get("owner", {})
	var selected: String = "dynasty" if snapshot.get("version") in [92, 96] else "other"
	# New95/96 headers retain JSON float versions; keep the old branch exact.
	if shared_time:
		selected = "dynasty" if snapshot.get("version") == 96 else "other"
	elif league_home:
		selected = "dynasty" if snapshot.get("version") == 92 else "other"
	var slot: Dictionary = owner.get(selected, {})
	if found.get("status") != "ready" or owner.get("selected") != selected \
		or binding.get("revision") != found.get("revision") \
		or binding.get("session_id") != slot.get("session_id") \
		or DynastyCareerOwner.validate_selected(owner, snapshot) == null:
		return {}
	result.version = (6 if snapshot.get("version") == 96 else 5) if shared_time else (4 if snapshot.get("version") == 92 else (3 if league_home else 2))
	result["owner"] = {"path": absolute, "owner_id": owner.owner_id,
		"revision": found.revision, "session_id": slot.session_id,
		"reference": slot.reference.duplicate(true)}
	return result


static func decode_request(input: Variant, token: String) -> SeasonState:
	if input is Dictionary and WorkingPitchProgression.is_version(input.get("version"), 11):
		return ExpandedSeasonProgression.decode_worker_request(input, token)
	if input is Dictionary and WorkingPitchProgression.is_version(input.get("version"), WorkingPitchLeagueSave.WORKER_VERSION):
		return WorkingPitchLeagueSave.decode_worker(input, token)
	if input is Dictionary and WorkingPitchProgression.is_version(input.get("version"), WorkingPitchDynastySave.WORKER_VERSION):
		return WorkingPitchDynastySave.decode_worker(input, token)
	if input is Dictionary and WorkingPitchProgression.is_version(input.get("version"), WorkingPitchCareerSave.WORKER_VERSION):
		return WorkingPitchCareerSave.decode_worker(input, token)
	if input is Dictionary and SeasonOwnership._whole(input.get("version"), 7, 7):
		return WorkingPitchProgression.decode_worker_request(input, token)
	if not input is Dictionary or not SeasonOwnership._whole(input.get("version"), 1, 6):
		return null
	var keys: Array = ["version", "token", "request", "fixture", "season"]
	if input.version >= 2:
		keys.append("owner")
	if not SeasonOwnership._keys(input, keys) or input.token != token \
		or not input.request is String or not SeasonOwnership._whole(input.fixture, 0, 32) \
		or not input.season is Dictionary:
		return null
	var standard: bool = SeasonOwnership._whole(input.season.get("version"), 88, 89)
	var league_home: bool = SeasonOwnership._whole(input.season.get("version"), 91, 92)
	var shared_time: bool = SeasonSave.OwnedDraftSave.version_in(input.season.get("version"), [95, 96])
	if input.version == 1:
		return null if standard or league_home or shared_time \
			or SeasonSave.OwnedDraftSave.version_in(input.season.get("version"), [WorkingPitchDynastySave.VERSION, WorkingPitchDynastySave.BOUND_VERSION]) \
			or WorkingPitchProgression.is_version(input.season.get("version"), ExpandedSeasonProgression.SEASON_VERSION) \
			or WorkingPitchProgression.is_version(input.season.get("version"), WorkingPitchProgression.SEASON_VERSION) \
			or WorkingPitchProgression.is_version(input.season.get("version"), WorkingPitchCareerSave.VERSION) \
			or WorkingPitchProgression.is_version(input.season.get("version"), WorkingPitchLeagueSave.VERSION) \
			else SeasonSave._decode(input.season)
	# Reject malformed nested markers before type-sensitive numeric pair comparisons.
	if not standard and not league_home and not shared_time:
		return null
	if (input.version == 2 and not standard) or (input.version == 3 and input.season.get("version") != 91) or (input.version == 4 and input.season.get("version") != 92) \
		or (input.version == 5 and input.season.get("version") != 95) or (input.version == 6 and input.season.get("version") != 96) \
		or not input.owner is Dictionary or not SeasonOwnership._keys(input.owner,
		["path", "owner_id", "revision", "session_id", "reference"]):
		return null
	var context: Dictionary = input.owner
	if not context.path is String or not context.path.is_absolute_path() \
		or context.path != DynastyOwnerStore._canonical(context.path) \
		or FileAccess.file_exists(context.path + ".intent"):
		return null
	var found: Dictionary = DynastyOwnerStore.inspect(context.path)
	var owner: Dictionary = found.get("owner", {})
	var selected: String = "dynasty" if input.version in [4, 6] else "other"
	# Full request/version pairing above validates the numeric discriminator.
	if shared_time:
		selected = "dynasty" if input.version == 6 else "other"
	elif league_home:
		selected = "dynasty" if input.version == 4 else "other"
	var slot: Dictionary = owner.get(selected, {})
	if found.get("status") != "ready" or owner.get("selected") != selected \
		or owner.get("owner_id") != context.owner_id or found.get("revision") != context.revision \
		or slot.get("session_id") != context.session_id \
		or not ClubCareer.same(slot.get("reference"), context.reference):
		return null
	var season: SeasonState = DynastyCareerOwner.validate_selected(owner, input.season)
	if season == null:
		return null
	# This binding is derived from the inspected committed owner, not serialized
	# job binding. No restore, repair, transaction or save is performed here.
	SeasonSave._dynasty_owner_path = context.path
	SeasonSave._bind_owner_season(season, found)
	return season
