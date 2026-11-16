class_name StadiumOutfieldPlazaItems
extends RefCounted
## Additive exact-owned concourse package; base remains frozen during isolated authoring.
const Base = preload("res://src/gameplay/stadium/stadium_lighting_kit_items.gd")
const VERSION: int = 1
const PRICE_VERSION: int = 34
const LAYOUT_VERSION: int = 44
const FAMILY: String = "reference-outfield-plaza-v44"
const PRICES: Dictionary = {"ST-112": [1100, 420]}
const ITEMS: Array[String] = ["ST-112"]
const FIELDS: Array[String] = ["copy", "recipe", "occupants"]
const NIGHT_REASON: String = \
	("Outfield concourses and plazas are daylight-only until exact lighting " + \
	"and camera coverage are qualified.")


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if StadiumWaterfallLiveItems.is_family(layout):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = Base.upgrade(layout, access)
	if not Base.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["outfield_plaza"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if StadiumWaterfallLiveItems.is_family(layout):
		return base(StadiumWaterfallLiveItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = Base.LAYOUT_VERSION
	result.family = Base.FAMILY
	result.erase("outfield_plaza")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if StadiumWaterfallLiveItems.is_family(layout):
		return StadiumWaterfallLiveItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("outfield_plaza") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if Base.is_family(original)
		else Base.with_base(base(layout), original)
	)
	if not Base.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["outfield_plaza"] = layout.outfield_plaza.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if StadiumWaterfallLiveItems.is_family(layout):
		return StadiumWaterfallLiveItems.is_terrain(layout)
	return is_family(layout) and Base.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return Base.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, Base.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return Base.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"recipes": StadiumOutfieldPlazaRecipes.signature(),
				"model": StadiumOutfieldPlazaModels.VERSION,
				"ownership": "exact-kit-and-separate-optional-copies-store-first-v1",
				"tier": "mogul",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"night": false
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func price_signature() -> String:
	return (
		JSON.stringify({"version": PRICE_VERSION, "prices": PRICES}, "", true, true).sha256_text()
	)


static func geometry(tier: String, layout: Dictionary) -> String:
	if StadiumWaterfallLiveItems.is_family(layout):
		return StadiumWaterfallLiveItems.geometry(tier, layout)
	var contract: Dictionary = {"base": Base.geometry(tier, base(layout)), "plaza": signature()}
	var revisions: Dictionary = {}
	for kit: Dictionary in layout.get("outfield_plaza", []):
		var seal: String = StadiumOutfieldPlazaRecipes.revision_signature(kit.recipe)
		if not seal.is_empty():
			revisions[kit.recipe] = seal
	if not revisions.is_empty():
		contract["authored_recipe_revisions"] = revisions
	return JSON.stringify(contract, "", true, true).sha256_text()


static func quote(
	stock: StadiumStock, item: String, quantity: int, request: String, progress: Dictionary
) -> Dictionary:
	if stock == null or not PRICES.has(item):
		return ClubAssetLedger._error("This is not the complete outfield-concourse package.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The Working plaza quote changed; reload before purchasing.")
	return result


static func row(copy: String, recipe: String) -> Dictionary:
	if not StadiumOutfieldPlazaRecipes.supported(recipe):
		return {}
	return {
		"copy": copy,
		"item": "ST-112",
		"site": "OUTFIELD-PLAZA",
		"recipe": recipe,
		"position": Vector3.ZERO,
		"yaw": 0,
		"role": StadiumOutfieldPlazaRecipes.ROLE
	}


static func occupant(copy: String, item: String, recipe: String, site: String) -> Dictionary:
	var definition: Dictionary = StadiumOutfieldPlazaRecipes.definition(recipe)
	if (
		definition.is_empty()
		or not definition.sites.has(site)
		or not definition.sites[site].items.has(item)
	):
		return {}
	return {
		"copy": copy,
		"item": item,
		"site": site,
		"plaza_recipe": recipe,
		"position": definition.sites[site].position,
		"yaw": 0,
		"role": StadiumOutfieldPlazaRecipes.ROLE
	}


static func bounds(placed: Dictionary) -> AABB:
	if placed.item != "ST-112":
		var definition: Dictionary = StadiumOutfieldPlazaRecipes.definition(
			placed.get("plaza_recipe", "")
		)
		return (
			definition.sites[placed.site].box
			if definition.get("sites", {}).has(placed.site)
			else AABB()
		)
	var result: AABB = AABB()
	for reserve: AABB in StadiumOutfieldPlazaRecipes.reservations(placed.recipe):
		result = reserve if result.size == Vector3.ZERO else result.merge(reserve)
	return result


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if StadiumWaterfallLiveItems.is_family(layout):
		return StadiumWaterfallLiveItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("outfield_plaza") is Array
		or layout.outfield_plaza.size() > 1
	):
		return StadiumStarterLayout._error("Unknown outfield-concourse layout or capacity.")
	var checked: Dictionary = Base.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["outfield_plaza_placements"] = []
	if layout.outfield_plaza.is_empty():
		return checked
	if tier != "mogul" or stock == null or graph_for(layout) == null:
		return StadiumStarterLayout._error(
			"Outfield concourses require Mogul property and a complete verified field boundary."
		)
	var raw: Variant = layout.outfield_plaza[0]
	if (
		not raw is Dictionary
		or not SeasonOwnership._keys(raw, FIELDS)
		or not raw.copy is String
		or not raw.recipe is String
		or not raw.occupants is Array
		or not stock.copies.has(raw.copy)
		or stock.copies[raw.copy].item != "ST-112"
		or not checked.stored.has(raw.copy)
	):
		return StadiumStarterLayout._error(
			"The plaza needs one exact stored infrastructure copy and an explicit recipe."
		)
	var placed: Dictionary = row(raw.copy, raw.recipe)
	if placed.is_empty():
		return StadiumStarterLayout._error("Unknown concourse recipe.")
	var recipe: Dictionary = StadiumOutfieldPlazaRecipes.definition(raw.recipe)
	for reserve: AABB in StadiumOutfieldPlazaRecipes.reservations(raw.recipe):
		if (
			not StadiumProperty.contains(tier, reserve)
			or not StadiumPracticeFacilityItems._supported(reserve, base(layout))
			or not StadiumGroundBoxItems._outside_play(reserve, graph_for(layout))
		):
			return (
				StadiumStarterLayout
				. _error(
					"The complete concourse, routes, backdrop and pads must fit supported property outside play."
				)
			)
		for other: Dictionary in checked.placements:
			for obstacle: AABB in _obstacles(other):
				if reserve.intersects(obstacle):
					return StadiumStarterLayout._error(
						(
							"Concourse conflicts with "
							+ other.site
							+ "; explicitly Store one placement first."
						)
					)
		if StadiumMoldedSeatItems.has_pad(base(layout)):
			for pad: AABB in StadiumMoldedSeatItems.reservations():
				if StadiumPracticeFacilityItems._horizontal_overlap(reserve, pad):
					return StadiumStarterLayout._error(
						"Concourse must leave the existing molded-seat pad and access clear."
					)
	checked.stored.erase(raw.copy)
	checked.placements.append(placed)
	checked.outfield_plaza_placements.append(placed)
	var apple_count: int = layout.get("rising_apple", []).size()
	var prior: String = ""
	for value: Variant in raw.occupants:
		if (
			not value is Dictionary
			or not SeasonOwnership._keys(value, ["copy", "site"])
			or not value.copy is String
			or not value.site is String
			or value.site <= prior
			or not stock.copies.has(value.copy)
			or not checked.stored.has(value.copy)
		):
			return StadiumStarterLayout._error(
				"Each plaza pad needs one unique exact stored copy; Store before moving."
			)
		var child: Dictionary = occupant(
			value.copy, stock.copies[value.copy].item, raw.recipe, value.site
		)
		if child.is_empty():
			return StadiumStarterLayout._error(
				"That complete owned item is not qualified for this plaza pad."
			)
		if child.item == "ST-047":
			apple_count += 1
			if apple_count > 1:
				return StadiumStarterLayout._error(
					"Only one active rising apple is qualified; Store the existing apple first."
				)
		# The exact reservation must not block any declared circulation lane or outer wall.
		for lane: Rect2 in recipe.lanes + recipe.walls + recipe.beds:
			if StadiumPracticeFacilityItems._horizontal_overlap(
				bounds(child), StadiumOutfieldPlazaRecipes.box(lane)
			):
				return StadiumStarterLayout._error(
					"The selected landmark blocks a clear route, bed or backdrop."
				)
		checked.placements.append(child)
		checked.outfield_plaza_placements.append(child)
		checked.stored.erase(value.copy)
		prior = value.site
	checked.night_qualified = false
	checked["night_unqualified_reason"] = NIGHT_REASON
	return checked


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	recipe: String,
	access: Array[String] = []
) -> Dictionary:
	if StadiumWaterfallLiveItems.is_family(layout):
		return StadiumWaterfallLiveItems.with_base(
			layout, place(StadiumWaterfallLiveItems.base(layout), stock, copy, recipe, access)
		)
	if recipe.is_empty():
		return store_copy(layout, copy)
	if (
		stock == null
		or not stock.copies.has(copy)
		or stock.copies[copy].item != "ST-112"
		or row(copy, recipe).is_empty()
	):
		return layout.duplicate(true)
	var result: Dictionary = upgrade(layout, access)
	if result.is_empty():
		return layout.duplicate(true)
	if not result.outfield_plaza.is_empty():
		return result  # No silent replacement or move, including changing the recipe.
	result.outfield_plaza.append({"copy": copy, "recipe": recipe, "occupants": []})
	return result


static func place_occupant(layout: Dictionary, copy: String, site: String) -> Dictionary:
	if StadiumWaterfallLiveItems.is_family(layout):
		return StadiumWaterfallLiveItems.with_base(
			layout, place_occupant(StadiumWaterfallLiveItems.base(layout), copy, site)
		)
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result) or result.get("outfield_plaza", []).size() != 1:
		return result
	result.outfield_plaza[0].occupants.append({"copy": copy, "site": site})
	result.outfield_plaza[0].occupants.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if StadiumWaterfallLiveItems.is_family(layout):
		return StadiumWaterfallLiveItems.with_base(
			layout, store_copy(StadiumWaterfallLiveItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result) or result.get("outfield_plaza", []).size() != 1:
		return result
	if result.outfield_plaza[0].copy == copy:
		# Infrastructure cannot disappear under paid occupants. Store those explicitly first.
		if result.outfield_plaza[0].occupants.is_empty():
			result.outfield_plaza = []
	else:
		result.outfield_plaza[0].occupants = result.outfield_plaza[0].occupants.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if StadiumWaterfallLiveItems.is_family(layout):
		return StadiumWaterfallLiveItems.prune(layout)
	return with_base(layout, Base.prune(base(layout)))


static func _obstacles(other: Dictionary) -> Array[AABB]:
	var result: Array[AABB] = []
	if other.item == "ST-036":
		return StadiumStringLightItems.reservations(other.site)
	if other.item == "ST-111":
		for component: Dictionary in StadiumLightingKitModels.components(other.site):
			result.append(component.bounds)
		return result
	result.append(StadiumHomeLayout.bounds(other))
	return result
