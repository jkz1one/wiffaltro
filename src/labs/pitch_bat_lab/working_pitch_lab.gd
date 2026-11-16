extends PitchBatLab
## Explicit private practice entry. No profile install, purchase, save migration,
## starter grant or character-row edit. Use an isolated user-data directory.

var _working_options: Array[PitchDefinition] = []
var _working_picker: OptionButton
var _working_note: Label
var _working_panel: VBoxContainer
var _working_delivery_index: int = -1
var _working_quit: Button
var _working_request_generation: int = 0
var _working_preparing_generation: int = -1


func _ready() -> void:
	_working_options = WorkingPitchCatalog.recipes()
	_match_mode = false
	super._ready()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	_working_panel = VBoxContainer.new()
	layer.add_child(_working_panel)
	_working_note = Label.new()
	_working_note.text = "WORKING PITCH DESIGNS • Private practice\nSPACE windup + throw • Tab/Enter choose"
	_working_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_working_panel.add_child(_working_note)
	_working_picker = OptionButton.new()
	_working_picker.custom_minimum_size = Vector2(0, 36)
	_working_picker.fit_to_longest_item = false
	for pitch: PitchDefinition in _working_options:
		_working_picker.add_item(_working_label(pitch))
	_working_picker.item_selected.connect(_choose_working_pitch)
	_working_picker.get_popup().about_to_popup.connect(_focus_working_popup)
	_working_panel.add_child(_working_picker)
	var navigation: HBoxContainer = HBoxContainer.new()
	_working_panel.add_child(navigation)
	for pair: Array in [["Previous pitch", -1], ["Next pitch", 1]]:
		var button: Button = Button.new()
		button.text = pair[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_cycle_working_pitch.bind(pair[1]))
		navigation.add_child(button)
	get_viewport().size_changed.connect(_layout_working_controls)
	_layout_working_controls()
	_refresh_config()
	_install_working_quit.call_deferred()


func _input(event: InputEvent) -> void:
	super._input(event)
	if not event is InputEventKey or event.keycode != KEY_SPACE:
		return
	if _debug_paused or _working_picker == null or _working_picker.get_popup().visible:
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and focus == _working_quit:
		return  # Let the visible Quit button own its normal Space/Enter input.
	if focus == null or not _working_panel.is_ancestor_of(focus):
		return
	# Space is both ui_accept and match_advance. Claim both edges before GUI
	# dispatch, so a focused private picker/button cannot also open or reset.
	# Keep focus for Tab/Enter and leave popup, pause and other UI input alone.
	if event.pressed and not event.echo:
		# Retain the ordinary admission/overlay guards and actual throw path.
		super._unhandled_input(event)
	get_viewport().set_input_as_handled()


func _request_lab_pitch() -> void:
	if _working_preparing_generation >= 0 or not _working_delivery_admitted():
		return
	if _at_bat_cadence.state == AtBatCadenceController.State.DELIVERY:
		return  # Do not restart or queue an existing delivery.
	_working_request_generation += 1
	var generation: int = _working_request_generation
	_working_preparing_generation = generation
	_working_delivery_index = _selected_pitch_index
	var request: Dictionary = {
		"generation": generation, "index": _selected_pitch_index, "pitch": _selected_pitch(),
		"actor": _pitch_actor, "cadence": _at_bat_cadence, "match_state": _match_state,
		"throw_number": _throw_number, "ball": _batted_ball,
		"actor_state": _pitch_actor.state, "parameters": _pitch_actor.parameters,
		"resolver": _ball_play_resolver,
		"play": _ball_play_resolver.state if _ball_play_resolver != null else null,
		"home": _home_run, "home_generation": _home_run._generation,
		"fielder": _primary_fielder
	}
	_prepare_working_delivery(request)
	if is_instance_valid(self) and _working_preparing_generation == generation:
		_working_preparing_generation = -1


func _working_delivery_admitted() -> bool:
	var tactics: MatchTacticalControls = get_node_or_null("TacticalControls")
	return (
		is_inside_tree() and not is_queued_for_deletion()
		and not _match_mode and not _managed_match and _automation == null and not _debug_paused
		and not get_tree().paused and not ac02_startup_pending()
		and not has_meta("loadout_open") and not has_meta("player_inspection_open")
		and not SeasonEncoreUI.reviewing(self)
		and (tactics == null or not tactics._dialog.visible)
		and (_match_presentation_director == null
			or not _match_presentation_director.blocks_gameplay())
		and _match_state != null and _at_bat_cadence != null and _home_run != null
		and is_instance_valid(_pitch_actor) and not _pitch_actor.is_queued_for_deletion()
		and _selected_pitch() != null and not _field_setup_active and not _pitching_staff_active
		and not pool_bound_startup_failed and not yard_bound_startup_failed
		and _private_hillside_admits()
		and StadiumSurfaceNightRuntime.action_allowed(self)
		and StadiumSurfaceTerrainRuntime.action_allowed(self)
		and (_working_picker == null or (is_instance_valid(_working_picker)
			and not _working_picker.get_popup().visible))
	)


func _working_request_current(request: Dictionary, cleaned: bool = false) -> bool:
	return (
		is_instance_valid(self) and _working_delivery_admitted()
		and _working_request_generation == request.generation
		and _working_preparing_generation == request.generation
		and _selected_pitch_index == request.index and _selected_pitch() == request.pitch
		and _throw_number == request.throw_number
		and _pitch_actor == request.actor and _at_bat_cadence == request.cadence
		and _at_bat_cadence.state == AtBatCadenceController.State.IDLE
		and _match_state == request.match_state and _home_run == request.home
		and _home_run._generation == request.home_generation + (1 if cleaned else 0)
		and _batted_ball == (null if cleaned else request.ball)
		and _ball_play_resolver == request.resolver
		and (_ball_play_resolver == null or _ball_play_resolver.state == request.play)
		and _primary_fielder == request.fielder
		and (request.fielder == null or (is_instance_valid(request.fielder)
			and not request.fielder.is_queued_for_deletion()))
		and (not cleaned or (not _pitch_actor.running
			and _pitch_actor.state == null and _pitch_actor.parameters == null))
	)


func _prepare_working_delivery(request: Dictionary) -> void:
	# Every helper below can reach synchronous presentation callbacks.
	# Revalidate captured ownership before any later mutation or final commit.
	PitchBatLabFeelSupport.cancel_release(self)
	if (not _working_request_current(request)
		or _pitch_actor.state != request.actor_state or _pitch_actor.parameters != request.parameters):
		return
	_pitch_actor.reset_pitch()
	if (not _working_request_current(request) or _pitch_actor.running
		or _pitch_actor.state != null or _pitch_actor.parameters != null):
		return
	_cleanup_batted_ball()
	if not _working_request_current(request, true):
		return
	PitchBatLabSwingSupport.reset(self)
	if not _working_request_current(request, true):
		return
	_active_play_record = null
	_status_label.text = ""
	if not _working_request_current(request, true):
		return
	_live_label.text = ""
	if not _working_request_current(request, true):
		return
	_refresh_config()
	if not _working_request_current(request, true):
		return
	# Commit last: begin_delivery changes only cadence state, without callbacks.
	# Shared cadence/telegraph later use the unchanged guarded _throw_pitch path.
	_at_bat_cadence.begin_delivery(_throw_number * 811 + _selected_pitch_index * 131)


func _reset_lab() -> void:
	# Invalidate preparation before reset can emit visibility/cleanup callbacks.
	# Keep its latch until the older request unwinds; recursive requests cannot race it.
	_working_request_generation += 1
	super._reset_lab()


func _focus_working_popup() -> void:
	# Mouse-open normally scrolls without highlighting a row. Seed the committed
	# selection so switching directly to Space/Enter confirms that same recipe.
	_working_picker.get_popup().set_focused_item(_working_picker.selected)


func _continuous_input_blocked() -> bool:
	return _working_picker != null and _working_picker.get_popup().visible


func _selected_pitch() -> PitchDefinition:
	if _working_options.is_empty():
		return null
	_selected_pitch_index = clampi(_selected_pitch_index, 0, _working_options.size() - 1)
	return _working_options[_selected_pitch_index]


func _current_pitch_options() -> Array[PitchDefinition]:
	return _working_options


func _refresh_config() -> void:
	# Numeric selection may change during preparation, before cadence is DELIVERY.
	if (
		_at_bat_cadence != null
		and (_working_preparing_generation >= 0
			or _at_bat_cadence.state == AtBatCadenceController.State.DELIVERY)
		and _selected_pitch_index != _working_delivery_index
	):
		_working_request_generation += 1
		PitchBatLabFeelSupport.cancel_release(self)
	super._refresh_config()
	if _controls_label != null:
		_controls_label.text = _controls_label.text.replace("F2 RESUME MATCH", "F2 PRIVATE ONLY")
	if _config_label != null:
		_config_label.text = _config_label.text.replace(
			"/%d" % PITCH_IDS.size(), "/%d" % _working_options.size()
		)
	if _working_picker != null:
		_working_picker.select(_selected_pitch_index)
		_working_picker.tooltip_text = _selected_pitch().tactical_description
		for label: String in WorkingPitchCatalog.SOURCE_STYLES:
			var style: Dictionary = WorkingPitchCatalog.SOURCE_STYLES[label]
			if style.recipe == String(_selected_pitch().id):
				_working_picker.tooltip_text += "\n" + label + ": " + style.status + ". " + style.note
				_working_picker.tooltip_text += "\n" + style.source


func _working_label(pitch: PitchDefinition) -> String:
	var names: Array[String] = []
	for label: String in WorkingPitchCatalog.SOURCE_STYLES:
		if WorkingPitchCatalog.SOURCE_STYLES[label].recipe == String(pitch.id):
			names.append(label)
	return (pitch.display_name if names.is_empty()
		else pitch.display_name + " (" + ", ".join(names) + ")")


func _choose_working_recipe(id: String) -> bool:
	# Old selected IDs have an explicit destination, with no save or ownership mutation.
	var canonical: String = WorkingPitchCatalog.canonical_id(id)
	for index: int in range(_working_options.size()):
		if String(_working_options[index].id) == canonical:
			_choose_working_pitch(index)
			return true
	return false


func _choose_working_pitch(index: int) -> void:
	if index < 0 or index >= _working_options.size() or index == _selected_pitch_index:
		return
	_reset_lab()
	_active_play_record = null  # Selection cancels practice only, never a completed match.
	_selected_pitch_index = index
	_refresh_config()


func _cycle_working_pitch(direction: int) -> void:
	if not _working_options.is_empty():
		_choose_working_pitch(wrapi(_selected_pitch_index + direction, 0, _working_options.size()))


func _layout_working_controls() -> void:
	if _working_panel == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var width: float = clampf(viewport_size.x * 0.36, 260.0, 380.0)
	_working_panel.custom_minimum_size.x = width
	_working_panel.size.x = width
	_working_panel.position = Vector2(maxf(12.0, viewport_size.x - width - 12.0), 12.0)
	_working_picker.get_popup().max_size = Vector2i(int(width), int(maxf(150, viewport_size.y - 100)))


func _toggle_match_mode() -> void:
	# This scene never writes an unqualified candidate into an ordinary match.
	_status_label.text = "Private practice only. Paid season access uses its versioned catalog."


func _install_working_quit() -> void:
	# Embedded test/host scenes must never acquire an application-wide exit.
	if get_tree().current_scene != self or _match_mode or _managed_match:
		return
	_working_quit = Button.new()
	_working_quit.text = "Quit private practice"
	_working_quit.custom_minimum_size.y = 36.0
	_working_quit.pressed.connect(_quit_working_practice)
	_working_panel.add_child(_working_quit)


func _quit_working_practice() -> void:
	if get_tree().current_scene != self or _match_mode or _managed_match:
		return
	get_tree().quit()  # Normal standalone application exit, including while paused.
