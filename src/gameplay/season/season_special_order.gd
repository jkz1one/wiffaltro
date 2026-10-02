class_name SeasonSpecialOrder
extends RefCounted
## Working v18 contract. Category selection never reveals the next stock before payment.

const ITEMS: Dictionary = {
	"J01":
	{
		"name": "Special Order Supply",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Once per shop, pay the ordinary reroll price to focus one eligible non-development "
			+ "category. No duplicates; small pools leave unavailable slots. "
			+ "Pack and recruiting stay fixed."
		)
	}
}
const CATEGORIES: Dictionary = {
	"gear": "Gear",
	"sponsor": "Sponsors",
	"ability": "Learned Abilities",
	"lesson": "Pitch Lessons",
	"tactical": "Tactical Supplies",
	"transformation": "Transformations"
}


static func pool(build: SeasonBuild, category: String) -> Dictionary:
	var result: Dictionary = {}
	match category:
		"gear":
			var slots: Dictionary = SeasonGearCatalog.eligible(
				build.view().wallet.gear, 3, build._gear_progress.eligible(build._format >= 41)
			)
			for ids: Array in slots.values():
				for id: String in ids:
					result[id] = 1.0 / (slots.size() * ids.size())
		"sponsor":
			result = SeasonEarnedSponsors.eligible(build)
		"lesson":
			for recipe: String in DevelopmentShopCatalog.LESSON_PRICES:
				var id: String = "lesson." + recipe
				if not build.targets(id).is_empty():
					result[id] = 1.0
		"tactical":
			result = SeasonTacticalCatalog.weights(build._tactical_catalog_version())
		"transformation":
			result = SeasonRetraining.pool(build)
		"ability":
			if build._format >= 39:
				result = build._abilities.pool(build)
	return result


static func available(build: SeasonBuild) -> bool:
	return (
		build._format >= 23
		and build._market == 0
		and build._visit.open
		and not build._visit.get("focused_used", false)
		and not SeasonSchoolSponsors.active(build, "J01").is_empty()
	)


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	if not build._keys(command, ["category"]) or not command.category is String:
		return "Choose one exact supported category."
	if not available(build):
		return "Special Order requires an active copy and an unused focused reroll this visit."
	var candidates: Dictionary = pool(build, command.category)
	var protected: Dictionary = SeasonRaincheck.protected_offer(build)
	for id: String in protected.values():
		candidates.erase(id)
	if candidates.is_empty():
		return "This category has no eligible items."
	var price: int = SeasonReclamation.price(build._visit)
	var error: String = build._charge(price)
	if not error.is_empty():
		return error
	build._visit.rerolls += 1
	build._visit["reroll_credit"] = 0
	build._visit["focused_used"] = true
	build._visit["focused_category"] = command.category
	var rng: RandomNumberGenerator = build._rng(build._visit.rerolls)
	var offers: Dictionary = protected.duplicate()
	for index in range(mini(4 - protected.size(), candidates.size())):
		# Gear preserves equal slot weighting after each identity is removed.
		if command.category == "gear":
			var counts: Dictionary = {}
			for id: String in candidates:
				var slot: String = SeasonGearCatalog.item(id).slot
				counts[slot] = int(counts.get(slot, 0)) + 1
			for id: String in candidates:
				candidates[id] = 1.0 / (counts.size() * counts[SeasonGearCatalog.item(id).slot])
		var selected: String = SeasonGearCatalog._weighted(candidates, rng)
		offers["visit:%d:roll:%d:%d" % [build._visit.number, build._visit.rerolls, index]] = selected
		candidates.erase(selected)
	build._visit.offers = offers
	build._visit["unavailable_slots"] = 4 - offers.size()
	return ""
