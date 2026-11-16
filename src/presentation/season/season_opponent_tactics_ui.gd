class_name SeasonOpponentTacticsUI
extends RefCounted
## Read-only shared bag, actual paid copies and completed use history.


static func preview(
	card: VBoxContainer, club: Dictionary, opposition: TeamMatchState = null
) -> void:
	var box: VBoxContainer = SeasonPlayerCard.panel(card, false)
	var build: SeasonBuild = club.build
	var held: Array[Dictionary] = SeasonTacticalCatalog.held(build._bank.view())
	var hitter: PlayerDefinition = build.definition(club.roles.hitter)
	var capacity: int = int(build._bank.view().capacity.held) if (
		build._format == SeasonBuild.LEAGUE_VERSION and build.league_context_valid()) else 2
	SeasonPages.wrapped(box, ("MATCH SUPPLIES" if build._market >= 9 else "BATTING SUPPLIES")
		+ " • %d / %d held" % [held.size(), capacity]).set_meta(
		"opponent_tactical_slots", true)
	SeasonPages.wrapped(box, "Grip Tape / Swing Plan: 3 Cash each, bought after development, "
		+ "preferred Gear, qualified sponsors and learning. Same wallet and held capacity. "
		+ ("If no Base was used this PA, %s uses Tape or a %s Swing Plan before the first pitch. "
			if build._market >= 12
			else "Before the first pitch of each PA for %s: Tape first; otherwise Plan locks %s. ") % [
			hitter.display_name, "Power" if hitter.power > hitter.contact else "Contact"]
		+ "One copy per PA; unused copies stay held. "
		+ ("All five supplies and Budget Bites grants share this bag." if build._market >= 12 else
			"Take a Base remains gated. Budget Bites grants use this same bag." if build._market == 11 else
			"Take a Base and Budget Bites remain gated." if build._market in [10, 11, 12] else
			"Recovery Pack, Take a Base and Budget Bites remain gated." if build._market >= 9
			else "Other supplies and Budget Bites remain gated."))
	if build._market >= 9:
		var target_name: String = "the opposing roster's highest-Power hitter (ties by player ID)"
		if opposition != null:
			var id: String = SeasonOpponentHeat.target(opposition)
			for player: PlayerMatchState in opposition.roster:
				if String(player.definition.id) == id:
					target_name = player.definition.display_name
		SeasonPages.wrapped(box, ("Extra Heat: 5 Cash, after Tape/Plan/Recovery when offered. Before "
			if build._market in [10, 11, 12]
			else "Extra Heat: 5 Cash, after Tape/Plan when offered. Before ")
			+ "the first pitch against %s, consume one copy on the active pitcher. " % target_name
			+ "Velocity parameter ×1.05 for that PA; ends on pitcher substitution. "
			+ "Normal fatigue and physical limits apply; no guaranteed result.").set_meta(
				"opponent_heat_policy", true)
	if build._market in [10, 11, 12]:
		var pitcher: PlayerDefinition = build.definition(club.roles.pitcher)
		SeasonPages.wrapped(box, "Recovery Pack: 4 Cash, after Tape/Plan and before Heat when "
			+ "offered. Before the first pitch for %s, once at least 10%% of game-start " % (
				pitcher.display_name)
			+ "stamina has been spent, restore 10% of that maximum. Once per pitcher/game. "
			+ "Recovery outranks Heat at readiness; normal workload and fatigue continue. "
			+ "Unused copies stay held; substitution never transfers recovery.").set_meta(
				"opponent_recovery_policy", true)
	if build._market >= 12:
		SeasonPages.wrapped(box, "Take a Base: 8 Cash, after other affordable supplies when offered. "
			+ "At legal pre-first-pitch readiness, use only when the lowest occupied runner is "
			+ "alone on third and can score. It outranks this club's Tape/Plan. "
			+ "One real run, possibly a walk-off; no hit, walk, RBI or completed PA. "
			+ "Blocked or unused copies stay held. No forced stock or future-pitch knowledge."
		).set_meta("opponent_base_policy", true)
	if held.is_empty():
		SeasonPages.wrapped(box, "No held match supply.")
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
			SeasonPages.wrapped(box, "Used %s • game %d • plate appearance %d%s%s" % [
				_used_name(club, action.receipt), event.game, action.pa,
				" • " + action.swing.trim_prefix("swing.").capitalize() if action.swing != "" else "",
				" • " + build.definition(action.player).display_name if build._market >= 9 else ""]
				+ (" • 3B → HOME (+1 run, no RBI)" if action.get("advance", {}).get("to") == 4 else "")
			).set_meta("opponent_tactical_used", true)


static func _used_name(club: Dictionary, receipt: String) -> String:
	if receipt.begins_with("budget:"):
		return "Swing Plan (Budget Bites grant)"
	var request: String = "ai:" + receipt.trim_prefix("tactical-purchase:")
	for decision: Dictionary in club.decisions:
		if decision.stat == "tactical" and decision.request == request:
			return SeasonTacticalCatalog.item(decision.item).name
	return "batting supply"
