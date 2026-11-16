extends Node
## Inert source-only marker test. No actual PID, worker, save, request or game proof.
var checks: int = 0
var failures: int = 0
var instance: PhysicalTestSupervision
var answer: Dictionary = {}
var recurse: bool = false


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--physical-supervision-unit-tests"):
		get_tree().quit(78)
		return
	instance = PhysicalTestSupervision.new()
	instance.callback = _reply
	answer = _running()
	_check(instance.launch("INERT_FIXTURE_ONLY", PackedStringArray(), {}) == 123, "launch")
	_check(instance.status({}).running, "running")
	answer = _terminal(0, true, 0)
	_check(instance.status({}).raw_wait_status == 0, "raw_zero")
	_check(instance.launch("INERT_FIXTURE_ONLY", PackedStringArray(), {}) == -1, "no_relaunch")
	instance = PhysicalTestSupervision.new()
	instance.callback = _reply
	answer = _running()
	_check(instance.launch("INERT_FIXTURE_ONLY", PackedStringArray(), {}) == 123, "launch_two")
	answer = _terminal(7, true, 7 << 8)
	_check(instance.status({}).exit_code == 7, "actual_nonzero_preserved")
	answer = _terminal(-15, false, 15)
	_check(not instance.status({}).normal_exit, "signal_not_zero")
	answer = _terminal(0, false, 15)
	_check(instance.status({}).is_empty(), "inconsistent_status_rejected")
	instance = PhysicalTestSupervision.new()
	instance.callback = _reply
	answer = _running()
	recurse = true
	_check(instance.launch("INERT_FIXTURE_ONLY", PackedStringArray(), {}) == -1, "reentry")
	_check(instance.blocked, "reentry_latched")
	print("PHYSICAL_SUPERVISION_MARKER checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _reply(_request: Dictionary) -> Dictionary:
	if recurse:
		recurse = false
		instance.status({})
	return answer.duplicate(true)


func _running() -> Dictionary:
	return {"ok": true, "pid": 123, "running": true, "normal_exit": false,
		"exit_code": -1, "raw_wait_status": -1, "receipt_sha256": "a".repeat(64)}


func _terminal(code: int, normal: bool, raw: int) -> Dictionary:
	return {"ok": true, "pid": 123, "running": false, "normal_exit": normal,
		"exit_code": code, "raw_wait_status": raw, "receipt_sha256": "a".repeat(64)}


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("INERT_SUPERVISION_FIXTURE " + label)
