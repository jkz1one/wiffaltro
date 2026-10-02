class_name SeasonPlayerInspector
extends AcceptDialog
## Read-only current-definition projection; dismissal restores the pending screen and pause.

var body: VBoxContainer
var scroll: ScrollContainer
var _previous_focus: WeakRef
var _lab: PitchBatLab
var _was_paused: bool = false
var _was_tree_paused: bool = false
var _opened: bool = false


static func open_from(parent: Node, player: PlayerDefinition) -> SeasonPlayerInspector:
	var inspector: SeasonPlayerInspector = SeasonPlayerInspector.new()
	parent.add_child(inspector)
	inspector.inspect(player)
	return inspector


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "Player details"
	ClubhouseTheme.confirmation(self)
	get_ok_button().text = "BACK  Esc / B"
	get_label().hide()
	confirmed.connect(close)
	canceled.connect(close)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.custom_minimum_size.y = 120
	scroll.get_v_scroll_bar().custom_minimum_size.x = 12
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	get_ok_button().focus_neighbor_top = get_ok_button().get_path_to(scroll)
	get_ok_button().focus_neighbor_bottom = get_ok_button().get_path_to(scroll)
	scroll.focus_neighbor_top = scroll.get_path_to(get_ok_button())
	scroll.focus_neighbor_bottom = scroll.get_path_to(get_ok_button())


func inspect(player: PlayerDefinition) -> void:
	_previous_focus = weakref(get_parent().get_viewport().gui_get_focus_owner())
	_was_tree_paused = get_tree().paused
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is PitchBatLab:
			_lab = ancestor
			break
		ancestor = ancestor.get_parent()
	if _lab != null:
		_was_paused = _lab._debug_paused
		_lab.set_meta("player_inspection_open", true)
		_lab._debug_paused = true
	_opened = true
	get_tree().paused = true
	_render(player)
	var viewport: Viewport = get_parent().get_viewport()
	var extent: Vector2i = Vector2i(viewport.get_visible_rect().size)
	var requested: Vector2i = Vector2i(mini(760, extent.x - 32), mini(600, extent.y - 64))
	var origin: Vector2i = Vector2i.ZERO
	if viewport is Window:
		if not is_embedded() or (viewport.is_embedded() and not viewport.gui_embed_subwindows):
			origin = viewport.position
	popup(Rect2i(origin + (extent - requested) / 2, requested))
	get_ok_button().grab_focus()


func _render(player: PlayerDefinition) -> void:
	var heading: Label = _line(body, player.display_name, 28)
	heading.add_theme_color_override("font_color", ClubhouseTheme.GOLD)
	_line(
		body,
		(
			"Bats / Throws: %s • %s"
			% [SeasonPlayerCard.hands(player), SeasonPlayerCard.STYLE_NAMES[player.pitching_style]]
		)
	)
	_line(body, "CURRENT RATINGS", 15)
	var names: Array[String] = SeasonPlayerCard.rating_names(player)
	var values: Array[int] = SeasonPlayerCard.values(player)
	var ratings: GridContainer = GridContainer.new()
	ratings.columns = names.size()
	ratings.add_theme_constant_override("h_separation", 16)
	body.add_child(ratings)
	for name: String in names:
		_line(ratings, name)
	for value: int in values:
		_line(ratings, "%d / 10" % value, 22)
	if player.progression_test:
		_line(
			body,
			"Pitching develops command and endurance. Recipe speed and movement come from mastery.",
			16
		)
	_line(
		body,
		"REPERTOIRE • %d / %d slots" % [player.starting_pitches.size(), player.pitch_capacity],
		15
	)
	for recipe: PitchDefinition in player.starting_pitches:
		var card: VBoxContainer = SeasonPlayerCard.panel(body)
		_line(card, SeasonPlayerCard.pitch_name(player, recipe), 21)
		_line(card, recipe.delivery_profile.display_name, 16)
		if player.progression_test:
			_line(
				card,
				(
					"Base speed: %.1f mph • movement ×%.2f • execution spread ×%.3f"
					% [
						recipe.nominal_velocity_mps * 2.236936,
						recipe.mastery_movement_scale,
						recipe.mastery_noise_scale
					]
				),
				16
			)
			_line(card, "Next level: " + PitchMastery.next_effect(recipe))
	var abilities: String = SeasonAbilities.description(player)
	if not abilities.is_empty():
		_line(body, "LEARNED THIS SEASON", 15)
		_line(body, abilities)
	_line(
		body,
		(
			(
				"Working calibration • Next-level effects describe this recipe before effort, fatigue "
				+ "and temporary modifiers. Return with Esc or controller B."
			)
			if player.progression_test
			else "Current vanilla attributes and repertoire. Return with Esc or controller B."
		),
		16
	)


static func _line(parent: Node, text: String, font_size: int = 18) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	if font_size <= 17:
		ClubhouseTheme.section(label)
	parent.add_child(label)
	return label


func close() -> void:
	_restore()
	queue_free()


func _restore() -> void:
	if not _opened:
		return
	_opened = false
	hide()
	get_tree().paused = _was_tree_paused
	if is_instance_valid(_lab):
		_lab.remove_meta("player_inspection_open")
		_lab._debug_paused = _was_paused
		if _lab.is_inside_tree():
			_lab._refresh_config()
	var target: Control = _previous_focus.get_ref() if _previous_focus != null else null
	if (
		is_instance_valid(target)
		and target.is_inside_tree()
		and not target.is_queued_for_deletion()
		and target.is_visible_in_tree()
	):
		target.grab_focus()


func _exit_tree() -> void:
	_restore()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var pad_cancel: bool = (
		event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B
	)
	if event.is_action_pressed(&"ui_cancel") or pad_cancel:
		get_viewport().set_input_as_handled()
		close()
