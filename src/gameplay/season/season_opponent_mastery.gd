class_name SeasonOpponentMastery
extends RefCounted
## Policy4: paid exact primary-fastball growth and five-family development stock.

const FASTBALLS: Array[String] = [
	"pitch.overhand_four_seam", "pitch.overhand_sinker", "pitch.sidearm_sinker"
]


static func primary(build: SeasonBuild, player: String) -> String:
	var profile: Dictionary = build.player(player)
	var candidates: Array[String] = []
	for recipe: String in profile.active:
		if FASTBALLS.has(recipe):
			candidates.append(recipe)
	candidates.sort_custom(func(a: String, b: String) -> bool:
		if profile.mastery[a] != profile.mastery[b]:
			return profile.mastery[a] > profile.mastery[b]
		return a < b)
	return candidates[0] if not candidates.is_empty() else ""


static func offers(build: SeasonBuild, roll: int) -> Dictionary:
	var development: Dictionary = DevelopmentShopCatalog.families(build._book, build.roster())
	var gear: Dictionary = {}
	var owned: Dictionary = build._bank.view().gear
	for id: String in SeasonOpponentGear.INITIAL:
		var slot: String = SeasonGearCatalog.item(id).slot
		if owned[slot].get("item", "") == id:
			continue
		if not gear.has(slot):
			gear[slot] = []
		gear[slot].append(id)
	var weights: Dictionary = {}
	if not development.is_empty():
		weights["development"] = 25.0
	if not gear.is_empty():
		weights["gear"] = 20.0
	var result: Dictionary = {}
	var seen: Array[String] = []
	var rng: RandomNumberGenerator = build._rng(roll)
	for index in range(4):
		var choices: Dictionary = weights.duplicate()
		if index == 3 and seen.size() == 1 and choices.size() > 1:
			choices.erase(seen[0])
		if choices.is_empty():
			break
		var category: String = SeasonGearCatalog._weighted(choices, rng)
		if not seen.has(category):
			seen.append(category)
		var groups: Dictionary = development if category == "development" else gear
		var group: String = groups.keys()[rng.randi_range(0, groups.size() - 1)]
		var pool: Array = groups[group]
		result["visit:%d:roll:%d:%d" % [build._visit.number, roll, index]] = (
			pool[rng.randi_range(0, pool.size() - 1)])
	return result


static func objectives(build: SeasonBuild, club: Dictionary) -> Array[Dictionary]:
	if club.profile != "Pitching / defense":
		return SeasonOpponentPolicy.objectives(build, club)
	var role: Dictionary = club.roles
	var targets: Array = [[role.pitcher, "pitching", 4], [role.pitcher, "mastery", 3],
		[role.fielder, "fielding", 4], [role.secondary, "pitching", 3]]
	var result: Array[Dictionary] = []
	for target: Array in targets:
		var goal: Dictionary = _goal(club, target[0], target[1], -1)
		if _level(build, goal) < target[2] and not cards(build, goal).is_empty():
			result.append(goal)
	if not result.is_empty():
		return result
	for offset in range(targets.size()):
		var index: int = (int(club.cursor) + offset) % targets.size()
		var target: Array = targets[index]
		var goal: Dictionary = _goal(club, target[0], target[1], (index + 1) % targets.size())
		if not cards(build, goal).is_empty():
			result.append(goal)
	return result


static func _goal(club: Dictionary, player: String, stat: String, cursor: int) -> Dictionary:
	return {"player": player, "stat": stat, "pitch": club.primary if stat == "mastery" else "",
		"cursor": cursor}


static func _level(build: SeasonBuild, goal: Dictionary) -> int:
	var profile: Dictionary = build.player(goal.player)
	if goal.stat == "mastery":
		return int(profile.mastery.get(goal.pitch, SeasonDevelopment.PITCH_CAP))
	return int(profile.stats[goal.stat])


static func cards(build: SeasonBuild, goal: Dictionary) -> Array[String]:
	var candidates: Array[String] = ["development." + goal.stat]
	if goal.stat == "mastery":
		candidates.assign(["development.round_out", "development.mastery"])
	var result: Array[String] = []
	for id: String in candidates:
		for target: Dictionary in build.targets(id):
			if target.player == goal.player and target.pitch == goal.get("pitch", ""):
				result.append(id)
				break
	return result


static func checkout(build: SeasonBuild, club: Dictionary, game: int) -> void:
	if not build.commit(SeasonOpponentPolicy.command(build, "open")).ok:
		return
	for step in range(100):
		var goals: Array[Dictionary] = objectives(build, club)
		if _develop(build, club, game, goals) or SeasonOpponentGear._equip(build, club, game):
			continue
		var price: int = useful_price(build, club, goals)
		if (build._visit.rerolls == 0 and price > 0
			and build.cash() >= SeasonReclamation.price(build._visit) + price):
			if build.commit(SeasonOpponentPolicy.command(build, "reroll")).ok:
				continue
		break


static func _develop(build: SeasonBuild, club: Dictionary, game: int,
	goals: Array[Dictionary]) -> bool:
	var families: Dictionary = {}
	for goal: Dictionary in goals:
		for id: String in cards(build, goal):
			families[DevelopmentShopCatalog.item(id).family] = true
			if build.cash() < int(DevelopmentShopCatalog.item(id).price):
				continue
			for offer: String in build._visit.offers:
				if build._visit.offers[offer] == id:
					return purchase(build, club, game, goal, id, "buy",
						{"offer": offer, "mode": "use"})
	if build._visit.pack_status != "sealed" or families.size() < 3 or build.cash() < 8:
		return false
	if not build.commit(SeasonOpponentPolicy.command(build, "pack_open")).ok:
		return false
	for goal: Dictionary in goals:
		for id: String in cards(build, goal):
			if build._visit.cards.has(id):
				return purchase(build, club, game, goal, id, "pack_pick", {"item": id})
	build.commit(SeasonOpponentPolicy.command(build, "pack_skip"))
	return true


static func purchase(build: SeasonBuild, club: Dictionary, game: int, goal: Dictionary,
	id: String, op: String, fields: Dictionary) -> bool:
	fields.merge({"player": goal.player, "pitch": goal.get("pitch", ""), "replace": ""})
	var request: Dictionary = SeasonOpponentPolicy.command(build, op, fields)
	if not build.commit(request).ok:
		return false
	if goal.cursor >= 0:
		club.cursor = goal.cursor
	var decision: Dictionary = {"game": game, "request": request.id, "player": goal.player,
		"stat": goal.stat, "reason": "objective" if goal.cursor < 0 else "rotation",
		"paid": 8 if op == "pack_pick" else int(DevelopmentShopCatalog.item(id).price)}
	if goal.stat == "mastery":
		decision.merge({"item": id, "pitch": goal.pitch, "level": _level(build, goal)})
	club.decisions.append(decision)
	return true


static func useful_price(build: SeasonBuild, club: Dictionary,
	goals: Array[Dictionary]) -> int:
	var result: int = SeasonOpponentGear.useful_price(build, club, [])
	for goal: Dictionary in goals:
		for id: String in cards(build, goal):
			var price: int = DevelopmentShopCatalog.item(id).price
			result = price if result == 0 else mini(result, price)
	return result
