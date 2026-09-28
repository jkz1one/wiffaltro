class_name PitchBatLabPauseMenu
extends PanelContainer

var stats: MatchStatsPanel
var settings: GameSettingsPanel
var _lab: PitchBatLab
var _main: VBoxContainer
var _title: Label
var _mute_button: Button
var _leave_button: Button
var _stats_button: Button
var _showing_settings: bool = false
var _controls: VBoxContainer
var _controls_button: Button


func build(lab: PitchBatLab) -> void:
	_lab = lab
	name = "PauseMenu"
	position = Vector2(32.0, 178.0)
	custom_minimum_size = Vector2(336.0, 0.0)
	z_index = 20
	theme = ClubhouseTheme.create()
	var style: StyleBoxFlat = ClubhouseTheme.surface(false, 18)
	add_theme_stylebox_override("panel", style)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	var brand: Label = Label.new()
	brand.text = "WIFFALTRO   /   MATCH MENU"
	brand.add_theme_font_size_override("font_size", 13)
	brand.add_theme_color_override("font_color", ClubhouseTheme.GOLD)
	layout.add_child(brand)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	layout.add_child(_title)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 8)
	layout.add_child(_main)
	_button(_main, "RESUME  •  Esc", _resume)
	_stats_button = _button(_main, "PLAYER RATINGS & STATS", open_stats)
	_stats_button.focus_mode = Control.FOCUS_ALL
	_button(_main, "SETTINGS", lab._toggle_display_menu)
	_controls_button = _button(_main, "CONTROLS", open_controls)
	_button(_main, "CHANGE CAMERA  •  V", lab._cycle_camera)
	if lab._managed_match:
		_leave_button = _button(_main, "LEAVE GAME", lab.menu_exit_requested.emit)
	settings = GameSettingsPanel.new()
	lab._display_menu_panel = settings
	layout.add_child(settings)
	settings.build(lab)
	lab._hud_anchor_button = settings.anchor_button
	lab._backdrop_button = settings.backdrop_button
	_mute_button = settings.mute_button
	_button(settings, "BACK", lab._toggle_display_menu)
	_controls = VBoxContainer.new()
	layout.add_child(_controls)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 270)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_controls.add_child(scroll)
	var guide: VBoxContainer = VBoxContainer.new()
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.add_theme_constant_override("separation", 12)
	scroll.add_child(guide)
	ControlsGuide.populate(guide)
	_button(_controls, "BACK", close_controls)
	_controls.hide()
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
	var was_visible: bool = visible
	var settings_changed: bool = _showing_settings != _lab._display_menu_open
	_showing_settings = _lab._display_menu_open
	if not _lab._debug_paused:
		stats.hide()
		_controls.hide()
	visible = _lab._debug_paused and not stats.visible
	_stats_button.disabled = not _lab._match_mode or _lab._match_state == null
	_main.visible = not _lab._display_menu_open and not _controls.visible
	_lab._display_menu_panel.visible = _lab._display_menu_open and visible
	settings.refresh()
	_title.text = "CONTROLS" if _controls.visible else (
		"SETTINGS" if _lab._display_menu_open else "PAUSED"
	)
	if visible and (not was_visible or settings_changed):
		var active: VBoxContainer = _lab._display_menu_panel if _showing_settings else _main
		(active.get_child(0) as Button).grab_focus()
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


func open_controls() -> void:
	_controls.show()
	refresh()
	(_controls.get_child(1) as Button).grab_focus()


func close_controls() -> void:
	_controls.hide()
	refresh()
	_controls_button.grab_focus()


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
	button.custom_minimum_size = Vector2(300.0, 42.0)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	parent.add_child(button)
	if text.begins_with("RESUME"):
		ClubhouseTheme.primary(button)
	return button
