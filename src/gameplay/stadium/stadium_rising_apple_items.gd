class_name StadiumRisingAppleItems
extends RefCounted
## One complete paid rising-apple landmark. Exact ownership; outside-play scenery only.

const VERSION: int = 1
const PRICE_VERSION: int = 26
const LAYOUT_VERSION: int = 35
const FAMILY: String = "reference-rising-apple-v35"
const PRICES: Dictionary = {"ST-047": [900, 240]}
const ITEMS: Array[String] = ["ST-047"]
const FIELDS: Array[String] = ["copy", "site"]
const SITES: Dictionary = {"LANDMARK-A": Vector3(36.5, 0, 44)}
const ENVELOPE: AABB = AABB(Vector3(-6.5, 0, -5), Vector3(13, 8, 10))


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
		StadiumWallTopTerraceItems.is_family(layout)
		or (
			StadiumPlayerTunnelItems.is_family(layout)
			or (
				StadiumMountedDisplayItems.is_family(layout)
				or (
					StadiumStringLightItems.is_family(layout)
					or (
						StadiumSalvageCarItems.is_family(layout)
						or (
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
						)
					)
				)
			)
		)
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}  # ST-006 retains its exact separate owned route.
	var result: Dictionary = StadiumOutfieldBleacherItems.upgrade(layout, access)
	if not StadiumOutfieldBleacherItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["rising_apple"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
		StadiumWallTopTerraceItems.is_family(layout)
		or (
			StadiumPlayerTunnelItems.is_family(layout)
			or (
				StadiumMountedDisplayItems.is_family(layout)
				or (
					StadiumStringLightItems.is_family(layout)
					or (
						StadiumSalvageCarItems.is_family(layout)
						or (
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
						)
					)
				)
			)
		)
	):
		return base(StadiumWallTopTerraceItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumOutfieldBleacherItems.LAYOUT_VERSION
	result.family = StadiumOutfieldBleacherItems.FAMILY
	result.erase("rising_apple")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
		StadiumWallTopTerraceItems.is_family(layout)
		or (
			StadiumPlayerTunnelItems.is_family(layout)
			or (
				StadiumMountedDisplayItems.is_family(layout)
				or (
					StadiumStringLightItems.is_family(layout)
					or (
						StadiumSalvageCarItems.is_family(layout)
						or (
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
						)
					)
				)
			)
		)
	):
		return StadiumWallTopTerraceItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("rising_apple") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumOutfieldBleacherItems.is_family(original)
		else StadiumOutfieldBleacherItems.with_base(base(layout), original)
	)
	if not StadiumOutfieldBleacherItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["rising_apple"] = layout.rising_apple.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if StadiumWallTopTerraceItems.is_family(layout) or StadiumPlayerTunnelItems.is_family(layout):
		return (
			StadiumWallTopTerraceItems.is_terrain(layout)
			or StadiumPlayerTunnelItems.is_terrain(layout)
		)
	return is_family(layout) and StadiumOutfieldBleacherItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumOutfieldBleacherItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumOutfieldBleacherItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumOutfieldBleacherItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 34,
				"optional_base": [28, 29],
				"models": StadiumRisingAppleModels.VERSION,
				"sites": {"LANDMARK-A": [36.5, 0, 44]},
				"exclusive_site": "LANDMARK-A",
				"envelope": [-6.5, 0, -5, 13, 8, 10],
				"yaw": 0,
				"tiers": ["mogul"],
				"items": ITEMS,
				"copy_policy": "exact-owned-copy-store-first-v1",
				"site_capacity": 1,
				"support": "whole-outer-property-ground-outside-terrain-patch-v1",
				"clearance": "selected-boundary-slabs-and-full-occupied-reservations-v1",
				"symmetric_reservation_conflict": "explicit-store-first-both-orders-v1",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
				"receiver": false,
				"gameplay_bonus": false,
				"earned_route": false,
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
		StadiumWallTopTerraceItems.is_family(layout)
		or (
			StadiumPlayerTunnelItems.is_family(layout)
			or (
				StadiumMountedDisplayItems.is_family(layout)
				or (
					StadiumStringLightItems.is_family(layout)
					or (
						StadiumSalvageCarItems.is_family(layout)
						or (
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
						)
					)
				)
			)
		)
	):
		return StadiumWallTopTerraceItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumOutfieldBleacherItems.geometry(tier, base(layout)),
				"rising_apple": signature()
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
		return ClubAssetLedger._error("This item is not the complete paid rising-apple landmark.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The rising-apple quote changed; reload before purchasing.")
	return result


static func sites(item: String = "ST-047") -> Array[String]:
	var result: Array[String] = []
	if PRICES.has(item):
		result.assign(SITES.keys())
		result.sort()
	return result


static func yaws(item: String = "ST-047") -> Array[int]:
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


static func envelope(item: String = "ST-047", site: String = "LANDMARK-A") -> AABB:
	return ENVELOPE if PRICES.has(item) and SITES.has(site) else AABB()


static func bounds(placed: Dictionary) -> AABB:
	return Transform3D(Basis.IDENTITY, placed.position) * envelope(placed.item, placed.site)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		StadiumWallTopTerraceItems.is_family(layout)
		or (
			StadiumPlayerTunnelItems.is_family(layout)
			or (
				StadiumMountedDisplayItems.is_family(layout)
				or (
					StadiumStringLightItems.is_family(layout)
					or (
						StadiumSalvageCarItems.is_family(layout)
						or (
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
						)
					)
				)
			)
		)
	):
		return StadiumWallTopTerraceItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("rising_apple") is Array
		or layout.rising_apple.size() > SITES.size()
	):
		return StadiumStarterLayout._error("Unknown rising-apple layout or site capacity.")
	var checked: Dictionary = StadiumOutfieldBleacherItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["rising_apple_placements"] = []
	if layout.rising_apple.is_empty():
		return checked
	if tier != "mogul":
		return StadiumStarterLayout._error("The rising apple requires Mogul property.")
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error(
			"The rising apple needs a verified complete selected field boundary."
		)
	var prior: String = ""
	for raw: Variant in layout.rising_apple:
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
						"LANDMARK-A needs one exact owned ST-047 copy; explicitly store its occupant or "
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
							"LANDMARK-A is exclusive; explicitly store its existing landmark or the rising "
							+ "apple first. Both complete paid copies remain owned."
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
					return StadiumStarterLayout._error(
						"The rising apple must leave the selected molded-seat pad and access clear."
					)
		checked.placements.append(placed)
		checked.rising_apple_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	checked.night_qualified = false
	checked["night_unqualified_reason"] = "The rising apple has not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func _supported(box: AABB, layout: Dictionary) -> bool:
	return StadiumPracticeFacilityItems._supported(box, layout)


static func _outside_play(box: AABB, graph: StadiumRecipeBoundary) -> bool:
	return StadiumGroundBoxItems._outside_play(box, graph)


static func _overlaps(reserve: AABB, other: Dictionary) -> bool:
	if PRICES.has(other.item):
		return StadiumPracticeFacilityItems._horizontal_overlap(reserve, bounds(other))
	return StadiumOutfieldBleacherItems._overlaps(reserve, other)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if (
		StadiumWallTopTerraceItems.is_family(layout)
		or (
			StadiumPlayerTunnelItems.is_family(layout)
			or (
				StadiumMountedDisplayItems.is_family(layout)
				or (
					StadiumStringLightItems.is_family(layout)
					or (
						StadiumSalvageCarItems.is_family(layout)
						or (
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
						)
					)
				)
			)
		)
	):
		return StadiumWallTopTerraceItems.with_base(
			layout, place(StadiumWallTopTerraceItems.base(layout), stock, copy, site, yaw, access)
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
	for current: Dictionary in result.rising_apple:
		if current.copy == copy and current.site == site:
			return result
	result.rising_apple.append({"copy": copy, "site": site})
	result.rising_apple.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
		StadiumWallTopTerraceItems.is_family(layout)
		or (
			StadiumPlayerTunnelItems.is_family(layout)
			or (
				StadiumMountedDisplayItems.is_family(layout)
				or (
					StadiumStringLightItems.is_family(layout)
					or (
						StadiumSalvageCarItems.is_family(layout)
						or (
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
						)
					)
				)
			)
		)
	):
		return StadiumWallTopTerraceItems.with_base(
			layout, store_copy(StadiumWallTopTerraceItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("rising_apple") is Array:
		result.rising_apple = result.rising_apple.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if (
		StadiumWallTopTerraceItems.is_family(layout)
		or (
			StadiumPlayerTunnelItems.is_family(layout)
			or (
				StadiumMountedDisplayItems.is_family(layout)
				or (
					StadiumStringLightItems.is_family(layout)
					or (
						StadiumSalvageCarItems.is_family(layout)
						or (
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
						)
					)
				)
			)
		)
	):
		return StadiumWallTopTerraceItems.prune(layout)
	return with_base(layout, StadiumOutfieldBleacherItems.prune(base(layout)))
