class_name MatchScorebug
extends Control

const PANEL_SIZE: Vector2 = Vector2(320.0, 108.0)
const EMPTY_BASE_COLOR: Color = Color(0.08, 0.12, 0.16, 0.92)
const OCCUPIED_BASE_COLOR: Color = Color(0.98, 0.78, 0.16, 1.0)

var _away_name: Label
var _away_score: Label
var _home_name: Label
var _home_score: Label
var _inning: Label
var _count: Label
var _outs: Label
var _pitcher: Label
var _batter: Label
var _base_markers: Array[Panel] = []
var _built: bool = false


func _ready() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_built()


func refresh(match_state: MatchState) -> void:
	_ensure_built()
	if match_state == null:
		visible = false
		return
	visible = true
	_away_name.text = match_state.away_team.display_name
	_away_score.text = str(match_state.away_team.runs)
	_home_name.text = match_state.home_team.display_name
	_home_score.text = str(match_state.home_team.runs)
	_inning.text = "%s %d" % ["▲" if match_state.top_half else "▼", match_state.inning]
	_count.text = "%d–%d" % [match_state.balls, match_state.strikes]
	_outs.text = (
		"%d OUT%s"
		% [
			match_state.outs,
			"" if match_state.outs == 1 else "S",
		]
	)
	var pitcher_state: PlayerMatchState = match_state.pitcher()
	var batter_state: PlayerMatchState = match_state.batter()
	_pitcher.text = (
		"PIT  %s   P:%d   STA %.0f%%"
		% [
			pitcher_state.definition.display_name,
			pitcher_state.pitch_count,
			pitcher_state.stamina_percent() * 100.0,
		]
	)
	_batter.text = "BAT  %s" % batter_state.definition.display_name
	_set_base(0, not match_state.bases.first.is_empty())
	_set_base(1, not match_state.bases.second.is_empty())
	_set_base(2, not match_state.bases.third.is_empty())


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_build()


func _build() -> void:
	var background: Panel = Panel.new()
	background.size = PANEL_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.025, 0.055, 0.085, 0.96), Color(0.78, 0.84, 0.88, 0.9), 2)
	)
	add_child(background)

	var away_band: ColorRect = _band(Color(0.10, 0.28, 0.48, 0.96), Vector2(7.0, 7.0))
	background.add_child(away_band)
	var home_band: ColorRect = _band(Color(0.62, 0.18, 0.14, 0.96), Vector2(7.0, 34.0))
	background.add_child(home_band)

	_away_name = _label(background, Vector2(15.0, 7.0), Vector2(104.0, 27.0), 17)
	_away_score = _label(
		background, Vector2(119.0, 7.0), Vector2(38.0, 27.0), 19, HORIZONTAL_ALIGNMENT_CENTER
	)
	_home_name = _label(background, Vector2(15.0, 34.0), Vector2(104.0, 27.0), 17)
	_home_score = _label(
		background, Vector2(119.0, 34.0), Vector2(38.0, 27.0), 19, HORIZONTAL_ALIGNMENT_CENTER
	)

	var game_block: Panel = Panel.new()
	game_block.position = Vector2(163.0, 7.0)
	game_block.size = Vector2(150.0, 54.0)
	game_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_block.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.015, 0.027, 0.04, 0.94), Color(0.22, 0.31, 0.38, 1.0), 1)
	)
	background.add_child(game_block)
	_inning = _label(game_block, Vector2(8.0, 3.0), Vector2(47.0, 23.0), 15)
	_count = _label(game_block, Vector2(8.0, 25.0), Vector2(58.0, 25.0), 18)
	_outs = _label(game_block, Vector2(53.0, 4.0), Vector2(48.0, 20.0), 10)

	_add_base_marker(game_block, Vector2(127.0, 33.0))
	_add_base_marker(game_block, Vector2(114.0, 20.0))
	_add_base_marker(game_block, Vector2(101.0, 33.0))

	var lower_band: ColorRect = ColorRect.new()
	lower_band.position = Vector2(7.0, 66.0)
	lower_band.size = Vector2(306.0, 35.0)
	lower_band.color = Color(0.035, 0.075, 0.105, 0.96)
	lower_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(lower_band)
	_batter = _label(background, Vector2(14.0, 65.0), Vector2(292.0, 18.0), 12)
	_pitcher = _label(background, Vector2(14.0, 82.0), Vector2(292.0, 18.0), 12)


func _set_base(index: int, occupied: bool) -> void:
	if index < 0 or index >= _base_markers.size():
		return
	_base_markers[index].add_theme_stylebox_override(
		"panel",
		_panel_style(
			OCCUPIED_BASE_COLOR if occupied else EMPTY_BASE_COLOR, Color(0.82, 0.87, 0.90, 1.0), 1
		)
	)


func _add_base_marker(parent: Control, offset: Vector2) -> void:
	var marker: Panel = Panel.new()
	marker.position = offset
	marker.size = Vector2(12.0, 12.0)
	marker.pivot_offset = Vector2(6.0, 6.0)
	marker.rotation = deg_to_rad(45.0)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(marker)
	_base_markers.append(marker)
	_set_base(_base_markers.size() - 1, false)


static func _band(color: Color, offset: Vector2) -> ColorRect:
	var band: ColorRect = ColorRect.new()
	band.position = offset
	band.size = Vector2(150.0, 27.0)
	band.color = color
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return band


static func _label(
	parent: Control,
	offset: Vector2,
	label_size: Vector2,
	font_size: int,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label: Label = Label.new()
	label.position = offset
	label.size = label_size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


static func _panel_style(
	background_color: Color, border_color: Color, border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style
