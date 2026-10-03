class_name SeasonOpponentSponsorsUI
extends RefCounted
## Read-only paid team sponsors, actual earnings and conservative buying qualifications.


static func preview(card: VBoxContainer, club: Dictionary) -> void:
	SeasonPages.wrapped(card, "Opponent stock adds Take Your Base, Neighborhood Deli, "
		+ "Community College and Strikecraft to development, 13 initial Gear and learning. "
		+ "Other sponsors, supplies and recruiting remain gated.")
	var box: VBoxContainer = SeasonPlayerCard.panel(card, false)
	SeasonPages.wrapped(box, "TEAM SPONSORS")
	var build: SeasonBuild = club.build
	SeasonPages.wrapped(box, "%d / 5 active • Empty slots only; no replacements. " % [
		build._bank.view().sponsors.size()]
		+ "Bought after development and preferred Gear, before learning.").set_meta(
		"opponent_sponsor_slots", true)
	var rule: String = "Take Your Base: a credited walk in the last two games, " \
		+ "with at least three regular games left."
	if club.profile == "Featured hitter":
		rule = "Deli first: at least two team Singles last game. " + rule
	elif club.profile == "Pitching / defense":
		rule = "College first: actual earned development; then Strikecraft: " \
			+ "primary arm knows at least three recipes. " + rule
	SeasonPages.wrapped(box, rule)
	if build._bank.view().sponsors.is_empty():
		SeasonPages.wrapped(box, "No paid sponsor yet.")
	for receipt: Dictionary in build._bank.view().sponsors:
		var item: Dictionary = SeasonSponsorCatalog.item(receipt.item)
		SeasonPages.wrapped(box, "%s • paid %d Cash\n%s" % [item.name, receipt.paid, item.effect]
		).set_meta("opponent_sponsor_owned", true)
		if receipt.item == "B02":
			SeasonPages.wrapped(box, "Current qualifying developed players: %d / 4" % [
				build._book.earned_players(build.roster()).size()])
	for row: Dictionary in club.decisions:
		if row.stat == "sponsor":
			SeasonPages.wrapped(box, "Bought %s • %d Cash • game %d" % [
				SeasonSponsorCatalog.item(row.item).name, row.paid, row.game]
			).set_meta("opponent_sponsor_purchase", true)
	for event: Dictionary in SeasonOpponentSponsors.history(build):
		var income: Dictionary = build.income_for_game(int(event.game))
		if income.has("D01"):
			SeasonPages.wrapped(box, "Take Your Base earned %d Cash • game %d • actual credited walks" % [
				income.D01, event.game]).set_meta("opponent_sponsor_income", true)
