class_name SeasonSponsorCatalog
extends RefCounted
## Versioned initial sponsors. All prices/effects/rarities are Working.
## Active-only ownership is Approved; no AI purchasing or offscreen event fabrication.

const ITEMS: Dictionary = {
	"D01":
	{
		"name": "Take Your Base",
		"price": 8,
		"rarity": "Common",
		"weight": 2.0,
		"effect": "Earn 2 Cash for each of your first two credited walks per completed game, max 4."
	},
	"A08":
	{
		"name": "Shift Crew",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		"Earn 2 Cash for each distinct pitcher's first credited strikeout per completed game, max 8."
	},
	"A09":
	{
		"name": "Highlight Reel",
		"price": 14,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		"Earn 3 Cash for your first credited Double, Triple and Home Run per completed game, max 9."
	}
}

# Keep ITEMS frozen for build6 journals; this pool starts with build7.
const GAMEPLAY_ITEMS: Dictionary = {
	"A07":
	{
		"name": "Neighborhood Deli",
		"price": 14,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"A credited Single gives the next batter +4% fair Contact exit speed in the "
			+ "same half-inning. Singles refresh; walks, outs and extra-base hits end the "
			+ "chain. No Power bonus."
		)
	},
	"B02":
	{
		"name": "Community College",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Each current player with actual club-earned stat growth or mastery reduces "
			+ "natural-delivery pitch workload by 3%, max 12%. Baseline, catch-up, held "
			+ "cards and learning alone do not count."
		)
	}
}


static func catalog(version: int = 2) -> Dictionary:
	var result: Dictionary = ITEMS.duplicate(true)
	if version >= 2:
		result.merge(GAMEPLAY_ITEMS.duplicate(true))
	return result


static func item(id: String) -> Dictionary:
	return catalog().get(id, {})


static func signature(version: int = 2) -> String:
	return JSON.stringify(catalog(version)).sha256_text()


static func ownership_catalog() -> Dictionary:
	var result: Dictionary = SeasonGearCatalog.ownership_catalog()
	for id: String in catalog():
		result[id] = {"kind": "sponsor", "price": item(id).price, "sale": "half"}
	return result


static func eligible(active: Array, version: int = 2) -> Dictionary:
	var result: Dictionary = {}
	var all_items: Dictionary = catalog(version)
	for id: String in all_items:
		result[id] = all_items[id].weight
	for receipt: Dictionary in active:
		result.erase(receipt.item)
	return result


static func earnings(active: Array, roster: Array, performance: Dictionary) -> Dictionary:
	var walks: int = 0
	var pitchers: int = 0
	var types: Dictionary = {}
	for id: String in roster:
		var line: Dictionary = performance.get(id, {})
		walks += int(line.get("bb", 0))
		if int(line.get("p_k", 0)) > 0:
			pitchers += 1
		for kind: String in ["double", "triple", "hr"]:
			if int(line.get(kind, 0)) > 0:
				types[kind] = true
	var amounts: Dictionary = {
		"D01": mini(2, walks) * 2, "A08": mini(4, pitchers) * 2, "A09": types.size() * 3
	}
	var result: Dictionary = {}
	for receipt: Dictionary in active:
		if ITEMS.has(receipt.item):
			result[receipt.item] = amounts[receipt.item]
	return result
