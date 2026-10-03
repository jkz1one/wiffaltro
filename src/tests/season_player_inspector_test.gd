extends "res://src/tests/paid_shop_ui_test.gd"

var _app: SeasonApp


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://player-inspection-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://player-inspection-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	await _draft_inspection()
	await _shop_inspection()
	await _match_inspection()
	_app.queue_free()
	await _frames()
	_check(not get_tree().paused, "inspection teardown never strands pause")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	DirAccess.remove_absolute(PitchBatLabSettings.path)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro player inspection checks passed: read-only previews, targets and pause.")
	get_tree().quit(0 if _failures == 0 else 1)


func _draft_inspection() -> void:
	_app.begin_season(61, true)
	# Historical score-only fixture; physical rounds have separate integration coverage.
	_app.season.physical = null
	_app.season.opponents._format = 2
	var id: String = _app.season.offers()[0]
	_app.menu._select_draft(id)
	await _frames()
	var before: Dictionary = _app.season.build.to_data()
	var saved: String = FileAccess.get_file_as_string(SeasonSave.path)
	var button: Button = _inspect_button(_app.menu, id)
	await _click(button)
	var inspector: SeasonPlayerInspector = _inspector(_app.menu)
	await _inspection_bounds(inspector, Vector2i(1280, 720), "player-draft")
	_check(get_tree().paused, "inspection pauses its scene")
	var player: PlayerDefinition = _app.season.player_definition(id)
	var text: String = _text(inspector)
	_check(text.contains(player.display_name), "exact offered player is inspected")
	for recipe: PitchDefinition in player.starting_pitches:
		_check(
			text.contains(PitchMastery.next_effect(recipe)), "shared next-level effect is disclosed"
		)
	_check(not text.contains("Velocity\n"), "Working profile uses four visible ratings")
	await _dismiss(inspector, false)
	_check(
		_app.menu.draft_selection == id and _app.season.picks.is_empty(),
		"Escape preserves draft selection without confirming"
	)
	_check(
		(
			_app.season.build.to_data() == before
			and FileAccess.get_file_as_string(SeasonSave.path) == saved
		),
		"draft inspection preserves state and saved bytes"
	)
	_check(not get_tree().paused and button.has_focus(), "draft focus and running state restored")
	# The original draft confirmation remains usable after inspection.
	await _click(_button(_app.menu, "DRAFT ", true))
	for pick in range(3):
		_app.choose_player(_app.season.offers()[0])
	_app.menu.show_lineup()
	await _frames()
	id = _app.season.teams[0].roster[0]
	before = _app.season.build.to_data()
	await _click(_inspect_button(_app.menu, id))
	inspector = _inspector(_app.menu)
	await _inspection_bounds(inspector, Vector2i(1280, 720), "player-lineup")
	await _click(inspector.get_ok_button())
	_check(_app.menu.page == "lineup" and _app.season.build.to_data() == before, "lineup survives")
	# A capped recipe uses the real shared cap description; resources remain immutable.
	player = _app.season.player_definition(id).duplicate()
	var recipe_id: StringName = player.starting_pitches[0].id
	var source: PitchDefinition = ContentDB.get_pitch(recipe_id)
	var original_speed: float = source.nominal_velocity_mps
	player.starting_pitches = [PitchMastery.apply(source, 5)]
	player.season_abilities = [SeasonAbilities.COUNT, SeasonAbilities.HANDS]
	inspector = SeasonPlayerInspector.open_from(_app.menu, player)
	await _frames()
	_check(_text(inspector).contains("Level 5 cap reached."), "cap replaces unavailable preview")
	_check(
		_text(inspector).contains(SeasonAbilities.description(player)),
		"learned effects are disclosed"
	)
	await _dismiss(inspector, true)
	_check(
		source.nominal_velocity_mps == original_speed, "inspection never mutates authored recipe"
	)
	player = ContentDB.get_player(StringName(id))
	inspector = SeasonPlayerInspector.open_from(_app.menu, player)
	await _inspection_bounds(inspector, Vector2i(1280, 720), "player-vanilla")
	_check(
		_text(inspector).contains("Velocity") and not _text(inspector).contains("Next level:"),
		"legacy vanilla inspection retains seven stats without Working mastery"
	)
	await _dismiss(inspector, false)


func _shop_inspection() -> void:
	var game: Dictionary = _app.season.pending_fixture()
	_check(
		_app.season.record_player_result(
			game.id, 0 if game.home == 0 else 1, 1 if game.home == 0 else 0
		),
		"earned actual shop window"
	)
	_check(_app._checkpoint(), "funded shop saves")
	_app.show_season()
	_app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(_app)
	window.size = Vector2i(700, 400)
	var offer: String = ""
	for key: String in _app.season.build.view().shop.offers:
		if DevelopmentShopCatalog.CARDS.has(_app.season.build.view().shop.offers[key]):
			offer = key
			break
	_check(not offer.is_empty(), "generated development offer exists")
	if offer.is_empty():
		return
	var before: Dictionary = _app.season.build.to_data()
	var saved: String = FileAccess.get_file_as_string(SeasonSave.path)
	await _click(_offer_button(window, offer))
	var target: Button = _target_button(window)
	var fields: Dictionary = target.get_meta("target")
	var button: Button = _inspect_button(window._body, fields.player)
	await _click(button)
	var inspector: SeasonPlayerInspector = _inspector(window)
	await _inspection_bounds(inspector, window.size, "player-shop-small")
	await _dismiss(inspector, true)
	_check(
		is_instance_valid(target) and target.get_meta("target") == fields and button.has_focus(),
		"shop exact target and focus survive controller dismissal"
	)
	_check(
		(
			_app.season.build.to_data() == before
			and FileAccess.get_file_as_string(SeasonSave.path) == saved
		),
		"shop inspection changes no offers, money, journal or save"
	)
	await _click(target)
	_check(
		window._confirm.visible and window._pending.player == fields.player, "same pending purchase"
	)
	await _click(window._confirm.get_cancel_button())
	await _click(_button(window._body, "CANCEL TARGETING"))
	var loadout: SeasonLoadoutUI
	for child: Node in window.get_children():
		if child is SeasonLoadoutUI:
			loadout = child
	await _loadout_inspection(loadout, window.size, "player-equipped-shop", fields.player)
	await _click(window._back)


func _match_inspection() -> void:
	# Choose a scheduled home fixture through valid score settlement, not by editing the match.
	while _app.season.pending_fixture().home != 0:
		var game: Dictionary = _app.season.pending_fixture()
		_check(
			_app.season.record_player_result(game.id, 1, 0), "settle away fixture for home review"
		)
	_app.show_season()
	_app.play_season_game()
	await _frames()
	var lab: PitchBatLab = _app.lab
	_check(lab != null and lab._player_is_pitching(), "actual managed defensive fixture")
	if lab == null:
		return
	var skip: InputEventKey = InputEventKey.new()
	skip.keycode = KEY_SPACE
	skip.pressed = true
	get_viewport().push_input(skip, true)
	await _frames()
	lab._toggle_pitching_staff()
	await _frames()
	var details: Button
	for button: Node in lab._pitching_staff_panel.find_children("*", "Button", true, false):
		if button.has_meta("inspect_staff") and button.get_meta("inspect_staff") == 0:
			details = button
	var pitcher: int = lab._match_state.defensive_team().pitcher_index
	var performance: Dictionary = lab._match_state.performance.snapshot(lab._match_state)
	await _click(details)
	var inspector: SeasonPlayerInspector = _inspector(lab)
	await _inspection_bounds(inspector, Vector2i(1280, 720), "player-bullpen")
	if inspector == null:
		return
	_check(lab._debug_paused and get_tree().paused, "bullpen inspection freezes full play")
	var debug: InputEventKey = InputEventKey.new()
	debug.keycode = KEY_F2
	debug.pressed = true
	PitchBatLabInput.handle(lab, debug)
	_check(lab._match_mode, "match shortcut blocked while inspecting")
	await _click(inspector.get_ok_button())
	_check(
		(
			not get_tree().paused
			and not lab._debug_paused
			and lab._pitching_staff_active
			and lab._match_state.defensive_team().pitcher_index == pitcher
			and lab._match_state.performance.snapshot(lab._match_state) == performance
		),
		"bullpen plan, evidence and prior running state survive"
	)
	lab._toggle_pitching_staff()
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	lab._pause_menu.open_stats()
	await _frames()
	var panel: MatchStatsPanel = lab._pause_menu.stats
	var id: String = String(panel.selected_team().roster[0].definition.id)
	await _click(_inspect_button(panel, id))
	inspector = _inspector(lab)
	await _inspection_bounds(inspector, Vector2i(1280, 720), "player-paused-stats")
	await _dismiss(inspector, false)
	_check(
		get_tree().paused and lab._debug_paused and panel.visible, "existing pause remains paused"
	)
	# Freeing a parent with its inspector open must restore the saved pause before teardown.
	lab._pause_menu.close_stats()
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	await _loadout_inspection(_app.loadout, Vector2i(1280, 720), "player-equipped-live", id)
	_check(not get_tree().paused and not lab._debug_paused, "nested loadout restores live play")
	lab._toggle_pitching_staff()
	await _click(details)
	_check(_inspector(lab) != null, "teardown exercise has a live inspector")


func _loadout_inspection(ui: SeasonLoadoutUI, extent: Vector2i, stage: String, id: String) -> void:
	var before: Dictionary = _app.season.build.to_data()
	var saved: String = FileAccess.get_file_as_string(SeasonSave.path)
	await _click(ui.entry)
	await _click(ui._tab_buttons[3])
	var button: Button = _inspect_button(ui.body, id)
	ui.close_button.grab_focus()
	var reached: Dictionary = {}
	for step in range(6 + ui._player_buttons.size()):
		await _pad(JOY_BUTTON_DPAD_DOWN)
		var focused: Control = ui.get_viewport().gui_get_focus_owner()
		if focused != null and focused.has_meta("inspect_player"):
			reached[focused.get_meta("inspect_player")] = true
	_check(reached.size() == ui._player_buttons.size(), "controller reaches every Equipped player")
	for step in range(6 + ui._player_buttons.size()):
		if ui.get_viewport().gui_get_focus_owner() == button:
			break
		await _pad(JOY_BUTTON_DPAD_DOWN)
	_check(button != null and button.has_focus(), "controller reaches exact player")
	await _pad(JOY_BUTTON_A)
	var inspector: SeasonPlayerInspector = _inspector(ui)
	await _inspection_bounds(inspector, extent, stage)
	if inspector == null:
		return
	await _dismiss(inspector, false)
	_check(
		ui.shade.visible and ui._tab == "abilities" and button.has_focus(), "nested modal survives"
	)
	_check(
		(
			_app.season.build.to_data() == before
			and FileAccess.get_file_as_string(SeasonSave.path) == saved
		),
		"Equipped inspection preserves owned items and saved bytes"
	)
	await _click(ui.close_button)


func _pad(button_index: int) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button_index
		event.pressed = pressed
		get_viewport().push_input(event, true)
	await _frames()


func _inspection_bounds(
	inspector: SeasonPlayerInspector, parent_size: Vector2i, stage: String
) -> void:
	_check(inspector != null, "inspector opens: " + stage)
	if inspector == null:
		return
	await _frames()
	_check(
		(
			inspector.visible
			and inspector.size.x <= parent_size.x
			and inspector.size.y <= parent_size.y
		),
		(
			"inspector fits containing viewport: %s (%s within %s)"
			% [stage, inspector.size, parent_size]
		)
	)
	var container: Viewport = inspector.get_parent().get_viewport()
	var origin: Vector2i = Vector2i.ZERO
	if container is Window and container.is_embedded() and not container.gui_embed_subwindows:
		origin = container.position
	_check(
		Rect2i(origin, parent_size).encloses(Rect2i(inspector.position, inspector.size)),
		"inspector position stays inside its containing screen: " + stage
	)
	_check(inspector.get_ok_button().size.y >= 44, "Back has usable hit area")
	_check(inspector.gui_get_focus_owner() == inspector.get_ok_button(), "Back starts focused")
	_check(
		inspector.get_visible_rect().encloses(inspector.get_ok_button().get_global_rect()),
		"Back stays in the viewport"
	)
	for label: Node in inspector.body.find_children("*", "Label", true, false):
		var rect: Rect2 = label.get_global_rect()
		_check(
			rect.position.x >= 0 and rect.end.x <= inspector.size.x + 1, "no horizontal clipping"
		)
	await _capture(inspector, stage)
	await _capture(get_viewport(), stage + "-context")
	if inspector.body.size.y > inspector.scroll.size.y:
		var viewport: Viewport = inspector
		var point: Vector2 = inspector.scroll.get_global_rect().get_center()
		while viewport is Window and viewport.is_embedded():
			point += Vector2(viewport.position)
			var ancestor: Node = viewport.get_parent()
			while ancestor != null and not (ancestor is Viewport and ancestor.gui_embed_subwindows):
				ancestor = ancestor.get_parent()
			_check(ancestor != null, "inspection scroll has an input viewport")
			if ancestor == null:
				return
			viewport = ancestor as Viewport
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = point
		viewport.push_input(motion, true)
		for step in range(4):
			var wheel: InputEventMouseButton = InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			wheel.position = point
			viewport.push_input(wheel, true)
			wheel = wheel.duplicate()
			wheel.pressed = false
			viewport.push_input(wheel, true)
		await _frames()
		_check(inspector.scroll.scroll_vertical > 0, "actual wheel reaches repertoire: " + stage)
		await _capture(inspector, stage + "-repertoire")
		inspector.scroll.scroll_vertical = 0


func _dismiss(inspector: SeasonPlayerInspector, controller: bool) -> void:
	var event: InputEvent
	if controller:
		var pad: InputEventJoypadButton = InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_B
		pad.pressed = true
		event = pad
	else:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = true
		event = key
	get_viewport().push_input(event, true)
	await _frames()
	_check(not is_instance_valid(inspector), "dismissal releases modal")


func _inspect_button(parent: Node, id: String) -> Button:
	for node: Node in parent.find_children("*", "Button", true, false):
		if node.has_meta("inspect_player") and node.get_meta("inspect_player") == id:
			return node
	return null


func _inspector(parent: Node) -> SeasonPlayerInspector:
	for node: Node in parent.find_children("*", "Window", true, false):
		if node is SeasonPlayerInspector:
			return node
	return null


func _text(inspector: SeasonPlayerInspector) -> String:
	var result: PackedStringArray = []
	for label: Node in inspector.body.find_children("*", "Label", true, false):
		result.append(label.text)
	return "\n".join(result)
