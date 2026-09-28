class_name DevelopmentShopCatalog
extends RefCounted
## Working prices/family sampling from Players v17 and Economy v24.
## Only implemented categories enter this bounded shop; missing pools stay absent.

const CARDS: Dictionary = {
	"development.contact": {"name": "Batting Cage", "price": 6, "family": "contact", "op": "stat"},
	"development.power": {"name": "Strength Session", "price": 6, "family": "power", "op": "stat"},
	"development.fielding":
	{"name": "Fielding Drills", "price": 6, "family": "fielding", "op": "stat"},
	"development.pitching":
	{"name": "Bullpen Coach", "price": 6, "family": "pitching", "op": "stat"},
	"development.mastery":
	{"name": "Pitch Mastery", "price": 8, "family": "pitch", "op": "mastery"},
	"development.round_out": {"name": "Round Out", "price": 6, "family": "pitch", "op": "round_out"}
}
const LESSON_PRICES: Dictionary = {
	"pitch.overhand_four_seam": 10,
	"pitch.overhand_sinker": 10,
	"pitch.sidearm_sinker": 10,
	"pitch.overhand_slider": 10,
	"pitch.sidearm_slider": 10,
	"pitch.drop": 12,
	"pitch.riser": 12,
	"pitch.knuckleball": 14,
	"pitch.eephus": 12
}
const PACK_PRICE: int = 8


static func item(id: String) -> Dictionary:
	if CARDS.has(id):
		return CARDS[id].duplicate(true)
	var recipe: String = id.trim_prefix("lesson.")
	if id.begins_with("lesson.") and LESSON_PRICES.has(recipe):
		return {
			"name": ContentDB.get_pitch(StringName(recipe)).display_name + " Lesson",
			"price": LESSON_PRICES[recipe],
			"op": "learn",
			"recipe": recipe,
			"family": "lesson"
		}
	return {}


static func ownership_catalog() -> Dictionary:
	var result: Dictionary = {}
	for id: String in CARDS:
		result[id] = {"kind": "held", "price": CARDS[id].price, "sale": "zero"}
	return result


static func signature() -> String:
	return JSON.stringify([CARDS, LESSON_PRICES, PACK_PRICE]).sha256_text()


static func targets(
	book: SeasonDevelopment, roster: Array[String], id: String
) -> Array[Dictionary]:
	var definition: Dictionary = item(id)
	var result: Array[Dictionary] = []
	if definition.is_empty():
		return result
	for player_id: String in roster:
		var profile: Dictionary = book.player(player_id)
		if profile.is_empty():
			continue
		if definition.op == "stat":
			if profile.stats[definition.family] < SeasonDevelopment.STAT_CAP:
				result.append({"player": player_id, "pitch": "", "replace": ""})
		elif definition.op == "learn":
			if profile.active.has(definition.recipe):
				continue
			if profile.active.size() < profile.capacity:
				result.append({"player": player_id, "pitch": "", "replace": ""})
			for active: String in profile.active:
				result.append({"player": player_id, "pitch": "", "replace": active})
		else:
			var lowest: int = SeasonDevelopment.PITCH_CAP
			for active: String in profile.active:
				lowest = mini(lowest, profile.mastery[active])
			for active: String in profile.active:
				if profile.mastery[active] >= SeasonDevelopment.PITCH_CAP:
					continue
				if definition.op == "round_out" and profile.mastery[active] != lowest:
					continue
				result.append({"player": player_id, "pitch": active, "replace": ""})
	return result


static func families(book: SeasonDevelopment, roster: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for id: String in CARDS:
		if targets(book, roster, id).is_empty():
			continue
		var family: String = CARDS[id].family
		if not result.has(family):
			result[family] = []
		result[family].append(id)
	return result


static func pack(
	book: SeasonDevelopment, roster: Array[String], rng: RandomNumberGenerator
) -> Array:
	var available: Dictionary = families(book, roster)
	var result: Array = []
	for _index in range(mini(3, available.size())):
		var family: String = available.keys()[rng.randi_range(0, available.size() - 1)]
		var variants: Array = available[family]
		result.append(variants[rng.randi_range(0, variants.size() - 1)])
		available.erase(family)
	return result


static func offers(
	book: SeasonDevelopment, roster: Array[String], rng: RandomNumberGenerator, prefix: String
) -> Dictionary:
	var available: Dictionary = families(book, roster)
	var lessons: Array[String] = []
	for recipe: String in LESSON_PRICES:
		var id: String = "lesson." + recipe
		if not targets(book, roster, id).is_empty():
			lessons.append(id)
	var result: Dictionary = {}
	if available.is_empty() and lessons.is_empty():
		return result
	var kinds: Array[String] = []
	for index in range(4):
		var development: bool = lessons.is_empty() or rng.randf() < 25.0 / 37.0
		if available.is_empty():
			development = false
		# Bounded diversity repair in the last slot. Unsupported category weights
		# are redistributed, with no wallet or held-slot eligibility filter.
		if index == 3 and not available.is_empty() and not lessons.is_empty():
			if not kinds.has("development"):
				development = true
			elif not kinds.has("lesson"):
				development = false
		var id: String
		if development:
			var family: String = available.keys()[rng.randi_range(0, available.size() - 1)]
			var variants: Array = available[family]
			id = variants[rng.randi_range(0, variants.size() - 1)]
		else:
			id = lessons[rng.randi_range(0, lessons.size() - 1)]
		result["%s:%d" % [prefix, index]] = id
		kinds.append("development" if development else "lesson")
	return result
