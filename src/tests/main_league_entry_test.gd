extends Node

const MainScene = preload("res://src/presentation/season/season_app.tscn")
const LeagueUI = preload("res://src/presentation/season/league_career_ui.gd")
var checks: int = 0
var failures: int = 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _ready() -> void:
	var root: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--main-league-test-root="):
			root = argument.trim_prefix("--main-league-test-root=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root):
		push_error("A fresh absolute isolated test root is required.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	var original: String = SeasonSave.path
	SeasonSave.path = root.path_join("season.json")
	var app: SeasonApp = MainScene.instantiate()
	add_child(app)
	check(app.get_script() == SeasonApp and app._uses_main_leagues(), "normal main retains exact SeasonApp identity")
	check(app.season == null, "fresh isolated main starts empty")
	check(_text(app.menu).contains("CHOOSE LEAGUE"), "home exposes league entry")
	app.call("_show_main_leagues")
	check(app.menu.page == "main_leagues", "normal league page opens")
	check(_field_lock_copy(app.menu), "selector explains the first-pick field lock")
	check(not _tier(app.menu, "standard", 0).disabled, "Standard starts unlocked")
	check(not _tier(app.menu, "dugout", 0).disabled, "Dugout starts unlocked")
	check(_tier(app.menu, "standard", 1).disabled, "Standard difficulty remains gated")
	check(_tier(app.menu, "sponsorship", 0).disabled, "Sponsorship remains gated")
	check(_text(app.menu).contains("owned home field"), "Standard retains owned-home route")
	check(not FileAccess.file_exists(SeasonSave.path), "navigation makes no save")
	var controller: RefCounted = app.get("league_career")
	check(controller.prepare("dugout", 77101), "normal controller prepares Dugout")
	var ticket: int = controller.token()
	LeagueUI.review(app)
	check(app.menu.page == "league_career_review", "review opens")
	check(_field_lock_copy(app.menu), "ordinary home review explains the first-pick field lock")
	LeagueUI._cancel(app, ticket)
	check(app.menu.page == "main_leagues", "cancel returns to normal selector")
	check(not FileAccess.file_exists(SeasonSave.path), "cancel preserves absent save")
	app.season = SeasonState.create(77099)
	check(app.season.career == null, "legacy fixture has no career")
	check(SeasonSave.save(app.season), "save legacy fixture")
	app.call("_show_main_leagues")
	check(not _tier(app.menu, "standard", 0).disabled, "legacy Standard Base remains available")
	check(not _tier(app.menu, "dugout", 0).disabled, "legacy Dugout Base remains available")
	check(controller.prepare("dugout", 77102), "prepare from valid legacy save")
	ticket = controller.token()
	check(controller.commit(ticket), "alternate start commits ordinary path")
	check(not controller.commit(ticket), "repeat start cannot replace season")
	check(app.season.career.runs.size() == 1, "single saved run")
	check(app.season.league_rules.league == "dugout", "captured league survives admission")
	for index: int in range(4):
		app.choose_player(app.season.offers()[0])
		check(app.season.picks.size() == index + 1, "main draft pick saves")
	check(SeasonInventoryRules.valid(app.season.inventory_rules), "four picks activate league inventory")
	check(app.season.make_match() != null, "main alternate creates match state")
	app.season = SeasonSave.restore()
	check(app.season != null and app.season.picks.size() == 4, "cold restore keeps draft")
	ClubCareerUI.show(app.menu)
	check(_text(app.menu).contains("STADIUM WORKSHOP"), "normal record keeps stadium workshop")
	check(_text(app.menu).contains("Dugout/Base"), "normal record includes league identity")
	ClubPlayersUI.show(app.menu)
	check(app.menu.page == "players", "ordinary player collection remains available")
	ClubCareerUI.show(app.menu)
	check(app.menu.page == "career", "ordinary record routing stays ordinary")
	app.ask_progression_season(0)
	check(app._dialog.dialog_text.contains("Working Standard"), "Standard uses original confirmation")
	check(app._confirmed_action.is_valid(), "Standard retains original creation path")
	app._dialog.hide()
	app.menu.show_home()
	app.call("_show_main_leagues")
	check(app.menu.page == "main_leagues", "repeated navigation remains normal")
	check(app.season.league_rules.league == "dugout", "unconfirmed Standard leaves alternate unchanged")
	app.ask_progression_season(0)
	app._confirmed_action.call()
	check(app.season.league_rules.is_empty(), "original Standard path starts after alternate")
	check(not app.season.home_property.is_empty(), "Standard retains owned home")
	check(not app.season.npc_venues.is_empty(), "Standard retains frozen away parks")
	check(app.season.career.runs.size() == 2, "Standard preserves alternate history")
	app.free()
	SeasonSave.path = original
	print("MAIN_LEAGUE_ENTRY: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _text(node: Node) -> String:
	var text: String = str(node.text) if node is Label or node is Button else ""
	for child: Node in node.get_children():
		text += "\n" + _text(child)
	return text


func _tier(node: Node, league: String, tier: int) -> Button:
	if node is Button and node.get_meta("league_choice", "") == league \
		and node.get_meta("league_tier", -1) == tier:
		return node
	for child: Node in node.get_children():
		var result: Button = _tier(child, league, tier)
		if result != null:
			return result
	return null


func _field_lock_copy(node: Node) -> bool:
	var text: String = _text(node)
	return (
		text.contains("before your first draft pick")
		and text.contains("locked for the season")
		and not text.contains("Opening Day locks")
	)
