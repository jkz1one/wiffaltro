class_name PitchPicker
extends PanelContainer

var _lab: PitchBatLab
var _title: Label
var _condition: Label
var _stamina: ProgressBar
var _stamina_fill: StyleBoxFlat
var _grid: GridContainer
var _selected: Label
var _buttons: Array[Button] = []


func build(lab: PitchBatLab) -> void:
	_lab = lab
	name = "PitchPicker"
	custom_minimum_size = Vector2(252.0, 0.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.085, 0.92)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", style)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	add_child(layout)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	layout.add_child(_title)
	_condition = Label.new()
	_condition.add_theme_font_size_override("font_size", 12)
	layout.add_child(_condition)
	_stamina = ProgressBar.new()
	_stamina.custom_minimum_size = Vector2(0.0, 7.0)
	_stamina.show_percentage = false
	layout.add_child(_stamina)
	_stamina_fill = StyleBoxFlat.new()
	_stamina_fill.bg_color = Color(0.25, 0.75, 0.55)
	_stamina.add_theme_stylebox_override("fill", _stamina_fill)
	_selected = Label.new()
	_selected.add_theme_font_size_override("font_size", 14)
	layout.add_child(_selected)
	_grid = GridContainer.new()
	_grid.columns = 1
	layout.add_child(_grid)
	for index in range(9):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(228.0, 28.0)
		button.add_theme_font_size_override("font_size", 14)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.pressed.connect(_select.bind(index))
		_grid.add_child(button)
		_buttons.append(button)


func refresh() -> void:
	visible = (
		_lab._match_mode and _lab._player_is_pitching()
		and not _lab._field_setup_active and not _lab._pitching_staff_active
		and not _lab._debug_overlay_visible and not _lab._debug_paused
		and not _lab._home_run.active
		and not _lab._match_presentation_director.blocks_gameplay()
	)
	if not visible:
		return
	position = Vector2(18.0, 198.0 if _lab._hud_anchor_index == 1 else 18.0)
	var pitcher: PlayerMatchState = _lab._match_state.pitcher()
	_title.text = pitcher.definition.display_name
	var fatigue: float = maxf(pitcher.fatigue_ratio(), _lab._fatigue)
	_condition.text = "%d P  •  %.0f%% stamina  •  %s" % [
		pitcher.pitch_count, pitcher.stamina_percent() * 100.0,
		PitchExecutionModel.fatigue_stage_name(fatigue).capitalize().replace("Batting practice", "Empty")
	]
	_stamina.value = pitcher.stamina_percent() * 100.0
	_stamina_fill.bg_color = (
		Color(0.88, 0.20, 0.15) if fatigue >= 0.83 else Color(0.25, 0.75, 0.55)
	)
	var options: Array[PitchDefinition] = _lab._current_pitch_options()
	_grid.visible = MatchLabSupport.can_edit_pitch_plan(_lab)
	_selected.visible = not _grid.visible
	_selected.text = _lab._selected_pitch().display_name
	for index in range(_buttons.size()):
		var button: Button = _buttons[index]
		button.visible = index < options.size()
		if not button.visible:
			continue
		var pitch: PitchDefinition = options[index]
		button.text = "%d  %s" % [index + 1, pitch.display_name]
		button.tooltip_text = pitch.display_name + "\n" + pitch.tactical_description
		button.button_pressed = index == _lab._selected_pitch_index
		button.disabled = not MatchLabSupport.can_edit_pitch_plan(_lab)
	size.y = get_combined_minimum_size().y


func _select(index: int) -> void:
	if not MatchLabSupport.can_edit_pitch_plan(_lab):
		return
	if index >= _lab._current_pitch_options().size():
		return
	_lab._selected_pitch_index = index
	_lab._refresh_config()
