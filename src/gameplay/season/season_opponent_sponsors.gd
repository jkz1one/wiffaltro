class_name SeasonOpponentSponsors
extends RefCounted
## Policy7/8: four automatic plus two explicit-choice sponsors, paid shared effects.

const ITEMS: Array[String] = ["D01", "A07", "B02", "B03"]


static func offers(build: SeasonBuild, roll: int) -> Dictionary:
	var development: Dictionary = DevelopmentShopCatalog.families(build._book, build.roster())
	var lessons: Array[String] = SeasonOpponentLessons.pool(build)
	var abilities: Dictionary = build._abilities.pool(build)
	var sponsors: Dictionary = pool(build)
	var tactics: Dictionary = (SeasonOpponentTactics.pool(build._market)
		if build._market in [8, 9, 10] else {})
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
	if not sponsors.is_empty():
		weights["sponsor"] = 20.0
	if not tactics.is_empty():
		weights["tactical"] = 10.0
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
		if category == "sponsor":
			id = SeasonGearCatalog._weighted(sponsors, rng)
		elif category == "tactical":
			id = SeasonGearCatalog._weighted(tactics, rng)
		elif category == "ability":
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


static func pool(build: SeasonBuild) -> Dictionary:
	var result: Dictionary = {}
	var items: Array[String] = ITEMS.duplicate()
	if build._market in [7, 8, 9, 10]:
		items.append_array(["F01", "F03"])
	for id: String in items:
		result[id] = SeasonSponsorCatalog.item(id).weight
	for receipt: Dictionary in build._bank.view().sponsors:
		result.erase(receipt.item)
	return result


static func history(build: SeasonBuild) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in build.to_data().events:
		if event.op == "reward":
			result.append(event)
	return result


static func qualifies(build: SeasonBuild, club: Dictionary, item: String) -> bool:
	var games: Array[Dictionary] = history(build)
	if build._market in [7, 8, 9, 10] and item in ["F01", "F03"]:
		return true
	if item == "B02":
		return not build._book.earned_players(build.roster()).is_empty()
	if item == "B03":
		return build.definition(club.roles.pitcher).starting_pitches.size() >= 3
	if item == "A07":
		if games.is_empty():
			return false
		var singles: int = 0
		for id: String in build.roster():
			var line: Dictionary = games[-1].get("performance", {}).get(id, {})
			singles += int(line.get("h", 0)) - int(line.get("double", 0)) \
				- int(line.get("triple", 0)) - int(line.get("hr", 0))
		return singles >= 2
	if item != "D01":
		return false
	var regular: int = 0
	for game: Dictionary in games:
		regular += 1 if int(game.game) < 30 else 0
	if regular > 7:
		return false # At least three scheduled regular games remain; playoffs never qualify.
	for game: Dictionary in games.slice(maxi(0, games.size() - 2)):
		for id: String in build.roster():
			if int(game.get("performance", {}).get(id, {}).get("bb", 0)) > 0:
				return true
	return false


static func targets(build: SeasonBuild, club: Dictionary) -> Array[String]:
	if build._bank.view().sponsors.size() >= 5:
		return [] # No replacements, capacity sponsors or reserves in this policy.
	var preferred: Array[String] = ["D01"]
	if club.profile == "Featured hitter":
		preferred.push_front("A07")
	elif club.profile == "Pitching / defense":
		preferred.assign(["B02", "B03", "D01"])
	if build._market in [7, 8, 9, 10]:
		if club.profile == "Featured hitter":
			preferred.assign(["A07", "F03", "D01"])
		elif club.profile == "Pitching / defense":
			preferred.assign(["B02", "B03", "F01", "D01"])
		else:
			preferred.push_front("F03")
	var result: Array[String] = []
	for id: String in preferred:
		if pool(build).has(id) and qualifies(build, club, id):
			result.append(id)
	return result


static func purchase(build: SeasonBuild, club: Dictionary, game: int) -> bool:
	for item: String in targets(build, club):
		var price: int = SeasonSponsorCatalog.item(item).price
		if build.cash() < price:
			continue
		for offer: String in build._visit.offers:
			if build._visit.offers[offer] != item:
				continue
			var request: Dictionary = SeasonOpponentPolicy.command(build, "sponsor_buy", {
				"offer": offer, "replace": ""})
			if not build.commit(request).ok:
				return false
			club.decisions.append({"game": game, "request": request.id, "player": "",
				"stat": "sponsor", "item": item, "paid": price, "reason": "qualified team sponsor"})
			return true
	return false


static func checkout(build: SeasonBuild, club: Dictionary, game: int) -> void:
	if not build.commit(SeasonOpponentPolicy.command(build, "open")).ok:
		return
	for step in range(100):
		var goals: Array[Dictionary] = SeasonOpponentMastery.objectives(build, club)
		if (SeasonOpponentMastery._develop(build, club, game, goals)
			or SeasonOpponentGear._equip(build, club, game) or purchase(build, club, game)
			or SeasonOpponentAbilities.purchase(build, club, game)
			or SeasonOpponentLessons.purchase(build, club, game)
			or SeasonOpponentTactics.purchase(build, club, game)):
			continue
		var price: int = SeasonOpponentAbilities.useful_price(build, club, goals)
		for item: String in targets(build, club):
			var sponsor_price: int = SeasonSponsorCatalog.item(item).price
			price = sponsor_price if price == 0 else mini(price, sponsor_price)
		var tactical_price: int = SeasonOpponentTactics.useful_price(build)
		if tactical_price > 0:
			price = tactical_price if price == 0 else mini(price, tactical_price)
		if (build._visit.rerolls == 0 and price > 0
			and build.cash() >= SeasonReclamation.price(build._visit) + price):
			if build.commit(SeasonOpponentPolicy.command(build, "reroll")).ok:
				continue
		break
