class_name SeasonOpponentPolicy
extends RefCounted
## Bounded paid Working objectives. No access to human purchases or concealed pack cards.

const PROFILES: Array[String] = [
	"", "Distributed", "Featured hitter", "Pitching / defense", "Distributed", "Pitching / defense"
]


static func roles(build: SeasonBuild) -> Dictionary:
	var pitcher: String = ranked(build, "pitching", build.roster())[0]
	var other: Array[String] = build.roster()
	other.erase(pitcher)
	return {
		"hitter": ranked(build, "power", build.roster())[0],
		"pitcher": pitcher,
		"fielder": ranked(build, "fielding", other)[0],
		"secondary": ranked(build, "pitching", other)[0]
	}


static func ranked(build: SeasonBuild, stat: String, ids: Array[String]) -> Array[String]:
	var result: Array[String] = ids.duplicate()
	result.sort_custom(
		func(a: String, b: String) -> bool:
			var first: Dictionary = build.player(a)
			var second: Dictionary = build.player(b)
			if first.stats[stat] != second.stats[stat]:
				return first.stats[stat] > second.stats[stat]
			if stat == "power" and first.stats.contact != second.stats.contact:
				return first.stats.contact > second.stats.contact
			if stat == "pitching":
				var left: int = 0
				var right: int = 0
				for recipe: String in first.active:
					left += int(first.mastery[recipe])
				for recipe: String in second.active:
					right += int(second.mastery[recipe])
				if left != right:
					return left > right
			return a < b
	)
	return result


static func objectives(build: SeasonBuild, club: Dictionary) -> Array[Dictionary]:
	var role: Dictionary = club.roles
	var targets: Array = []
	match club.profile:
		"Distributed":
			targets = [
				[role.hitter, "contact", 3],
				[role.hitter, "power", 3],
				[role.pitcher, "pitching", 3],
				[role.fielder, "fielding", 3]
			]
		"Featured hitter":
			targets = [[role.hitter, "contact", 4], [role.hitter, "power", 6]]
		_:
			targets = [
				[role.pitcher, "pitching", 4],
				[role.fielder, "fielding", 4],
				[role.secondary, "pitching", 3]
			]
	var result: Array[Dictionary] = []
	for target: Array in targets:
		if build.player(target[0]).stats[target[1]] < target[2]:
			result.append({"player": target[0], "stat": target[1], "cursor": -1})
	if not result.is_empty():
		return result
	var rotation: Array = []
	if club.profile == "Featured hitter":
		rotation = [[role.hitter, "power"], [role.hitter, "power"], [role.hitter, "contact"]]
	elif club.profile == "Pitching / defense":
		rotation = [
			[role.pitcher, "pitching"], [role.fielder, "fielding"], [role.secondary, "pitching"]
		]
	else:
		for stat: String in ["contact", "power", "pitching", "fielding"]:
			var eligible: Array[String] = build.roster()
			if stat == "pitching":
				eligible.assign([role.pitcher, role.secondary])
			elif stat == "fielding":
				eligible.assign([role.fielder])
			eligible.sort_custom(
				func(a: String, b: String) -> bool:
					var left: int = build.player(a).stats[stat]
					var right: int = build.player(b).stats[stat]
					return left < right if left != right else a < b
			)
			rotation.append([eligible[0], stat])
	for offset in range(rotation.size()):
		var index: int = (int(club.cursor) + offset) % rotation.size()
		var target: Array = rotation[index]
		if build.player(target[0]).stats[target[1]] < SeasonDevelopment.STAT_CAP:
			result.append(
				{"player": target[0], "stat": target[1], "cursor": (index + 1) % rotation.size()}
			)
	return result


static func command(build: SeasonBuild, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id": "ai:%d" % build.revision(), "rev": build.revision(), "op": op}
	result.merge(fields)
	return result


static func checkout(build: SeasonBuild, club: Dictionary, game: int) -> void:
	if build._market == 5:
		SeasonOpponentAbilities.checkout(build, club, game)
		return
	if build._market == 4:
		SeasonOpponentLessons.checkout(build, club, game)
		return
	if build._market == 3:
		SeasonOpponentMastery.checkout(build, club, game)
		return
	if build._market == 2:
		SeasonOpponentGear.checkout(build, club, game)
		return
	if not build.commit(command(build, "open")).ok:
		return
	for step in range(100):
		var goals: Array[Dictionary] = objectives(build, club)
		if goals.is_empty():
			break
		var bought: bool = false
		for goal: Dictionary in goals:
			for offer: String in build._visit.offers:
				if build._visit.offers[offer] == "development." + goal.stat and build.cash() >= 6:
					bought = purchase(
						build, club, game, goal, "buy", {"offer": offer, "mode": "use"}
					)
					break
			if bought:
				break
		if bought:
			continue
		var families: Dictionary = {}
		for goal: Dictionary in goals:
			families[goal.stat] = true
		if build._visit.pack_status == "sealed" and families.size() >= 3 and build.cash() >= 8:
			if not build.commit(command(build, "pack_open")).ok:
				break
			for goal: Dictionary in goals:
				var id: String = "development." + goal.stat
				if build._visit.cards.has(id):
					bought = purchase(build, club, game, goal, "pack_pick", {"item": id})
					break
			if not bought:
				build.commit(command(build, "pack_skip"))
			continue
		# No preview of next stock. After paying, at least one useful 6-Cash card is affordable.
		if build._visit.rerolls == 0 and build.cash() >= SeasonReclamation.price(build._visit) + 6:
			if build.commit(command(build, "reroll")).ok:
				continue
		break


static func purchase(
	build: SeasonBuild,
	club: Dictionary,
	game: int,
	goal: Dictionary,
	op: String,
	fields: Dictionary
) -> bool:
	fields.merge({"player": goal.player, "pitch": "", "replace": ""})
	var request: Dictionary = command(build, op, fields)
	if not build.commit(request).ok:
		return false
	if goal.cursor >= 0:
		club.cursor = goal.cursor
	club.decisions.append(
		{
			"game": game,
			"request": request.id,
			"player": goal.player,
			"stat": goal.stat,
			"reason": "objective" if goal.cursor < 0 else "rotation",
			"paid": 8 if op == "pack_pick" else 6
		}
	)
	return true
