class_name SeasonOpponentAbilities
extends RefCounted
## Policy6 / market5: paid learned abilities and prior development/Gear/lesson contracts.


static func offers(build: SeasonBuild, roll: int) -> Dictionary:
	var development: Dictionary = DevelopmentShopCatalog.families(build._book, build.roster())
	var lessons: Array[String] = SeasonOpponentLessons.pool(build)
	var abilities: Dictionary = build._abilities.pool(build)
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
	if not abilities.is_empty():
		weights["ability"] = 10.0
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
		if category == "ability":
			id = SeasonGearCatalog._weighted(abilities, rng)
		elif category == "lesson":
			id = lessons[rng.randi_range(0, lessons.size() - 1)]
		else:
			var groups: Dictionary = development if category == "development" else gear
			var group: String = groups.keys()[rng.randi_range(0, groups.size() - 1)]
			var variants: Array = groups[group]
			id = variants[rng.randi_range(0, variants.size() - 1)]
		result["visit:%d:roll:%d:%d" % [build._visit.number, roll, index]] = id
	return result


static func targets(build: SeasonBuild, club: Dictionary) -> Array[Dictionary]:
	var items: Array[String] = [SeasonAbilities.HANDS]
	var player: String = club.roles.fielder
	if club.profile == "Featured hitter":
		items = [SeasonAbilities.COUNT]
		player = club.roles.hitter
	elif club.profile == "Pitching / defense":
		items.append(SeasonAbilities.SKY)
	var result: Array[Dictionary] = []
	for item: String in items:
		# No replacement or extra Fielding slot. Sky is an alternative to Hands.
		if build._abilities.pool(build).has(item) and build._abilities.targets(build, item).has(
			{"player": player, "replace": ""}):
			result.append({"player": player, "item": item})
	return result


static func purchase(build: SeasonBuild, club: Dictionary, game: int) -> bool:
	for goal: Dictionary in targets(build, club):
		var price: int = SeasonAbilities.ITEMS[goal.item].price
		if build.cash() < price:
			continue
		for offer: String in build._visit.offers:
			if build._visit.offers[offer] != goal.item:
				continue
			var request: Dictionary = SeasonOpponentPolicy.command(build, "ability_buy", {
				"offer": offer, "player": goal.player, "replace": ""})
			if not build.commit(request).ok:
				return false
			club.decisions.append({"game": game, "request": request.id, "player": goal.player,
				"stat": "ability", "item": goal.item, "paid": price, "reason": "learned role"})
			return true
	return false


static func useful_price(build: SeasonBuild, club: Dictionary, goals: Array[Dictionary]) -> int:
	var price: int = SeasonOpponentMastery.useful_price(build, club, goals)
	var lesson: Dictionary = SeasonOpponentLessons.target(build, club)
	if not lesson.is_empty():
		var lesson_price: int = DevelopmentShopCatalog.item(lesson.item).price
		price = lesson_price if price == 0 else mini(price, lesson_price)
	for goal: Dictionary in targets(build, club):
		var ability_price: int = SeasonAbilities.ITEMS[goal.item].price
		price = ability_price if price == 0 else mini(price, ability_price)
	return price


static func checkout(build: SeasonBuild, club: Dictionary, game: int) -> void:
	if not build.commit(SeasonOpponentPolicy.command(build, "open")).ok:
		return
	for step in range(100):
		var goals: Array[Dictionary] = SeasonOpponentMastery.objectives(build, club)
		if (SeasonOpponentMastery._develop(build, club, game, goals)
			or SeasonOpponentGear._equip(build, club, game) or purchase(build, club, game)
			or SeasonOpponentLessons.purchase(build, club, game)):
			continue
		var price: int = useful_price(build, club, goals)
		if (build._visit.rerolls == 0 and price > 0
			and build.cash() >= SeasonReclamation.price(build._visit) + price):
			if build.commit(SeasonOpponentPolicy.command(build, "reroll")).ok:
				continue
		break
