extends Node
## Independent lifecycle owner: survives removal of the SeasonApp it is saving.
const Coordinator = preload("async_save_coordinator.gd")
const Feedback = preload("res://src/presentation/season/season_loading_feedback.gd")
static var locked: bool = false
var _app: SeasonApp
var _tree: SceneTree
var _auto_quit: bool
var _modes: Dictionary = {}
var _worker: Node
var _overlay: CanvasLayer
var _restored: bool = false
var _cancel_requested: bool = false

static func save(app: SeasonApp, candidate: SeasonState, supervisor: Callable = Callable(), receipt_out: Dictionary = {}) -> bool:
	receipt_out.clear()
	if locked or Coordinator.leased or not app.is_inside_tree() or not app._ac02_settlement_ticket.is_empty():
		return false
	var owner = load("res://src/gameplay/season/async_save/async_save_ui.gd").new()
	owner.process_mode = Node.PROCESS_MODE_ALWAYS
	app.get_tree().root.add_child(owner)
	var saved: bool = await owner._run(app, candidate, supervisor, receipt_out)
	owner.queue_free()
	return saved

func _run(app: SeasonApp, candidate: SeasonState, supervisor: Callable, receipt_out: Dictionary) -> bool:
	locked = true
	_app = app
	_tree = app.get_tree()
	_auto_quit = _tree.auto_accept_quit
	var season: SeasonState = app.season
	var build: SeasonBuild = season.build
	var revision: int = build.revision()
	var generation: int = app._loading_generation
	var parent: Node = app.get_parent()
	_capture_modes(app)
	app._busy = true
	for node: Node in _modes:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	_tree.auto_accept_quit = false
	_worker = Coordinator.new()
	if supervisor.is_valid():
		_worker.configure_supervisor(supervisor)
	_worker.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_worker)
	_overlay = Feedback.show(self, "Checking and saving your result…")
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var cancel := Button.new()
	cancel.text = "CANCEL SAVE (KEEP RESULT OPEN)"
	cancel.position = Vector2(40, 40)
	_overlay.add_child(cancel)
	cancel.pressed.connect(_request_cancel)
	var label: Label = _overlay.get_child(0).get_child(0) as Label
	var tween: Tween = _overlay.create_tween().set_loops()
	tween.tween_property(label, "modulate:a", 0.45, 0.6)
	tween.tween_property(label, "modulate:a", 1.0, 0.6)
	var current: Callable = func() -> bool:
		return is_instance_valid(app) and app.is_inside_tree() and not app.is_queued_for_deletion() \
			and app.get_tree() == _tree and app.get_parent() == parent \
			and app._loading_generation == generation and app.season == season \
			and season.build == build and build.revision() == revision \
			and app.process_mode == Node.PROCESS_MODE_DISABLED
	await _tree.process_frame
	var saved: bool = false
	if not _cancel_requested and current.call() and _worker.start(candidate, current):
		var result: Array = await _worker.completed
		saved = result[0]
	else:
		if not Coordinator.leased:
			SeasonSave.last_error = ("Save cancelled. Your unsaved result remains available." if _cancel_requested
				else "Save could not start. Your unsaved result remains available.")
	if saved:
		var receipt: RefCounted = _worker.take_saved_receipt()
		if receipt != null:
			receipt_out["receipt"] = receipt
	_restore()
	return saved

func _request_cancel() -> void:
	if is_instance_valid(_worker) and _worker.committing:
		return
	# Consume the attempt even before start() has created a child or acquired a lease.
	_cancel_requested = true
	if is_instance_valid(_worker):
		_worker.cancel()

func _restore() -> void:
	if _restored:
		return
	_restored = true
	# Global quit policy belongs to the captured tree, not to a still-live app.
	if is_instance_valid(_tree):
		_tree.auto_accept_quit = _auto_quit
	for node: Node in _modes:
		if is_instance_valid(node) and node.process_mode == Node.PROCESS_MODE_DISABLED:
			node.process_mode = _modes[node]
	if is_instance_valid(_app):
		_app._busy = false # Transient finish_game busy is not a lasting session state.
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	locked = Coordinator.leased

func _exit_tree() -> void:
	_request_cancel()
	_restore()

func _capture_modes(node: Node) -> void:
	_modes[node] = node.process_mode
	for child: Node in node.get_children():
		_capture_modes(child)
