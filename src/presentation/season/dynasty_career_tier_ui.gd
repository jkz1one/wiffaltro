extends RefCounted
## Next Dynasty season only. A selected or paused session never changes difficulty.

const LeagueUI = preload("res://src/presentation/season/league_career_ui.gd")


static func show(app: Node) -> void:
	var controller: RefCounted = app.dynasty_owner
	if not controller._next_choice.is_empty():
		controller.cancel_next(controller._next_choice.ticket)
	var menu: SeasonMenu = app.menu
	menu._screen("dynasty_next_tier", "NEXT DYNASTY SEASON", "Keep this roster • Choose difficulty")
	if not controller.ready():
		menu._button(menu._body, "RECOVER SHARED CAREER", controller._recover)
		menu._button(menu._footer, "BACK", menu.show_home)
		return
	var current: Dictionary = controller.found()
	var owner: Dictionary = current.owner
	if owner.selected != "dynasty" or owner.lineage.state != "closed" \
		or not owner.pending_next.is_empty():
		SeasonPages.wrapped(menu._body, "Return to the saved Dynasty controls to finish this season.")
		menu._button(menu._footer, "BACK", menu.show_home)
		return
	SeasonPages.wrapped(menu._body,
		"A Dynasty championship unlocks only its next tier. Lower unlocked tiers remain replayable. "
		+ "Your roster carries with existing development decay. No players are redrafted or released.")
	var available: Array[int] = controller.available_tiers("dynasty")
	for tier: int in range(5):
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		var title: String = "Dynasty / " + LeagueUI.tier_label(tier)
		menu._label(card, title, 24)
		for line: String in LeagueUI.pressure_lines(tier):
			SeasonPages.wrapped(card, line)
		var button: Button = menu._button(card, "REVIEW " + title.to_upper()
			if tier in available else title.to_upper() + " • LOCKED",
			_prepare.bind(app, tier, current.revision))
		button.set_meta("dynasty_next_tier", tier)
		button.disabled = tier not in available
		if button.disabled:
			button.tooltip_text = "Win Dynasty / %s first. Other Leagues' titles do not count." \
				% LeagueUI.tier_label(tier - 1)
	menu._button(menu._footer, "CANCEL", menu.show_home)


static func _prepare(app: Node, tier: int, revision: int) -> void:
	var seed_value: int = int(Time.get_unix_time_from_system()) & 0x7fffffff
	if app.dynasty_owner.prepare_next(tier, seed_value, revision):
		review(app)
	else:
		show(app)


static func review(app: Node) -> void:
	var choice: Dictionary = app.dynasty_owner._next_choice
	if choice.is_empty():
		show(app)
		return
	var menu: SeasonMenu = app.menu
	menu._screen("dynasty_next_review", "DYNASTY / " + LeagueUI.tier_label(choice.tier).to_upper(),
		"Review next season • No save changes until Start")
	for line: String in LeagueUI.pressure_lines(choice.tier):
		SeasonPages.wrapped(menu._body, line)
	SeasonPages.wrapped(menu._body, LeagueUI.reward_summary(choice.tier))
	SeasonPages.wrapped(menu._body,
		"Carry the same roster with existing development decay and reset seasonal Cash and items. "
		+ "If an ability-forgetting choice is required, this exact difficulty stays saved with it. "
		+ "Cancel leaves the closed season and roster unchanged.")
	if app.dynasty_owner.found().get("owner", {}).get("version") != 3:
		load("res://src/presentation/season/dynasty_shared_time_ui.gd").next_review(app)
	if app.dynasty_owner.ready():
		menu._button(menu._footer, "START & SAVE DYNASTY", _commit.bind(app, choice.ticket))
		menu._button(menu._footer, "CANCEL", _cancel.bind(app, choice.ticket))
	else:
		SeasonPages.wrapped(menu._body,
			"The save needs recovery. Recover the exact attempted transition before choosing again.")
		menu._button(menu._footer, "RECOVER SHARED CAREER", app.dynasty_owner._recover)


static func _commit(app: Node, ticket: int) -> void:
	if not app.dynasty_owner.commit_next(ticket):
		review(app)


static func _cancel(app: Node, ticket: int) -> void:
	app.dynasty_owner.cancel_next(ticket)
	show(app)
