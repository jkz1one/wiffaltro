class_name SeasonSponsorCatalog
extends RefCounted
## First three supported initial sponsors. All prices/effects/rarities are Working.
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


static func signature() -> String:
	return JSON.stringify(ITEMS).sha256_text()


static func ownership_catalog() -> Dictionary:
	var result: Dictionary = SeasonGearCatalog.ownership_catalog()
	for id: String in ITEMS:
		result[id] = {"kind": "sponsor", "price": ITEMS[id].price, "sale": "half"}
	return result


static func eligible(active: Array) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ITEMS:
		result[id] = ITEMS[id].weight
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
