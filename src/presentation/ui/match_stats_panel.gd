class_name MatchStatsPanel
extends PanelContainer

signal back_requested

var _lab: PitchBatLab
var _team: OptionButton
var _tabs: TabBar
var _body: VBoxContainer
var _scroll: ScrollContainer
var _back: Button


func build(lab: PitchBatLab) -> void:
	_lab = lab
	name = "MatchStats"
	position = Vector2(100, 42)
	size = Vector2(1080, 630)
	z_index = 30
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("102332")
	style.set_content_margin_all(20)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	SeasonPlayerCard.line(layout, "PLAYER STATS", 26)
	_team = OptionButton.new()
	_team.custom_minimum_size.y = 36
	_team.add_theme_font_size_override("font_size", 20)
	_team.item_selected.connect(func(_index: int) -> void: refresh())
	layout.add_child(_team)
	_tabs = TabBar.new()
	_tabs.add_tab("Ratings & repertoire")
	_tabs.add_tab("This game")
	_tabs.add_theme_font_size_override("font_size", 18)
	_tabs.tab_changed.connect(func(_index: int) -> void: refresh())
	layout.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	layout.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	_scroll.add_child(_body)
	_back = Button.new()
	_back.text = "BACK TO PAUSE  •  Esc"
	_back.custom_minimum_size.y = 40
	_back.pressed.connect(func() -> void: back_requested.emit())
	layout.add_child(_back)
	hide()


func open() -> void:
	_team.clear()
	var state: MatchState = _lab._match_state
	var own: TeamMatchState = state.home_team if _lab._player_home else state.away_team
	var other: TeamMatchState = state.away_team if _lab._player_home else state.home_team
	_team.add_item(own.display_name + " • Your team")
	_team.add_item(other.display_name + " • Opponent")
	_team.selected = 0
	_tabs.current_tab = 0
	refresh()
	show()
	_team.grab_focus()


func selected_team() -> TeamMatchState:
	var home: bool = _lab._player_home if _team.selected == 0 else not _lab._player_home
	return _lab._match_state.home_team if home else _lab._match_state.away_team


func refresh() -> void:
	if _lab._match_state == null or _team.item_count == 0:
		return
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_scroll.scroll_vertical = 0
	if _tabs.current_tab == 0:
		_ratings()
	else:
		_box_score()


func _ratings() -> void:
	var team: TeamMatchState = selected_team()
	for index in range(team.roster.size()):
		var player: PlayerMatchState = team.roster[index]
		var definition: PlayerDefinition = player.definition
		var box: VBoxContainer = SeasonPlayerCard.panel(_body)
		var role: String = ""
		if index == team.pitcher_index:
			role = " • Pitcher"
		elif index == team.fielder_index:
			role = " • Primary Fielder"
		SeasonPlayerCard.line(box, "%d. %s%s" % [index + 1, definition.display_name, role], 21)
		SeasonPlayerCard.line(box, "Bats / Throws: %s • Stamina remaining: %.0f%%%s" % [
			SeasonPlayerCard.hands(definition), player.stamina_percent() * 100.0,
			" • Used arm" if player.pitching_finished else ""], 17)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 25)
		box.add_child(grid)
		for label in SeasonPlayerCard.RATING_NAMES:
			SeasonPlayerCard.line(grid, label, 17)
		for value in SeasonPlayerCard.values(definition):
			SeasonPlayerCard.line(grid, str(value), 20)
		var pitches: PackedStringArray = []
		for pitch in definition.starting_pitches:
			pitches.append(pitch.display_name)
		_wrapped(box, "Pitches: " + " • ".join(pitches))


func _box_score() -> void:
	var data: Dictionary = _lab._match_state.performance.snapshot(_lab._match_state)
	_wrapped(_body, "This game only. Batting results update after each plate appearance; "
		+ "pitch counts include the current batter.")
	for pitching in [false, true]:
		SeasonPlayerCard.line(_body, "PITCHING" if pitching else "BATTING", 22)
		var keys: Array = ["outs", "p_h", "p_bb", "p_k", "pitches"] if pitching else (
			["pa", "h", "double", "triple", "hr", "bb", "k", "rbi"])
		var headings: Array = ["OUTS", "H", "BB", "K", "PITCHES"] if pitching else (
			["PA", "H", "2B", "3B", "HR", "BB", "K", "RBI"])
		var grid: GridContainer = GridContainer.new()
		grid.columns = keys.size() + 1
		grid.add_theme_constant_override("h_separation", 22)
		grid.add_theme_constant_override("v_separation", 10)
		_body.add_child(grid)
		SeasonPlayerCard.line(grid, "PLAYER", 17)
		for heading: String in headings:
			SeasonPlayerCard.line(grid, heading, 17)
		for player in selected_team().roster:
			SeasonPlayerCard.line(grid, player.definition.display_name, 20)
			var line: Dictionary = data[String(player.definition.id)]
			for key: String in keys:
				SeasonPlayerCard.line(grid, str(line[key]), 20)
	_wrapped(_body, "PA: plate appearances • H: hits • BB: walks • K: strikeouts "
		+ "• RBI: runs batted in")
	_wrapped(_body, "Pitching H / BB are allowed. OUTS includes strikeouts. Play remains paused.")


static func _wrapped(parent: Node, text: String) -> void:
	var label: Label = SeasonPlayerCard.line(parent, text, 17)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
