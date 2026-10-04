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
				("Opponent paid build • %s • Cash %d • %d purchases"
				if season.opponents._format >= 3
				else "Opponent paid development • %s • Cash %d • %d purchased steps")
				% [data.profile, data.cash, data.purchases]
			)
		)
		. set_meta("opponent_build", true)
	)
	SeasonPages.wrapped(
		card,
		(
			"Purchases are committed before your shop. This opponent spends match rewards "
			+ ("on development, Gear, learning, six sponsors and match supplies, using one wallet."
				if season.opponents._format >= 10
				else "on development, Gear, learning, six sponsors and batting supplies, using one wallet."
				if season.opponents._format >= 9
				else "on development, Gear, learning and six supported sponsors, using one wallet."
				if season.opponents._format >= 8
				else "on development, Gear, learning and four supported sponsors, using one wallet."
				if season.opponents._format >= 7
				else "on development, Gear, lessons and learned abilities, using one wallet."
				if season.opponents._format >= 6
				else "on development, initial Gear and Common pitch lessons, using one wallet."
				if season.opponents._format >= 5
				else "on stat development and initial Gear, using one wallet."
				if season.opponents._format >= 3 else "on Contact, Power, Fielding and Pitching.")
		)
	)
	if season.opponents._format >= 5:
		SeasonOpponentMasteryUI.preview(card, season.opponents.clubs[str(index)], false)
		SeasonOpponentLessonsUI.preview(card, season.opponents.clubs[str(index)],
			season.opponents._format < 6)
		if season.opponents._format >= 6:
			SeasonOpponentAbilitiesUI.preview(card, season.opponents.clubs[str(index)],
				season.opponents._format < 7)
		if season.opponents._format >= 7:
			SeasonOpponentSponsorsUI.preview(card, season.opponents.clubs[str(index)])
		if season.opponents._format >= 9:
			SeasonOpponentTacticsUI.preview(
				card, season.opponents.clubs[str(index)], season._make_team(0))
	elif season.opponents._format >= 4:
		SeasonOpponentMasteryUI.preview(card, season.opponents.clubs[str(index)])
	elif season.physical != null:
		SeasonPages.wrapped(card, "Other clubs play physical matches between rounds. "
			+ ("AI offers include 13 initial Gear and four stat cards. Sponsors and supplies remain gated."
				if season.opponents._format >= 3
				else "AI shopping supports paid stat development; Gear and sponsors remain gated."))
	if season.opponents._format >= 3:
		SeasonOpponentGearUI.equipment(card, season.opponents.clubs[str(index)].build)
	if season.opponents._format >= 2:
		SeasonPages.wrapped(card, "Two pitching options • Starting roles shown below")
	for id: String in season.teams[index].roster:
		var player: PlayerDefinition = season.player_definition(id)
		SeasonPages.wrapped(
			card,
			(
				"%s • %s\nContact %d / Power %d / Fielding %d / Pitching %d"
				% [
					player.display_name,
					role_names(data.roles, id),
					player.contact,
					player.power,
					player.fielding,
					player.control
				]
			)
		)
		SeasonPlayerCard.inspection_button(card, player, "INSPECT " + player.display_name)
	for row: Dictionary in data.decisions.slice(maxi(0, data.decisions.size() - 3)):
		if row.stat in ["lesson", "ability", "sponsor", "tactical"]:
			continue # Complete learning history is grouped with its role panel above.
		if row.stat == "mastery":
			SeasonOpponentMasteryUI.purchase(card, row)
			continue
		if row.stat == "gear":
			SeasonPages.wrapped(card, "Bought %s • team %s • %d Cash • %s" % [
				SeasonGearCatalog.item(row.item).name, SeasonGearCatalog.item(row.item).slot,
				row.paid, row.reason])
			continue
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


static func role_names(roles: Dictionary, id: String) -> String:
	var labels: Array[String] = []
	for role: String in ["pitcher", "fielder", "secondary", "hitter"]:
		if roles[role] == id:
			labels.append(
				{
					"pitcher": "Starting pitcher",
					"fielder": "Primary fielder",
					"secondary": "Reserve pitcher",
					"hitter": "Featured hitter"
				}[role]
			)
	return " / ".join(labels) if not labels.is_empty() else "Hitter"
