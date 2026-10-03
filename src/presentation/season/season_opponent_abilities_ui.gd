class_name SeasonOpponentAbilitiesUI
extends RefCounted
## Read-only committed role, learned slot, exact effect and paid receipt disclosure.


static func preview(card: VBoxContainer, club: Dictionary) -> void:
	SeasonPages.wrapped(card, "Opponent stock: development, 13 initial Gear, five Common lessons "
		+ "and Work the Count / Soft Hands / Sky Reader. Sponsors and supplies remain gated."
	).set_meta("opponent_ability_pool", true)
	var box: VBoxContainer = SeasonPlayerCard.panel(card, false)
	SeasonPages.wrapped(box, "LEARNED ABILITIES")
	var player: String = club.roles.hitter if club.profile == "Featured hitter" else club.roles.fielder
	var slot: String = "Hitting" if club.profile == "Featured hitter" else "Fielding"
	var build: SeasonBuild = club.build
	var rule: String = "Work the Count • 12 Cash" if slot == "Hitting" else "Soft Hands • 10 Cash"
	if club.profile == "Pitching / defense":
		rule += "; otherwise Sky Reader • 12 Cash"
	SeasonPages.wrapped(box, "%s • %s %d / 1\n%s when offered and affordable. " % [
		ContentDB.get_player(StringName(player)).display_name, slot,
		build._abilities.in_slot(player, slot).size(), rule]
		+ "Learning needs an empty slot; this club never replaces an ability."
	).set_meta("opponent_ability_role", true)
	var learned: Array[String] = build._abilities.ids(player)
	if learned.is_empty():
		SeasonPages.wrapped(box, "No learned ability on this role yet.")
	for item: String in learned:
		SeasonPages.wrapped(box, "%s • %s" % [
			SeasonAbilities.ITEMS[item].name, SeasonAbilities.ITEMS[item].effect])
	for row: Dictionary in club.decisions:
		if row.stat == "ability":
			SeasonPages.wrapped(box, "Learned %s for %s • %d Cash • game %d" % [
				SeasonAbilities.ITEMS[row.item].name,
				ContentDB.get_player(StringName(row.player)).display_name, row.paid, row.game]
			).set_meta("opponent_ability_purchase", true)
