extends RefCounted
## Isolated diagnostic only. No game objects, listeners, return-value inspection,
## caches, timers, awaits or source approval. Never used to authorize gameplay.
## Exact synchronous bodies stay in per-file uniquely named implementation methods.
## Wall spans are inclusive; exclusive subtracts immediate instrumented children.
## Instrumentation overhead remains present. CPU is stage/process-only, not per scope.

const MAX_ENTRIES: int = 2000000
const MAX_DEPTH: int = 128
static var _used: bool = false
static var _active: bool = false
static var _output: String = ""
static var _stage: String = "unstarted"
static var _started: int = 0
static var _sequence: int = 0
static var _entries: int = 0
static var _completed: int = 0
static var _overhead_usec: int = 0
static var _max_depth: int = 0
static var _stack: Array[Dictionary] = []
static var _rows: Dictionary = {}
static var _errors: Array[String] = []


static func begin_session(output: String) -> bool:
	if _used or not output.is_absolute_path() or not DirAccess.dir_exists_absolute(output):
		return false
	_used = true
	_active = true
	_output = output
	_stage = "retained_input"
	_started = Time.get_ticks_usec()
	return checkpoint("session_started", {}, "retained_input")


static func enter(label: String) -> int:
	if not _active:
		return -1
	var start: int = Time.get_ticks_usec()
	if _entries >= MAX_ENTRIES or _stack.size() >= MAX_DEPTH:
		_fault("collector bound exceeded")
		return -1
	_entries += 1
	var parent: String = "ROOT" if _stack.is_empty() else str(_stack.back().label)
	var key: String = _stage + "|" + parent + "|" + label
	if not _rows.has(key):
		_rows[key] = {
			"stage": _stage,
			"parent": parent,
			"label": label,
			"calls": 0,
			"completed": 0,
			"inclusive_usec": 0,
			"exclusive_usec": 0,
			"minimum_usec": -1,
			"maximum_usec": 0
		}
	_rows[key].calls += 1
	_stack.append({"token": _entries, "key": key, "label": label, "start": start, "child_usec": 0})
	_max_depth = maxi(_max_depth, _stack.size())
	_overhead_usec += Time.get_ticks_usec() - start
	return _entries


static func leave(token: int) -> void:
	if token < 0:
		return
	var stopped: int = Time.get_ticks_usec()
	if _stack.is_empty() or _stack.back().token != token:
		_fault("unbalanced synchronous scope")
		return
	var frame: Dictionary = _stack.pop_back()
	var duration: int = stopped - int(frame.start)
	var own: int = duration - int(frame.child_usec)
	if own < 0:
		_fault("negative exclusive duration")
	var row: Dictionary = _rows[frame.key]
	row.completed += 1
	row.inclusive_usec += duration
	row.exclusive_usec += own
	row.minimum_usec = duration if row.minimum_usec < 0 else mini(row.minimum_usec, duration)
	row.maximum_usec = maxi(row.maximum_usec, duration)
	_completed += 1
	if not _stack.is_empty():
		_stack.back().child_usec += duration
	_overhead_usec += Time.get_ticks_usec() - stopped


static func _fault(reason: String) -> void:
	if not _errors.has(reason):
		_errors.append(reason)
	_active = false


static func _cpu_sample() -> Dictionary:
	# Linux proc counters, available only at stage boundaries. Never sampled per call.
	var ticks_text: String = OS.get_environment("AC02_CLOCK_TICKS")
	var file: FileAccess = FileAccess.open("/proc/self/stat", FileAccess.READ)
	if file == null or not ticks_text.is_valid_int() or ticks_text.to_int() <= 0:
		return {"available": false, "scope": "process_stage_only"}
	var line: String = file.get_line()
	file.close()
	var after_comm: int = line.rfind(")")
	if after_comm < 0:
		return {"available": false, "scope": "process_stage_only"}
	var fields: PackedStringArray = line.substr(after_comm + 2).split(" ", false)
	if fields.size() < 13 or not fields[11].is_valid_int() or not fields[12].is_valid_int():
		return {"available": false, "scope": "process_stage_only"}
	return {
		"available": true,
		"scope": "process_stage_only",
		"source": "/proc/self/stat",
		"user_ticks": fields[11].to_int(),
		"system_ticks": fields[12].to_int(),
		"ticks_per_second": ticks_text.to_int()
	}


static func snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	var keys: Array = _rows.keys()
	keys.sort()
	for key: String in keys:
		rows.append(_rows[key].duplicate(true))
	return {
		"schema": "AC02-PASSIVE-ATTRIBUTION-v1",
		"stage": _stage,
		"wall_usec": Time.get_ticks_usec() - _started,
		"entries": _entries,
		"completed": _completed,
		"open_scopes": _stack.size(),
		"max_depth": _max_depth,
		"collector_bookkeeping_usec": _overhead_usec,
		"errors": _errors.duplicate(),
		"rows": rows,
		"scope_cpu_supported": false,
		"overhead_note":
		(
			"Bookkeeping is measured, not subtracted. Wrapper dispatch, timer-call cost and "
			+ "profiler effects remain. Exclusive means uninstrumented remainder, not pure business "
			+ "cost."
		)
	}


static func checkpoint(label: String, detail: Dictionary = {}, next_stage: String = "") -> bool:
	if not _stack.is_empty():
		_fault("checkpoint inside synchronous scope")
		return false
	var wall: int = Time.get_ticks_usec() - _started
	var cpu: Dictionary = _cpu_sample()
	var record: Dictionary = {
		"schema": "AC02-PASSIVE-STAGE-v1",
		"sequence": _sequence,
		"label": label,
		"completed_stage": _stage,
		"next_stage": next_stage,
		"pid": OS.get_process_id(),
		"wall_usec": wall,
		"cpu": cpu,
		"detail": detail.duplicate(true),
		"profile": snapshot()
	}
	var path: String = _output.path_join("stage-%02d-%s.json" % [_sequence, label])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fault("stage evidence write failed")
		return false
	file.store_string(JSON.stringify(record, "\t", true, true) + "\n")
	file.flush()
	file.close()
	_sequence += 1
	print(
		"AC02_ATTRIBUTION_STAGE ",
		label,
		" wall_usec=",
		wall,
		" entries=",
		_entries,
		" completed_stage=",
		_stage
	)
	if not next_stage.is_empty():
		_stage = next_stage
	return true


static func finish_session() -> Dictionary:
	_active = false
	return snapshot()
