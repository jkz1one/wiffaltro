class_name SeasonOpponentLessons
extends RefCounted
## Policy5 / market4: five paid Common lessons, bounded secondary-slider buying.

const RECIPES: Array[String] = [
	"pitch.overhand_four_seam", "pitch.overhand_sinker", "pitch.sidearm_sinker",
	"pitch.overhand_slider", "pitch.sidearm_slider"
]


static func pool(build: SeasonBuild) -> Array[String]:
	var result: Array[String] = []
	for recipe: String in RECIPES:
		var id: String = "lesson." + recipe
		if not build.targets(id).is_empty():
			result.append(id)
	return result


static func offers(build: SeasonBuild, roll: int) -> Dictionary:
	var development: Dictionary = DevelopmentShopCatalog.families(build._book, build.roster())
	var lessons: Array[String] = pool(build)
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
	if not lessons.is_empty():
		weights["lesson"] = 12.0
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
		var id: String
		if category == "lesson":
			id = lessons[rng.randi_range(0, lessons.size() - 1)]
		else:
			var groups: Dictionary = development if category == "development" else gear
			var group: String = groups.keys()[rng.randi_range(0, groups.size() - 1)]
			var variants: Array = groups[group]
			id = variants[rng.randi_range(0, variants.size() - 1)]
		result["visit:%d:roll:%d:%d" % [build._visit.number, roll, index]] = id
	return result


static func target(build: SeasonBuild, club: Dictionary) -> Dictionary:
	if club.profile not in ["Distributed", "Pitching / defense"]:
		return {}
	var player: String = club.roles.secondary
	if not build.roster().has(player):
		return {}
	var definition: PlayerDefinition = ContentDB.get_player(StringName(player))
	if definition.natural_delivery == null:
		return {}
	var recipe: String
	match definition.natural_delivery.id:
		&"delivery.overhand": recipe = "pitch.overhand_slider"
		&"delivery.sidearm": recipe = "pitch.sidearm_slider"
		_: return {}
	var id: String = "lesson." + recipe
	var destination: Dictionary = {"player": player, "pitch": "", "replace": ""}
	# Stock eligibility remains shared; this first buying policy never forgets a pitch.
	return ({"player": player, "pitch": recipe, "item": id}
		if build.targets(id).has(destination) else {})


static func purchase(build: SeasonBuild, club: Dictionary, game: int) -> bool:
	var goal: Dictionary = target(build, club)
	if goal.is_empty():
		return false
	var price: int = DevelopmentShopCatalog.item(goal.item).price
	if build.cash() < price:
		return false
	for offer: String in build._visit.offers:
		if build._visit.offers[offer] != goal.item:
			continue
		var request: Dictionary = SeasonOpponentPolicy.command(build, "buy", {
			"offer": offer, "mode": "use", "player": goal.player, "pitch": "", "replace": ""})
		if not build.commit(request).ok:
			return false
		club.decisions.append({"game": game, "request": request.id, "player": goal.player,
			"stat": "lesson", "item": goal.item, "pitch": goal.pitch,
			"level": build.player(goal.player).mastery[goal.pitch], "paid": price,
			"reason": "secondary slider"})
		return true
	return false


static func checkout(build: SeasonBuild, club: Dictionary, game: int) -> void:
	if not build.commit(SeasonOpponentPolicy.command(build, "open")).ok:
		return
	for step in range(100):
		var goals: Array[Dictionary] = SeasonOpponentMastery.objectives(build, club)
		if (SeasonOpponentMastery._develop(build, club, game, goals)
			or SeasonOpponentGear._equip(build, club, game) or purchase(build, club, game)):
			continue
		var price: int = SeasonOpponentMastery.useful_price(build, club, goals)
		var lesson: Dictionary = target(build, club)
		if not lesson.is_empty():
			var lesson_price: int = DevelopmentShopCatalog.item(lesson.item).price
			price = lesson_price if price == 0 else mini(price, lesson_price)
		if (build._visit.rerolls == 0 and price > 0
			and build.cash() >= SeasonReclamation.price(build._visit) + price):
			if build.commit(SeasonOpponentPolicy.command(build, "reroll")).ok:
				continue
		break
