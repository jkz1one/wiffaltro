class_name SeasonTransfer
extends RefCounted

const ITEMS: Dictionary = {
	"F07":
	{
		"name": "Transfer Station",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Once per shop, exchange two different season-learned pitches on two roster players. "
			+ "Keep each player's personal mastery history. No added pitch, fee or new purchase."
		)
	}
}


static func learners(build: SeasonBuild) -> int:
	var count: int = 0
	for player: String in build.roster():
		if not SeasonPitchExchange.learned(build._book, player).is_empty():
			count += 1
	return count


static func available(build: SeasonBuild) -> bool:
	return (
		build._format >= 25
		and build._market == 0
		and build._visit.open
		and (
			not build._visit.get("transfer_used", false)
			and not SeasonSchoolSponsors.active(build, "F07").is_empty()
		)
	)


static func options(build: SeasonBuild) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var roster: Array[String] = build.roster()
	for a in range(roster.size()):
		for b in range(a + 1, roster.size()):
			for first: String in SeasonPitchExchange.learned(build._book, roster[a]):
				for second: String in SeasonPitchExchange.learned(build._book, roster[b]):
					var row: Dictionary = {
						"player": roster[a], "other": roster[b], "first": first, "second": second
					}
					var cmd: Dictionary = row.duplicate()
					cmd.merge({"id": "preview", "rev": build._book.revision(), "op": "exchange"})
					if build._book.preview(cmd).ok:
						result.append(row)
	return result


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	if not build._keys(command, ["player", "other", "first", "second"]) or not available(build):
		return "An active Transfer Station and unused shop exchange are required."
	if not build.roster().has(command.player) or not build.roster().has(command.other):
		return "Both players must still be on this roster."
	var result: Dictionary = build._book.commit(
		{
			"id": "exchange:%d" % build.revision(),
			"rev": build._book.revision(),
			"op": "exchange",
			"player": command.player,
			"other": command.other,
			"first": command.first,
			"second": command.second
		}
	)
	if not result.ok:
		return result.error
	build._visit["transfer_used"] = true
	return ""
