class_name StadiumSalvageCarItems
extends RefCounted
## Separately versioned fixed starter salvage, never a fourth starter entitlement.
const VERSION: int = 1
const PRICE_VERSION: int = 31
const LAYOUT_VERSION: int = 40
const FAMILY: String = "reference-salvage-car-v40"
const PRICES: Dictionary = {"ST-005": [620, 190]}
const SITE: String = "CAR-START"
const POSITION: Vector3 = Vector3(-16.2, 0, 18)


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
		StadiumMasteryBannerItems.is_family(layout)
		or (
			StadiumWaterfallItems.is_family(layout)
			or (
				StadiumLightingKitItems.is_family(layout)
				or (
					StadiumOutfieldPlazaItems.is_family(layout)
					or StadiumWaterfallLiveItems.is_family(layout)
				)
			)
		)
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = StadiumStringLightItems.upgrade(layout, access)
	if not StadiumStringLightItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["salvage_cars"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
		StadiumMasteryBannerItems.is_family(layout)
		or (
			StadiumWaterfallItems.is_family(layout)
			or (
				StadiumLightingKitItems.is_family(layout)
				or (
					StadiumOutfieldPlazaItems.is_family(layout)
					or StadiumWaterfallLiveItems.is_family(layout)
				)
			)
		)
	):
		return base(StadiumMasteryBannerItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumStringLightItems.LAYOUT_VERSION
	result.family = StadiumStringLightItems.FAMILY
	result.erase("salvage_cars")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
		StadiumMasteryBannerItems.is_family(layout)
		or (
			StadiumWaterfallItems.is_family(layout)
			or (
				StadiumLightingKitItems.is_family(layout)
				or (
					StadiumOutfieldPlazaItems.is_family(layout)
					or StadiumWaterfallLiveItems.is_family(layout)
				)
			)
		)
	):
		return StadiumMasteryBannerItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("salvage_cars") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumStringLightItems.is_family(original)
		else StadiumStringLightItems.with_base(base(layout), original)
	)
	if not StadiumStringLightItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["salvage_cars"] = layout.salvage_cars.duplicate(true)
	return result


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"site": SITE,
				"position": [-16.2, 0, 18],
				"yaw": 0,
				"model": StadiumJunkCarModels.VERSION,
				"reservation": [2.3, 1.8, 4.4],
				"live_units": 4,
				"trap_speed": StadiumJunkCarRuntime.SETTLED_SPEED,
				"trap_travel": StadiumJunkCarRuntime.SETTLED_TRAVEL,
				"trap_dwell": StadiumJunkCarRuntime.SETTLED_DWELL,
				"trap_expiry": StadiumJunkCarRuntime.OBSERVATION_EXPIRY,
				"trap": "actual-underbody-entry-minimum-single-higher-preserved-foul-remains-foul",
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


static func quote(
	stock: StadiumStock, item: String, quantity: int, request: String, progress: Dictionary
) -> Dictionary:
	return (
		stock.quote(item, quantity, progress, request)
		if item == "ST-005"
		else StadiumStringLightItems.quote(stock, item, quantity, request, progress)
	)


static func geometry(tier: String, layout: Dictionary) -> String:
	if (
		StadiumMasteryBannerItems.is_family(layout)
		or (
			StadiumWaterfallItems.is_family(layout)
			or (
				StadiumLightingKitItems.is_family(layout)
				or (
					StadiumOutfieldPlazaItems.is_family(layout)
					or StadiumWaterfallLiveItems.is_family(layout)
				)
			)
		)
	):
		return StadiumMasteryBannerItems.geometry(tier, layout)
	return (StadiumStringLightItems.geometry(tier, base(layout)) + ":" + signature()).sha256_text()


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumStringLightItems.graph_for(base(layout))


static func is_terrain(layout: Variant) -> bool:
	if (
		StadiumMasteryBannerItems.is_family(layout)
		or (
			StadiumWaterfallItems.is_family(layout)
			or (
				StadiumLightingKitItems.is_family(layout)
				or (
					StadiumOutfieldPlazaItems.is_family(layout)
					or StadiumWaterfallLiveItems.is_family(layout)
				)
			)
		)
	):
		return (
			StadiumMasteryBannerItems.is_terrain(layout)
			or (
				StadiumWaterfallItems.is_terrain(layout)
				or (
					StadiumLightingKitItems.is_terrain(layout)
					or (
						StadiumOutfieldPlazaItems.is_terrain(layout)
						or StadiumWaterfallLiveItems.is_terrain(layout)
					)
				)
			)
		)
	return is_family(layout) and StadiumStringLightItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumStringLightItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumStringLightItems.contacts_layout(base(layout)))


static func row(copy: String) -> Dictionary:
	return {
		"copy": copy,
		"item": "ST-005",
		"site": SITE,
		"position": POSITION,
		"yaw": 0,
		"role": "LIVE_RICOCHET"
	}


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		StadiumMasteryBannerItems.is_family(layout)
		or (
			StadiumWaterfallItems.is_family(layout)
			or (
				StadiumLightingKitItems.is_family(layout)
				or (
					StadiumOutfieldPlazaItems.is_family(layout)
					or StadiumWaterfallLiveItems.is_family(layout)
				)
			)
		)
	):
		return StadiumMasteryBannerItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("salvage_cars") is Array
		or layout.salvage_cars.size() > 1
	):
		return StadiumStarterLayout._error("Unknown fixed salvage-car layout.")
	var checked: Dictionary = StadiumStringLightItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["salvage_car_placements"] = []
	if layout.salvage_cars.is_empty():
		return checked
	var raw: Variant = layout.salvage_cars[0]
	if (
		not raw is Dictionary
		or not SeasonOwnership._keys(raw, ["copy", "site"])
		or not raw.copy is String
		or raw.site != SITE
		or stock == null
		or not stock.copies.has(raw.copy)
		or stock.copies[raw.copy].item != "ST-005"
		or not checked.stored.has(raw.copy)
	):
		return StadiumStarterLayout._error(
			"The fixed car site requires one distinct owned ST-005 copy."
		)
	if int(checked.get("live_units", 0)) != 0:
		return (
			StadiumStarterLayout
			. _error(
				"The car consumes all four live-capacity units; explicitly store other live obstacles first."
			)
		)
	var placed: Dictionary = row(raw.copy)
	var reserve: AABB = AABB(POSITION + Vector3(-1.15, 0, -2.2), Vector3(2.3, 1.8, 4.4))
	if (
		not StadiumProperty.contains(tier, reserve)
		or not StadiumLandscapeOwnedItems._supported(reserve, layout)
	):
		return StadiumStarterLayout._error(
			"The whole car requires level supported land inside the property."
		)
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if graph == null or graph.polygon() != StadiumRecipeBoundary.create("straight").polygon():
		return StadiumStarterLayout._error(
			"The fixed salvage car currently supports the reference straight field only."
		)
	for other: Dictionary in checked.placements:
		if reserve.intersects(StadiumHomeLayout.bounds(other)):
			return StadiumStarterLayout._error(
				(
					"The fixed car site conflicts with "
					+ other.site
					+ "; explicitly store that copy first."
				)
			)
	checked.placements.append(placed)
	checked.salvage_car_placements.append(placed)
	checked.stored.erase(raw.copy)
	checked.live_units = 4
	checked.night_qualified = false
	checked["night_unqualified_reason"] = \
		"The fixed salvage-car site awaits rendered night qualification."
	return checked


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String = SITE,
	access: Array[String] = []
) -> Dictionary:
	if (
		StadiumMasteryBannerItems.is_family(layout)
		or (
			StadiumWaterfallItems.is_family(layout)
			or (
				StadiumLightingKitItems.is_family(layout)
				or (
					StadiumOutfieldPlazaItems.is_family(layout)
					or StadiumWaterfallLiveItems.is_family(layout)
				)
			)
		)
	):
		return StadiumMasteryBannerItems.with_base(
			layout, place(StadiumMasteryBannerItems.base(layout), stock, copy, site, access)
		)
	if site.is_empty():
		return store_copy(layout, copy)
	if (
		stock == null
		or not stock.copies.has(copy)
		or stock.copies[copy].item != "ST-005"
		or site != SITE
	):
		return layout.duplicate(true)
	var result: Dictionary = upgrade(layout, access)
	if result.is_empty():
		return layout.duplicate(true)
	result.salvage_cars = result.salvage_cars.filter(
		func(value: Dictionary) -> bool: return value.copy != copy
	)
	result.salvage_cars.append({"copy": copy, "site": SITE})
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
		StadiumMasteryBannerItems.is_family(layout)
		or (
			StadiumWaterfallItems.is_family(layout)
			or (
				StadiumLightingKitItems.is_family(layout)
				or (
					StadiumOutfieldPlazaItems.is_family(layout)
					or StadiumWaterfallLiveItems.is_family(layout)
				)
			)
		)
	):
		return StadiumMasteryBannerItems.with_base(
			layout, store_copy(StadiumMasteryBannerItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("salvage_cars") is Array:
		result.salvage_cars = result.salvage_cars.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if (
		StadiumMasteryBannerItems.is_family(layout)
		or (
			StadiumWaterfallItems.is_family(layout)
			or (
				StadiumLightingKitItems.is_family(layout)
				or (
					StadiumOutfieldPlazaItems.is_family(layout)
					or StadiumWaterfallLiveItems.is_family(layout)
				)
			)
		)
	):
		return StadiumMasteryBannerItems.prune(layout)
	return with_base(layout, StadiumStringLightItems.prune(base(layout)))
