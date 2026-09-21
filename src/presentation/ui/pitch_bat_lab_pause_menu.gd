class_name PitchBatLabPauseMenu
extends PanelContainer

var _lab: PitchBatLab
var _main: VBoxContainer
var _title: Label


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
	_button(_main, "SETTINGS", lab._toggle_display_menu)
	_button(_main, "CHANGE CAMERA  •  V", lab._cycle_camera)
	lab._display_menu_panel = VBoxContainer.new()
	lab._display_menu_panel.add_theme_constant_override("separation", 8)
	layout.add_child(lab._display_menu_panel)
	lab._hud_anchor_button = _button(lab._display_menu_panel, "", lab._cycle_hud_anchor)
	lab._backdrop_button = _button(lab._display_menu_panel, "", lab._toggle_sky_backdrop)
	_button(lab._display_menu_panel, "BACK", lab._toggle_display_menu)
	var hint: Label = Label.new()
	hint.text = "Play stays frozen while you inspect."
	hint.add_theme_font_size_override("font_size", 12)
	layout.add_child(hint)
	refresh()


func refresh() -> void:
	visible = _lab._debug_paused
	_main.visible = not _lab._display_menu_open
	_lab._display_menu_panel.visible = _lab._display_menu_open and visible
	_title.text = "SETTINGS" if _lab._display_menu_open else "PAUSED"
	var anchors: Array[String] = ["Bottom right", "Top left", "Top right"]
	_lab._hud_anchor_button.text = "Score box: " + anchors[_lab._hud_anchor_index]
	_lab._backdrop_button.text = "Backdrop: " + (
		"Blue sky" if _lab._sky_backdrop_enabled else "Green"
	)
	_lab._display_menu_button.text = "RESUME  Esc" if visible else "PAUSE  Esc"
	size.y = get_combined_minimum_size().y


func _resume() -> void:
	PitchBatLabFeelSupport.toggle_debug_pause(_lab)


static func _button(parent: Control, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(254.0, 38.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button
