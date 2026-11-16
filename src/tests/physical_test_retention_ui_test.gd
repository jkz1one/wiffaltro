extends Node
## Coordinator gate tests only. No game, request, report, reward or save is created.

var failures: int = 0
var checks: int = 0
var rejected_captures: int = 0


class RejectedQueue:
	extends SeasonRoundUI

	func _queue_human(_human: Array) -> bool:
		return false



class BoundaryApp:
	extends SeasonApp
	var queue_checks: int = 0
	var resume_checks: int = 0
	var close_calls: int = 0
	var events: Array[String] = []

	func _ac02_queue_authorized(_human: Array) -> bool:
		queue_checks += 1
		return false

	func _ac02_resume_authorized() -> bool:
		resume_checks += 1
		return false

	func _close_match(_close_inventory: bool = false) -> bool:
		close_calls += 1
		events.append("close")
		return false


class BoundaryUI:
	extends SeasonRoundUI
	var require_authority: bool = false
	var save_calls: int = 0
	var queue_calls: int = 0
	var launch_calls: int = 0
	var publication_calls: int = 0
	var events: Array[String] = []

	func _ac02_guard_needed() -> bool:
		return require_authority

	func _save_pending_checkpoint() -> bool:
		save_calls += 1
		events.append("save")
		return true

	func _queue_human(_human: Array) -> bool:
		queue_calls += 1
		return true

	func _next() -> void:
		launch_calls += 1

	func _publish_round(_candidate: SeasonState) -> void:
		publication_calls += 1


class ReentryProbe:
	extends Node
	var ui: SeasonRoundUI
	var stage: String
	var transition: String
	var contexts: Array[Dictionary] = []

	func capture(context: Dictionary) -> bool:
		contexts.append(context.duplicate(true))
		if context.stage == stage:
			match transition:
				"cancel": ui.cancel()
				"begin": ui.begin([])
				"queue": ui.queue_human([])
				"resume": ui.resume()
				"next": ui._next()
				"restore": ui.restore_pending()
		return true


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func capture(_context: Dictionary) -> bool:
	return true


func reject_capture(_context: Dictionary) -> bool:
	rejected_captures += 1
	return false


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--physical-retention-unit-tests"):
		push_error("Explicit isolated unit-test argument required.")
		get_tree().quit(78)
		return
	var ordinary: SeasonRoundUI = SeasonRoundUI.new()
	add_child(ordinary)
	ordinary._process_failed("unit child failure")
	check(not ordinary.process_jobs, "normal child failure still selects slower retry")
	check(not ordinary.action.disabled, "normal retry remains available")
	ordinary.free()
	_idle_cancel(false)
	_close_failure(false)
	_authorization_rejection(false, "begin")
	_authorization_rejection(false, "resume")
	if OS.has_feature("editor") \
		and OS.get_cmdline_user_args().has("--physical-test-retention"):
		_strict_failure()
		_backend_change()
		_rejected_configuration()
		_queue_failure()
		_publication_veto()
		_idle_cancel(true)
		_close_failure(true)
		_authorization_rejection(true, "begin")
		_authorization_rejection(true, "resume")
		_working_resume()
		for stage: String in ["job_started", "pending_checkpoint", "before_publish"]:
			for transition: String in ["cancel", "begin", "queue", "resume", "next", "restore"]:
				_capture_reentry(stage, transition)
	print("Physical retention coordinator unit checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _strict_failure() -> void:
	var ui: SeasonRoundUI = SeasonRoundUI.new()
	add_child(ui)
	check(ui.configure_physical_test(capture), "coordinator installs before first transition")
	ui._process_failed("unit child failure")
	check(ui.process_jobs, "strict failure never enables slower backend")
	check(ui.action.disabled, "strict failure disables retry button")
	check(not ui.process_runner.physical_test_can_advance(), "strict failure latches worker")
	# No SeasonApp is supplied: these must return before touching app state or saves.
	ui.resume()
	ui._next()
	ui.begin([])
	check(not ui.queue_human([]), "latched queue cannot modify pending data")
	check(not ui.runner._running and not ui.process_runner.running,
		"latched transitions cannot run either backend")
	check(not ui.configure_physical_test(capture), "strict failure cannot be reset by configure")
	ui.free()


func _backend_change() -> void:
	var ui: SeasonRoundUI = SeasonRoundUI.new()
	add_child(ui)
	check(ui.configure_physical_test(capture), "backend-change opt-in")
	ui.process_jobs = false
	ui._next()
	check(not ui.runner._running and not ui.process_runner.running,
		"changed backend preference fails before projection or fallback")
	check(ui.action.disabled and not ui.process_runner.physical_test_can_advance(),
		"backend mismatch is terminal")
	ui.free()


func _rejected_configuration() -> void:
	var ui: SeasonRoundUI = SeasonRoundUI.new()
	add_child(ui)
	ui.process_jobs = false
	check(not ui.configure_physical_test(capture), "explicit in-process preference rejects mode")
	ui.process_jobs = true
	ui._round_attempted = true
	check(not ui.configure_physical_test(capture), "late coordinator configuration rejects")
	ui.free()


func _queue_failure() -> void:
	var ui: RejectedQueue = RejectedQueue.new()
	add_child(ui)
	check(ui.configure_physical_test(capture), "queue-failure opt-in")
	check(not ui.queue_human([]), "rejected validation/save outcome returns false")
	check(ui.action.disabled and not ui.process_runner.physical_test_can_advance(),
		"queue/save failure latches before any resume")
	ui.resume()
	check(not ui.runner._running and not ui.process_runner.running, "queue failure cannot retry")
	ui.free()


func _publication_veto() -> void:
	var ui: SeasonRoundUI = SeasonRoundUI.new()
	add_child(ui)
	# Only empty in-memory objects for the context bridge; no app _ready or game/save data.
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.physical = SeasonPhysicalFixtures.new()
	ui.app = app
	check(ui.configure_physical_test(reject_capture), "publication-veto opt-in")
	ui._publish_round(null)
	check(rejected_captures == 1, "publication must synchronously ask capture first")
	check(not app._result_saved and app.season != null, "rejected capture never publishes candidate")
	check(ui.action.disabled, "publication rejection forbids retry")
	ui.free()
	app.free()


func _idle_cancel(strict: bool) -> void:
	var ui: SeasonRoundUI = SeasonRoundUI.new()
	add_child(ui)
	if strict:
		check(ui.configure_physical_test(capture), "idle cancel opt-in")
	check(not ui._working, "idle cancellation starts before working")
	ui.cancel()
	check(ui.process_runner.physical_test_can_advance() != strict, "idle cancel strict-only latch")
	check(ui.action.disabled == strict, "ordinary idle cancel does not change retry UI")
	ui.free()


func _marker(worker: PhysicalRoundProcess) -> String:
	worker._token = Crypto.new().generate_random_bytes(16).hex_encode()
	worker._folder = PhysicalJobFiles.directory(worker._token)
	check(DirAccess.make_dir_recursive_absolute(worker._folder) == OK, "marker folder created")
	for name: String in ["worker.log", "unknown.partial"]:
		var file: FileAccess = FileAccess.open(worker._folder.path_join(name), FileAccess.WRITE)
		check(file != null, "marker opened")
		if file != null:
			file.store_string("UI REENTRY UNIT MARKER ONLY\n")
			file.close()
	return worker._folder


func _capture_reentry(stage: String, transition: String) -> void:
	var ui: SeasonRoundUI = SeasonRoundUI.new()
	add_child(ui)
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.physical = SeasonPhysicalFixtures.new()
	ui.app = app
	var probe: ReentryProbe = ReentryProbe.new()
	probe.ui = ui
	probe.stage = stage
	probe.transition = transition
	check(ui.configure_physical_test(probe.capture), "UI reentry opt-in")
	var worker: PhysicalRoundProcess = ui.process_runner
	var folder: String = _marker(worker)
	check(not ui._working and worker._pid == -1, "idle UI and no invented child identity")
	if stage == "job_started":
		check(not worker._capture_started_job(), "public reentry vetoes start observation")
	else:
		check(worker._finish_job("finished"), "marker-only prior teardown")
		check(not worker.capture_test_checkpoint(stage), "public reentry vetoes checkpoint")
	check(not worker.physical_test_can_advance(), "true callback cannot override public stop")
	var terminal_count: int = 0
	for context: Dictionary in probe.contexts:
		if context.stage == "job_terminal":
			terminal_count += 1
	check(terminal_count == 1 and probe.contexts.size() == 2, "exactly one terminal observation")
	var pending: Dictionary = app.season.physical.pending.duplicate(true)
	ui.begin([])
	check(not ui.queue_human([]), "stopped public queue returns before pending mutation")
	ui.resume()
	ui._next()
	ui.cancel()
	check(probe.contexts.size() == 2, "stopped transitions never capture or retry again")
	check(app.season.physical.pending == pending and not app._result_saved,
		"stopped transitions preserve empty pending state and never publish")
	check(not ui.runner._running and not worker.running, "no backend starts after stop")
	ui.free()
	for name: String in ["worker.log", "unknown.partial"]:
		check(FileAccess.get_file_as_string(folder.path_join(name)) == "UI REENTRY UNIT MARKER ONLY\n",
			"public reentry/free preserves original and unknown partial bytes")
	probe.free()
	app.free()


func _close_failure(strict: bool) -> void:
	var ui: BoundaryUI = BoundaryUI.new()
	add_child(ui)
	var app: BoundaryApp = BoundaryApp.new()
	# Neither app nor lab enters the tree. All save/close/launch boundaries are stubbed.
	app.lab = PitchBatLab.new()
	app.events = ui.events
	ui.app = app
	if strict:
		check(ui.configure_physical_test(capture), "close-result strict opt-in")
	ui.resume()
	check(ui.events == ["save", "close"], "one successful save boundary then one rejected close")
	check(ui.save_calls == 1 and app.close_calls == 1, "fault seam called exactly once")
	check(ui.launch_calls == 0 and ui.publication_calls == 0, "failed close cannot launch/publish")
	check(ui.process_runner.physical_test_can_advance() != strict, "failed close strict-only latch")
	ui.resume()
	var expected: int = 1 if strict else 2
	check(ui.save_calls == expected and app.close_calls == expected,
		"strict close failure cannot save/close again; ordinary behavior unchanged")
	check(ui.launch_calls == 0 and ui.publication_calls == 0, "no later launch/publication")
	ui.free()
	app.lab.free()
	app.lab = null
	app.free()


func _authorization_rejection(strict: bool, entry: String) -> void:
	var ui: BoundaryUI = BoundaryUI.new()
	add_child(ui)
	ui.require_authority = true
	var app: BoundaryApp = BoundaryApp.new()
	ui.app = app
	if strict:
		check(ui.configure_physical_test(capture), "AC02-rejection strict opt-in")
	if entry == "begin":
		ui.begin([])
		ui.begin([])
	else:
		ui.resume()
		ui.resume()
	var expected: int = 1 if strict else 2
	check(app.queue_checks + app.resume_checks == expected, "strict rejected entry cannot retry")
	check(app.queue_checks == (expected if entry == "begin" else 0), "only requested stub checked")
	check(ui.process_runner.physical_test_can_advance() != strict, "AC02 rejection strict-only latch")
	check(ui.save_calls == 0 and ui.queue_calls == 0 and ui.launch_calls == 0 \
		and ui.publication_calls == 0, "rejected authority performs no save/queue/launch/publication")
	ui.free()
	app.free()


func _working_resume() -> void:
	var ui: BoundaryUI = BoundaryUI.new()
	add_child(ui)
	check(ui.configure_physical_test(capture), "duplicate working-resume opt-in")
	ui._working = true
	ui.resume()
	check(ui.process_runner.physical_test_can_advance() and ui.save_calls == 0,
		"ordinary duplicate working resume stays a non-failure no-op")
	ui._working = false
	ui.free()
