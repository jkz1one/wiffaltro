class_name StadiumWaterfallItems
extends RefCounted
## One complete paid decorative waterfall. Frozen collider-free model; no live-ball authority.

const VERSION: int = 1
const PRICE_VERSION: int = 32
const LAYOUT_VERSION: int = 42
const FAMILY: String = "reference-owned-waterfall-v42"
const PRICES: Dictionary = {"ST-046": [950, 260]}
const ITEMS: Array[String] = ["ST-046"]
const FIELDS: Array[String] = ["copy", "site"]
const SITES: Dictionary = {"LANDMARK-A": Vector3(36.5, 0, 44)}
const ENVELOPE: AABB = AABB(Vector3(-6.5, 0, -5), Vector3(13, 4, 10))


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
		StadiumLightingKitItems.is_family(layout)
		or (
			StadiumOutfieldPlazaItems.is_family(layout)
			or StadiumWaterfallLiveItems.is_family(layout)
		)
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}  # ST-006 retains its exact separate owned route.
	var result: Dictionary = StadiumMasteryBannerItems.upgrade(layout, access)
	if not StadiumMasteryBannerItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["waterfalls"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
		StadiumLightingKitItems.is_family(layout)
		or (
			StadiumOutfieldPlazaItems.is_family(layout)
			or StadiumWaterfallLiveItems.is_family(layout)
		)
	):
		return base(StadiumLightingKitItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumMasteryBannerItems.LAYOUT_VERSION
	result.family = StadiumMasteryBannerItems.FAMILY
	result.erase("waterfalls")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
		StadiumLightingKitItems.is_family(layout)
		or (
			StadiumOutfieldPlazaItems.is_family(layout)
			or StadiumWaterfallLiveItems.is_family(layout)
		)
	):
		return StadiumLightingKitItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("waterfalls") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumMasteryBannerItems.is_family(original)
		else StadiumMasteryBannerItems.with_base(base(layout), original)
	)
	if not StadiumMasteryBannerItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["waterfalls"] = layout.waterfalls.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
		StadiumLightingKitItems.is_family(layout)
		or (
			StadiumOutfieldPlazaItems.is_family(layout)
			or StadiumWaterfallLiveItems.is_family(layout)
		)
	):
		return (
			StadiumLightingKitItems.is_terrain(layout)
			or (
				StadiumOutfieldPlazaItems.is_terrain(layout)
				or StadiumWaterfallLiveItems.is_terrain(layout)
			)
		)
	return is_family(layout) and StadiumMasteryBannerItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumMasteryBannerItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumMasteryBannerItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumMasteryBannerItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 41,
				"model_version": 1,
				"model_parts": StadiumWaterfallModels.PARTS,
				"sites": {"LANDMARK-A": [36.5, 0, 44]},
				"exclusive_site": "LANDMARK-A",
				"envelope": [-6.5, 0, -5, 13, 4, 10],
				"yaw": 0,
				"tiers": ["mogul"],
				"items": ITEMS,
				"copy_policy": "exact-owned-copy-store-first-v1",
				"site_capacity": 1,
				"support": "whole-outer-property-ground-outside-terrain-patch-v1",
				"clearance": "selected-boundary-slabs-and-full-occupied-reservations-v1",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
				"colliders": false,
				"animation": false,
				"water_result": false,
				"gameplay_bonus": false,
				"night_qualified": false
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
	if (
		StadiumLightingKitItems.is_family(layout)
		or (
			StadiumOutfieldPlazaItems.is_family(layout)
			or StadiumWaterfallLiveItems.is_family(layout)
		)
	):
		return StadiumLightingKitItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumMasteryBannerItems.geometry(tier, base(layout)),
				"waterfalls": signature()
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func quote(
	stock: StadiumStock, item: String, quantity: int, request: String, progress: Dictionary
) -> Dictionary:
	if stock == null or not PRICES.has(item):
		return ClubAssetLedger._error(
			"This item is not the complete paid owned-waterfall landmark."
		)
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error(
			"The decorative waterfall quote changed; reload before purchasing."
		)
	return result


static func sites(item: String = "ST-046") -> Array[String]:
	var result: Array[String] = []
	if PRICES.has(item):
		result.assign(SITES.keys())
		result.sort()
	return result


static func yaws(item: String = "ST-046") -> Array[int]:
	var result: Array[int] = []
	if PRICES.has(item):
		result.append(0)
	return result


static func row(copy: String, item: String, site: String, yaw: float = 0.0) -> Dictionary:
	if not PRICES.has(item) or not SITES.has(site) or not is_finite(yaw) or yaw != 0.0:
		return {}
	return {
		"copy": copy,
		"item": item,
		"site": site,
		"position": SITES[site],
		"yaw": 0,
		"role": "DECORATIVE_AFTER_TERMINAL"
	}


static func envelope(item: String = "ST-046", site: String = "LANDMARK-A") -> AABB:
	return ENVELOPE if PRICES.has(item) and SITES.has(site) else AABB()


static func bounds(placed: Dictionary) -> AABB:
	return Transform3D(Basis.IDENTITY, placed.position) * envelope(placed.item, placed.site)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		StadiumLightingKitItems.is_family(layout)
		or (
			StadiumOutfieldPlazaItems.is_family(layout)
			or StadiumWaterfallLiveItems.is_family(layout)
		)
	):
		return StadiumLightingKitItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("waterfalls") is Array
		or layout.waterfalls.size() > SITES.size()
	):
		return StadiumStarterLayout._error("Unknown owned-waterfall layout or site capacity.")
	var checked: Dictionary = StadiumMasteryBannerItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["waterfalls_placements"] = []
	if layout.waterfalls.is_empty():
		return checked
	if tier != "mogul":
		return StadiumStarterLayout._error("The decorative waterfall requires Mogul property.")
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error(
			"The decorative waterfall needs a verified complete selected field boundary."
		)
	var prior: String = ""
	for raw: Variant in layout.waterfalls:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, FIELDS)
			or not raw.copy is String
			or not raw.site is String
			or not SITES.has(raw.site)
			or raw.site <= prior
			or stock == null
			or not stock.copies.has(raw.copy)
			or not checked.stored.has(raw.copy)
			or not PRICES.has(stock.copies[raw.copy].item)
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						"LANDMARK-A needs one exact owned ST-046 copy; explicitly store its occupant or "
						+ "moving copy first."
					)
				)
			)
		var placed: Dictionary = row(raw.copy, stock.copies[raw.copy].item, raw.site)
		var reserve: AABB = bounds(placed)
		if (
			not StadiumProperty.contains(tier, reserve)
			or not _supported(reserve, layout)
			or not _outside_play(reserve, graph)
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						raw.site
						+ (" needs its entire supported reservation inside the property and " + \
							"outside the selected field and boundary slabs.")
					)
				)
			)
		# Validate the complete reconstructed layout in either command order.
		# Keep all paid occupants until the user explicitly stores one.
		for other: Dictionary in checked.placements:
			if other.site == "LANDMARK-A":
				return (
					StadiumStarterLayout
					. _error(
						(
							"LANDMARK-A is exclusive; explicitly store its existing landmark or the decorative "
							+ "waterfall first. Both complete paid copies remain owned."
						)
					)
				)
			if _overlaps(reserve, other):
				return StadiumStarterLayout._error(
					(
						raw.site
						+ " conflicts with "
						+ other.site
						+ "; explicitly store one placement first."
					)
				)
		if StadiumMoldedSeatItems.has_pad(layout):
			for pad: AABB in StadiumMoldedSeatItems.reservations():
				if StadiumPracticeFacilityItems._horizontal_overlap(reserve, pad):
					return (
						StadiumStarterLayout
						. _error(
							"The decorative waterfall must leave the selected molded-seat pad and access clear."
						)
					)
		checked.placements.append(placed)
		checked.waterfalls_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	checked.night_qualified = false
	checked["night_unqualified_reason"] = "The decorative waterfall has not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func _supported(box: AABB, layout: Dictionary) -> bool:
	return StadiumPracticeFacilityItems._supported(box, layout)


static func _outside_play(box: AABB, graph: StadiumRecipeBoundary) -> bool:
	return StadiumGroundBoxItems._outside_play(box, graph)


static func _overlaps(reserve: AABB, other: Dictionary) -> bool:
	if PRICES.has(other.item):
		return StadiumPracticeFacilityItems._horizontal_overlap(reserve, bounds(other))
	return StadiumPracticeFacilityItems._horizontal_overlap(
		reserve, StadiumHomeLayout.bounds(other)
	)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if (
		StadiumLightingKitItems.is_family(layout)
		or (
			StadiumOutfieldPlazaItems.is_family(layout)
			or StadiumWaterfallLiveItems.is_family(layout)
		)
	):
		return StadiumLightingKitItems.with_base(
			layout, place(StadiumLightingKitItems.base(layout), stock, copy, site, yaw, access)
		)
	if site.is_empty():
		return store_copy(layout, copy)
	if (
		stock == null
		or not stock.copies.has(copy)
		or row(copy, stock.copies[copy].item, site, yaw).is_empty()
	):
		return layout.duplicate(true)
	var result: Dictionary = upgrade(layout, access)
	if result.is_empty():
		return layout.duplicate(true)
	for current: Dictionary in result.waterfalls:
		if current.copy == copy and current.site == site:
			return result
	result.waterfalls.append({"copy": copy, "site": site})
	result.waterfalls.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
		StadiumLightingKitItems.is_family(layout)
		or (
			StadiumOutfieldPlazaItems.is_family(layout)
			or StadiumWaterfallLiveItems.is_family(layout)
		)
	):
		return StadiumLightingKitItems.with_base(
			layout, store_copy(StadiumLightingKitItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("waterfalls") is Array:
		result.waterfalls = result.waterfalls.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if (
		StadiumLightingKitItems.is_family(layout)
		or (
			StadiumOutfieldPlazaItems.is_family(layout)
			or StadiumWaterfallLiveItems.is_family(layout)
		)
	):
		return StadiumLightingKitItems.prune(layout)
	return with_base(layout, StadiumMasteryBannerItems.prune(base(layout)))
