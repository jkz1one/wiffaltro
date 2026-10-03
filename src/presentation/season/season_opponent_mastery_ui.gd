class_name SeasonOpponentMasteryUI
extends RefCounted
## Public committed growth; no shopping or target changes from disclosure.


static func preview(card: VBoxContainer, club: Dictionary) -> void:
	SeasonPages.wrapped(card, "Opponent shops offer stat training, Pitch Mastery, Round Out "
		+ "and 13 initial Gear items. Pitch upgrades share a cap of 5. "
		+ "Lessons, sponsors and supplies remain unavailable.").set_meta("opponent_mastery_pool", true)
	if club.profile != "Pitching / defense":
		return
	var profile: Dictionary = club.build.player(club.roles.pitcher)
	var box: VBoxContainer = SeasonPlayerCard.panel(card, false)
	SeasonPages.wrapped(box, "PITCHING FOCUS • "
		+ ContentDB.get_player(StringName(club.roles.pitcher)).display_name)
	SeasonPages.wrapped(box, "%s • Lv%d / %d" % [
		ContentDB.get_pitch(StringName(club.primary)).display_name, profile.mastery[club.primary],
		SeasonDevelopment.PITCH_CAP]).set_meta("opponent_mastery", true)
	SeasonPages.wrapped(box, "Working goals: starter Pitching 4, this pitch Lv3, "
		+ "fielder Fielding 4, then second pitcher Pitching 3. Upgrades cost Cash.")
	SeasonPages.wrapped(box, "Round Out • 6 Cash • improves one lowest-level active pitch.\n"
		+ "Pitch Mastery • 8 Cash • improves one chosen active pitch. "
		+ "This club keeps its chosen fastball.")


static func purchase(card: VBoxContainer, row: Dictionary) -> void:
	var item: Dictionary = DevelopmentShopCatalog.item(row.item)
	var label: String = item.name
	if row.paid != item.price:
		label += " (pack pick)"
	SeasonPages.wrapped(card, "Bought %s for %s • %s to Lv%d • %d Cash • %s" % [
		label,
		ContentDB.get_player(StringName(row.player)).display_name,
		ContentDB.get_pitch(StringName(row.pitch)).display_name, row.level, row.paid, row.reason]
	).set_meta("opponent_mastery_purchase", true)
