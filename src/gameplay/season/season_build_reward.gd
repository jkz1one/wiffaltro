class_name SeasonBuildReward
extends RefCounted
# gdlint: disable=max-returns
## One atomic completed-game settlement, replayed inside the candidate build.


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	if not build._match_inventory.is_empty() and command.get("game") != build._match_inventory.game:
		return "Complete the current inventory attempt first."
	var fields: Array = ["game", "win"]
	if build._format >= 34 and command.has("field_supply"):
		fields.append("field_supply")
	if build._format >= 33 and command.has("pitching"):
		fields.append("pitching")
	if build._format >= 31 and command.has("fielding"):
		fields.append("fielding")
	if build._format >= 30 and command.has("stances"):
		fields.append("stances")
	if build._format >= 29 and command.has("batting"):
		fields.append("batting")
	if build._format >= 6 and command.has("performance"):
		fields.append("performance")
	if build._format >= 10 and command.has("used_gear"):
		fields.append("used_gear")
	if build._format >= 14 and command.has("tactics"):
		fields.append("tactics")
	if not build._keys(command, fields) or build._roster.size() != 4:
		return "Invalid season reward."
	var result: Dictionary = build._bank.commit(
		{
			"id": "game:%s" % str(command.game),
			"rev": build._bank.revision(),
			"op": "reward",
			"game": command.game,
			"win": command.win
		}
	)
	if not result.ok or result.replayed:
		return "This fixture cannot pay again."
	var error: String = build._settle_sponsors(command)
	if not error.is_empty():
		return error
	error = SeasonCarbonCopy.settle(build, command)
	if not error.is_empty():
		return error
	error = SeasonSureShot.settle(build, command)
	if not error.is_empty():
		return error
	error = SeasonJumpstart.settle(build, command)
	if not error.is_empty():
		return error
	error = SeasonFieldSupply.settle(build, command)
	if not error.is_empty():
		return error
	error = SeasonFieldGrant.prepare(build, command)
	if not error.is_empty():
		return error
	error = SeasonLeftRight.settle(build, command)
	if not error.is_empty():
		return error
	error = SeasonFreezers.settle(build, command)
	if not error.is_empty():
		return error
	if build._format >= 10:
		error = SeasonReclamation.settle(
			build, command.get("used_gear", []), command.get("performance", {})
		)
		if not error.is_empty():
			return error
	if build._format >= 14:
		error = SeasonTacticalPurchase.settle(
			build, command.get("tactics", []), command.get("performance", {}), int(command.game)
		)
		if not error.is_empty():
			return error
	if build._checkout_start != null:
		for action: Dictionary in command.get("tactics", []):
			build._checkout_earned = build._checkout_earned or action.get("walked", false)
	if build._supply_start != null:
		build._supply_used += command.get("tactics", []).size()
	error = SeasonFieldGrant.finish(build, command)
	if not error.is_empty():
		return error
	var insured: String = SeasonSecondChance.settle(build, command)
	if not insured.is_empty():
		return insured
	build._gear_progress.settle(build, command)
	build._match_inventory.clear()
	build._sponsor_progress.settle(build, command)
	SeasonLegends.settle(build, command.get("performance", {}))
	build._game_rosters[int(command.game)] = build.roster()
	build._visit = {"number": build._visit.number + 1, "open": false}
	if (
		build._format >= 11
		and SeasonSchoolSponsors.qualifies_union(build, command.get("performance", {}))
	):
		build._visit["union_earned"] = true
	return ""
