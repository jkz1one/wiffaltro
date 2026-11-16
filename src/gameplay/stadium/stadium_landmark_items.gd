class_name StadiumLandmarkItems
extends RefCounted
## Complete paid sculpture, robot and tiki fountain. Fixed outside-play scenery only.

const VERSION: int = 1
const PRICE_VERSION: int = 24
const LAYOUT_VERSION: int = 33
const FAMILY: String = "reference-landmarks-v33"
const PRICES: Dictionary = {"ST-048": [600, 160], "ST-049": [650, 170], "ST-050": [750, 200]}
const ITEMS: Array[String] = ["ST-048", "ST-049", "ST-050"]
const FIELDS: Array[String] = ["copy", "site"]
const EPS: float = 0.0001
const SITES: Dictionary = {"LANDMARK-A": Vector3(36.5, 0, 44), "ODDITY-PLAZA": Vector3(40, 0, -14)}


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
		StadiumOutfieldBleacherItems.is_family(layout)
		or (
			StadiumRisingAppleItems.is_family(layout)
			or (
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
			)
		)
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}  # ST-006 retains its exact separate owned route.
	var result: Dictionary = StadiumTreehouseItems.upgrade(layout, access)
	if not StadiumTreehouseItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["landmarks"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
		StadiumOutfieldBleacherItems.is_family(layout)
		or (
			StadiumRisingAppleItems.is_family(layout)
			or (
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
			)
		)
	):
		return base(StadiumOutfieldBleacherItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumTreehouseItems.LAYOUT_VERSION
	result.family = StadiumTreehouseItems.FAMILY
	result.erase("landmarks")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
		StadiumOutfieldBleacherItems.is_family(layout)
		or (
			StadiumRisingAppleItems.is_family(layout)
			or (
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
			)
		)
	):
		return StadiumOutfieldBleacherItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("landmarks") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumTreehouseItems.is_family(original)
		else StadiumTreehouseItems.with_base(base(layout), original)
	)
	if not StadiumTreehouseItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["landmarks"] = layout.landmarks.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
		StadiumOutfieldBleacherItems.is_family(layout)
		or (
			StadiumRisingAppleItems.is_family(layout)
			or (
				StadiumWallTopTerraceItems.is_family(layout)
				or StadiumPlayerTunnelItems.is_family(layout)
			)
		)
	):
		return (
			StadiumOutfieldBleacherItems.is_terrain(layout)
			or (
				StadiumRisingAppleItems.is_terrain(layout)
				or (
					StadiumWallTopTerraceItems.is_terrain(layout)
					or StadiumPlayerTunnelItems.is_terrain(layout)
				)
			)
		)
	return is_family(layout) and StadiumTreehouseItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumTreehouseItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumTreehouseItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumTreehouseItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 32,
				"optional_base": [28, 29],
				"models": StadiumLandmarkModels.VERSION,
				"sites": {"LANDMARK-A": [36.5, 0, 44], "ODDITY-PLAZA": [40, 0, -14]},
				"primary_footprint": [-6.5, 0, -5, 13, 10],
				"primary_heights": {"ST-048": 5, "ST-049": 7, "ST-050": 5},
				"plaza_envelope": [-3.5, 0, -3.5, 7, 8, 7],
				"yaw": 0,
				"tiers": ["mogul"],
				"items": ITEMS,
				"copy_policy": "exact-owned-copy-store-first-v1",
				"site_capacity": 1,
				"support": "whole-outer-property-ground-outside-terrain-patch-v1",
				"clearance": "selected-boundary-slabs-and-full-occupied-reservations-v1",
				"club_or_conflict": "explicit-store-first-both-orders-v1",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
				"receiver": false,
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
		StadiumOutfieldBleacherItems.is_family(layout)
		or (
			StadiumRisingAppleItems.is_family(layout)
			or (
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
			)
		)
	):
		return StadiumOutfieldBleacherItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{"base": StadiumTreehouseItems.geometry(tier, base(layout)), "landmarks": signature()},
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
		return ClubAssetLedger._error("This item is not a complete paid landmark.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The landmark quote changed; reload before purchasing.")
	return result


static func sites(item: String = "ST-048") -> Array[String]:
	var result: Array[String] = []
	if PRICES.has(item):
		result.assign(SITES.keys())
		result.sort()
	return result


static func yaws(item: String = "ST-048") -> Array[int]:
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


static func envelope(item: String = "ST-048", site: String = "LANDMARK-A") -> AABB:
	if not PRICES.has(item) or not SITES.has(site):
		return AABB()
	if site == "ODDITY-PLAZA":
		return AABB(Vector3(-3.5, 0, -3.5), Vector3(7, 8, 7))
	return AABB(Vector3(-6.5, 0, -5), Vector3(13, 7 if item == "ST-049" else 5, 10))


static func bounds(placed: Dictionary) -> AABB:
	return Transform3D(Basis.IDENTITY, placed.position) * envelope(placed.item, placed.site)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		StadiumOutfieldBleacherItems.is_family(layout)
		or (
			StadiumRisingAppleItems.is_family(layout)
			or (
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
			)
		)
	):
		return StadiumOutfieldBleacherItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("landmarks") is Array
		or layout.landmarks.size() > SITES.size()
	):
		return StadiumStarterLayout._error("Unknown landmark layout or site capacity.")
	var checked: Dictionary = StadiumTreehouseItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["landmark_placements"] = []
	if layout.landmarks.is_empty():
		return checked
	if tier != "mogul":
		return StadiumStarterLayout._error("Both landmark sites require Mogul property.")
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error(
			"Landmarks need a verified complete selected field boundary."
		)
	var prior: String = ""
	for raw: Variant in layout.landmarks:
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
						"Each landmark site needs one distinct exact owned ST-048, ST-049 or ST-050 copy; "
						+ "explicitly store an occupant or moving copy first."
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
		# The complete reconstructed result catches conflicts in both command orders,
		# including CLIGHT-OR's actual 1.35m circular footprint at (32, 38).
		for other: Dictionary in checked.placements:
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
						"Landmarks must leave the selected molded-seat pad and access clear."
					)
		checked.placements.append(placed)
		checked.landmark_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	checked.night_qualified = false
	checked["night_unqualified_reason"] = "Landmarks have not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func _supported(box: AABB, layout: Dictionary) -> bool:
	return StadiumPracticeFacilityItems._supported(box, layout)


static func _outside_play(box: AABB, graph: StadiumRecipeBoundary) -> bool:
	return StadiumGroundBoxItems._outside_play(box, graph)


static func _overlaps(reserve: AABB, other: Dictionary) -> bool:
	if PRICES.has(other.item):
		return StadiumPracticeFacilityItems._horizontal_overlap(reserve, bounds(other))
	if StadiumTreehouseItems.PRICES.has(other.item):
		return StadiumPracticeFacilityItems._horizontal_overlap(
			reserve, StadiumTreehouseItems.bounds(other)
		)
	return StadiumPracticeFacilityItems._overlaps(reserve, other)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if (
		StadiumOutfieldBleacherItems.is_family(layout)
		or (
			StadiumRisingAppleItems.is_family(layout)
			or (
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
			)
		)
	):
		return StadiumOutfieldBleacherItems.with_base(
			layout, place(StadiumOutfieldBleacherItems.base(layout), stock, copy, site, yaw, access)
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
	for current: Dictionary in result.landmarks:
		if current.copy == copy and current.site == site:
			return result
	result.landmarks.append({"copy": copy, "site": site})
	result.landmarks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
		StadiumOutfieldBleacherItems.is_family(layout)
		or (
			StadiumRisingAppleItems.is_family(layout)
			or (
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
			)
		)
	):
		return StadiumOutfieldBleacherItems.with_base(
			layout, store_copy(StadiumOutfieldBleacherItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("landmarks") is Array:
		result.landmarks = result.landmarks.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if (
		StadiumOutfieldBleacherItems.is_family(layout)
		or (
			StadiumRisingAppleItems.is_family(layout)
			or (
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
			)
		)
	):
		return StadiumOutfieldBleacherItems.prune(layout)
	return with_base(layout, StadiumTreehouseItems.prune(base(layout)))
