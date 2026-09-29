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

# Frozen third generation; build8 adds ordered-sequence recovery.
const SEQUENCE_ITEMS: Dictionary = {
	"B03":
	{
		"name": "Strikecraft",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"A strikeout after three distinct pitches by its credited pitcher refunds 25% "
			+ "of the actual costs of their first three distinct pitches in that plate "
			+ "appearance, max 6 stamina. Twice per team per game, including extras."
		)
	}
}

const FIELD_ITEMS: Dictionary = {
	"F02":
	{
		"name": "Express Courier",
		"price": 8,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Clean airborne catches reduce tag-return gather time by 25%. "
			+ "Your Primary Fielder loses 0.08 ground-control margin, even with bases empty. "
			+ "Pitcher ground control, throw speed and tag eligibility stay unchanged."
		)
	},
	"F03":
	{
		"name": "Split Decision Optics",
		"price": 10,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Before each at-bat choose normal, wide or tall Contact coverage. "
			+ "Wide multiplies width by 1.10 and height by 0.90; tall reverses them. "
			+ "Locked through the at-bat. Power and timing stay unchanged; ordinary Contact "
			+ "quality still determines exit speed."
		)
	},
	"G04":
	{
		"name": "Trackside Trainers",
		"price": 8,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Your runners take 12% less time on legal second-to-third and third-to-home "
			+ "tags after airborne catches. No first-to-second tags, groundout advancement "
			+ "or hit/walk bonus. Ordinary safety margin and third-out rules still apply."
		)
	}
}

const SHOP_ITEMS: Dictionary = {
	"F05":
	{
		"name": "Reclamation Station",
		"price": 6,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"First sale or replacement of paid Gear used from first pitch through a completed game "
			+ "earns 2 reroll credit per visit, plus ordinary resale. Credit is not Cash, "
			+ "cannot fund purchases, and expires on leaving. Selling this sponsor does not renew the limit."
		)
	}
}

const SCHOOL_ITEMS: Dictionary = {
	"E06":
	{
		"name": "Union Hall",
		"price": 10,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Three distinct club hitters in a completed game earn one 3-credit discount next eligible shop. "
			+ "Unapproved Proposal: one loose development card (held or used), including mastery, "
			+ "or fixed pack. "
			+ "Consumed at purchase, not later use. Not Cash; expires on leaving; "
			+ "no stacking with Summer School."
		)
	},
	"F04":
	{
		"name": "Open Book Tutors",
		"price": 10,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Once per visit, teach one offered non-Exotic lesson to two distinct eligible players. "
			+ "Pay its price plus half rounded up. Preview both replacements; each retains "
			+ "their own remembered mastery."
		)
	},
	"J10":
	{
		"name": "Summer School Scholarships",
		"price": 6,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Fix one student at purchase. Their next three immediate broad-stat purchases cost 4 less; "
			+ "then retire, or retire on departure. Always 0 resale. No packs, holds, mastery or lessons. "
			+ "Unapproved Proposal: no earned stats/mastery or generated catch-up at nomination. "
			+ "Never stacks with Union."
		)
	}
}

const ANCHOR_ITEMS: Dictionary = {
	"F01":
	{
		"name": "Cornerstone Concrete",
		"price": 10,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Before an opposing plate appearance, choose normal or anchor the Primary Fielder. "
			+ "On fair contact, anchored Primary cannot travel and gains +0.12 control margin "
			+ "only after normal reaction, within ordinary reach/height and with nonnegative "
			+ "reaction margin. Position locks through that PA; resets next batter. "
			+ "Pitcher and foul pursuit unchanged."
		)
	}
}

const WHOLESALE_ITEMS: Dictionary = {
	"J02":
	{
		"name": "Wholesale Club",
		"price": 8,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Once per visit, buy two same-category offers together. Cheaper item gets "
			+ "25% off rounded down, max 4; choose discounted item on ties. Gear uses distinct "
			+ "slots with explicit replacements; lessons need legal learners. No development, "
			+ "packs, recruits, other concessions or reserves. Actual paid receipts set resale."
		)
	}
}


static func catalog(version: int = 8) -> Dictionary:
	var result: Dictionary = ITEMS.duplicate(true)
	if version >= 2:
		result.merge(GAMEPLAY_ITEMS.duplicate(true))
	if version >= 3:
		result.merge(SEQUENCE_ITEMS.duplicate(true))
	if version >= 4:
		result.merge(FIELD_ITEMS.duplicate(true))
	if version >= 5:
		result.merge(SHOP_ITEMS.duplicate(true))
	if version >= 6:
		result.merge(SCHOOL_ITEMS.duplicate(true))
	if version >= 7:
		result.merge(ANCHOR_ITEMS.duplicate(true))
	if version >= 8:
		result.merge(WHOLESALE_ITEMS.duplicate(true))
	return result


static func item(id: String) -> Dictionary:
	return catalog().get(id, {})


static func signature(version: int = 8) -> String:
	return JSON.stringify(catalog(version)).sha256_text()


static func ownership_catalog() -> Dictionary:
	var result: Dictionary = SeasonGearCatalog.ownership_catalog()
	for id: String in catalog():
		result[id] = {
			"kind": "sponsor", "price": item(id).price, "sale": "zero" if id == "J10" else "half"
		}
	return result


static func eligible(active: Array, version: int = 8) -> Dictionary:
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


static func resale(receipt: Dictionary) -> int:
	return 0 if receipt.item == "J10" else floori(float(receipt.paid) / 2.0)
