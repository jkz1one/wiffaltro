class_name SeasonOpponentTacticsUI
extends RefCounted
## Read-only shared bag, actual paid copies and completed use history.


static func preview(card: VBoxContainer, club: Dictionary) -> void:
	var box: VBoxContainer = SeasonPlayerCard.panel(card, false)
	var build: SeasonBuild = club.build
	var held: Array[Dictionary] = SeasonTacticalCatalog.held(build._bank.view())
	var hitter: PlayerDefinition = build.definition(club.roles.hitter)
	SeasonPages.wrapped(box, "BATTING SUPPLIES • %d / 2 held" % held.size()).set_meta(
		"opponent_tactical_slots", true)
	SeasonPages.wrapped(box, "Grip Tape / Swing Plan: 3 Cash each, bought after development, "
		+ "preferred Gear, qualified sponsors and learning. Same wallet and held capacity. "
		+ "Before the first pitch of each PA for %s: Tape first; otherwise Plan locks %s. " % [
			hitter.display_name, "Power" if hitter.power > hitter.contact else "Contact"]
		+ "One copy per PA; unused copies stay held. Other supplies and Budget Bites remain gated.")
	if held.is_empty():
		SeasonPages.wrapped(box, "No held batting supply.")
	for copy: Dictionary in held:
		var item: Dictionary = SeasonTacticalCatalog.item(copy.item)
		SeasonPages.wrapped(box, "%s • paid %d Cash\n%s" % [item.name, copy.paid, item.effect]
		).set_meta("opponent_tactical_owned", true)
	for decision: Dictionary in club.decisions:
		if decision.stat == "tactical":
			SeasonPages.wrapped(box, "Bought %s • %d Cash • game %d" % [
				SeasonTacticalCatalog.item(decision.item).name, decision.paid, decision.game])
	for event: Dictionary in build.to_data().events:
		for action: Dictionary in event.get("tactics", []):
			SeasonPages.wrapped(box, "Used %s • game %d • plate appearance %d%s" % [
				_used_name(club, action.receipt), event.game, action.pa,
				" • " + action.swing.trim_prefix("swing.").capitalize() if action.swing != "" else ""])


static func _used_name(club: Dictionary, receipt: String) -> String:
	var request: String = "ai:" + receipt.trim_prefix("tactical-purchase:")
	for decision: Dictionary in club.decisions:
		if decision.stat == "tactical" and decision.request == request:
			return SeasonTacticalCatalog.item(decision.item).name
	return "batting supply"
