extends RefCounted
## Presentation for the separate, explicitly isolated career candidate scene.

const Catalog = preload("res://src/presentation/season/league_catalog_ui.gd")
const Controller = preload("res://src/presentation/season/league_career_controller.gd")
const Unlocks = preload("res://src/gameplay/season/league_unlocks.gd")


static func description(league: String) -> String:
	if league == "standard":
		return "Two held-item slots, five sponsor slots and ordinary win/loss game income."
	return Catalog.description(league)


static func tier_label(tier: int) -> String:
	return "Base" if tier == 0 else "d%d" % tier


static func pressure_lines(tier: int) -> Array[String]:
	var result: Array[String] = ["Base: this League's captured rules and ordinary game pressure."]
	if tier >= 1:
		result.append("d1: paid rerolls cost +1 Cash. Free rerolls stay free.")
	if tier >= 2:
		result.append("d2: AI clubs compare two draft candidates using their assigned role stats.")
	if tier >= 3:
		result.append("d3: marked nonrefundable sponsors return 0 Cash on cancellation or replacement.")
	if tier >= 4:
		result.append(
			"d4: a separate marked short-term sponsor class expires after two completed club games "
			+ "for 0 Cash. Early cancellation returns half the Cash actually paid. "
			+ "d3 nonrefundable copies remain nonrefundable."
		)
	return result


static func reward_summary(tier: int) -> String:
	var payouts: Array[String] = [
		"35 / 65 / 95 / 180", "36 / 68 / 99 / 189", "38 / 71 / 104 / 198",
		"40 / 74 / 109 / 207", "42 / 78 / 114 / 216"
	]
	return (
		"Working %s finish rewards: %s Club Bucks for missed playoffs / semifinal / "
		% [tier_label(tier), payouts[tier]]
		+ "runner-up / champion. Add up to 15 for your regular record and 25 once for the first "
		+ "title at this League and tier. Repeat titles still earn ordinary rewards. "
		+ "Season Cash does not convert to Club Bucks."
	)


static func unlock_summary() -> String:
	return (
		"Standard and Dugout start unlocked. Win Standard to unlock Sponsorship, then win "
		+ "Sponsorship for Academy. Win Dugout for Equipment, then Equipment for Earnings. "
		+ "A tier 1 title in any League unlocks Doubleheader; tier 2 unlocks Scramble; "
		+ "tier 3 unlocks Dynasty. Every newly unlocked League begins at Base."
	)


static func show(app: Node) -> void:
	if app.has_method("_uses_main_leagues") and app._uses_main_leagues():
		app.call("_show_main_leagues")
		return
	if app.league_career.candidate() != null:
		app.league_career.cancel(app.league_career.token())
	var menu: SeasonMenu = app.menu
	menu._screen("league_career", "CHOOSE YOUR LEAGUE", "Career playtest • League-specific difficulty")
	SeasonPages.wrapped(menu._body, (
		"This isolated candidate uses the approved League unlock tree. "
		+ "Club Bucks, earned access and history stay with this candidate club. "
		+ "Each fresh season freezes your permanently owned players as its draft and recruit pool. "
		+ "New clubs start with 12 players; purchases join the next fresh season, not a paused pool. "
		+ "NPC clubs still use the full authored catalog. Cash and items reset."
	))
	SeasonPages.wrapped(menu._body, unlock_summary())
	SeasonPages.wrapped(menu._body, (
		"Current candidate uses starter fields. After unlocking Dynasty and drafting, the menu offers "
		+ "Dynasty enrollment into a shared owner route with same-League title-gated tiers. "
		+ "Rule values are adjustable playtest values."
	))
	SeasonPages.wrapped(menu._body, (
		"Each League starts at Base. A championship unlocks the next difficulty only in that "
		+ "League; earlier difficulties remain replayable. Higher tiers include every earlier pressure."
	))
	for league: String in Controller.IDS:
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		menu._label(card, league.capitalize(), 25)
		SeasonPages.wrapped(card, description(league))
		_tier_controls(app, card, league)
	_dynasty_card(app)
	menu._button(menu._footer, "BACK", menu.show_home)


static func _tier_controls(app: Node, card: Node, league: String) -> void:
	var menu: SeasonMenu = app.menu
	var available: Array[int] = app.league_career.available_tiers(league)
	var league_open: bool = league in app.league_career.available_leagues()
	if not league_open:
		SeasonPages.wrapped(card, "LEAGUE LOCKED • " + Unlocks.requirement(league))
	var tiers: HFlowContainer = HFlowContainer.new()
	tiers.add_theme_constant_override("h_separation", 12)
	tiers.add_theme_constant_override("v_separation", 8)
	card.add_child(tiers)
	for tier: int in range(1 if league == "standard" else 5):
		var unlocked: bool = league_open and tier in available
		var cleared: bool = (
			app.season != null and app.season.career != null
			and app.season.career.cleared(tier, league)
		)
		var label: String = (
			("REPLAY " if cleared else "REVIEW ") + tier_label(tier).to_upper()
			if unlocked else tier_label(tier).to_upper() + " • LOCKED"
		)
		var button: Button = menu._button(tiers, label, _prepare.bind(app, league, tier))
		button.set_meta("league_choice", league)
		button.set_meta("league_tier", tier)
		button.disabled = not unlocked
		button.tooltip_text = "\n".join(pressure_lines(tier))
		if not unlocked:
			button.tooltip_text = (
				(Unlocks.requirement(league) + "\n" if not league_open else
				("Recover the saved club before starting a new season.\n" if tier == 0 else
				"Win %s / %s to unlock this difficulty.\n" % [league.capitalize(), tier_label(tier - 1)])
				)
				+ button.tooltip_text
			)
	if league == "standard":
		SeasonPages.wrapped(card, (
			"Standard is Base-only in this isolated selector. Its existing higher-tier entry "
			+ "uses the full owned-home and venue setup, which is not integrated here."
		))
	else:
		var labels: PackedStringArray = []
		for tier: int in available:
			labels.append(tier_label(tier))
		SeasonPages.wrapped(card, "Available: " + ", ".join(labels))
		if league_open and available.size() < 5:
			SeasonPages.wrapped(card, (
				"Locked tiers require a championship at the previous tier in " + league.capitalize()
				+ ". Other Leagues' titles do not count."
			))


static func _dynasty_card(app: Node) -> void:
	var menu: SeasonMenu = app.menu
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	var unlocked: bool = "dynasty" in app.league_career.available_leagues()
	menu._label(card, "Dynasty", 25)
	SeasonPages.wrapped(card, "Carry your roster across seasons, including losses and abandonment.")
	SeasonPages.wrapped(card, "Unlock earned. Enrollment begins at Base with your current roster."
		if unlocked else "LEAGUE LOCKED • " + Unlocks.requirement("dynasty"))
	var button: Button = menu._button(card, "REVIEW DYNASTY ENROLLMENT" if unlocked else
		"DYNASTY • LOCKED", _enroll_dynasty.bind(app))
	button.set_meta("league_choice", "dynasty")
	button.set_meta("league_tier", 0)
	button.disabled = not unlocked or app.season == null or app.season.picks.size() != 4
	button.tooltip_text = "Finish a four-player draft before reviewing enrollment." if unlocked \
		else Unlocks.requirement("dynasty")


static func _enroll_dynasty(app: Node) -> void:
	if app.has_method("_prepare_dynasty"):
		app._prepare_dynasty()


static func _prepare(app: Node, league: String, tier: int = 0) -> void:
	var seed_value: int = int(Time.get_unix_time_from_system()) & 0x7fffffff
	if not app.league_career.prepare(league, seed_value, tier):
		show(app)
		return
	review(app)


static func review(app: Node) -> void:
	var next: SeasonState = app.league_career.candidate()
	if next == null:
		show(app)
		return
	var ticket: int = app.league_career.token()
	var league: String = str(next.league_rules.get("league", "standard"))
	var tier: int = next.career.active_tier()
	var menu: SeasonMenu = app.menu
	menu._screen(
		"league_career_review", league.to_upper() + " / " + tier_label(tier).to_upper(),
		"Review before starting • All active pressures"
	)
	SeasonPages.wrapped(menu._body, description(league))
	for line: String in pressure_lines(tier):
		SeasonPages.wrapped(menu._body, line)
	SeasonPages.wrapped(menu._body, (
		"Draft four players for ten regular-season games and the playoffs. "
		+ "The captured League rules stay fixed through save and reload."
	))
	if next._league_home_context.get("format") in [93, 94]:
		SeasonPages.wrapped(menu._body, (
			"This season uses your current paid home field. "
			+ "Supported field edits are allowed before your first draft pick, "
			+ "then locked for the season."
		))
	var time_adapter = load("res://src/gameplay/season/normal_league_time_candidate.gd")
	if next._league_home_context.get("format") == 94:
		SeasonPages.wrapped(menu._body, "HOME STARTING TIME • "
			+ str(next._league_home_context.header.starting_profile).replace("_", " ").capitalize()
			+ ". The selected paid lighting policy stays fixed for this season.")
	if time_adapter.ENTRY_ENABLED and next._league_home_context.get("format") in [93, 94] \
		and time_adapter.supported_home(next.home_property):
		var times: HBoxContainer = HBoxContainer.new()
		menu._body.add_child(times)
		for profile: String in ["day", "sunset", "night"]:
			var button: Button = menu._button(times, profile.to_upper(), _time_profile.bind(app, ticket, profile))
			button.set_meta("league_starting_profile", profile)
	if app.season != null and app.season.phase != SeasonState.Phase.COMPLETE:
		SeasonPages.wrapped(menu._body, (
			"Starting abandons the unfinished season with no Club Bucks payout. "
			+ "Existing club rewards and history remain. Cancel keeps your current season."
		))
	else:
		SeasonPages.wrapped(
			menu._body, "Earned club rewards and history remain. No save changes until Start."
		)
	menu._label(menu._body, "CLUB BUCKS CARRIED FORWARD  •  %d" % next.career.balance(), 24)
	SeasonPages.wrapped(menu._body, "%d PERMANENTLY OWNED PLAYERS • Frozen draft and recruit pool. "
		% next.player_access.size() + "Purchases during this season first enter the next fresh season.")
	SeasonPages.wrapped(menu._body, reward_summary(tier))
	menu._button(menu._footer, "START & SAVE SEASON", _commit.bind(app, ticket))
	menu._button(menu._footer, "CANCEL", _cancel.bind(app, ticket))


static func _time_profile(app: Node, ticket: int, profile: String) -> void:
	if app.league_career.starting_profile(ticket, profile):
		review(app)


static func _commit(app: Node, ticket: int) -> void:
	if not app.league_career.commit(ticket):
		review(app)


static func _cancel(app: Node, ticket: int) -> void:
	if app.league_career.cancel(ticket):
		show(app)


static func record(app: Node, page: int = 0) -> void:
	var menu: SeasonMenu = app.menu
	var club: ClubCareer = app.season.career
	var last_page: int = maxi(0, int((club.runs.size() - 1) / 20.0))
	page = clampi(page, 0, last_page)
	menu._screen(
		"career", "CLUB RECORD", "Shared candidate career • League identity stays with each season"
	)
	menu._label(menu._body, "CLUB BUCKS  •  %d" % club.balance(), 28)
	SeasonPages.wrapped(menu._body, (
		"League access follows the approved unlock tree. Difficulty clears are recorded for their "
		+ "own League. Win the previous tier's championship to open the next; lower tiers remain "
		+ "replayable. Standard stays Base-only here. Dynasty needs explicit main-menu enrollment."
	))
	menu._button(menu._body, "CHOOSE NEXT LEAGUE", show.bind(app))
	if not app.season.player_access.is_empty():
		menu._button(menu._body, "PLAYERS & PACKS", ClubPlayersUI.show.bind(menu, "All", 0))
		SeasonPages.wrapped(menu._body,
			"This season's owned draft and recruit pool stays frozen. Purchases join the next season.")
	else:
		SeasonPages.wrapped(menu._body,
			"This older saved season retains its full player pool unchanged. The next fresh candidate "
			+ "season uses permanent ownership and enables player packs. No current roster is removed.")
	menu._button(menu._body, "COLLECTION", ClubCollectionUI.show.bind(menu, "Gear", 0))
	menu._button(menu._body, "GEAR PROGRESSION", ClubGearProgressUI.show.bind(menu))
	menu._button(menu._body, "LEARNED ABILITIES", SeasonAbilityUI.show.bind(menu))
	menu._button(menu._body, "EARNED SPONSORS", ClubSponsorProgressUI.show.bind(menu))
	menu._label(menu._body, "SEASONS • Page %d of %d" % [page + 1, last_page + 1], 22)
	var end: int = maxi(0, club.runs.size() - page * 20)
	for index: int in range(end - 1, maxi(-1, end - 21), -1):
		var run: Dictionary = club.runs[index]
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		SeasonPages.wrapped(card, "Season #%d • %s • %s • +%d CB" % [
			run.id, ClubCareerUI.tier_label(int(run.tier), str(run.league)),
			str(run.receipt.get("finish", run.status)).replace("_", " ").capitalize(),
			run.receipt.get("total", 0)
		])
		menu._button(card, "VIEW SEASON #%d" % run.id, ClubCareerUI.detail.bind(menu, index, page))
	if page > 0:
		menu._button(menu._footer, "NEWER", record.bind(app, page - 1))
	if page < last_page:
		menu._button(menu._footer, "OLDER", record.bind(app, page + 1))
	menu._button(menu._footer, "CURRENT SEASON", app.show_season)
	menu._button(menu._footer, "MAIN MENU", menu.show_home)
