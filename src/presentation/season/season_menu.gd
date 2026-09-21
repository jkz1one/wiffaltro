class_name SeasonMenu
extends PanelContainer

var app: SeasonApp
var page: String = "home"
var _layout: VBoxContainer
var _body: VBoxContainer
var _footer: HBoxContainer


func build(owner_app: SeasonApp) -> void:
	app = owner_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.085)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	add_theme_stylebox_override("panel", style)
	add_theme_font_size_override("font_size", 18)
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


func show_home() -> void:
	_screen("home", "WIFFALTRO", "Small teams. Big swings.")
	_label(_body, "Play a season or jump into a game.", 24)
	if app.season != null:
		_button(
			_body,
			(
				"SEASON RESULTS"
				if app.season.phase == SeasonState.Phase.COMPLETE
				else "CONTINUE SEASON"
			),
			app.show_season
		)
	_button(_body, "NEW SEASON", app.ask_new_season)
	_button(_body, "EXHIBITION", app.play_exhibition)
	_label(
		_body,
		"Mouse: aim • Left click: contact / pitch • Right click: power\nEsc: pause and settings",
		16
	)
	_button(_footer, "QUIT", get_tree().quit)


func show_preseason() -> void:
	_screen("preseason", "START A SEASON", "Backyard League • Standard")
	_label(_body, "Build your four-player club", 26)
	_label(
		_body,
		(
			"Four rounds. Three players each round. Pick one.\n"
			+ "Everyone can bat, pitch and field. Set your order and opening defense before each game."
		)
	)
	_label(_body, "Six clubs • Ten games • Top four reach the playoffs", 24)
	_label(
		_body,
		(
			"Play each rival home and away. Semifinals are hosted by the higher seed.\n"
			+ "The championship is at a neutral venue. This first season uses the starter field throughout."
		)
	)
	_label(
		_body,
		(
			"Progress saves after draft picks and completed games.\n"
			+ "An unfinished game restarts from its beginning when you return."
		),
		16
	)
	_button(_footer, "START TRYOUTS", app.begin_season)
	_button(_footer, "BACK", show_home)


func show_draft() -> void:
	_screen(
		"draft",
		"TRYOUT %d OF 4" % (app.season.picks.size() + 1),
		"Choose one player for Yard Club."
	)
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	_body.add_child(cards)
	for id in app.season.offers():
		var player: PlayerDefinition = ContentDB.get_player(StringName(id))
		var panel: PanelContainer = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(320, 360)
		cards.add_child(panel)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 18)
		panel.add_child(box)
		_label(box, player.display_name, 26)
		_label(
			box,
			(
				"Bats %s • Throws %s"
				% ["L" if player.bats == 1 else "R", "L" if player.throws == 1 else "R"]
			),
			16
		)
		_label(box, _ratings(player), 18)
		_label(box, _pitches(player), 16)
		_button(box, "DRAFT", app.choose_player.bind(id))
	var names: PackedStringArray = []
	for id in app.season.picks:
		names.append(ContentDB.get_player(StringName(id)).display_name)
	_label(_body, "Your club: " + (", ".join(names) if not names.is_empty() else "First pick"), 16)
	_button(_footer, "MAIN MENU", show_home)


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
		"YOUR LINEUP",
		"Batting order is fixed for the game. Pitchers start each game fresh."
	)
	var roster: Array = app.season.teams[0]["roster"]
	for index in range(4):
		var player: PlayerDefinition = ContentDB.get_player(StringName(roster[index]))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_body.add_child(row)
		var label: Label = _label(row, "%d. %s" % [index + 1, player.display_name], 22)
		label.custom_minimum_size.x = 220
		label.tooltip_text = _ratings(player) + "\n" + _pitches(player)
		var up: Button = _button(row, "UP", app.swap_lineup.bind(index, index - 1))
		up.disabled = index == 0
		var down: Button = _button(row, "DOWN", app.swap_lineup.bind(index, index + 1))
		down.disabled = index == 3
	for pitcher in [true, false]:
		var row: HBoxContainer = HBoxContainer.new()
		_body.add_child(row)
		_label(row, "Starting pitcher  " if pitcher else "Primary fielder  ")
		var choice: OptionButton = OptionButton.new()
		choice.custom_minimum_size = Vector2(300, 42)
		for id: String in roster:
			choice.add_item(ContentDB.get_player(StringName(id)).display_name)
		choice.selected = app.season.starter_index if pitcher else app.season.fielder_index
		if not pitcher:
			choice.set_item_disabled(app.season.starter_index, true)
		choice.item_selected.connect(app.select_starter if pitcher else app.select_fielder)
		row.add_child(choice)
	_label(
		_body,
		(
			"Standard bat and fresh ball • Starting pitches stay with each player.\n"
			+ "Hover a player for ratings and repertoire."
		),
		16
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
