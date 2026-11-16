class_name SeasonOpponentGear
extends RefCounted
## Economy24 supported subset: four stat families plus thirteen initial passive Gear.

const INITIAL: Array[String] = [
	"BAT-CON-01", "BAT-POW-01", "A02", "BALL-MOV-01", "BALL-VEL-01", "BALL-HYB-01",
	"A04", "D02", "MISC-FLD-01", "MISC-FLD-02", "MISC-PIT-03", "MISC-BAT-01", "MISC-FLD-03"
]
const PREFERENCES: Dictionary = {
	"Distributed": ["BAT-CON-01", "BALL-MOV-01", "MISC-FLD-02"],
	"Featured hitter": ["BAT-POW-01", "MISC-BAT-01", "BALL-VEL-01"],
	"Pitching / defense": ["BALL-MOV-01", "MISC-PIT-03"]
}


static func offers(build: SeasonBuild, roll: int) -> Dictionary:
	var development: Array[String] = SeasonOpponentMarket.cards(build)
	var gear: Dictionary = {}
	var owned: Dictionary = build._bank.view().gear
	for id: String in INITIAL:
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
		var pool: Array = development
		if category == "gear":
			var slot: String = gear.keys()[rng.randi_range(0, gear.size() - 1)]
			pool = gear[slot]
		result["visit:%d:roll:%d:%d" % [build._visit.number, roll, index]] = (
			pool[rng.randi_range(0, pool.size() - 1)])
	return result


static func checkout(build: SeasonBuild, club: Dictionary, game: int) -> void:
	if not build.commit(SeasonOpponentPolicy.command(build, "open")).ok:
		return
	for step in range(100):
		var goals: Array[Dictionary] = SeasonOpponentPolicy.objectives(build, club)
		if _develop(build, club, game, goals) or _equip(build, club, game):
			continue
		var price: int = useful_price(build, club, goals)
		if (build._visit.rerolls == 0 and price > 0
			and build.cash() >= SeasonReclamation.price(build._visit) + price):
			if build.commit(SeasonOpponentPolicy.command(build, "reroll")).ok:
				continue
		break


static func _develop(build: SeasonBuild, club: Dictionary, game: int,
	goals: Array[Dictionary]) -> bool:
	for goal: Dictionary in goals:
		for offer: String in build._visit.offers:
			if build._visit.offers[offer] == "development." + goal.stat and build.cash() >= 6:
				return SeasonOpponentPolicy.purchase(
					build, club, game, goal, "buy", {"offer": offer, "mode": "use"})
	var families: Dictionary = {}
	for goal: Dictionary in goals:
		families[goal.stat] = true
	if build._visit.pack_status != "sealed" or families.size() < 3 or build.cash() < 8:
		return false
	if not build.commit(SeasonOpponentPolicy.command(build, "pack_open")).ok:
		return false
	for goal: Dictionary in goals:
		var id: String = "development." + goal.stat
		if build._visit.cards.has(id):
			return SeasonOpponentPolicy.purchase(build, club, game, goal, "pack_pick", {"item": id})
	build.commit(SeasonOpponentPolicy.command(build, "pack_skip"))
	return true


static func _equip(build: SeasonBuild, club: Dictionary, game: int) -> bool:
	for id: String in PREFERENCES[club.profile]:
		var item: Dictionary = SeasonGearCatalog.item(id)
		if not build._bank.view().gear[item.slot].is_empty() or build.cash() < int(item.price):
			continue
		for offer: String in build._visit.offers:
			if build._visit.offers[offer] != id:
				continue
			var request: Dictionary = SeasonOpponentPolicy.command(
				build, "equip", {"offer": offer, "replace": ""})
			if not build.commit(request).ok:
				return false
			club.decisions.append({"game": game, "request": request.id, "player": "",
				"stat": "gear", "item": id, "reason": "slot preference", "paid": int(item.price)})
			return true
	return false


static func useful_price(build: SeasonBuild, club: Dictionary,
	goals: Array[Dictionary]) -> int:
	# Current eligibility/empty slots only; never inspect a future roll or concealed pack.
	var result: int = 0
	if not goals.is_empty():
		result = 6
	for id: String in PREFERENCES[club.profile]:
		var item: Dictionary = SeasonGearCatalog.item(id)
		if build._bank.view().gear[item.slot].is_empty():
			result = int(item.price) if result == 0 else mini(result, int(item.price))
	return result
