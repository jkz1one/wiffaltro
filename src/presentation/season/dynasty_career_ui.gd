extends RefCounted
## Owner-wide presentation. A raw owner session deliberately has no per-season ClubCareer.

const LeagueUI = preload("res://src/presentation/season/league_career_ui.gd")
const LeagueController = preload("res://src/presentation/season/league_career_controller.gd")


static func enrollment(app: Node) -> void:
	var setup: RefCounted = app.dynasty_enrollment
	var menu: SeasonMenu = app.menu
	if not setup.pending():
		menu.show_home()
		return
	menu._screen("dynasty_enrollment", "START DYNASTY / BASE", "Review this carried roster")
	var profile: Dictionary = setup.preview()
	var names: PackedStringArray = []
	for id: String in profile.get("roster", []):
		names.append(ContentDB.get_player(StringName(id)).display_name)
	SeasonPages.wrapped(menu._body, "ROSTER: " + ", ".join(names))
	SeasonPages.wrapped(menu._body, (
		"This closes the current season and imports its club history and earned balance. "
		+ "An unfinished source is abandoned for 0 Club Bucks; a completed source keeps its payout. "
		+ "The exact original is archived, not kept as a second playable season."
	))
	SeasonPages.wrapped(menu._body, (
		"Your current roster and supported development carry into Dynasty. Seasonal Cash and items "
		+ "reset. Later Dynasty seasons use the existing decay and ability-forgetting choices. "
		+ "No new player-replacement or AI carryover rules are introduced."
	))
	if profile.has("pitch_catalog"):
		SeasonPages.wrapped(menu._body, "Current-pitch Dynasty starts at Base and retains this catalog and earned pitch history. "
			+ "This version supports Dynasty seasons and roster carry only. Alternate leagues, owned homes and shared asset purchases are not yet supported.")
	else:
		SeasonPages.wrapped(menu._body, (
			"Enrollment starts Dynasty at Base. Later seasons and the seven alternate Leagues use "
			+ "same-League championship gates for Base through d4. Standard keeps its owned home and saved away venues. "
			+ "Switching to an alternate pauses Dynasty and keeps its exact roster and season."
		))
		load("res://src/presentation/season/dynasty_shared_time_ui.gd").enrollment(app)
	if setup.attempted():
		SeasonPages.wrapped(menu._body, (
			"The start was attempted. Retry this same roster or recover the save. "
			+ "Do not start a replacement or return to the archived source."
		))
	menu._button(menu._footer, "RETRY DYNASTY START" if setup.attempted()
		else "START DYNASTY & ARCHIVE SOURCE", _commit_enrollment.bind(app, setup.token()))
	if not setup.attempted():
		menu._button(menu._footer, "CANCEL", _cancel_enrollment.bind(app, setup.token()))
	else:
		menu._button(menu._footer, "RECOVER SAVE", app.dynasty_owner._recover)


static func _commit_enrollment(app: Node, ticket: int) -> void:
	if not app.dynasty_enrollment.commit(ticket):
		enrollment(app)


static func _cancel_enrollment(app: Node, ticket: int) -> void:
	if app.dynasty_enrollment.cancel(ticket):
		app.menu.show_home()


static func show(app: Node) -> void:
	var menu: SeasonMenu = app.menu
	menu._screen("dynasty_career_leagues", "SHARED CAREER LEAGUES", "League-specific difficulty")
	SeasonPages.wrapped(menu._body, (
		"Dynasty and its alternate share club income, history and earned access. "
		+ "Switching pauses the current session; it does not abandon or reseed it. "
		+ "Higher tiers require the previous tier's title in that same League; lower tiers replay. "
		+ "The approved League unlock tree gates new starts, not your existing saved sessions."
	))
	SeasonPages.wrapped(menu._body, LeagueUI.unlock_summary())
	if not app.dynasty_owner.ready():
		menu._button(menu._body, "RECOVER SHARED CAREER", app.dynasty_owner._recover)
		menu._button(menu._footer, "BACK", menu.show_home)
		return
	var current: Dictionary = app.dynasty_owner.found()
	var owner: Dictionary = current.owner
	var dynasty: VBoxContainer = SeasonPlayerCard.panel(menu._body, true)
	menu._label(dynasty, "Dynasty / " + LeagueUI.tier_label(int(owner.dynasty.profile.tier)), 25)
	SeasonPages.wrapped(dynasty, "Keep your roster across seasons, wins, losses and abandonment.")
	if not owner.pending_next.is_empty():
		SeasonPages.wrapped(dynasty, "Saved next season: Dynasty / %s. Resume its ability choice; "
			% LeagueUI.tier_label(int(owner.get("pending_tier", 0)))
			+ "the selected difficulty cannot be changed or rerolled.")
	menu._button(dynasty, "RETURN TO DYNASTY" if owner.selected != "dynasty" else
		("NEXT DYNASTY SEASON" if owner.lineage.state == "closed" else "CURRENT DYNASTY"),
		app.dynasty_owner.ask_switch.bind("dynasty") if owner.selected != "dynasty" else
		(app.dynasty_owner.ask_next if owner.lineage.state == "closed" else app.show_season))
	if owner.get("version") == 3:
		SeasonPages.wrapped(menu._body, "Current-pitch Dynasty retains its exact roster, paid learning and shared history. "
			+ "Alternate leagues, owned-home play and shared asset purchases are not supported by this version.")
		menu._button(menu._footer, "CLUB RECORD", record.bind(app, 0))
		menu._button(menu._footer, "BACK", menu.show_home)
		return
	var alternate: Dictionary = owner.other
	var active: bool = not alternate.is_empty() and (
		owner.career.sessions[alternate.session_id].settled == 0
	)
	for league: String in LeagueController.IDS:
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		menu._label(card, league.capitalize(), 24)
		SeasonPages.wrapped(card, LeagueUI.description(league))
		if league not in app.dynasty_owner.available_leagues():
			SeasonPages.wrapped(card, "NEW START LOCKED • " + LeagueUI.Unlocks.requirement(league))
		if active:
			if alternate.profile.league == league:
				SeasonPages.wrapped(card, "Saved difficulty: "
					+ LeagueUI.tier_label(int(alternate.profile.tier)) + ". Resume keeps it unchanged.")
				menu._button(card, "RESUME SAVED ALTERNATE", app.show_season if owner.selected == "other"
					else app.dynasty_owner.ask_switch.bind("other"))
			else:
				SeasonPages.wrapped(card, "Resume or close your " + str(alternate.profile.league).capitalize()
					+ " alternate before choosing a replacement.")
		elif owner.selected != "dynasty":
			SeasonPages.wrapped(card, "Return to Dynasty before starting a new alternate.")
		else:
			_alternate_tiers(app, card, league, current.revision)
	menu._button(menu._footer, "SHARED CLUB RECORD", record.bind(app, 0))
	menu._button(menu._footer, "BACK", menu.show_home)


static func _alternate_tiers(app: Node, card: Node, league: String, revision: int) -> void:
	var unlocked: bool = league in app.dynasty_owner.available_leagues()
	var available: Array[int] = []
	if unlocked:
		available = app.dynasty_owner.available_tiers(league)
	for tier: int in range(5):
		var button: Button = app.menu._button(card,
			"REVIEW " + LeagueUI.tier_label(tier).to_upper() if tier in available
			else LeagueUI.tier_label(tier).to_upper() + " • LOCKED",
			_ask_other.bind(app, league, revision, tier))
		button.set_meta("owner_league", league)
		button.set_meta("owner_league_tier", tier)
		button.disabled = tier not in available
		button.tooltip_text = "\n".join(LeagueUI.pressure_lines(tier))
		if button.disabled:
			button.tooltip_text = ("Win %s / %s first.\n"
				% [league.capitalize(), LeagueUI.tier_label(tier - 1)] if unlocked
				else LeagueUI.Unlocks.requirement(league) + "\n") + button.tooltip_text
	if league == "standard":
		SeasonPages.wrapped(card, "Standard keeps the owned home field, five saved away venues and its tier final. "
			+ "Only previous Standard titles unlock its higher difficulties.")


static func _ask_other(app: Node, league: String, revision: int, tier: int = 0) -> void:
	var seed_value: int = int(Time.get_unix_time_from_system()) & 0x7fffffff
	app._confirm(
		"Pause Dynasty and start %s / %s? Draft a fresh roster with reset Cash and items. "
		% [league.capitalize(), LeagueUI.tier_label(tier)]
		+ "Dynasty's exact season stays saved. This league freezes your current owned home. Shared club income and earned access remain.\n\n"
		+ "\n".join(LeagueUI.pressure_lines(tier)) + "\n\n" + LeagueUI.reward_summary(tier),
		_start_other.bind(app, league, revision, seed_value, tier)
	)
	if league == "standard" and StadiumSurfaceNightSnapshot.PUBLIC_READY:
		var choice: OptionButton = OptionButton.new()
		choice.name = "SharedStandardTime"
		choice.add_item("Day · 13:10")
		choice.add_item("Sunset · 16:10 (qualified owned lights required)")
		choice.add_item("Night (qualified owned lights required)")
		choice.fit_to_longest_item = false
		choice.clip_text = true
		app._confirmation_body.add_child(choice)
		app._dialog.dialog_text += " Home time stays fixed for this season. Unsupported Sunset/Night does not fall back to Day. Away and final parks keep their venue profiles."
		var ref: WeakRef = weakref(choice)
		app._confirmed_action = func() -> void:
			var selected: OptionButton = ref.get_ref()
			if is_instance_valid(selected) and selected.selected in [0, 1, 2]:
				_start_other(app, league, revision, seed_value, tier, ["day", "sunset", "night"][selected.selected])
		app._dialog.visibility_changed.connect(func() -> void:
			var previous: OptionButton = ref.get_ref()
			if not app._dialog.visible and is_instance_valid(previous):
				previous.queue_free(), CONNECT_ONE_SHOT)
		app._refresh_confirmation()
	if league != "standard":
		load("res://src/presentation/season/dynasty_shared_time_ui.gd").alternate(app, league, revision, seed_value, tier)
	app._dialog.get_cancel_button().grab_focus()


static func _start_other(
	app: Node, league: String, revision: int, seed_value: int, tier: int, starting_profile: String = ""
) -> void:
	if not app.dynasty_owner.start_other(league, revision, seed_value, tier, starting_profile):
		show(app)


static func badge(app: Node, parent: Node) -> void:
	var view: Dictionary = app.dynasty_owner.view()
	if view.is_empty():
		SeasonPages.wrapped(parent, "Shared club balance is unavailable until save recovery.")
		return
	SeasonPages.wrapped(parent, "CLUB BUCKS  •  %d  •  Shared Dynasty career" % view.balance)
	app.menu._button(parent, "SHARED CLUB RECORD", record.bind(app, 0))


static func settlement(app: Node) -> void:
	var owner: Dictionary = app.dynasty_owner.found().get("owner", {})
	if owner.is_empty():
		return
	var id: String = owner[owner.selected].session_id
	var receipt: Dictionary = {}
	for row: Dictionary in owner.career.settlements:
		if row.session_id == id:
			receipt = row.receipt
	if receipt.is_empty():
		SeasonPages.wrapped(app.menu._body,
			"Result save pending. Club Bucks are credited in the same saved completion transaction.")
		app.menu._button(app.menu._body, "RETRY RESULT SAVE", app.dynasty_owner._retry_completed)
	else:
		SeasonPages.wrapped(app.menu._body, "+%d CLUB BUCKS • Shared season settled" % receipt.total)
	badge(app, app.menu._body)


static func record(app: Node, page: int = 0) -> void:
	var menu: SeasonMenu = app.menu
	menu._screen("dynasty_career_record", "SHARED CLUB RECORD", "One owner-wide balance and history")
	var view: Dictionary = app.dynasty_owner.view()
	if view.is_empty():
		menu._button(menu._body, "RECOVER SHARED CAREER", app.dynasty_owner._recover)
		menu._button(menu._footer, "BACK", menu.show_home)
		return
	menu._label(menu._body, "CLUB BUCKS  •  %d" % view.balance, 28)
	SeasonPages.wrapped(menu._body, (
		"New sessions receive current earned access. Paused sessions keep their original access "
		+ "and rules. Closing an unfinished session pays no Club Bucks. "
		+ "Player packs and supported field purchases use this shared balance. Existing fields stay frozen."
	))
	menu._button(menu._body, "PLAYERS & PACKS", ClubPlayersUI.show.bind(menu, "All", 0))
	menu._button(menu._body, "SHARED STADIUM WORKSHOP",
		load("res://src/presentation/stadium/shared_stadium_workshop_ui.gd").show.bind(app))
	var history: Array = view.history
	var last: int = maxi(0, int((history.size() - 1) / 20.0))
	page = clampi(page, 0, last)
	menu._label(menu._body, "SETTLED SEASONS • Page %d of %d" % [page + 1, last + 1], 22)
	var end: int = maxi(0, history.size() - page * 20)
	for index: int in range(end - 1, maxi(-1, end - 21), -1):
		var run: Dictionary = history[index]
		SeasonPages.wrapped(menu._body, "Season #%d • %s • %s • +%d CB" % [
			run.id, ClubCareerUI.tier_label(int(run.tier), str(run.league)),
			str(run.receipt.get("finish", run.status)).replace("_", " ").capitalize(),
			run.receipt.get("total", 0)
		])
	menu._label(menu._body, "SAVED SESSIONS", 22)
	for entry: Dictionary in view.sessions.values():
		SeasonPages.wrapped(menu._body, "%s / %s • %s" % [
			str(entry.session.league).capitalize(), LeagueUI.tier_label(int(entry.session.tier)),
			"Closed" if entry.settled > 0 else "In progress"
		])
	if page > 0:
		menu._button(menu._footer, "NEWER", record.bind(app, page - 1))
	if page < last:
		menu._button(menu._footer, "OLDER", record.bind(app, page + 1))
	menu._button(menu._footer, "CHOOSE LEAGUE", show.bind(app))
	menu._button(menu._footer, "MAIN MENU", menu.show_home)
