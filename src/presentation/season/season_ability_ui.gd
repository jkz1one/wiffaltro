class_name SeasonAbilityUI
extends RefCounted


static func offer(window: SeasonShopWindow, quote: String, id: String) -> void:
	var item: Dictionary = SeasonAbilities.ITEMS[id]
	window._label(
		(
			"%s • %s ability • %s • %d Cash • Working\n%s"
			% [item.name, item.slot, item.rarity, item.price, item.effect]
		)
	)
	var button: Button = window._button("LEARN " + item.name, choose.bind(window, quote, id))
	button.set_meta("ability_offer", quote)
	button.disabled = (
		window.app.season.build._abilities.targets(window.app.season.build, id).is_empty()
	)


static func choose(window: SeasonShopWindow, quote: String, id: String) -> void:
	var build: SeasonBuild = window.app.season.build
	var item: Dictionary = SeasonAbilities.ITEMS[id]
	window._clear()
	window._label("LEARN %s • %d Cash" % [item.name, item.price])
	window._label(item.effect)
	window._label(
		(
			(
				"One Hitting and one Fielding slot; Double Major grants its nominee a "
				+ "second Fielding slot. Learning lasts this season."
			)
			+ "Choose a player below, then review before paying. No held copy, resale or refund."
		)
	)
	for target: Dictionary in build._abilities.targets(build, id):
		var player: PlayerDefinition = build.definition(target.player)
		var old: Dictionary = {}
		for receipt: Dictionary in build._abilities.in_slot(target.player, item.slot):
			if receipt.id == target.replace:
				old = receipt
		SeasonPlayerCard.ratings_card(window._body, player, player.display_name)
		var replacement: String = (
			"Fill the empty %s slot." % item.slot
			if old.is_empty()
			else (
				"Forget %s; no refund. Its effect ends immediately."
				% SeasonAbilities.ITEMS[old.item].name
			)
		)
		var command: Dictionary = window._request(
			"ability_buy", {"offer": quote, "player": target.player, "replace": target.replace}
		)
		var button: Button = window._button(
			"TEACH " + player.display_name,
			window._preview.bind(
				command,
				(
					"Teach %s to %s.\n%s\n%s\nSeason only; no resale."
					% [item.name, player.display_name, replacement, item.effect]
				)
			)
		)
		button.set_meta("ability_player", target.player)
		button.set_meta("ability_replace", target.replace)
		window._label(replacement)
	window._button("BACK TO SHOP", window._refresh)
	window._focus_first.call_deferred()


static func show(menu: SeasonMenu) -> void:
	menu._screen(
		"abilities",
		"LEARNED ABILITIES",
		"Player learning lasts this season; earned access persists"
	)
	(
		SeasonPages
		. wrapped(
			menu._body,
			(
				(
					"Working contracts. One Hitting and one Fielding ability; Double Major "
					+ "grants its nominee a second Fielding slot."
				)
				+ "Buy from future shops and apply immediately; explicit replacement forgets "
				+ "the old ability without a refund. "
				+ "A released player keeps learning if they return in this season. New seasons reset learning."
			)
		)
	)
	var total: int = SeasonAbilities.access(menu.app.season.career)
	for id: String in SeasonAbilities.ITEMS:
		var item: Dictionary = SeasonAbilities.ITEMS[id]
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		menu._label(
			card,
			(
				item.name
				+ (" • LOCKED" if id == SeasonAbilities.SKY and total < 3 else " • SHOP ELIGIBLE")
			),
			22
		)
		SeasonPages.wrapped(
			card, "%s • %s • %d Cash\n%s" % [item.slot, item.rarity, item.price, item.effect]
		)
		if id == SeasonAbilities.SKY:
			SeasonPages.wrapped(
				card,
				(
					"%d / 3 career clean airborne Primary Fielder outs in completed games. " % total
					+ "No free or guaranteed copy; existing shop stock stays fixed."
				)
			)
	if menu.app.season.build != null:
		if menu.app.season.build._abilities.start == null:
			SeasonPages.wrapped(
				menu._body, "This older active save begins Sky Reader tracking next Working season."
			)
		for id: String in menu.app.season.build.roster():
			SeasonPlayerCard.ratings_card(
				menu._body,
				menu.app.season.build.definition(id),
				menu.app.season.build.definition(id).display_name
			)
	menu._button(menu._footer, "BACK TO CLUB RECORD", ClubCareerUI.show.bind(menu, 0))
