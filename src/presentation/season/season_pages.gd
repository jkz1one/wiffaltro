class_name SeasonPages
extends RefCounted


static func club_record(season: SeasonState) -> String:
	var rows: Array[Dictionary] = season.standings()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		if row["team"] == 0:
			return "%d–%d • %d of 6 in the league" % [row["wins"], row["losses"], index + 1]
	return ""


static func stage(season: SeasonState) -> String:
	match season.phase:
		SeasonState.Phase.DRAFT:
			return "Tryout %d of 4" % (season.picks.size() + 1)
		SeasonState.Phase.REGULAR:
			return "Game %d of 10" % (season.round_index + 1)
		SeasonState.Phase.SEMIFINAL:
			return "Semifinal • Win to reach the championship"
		SeasonState.Phase.FINAL:
			return "Championship • One game for the title"
	return ending(season)


static func ending(season: SeasonState) -> String:
	if season.champion == 0:
		return "BACKYARD LEAGUE CHAMPIONS"
	if not season.playoff_seeds.has(0):
		return "MISSED THE PLAYOFFS"
	if season.final_fixture.get("home", -1) == 0 or season.final_fixture.get("away", -1) == 0:
		return "CHAMPIONSHIP RUNNER-UP"
	return "ELIMINATED IN THE SEMIFINAL"


static func hub(menu: SeasonMenu) -> void:
	var season: SeasonState = menu.app.season
	if season.phase == SeasonState.Phase.COMPLETE:
		summary(menu)
		return
	menu._screen("hub", "YARD CLUB", stage(season) + " • Backyard League")
	menu._label(menu._body, club_record(season), 24)
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body, true)
	menu._label(card, "NEXT UP  •  " + menu._matchup(season.pending_fixture()), 26)
	menu._label(card, venue(season.pending_fixture()), 18)
	menu._label(card, defense(season), 18)
	if season.phase == SeasonState.Phase.REGULAR:
		menu._label(
			card, "Top 4 qualify • %d regular games remaining" % (10 - season.round_index), 18
		)
	if not season.player_results.is_empty():
		menu._label(
			menu._body, "LAST GAME  •  " + result_label(menu, season.player_results.back()), 20
		)
	menu._standings()
	menu._label(
		menu._body, "Standings: regular games only. Ties use run difference, runs, then draw.", 16
	)
	menu._button(menu._footer, "PREPARE NEXT GAME", menu.show_lineup)
	menu._button(menu._footer, "PLAYER RATINGS", menu.show_players)
	menu._button(menu._footer, "TEAM STATS", menu.show_stats)
	if not season.player_results.is_empty():
		menu._button(menu._footer, "LAST GAME", menu.show_last_game)
	menu._button(menu._footer, "SCHEDULE", menu.show_schedule)
	menu._button(menu._footer, "MAIN MENU", menu.show_home)


static func venue(fixture: Dictionary) -> String:
	var field_name: String = SeasonState.field_for_fixture(fixture).display_name
	var opening: String = "You pitch first" if fixture["home"] == 0 else "You bat first"
	if fixture.get("neutral", false):
		return "Neutral final • %s • %s" % [field_name, opening]
	return ("Home • %s • You pitch first" if fixture["home"] == 0 else (
		"Away • %s • You bat first")) % field_name


static func defense(season: SeasonState) -> String:
	var roster: Array = season.teams[0]["roster"]
	return (
		"Starting Pitcher: %s  •  Primary Fielder: %s"
		% [
			ContentDB.get_player(StringName(roster[season.starter_index])).display_name,
			ContentDB.get_player(StringName(roster[season.fielder_index])).display_name
		]
	)


static func pregame(menu: SeasonMenu) -> void:
	var season: SeasonState = menu.app.season
	var fixture: Dictionary = season.pending_fixture()
	if fixture.is_empty():
		return
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body, true)
	menu._label(card, menu._matchup(fixture), 24)
	menu._label(card, venue(fixture) + " • Fresh Stamina • 5 innings", 18)
	var opponent: int = fixture["away"] if fixture["home"] == 0 else fixture["home"]
	var starter: PlayerDefinition = ContentDB.get_player(
		StringName(season.teams[opponent]["roster"][0])
	)
	menu._label(
		card,
		(
			"Opposing starter: %s • Throws %s • %s"
			% [
				starter.display_name,
				"L" if starter.throws == 1 else "R",
				SeasonPlayerCard.STYLE_NAMES[starter.pitching_style]
			]
		),
		20
	)
	wrapped(card, "Arsenal: " + menu._pitches(starter).replace("\n", " • "))


static func postgame(menu: SeasonMenu) -> void:
	var season: SeasonState = menu.app.season
	var game: Dictionary = season.player_results.back()
	menu._screen(
		"postgame", "WIN" if SeasonState._winner(game) == 0 else "LOSS", result_label(menu, game)
	)
	menu._label(menu._body, movement(season, game), 22)
	var recorded: Dictionary = game.get("performance", {})
	var highlights: Array[String] = SeasonPerformance.highlights(
		recorded, season.teams[0]["roster"]
	)
	for line in highlights:
		wrapped(menu._body, line)
	if recorded.is_empty():
		menu._label(menu._body, "Player statistics were not recorded for this older game.", 18)
	else:
		stat_tables(menu, recorded)
	var next: Dictionary = season.pending_fixture()
	if not next.is_empty():
		menu._label(menu._body, "NEXT  •  " + menu._matchup(next) + " • " + stage(season), 20)
	else:
		menu._label(menu._body, ending(season), 24)
	menu._label(menu._body, "AROUND THE LEAGUE", 22)
	for other in season.results:
		if other["round"] == game["round"] and other["home"] != 0 and other["away"] != 0:
			menu._label(menu._body, result_label(menu, other), 18)
	menu._standings()
	menu._button(
		menu._footer,
		"PREPARE NEXT GAME" if not next.is_empty() else "SEASON RECAP",
		menu.show_lineup if not next.is_empty() else menu.show_summary
	)
	menu._button(menu._footer, "SEASON HUB", menu.show_hub)
	menu._button(menu._footer, "MAIN MENU", menu.show_home)


static func movement(season: SeasonState, game: Dictionary) -> String:
	if game["id"] >= 30:
		return ending(season) if season.phase == SeasonState.Phase.COMPLETE else stage(season)
	# Rank from the prior completed round, with the same tiebreak rule.
	var prior: SeasonState = SeasonState.new()
	prior.teams = season.teams
	for result in season.results:
		if result["round"] < game["round"]:
			prior.results.append(result)
	var before: int = 0
	var after: int = 0
	var old_rows: Array[Dictionary] = prior.standings()
	var new_rows: Array[Dictionary] = season.standings()
	for index in range(6):
		if old_rows[index]["team"] == 0:
			before = index + 1
		if new_rows[index]["team"] == 0:
			after = index + 1
	if game["round"] == 0:
		return "First league result • " + club_record(season)
	return "League position %d → %d • %s" % [before, after, club_record(season)]


static func stats(menu: SeasonMenu) -> void:
	var season: SeasonState = menu.app.season
	menu._screen("stats", "YARD CLUB STATS", SeasonPerformance.coverage(season))
	menu._label(menu._body, "Totals from your completed games. Unfinished games do not count.", 18)
	if season.player_results.any(
		func(game: Dictionary) -> bool: return not game.has("performance")
	):
		wrapped(menu._body, "Older games retain their scores but have no player statistics.")
	stat_tables(menu, SeasonPerformance.totals(season))
	menu._button(menu._footer, "PLAYER RATINGS", menu.show_players)
	menu._button(menu._footer, "BACK", menu.show_hub)


static func players(menu: SeasonMenu) -> void:
	var season: SeasonState = menu.app.season
	menu._screen("players", "PLAYER RATINGS", "Yard Club • Current attributes and repertoires")
	menu._label(menu._body,
		"Ratings are 0–10. Higher is stronger. Season results are in Team Stats.", 18)
	for index in range(season.teams[0]["roster"].size()):
		var player: PlayerDefinition = ContentDB.get_player(
			StringName(season.teams[0]["roster"][index]))
		var role: String = ""
		if index == season.starter_index:
			role = " • Starting Pitcher"
		elif index == season.fielder_index:
			role = " • Primary Fielder"
		SeasonPlayerCard.ratings_card(menu._body, player, player.display_name + role)
	menu._button(menu._footer, "TEAM STATS", menu.show_stats)
	menu._button(menu._footer, "BACK TO SEASON", menu.show_hub)


static func stat_tables(menu: SeasonMenu, stats_data: Dictionary) -> void:
	for pitching in [false, true]:
		menu._label(menu._body, "PITCHING" if pitching else "BATTING", 22)
		var keys: Array = (
			["outs", "p_h", "p_bb", "p_k", "pitches"]
			if pitching
			else ["pa", "h", "double", "triple", "hr", "bb", "k", "rbi"]
		)
		var headings: Array = (
			["OUTS", "H", "BB", "K", "PITCHES"]
			if pitching
			else ["PA", "H", "2B", "3B", "HR", "BB", "K", "RBI"]
		)
		var grid: GridContainer = GridContainer.new()
		grid.columns = keys.size() + 1
		grid.add_theme_constant_override("h_separation", 0)
		grid.add_theme_constant_override("v_separation", 2)
		menu._body.add_child(grid)
		menu._label(grid, "PLAYER", 16)
		for heading: String in headings:
			menu._label(grid, heading, 16)
		for id: String in menu.app.season.teams[0]["roster"]:
			menu._label(grid, ContentDB.get_player(StringName(id)).display_name, 20)
			for key: String in keys:
				menu._label(grid, str(stats_data[id][key]) if stats_data.has(id) else "—", 20)
	wrapped(
		menu._body,
		"PA: plate appearances • H: hits • BB: walks • K: strikeouts • RBI: runs batted in"
	)
	wrapped(
		menu._body, "Pitching H / BB are allowed. OUTS counts recorded outs, including strikeouts."
	)


static func summary(menu: SeasonMenu) -> void:
	var season: SeasonState = menu.app.season
	menu._screen("summary", ending(season), "Yard Club • " + club_record(season))
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body, season.champion == 0)
	menu._label(card, "%s win the title" % season.teams[season.champion]["name"], 28)
	menu._label(
		card,
		"%d games played • %s" % [season.player_results.size(), SeasonPerformance.coverage(season)],
		18
	)
	for line in SeasonPerformance.highlights(
		SeasonPerformance.totals(season), season.teams[0]["roster"]
	):
		wrapped(card, line)
	wrapped(menu._body, menu._playoffs())
	menu._label(menu._body, "FINAL REGULAR-SEASON STANDINGS", 22)
	menu._standings()
	menu._label(menu._body, "This season stays available until you confirm a new season.", 18)
	menu._button(menu._footer, "NEW SEASON", menu.app.ask_new_season)
	menu._button(menu._footer, "PLAYER RATINGS", menu.show_players)
	menu._button(menu._footer, "TEAM STATS", menu.show_stats)
	menu._button(menu._footer, "LAST GAME", menu.show_last_game)
	menu._button(menu._footer, "SCHEDULE", menu.show_schedule)
	menu._button(menu._footer, "MAIN MENU", menu.show_home)


static func result_label(menu: SeasonMenu, game: Dictionary) -> String:
	return (
		"%s %d  •  %s %d"
		% [
			menu.app.season.teams[game["away"]]["name"],
			game["away_runs"],
			menu.app.season.teams[game["home"]]["name"],
			game["home_runs"]
		]
	)


static func wrapped(parent: Node, text: String) -> Label:
	var label: Label = SeasonPlayerCard.line(parent, text, 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
