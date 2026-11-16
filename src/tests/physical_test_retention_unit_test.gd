extends Node
## Lifecycle unit tests only. No physical job, report, request, score or game save.
## Marker logs below are test inputs, never physical evidence. Run in isolated user storage.

const MARKER: String = "RETENTION UNIT TEST ONLY\n"
var failures: int = 0
var checks: int = 0


class CaptureProbe:
	extends Node
	var worker: PhysicalRoundProcess
	var contexts: Array[Dictionary] = []
	var answer: Variant = true
	var reenter: String = ""
	var intact: bool = true

	func capture(context: Dictionary) -> Variant:
		contexts.append(context.duplicate(true))
		if context.get("stage") == "job_terminal" and not worker._token.is_empty():
			intact = intact and context.token == worker._token and context.pid == worker._pid
			intact = intact and FileAccess.file_exists(context.folder.path_join("worker.log"))
		context["token"] = "unit callback mutated its copy"
		if reenter == "cancel":
			worker.cancel()
		elif reenter == "start":
			worker.start(null)
		elif reenter == "checkpoint":
			worker.capture_test_checkpoint("before_publish")
		return answer


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--physical-retention-unit-tests"):
		push_error("Explicit isolated unit-test argument required.")
		get_tree().quit(78)
		return
	_defaults()
	var enabled: bool = OS.has_feature("editor") \
		and OS.get_cmdline_user_args().has("--physical-test-retention")
	if enabled:
		for outcome: String in ["finished", "start_failed", "failed", "cancelled", "exited"]:
			for answer: Variant in [true, false, 1, null]:
				_terminal(outcome, answer)
		_checkpoints()
		_invalid_callback()
		for action_name: String in ["cancel", "start", "checkpoint"]:
			_reentrancy(action_name)
		_early_start_failure()
		_started_capture_rejection()
	print("Physical retention lifecycle unit checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _prime(worker: PhysicalRoundProcess, extra: bool = false) -> String:
	worker._token = Crypto.new().generate_random_bytes(16).hex_encode()
	worker._folder = PhysicalJobFiles.directory(worker._token)
	check(DirAccess.make_dir_recursive_absolute(worker._folder) == OK, "unit folder created")
	var file: FileAccess = FileAccess.open(worker._folder.path_join("worker.log"), FileAccess.WRITE)
	check(file != null, "unit marker opened")
	if file != null:
		file.store_string(MARKER)
		file.close()
	if extra:
		file = FileAccess.open(worker._folder.path_join("unknown.partial"), FileAccess.WRITE)
		check(file != null, "unrecognized partial marker opened")
		if file != null:
			file.store_string(MARKER)
			file.close()
	return worker._folder


func _defaults() -> void:
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	check(not worker.physical_test_enabled(), "CLI flag alone never enables retention")
	check(not worker.configure_physical_test(Callable()), "invalid callback cannot opt in")
	var folder: String = _prime(worker)
	worker.cancel()
	check(not DirAccess.dir_exists_absolute(folder), "default cancel removes known job files")
	check(worker.physical_test_can_advance(), "default cancel remains retryable")
	check(worker.capture_test_checkpoint("unused"), "default checkpoint is a no-op")
	worker.free()
	worker = PhysicalRoundProcess.new()
	var probe: CaptureProbe = CaptureProbe.new()
	probe.worker = worker
	if not OS.get_cmdline_user_args().has("--physical-test-retention"):
		check(not worker.configure_physical_test(probe.capture), "CLI gate refuses instrumentation")
	check(not worker.start(null), "off-tree start cannot create a process")
	check(not worker.configure_physical_test(probe.capture), "cannot configure after start attempt")
	worker.free()
	probe.free()


func _terminal(outcome: String, answer: Variant) -> void:
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	var probe: CaptureProbe = CaptureProbe.new()
	probe.worker = worker
	probe.answer = answer
	check(worker.configure_physical_test(probe.capture), "explicit opt-in accepted")
	check(not worker.configure_physical_test(probe.capture), "configuration cannot change")
	var folder: String = _prime(worker, true)
	var token: String = worker._token
	if outcome == "finished":
		# Private teardown helper only: does not validate, invent or emit a report.
		worker._finish_job("finished")
	elif outcome == "start_failed":
		worker._start_failed("unit start failure")
	elif outcome == "failed":
		worker._fail("unit validation/heartbeat/timeout failure")
	elif outcome == "cancelled":
		worker.cancel()
	else:
		add_child(worker)
		remove_child(worker)
	check(probe.contexts.size() == 1, outcome + " captures exactly once")
	check(probe.intact, outcome + " captures before resetting token/PID")
	check(worker._test_last_context.token == token, "callback cannot mutate retained context")
	check(worker._test_last_context.outcome == outcome, "terminal cause retained")
	check(FileAccess.get_file_as_string(folder.path_join("worker.log")) == MARKER,
		outcome + " retains original marker bytes regardless of callback result")
	check(FileAccess.get_file_as_string(folder.path_join("unknown.partial")) == MARKER,
		outcome + " retains unknown and partial files too")
	var successful: bool = outcome == "finished" and answer is bool and answer
	check(worker.physical_test_can_advance() == successful, "only captured success may advance")
	worker.cancel()
	check(probe.contexts.size() == 1, "post-terminal cancel never recaptures or deletes")
	check(not worker.start(null), "cancelled or failed unit cannot retry")
	worker.free()
	check(FileAccess.file_exists(folder.path_join("worker.log")), "free retains originals")
	probe.free()


func _checkpoints() -> void:
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	var probe: CaptureProbe = CaptureProbe.new()
	probe.worker = worker
	check(worker.configure_physical_test(probe.capture), "checkpoint opt-in")
	_prime(worker)
	check(worker._finish_job("finished"), "unit teardown capture succeeds")
	var token: String = worker._test_last_context.token
	check(worker.capture_test_checkpoint("pending_checkpoint"), "durable checkpoint gate accepts")
	check(worker.capture_test_checkpoint("before_publish"), "prepublication gate accepts")
	check(probe.contexts.size() == 3 and probe.contexts[1].token == token \
		and probe.contexts[2].token == token, "later gates retain original job context")
	probe.answer = false
	check(not worker.capture_test_checkpoint("pending_checkpoint"), "failed archive vetoes gate")
	var count: int = probe.contexts.size()
	check(not worker.capture_test_checkpoint("before_publish"), "failure blocks publication gate")
	check(not worker.start(null) and probe.contexts.size() == count, "no retry after veto")
	worker.free()
	probe.free()


func _invalid_callback() -> void:
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	var probe: CaptureProbe = CaptureProbe.new()
	check(worker.configure_physical_test(probe.capture), "initially valid callback installed")
	var folder: String = _prime(worker)
	probe.free()
	check(not worker._finish_job("finished"), "freed callback fails closed")
	check(FileAccess.get_file_as_string(folder.path_join("worker.log")) == MARKER,
		"freed callback cannot erase originals")
	worker.free()


func _reentrancy(action_name: String) -> void:
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	var probe: CaptureProbe = CaptureProbe.new()
	probe.worker = worker
	probe.reenter = action_name
	check(worker.configure_physical_test(probe.capture), "reentrancy opt-in")
	var folder: String = _prime(worker)
	check(not worker._finish_job("finished"), "reentrant " + action_name + " vetoes success")
	check(probe.contexts.size() == 1, "reentrant call cannot capture twice")
	check(FileAccess.get_file_as_string(folder.path_join("worker.log")) == MARKER,
		"reentrant call cannot clean original")
	worker.free()
	probe.free()


func _early_start_failure() -> void:
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	var probe: CaptureProbe = CaptureProbe.new()
	probe.worker = worker
	check(worker.configure_physical_test(probe.capture), "early failure opt-in")
	check(not worker.start(null), "off-tree test start fails before projection or launch")
	check(probe.contexts.size() == 1 and probe.contexts[0].outcome == "start_failed",
		"even no-directory start failure is reported once")
	check(probe.contexts[0].token == "" and probe.contexts[0].pid == -1,
		"early failure does not invent job or process identities")
	check(not worker.start(null) and probe.contexts.size() == 1, "early failure cannot retry")
	worker.free()
	probe.free()


func _started_capture_rejection() -> void:
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	var probe: CaptureProbe = CaptureProbe.new()
	probe.worker = worker
	probe.answer = false
	check(worker.configure_physical_test(probe.capture), "started observation opt-in")
	var folder: String = _prime(worker)
	# Exercise dispatch without launching or claiming an actual child identity.
	check(not worker._capture_started_job(), "failed start observation refuses start success")
	check(probe.contexts.size() == 2 and probe.contexts[0].stage == "job_started" \
		and probe.contexts[1].stage == "job_terminal", "start failure has one terminal salvage call")
	check(probe.contexts[0].pid == -1, "unit test does not invent a positive PID")
	check(not worker.physical_test_can_advance(), "start observation failure is terminal")
	check(FileAccess.get_file_as_string(folder.path_join("worker.log")) == MARKER,
		"failed start observation preserves original marker")
	worker.free()
	probe.free()
