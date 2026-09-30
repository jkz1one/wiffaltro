class_name SeasonTransferUI
extends RefCounted


static func entry(window: SeasonShopWindow) -> void:
	var build: SeasonBuild = window.app.season.build
	if SeasonSchoolSponsors.active(build, "F07").is_empty():
		return
	if build._visit.get("transfer_used", false):
		window._label("Transfer Station used this visit. Personal mastery is retained.")
	else:
		window._button("TRANSFER STATION • EXCHANGE PITCHES", choose.bind(window))


static func description(build: SeasonBuild, row: Dictionary) -> String:
	var a: Dictionary = build.player(row.player)
	var b: Dictionary = build.player(row.other)
	return (
		(
			"%s: %s L%d → %s L%d\n%s: %s L%d → %s L%d\n"
			% [
				ContentDB.get_player(StringName(row.player)).display_name,
				ContentDB.get_pitch(StringName(row.first)).display_name,
				a.mastery[row.first],
				ContentDB.get_pitch(StringName(row.second)).display_name,
				a.mastery.get(row.second, 1),
				ContentDB.get_player(StringName(row.other)).display_name,
				ContentDB.get_pitch(StringName(row.second)).display_name,
				b.mastery[row.second],
				ContentDB.get_pitch(StringName(row.first)).display_name,
				b.mastery.get(row.first, 1)
			]
		)
		+ "No Cash fee. Both lose the outgoing recipe; repertoire sizes stay fixed. "
		+ "Outgoing mastery remains in each player's own history. Uses this visit's one exchange."
	)


static func choose(window: SeasonShopWindow) -> void:
	window._clear()
	window._label("TRANSFER STATION • REVIEW BOTH PLAYERS")
	(
		window
		. _label(
			(
				"Working contract. Only purchased season-learned pitches can move. "
				+ "Each incoming recipe uses the recipient's remembered mastery, or Level 1 if never known."
			)
		)
	)
	var build: SeasonBuild = window.app.season.build
	var options: Array[Dictionary] = SeasonTransfer.options(build)
	if options.is_empty():
		window._label(
			(
				"No legal pair. Two roster players need different learned pitches, "
				+ "and neither can already know the other's recipe."
			)
		)
	for row: Dictionary in options:
		window._label(description(build, row))
		(
			window
			. _button(
				"REVIEW EXCHANGE",
				window._preview.bind(
					window._request("transfer_pitch", row), description(build, row)
				)
			)
			. set_meta("transfer_pair", row)
		)
	window._button("BACK TO SHOP", window._refresh)
	window._focus_first.call_deferred()


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(
		card,
		(
			"Transfer Station • "
			+ ("SHOP ELIGIBLE" if menu.app.season.career.transfer_access() else "LOCKED")
		),
		22
	)
	SeasonPages.wrapped(
		card,
		(
			"Season: two different current players each know a purchased "
			+ "season-learned pitch. An Open Book pair qualifies. Access survives abandonment; "
			+ "no free copy. 12 Season Cash • Uncommon • Working. "
			+ SeasonTransfer.ITEMS.F07.effect
		)
	)
	var build: SeasonBuild = menu.app.season.build
	if build == null or build._transfer_start == null:
		SeasonPages.wrapped(
			card, "This older active save begins this tracking next Working season."
		)
	else:
		SeasonPages.wrapped(
			card,
			(
				"%d / 2 current players have qualifying learning."
				% mini(2, SeasonTransfer.learners(build))
			)
		)
