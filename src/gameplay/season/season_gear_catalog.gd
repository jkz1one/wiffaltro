class_name SeasonGearCatalog
extends RefCounted
## Supported Working candidates from Equipment/Sponsors v18. No earned tiers granted.
## Remaining Misc and Alley identity/physics dependencies stay outside this pool.

const ITEMS: Dictionary = {
	"BAT-CON-01":
	{
		"name": "Wide Barrel Bat",
		"slot": "bat",
		"price": 10,
		"radius": 1.06,
		"exit": 0.96,
		"effect": "Both contact radii +6%; fair exit speed −4%. Both swing types."
	},
	"BAT-POW-01":
	{
		"name": "Taped Bat",
		"slot": "bat",
		"price": 10,
		"radius": 0.94,
		"exit": 1.05,
		"effect": "Fair exit speed +5%; both contact radii −6%. Both swing types."
	},
	"BALL-MOV-01":
	{
		"name": "Scraped Ball",
		"slot": "ball",
		"price": 10,
		"velocity": 0.97,
		"movement": 1.08,
		"effect": "Authored pitch movement +8%; release velocity −3%."
	},
	"BALL-VEL-01":
	{
		"name": "Slick Ball",
		"slot": "ball",
		"price": 10,
		"velocity": 1.03,
		"movement": 0.92,
		"effect": "Release velocity +3%; authored pitch movement −8%."
	},
	"BALL-HYB-01":
	{
		"name": "Hot Ball",
		"slot": "ball",
		"price": 12,
		"velocity": 1.02,
		"movement": 1.05,
		"command": 1.10,
		"effect": "Release velocity +2%; movement +5%; command-error dispersion +10%."
	},
	"MISC-PIT-03":
	{
		"name": "Rosin Bag",
		"slot": "misc",
		"price": 10,
		"command": 0.85,
		"workload": 1.10,
		"effect": "Command-error dispersion −15%; pitch workload +10%."
	}
}

# Keep ITEMS byte-for-byte stable for paid build3 journals.
const MISC_ITEMS: Dictionary = {
	"D02":
	{
		"name": "Bullpen Kit",
		"slot": "misc",
		"price": 10,
		"effect":
		"Pitch workload −15% through each pitcher's first completed batter; +10% afterward."
	},
	"MISC-BAT-01":
	{
		"name": "Batting Gloves",
		"slot": "misc",
		"price": 10,
		"timing": 1.08,
		"exit": 0.96,
		"effect":
		"Timing window +8%; fair exit speed −4%. Both swing types; swing motion stays fixed."
	},
	"MISC-FLD-03":
	{
		"name": "Sports Goggles",
		"slot": "misc",
		"price": 12,
		"reaction": 0.85,
		"effect": "Fielder and pitcher reaction delay −15%. No movement-speed or handling bonus."
	}
}
const MIN_REACTION_SECONDS: float = 0.001


static func catalog(catalog_version: int = 2) -> Dictionary:
	var result: Dictionary = ITEMS.duplicate(true)
	if catalog_version >= 2:
		result.merge(MISC_ITEMS, true)
	return result


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, MISC_ITEMS.get(id, {})).duplicate(true)


static func signature(catalog_version: int = 2) -> String:
	return JSON.stringify(catalog(catalog_version)).sha256_text()


static func ownership_catalog() -> Dictionary:
	var result: Dictionary = DevelopmentShopCatalog.ownership_catalog()
	var all_items: Dictionary = catalog()
	for id: String in all_items:
		result[id] = {
			"kind": "gear", "slot": all_items[id].slot, "price": all_items[id].price, "sale": "half"
		}
	return result


static func eligible(gear: Dictionary, catalog_version: int = 2) -> Dictionary:
	var result: Dictionary = {}
	var all_items: Dictionary = catalog(catalog_version)
	for id: String in all_items:
		var slot: String = all_items[id].slot
		if gear.get(slot, {}).get("item", "") == id:
			continue
		if not result.has(slot):
			result[slot] = []
		result[slot].append(id)
	return result


static func equip(player: PlayerDefinition, gear: Dictionary) -> PlayerDefinition:
	# Runtime copy only. Ratings, authored resources and developed recipes stay pristine.
	var result: PlayerDefinition = player.duplicate() as PlayerDefinition
	result.season_gear = {}
	for slot: String in SeasonOwnership.GEAR_SLOTS:
		var id: String = gear.get(slot, {}).get("item", "")
		if item(id).get("slot", "") == slot:
			result.season_gear[slot] = id
	return result


static func factor(player: PlayerDefinition, key: String) -> float:
	var result: float = 1.0
	for id: String in player.season_gear.values():
		result *= float(item(id).get(key, 1.0))
	return result


static func swing(
	source: SwingProfileDefinition, player: PlayerDefinition
) -> SwingProfileDefinition:
	var result: SwingProfileDefinition = source.duplicate() as SwingProfileDefinition
	result.contact_radius_x_m *= factor(player, "radius")
	result.contact_radius_y_m *= factor(player, "radius")
	result.gear_fair_exit_scale = factor(player, "exit")
	result.gear_timing_scale = factor(player, "timing")
	return result


static func pitch(source: PitchDefinition, player: PlayerDefinition) -> PitchDefinition:
	var result: PitchDefinition = source.duplicate() as PitchDefinition
	result.nominal_velocity_mps *= factor(player, "velocity")
	# Existing authored lift/perforation only: gravity and natural Knuckle wobble stay intact.
	result.mastery_movement_scale *= factor(player, "movement")
	result.gear_command_scale = factor(player, "command")
	return result


static func offers(
	book: SeasonDevelopment,
	roster: Array[String],
	gear: Dictionary,
	rng: RandomNumberGenerator,
	prefix: String,
	catalog_version: int = 2
) -> Dictionary:
	var development: Dictionary = DevelopmentShopCatalog.families(book, roster)
	var lessons: Array[String] = []
	for recipe: String in DevelopmentShopCatalog.LESSON_PRICES:
		if not DevelopmentShopCatalog.targets(book, roster, "lesson." + recipe).is_empty():
			lessons.append("lesson." + recipe)
	var equipment: Dictionary = eligible(gear, catalog_version)
	var weights: Dictionary = {}
	if not development.is_empty():
		weights["development"] = 25.0
	if not lessons.is_empty():
		weights["lesson"] = 12.0
	if not equipment.is_empty():
		weights["gear"] = 20.0
	var result: Dictionary = {}
	var seen: Array[String] = []
	for index in range(4):
		var choices: Dictionary = weights.duplicate()
		# At least two categories when feasible; bounded last-position repair.
		if index == 3 and seen.size() == 1 and choices.size() > 1:
			choices.erase(seen[0])
		if choices.is_empty():
			break
		var kind: String = _weighted(choices, rng)
		if not seen.has(kind):
			seen.append(kind)
		var id: String
		if kind == "development":
			var family: String = development.keys()[rng.randi_range(0, development.size() - 1)]
			var variants: Array = development[family]
			id = variants[rng.randi_range(0, variants.size() - 1)]
		elif kind == "lesson":
			id = lessons[rng.randi_range(0, lessons.size() - 1)]
		else:
			# Equal eligible Bat/Ball/Misc subweights. Each enabled family has tier 1 only.
			var slot: String = equipment.keys()[rng.randi_range(0, equipment.size() - 1)]
			var variants: Array = equipment[slot]
			id = variants[rng.randi_range(0, variants.size() - 1)]
		result["%s:%d" % [prefix, index]] = id
	return result


static func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for weight: float in weights.values():
		total += weight
	var roll: float = rng.randf() * total
	for kind: String in weights:
		roll -= float(weights[kind])
		if roll < 0.0:
			return kind
	return weights.keys().back()


static func workload(player: PlayerMatchState) -> float:
	if player.definition.season_gear.get("misc", "") == "D02":
		return 1.10 if player.first_batter_completed else 0.85
	return factor(player.definition, "workload")


static func reaction_delay(seconds: float, player: PlayerDefinition) -> float:
	var scale: float = factor(player, "reaction")
	return seconds if scale == 1.0 else maxf(MIN_REACTION_SECONDS, seconds * scale)
