class_name PhysicalTestSupervision
extends RefCounted
## Strict-test-only external direct-parent capability. Never used by ordinary play.
## The broker Popen-owns the exact unchanged worker argv and reports actual waitpid.

var callback: Callable
var pid: int = -1
var running: bool = false
var blocked: bool = false
var busy: bool = false
var attempted: bool = false
var stop_attempted: bool = false
var last: Dictionary = {}


func launch(executable: String, arguments: PackedStringArray, context: Dictionary) -> int:
	if attempted or blocked or busy or not callback.is_valid():
		blocked = true
		return -1
	attempted = true
	var result: Dictionary = _call({"operation": "launch", "executable": executable,
		"arguments": Array(arguments), "context": context.duplicate(true)})
	if result.is_empty() or not result.running or result.normal_exit \
		or result.exit_code != -1 or result.raw_wait_status != -1:
		blocked = true
		return -1
	pid = int(result.pid)
	running = true
	last = result
	return pid


func status(context: Dictionary) -> Dictionary:
	if blocked or not attempted or pid <= 0:
		blocked = true
		return {}
	var result: Dictionary = _call({"operation": "status", "context": context.duplicate(true)})
	if result.is_empty():
		return {}
	running = result.running
	last = result
	return result


func stop(context: Dictionary) -> bool:
	if stop_attempted or busy:
		blocked = true
		return false
	# Consume before fallible IPC. One cleanup request cannot become a retry.
	stop_attempted = true
	var result: Dictionary = _call({"operation": "stop", "context": context.duplicate(true)}, true)
	if result.is_empty() or result.running:
		blocked = true
		return false
	running = false
	last = result
	return true


func _call(request: Dictionary, salvage: bool = false) -> Dictionary:
	if busy or (blocked and not salvage) or not callback.is_valid():
		blocked = true
		return {}
	busy = true
	var result: Variant = callback.call(request.duplicate(true))
	busy = false
	if not _valid(result) or (blocked and not salvage):
		blocked = true
		return {}
	return result.duplicate(true)


func _valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 7:
		return false
	for key: String in ["ok", "pid", "running", "normal_exit", "exit_code",
		"raw_wait_status", "receipt_sha256"]:
		if not value.has(key):
			return false
	if not value.ok is bool or not value.ok or not value.pid is int or value.pid <= 0 \
		or (pid > 0 and value.pid != pid) or not value.running is bool \
		or not value.normal_exit is bool or not value.exit_code is int \
		or not value.raw_wait_status is int or not value.receipt_sha256 is String \
		or value.receipt_sha256.length() != 64 or not value.receipt_sha256.is_valid_hex_number(false):
		return false
	if value.running:
		return not value.normal_exit and value.exit_code == -1 and value.raw_wait_status == -1
	if value.raw_wait_status < 0:
		return false
	if value.normal_exit:
		return value.exit_code >= 0 and value.exit_code <= 255 \
			and value.raw_wait_status == (value.exit_code << 8)
	return value.exit_code < 0 and value.exit_code >= -127 \
		and (value.raw_wait_status & 127) == -value.exit_code
