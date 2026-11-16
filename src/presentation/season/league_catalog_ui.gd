extends RefCounted
## Only the separate development scene calls this catalog. Availability here is
## not saved progression, an unlock threshold, or public League admission.
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const PlayerCopy = preload("res://src/presentation/season/closed_league_player_copy.gd")


static func label(league_id: String) -> String:
	return league_id.capitalize() if league_id in LeagueRules.IDS else "Unavailable League"


static func description(league_id: String) -> String:
	match league_id:
		"standard":
			return ("A separate playtest season with two held-item slots, five sponsor " + \
				"slots, and normal game income. Your normal Standard career stays " + "unchanged.")
		"dynasty":
			return ("Resume your saved Dynasty with its current rules. Switching leagues " + \
				"leaves your team and season unchanged. You can't start or replace a " + "Dynasty here.")
		"dugout":
			return "Three shared held-item slots and five sponsor slots."
		"sponsorship":
			return ("Six sponsor slots and normal Bat access. Current game income: 16 Cash " + \
				"for a win, 10 for a loss.")
		"academy":
			return ("Up to two distinct immediate-use upgrades from one fixed pack reveal. " + \
				"Current base pack price: 12 Cash, before eligible discounts.")
		"doubleheader":
			return ("Pitching workload carries across each two-game opponent set. Current " + \
				"regular-season pair sweep bonus: 6 Cash.")
		"equipment":
			return ("Three active Gear slots plus one inactive spare; swap between games " + \
				"in an open shop. One shared held-item slot.")
		"earnings":
			return ("Game income replaces ordinary win/loss Cash: 15 plus your final run " + \
				"margin, bounded to 10–24 Cash.")
		"scramble":
			return ("Each player's four starting stat values are permuted once for the " + \
				"season. Values and totals stay intact; reload never reshuffles them.")
	return "Unavailable."


static func show(app: Node) -> void:
	var setup: RefCounted = app.league_setup
	if not setup.token().is_empty():
		show_setup(app)
		return
	var menu: SeasonMenu = app.menu
	var found: Dictionary = Store.inspect(SeasonSave._dynasty_owner_path)
	var owner: Dictionary = found.get("owner", {})
	var ready: bool = (
		found.get("status") == "ready"
		and not owner.is_empty()
		and app.season != null
		and not SeasonSave._dynasty_owner_content_blocked
	)
	menu._screen(
		"closed_leagues", "LEAGUES · PLAYTEST", "Base leagues only. No unlocks or Club Bucks."
	)
	(
		SeasonPages
		. wrapped(
			menu._body,
			(
				"One alternate alongside Dynasty. Your normal Standard save stays unchanged. "
				+ "Alternates cannot be replaced in this playtest."
			)
		)
	)
	if not setup.error.is_empty():
		SeasonPages.wrapped(menu._body, PlayerCopy.notice(setup.error))
	if not ready:
		SeasonPages.wrapped(
			menu._body,
			PlayerCopy.recovery(
				str(found.get("status", "")), SeasonSave._dynasty_owner_content_blocked
			)
		)
		menu._button(menu._body, "RECOVER SAVE", _recover.bind(app))
	var expected: int = int(found.get("revision", -1))
	for league_id: String in LeagueRules.IDS:
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		menu._label(card, label(league_id) + " / Base", 25)
		SeasonPages.wrapped(card, description(league_id))
		if not ready:
			SeasonPages.wrapped(card, "Recover your save before choosing a league.")
		elif league_id == "dynasty":
			if owner.selected == "dynasty":
				menu._button(card, "CURRENT DYNASTY", app.show_season)
			else:
				menu._button(
					card, "RETURN TO DYNASTY", app.dynasty_owner.ask_switch.bind("dynasty")
				)
		elif not owner.other.is_empty():
			if owner.other.profile.league == league_id:
				menu._button(
					card,
					(
						"CURRENT " + label(league_id).to_upper()
						if owner.selected == "other"
						else "RESUME " + label(league_id).to_upper()
					),
					(
						app.show_season
						if owner.selected == "other"
						else app.dynasty_owner.ask_switch.bind("other")
					)
				)
			else:
				SeasonPages.wrapped(
					card,
					(
						"Your alternate is "
						+ label(owner.other.profile.league)
						+ ". Resume it to keep playing; it cannot be replaced in this playtest."
					)
				)
		else:
			menu._button(
				card,
				"PREPARE " + label(league_id).to_upper(),
				_prepare.bind(app, league_id, expected)
			)
	menu._button(menu._footer, "BACK", menu.show_home)


static func _prepare(app: Node, league_id: String, expected: int) -> void:
	var seed_value: int = int(Time.get_unix_time_from_system()) & 0x7fffffff
	app.league_setup.prepare_alternate(league_id, seed_value, expected)
	show(app)


static func show_setup(app: Node) -> void:
	var setup: RefCounted = app.league_setup
	var candidate: SeasonState = setup.candidate()
	if candidate == null or setup.token().is_empty():
		show(app)
		return
	var ticket: String = setup.token()
	var count: int = candidate.picks.size()
	var menu: SeasonMenu = app.menu
	var attempting: bool = setup.has_attempt()
	(
		menu
		. _screen(
			"closed_league_setup",
			label(candidate.league_rules.league).to_upper() + " / BASE",
			(
				(
					"Start not confirmed. Retry with this roster or recover your save. Closing setup "
					+ "does not cancel the start."
				)
				if attempting
				else "Canceling setup discards this draft."
			)
		)
	)
	SeasonPages.wrapped(menu._body, description(candidate.league_rules.league))
	if not attempting:
		(
			SeasonPages
			. wrapped(
				menu._body,
				(
					"Start with a new roster and zero Cash. Dynasty stays saved; its players and "
					+ "seasonal items do not carry over."
				)
			)
		)
	if not setup.error.is_empty():
		SeasonPages.wrapped(menu._body, PlayerCopy.notice(setup.error))
	var names: PackedStringArray = []
	for id: String in candidate.picks:
		names.append(candidate.player_definition(id).display_name)
	SeasonPages.wrapped(
		menu._body,
		"YOUR ROSTER: " + (", ".join(names) if not names.is_empty() else "Choose your first player")
	)
	if count < 4:
		menu._label(menu._body, "TRYOUT %d OF 4" % [count + 1], 24)
		var cards: HFlowContainer = HFlowContainer.new()
		cards.add_theme_constant_override("h_separation", 12)
		cards.add_theme_constant_override("v_separation", 12)
		menu._body.add_child(cards)
		var reference: PlayerDefinition = (
			candidate.player_definition(candidate.picks[-1]) if count > 0 else null
		)
		for id: String in candidate.offers():
			SeasonPlayerCard.draft_card(
				cards,
				candidate.player_definition(id),
				setup.selection == id,
				_select.bind(app, ticket, count, id),
				reference
			)
		var confirm: Button = menu._button(
			menu._footer, "DRAFT SELECTED PLAYER", _pick.bind(app, ticket, count, setup.selection)
		)
		confirm.disabled = setup.selection.is_empty()
	else:
		if not attempting:
			(
				SeasonPages
				. wrapped(
					menu._body,
					(
						"Roster ready. Start this alternate and pause Dynasty. You cannot replace this "
						+ "alternate during the playtest."
					)
				)
			)
		menu._button(
			menu._footer,
			"RETRY START" if setup.has_attempt() else "START SEASON",
			_ask_commit.bind(app, ticket)
		)
	if setup.has_attempt():
		menu._button(menu._body, "RECOVER SAVE", _recover.bind(app))
	menu._button(menu._footer, "CANCEL SETUP", _cancel.bind(app, ticket))


static func _select(app: Node, ticket: String, count: int, id: String) -> void:
	var setup: RefCounted = app.league_setup
	var candidate: SeasonState = setup.candidate()
	if (
		ticket != setup.token()
		or candidate == null
		or candidate.picks.size() != count
		or not candidate.offers().has(id)
	):
		return
	setup.selection = id
	show_setup(app)


static func _pick(app: Node, ticket: String, count: int, id: String) -> void:
	app.league_setup.choose_player(ticket, count, id)
	show(app)


static func _ask_commit(app: Node, ticket: String) -> void:
	if ticket != app.league_setup.token():
		return
	(
		app
		. _confirm(
			(
				"Start this roster as your one alternate? Dynasty will pause unchanged, and your "
				+ "normal Standard save stays untouched. This alternate can't be replaced during the "
				+ "playtest."
			),
			_commit.bind(app, ticket)
		)
	)
	app._dialog.get_cancel_button().grab_focus()


static func _commit(app: Node, ticket: String) -> void:
	if not app.league_setup.commit_alternate(ticket):
		show(app)


static func _cancel(app: Node, ticket: String) -> void:
	app.league_setup.cancel(ticket)
	show(app)


static func _recover(app: Node) -> void:
	app.league_setup.recover()
	show(app)
