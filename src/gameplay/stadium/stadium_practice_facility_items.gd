class_name StadiumPracticeFacilityItems
extends RefCounted
## Complete paid practice lanes. No training, receiver, live-ball or Night authority.

const VERSION: int = 1
const PRICE_VERSION: int = 22
const LAYOUT_VERSION: int = 31
const FAMILY: String = "reference-practice-facilities-v31"
const PRICES: Dictionary = {"ST-060": [750, 220], "ST-061": [750, 220]}
const ITEMS: Array[String] = ["ST-060", "ST-061"]
const FIELDS: Array[String] = ["copy", "site"]
const EPS: float = 0.0001
const SITES: Dictionary = {
	"PRACTICE-CLUB": Vector3(-36.75, 0, 39.25),
	"PRACTICE-M1": Vector3(-40.25, 0, 41.75),
	"PRACTICE-M2": Vector3(-34.25, 0, 41.75)
}


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
		StadiumTreehouseItems.is_family(layout)
		or (
			StadiumLandmarkItems.is_family(layout)
			or (
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
														or StadiumWaterfallLiveItems.is_family(
															layout
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
				)
			)
		)
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}  # ST-006 retains its exact separate owned route.
	var result: Dictionary = StadiumGroundBoxItems.upgrade(layout, access)
	if not StadiumGroundBoxItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["practice_facilities"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
		StadiumTreehouseItems.is_family(layout)
		or (
			StadiumLandmarkItems.is_family(layout)
			or (
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
														or StadiumWaterfallLiveItems.is_family(
															layout
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
				)
			)
		)
	):
		return base(StadiumTreehouseItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumGroundBoxItems.LAYOUT_VERSION
	result.family = StadiumGroundBoxItems.FAMILY
	result.erase("practice_facilities")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
		StadiumTreehouseItems.is_family(layout)
		or (
			StadiumLandmarkItems.is_family(layout)
			or (
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
														or StadiumWaterfallLiveItems.is_family(
															layout
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
				)
			)
		)
	):
		return StadiumTreehouseItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("practice_facilities") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumGroundBoxItems.is_family(original)
		else StadiumGroundBoxItems.with_base(base(layout), original)
	)
	if not StadiumGroundBoxItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["practice_facilities"] = layout.practice_facilities.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
		StadiumTreehouseItems.is_family(layout)
		or (
			StadiumLandmarkItems.is_family(layout)
			or (
				StadiumOutfieldBleacherItems.is_family(layout)
				or (
					StadiumRisingAppleItems.is_family(layout)
					or (
						StadiumWallTopTerraceItems.is_family(layout)
						or StadiumPlayerTunnelItems.is_family(layout)
					)
				)
			)
		)
	):
		return (
			StadiumTreehouseItems.is_terrain(layout)
			or (
				StadiumLandmarkItems.is_terrain(layout)
				or (
					StadiumOutfieldBleacherItems.is_terrain(layout)
					or (
						StadiumRisingAppleItems.is_terrain(layout)
						or (
							StadiumWallTopTerraceItems.is_terrain(layout)
							or StadiumPlayerTunnelItems.is_terrain(layout)
						)
					)
				)
			)
		)
	return is_family(layout) and StadiumGroundBoxItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumGroundBoxItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumGroundBoxItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumGroundBoxItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 30,
				"optional_base": [28, 29],
				"models": StadiumPracticeFacilityModels.VERSION,
				"sites":
				{
					"PRACTICE-CLUB": [-36.75, 0, 39.25],
					"PRACTICE-M1": [-40.25, 0, 41.75],
					"PRACTICE-M2": [-34.25, 0, 41.75]
				},
				"envelopes":
				{
					"ST-060": [-2.25, 0, -5.25, 4.5, 3.5, 10.5],
					"ST-061": [-2.25, 0, -5.25, 4.5, 4, 10.5]
				},
				"yaw": 0,
				"club_tiers": ["club", "mogul"],
				"mogul_tiers": ["mogul"],
				"club_lane_overlap_m2": [8, 16],
				"mogul_lane_gap": 1.5,
				"copy_policy": "exact-owned-copy-store-first-v1",
				"off_field": true,
				"support": "whole-outer-property-ground-outside-terrain-patch-v1",
				"clearance": "selected-boundary-slabs-and-full-occupied-reservations-v1",
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
		StadiumTreehouseItems.is_family(layout)
		or (
			StadiumLandmarkItems.is_family(layout)
			or (
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
														or StadiumWaterfallLiveItems.is_family(
															layout
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
				)
			)
		)
	):
		return StadiumTreehouseItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumGroundBoxItems.geometry(tier, base(layout)),
				"practice_facilities": signature()
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
		return ClubAssetLedger._error("This item is not a complete practice facility.")
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
			"The practice facility quote changed; reload before purchasing."
		)
	return result


static func sites(item: String = "ST-060") -> Array[String]:
	var result: Array[String] = []
	if PRICES.has(item):
		result.assign(SITES.keys())
		result.sort()
	return result


static func yaws(item: String = "ST-060") -> Array[int]:
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


static func envelope(item: String = "ST-060") -> AABB:
	if not PRICES.has(item):
		return AABB()
	return AABB(Vector3(-2.25, 0, -5.25), Vector3(4.5, 3.5 if item == "ST-060" else 4.0, 10.5))


static func bounds(placed: Dictionary) -> AABB:
	return Transform3D(Basis.IDENTITY, placed.position) * envelope(placed.item)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		StadiumTreehouseItems.is_family(layout)
		or (
			StadiumLandmarkItems.is_family(layout)
			or (
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
														or StadiumWaterfallLiveItems.is_family(
															layout
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
				)
			)
		)
	):
		return StadiumTreehouseItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("practice_facilities") is Array
		or layout.practice_facilities.size() > SITES.size()
	):
		return StadiumStarterLayout._error("Unknown practice facility layout or site capacity.")
	var checked: Dictionary = StadiumGroundBoxItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["practice_facility_placements"] = []
	if layout.practice_facilities.is_empty():
		return checked
	if tier not in ["club", "mogul"]:
		return StadiumStarterLayout._error("Practice facilities require Club or Mogul property.")
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error(
			"Practice facilities need a verified complete selected field boundary."
		)
	var prior: String = ""
	for raw: Variant in layout.practice_facilities:
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
						"Each practice site needs one distinct exact owned ST-060 or ST-061 copy; "
						+ "explicitly store an occupant or moving copy first."
					)
				)
			)
		if raw.site != "PRACTICE-CLUB" and tier != "mogul":
			return StadiumStarterLayout._error(
				"The two Mogul practice lanes require Mogul property."
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
		# Validate the complete combined result, including previously processed lanes.
		# This catches Club/M1 and Club/M2 in either command order without displacement.
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
		if layout.ground_box_base_version == 29:
			for pad: AABB in StadiumMoldedSeatItems.reservations():
				if _horizontal_overlap(reserve, pad):
					return (
						StadiumStarterLayout
						. _error(
							"Practice facilities must leave the selected molded-seat pad and access clear."
						)
					)
		checked.placements.append(placed)
		checked.practice_facility_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	checked.night_qualified = false
	checked["night_unqualified_reason"] = "Practice facilities have not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func _supported(box: AABB, layout: Dictionary) -> bool:
	# All lane sites are on the actual flat outer property ground. The finite inner
	# terrain sampler is not a separate ground extent and must not truncate them.
	if box.position.y != 0.0:
		return false
	if not is_terrain(layout):
		return true
	var contract: Dictionary = terrain_contract(layout)
	return (
		not contract.is_empty()
		and contract.get("mode") in ["rough", "leveled"]
		and not (
			Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
			. intersects(StadiumSurfaceTerrain.PATCH)
		)
	)


static func _outside_play(box: AABB, graph: StadiumRecipeBoundary) -> bool:
	return StadiumGroundBoxItems._outside_play(box, graph)


static func _horizontal_overlap(a: AABB, b: AABB) -> bool:
	return Rect2(Vector2(a.position.x, a.position.z), Vector2(a.size.x, a.size.z)).intersects(
		Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z))
	)


static func _overlaps(reserve: AABB, other: Dictionary) -> bool:
	if PRICES.has(other.item):
		return _horizontal_overlap(reserve, bounds(other))
	if StadiumGroundBoxItems.PRICES.has(other.item):
		return _horizontal_overlap(reserve, StadiumGroundBoxItems.bounds(other))
	if StadiumMoldedSeatItems.PRICES.has(other.item):
		return _horizontal_overlap(reserve, StadiumMoldedSeatItems.bounds(other))
	# The inherited reservation helper uses the frozen actual tower radius (1.35m
	# for ST-038), not an invented practice exclusion radius or a point-only test.
	# It also includes occupied service reservations, roofs, hosts and landscape.
	return StadiumMoldedSeatItems._reservation_overlaps(reserve, other)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if (
		StadiumTreehouseItems.is_family(layout)
		or (
			StadiumLandmarkItems.is_family(layout)
			or (
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
														or StadiumWaterfallLiveItems.is_family(
															layout
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
				)
			)
		)
	):
		return StadiumTreehouseItems.with_base(
			layout, place(StadiumTreehouseItems.base(layout), stock, copy, site, yaw, access)
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
	for current: Dictionary in result.practice_facilities:
		if current.copy == copy and current.site == site:
			return result
	result.practice_facilities.append({"copy": copy, "site": site})
	result.practice_facilities.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
		StadiumTreehouseItems.is_family(layout)
		or (
			StadiumLandmarkItems.is_family(layout)
			or (
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
														or StadiumWaterfallLiveItems.is_family(
															layout
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
				)
			)
		)
	):
		return StadiumTreehouseItems.with_base(
			layout, store_copy(StadiumTreehouseItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("practice_facilities") is Array:
		result.practice_facilities = result.practice_facilities.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if (
		StadiumTreehouseItems.is_family(layout)
		or (
			StadiumLandmarkItems.is_family(layout)
			or (
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
														or StadiumWaterfallLiveItems.is_family(
															layout
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
				)
			)
		)
	):
		return StadiumTreehouseItems.prune(layout)
	return with_base(layout, StadiumGroundBoxItems.prune(base(layout)))
