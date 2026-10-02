class_name SeasonRetrainingUI
extends RefCounted


static func status(window: SeasonShopWindow) -> void:
	var build: SeasonBuild = window.app.season.build
	if not build._retraining_enabled:
		window._label("Retraining Camp access begins with your next new Working season.")
		return
	window._label(
		(
			"Retraining Camp • %d / 4 applied training points this season. %s"
			% [
				mini(4, SeasonRetraining.count(build._book)),
				"Future offers need one player with two movable points; current stock stays fixed."
			]
		)
	)


static func offer(window: SeasonShopWindow, quote: String) -> void:
	window._label("Retraining Camp • Transformation • Uncommon • 8 Cash • Working")
	window._label(SeasonRetraining.ITEM.effect)
	window._button("RETRAIN PLAYER", choose.bind(window, quote)).set_meta("retrain_offer", quote)


static func choose(window: SeasonShopWindow, quote: String) -> void:
	window._clear()
	window._label("RETRAINING CAMP • CHOOSE A PLAYER")
	(
		window
		. _label(
			(
				"Move two trained points; baseline and recruit catch-up stay fixed. "
				+ "Earned-only targeting is a testing proposal. Apply now for 8 Cash, with final review."
			)
		)
	)
	var build: SeasonBuild = window.app.season.build
	for player: String in SeasonRetraining.targets(build):
		var definition: PlayerDefinition = build.definition(player)
		SeasonPlayerCard.ratings_card(window._body, definition, definition.display_name)
		var available: Dictionary = SeasonRetraining.points(build._book, player)
		window._label("Movable: " + _amounts(available))
		window._button("RETRAIN " + definition.display_name, sources.bind(window, quote, player))
	window._button("BACK TO SHOP", window._refresh)
	window._focus_first.call_deferred()


static func sources(window: SeasonShopWindow, quote: String, player: String) -> void:
	window._clear()
	window._label(
		"REMOVE TWO TRAINED POINTS • " + window.app.season.build.definition(player).display_name
	)
	var seen: Array = []
	for choice: Dictionary in SeasonRetraining.choices(window.app.season.build._book, player):
		if seen.has(choice.remove):
			continue
		seen.append(choice.remove)
		window._button(
			"REMOVE " + _pair(choice.remove),
			destinations.bind(window, quote, player, choice.remove)
		)
	window._button("BACK TO PLAYERS", choose.bind(window, quote))
	window._focus_first.call_deferred()


static func destinations(
	window: SeasonShopWindow, quote: String, player: String, remove: Array
) -> void:
	window._clear()
	window._label(
		"REDIRECT TWO POINTS • " + window.app.season.build.definition(player).display_name
	)
	window._label("Remove " + _pair(remove) + ". Choose the additions, then review before paying.")
	for choice: Dictionary in SeasonRetraining.choices(window.app.season.build._book, player):
		if choice.remove != remove:
			continue
		var command: Dictionary = window._request(
			"retrain_buy",
			{"offer": quote, "player": player, "remove": remove.duplicate(), "add": choice.add}
		)
		window._purchase(
			"ADD " + _pair(choice.add),
			command,
			review(window.app.season.build, command),
			window.app.season.build.definition(player).display_name + " • remove " + _pair(remove)
		)
	window._button("BACK TO REMOVALS", sources.bind(window, quote, player))
	window._focus_first.call_deferred()


static func review(build: SeasonBuild, command: Dictionary) -> String:
	var inspected: SeasonBuild = build._fork()
	var next: SeasonBuild = inspected.candidate(command)
	if next == null:
		return inspected.last_error
	var before: Dictionary = build.player(command.player).stats
	var after: Dictionary = next.player(command.player).stats
	var rows: PackedStringArray = []
	for stat: String in SeasonPlayerCatalog.STATS:
		rows.append("%s: %d → %d" % [stat.capitalize(), before[stat], after[stat]])
	return (
		(
			"%s • Retraining Camp\n%s\n8 Cash. Two points moved, zero gained.\n"
			+ "Baseline, recruit catch-up, mastery and training rewards stay unchanged. Season only."
		)
		% [build.definition(command.player).display_name, "\n".join(rows)]
	)


static func _pair(stats: Array) -> String:
	return (
		"2 %s" % String(stats[0]).capitalize()
		if stats[0] == stats[1]
		else "1 %s / 1 %s" % [String(stats[0]).capitalize(), String(stats[1]).capitalize()]
	)


static func _amounts(amounts: Dictionary) -> String:
	var result: PackedStringArray = []
	for stat: String in SeasonPlayerCatalog.STATS:
		result.append("%s %d" % [stat.capitalize(), amounts[stat]])
	return " / ".join(result)
