class_name SeasonRoundUI
extends CanvasLayer
## Durable completed-game checkpoints, sequential jobs, atomic round publication.

var app: SeasonApp
var runner: PhysicalMatchRunner
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
	get_viewport().size_changed.connect(_layout)
	panel.minimum_size_changed.connect(_schedule_layout)
	_layout()


func begin(human: Array) -> void:
	queue_human(human)
	resume()


func queue_human(human: Array) -> bool:
	app.season.physical.pending = {"human": human.duplicate(true), "reports": []}
	return SeasonSave.save(app.season)


func restore_pending() -> void:
	_pause("Your completed game is saved. Resume the remaining fixtures to finish the round.")


func resume() -> void:
	if _working:
		return
	# Also retries a completed report whose checkpoint failed; no second physical run.
	if not SeasonSave.save(app.season):
		_pause(SeasonSave.last_error)
		return
	if app.lab != null:
		app._close_match()
	app.menu.hide()
	app.loadout.close()
	_started = Time.get_ticks_msec()
	_next()


func cancel() -> void:
	if not _working:
		return
	runner.cancel()
	_pause("Round paused. Completed games are saved; the unfinished fixture will restart.")


func _next() -> void:
	_projection = SeasonRoundSettlement.project(app.season)
	if _projection.has("error"):
		_pause(_projection.error)
		return
	if not _projection.has("fixture"):
		var candidate: SeasonState = _projection.candidate
		if not SeasonSave.save(candidate):
			_pause(SeasonSave.last_error)
			return
		var human: Array = app.season.physical.pending.human
		var fixture: Dictionary = app.season.pending_fixture()
		var score: String = "%s %d — %s %d" % [app.season.teams[fixture.away].name,
			human[1], app.season.teams[fixture.home].name, human[2]]
		print("PHYSICAL_ROUND fixtures=", app.season.physical.pending.reports.size(),
			" session_wall_ms=", Time.get_ticks_msec() - _started)
		app.season = candidate
		app._result_saved = true
		_working = false
		shade.hide()
		app.menu.show()
		app.menu.show_postgame(score, true)
		return
	var fixture: Dictionary = _projection.fixture
	var candidate: SeasonState = _projection.candidate
	if not runner.start(SeasonPhysicalFixtures.match_for(candidate, fixture),
		SeasonPhysicalFixtures.seed_for(candidate, fixture), SeasonState.field_for_fixture(fixture).id):
		_pause("This fixture could not start. Your completed games remain available.")
		return
	_working = true
	heading.text = "FINISHING THE ROUND"
	action.text = "PAUSE ROUND  Esc"
	shade.show()
	action.grab_focus()


func _finished(report: Dictionary) -> void:
	_working = false
	var candidate: SeasonState = _projection.candidate
	var fixture: Dictionary = _projection.fixture
	app.season.physical.pending.reports.append({"fixture": int(fixture.id),
		"request": SeasonPhysicalFixtures.request_key(candidate, fixture), "report": report})
	if not SeasonSave.save(app.season):
		_pause(SeasonSave.last_error)
		return
	_next()


func _pause(reason: String) -> void:
	_working = false
	heading.text = "ROUND WAITING"
	detail.text = reason
	status.text = ("Round results publish together. "
		+ "Retry keeps completed results and pays each club once.")
	action.text = "RESUME / RETRY"
	shade.show()
	action.grab_focus()


func _process(_delta: float) -> void:
	if not _working or runner._lab == null:
		return
	var state: MatchState = runner._lab._match_state
	var fixture: Dictionary = _projection.fixture
	detail.text = "%s %d  ·  %s %d\n%s inning %d" % [state.away_team.display_name,
		state.away_team.runs, state.home_team.display_name, state.home_team.runs,
		"Top of" if state.top_half else "Bottom of", state.inning]
	status.text = ("Other games saved: %d · Game %d\n"
		+ "Pause at any time. Completed games stay saved.") % [
		app.season.physical.pending.reports.size(), int(fixture.id) + 1]


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
