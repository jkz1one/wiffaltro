class_name SeasonRetraining
extends RefCounted
# gdlint: disable=max-returns
## B05 Working immediate purchase. ED earned-only provenance remains a testing proposal.

const ID: String = "transformation.B05"
const ITEM: Dictionary = {
	"name": "Retraining Camp",
	"price": 8,
	"rarity": "Uncommon",
	"effect": "Move exactly two trained stat points within one player. No new points or mastery.",
	"status": "Working • earned-only provenance proposal"
}


static func points(book: SeasonDevelopment, player: String = "") -> Dictionary:
	var result: Dictionary = {"contact": 0, "power": 0, "fielding": 0, "pitching": 0}
	for event: Dictionary in book._events:
		if not player.is_empty() and event.player != player:
			continue
		if event.op == "stat":
			result[event.target] += 1
		elif event.op == "retrain":
			for stat: String in event.remove:
				result[stat] -= 1
			for stat: String in event.add:
				result[stat] += 1
	return result


static func count(book: SeasonDevelopment) -> int:
	var total: int = 0
	for value: int in points(book).values():
		total += value
	return total


static func prepare(book: SeasonDevelopment, command: Dictionary) -> Dictionary:
	if not SeasonOwnership._keys(command, ["id", "rev", "op", "player", "remove", "add"]):
		return SeasonDevelopment._error("Choose one player and exactly two removals and additions.")
	for key: String in ["remove", "add"]:
		if not command[key] is Array or command[key].size() != 2:
			return SeasonDevelopment._error("Move exactly two points.")
		for stat: Variant in command[key]:
			if not stat is String or not SeasonPlayerCatalog.STATS.has(stat):
				return SeasonDevelopment._error(
					"Only Contact, Power, Fielding and Pitching can move."
				)
	var available: Dictionary = points(book, command.player)
	var after: Dictionary = book.player(command.player)
	if not _legal(after, available, command.remove, command.add):
		return SeasonDevelopment._error(
			"Keep baseline/catch-up points, disjoint stats and the level-10 cap."
		)
	for stat: String in command.remove:
		after.stats[stat] -= 1
	for stat: String in command.add:
		after.stats[stat] += 1
	return {"ok": true, "replayed": false, "after": after}


static func targets(build: SeasonBuild) -> Array[String]:
	var result: Array[String] = []
	for player: String in build.roster():
		if not choices(build._book, player).is_empty():
			result.append(player)
	return result


static func choices(book: SeasonDevelopment, player: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var profile: Dictionary = book.player(player)
	var available: Dictionary = points(book, player)
	var pairs: Array[Array] = []
	for first in range(4):
		for second in range(first, 4):
			pairs.append([SeasonPlayerCatalog.STATS[first], SeasonPlayerCatalog.STATS[second]])
	for remove: Array in pairs:
		for add: Array in pairs:
			if _legal(profile, available, remove, add):
				result.append({"remove": remove.duplicate(), "add": add.duplicate()})
	return result


static func _legal(profile: Dictionary, available: Dictionary, remove: Array, add: Array) -> bool:
	if profile.is_empty():
		return false
	for stat: String in remove:
		if add.has(stat) or available[stat] < remove.count(stat):
			return false
	for stat: String in add:
		if profile.stats[stat] + add.count(stat) > SeasonDevelopment.STAT_CAP:
			return false
	return true


static func pool(build: SeasonBuild) -> Dictionary:
	if build._format < 38 or not build._retraining_enabled or build._market != 0:
		return {}
	if count(build._book) < 4 or targets(build).is_empty():
		return {}
	return {ID: 1.0}


static func buy(build: SeasonBuild, command: Dictionary) -> String:
	if not build._keys(command, ["offer", "player", "remove", "add"]):
		return "Review the exact transformation, player and point changes."
	if not command.offer is String or not command.player is String:
		return "Choose an exact offer and current player."
	if build._visit.offers.get(command.offer, "") != ID or not pool(build).has(ID):
		return "Retraining requires four applied training points and a legal current target."
	if not build.roster().has(command.player):
		return "Choose one current roster player."
	var result: Dictionary = build._book.commit(
		{
			"id": "retraining:%d" % build.revision(),
			"rev": build._book.revision(),
			"op": "retrain",
			"player": command.player,
			"remove": command.remove,
			"add": command.add
		}
	)
	if not result.ok:
		return result.error
	var error: String = build._charge(ITEM.price)
	if not error.is_empty():
		return error
	build._visit.offers.erase(command.offer)
	return ""
