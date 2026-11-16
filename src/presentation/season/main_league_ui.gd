extends RefCounted
## Main-menu league selection. Reuses existing Standard entry, not candidate Standard/Base.

const LeagueUI = preload("res://src/presentation/season/league_career_ui.gd")
const Controller = preload("res://src/presentation/season/league_career_controller.gd")
const Unlocks = preload("res://src/gameplay/season/league_unlocks.gd")


static func show(app: Node) -> void:
	if app.league_career.candidate() != null:
		app.league_career.cancel(app.league_career.token())
	var menu: SeasonMenu = app.menu
	menu._screen("main_leagues", "CHOOSE YOUR LEAGUE", "Win a title. Unlock the next challenge.")
	_standard(app)
	SeasonPages.wrapped(menu._body, (
		"Alternate leagues use your owned home field. "
		+ "Edit supported layouts before your first draft pick. "
		+ "The field then stays locked for the season."
	))
	for league: String in Controller.IDS:
		if league == "standard":
			continue
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		menu._label(card, league.capitalize(), 25)
		SeasonPages.wrapped(card, LeagueUI.description(league))
		LeagueUI._tier_controls(app, card, league)
	var dynasty: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(dynasty, "Dynasty", 25)
	SeasonPages.wrapped(dynasty, "Carry your roster from season to season.")
	SeasonPages.wrapped(dynasty, Unlocks.requirement("dynasty") if
		"dynasty" not in app.league_career.available_leagues() else
		"Unlocked. Main-career enrollment is not available in this build yet.")
	if app._dynasty_enrollment_enabled():
		var enroll: Button = menu._button(dynasty, "REVIEW DYNASTY ENROLLMENT", app._prepare_dynasty)
		enroll.disabled = "dynasty" not in app.league_career.available_leagues() \
			or app.season == null or app.season.picks.size() != 4
	menu._button(menu._footer, "BACK", menu.show_home)


static func _standard(app: Node) -> void:
	var menu: SeasonMenu = app.menu
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(card, "Standard", 25)
	SeasonPages.wrapped(card, "Your owned home field, permanent club upgrades and assigned away parks.")
	var club: ClubCareer = app.season.career if app.season != null else ClubCareer.new()
	var available: Array[int] = club.available_tiers() if club != null else ClubCareer.new().available_tiers()
	var row: HBoxContainer = HBoxContainer.new()
	card.add_child(row)
	for tier: int in range(5):
		var enabled: bool = tier in available and (tier != 4 or ClubCareer.D4_PUBLIC_ACTIVATION_ENABLED)
		var button: Button = menu._button(row, LeagueUI.tier_label(tier).to_upper() +
			("" if enabled else " • LOCKED"), app.ask_progression_season.bind(tier))
		button.set_meta("league_choice", "standard")
		button.set_meta("league_tier", tier)
		button.disabled = not enabled
		button.tooltip_text = ("\n".join(LeagueUI.pressure_lines(tier)) if enabled else
			"Win the previous Standard difficulty. Each League advances separately.")
