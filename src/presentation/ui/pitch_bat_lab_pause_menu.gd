class_name PitchBatLabPauseMenu
extends PanelContainer

var stats: MatchStatsPanel
var _lab: PitchBatLab
var _main: VBoxContainer
var _title: Label
var _mute_button: Button
var _leave_button: Button
var _stats_button: Button


func build(lab: PitchBatLab) -> void:
	_lab = lab
	name = "PauseMenu"
	position = Vector2(18.0, 190.0)
	custom_minimum_size = Vector2(286.0, 0.0)
	z_index = 20
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.085, 0.97)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	add_theme_stylebox_override("panel", style)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	layout.add_child(_title)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 8)
	layout.add_child(_main)
	_button(_main, "RESUME  •  Esc", _resume)
	_stats_button = _button(_main, "PLAYER STATS", open_stats)
	_stats_button.focus_mode = Control.FOCUS_ALL
	_button(_main, "SETTINGS", lab._toggle_display_menu)
	_button(_main, "CHANGE CAMERA  •  V", lab._cycle_camera)
	if lab._managed_match:
		_leave_button = _button(_main, "LEAVE GAME", lab.menu_exit_requested.emit)
	lab._display_menu_panel = VBoxContainer.new()
	lab._display_menu_panel.add_theme_constant_override("separation", 8)
	layout.add_child(lab._display_menu_panel)
	lab._hud_anchor_button = _button(lab._display_menu_panel, "", lab._cycle_hud_anchor)
	lab._backdrop_button = _button(lab._display_menu_panel, "", lab._toggle_sky_backdrop)
	_mute_button = _button(lab._display_menu_panel, "", _toggle_mute)
	_button(lab._display_menu_panel, "BACK", lab._toggle_display_menu)
	var hint: Label = Label.new()
	hint.text = "Play stays frozen while you inspect."
	hint.add_theme_font_size_override("font_size", 12)
	layout.add_child(hint)
	stats = MatchStatsPanel.new()
	get_parent().add_child(stats)
	stats.build(lab)
	stats.back_requested.connect(close_stats)
	refresh()


func refresh() -> void:
	if not _lab._debug_paused:
		stats.hide()
	visible = _lab._debug_paused and not stats.visible
	_stats_button.disabled = not _lab._match_mode or _lab._match_state == null
	_main.visible = not _lab._display_menu_open
	_lab._display_menu_panel.visible = _lab._display_menu_open and visible
	_mute_button.text = "Mute sounds: " + ("On" if _lab._sounds_muted else "Off")
	_title.text = "SETTINGS" if _lab._display_menu_open else "PAUSED"
	if _leave_button != null:
		_leave_button.disabled = (
			_lab._match_state != null and _lab._match_state.phase == MatchState.Phase.GAME_END
		)
		_leave_button.tooltip_text = "Resume to view the final result." if _leave_button.disabled else ""
	var anchors: Array[String] = ["Bottom right", "Top left", "Top right"]
	_lab._hud_anchor_button.text = "Score box: " + anchors[_lab._hud_anchor_index]
	_lab._backdrop_button.text = "Backdrop: " + (
		"Blue sky" if _lab._sky_backdrop_enabled else "Green"
	)
	_lab._display_menu_button.text = "RESUME  Esc" if _lab._debug_paused else "PAUSE  Esc"
	size.y = get_combined_minimum_size().y


func _toggle_mute() -> void:
	_lab._sounds_muted = not _lab._sounds_muted
	_lab._sounds.set_muted(_lab._sounds_muted)
	PitchBatLabSettings.save(_lab)
	refresh()


func _resume() -> void:
	PitchBatLabFeelSupport.toggle_debug_pause(_lab)


func open_stats() -> void:
	if not _lab._debug_paused or not _lab._match_mode or _lab._match_state == null:
		return
	stats.open()
	refresh()


func close_stats() -> void:
	stats.hide()
	refresh()
	_stats_button.grab_focus()


static func _button(parent: Control, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(254.0, 38.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button
