extends RefCounted
## Dispatch mouse and keyboard through native Window input and GUI focus.
## Never call selection, throw,
## reset, or button/picker signals to establish these regression results.

var _lab
var _check: Callable
var _tree: SceneTree


func run(lab, check: Callable) -> void:
	_lab = lab
	_check = check
	_tree = lab.get_tree()
	if not await _prepare_admission("GUI suite setup"):
		return
	var picker: OptionButton = lab._working_picker
	var popup: PopupMenu = picker.get_popup()
	var previous: Button = lab._working_panel.get_child(2).get_child(0)
	var next: Button = lab._working_panel.get_child(2).get_child(1)
	var corkscrew: int = WorkingPitchCatalog.ids().find("pitch.corkscrew")
	_check.call(corkscrew >= 0, "GUI fixture identifies exact Corkscrew")
	if corkscrew < 0:
		return
	_check.call(_space_matches(&"ui_accept") and _space_matches(&"match_advance"),
		"regression retains the real overlapping Space input bindings")
	await _click(picker)
	if not _require(popup.visible, "pointer opens the real recipe popup"):
		return
	if not await _choose_popup(corkscrew):
		return
	_check.call(picker.has_focus(), "selection retains accessible picker focus")
	await _throw_from_focus("dropdown selection")

	var in_flight: PitchLaunchParameters = lab._pitch_actor.parameters
	await _click(picker)
	if not await _choose_popup(corkscrew):
		return
	_check.call(lab._pitch_actor.parameters == in_flight and lab._pitch_actor.running,
		"repeated GUI selection preserves the exact unfinished flight")
	await _throw_from_focus("repeated dropdown selection")

	await _click(next)
	_check.call(lab._selected_pitch_index == corkscrew + 1 and next.has_focus(),
		"pointer Next selects Trapdoor and retains focus")
	_check.call(not lab._pitch_actor.running, "Next cancels only the unfinished practice pitch")
	await _throw_from_focus("Next button")
	await _click(previous)
	_check.call(lab._selected_pitch_index == corkscrew and previous.has_focus(),
		"pointer Previous selects Corkscrew and retains focus")
	await _throw_from_focus("Previous button")
	if await _test_keyboard(lab, picker, previous, next, corkscrew):
		await _test_dismiss_and_boundaries(lab, picker, corkscrew)


func _test_keyboard(
	lab, picker: OptionButton, previous: Button, next: Button, corkscrew: int
) -> bool:
	var popup: PopupMenu = picker.get_popup()
	if not await _tab_to(next):
		return false
	await _key(KEY_ENTER)
	_check.call(lab._selected_pitch_index == corkscrew + 1,
		"Tab/Enter activates Next once without a throw")
	_check.call(not lab._pitch_actor.running, "Enter navigation does not throw")
	await _throw_from_focus("keyboard Next")
	if not await _tab_to(previous, true):
		return false
	await _key(KEY_ENTER)
	_check.call(lab._selected_pitch_index == corkscrew,
		"Shift+Tab/Enter activates Previous once")
	await _throw_from_focus("keyboard Previous")
	if not await _tab_to(picker, true):
		return false
	await _key(KEY_ENTER)
	if not _require(popup.visible, "Tab/Enter opens the actual picker"):
		return false
	var target_before: Vector2 = lab._pitch_target
	await _key(KEY_DOWN, popup)
	_check.call(popup.get_focused_item() == corkscrew + 1,
		"Down moves the actual popup highlight")
	_check.call(lab._selected_pitch_index == corkscrew and lab._pitch_target == target_before,
		"popup navigation changes neither committed recipe nor game aim")
	await _key(KEY_ENTER, popup)
	_check.call(not popup.visible and lab._selected_pitch_index == corkscrew + 1,
		"Enter commits the keyboard-highlighted recipe and dismisses")
	target_before = lab._pitch_target
	await _key(KEY_DOWN)
	_check.call(lab._pitch_target != target_before,
		"ordinary held arrow input resumes after recipe popup dismissal")
	await _throw_from_focus("keyboard popup choice")
	return true


func _test_dismiss_and_boundaries(lab, picker: OptionButton, corkscrew: int) -> void:
	var popup: PopupMenu = picker.get_popup()
	var in_flight: PitchLaunchParameters = lab._pitch_actor.parameters
	await _click(picker)
	if not _require(popup.visible, "picker can reopen during a throw"):
		return
	await _key(KEY_DOWN, popup)
	await _key(KEY_ESCAPE, popup)
	_check.call(not popup.visible and not lab._debug_paused,
		"Escape dismisses the popup without also pausing")
	_check.call(lab._selected_pitch_index == corkscrew + 1
		and lab._pitch_actor.parameters == in_flight,
		"Escape abandons the highlight without selection or reset")
	await _throw_from_focus("Escape dismissal")
	in_flight = lab._pitch_actor.parameters
	await _click(picker)
	if not _require(popup.visible, "popup owns its ordinary Space confirmation"):
		return
	_check.call(popup.get_focused_item() == picker.selected,
		"pointer-open highlights the committed recipe before Space confirmation")
	await _key(KEY_SPACE, popup)
	_check.call(not popup.visible and lab._selected_pitch_index == corkscrew + 1
		and lab._pitch_actor.parameters == in_flight,
		"popup Space confirms the same item without also throwing or reopening")
	await _throw_from_focus("popup confirmation")
	await _test_popup_space_choice(lab, picker)
	await _key(KEY_F2)
	_check.call(not lab._match_mode
		and lab._status_label.text.contains("Private practice only"),
		"real F2 input refuses match entry in private practice")
	_check.call(not lab._controls_label.text.contains("RESUME MATCH")
		and lab._controls_label.text.contains("F2 PRIVATE ONLY"),
		"private footer describes the actual F2 boundary")

	# Pause owns Space while active. Merely pressing it must not throw through
	# the private input override; other pause UI continues its ordinary routing.
	await _key(KEY_ESCAPE)
	_check.call(lab._debug_paused, "Escape outside the picker still pauses")
	in_flight = lab._pitch_actor.parameters
	await _key(KEY_SPACE)
	_check.call(lab._pitch_actor.parameters == in_flight, "paused Space cannot launch a pitch")
	if lab._debug_paused:
		await _key(KEY_ESCAPE)
	_check.call(not lab._debug_paused, "ordinary Escape resumes after the pause check")


func _test_popup_space_choice(lab, picker: OptionButton) -> void:
	var popup: PopupMenu = picker.get_popup()
	var prior_index: int = lab._selected_pitch_index
	var index: int = wrapi(prior_index + 1, 0, picker.item_count)
	var target_before: Vector2 = lab._pitch_target
	await _click(picker)
	if not _require(popup.visible, "pointer can reopen for a changed Space choice"):
		return
	_check.call(popup.get_focused_item() == prior_index,
		"reopened pointer popup starts from the committed recipe")
	await _key(KEY_DOWN, popup)
	_check.call(popup.get_focused_item() == index
		and lab._selected_pitch_index == prior_index and lab._pitch_target == target_before,
		"pointer-to-keyboard navigation changes only the popup highlight")
	await _key_edge(KEY_SPACE, true, popup)
	_check.call(not popup.visible and lab._selected_pitch_index == index
		and picker.selected == index and not lab._pitch_actor.running,
		"popup Space commits a changed highlighted recipe without a throw")
	var after_confirmation: PitchLaunchParameters = lab._pitch_actor.parameters
	await _key_edge(KEY_SPACE, true, null, false, true)
	await _key_edge(KEY_SPACE, false)
	_check.call(lab._pitch_actor.parameters == after_confirmation
		and not lab._pitch_actor.running and not popup.visible and picker.selected == index,
		"confirmation echo/release neither throws nor reopens or changes the recipe")
	await _throw_from_focus("changed popup Space choice")


func _choose_popup(index: int) -> bool:
	var popup: PopupMenu = _lab._working_picker.get_popup()
	if not _require(popup.visible, "recipe choice requires the actual open popup"):
		return false
	# Use visible-menu key routing, not select(), item_selected.emit(), or a
	# private callback. The finite bound fails if the menu cannot reach a row.
	for step: int in range(popup.item_count + 1):
		if popup.get_focused_item() == index:
			break
		await _key(KEY_DOWN, popup)
	if not _require(popup.get_focused_item() == index, "popup reaches the requested recipe"):
		await _key(KEY_ESCAPE, popup)
		return false
	await _key(KEY_ENTER, popup)
	return _require(not popup.visible and _lab._selected_pitch_index == index,
		"popup commits exactly the highlighted recipe")


func _throw_from_focus(stage: String) -> void:
	var index: int = _lab._selected_pitch_index
	var id: StringName = _lab._selected_pitch().id
	var prior: PitchLaunchParameters = _lab._pitch_actor.parameters
	var prior_throw: int = _lab._throw_number
	var focus: Control = _lab.get_viewport().gui_get_focus_owner()
	_check.call(focus != null and _lab._working_panel.is_ancestor_of(focus),
		stage + ": real GUI focus remains in the private controls")
	await _key_edge(KEY_SPACE, true)
	var cadence: AtBatCadenceController = _lab._at_bat_cadence
	_check.call(cadence.state == AtBatCadenceController.State.DELIVERY
		and not _lab._pitch_actor.running and _lab._throw_number == prior_throw,
		stage + ": Space begins a visible windup before the actual throw")
	var elapsed: float = cadence.elapsed_seconds
	await _key_edge(KEY_SPACE, true, null, false, true)
	await _key_edge(KEY_SPACE, false)
	_check.call(cadence.state == AtBatCadenceController.State.DELIVERY
		and cadence.elapsed_seconds >= elapsed and not _lab._pitch_actor.running
		and _lab._throw_number == prior_throw,
		stage + ": echo/release neither restarts the windup nor throws early")
	if not await _wait_for_working_release(stage):
		return
	var launched: PitchLaunchParameters = _lab._pitch_actor.parameters
	_check.call(launched != null and launched != prior
		and launched.pitch_id == id and _lab._pitch_actor.running
		and _lab._throw_number == prior_throw + 1,
		stage + ": the windup launches exactly one actual selected-recipe flight")
	await _key_edge(KEY_SPACE, true, null, false, true)
	await _key_edge(KEY_SPACE, false)
	_check.call(_lab._pitch_actor.parameters == launched and _lab._pitch_actor.running
		and _lab._throw_number == prior_throw + 1,
		stage + ": echo/release neither relaunches nor resets the flight")
	_check.call(_lab._selected_pitch_index == index
		and _lab._working_picker.selected == index
		and not _lab._working_picker.get_popup().visible,
		stage + ": Space never reopens the selector or advances its selection")
	_check.call(_lab.get_viewport().gui_get_focus_owner() == focus,
		stage + ": throwing does not discard keyboard focus")


func _wait_for_working_release(stage: String) -> bool:
	# The authored cadence is at most 3.53 seconds; retain a finite scheduling margin.
	# Observe real frames, never advance cadence or call the throw path in this test.
	var started: int = Time.get_ticks_msec()
	var deadline: int = started + 6000
	while not _lab._pitch_actor.running and Time.get_ticks_msec() < deadline:
		if _lab._at_bat_cadence.state != AtBatCadenceController.State.DELIVERY:
			break
		await _tree.process_frame
	var elapsed_ms: int = Time.get_ticks_msec() - started
	return _require(_lab._pitch_actor.running and elapsed_ms <= 6000,
		stage + ": actual release within 6000 ms (observed %d ms)"
		% elapsed_ms)


func _tab_to(control: Control, backwards: bool = false) -> bool:
	for step: int in range(16):
		if control.has_focus():
			return true
		await _key(KEY_TAB, null, backwards)
	return _require(control.has_focus(), "bounded Tab traversal reaches " + control.name)


func _prepare_admission(stage: String) -> bool:
	var before: int = _lab._throw_number
	var director = _lab._match_presentation_director
	_lab._working_picker.grab_focus()
	if director != null and director.blocks_gameplay():
		await _key(KEY_SPACE)
	return _require(
		(director == null or not director.blocks_gameplay())
		and _lab._throw_number == before and not _lab._pitch_actor.running
		and _lab._at_bat_cadence.state == AtBatCadenceController.State.IDLE
		and not _lab._working_picker.get_popup().visible,
		stage + ": actual input clears presentation without a throw")


func _dispatch_pointer(event: InputEventMouse, screen_position: Vector2) -> void:
	var root_window: Window = _lab.get_window()
	var target_window: Window = root_window
	var popup: PopupMenu = _lab._working_picker.get_popup()
	if popup.visible and not popup.is_embedded():
		target_window = popup
	# Godot 4.6.3 X11 uses target-window-local pixels for both mouse fields.
	# Screen coordinates are only an intermediate for native popup retargeting.
	var local_position: Vector2 = screen_position - Vector2(target_window.position)
	event.window_id = target_window.get_window_id()
	event.position = local_position
	event.global_position = local_position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _click(control: Control) -> void:
	var root_window: Window = _lab.get_window()
	var screen_position: Vector2 = (Vector2(root_window.position)
		+ root_window.get_final_transform()
		* control.get_global_transform_with_canvas() * (control.size * 0.5))
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.button_mask = Input.get_mouse_button_mask()
	_dispatch_pointer(motion, screen_position)
	# Keep both edges adjacent, like an ordinary click. Yielding a slow render
	# frame between them can exceed PopupMenu's opening-release guard.
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		_dispatch_pointer(event, screen_position)
	await _tree.process_frame


func _key(key: Key, viewport: Viewport = null, shift: bool = false) -> void:
	await _key_edge(key, true, viewport, shift)
	await _key_edge(key, false, viewport, shift)


func _key_edge(
	key: Key, pressed: bool, viewport: Viewport = null, shift: bool = false, echo: bool = false
) -> void:
	# Popup windows own their input while visible. A release after dismissal
	# returns to the root, matching the real window/focus transition.
	if viewport == null or (viewport is Window and not viewport.visible):
		viewport = _lab.get_viewport()
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	event.shift_pressed = shift
	event.echo = echo
	# PopupMenu handles keys in Window's input path, before Viewport.push_input.
	# Enter through Input for BOTH edges, including release after dismissal, so
	# actual Input polling remains observable rather than bypassed by this test.
	# Embedded popups receive keys via the root's ordinary subwindow forwarding;
	# native popups have their own Window ID. Never broadcast an unbound event.
	event.window_id = _lab.get_window().get_window_id()
	if viewport is Window and viewport.visible and not viewport.is_embedded():
		event.window_id = viewport.get_window_id()
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _tree.process_frame


func _space_matches(action: StringName) -> bool:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	return event.is_action_pressed(action)


func _require(condition: bool, message: String) -> bool:
	_check.call(condition, message)
	return condition
