class_name PhysicalMatchRunner
extends Node
## One detached real-time physical job. Never writes or settles a season/save.

signal finished(report: Dictionary)
signal failed(reason: String)

const MAX_SECONDS: float = 2400.0
const STALL_SECONDS: float = 30.0

var _viewport: SubViewport
var _lab: PitchBatLab
var _elapsed: float = 0.0
var _stalled: float = 0.0
var _progress: String = ""
var _running: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func start(source: MatchState, seed: int, field: StringName = PitchBatLab.FIELD_ID) -> bool:
	if not is_inside_tree() or _running or _viewport != null or seed < 0 or seed > 2147483647:
		return false
	if ContentDB.get_field(field) == null:
		return false
	var snapshot: MatchState = PhysicalMatchRequest.capture(source)
	if snapshot == null:
		return false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_lab = PitchBatLab.new()
	_lab._configured_match = snapshot
	_lab._field_id = field
	_lab._sky_backdrop_enabled = false
	_lab._automation = MatchAutomation.new()
	_lab._automation.seed = seed
	_viewport.add_child(_lab)
	_elapsed = 0.0
	_stalled = 0.0
	_progress = ""
	_running = true
	set_process(true)
	return true


func cancel() -> void:
	_running = false
	_cleanup()
	set_process(false)


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var state: MatchState = _lab._match_state
	if state == null:
		_fail("Physical match initialization failed.")
		return
	if state.phase == MatchState.Phase.GAME_END:
		var report: Dictionary = PhysicalMatchReport.capture(_lab)
		if not PhysicalMatchReport.valid(report):
			_fail("Physical match evidence did not balance.")
			return
		cancel()
		finished.emit(report)
		return
	var progress: String = "%d:%d:%d" % [
		state.phase, state.plate_appearance_number, _lab._throw_number]
	_stalled = _stalled + delta if progress == _progress else 0.0
	_progress = progress
	if _elapsed >= MAX_SECONDS or _stalled >= STALL_SECONDS:
		_fail("Physical match exceeded its time or progress limit; no result was settled.")


func _fail(reason: String) -> void:
	cancel()
	failed.emit(reason)


func _cleanup() -> void:
	if is_instance_valid(_viewport):
		# Stop processing before deferred deletion; consumers may start the next job.
		if is_instance_valid(_lab):
			_lab.process_mode = Node.PROCESS_MODE_DISABLED
		_viewport.process_mode = Node.PROCESS_MODE_DISABLED
		_viewport.queue_free()
	_viewport = null
	_lab = null
