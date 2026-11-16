extends Node
## Prototype: caller MUST lock every mutation/write before start until completed.
## Parent owns captured bytes and is sole slot writer. No worker-produced state is installed.
const Protocol = preload("async_save_protocol.gd")
signal completed(saved: bool, reason: String)
static var leased: bool = false
var running: bool = false
var committing: bool = false
var _pid: int = -1
var _token: String
var _folder: String
var _path: String
var _bytes: PackedByteArray
var _native: PackedByteArray
var _pending: PackedByteArray
var _old: PackedByteArray
var _old_exists: bool
var _request: Dictionary
var _guard: Callable
var _season: SeasonState
var _build: SeasonBuild
var _revision: int
var _started: int
var _last_poll: int = 0
var _supervision: PhysicalTestSupervision
var _start_attempted: bool = false
var _owns_lease: bool = false
var _cleanup_pending: bool = false

func configure_supervisor(callback: Callable) -> bool:
	if _start_attempted or _owns_lease or running or not callback.is_valid():
		return false
	_supervision = PhysicalTestSupervision.new()
	_supervision.callback = callback
	return true

func _context() -> Dictionary:
	return {"token": _token, "folder": _folder, "pid": _pid, "save_path": _path}


static func supported() -> bool:
	# Exported binaries retain synchronous saving until a reviewed packaged worker route exists.
	return OS.has_feature("editor") and PhysicalRoundProcess.supported()

func start(season: SeasonState, still_current: Callable) -> bool:
	if _start_attempted or leased or running or not is_inside_tree() or not supported() or not Protocol.standalone(season) \
		or not still_current.is_valid() or not still_current.call():
		return false
	if OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") == "1" and _supervision == null:
		return false
	_start_attempted = true # One coordinator owns at most one launch attempt.
	_guard = still_current
	_season = season
	_build = season.build
	_revision = _build.revision()
	_path = SeasonSave.path
	# Snapshot ONCE; expensive full replay lives only in the child.
	var data: Dictionary = SeasonSave.snapshot(season)
	if data.is_empty() or data.get("version") != ExpandedSeasonProgression.SEASON_VERSION:
		return false
	_native = var_to_bytes(data)
	_pending = var_to_bytes(season.physical.pending) if season.physical != null else PackedByteArray()
	_bytes = JSON.stringify(data, "", true, true).to_utf8_buffer()
	if _bytes.size() > Protocol.MAX_BYTES or _native.size() > Protocol.MAX_BYTES:
		return false
	_old_exists = FileAccess.file_exists(_path)
	if _old_exists:
		var old: Variant = Protocol.bytes_at(_path)
		if old == null:
			return false # Cannot capture exact old bytes: fail closed, do not overwrite.
		_old = old
	else:
		_old = PackedByteArray()
	var binding: Dictionary = Protocol.binding()
	if binding.is_empty():
		return false
	_token = Crypto.new().generate_random_bytes(16).hex_encode()
	_folder = PhysicalJobFiles.directory(_token)
	if DirAccess.make_dir_recursive_absolute(_folder) != OK:
		return false
	_request = {"version": 1, "token": _token, "binding": binding,
		"new_hash": Protocol.digest(_bytes), "native_hash": Protocol.digest(_native), "old_hash": Protocol.digest(_old), "old_exists": _old_exists}
	if not _write_bytes(_folder.path_join("new.json"), _bytes) \
		or not _write_bytes(_folder.path_join("new.variant"), _native) \
		or (_old_exists and not _write_bytes(_folder.path_join("old.json"), _old)) \
		or not PhysicalJobFiles.write(_folder.path_join("request.json"), _request):
		return false
	var worker: String = (get_script() as GDScript).resource_path.get_base_dir().path_join("async_save_worker.gd")
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", _folder.path_join("worker.log"), "--script", ProjectSettings.globalize_path(worker),
		"--", "--save-job=" + _token]
	# Lease exists BEFORE fallible external launch IPC. A -1 result may hide a child.
	leased = true
	_owns_lease = true
	_cleanup_pending = true
	_pid = (_supervision.launch(OS.get_executable_path(), args, _context()) if _supervision != null
		else OS.create_process(OS.get_executable_path(), args))
	if _pid <= 0:
		_finish(false, "Save child launch failed. Previous files preserved.")
		return false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started = Time.get_ticks_msec()
	running = true
	leased = true
	return true

func cancel() -> bool:
	if committing:
		return false
	if running or _pid > 0 or _cleanup_pending or _owns_lease:
		_finish(false, "Save cancelled. Unsaved result remains available; previous files preserved.")
	return not _cleanup_pending

func _exit_tree() -> void:
	cancel()

func _current() -> bool:
	return is_instance_valid(_season) and _season.build == _build and _build.revision() == _revision \
		and SeasonSave.path == _path and Protocol.standalone(_season) \
		and (var_to_bytes(_season.physical.pending) if _season.physical != null else PackedByteArray()) == _pending \
		and _guard.is_valid() and _guard.call()

func _process(_delta: float) -> void:
	if not running or Time.get_ticks_msec() - _last_poll < 100:
		return
	_last_poll = Time.get_ticks_msec()
	if not _current() or Time.get_ticks_msec() - _started > 300000:
		_finish(false, "Save owner changed or validation timed out. Retry before closing.")
		return
	var status: Dictionary = {}
	if _supervision != null:
		status = _supervision.status(_context())
		if status.is_empty():
			_finish(false, "Save supervisor status failed.")
			return
	if (_supervision.running if _supervision != null else OS.is_process_running(_pid)):
		return
	var exit_code: int = int(status.exit_code) if _supervision != null else OS.get_process_exit_code(_pid)
	if _supervision != null and (not status.normal_exit or status.raw_wait_status != 0):
		_finish(false, "Save worker did not exit normally.")
		return
	var response: Variant = PhysicalJobFiles.read(_folder.path_join("response.json"))
	var log_file := FileAccess.open(_folder.path_join("worker.log"), FileAccess.READ)
	if log_file == null or log_file.get_length() > 16 * 1024 * 1024:
		_finish(false, "Save worker log missing or exceeds 16 MiB.")
		return
	var log: String = log_file.get_as_text()
	log_file.close()
	if exit_code != 0 or log.contains("SCRIPT ERROR:") or log.contains("ERROR:") \
		or not response is Dictionary or not SeasonOwnership._keys(response,
		["version", "token", "binding", "new_hash", "native_hash", "old_hash", "old_exists", "old_valid"]) \
		or not response.old_valid is bool:
		_finish(false, "Save validation failed. Unsaved result remains available.")
		return
	var receipt: Dictionary = response.duplicate(true)
	receipt.erase("old_valid")
	if not ClubCareer.same(receipt, _request) or not ClubCareer.same(Protocol.binding(), _request.binding) \
		or not _current() or FileAccess.file_exists(_path) != _old_exists \
		or (_old_exists and FileAccess.get_sha256(_path) != _request.old_hash) \
		or Protocol.digest(_bytes) != _request.new_hash:
		_finish(false, "Save response became stale. Previous files preserved.")
		return
	# One FINAL fresh snapshot, not a cache or a second decode. Reject all serialized
	# state changes, including fields that do not increment the Build revision.
	var current_data: Dictionary = SeasonSave.snapshot(_season)
	if current_data.is_empty() or var_to_bytes(current_data) != _native \
		or JSON.stringify(current_data, "", true, true).to_utf8_buffer() != _bytes \
		or not _current():
		_finish(false, "Season changed while saving. Previous files preserved; retry is safe.")
		return
	# No signal, yield, cancellation or UI callback inside commit.
	committing = true
	if not _write_bytes(_path + ".tmp", _bytes):
		_finish(false, "Could not save season. Your current session is still available.")
		return
	if _old_exists and response.old_valid and DirAccess.copy_absolute(_path, _path + ".bak") != OK:
		_finish(false, "Could not back up the previous season save. Retry before closing.")
		return
	if DirAccess.rename_absolute(_path + ".tmp", _path) != OK:
		_finish(false, "Could not replace the season save. Retry before closing.")
		return
	_finish(true, "")

static func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok

func _stop_child() -> bool:
	if not _cleanup_pending:
		return true
	if _supervision != null:
		# launch() can set blocked with pid=-1 AFTER the broker creates a child.
		# Salvage by token/context, never by a positive local PID requirement.
		if not _supervision.attempted:
			return false
		if _supervision.stop_attempted:
			return false # A prior unconfirmed one-shot stop is not a new cleanup receipt.
		if _supervision.running or _supervision.blocked or _supervision.last.is_empty():
			return _supervision.stop(_context())
		# status() already supplied a validated terminal waitpid receipt.
		return not _supervision.last.running
	if _pid <= 0:
		# OS.create_process reports launch failure directly; no external IPC ambiguity.
		return true
	if OS.is_process_running(_pid):
		if OS.kill(_pid) != OK:
			return false
	return not OS.is_process_running(_pid)

func _finish(saved: bool, reason: String) -> void:
	var stopped: bool = _stop_child()
	if not stopped:
		saved = false
		reason = "Save child cleanup failed; writer remains locked. Supervisor intervention required."
	else:
		_pid = -1
		_cleanup_pending = false
		if _owns_lease:
			leased = false
			_owns_lease = false
	running = false
	committing = false
	SeasonSave.last_error = reason
	# Failed cleanup keeps this attempt's lease, even when the launch PID is unknown.
	# Do not clear supervisor identity or retry its one-shot stop after ambiguous IPC.
	completed.emit(saved, reason)
