class_name SeasonMenu
extends PanelContainer

var app: SeasonApp
var page: String = "home"
var draft_selection: String = ""
var draft_reference: int = 0
var _layout: VBoxContainer
var _body: VBoxContainer
var _footer: HBoxContainer


func build(owner_app: SeasonApp) -> void:
	app = owner_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ClubhouseTheme.create()
	var style: StyleBoxFlat = ClubhouseTheme.surface(false, 32)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.bg_color = ClubhouseTheme.INK
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", style)
	var backdrop: ClubhouseBackdrop = ClubhouseBackdrop.new()
	add_child(backdrop)
	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 12)
	add_child(_layout)


func _screen(key: String, title: String, subtitle: String) -> void:
	page = key
	show()
	for child in _layout.get_children():
		_layout.remove_child(child)
		child.queue_free()
	var kicker: Label = _label(_layout, "WIFFALTRO   /   CLUBHOUSE", 14)
	kicker.add_theme_color_override("font_color", ClubhouseTheme.GOLD)
	_label(_layout, title, 60 if key == "home" else 36)
	var description: Label = _label(_layout, subtitle, 18)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ClubhouseTheme.section(description)
	if not app.notice.is_empty():
		var warning: Label = _label(_layout, app.notice, 16)
		warning.modulate = Color(1, 0.75, 0.45)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
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
	_label(club, "THE SEASON", 28)
	_label(club, "Four players. Ten games. One title.", 20)
	if app.season != null:
		var progress: String = SeasonPages.stage(app.season)
		_label(club, progress, 18)
		if app.season.phase != SeasonState.Phase.DRAFT:
			_label(club, SeasonPages.club_record(app.season), 18)
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
	_label(box, "Home: Yard Club Field • Away and neutral final: Commons Park", 18)
	_label(_body, "DIFFICULTY • BASE", 22)
	_label(_body, "Backyard League is the first playable league. Base difficulty is available.", 18)
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
	var reference: PlayerDefinition = _draft_comparison()
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	_body.add_child(cards)
	for id in app.season.offers():
		SeasonPlayerCard.draft_card(
			cards,
			ContentDB.get_player(StringName(id)),
			id == draft_selection,
			_select_draft.bind(id),
			reference
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
	SeasonPages.hub(self)


func show_stats() -> void:
	SeasonPages.stats(self)


func show_players() -> void:
	SeasonPages.players(self)


func show_summary() -> void:
	SeasonPages.summary(self)


func show_last_game() -> void:
	SeasonPages.postgame(self)


func show_lineup() -> void:
	_screen(
		"lineup",
		"PREGAME • LINEUP & DEFENSE",
		"Edit freely before each game. Batting order locks when the game starts."
	)
	SeasonPages.pregame(self)
	var roster: Array = app.season.teams[0]["roster"]
	var grid: GridContainer = GridContainer.new()
	grid.columns = 11
	grid.add_theme_constant_override("h_separation", 8)
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
		up.set_meta("lineup_focus", String(player.id) + ":up")
		up.custom_minimum_size = Vector2(40, 38)
		up.disabled = index == 0
		up.tooltip_text = "Move earlier in the batting order"
		var down: Button = _button(grid, "↓", app.swap_lineup.bind(index, index + 1))
		down.set_meta("lineup_focus", String(player.id) + ":down")
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
		choice.set_meta("lineup_focus", "pitcher" if pitcher else "fielder")
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
	_button(_footer, "PLAY GAME", app.play_season_game)
	_button(_footer, "SEASON HUB", show_hub)


func refresh_lineup() -> void:
	var scroll: ScrollContainer = _body.get_parent() as ScrollContainer
	var offset: int = scroll.scroll_vertical if page == "lineup" else 0
	var focused: Control = get_viewport().gui_get_focus_owner()
	var key: String = String(focused.get_meta("lineup_focus", "")) if focused != null else ""
	show_lineup()
	_restore_lineup_view.call_deferred(offset, key)


func _restore_lineup_view(offset: int, key: String) -> void:
	if page != "lineup":
		return
	for node in _body.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		if (
			not key.is_empty()
			and button.get_meta("lineup_focus", "") == key
			and not button.disabled
		):
			button.grab_focus()
	(_body.get_parent() as ScrollContainer).set_deferred("scroll_vertical", offset)


func show_schedule() -> void:
	_screen("schedule", "SEASON SCHEDULE", "Five home games. Five away games.")
	for round_number in range(10):
		for fixture in app.season.schedule:
			if fixture["round"] == round_number and (fixture["home"] == 0 or fixture["away"] == 0):
				var line: String = _matchup(fixture)
				var status: String = "UPCOMING"
				for result in app.season.results:
					if result["id"] == fixture["id"]:
						line += "   %d–%d" % [result["away_runs"], result["home_runs"]]
						status = "WIN" if SeasonState._winner(result) == 0 else "LOSS"
				var card: VBoxContainer = SeasonPlayerCard.panel(_body,
					round_number == app.season.round_index)
				var heading: Label = _label(card, "GAME %02d   /   %s" % [round_number + 1, status], 14)
				heading.add_theme_color_override("font_color", ClubhouseTheme.GOLD)
				_label(card, line, 20)
				ClubhouseTheme.section(_label(card, SeasonPages.venue(fixture), 16))
	if app.season.round_index >= 10:
		SeasonPages.wrapped(_body, _playoffs())
	_button(_footer, "BACK", show_hub)


func show_postgame(score: String, season_game: bool) -> void:
	if season_game:
		SeasonPages.postgame(self)
		return
	_screen("postgame", "FINAL SCORE", score)
	_button(_footer, "PLAY AGAIN", app.play_exhibition)
	_button(_footer, "MAIN MENU", show_home)


func _draft_comparison() -> PlayerDefinition:
	if app.season.picks.is_empty():
		_label(
			_body,
			"Build around hitting, defense or an arm. Every player fills all three roles.",
			18
		)
		return null
	draft_reference = clampi(draft_reference, 0, app.season.picks.size() - 1)
	var row: HBoxContainer = HBoxContainer.new()
	_body.add_child(row)
	_label(row, "COMPARE WITH YOUR PLAYER", 18)
	var choice: OptionButton = OptionButton.new()
	choice.custom_minimum_size = Vector2(260, 38)
	for id in app.season.picks:
		choice.add_item(ContentDB.get_player(StringName(id)).display_name)
	choice.select(draft_reference)
	choice.item_selected.connect(_compare_draft)
	row.add_child(choice)
	_label(row, "+ / − = rating difference", 18)
	var reference: PlayerDefinition = ContentDB.get_player(
		StringName(app.season.picks[draft_reference])
	)
	SeasonPages.wrapped(
		_body,
		(
			"%s • B/T %s • %s"
			% [
				reference.display_name,
				SeasonPlayerCard.hands(reference),
				_pitches(reference).replace("\n", " • ")
			]
		)
	)
	var best: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for id in app.season.picks:
		var ratings: Array[int] = SeasonPlayerCard.values(ContentDB.get_player(StringName(id)))
		for index in range(7):
			best[index] = maxi(best[index], ratings[index])
	var weakest: int = best.find(best.min())
	_label(
		_body,
		(
			"Roster coverage: strongest %s rating is %d. Compare this area as you draft."
			% [SeasonPlayerCard.RATING_NAMES[weakest], best[weakest]]
		),
		18
	)
	return reference


func _compare_draft(index: int) -> void:
	draft_reference = index
	show_draft()


func _standings() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 2)
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
				label.add_theme_color_override("font_color", ClubhouseTheme.GOLD)
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
	if parent is GridContainer:
		var index: int = parent.get_child_count() - 1
		var row: int = floori(float(index) / parent.columns)
		if row == 0:
			ClubhouseTheme.section(label)
		else:
			ClubhouseTheme.table_cell(label, row)
		if index % parent.columns > 0:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif font_size <= 16:
		ClubhouseTheme.section(label)
	return label


static func _button(parent: Node, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 46)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	if text.begins_with("CONTINUE") or text.begins_with("PREPARE") or text.begins_with("DRAFT ") \
		or text in ["START TRYOUTS", "PLAY GAME", "PLAY AGAIN", "RESUME"]:
		ClubhouseTheme.primary(button)
	elif text == "NEW SEASON" and parent is VBoxContainer and parent.get_child_count() <= 4:
		ClubhouseTheme.primary(button)
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
