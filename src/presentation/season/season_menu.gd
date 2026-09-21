class_name SeasonMenu
extends PanelContainer

var app: SeasonApp
var page: String = "home"
var draft_selection: String = ""
var _layout: VBoxContainer
var _body: VBoxContainer
var _footer: HBoxContainer


func build(owner_app: SeasonApp) -> void:
	app = owner_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("091722")
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	add_theme_stylebox_override("panel", style)
	add_theme_font_size_override("font_size", 18)
	theme = Theme.new()
	theme.set_color("font_color", "Label", Color("eef3f7"))
	theme.set_color("font_color", "Button", Color("eef3f7"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var button_style: StyleBoxFlat = StyleBoxFlat.new()
		button_style.bg_color = Color("29475b") if state == "hover" else Color("193448")
		button_style.border_color = Color("f2c66d") if state == "focus" else Color("59788d")
		button_style.set_border_width_all(2 if state == "focus" else 1)
		button_style.set_corner_radius_all(5)
		button_style.content_margin_left = 14
		button_style.content_margin_right = 14
		theme.set_stylebox(state, "Button", button_style)
	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 18)
	add_child(_layout)


func _screen(key: String, title: String, subtitle: String) -> void:
	page = key
	show()
	for child in _layout.get_children():
		_layout.remove_child(child)
		child.queue_free()
	_label(_layout, title, 34)
	_label(_layout, subtitle, 18)
	if not app.notice.is_empty():
		var warning: Label = _label(_layout, app.notice, 16)
		warning.modulate = Color(1, 0.75, 0.45)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_layout.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_body)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 12)
	_layout.add_child(_footer)
	_focus_first.call_deferred()


func show_home() -> void:
	_screen("home", "WIFFALTRO", "YOUR CLUB. YOUR SEASON.")
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_body.add_child(row)
	var club: VBoxContainer = SeasonPlayerCard.panel(row, true)
	_label(club, "SEASON", 28)
	_label(club, "Draft four players. Build a team. Chase the title.", 20)
	if app.season != null:
		var progress: String = "Tryout %d of 4" % (app.season.picks.size() + 1)
		if app.season.phase != SeasonState.Phase.DRAFT:
			progress = "%d of 10 regular games completed" % app.season.round_index
		_label(club, progress, 18)
		_button(club, "CONTINUE SEASON", app.show_season)
	_button(club, "NEW SEASON", app.ask_new_season)
	var quick: VBoxContainer = SeasonPlayerCard.panel(row)
	_label(quick, "EXHIBITION", 28)
	_label(quick, "One game. No season progress changed.", 20)
	_button(quick, "PLAY EXHIBITION", app.play_exhibition)
	_label(_body, "Mouse: aim • Left click: contact / pitch • Right click: power", 18)
	_label(
		_body,
		"Esc: pause, settings and leave game. Progress saves automatically between games.",
		18
	)
	_button(_footer, "QUIT", get_tree().quit)


func show_preseason() -> void:
	_screen(
		"preseason",
		"START YOUR SEASON",
		"1  SETUP    /    2  TRYOUTS    /    3  LINEUP    /    4  PLAY"
	)
	var box: VBoxContainer = SeasonPlayerCard.panel(_body, true)
	_label(box, "BACKYARD LEAGUE", 28)
	_label(box, "6 clubs • 10 games • Top 4 playoffs • 5-inning games", 22)
	_label(box, "Four two-way players. One Pitcher and one Primary Fielder on defense.", 20)
	_label(box, "One starter field for now, including the neutral championship.", 18)
	_label(_body, "PITCHING STRATEGY DIFFICULTY", 20)
	var choice: OptionButton = OptionButton.new()
	choice.custom_minimum_size = Vector2(400, 42)
	for text in [
		"Relaxed • more pitches to attack",
		"Standard • count-aware variety",
		"Tactical • more edges and sequencing"
	]:
		choice.add_item(text)
	choice.select(app.difficulty_choice)
	choice.item_selected.connect(func(index: int) -> void: app.difficulty_choice = index)
	_body.add_child(choice)
	_label(
		_body, "Same player ratings and physics. Tactics develop gradually over the schedule.", 18
	)
	_label(
		_body, "Draft 4 from 12 offers. Compare all seven ratings and the actual pitch arsenal.", 20
	)
	_label(
		_body, "Autosaves after picks, lineup edits and final scores. Unfinished games restart.", 18
	)
	_button(_footer, "START TRYOUTS", app.begin_season)
	_button(_footer, "BACK", show_home)


func show_draft() -> void:
	_screen(
		"draft",
		"TRYOUT %d OF 4" % (app.season.picks.size() + 1),
		"Select a card to compare, then confirm your pick. Ratings are 0–10; higher is stronger."
	)
	var names: PackedStringArray = []
	for id in app.season.picks:
		names.append(ContentDB.get_player(StringName(id)).display_name)
	_label(_body, "YOUR CLUB  " + (", ".join(names) if not names.is_empty() else "First pick"), 18)
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	_body.add_child(cards)
	for id in app.season.offers():
		SeasonPlayerCard.draft_card(
			cards,
			ContentDB.get_player(StringName(id)),
			id == draft_selection,
			_select_draft.bind(id)
		)
	var label: String = "SELECT A PLAYER"
	if not draft_selection.is_empty():
		label = "DRAFT " + ContentDB.get_player(StringName(draft_selection)).display_name.to_upper()
	var confirm: Button = _button(_footer, label, app.choose_player.bind(draft_selection))
	confirm.disabled = draft_selection.is_empty()
	_button(_footer, "MAIN MENU", show_home)


func _select_draft(id: String) -> void:
	if app.season.offers().has(id):
		draft_selection = id
		show_draft()


func show_hub() -> void:
	var season: SeasonState = app.season
	var title: String = "GAME %d OF 10" % (season.round_index + 1)
	if season.phase == SeasonState.Phase.SEMIFINAL:
		title = "SEMIFINAL"
	elif season.phase == SeasonState.Phase.FINAL:
		title = "CHAMPIONSHIP"
	elif season.phase == SeasonState.Phase.COMPLETE:
		title = "CHAMPIONS" if season.champion == 0 else "SEASON COMPLETE"
	_screen("hub", title, "Backyard League • Yard Club")
	var fixture: Dictionary = season.pending_fixture()
	if not fixture.is_empty():
		_label(_body, _matchup(fixture), 26)
		_label(
			_body,
			(
				"Neutral final • Starter field"
				if fixture.get("neutral", false)
				else ("Home game" if fixture["home"] == 0 else "Away game")
			),
			16
		)
	else:
		_label(_body, "%s win the championship." % season.teams[season.champion]["name"], 26)
	_standings()
	_label(_body, "Ties: wins, run difference, runs scored, then preseason draw.", 14)
	if season.round_index >= 10:
		_label(_body, _playoffs(), 18)
	if not fixture.is_empty():
		_button(_footer, "PLAY GAME", app.play_season_game)
		_button(_footer, "LINEUP", show_lineup)
	else:
		_button(_footer, "NEW SEASON", app.ask_new_season)
	_button(_footer, "SCHEDULE", show_schedule)
	_button(_footer, "MAIN MENU", show_home)


func show_lineup() -> void:
	_screen(
		"lineup",
		"LINEUP & DEFENSE",
		"Edit freely before each game. Batting order locks when the game starts."
	)
	var roster: Array = app.season.teams[0]["roster"]
	var grid: GridContainer = GridContainer.new()
	grid.columns = 11
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	for heading in [
		"BATTING ORDER",
		"B / T",
		"Contact",
		"Power",
		"Fielding",
		"Velocity",
		"Break",
		"Control",
		"Stamina",
		"",
		""
	]:
		_label(grid, heading, 18)
	for index in range(4):
		var player: PlayerDefinition = ContentDB.get_player(StringName(roster[index]))
		var name_label: Label = _label(grid, "%d. %s" % [index + 1, player.display_name], 20)
		name_label.custom_minimum_size.x = 190
		_label(grid, SeasonPlayerCard.hands(player), 18)
		for rating in SeasonPlayerCard.values(player):
			_label(grid, str(rating), 22)
		var up: Button = _button(grid, "↑", app.swap_lineup.bind(index, index - 1))
		up.custom_minimum_size = Vector2(40, 38)
		up.disabled = index == 0
		up.tooltip_text = "Move earlier in the batting order"
		var down: Button = _button(grid, "↓", app.swap_lineup.bind(index, index + 1))
		down.custom_minimum_size = Vector2(40, 38)
		down.disabled = index == 3
		down.tooltip_text = "Move later in the batting order"
	_label(_body, "OPENING DEFENSE", 22)
	for pitcher in [true, false]:
		var row: HBoxContainer = HBoxContainer.new()
		_body.add_child(row)
		var label: Label = _label(row, "Pitcher" if pitcher else "Primary Fielder", 20)
		label.custom_minimum_size.x = 175
		var choice: OptionButton = OptionButton.new()
		choice.custom_minimum_size = Vector2(360, 40)
		for id: String in roster:
			var player: PlayerDefinition = ContentDB.get_player(StringName(id))
			choice.add_item(
				player.display_name + (" • Fielding %d" % player.fielding if not pitcher else "")
			)
		choice.selected = app.season.starter_index if pitcher else app.season.fielder_index
		if not pitcher:
			choice.set_item_disabled(app.season.starter_index, true)
		choice.item_selected.connect(app.select_starter if pitcher else app.select_fielder)
		row.add_child(choice)
	_label(
		_body, "Field/Bullpen in game: change defenders between batters. Everyone still bats.", 18
	)
	for id: String in roster:
		var player: PlayerDefinition = ContentDB.get_player(StringName(id))
		_label(_body, "%s: %s" % [player.display_name, _pitches(player).replace("\n", " • ")], 18)
	_label(
		_body,
		"B / T = bats / throws. S = switch hitter. Fresh Stamina each game; vanilla equipment.",
		18
	)
	_button(_footer, "DONE", show_hub)


func show_schedule() -> void:
	_screen("schedule", "SEASON SCHEDULE", "Five home games. Five away games.")
	for round_number in range(10):
		for fixture in app.season.schedule:
			if fixture["round"] == round_number and (fixture["home"] == 0 or fixture["away"] == 0):
				var line: String = "Game %d   %s" % [round_number + 1, _matchup(fixture)]
				for result in app.season.results:
					if result["id"] == fixture["id"]:
						line += "   %d–%d" % [result["away_runs"], result["home_runs"]]
				_label(_body, line, 20)
	_button(_footer, "BACK", show_hub)


func show_postgame(score: String, season_game: bool) -> void:
	_screen("postgame", "FINAL SCORE", score)
	if season_game:
		_standings()
		_label(_body, "Around the league", 22)
		var latest_round: int = app.season.player_results.back()["round"]
		for result in app.season.results:
			if result["round"] == latest_round and result["away"] != 0 and result["home"] != 0:
				_label(
					_body,
					"%s   %d–%d" % [_matchup(result), result["away_runs"], result["home_runs"]],
					18
				)
		_button(_footer, "CONTINUE", app.show_season)
	else:
		_button(_footer, "PLAY AGAIN", app.play_exhibition)
	_button(_footer, "MAIN MENU", show_home)


func _standings() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	for heading in ["#", "CLUB", "W", "L", "RUNS", "+/−"]:
		_label(grid, heading, 16)
	var rank: int = 1
	for row in app.season.standings():
		for value in [
			str(rank),
			app.season.teams[row["team"]]["name"],
			str(row["wins"]),
			str(row["losses"]),
			"%d:%d" % [row["rf"], row["ra"]],
			str(row["rf"] - row["ra"])
		]:
			var label: Label = _label(grid, value, 20)
			if row["team"] == 0:
				label.modulate = Color(1, 0.82, 0.40)
		rank += 1


func _playoffs() -> String:
	var lines: PackedStringArray = []
	for fixture in app.season.semifinals:
		var line: String = "Semifinal: " + _matchup(fixture)
		for result in app.season.results:
			if result["id"] == fixture["id"]:
				line += "   %d–%d" % [result["away_runs"], result["home_runs"]]
		lines.append(line)
	if not app.season.final_fixture.is_empty():
		var line: String = "Neutral final: " + _matchup(app.season.final_fixture)
		for result in app.season.results:
			if result["id"] == app.season.final_fixture["id"]:
				line += "   %d–%d" % [result["away_runs"], result["home_runs"]]
		lines.append(line)
	return "\n".join(lines)


func _matchup(fixture: Dictionary) -> String:
	return (
		"%s at %s"
		% [app.season.teams[fixture["away"]]["name"], app.season.teams[fixture["home"]]["name"]]
	)


static func _label(parent: Node, text: String, font_size: int = 18) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


static func _button(parent: Node, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 46)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


static func _ratings(player: PlayerDefinition) -> String:
	return (
		"Contact %d    Power %d\nFielding %d    Velocity %d\nBreak %d    Control %d    Stamina %d"
		% [
			player.contact,
			player.power,
			player.fielding,
			player.velocity,
			player.break_rating,
			player.control,
			player.stamina
		]
	)


static func _pitches(player: PlayerDefinition) -> String:
	var names: PackedStringArray = []
	for pitch in player.starting_pitches:
		names.append(pitch.display_name)
	return "\n".join(names)


func _focus_first() -> void:
	if page == "draft" and not draft_selection.is_empty():
		(_footer.get_child(0) as Button).grab_focus()
		return
	var buttons: Array[Node] = _layout.find_children("*", "BaseButton", true, false)
	for node in buttons:
		var button: BaseButton = node as BaseButton
		if not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			return
