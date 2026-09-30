class_name SeasonOpponentUI
extends RefCounted


static func preview(menu: SeasonMenu, card: VBoxContainer, fixture: Dictionary) -> void:
	var season: SeasonState = menu.app.season
	if season.opponents == null:
		return
	var index: int = fixture.away if fixture.home == 0 else fixture.home
	var data: Dictionary = season.opponents.summary(index)
	(
		SeasonPages
		. wrapped(
			card,
			(
				"Opponent paid development • %s • Cash %d • %d purchased steps"
				% [data.profile, data.cash, data.purchases]
			)
		)
		. set_meta("opponent_build", true)
	)
	SeasonPages.wrapped(
		card,
		(
			"Purchases are committed before your shop. This opponent spends match rewards "
			+ "on Contact, Power, Fielding and Pitching."
		)
	)
	for id: String in season.teams[index].roster:
		var player: PlayerDefinition = season.player_definition(id)
		SeasonPages.wrapped(
			card,
			(
				"%s • Contact %d / Power %d / Fielding %d / Pitching %d"
				% [
					player.display_name,
					player.contact,
					player.power,
					player.fielding,
					player.control
				]
			)
		)
	for row: Dictionary in data.decisions.slice(maxi(0, data.decisions.size() - 3)):
		SeasonPages.wrapped(
			card,
			(
				"Bought %s for %s • %d Cash • %s"
				% [
					row.stat.capitalize(),
					ContentDB.get_player(StringName(row.player)).display_name,
					row.paid,
					row.reason
				]
			)
		)
