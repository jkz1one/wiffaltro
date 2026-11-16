class_name SeasonRoundUI
extends CanvasLayer
## Durable completed-game checkpoints, sequential jobs, atomic round publication.

var app: SeasonApp
var runner: PhysicalMatchRunner
var process_runner: PhysicalRoundProcess
var process_jobs: bool = not OS.get_cmdline_user_args().has("--physical-in-process")
var shade: ColorRect
var panel: PanelContainer
var heading: Label
var detail: Label
var status: Label
var action: Button
var _projection: Dictionary = {}
var _working: bool = false
var _started: int = 0
var _layout_queued: bool = false
var _round_attempted: bool = false
var _physical_test_capture: Callable
var _physical_test_supervisor: Callable


# Install after _ready, before any queue/resume. Configuration is one-shot.
func configure_physical_test(capture: Callable, supervisor: Callable = Callable()) -> bool:
	if _round_attempted or _working or not process_jobs or not capture.is_valid() \
		or not is_instance_valid(process_runner):
		return false
	if not process_runner.configure_physical_test(_capture_physical_test,
		_supervise_physical_test if supervisor.is_valid() else Callable()):
		return false
	_physical_test_capture = capture
	_physical_test_supervisor = supervisor
	return true


func _capture_physical_test(context: Dictionary) -> Variant:
	if not _physical_test_capture.is_valid() or app == null or app.season == null:
		return false
	context["pending"] = app.season.physical.pending.duplicate(true)
	context["save_path"] = ProjectSettings.globalize_path(SeasonSave.path)
	return _physical_test_capture.call(context)


func _supervise_physical_test(request: Dictionary) -> Variant:
	if not _physical_test_supervisor.is_valid() or app == null or app.season == null:
		return {}
	var context: Dictionary = request.context
	context["pending"] = app.season.physical.pending.duplicate(true)
	context["save_path"] = ProjectSettings.globalize_path(SeasonSave.path)
	return _physical_test_supervisor.call(request.duplicate(true))


func _test_can_advance() -> bool:
	if process_runner.physical_test_can_advance():
		return true
	_pause("Physical test stopped. Inspect retained evidence before a new test run.")
	return false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = ClubhouseTheme.create()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	shade = ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.025, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ClubhouseTheme.surface(false, 24))
	shade.add_child(panel)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	panel.add_child(body)
	heading = _label(body, "FINISHING THE ROUND", 28)
	heading.add_theme_color_override("font_color", ClubhouseTheme.GREEN)
	detail = _label(body, "", 21)
	status = _label(body, "", 17)
	status.add_theme_color_override("font_color", ClubhouseTheme.MUTED)
	action = Button.new()
	action.custom_minimum_size = Vector2(0, 48)
	action.pressed.connect(_activate)
	ClubhouseTheme.primary(action)
	action.add_theme_color_override("font_focus_color", ClubhouseTheme.INK)
	body.add_child(action)
	action.focus_next = NodePath(".")
	action.focus_previous = NodePath(".")
	for direction: String in ["top", "bottom", "left", "right"]:
		action.set("focus_neighbor_" + direction, NodePath("."))
	shade.hide()
	runner = PhysicalMatchRunner.new()
	add_child(runner)
	runner.finished.connect(_finished)
	runner.failed.connect(_pause)
	process_runner = PhysicalRoundProcess.new()
	add_child(process_runner)
	process_runner.finished.connect(_finished)
	process_runner.failed.connect(_process_failed)
	get_viewport().size_changed.connect(_layout)
	panel.minimum_size_changed.connect(_schedule_layout)
	_layout()


func begin(human: Array) -> void:
	if not _test_can_advance():
		return
	if _ac02_guard_needed() and not app._ac02_queue_authorized(human):
		if process_runner.physical_test_enabled():
			_pause("Physical test begin authorization was rejected.")
		return
	var queued: bool = queue_human(human)
	if not queued and process_runner.physical_test_enabled():
		return
	resume()


func queue_human(human: Array) -> bool:
	if not _test_can_advance():
		return false
	_round_attempted = true
	var queued: bool = _queue_human(human)
	if not queued and process_runner.physical_test_enabled():
		_pause("Physical test human checkpoint was not saved.")
	return queued


func _queue_human(human: Array) -> bool:
	if _ac02_guard_needed() and not app._ac02_queue_authorized(human):
		return false
	if (
		StadiumSurfaceNightHumanEvidence.expected(app.season, app.season.pending_fixture())
		and not StadiumSurfaceNightHumanEvidence.pending_valid(app.season, human)
	):
		return false
	if StadiumNpcYardTwoHumanEvidence.expected(app.season, app.season.pending_fixture()):
		if not StadiumNpcYardTwoHumanEvidence.pending_valid(app.season, human):
			return false
	elif (
		app.season.home_property.get("version") == StadiumPoolOwnedSnapshot.VERSION
		and not StadiumPoolOwnedHumanEvidence.pending_valid(app.season, human)
	):
		return false
	app.season.physical.pending = {"human": human.duplicate(true), "reports": []}
	if not app._ac02_settlement_ticket.is_empty():
		app._ac02_settlement_ticket["pending"] = app.season.physical.pending
		return app._ac02_save_settlement()
	return SeasonSave.save(app.season)


func _ac02_guard_needed() -> bool:
	return (
		not app._ac02_settlement_ticket.is_empty()
		or (is_instance_valid(app.lab) and app.lab._ac02_issued_owner != null)
	)


func restore_pending() -> void:
	_pause("Your completed game is saved. Resume the remaining fixtures to finish the round.")


func resume() -> void:
	if not _test_can_advance():
		return
	_round_attempted = true
	if _working:
		return
	if _ac02_guard_needed() and not app._ac02_resume_authorized():
		if process_runner.physical_test_enabled():
			_pause("Physical test resume authorization was rejected.")
		return
	# Also retries a completed report whose checkpoint failed; no second physical run.
	var saved: bool = _save_pending_checkpoint()
	if not saved:
		_pause(SeasonSave.last_error)
		return
	if app.lab != null and not app._close_match():
		if process_runner.physical_test_enabled():
			_pause("Physical test match close failed; retry is disabled.")
		return
	app.menu.hide()
	app.loadout.close()
	_started = Time.get_ticks_msec()
	_next()


# Kept separate for no-storage coordinator fault tests; default save routing is unchanged.
func _save_pending_checkpoint() -> bool:
	return (
		app._ac02_save_settlement()
		if not app._ac02_settlement_ticket.is_empty()
		else SeasonSave.save(app.season)
	)


func cancel() -> void:
	if process_runner.physical_test_enabled():
		process_runner.cancel()
		_pause("Physical test cancelled; inspect retained evidence before a new test run.")
		return
	if not _working:
		return
	runner.cancel()
	process_runner.cancel()
	_pause("Round paused. Completed games are saved; the unfinished fixture will restart.")


func _next() -> void:
	if not _test_can_advance():
		return
	_round_attempted = true
	if process_runner.physical_test_enabled() and not process_jobs:
		_pause("Physical test requires independent process execution.")
		return
	_projection = SeasonRoundSettlement.project(app.season)
	if _projection.has("error"):
		_pause(_projection.error)
		return
	if not _projection.has("fixture"):
		_publish_round(_projection.candidate)
		return
	var fixture: Dictionary = _projection.fixture
	var candidate: SeasonState = _projection.candidate
	var field: FieldDefinition = SeasonState.field_for_fixture(fixture, candidate)
	if field == null:
		_pause("The saved away venue assignment is invalid.")
		return
	if not _start_fixture(candidate, fixture, field):
		return
	_working = true
	heading.text = "FINISHING THE ROUND"
	action.text = "PAUSE ROUND  Esc"
	shade.show()
	action.grab_focus()


func _start_fixture(
	candidate: SeasonState, fixture: Dictionary, field: FieldDefinition
) -> bool:
	var started: bool = process_jobs and process_runner.start(app.season)
	if not started and process_runner.physical_test_enabled():
		_pause("Physical test process could not start. In-process fallback is forbidden.")
		return false
	if not started:
		var state: MatchState = SeasonPhysicalFixtures.match_for(candidate, fixture)
		if state == null:
			_pause("The immutable night fixture could not be reconstructed.")
			return false
		if StadiumSurfaceNightSnapshot.is_family(state.stadium):
			started = runner.start(
				state,
				SeasonPhysicalFixtures.seed_for(candidate, fixture),
				field.id,
				(load("res://src/gameplay/season/dynasty_shared_time_runtime.gd").projected_ledger(app.season, candidate, fixture)
				if candidate._league_home_context.get("format") in [95, 96] else StadiumSurfaceNightSnapshot.ledger(candidate)),
				{},
				candidate
			)
		elif (
			state.stadium.get("version")
			in [
				StadiumPoolOwnedSnapshot.FIXTURE_VERSION,
				StadiumLowWallSnapshot.FIXTURE_VERSION,
				StadiumWaterfallAnimationSnapshot.FIXTURE_VERSION
			]
		):
			started = runner.start(
				state,
				SeasonPhysicalFixtures.seed_for(candidate, fixture),
				field.id,
				(load("res://src/gameplay/season/dynasty_league_home_runtime.gd").projected_ledger(
					app.season, candidate, fixture)
				if candidate._league_home_context.get("format") in [91, 92] else
				load("res://src/gameplay/season/dynasty_standard_runtime.gd").projected_ledger(
					app.season, candidate, fixture)
				if not candidate._standard_live_context.is_empty()
				else ClubPlayers.assets(candidate.career))
			)
		else:
			started = runner.start(
				SeasonPhysicalFixtures.match_for(candidate, fixture),
				SeasonPhysicalFixtures.seed_for(candidate, fixture),
				field.id,
				null,
				{},
				candidate
			)
	if not started:
		_pause("This fixture could not start. Your completed games remain available.")
		return false
	return true


func _publish_round(candidate: SeasonState) -> void:
	if not process_runner.capture_test_checkpoint("before_publish"):
		_pause("Physical test publication capture failed; results remain pending.")
		return
	if not SeasonSave.save(candidate):
		_pause(SeasonSave.last_error)
		return
	var human: Array = app.season.physical.pending.human
	var fixture: Dictionary = app.season.pending_fixture()
	var score: String = (
		"%s %d — %s %d"
		% [
			app.season.teams[fixture.away].name,
			human[1],
			app.season.teams[fixture.home].name,
			human[2]
		]
	)
	print(
		"PHYSICAL_ROUND fixtures=",
		app.season.physical.pending.reports.size(),
		" session_wall_ms=",
		Time.get_ticks_msec() - _started
	)
	app.season = candidate
	app._result_saved = true
	_working = false
	shade.hide()
	app.menu.show()
	app.menu.show_postgame(score, true)


func _finished(report: Dictionary) -> void:
	if not _test_can_advance():
		return
	_working = false
	var candidate: SeasonState = _projection.candidate
	var fixture: Dictionary = _projection.fixture
	app.season.physical.pending.reports.append(
		{
			"fixture": int(fixture.id),
			"request": SeasonPhysicalFixtures.request_key(candidate, fixture),
			"report": report
		}
	)
	if not SeasonSave.save(app.season):
		_pause(SeasonSave.last_error)
		return
	if not process_runner.capture_test_checkpoint("pending_checkpoint"):
		_pause("Physical test checkpoint capture failed; no further fixture or publication.")
		return
	_next()


func _process_failed(reason: String) -> void:
	if process_runner.physical_test_enabled():
		_pause(reason)
		return
	process_jobs = false
	_pause(reason + " Retry will use the slower in-process simulation.")


func _pause(reason: String) -> void:
	_working = false
	heading.text = "ROUND WAITING"
	detail.text = reason
	status.text = (
		"Round results publish together. "
		+ "Retry keeps completed results and pays each club once."
	)
	action.text = "RESUME / RETRY"
	if process_runner.physical_test_enabled():
		process_runner.cancel()
		status.text = "Test stopped. Original job files are retained; retry is disabled."
		action.text = "TEST STOPPED"
		action.disabled = true
	shade.show()
	action.grab_focus()


func _process(_delta: float) -> void:
	if _working and process_runner.running:
		var fixture: Dictionary = _projection.fixture
		var progress: Dictionary = process_runner.progress
		detail.text = (
			"%s vs %s\nRunning the complete physical game..."
			% [app.season.teams[fixture.away].name, app.season.teams[fixture.home].name]
		)
		if not progress.is_empty():
			detail.text = (
				"%s %d · %s %d\n%s inning %d"
				% [
					app.season.teams[fixture.away].name,
					progress.away,
					app.season.teams[fixture.home].name,
					progress.home,
					"Top of" if progress.top else "Bottom of",
					progress.inning
				]
			)
		status.text = (
			(
				"Other games saved: %d · Accelerated physical simulation\n"
				+ "Pause keeps completed games."
			)
			% (app.season.physical.pending.reports.size())
		)
		return
	if not _working or runner._lab == null:
		return
	var state: MatchState = runner._lab._match_state
	var fixture: Dictionary = _projection.fixture
	detail.text = (
		"%s %d  ·  %s %d\n%s inning %d"
		% [
			state.away_team.display_name,
			state.away_team.runs,
			state.home_team.display_name,
			state.home_team.runs,
			"Top of" if state.top_half else "Bottom of",
			state.inning
		]
	)
	status.text = (
		("Other games saved: %d · Game %d\n" + "Pause at any time. Completed games stay saved.")
		% [app.season.physical.pending.reports.size(), int(fixture.id) + 1]
	)


func _input(event: InputEvent) -> void:
	if shade.visible and event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()


func _activate() -> void:
	if _working:
		cancel()
	else:
		resume()


func _layout() -> void:
	var available: Vector2 = get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(660.0, available.x - 40.0), 0.0)
	panel.position = Vector2((available.x - panel.size.x) * 0.5, maxf(32.0, available.y * 0.22))


func _schedule_layout() -> void:
	if not _layout_queued:
		_layout_queued = true
		_settle_layout.call_deferred()


func _settle_layout() -> void:
	_layout_queued = false
	_layout()


static func _label(parent: Node, text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
