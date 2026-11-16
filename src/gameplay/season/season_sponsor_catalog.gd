class_name SeasonSponsorCatalog
extends RefCounted
## Versioned initial sponsors. All prices/effects/rarities are Working.
## Active-only ownership is Approved; AI markets6/7 enable only their supported contracts.

const D3_RULE: String = "standard-d3-nonrefundable-v1"
const D4_RULE: String = "standard-d4-short-term-v1"
const D4_DURATION: int = 2
const D3_ITEMS: Array[String] = ["A07", "B02", "B03", "F01", "F03"]

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

const TACTICAL_ITEMS: Dictionary = {
	"E07":
	{
		"name": "Double Booking",
		"price": 18,
		"rarity": "Rare",
		"weight": 0.25,
		"effect":
		(
			"Once per game, combine one owned Grip Tape and Swing Plan before an offensive PA. "
			+ "Consumes both copies together. Lock Contact or Power; retain both tradeoffs. "
			+ "No other pair. Working contract; compatibility remains a testing Proposal."
		)
	},
	"J07":
	{
		"name": "Pick & Mix Market",
		"price": 8,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Once per shop, exchange one held Tape, Plan, Recovery or Heat for a different one. "
			+ "Pay only an upward list-price difference; no refund trading down. "
			+ "Same slot; no Take a Base or development. "
			+ "Working contract; compatibility is a testing Proposal."
		)
	}
}

const BUDGET_ITEMS: Dictionary = {
	"E08":
	{
		"name": "Budget Bites",
		"price": 10,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"At your first successful Play Game commitment, Cash of 4 or less grants one "
			+ "Swing Plan if the shared bag has room. Once per scheduled game, including a failed "
			+ "capacity check. Unused Plan carries; no overflow, delayed grant or restart farming. "
			+ "Working contract; named-card compatibility remains a testing Proposal."
		)
	}
}

const FILM_ITEMS: Dictionary = {
	"J08":
	{
		"name": "Film Room Video",
		"price": 8,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Choose one exact opposing starter recipe before Play Game. At actual release, "
			+ "identify that recipe, including from relievers. Locked for the game; no location, "
			+ "trajectory or accuracy bonus. Working information contract."
		)
	}
}


static func catalog(version: int = 11) -> Dictionary:
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
	if version >= 9:
		result.merge(TACTICAL_ITEMS.duplicate(true))
	if version >= 10:
		result.merge(BUDGET_ITEMS.duplicate(true))
	if version >= 11:
		result.merge(FILM_ITEMS.duplicate(true))
	return result


static func item(id: String) -> Dictionary:
	if SeasonDoubleMajor.ITEMS.has(id):
		return SeasonDoubleMajor.ITEMS[id].duplicate(true)
	if SeasonSmallBatch.ITEMS.has(id):
		return SeasonSmallBatch.ITEMS[id].duplicate(true)
	if SeasonCarbonCopy.ITEMS.has(id):
		return SeasonCarbonCopy.ITEMS[id].duplicate(true)
	if SeasonFieldSupply.ITEMS.has(id):
		return SeasonFieldSupply.ITEMS[id].duplicate(true)
	if SeasonSureShot.ITEMS.has(id):
		return SeasonSureShot.ITEMS[id].duplicate(true)
	if SeasonJumpstart.ITEMS.has(id):
		return SeasonJumpstart.ITEMS[id].duplicate(true)
	if SeasonLeftRight.ITEMS.has(id):
		return SeasonLeftRight.ITEMS[id].duplicate(true)
	if SeasonFreezers.ITEMS.has(id):
		return SeasonFreezers.ITEMS[id].duplicate(true)
	if SeasonAssociation.ITEMS.has(id):
		return SeasonAssociation.ITEMS[id].duplicate(true)
	if SeasonLateCheckout.ITEMS.has(id):
		return SeasonLateCheckout.ITEMS[id].duplicate(true)
	return (
		catalog()
		. get(
			id,
			SeasonEarnedSponsors.ITEMS.get(
				id,
				SeasonSpecialOrder.ITEMS.get(
					id,
					SeasonRaincheck.ITEMS.get(
						id, SeasonTransfer.ITEMS.get(id, SeasonSecondChance.ITEMS.get(id, {}))
					)
				)
			)
		)
		. duplicate(true)
	)


static func signature(version: int = 11) -> String:
	return JSON.stringify(catalog(version)).sha256_text()


static func ownership_catalog() -> Dictionary:
	var result: Dictionary = SeasonGearCatalog.ownership_catalog()
	var all_items: Dictionary = catalog()
	all_items.merge(SeasonEarnedSponsors.ITEMS)
	all_items.merge(SeasonSpecialOrder.ITEMS)
	all_items.merge(SeasonRaincheck.ITEMS)
	all_items.merge(SeasonTransfer.ITEMS)
	all_items.merge(SeasonSecondChance.ITEMS)
	all_items.merge(SeasonLateCheckout.ITEMS)
	all_items.merge(SeasonAssociation.ITEMS)
	all_items.merge(SeasonFreezers.ITEMS)
	all_items.merge(SeasonLeftRight.ITEMS)
	all_items.merge(SeasonCarbonCopy.ITEMS)
	all_items.merge(SeasonFieldSupply.ITEMS)
	all_items.merge(SeasonSureShot.ITEMS)
	all_items.merge(SeasonJumpstart.ITEMS)
	all_items.merge(SeasonDoubleMajor.ITEMS)
	all_items.merge(SeasonSmallBatch.ITEMS)
	for id: String in all_items:
		var definition: Dictionary = item(id)
		result[id] = {
			"kind": "sponsor",
			"price": definition.price,
			"sale": "zero" if id == "J10" else "half",
			"rarity": definition.rarity
		}
	result.J05.merge({"sponsor_delta": 2, "peer_rarity": "Common"})
	result.G02.merge({"held_delta": 1, "sponsor_cap": 3})
	result.F09.merge({"held_delta": -1})
	return result


static func eligible(active: Array, version: int = 11, earned: Array[String] = []) -> Dictionary:
	var result: Dictionary = {}
	var all_items: Dictionary = catalog(version)
	for id: String in earned:
		if SeasonEarnedSponsors.ITEMS.has(id):
			all_items[id] = SeasonEarnedSponsors.ITEMS[id]
		elif SeasonSpecialOrder.ITEMS.has(id):
			all_items[id] = SeasonSpecialOrder.ITEMS[id]
		elif SeasonRaincheck.ITEMS.has(id):
			all_items[id] = SeasonRaincheck.ITEMS[id]
		elif SeasonTransfer.ITEMS.has(id):
			all_items[id] = SeasonTransfer.ITEMS[id]
		elif SeasonSecondChance.ITEMS.has(id):
			all_items[id] = SeasonSecondChance.ITEMS[id]
		elif SeasonCarbonCopy.ITEMS.has(id):
			all_items[id] = SeasonCarbonCopy.ITEMS[id]
		elif SeasonFieldSupply.ITEMS.has(id):
			all_items[id] = SeasonFieldSupply.ITEMS[id]
		elif SeasonSureShot.ITEMS.has(id):
			all_items[id] = SeasonSureShot.ITEMS[id]
		elif SeasonJumpstart.ITEMS.has(id):
			all_items[id] = SeasonJumpstart.ITEMS[id]
		elif SeasonDoubleMajor.ITEMS.has(id):
			all_items[id] = SeasonDoubleMajor.ITEMS[id]
		elif SeasonSmallBatch.ITEMS.has(id):
			all_items[id] = SeasonSmallBatch.ITEMS[id]
		elif SeasonLeftRight.ITEMS.has(id):
			all_items[id] = SeasonLeftRight.ITEMS[id]
		elif SeasonFreezers.ITEMS.has(id):
			all_items[id] = SeasonFreezers.ITEMS[id]
		elif SeasonAssociation.ITEMS.has(id):
			all_items[id] = SeasonAssociation.ITEMS[id]
		elif SeasonLateCheckout.ITEMS.has(id):
			all_items[id] = SeasonLateCheckout.ITEMS[id]
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




static func original_offer(offer: String) -> String:
	var source: String = offer
	if source.begins_with("rain:"):
		var alias: PackedStringArray = source.split(":", true, 2)
		if alias.size() != 3 or not _offer_number(alias[1], 1):
			return ""
		source = alias[2]
	var parts: PackedStringArray = source.split(":")
	if (
		parts.size() != 5
		or parts[0] != "visit"
		or parts[2] != "roll"
		or not _offer_number(parts[1], 1)
		or not _offer_number(parts[3], 0)
		or not _offer_number(parts[4], 0)
		or int(parts[4]) > 3
		or not SeasonOwnership._text(source)
	):
		return ""
	return source


static func _offer_number(value: String, minimum: int) -> bool:
	return value.is_valid_int() and int(value) >= minimum and str(int(value)) == value


static func offer_terms(
	rule: String, seed_value: int, offer: String, item_id: String
) -> Dictionary:
	var source: String = original_offer(offer)
	if (
		rule not in [D3_RULE, D4_RULE]
		or not D3_ITEMS.has(item_id)
		or source.is_empty()
		or not SeasonOwnership._whole(seed_value, 0, 2147483647)
	):
		return {}
	# Preserve the D3 classification first, then independently classify only its
	# flexible copies. Full-precision canonical bytes consume no RNG.
	var canonical: String = JSON.stringify(
		[D3_RULE, int(seed_value), source, item_id], "", true, true
	)
	if canonical.sha256_buffer()[0] < 64:
		return {"rule": D3_RULE, "source_offer": source}
	if rule == D4_RULE:
		canonical = JSON.stringify([D4_RULE, int(seed_value), source, item_id], "", true, true)
		if canonical.sha256_buffer()[0] < 64:
			return {"rule": D4_RULE, "source_offer": source, "duration": D4_DURATION}
	return {}


static func terms_valid(value: Variant) -> bool:
	if (
		not value is Dictionary
		or not value.get("source_offer") is String
		or value.source_offer.is_empty()
		or original_offer(value.source_offer) != value.source_offer
	):
		return false
	if value.get("rule") == D3_RULE:
		return SeasonOwnership._keys(value, ["rule", "source_offer"])
	return (
		value.get("rule") == D4_RULE
		and SeasonOwnership._keys(value, ["rule", "source_offer", "duration"])
		and SeasonOwnership._whole(value.duration, D4_DURATION, D4_DURATION)
	)


static func offer_label(build: SeasonBuild, offer: String, item_id: String) -> String:
	if not build.d3_sponsors_valid() and not build.d4_sponsors_valid():
		return ""
	var terms: Dictionary = offer_terms(build._sponsor_rule, build._seed, offer, item_id)
	if terms.is_empty():
		return ""
	if terms.rule == D4_RULE:
		return ("Working terms: covers your club's next 2 completed games, through " + \
			"final settlement. Early cancellation or replacement returns half " + \
			"actually paid; automatic expiry returns 0 Cash.")
	return ("Working terms: cancellation or replacement returns 0 Cash. Voluntary " + \
		"removal remains available.")


static func receipt_label(receipt: Dictionary) -> String:
	if not D3_ITEMS.has(receipt.get("item", "")) or not terms_valid(receipt.get("terms")):
		return ""
	if receipt.terms.rule == D4_RULE:
		if not SeasonOwnership._whole(receipt.get("games_remaining"), 1, D4_DURATION):
			return ""
		return (
			(
				"Working terms: %d club games remaining, through final settlement. Early cancellation "
				+ "or replacement returns half actually paid; automatic expiry returns 0 Cash."
			)
			% int(receipt.games_remaining)
		)
	return ("Working terms: cancellation or replacement returns 0 Cash. Voluntary " + \
		"removal remains available.")


static func resale(receipt: Dictionary) -> int:
	if (
		receipt.item == "J10"
		or (
			D3_ITEMS.has(receipt.item)
			and terms_valid(receipt.get("terms"))
			and receipt.terms.rule == D3_RULE
		)
	):
		return 0
	return floori(float(receipt.paid) / 2.0)


static func for_build(version: int) -> int:
	for minimum: int in {18: 11, 17: 10, 16: 9, 13: 8, 12: 7, 11: 6, 10: 5, 9: 4, 8: 3, 7: 2}:
		if version >= minimum:
			return {18: 11, 17: 10, 16: 9, 13: 8, 12: 7, 11: 6, 10: 5, 9: 4, 8: 3, 7: 2}[minimum]
	return 1


static func for_visit(build: SeasonBuild) -> int:
	var gates: Array = [
		[18, 11, build._film_from],
		[17, 10, build._budget_from],
		[16, 9, build._tactical_sponsor_from],
		[13, 8, build._wholesale_from],
		[12, 7, build._anchor_sponsor_from],
		[11, 6, build._school_sponsor_from],
		[10, 5, build._shop_sponsor_from],
		[9, 4, build._field_sponsor_from],
		[8, 3, build._sequence_sponsor_from],
		[7, 2, build._gameplay_sponsor_from]
	]
	for gate: Array in gates:
		if build._format >= gate[0] and build._visit.number >= gate[2]:
			return gate[1]
	return 1
