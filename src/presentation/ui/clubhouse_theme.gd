class_name ClubhouseTheme
extends RefCounted

const INK: Color = Color("0c1918")
const SURFACE: Color = Color("152927")
const RAISED: Color = Color("203b36")
const LINE: Color = Color("456059")
const PAPER: Color = Color("f3eedc")
const MUTED: Color = Color("afc2b5")
const GOLD: Color = Color("edc374")
const GREEN: Color = Color("a4d6b1")
const RED: Color = Color("efa18b")


static func surface(selected: bool = false, padding: float = 16.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = RAISED if selected else SURFACE
	style.border_color = GOLD if selected else LINE
	style.set_border_width_all(1)
	style.border_width_top = 3 if selected else 1
	style.set_corner_radius_all(7)
	style.set_content_margin_all(padding)
	return style


static func create() -> Theme:
	var result: Theme = Theme.new()
	result.default_font_size = 18
	result.set_color("font_color", "Label", PAPER)
	for type in ["Button", "OptionButton", "CheckButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBoxFlat = surface(false, 10)
			style.content_margin_top = 5
			style.content_margin_bottom = 5
			style.bg_color = RAISED if state == "hover" else SURFACE
			if state == "pressed":
				style.bg_color = Color("33584a")
				style.border_color = GOLD
			if state == "disabled":
				style.bg_color = INK
				style.border_color = Color("293e37")
			result.set_stylebox(state, type, style)
		result.set_color("font_color", type, PAPER)
		result.set_color("font_hover_color", type, PAPER)
		result.set_color("font_pressed_color", type, PAPER)
		result.set_color("font_disabled_color", type, Color("84988d"))
		var focus: StyleBoxFlat = surface(true, 0)
		focus.draw_center = false
		focus.set_border_width_all(2)
		result.set_stylebox("focus", type, focus)
	result.set_stylebox("panel", "PanelContainer", surface())
	result.set_stylebox("panel", "PopupMenu", surface())
	result.set_stylebox("panel", "TooltipPanel", surface(false, 10))
	result.set_color("font_color", "TooltipLabel", PAPER)
	result.set_font_size("font_size", "TooltipLabel", 14)
	result.set_color("font_color", "PopupMenu", PAPER)
	result.set_color("font_hover_color", "PopupMenu", INK)
	var highlight: StyleBoxFlat = surface(true, 6)
	highlight.bg_color = GOLD
	result.set_stylebox("hover", "PopupMenu", highlight)
	for state in ["tab_selected", "tab_unselected", "tab_hovered"]:
		result.set_stylebox(state, "TabBar", surface(state == "tab_selected", 10))
	result.set_color("font_selected_color", "TabBar", GOLD)
	result.set_color("font_unselected_color", "TabBar", MUTED)
	var track: StyleBoxFlat = surface(false, 0)
	track.bg_color = INK
	track.set_border_width_all(0)
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = GREEN
	result.set_stylebox("background", "ProgressBar", track)
	result.set_stylebox("fill", "ProgressBar", fill)
	result.set_stylebox("scroll", "VScrollBar", track)
	result.set_stylebox("grabber", "VScrollBar", surface(false, 5))
	result.set_stylebox("grabber_highlight", "VScrollBar", highlight)
	result.set_stylebox("grabber_pressed", "VScrollBar", highlight)
	return result


static func primary(button: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = surface(true, 12)
		style.bg_color = GOLD.lightened(0.12) if state == "hover" else GOLD
		if state == "pressed":
			style.bg_color = GOLD.darkened(0.12)
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, INK)


static func table_cell(label: Label, row: int, highlight: bool = false) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SURFACE if row % 2 == 0 else RAISED
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.content_margin_left = 5
	style.content_margin_right = 5
	label.add_theme_stylebox_override("normal", style)
	label.add_theme_color_override("font_color", GOLD if highlight else PAPER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func section(label: Label) -> void:
	label.add_theme_color_override("font_color", MUTED)
